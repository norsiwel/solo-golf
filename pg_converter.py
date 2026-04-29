#!/usr/bin/env python3
"""
Perfect Golf -> Solo Golf Course Converter
Reads a .description JSON file and generates a Godot 4 .tscn scene file
with all tees, pins, and hole metadata placed at correct world positions.

Usage:
    python3 pg_converter.py <path_to_description_file> [output_dir]

Example:
    python3 pg_converter.py ~/Downloads/sunsetvalleygc_fnl3_1/sunsetvalleygc_fnl3_1.description ~/solo-golf/courses/
"""

import json
import sys
import os
import math

def parse_description(filepath):
    with open(filepath, 'r') as f:
        return json.load(f)

def meters_to_yards(m):
    return m * 1.09361

def distance_3d(a, b):
    return math.sqrt((a['x']-b['x'])**2 + (a['y']-b['y'])**2 + (a['z']-b['z'])**2)

def distance_2d(a, b):
    return math.sqrt((a['x']-b['x'])**2 + (a['z']-b['z'])**2)

def pg_to_godot(pos):
    """Convert Perfect Golf coords to Godot coords.
    PG uses Unity left-handed Y-up. Godot is right-handed Y-up.
    Flip Z axis."""
    return {
        'x': pos['x'],
        'y': pos['y'],
        'z': -pos['z']
    }

def par_str_to_int(par_str):
    """Convert '_3' -> 3, '_4' -> 4, '_5' -> 5"""
    try:
        return int(par_str.replace('_', ''))
    except:
        return 4

def build_hole_data(data):
    """Organize tees and pins by hole index."""
    holes = {}

    # Collect tees
    for tee in data.get('tees', []):
        hi = tee['holeIndex']
        if hi not in holes:
            holes[hi] = {'tees': [], 'pins': [], 'shots': []}
        holes[hi]['tees'].append(tee)

    # Collect pins
    for pin in data.get('pins', []):
        hi = pin['holeIndex']
        if hi not in holes:
            holes[hi] = {'tees': [], 'pins': [], 'shots': []}
        holes[hi]['pins'].append(pin)

    # Collect shot positions (approach cam hints)
    for shot in data.get('shots', []):
        hi = shot['holeIndex']
        if hi not in holes:
            holes[hi] = {'tees': [], 'pins': [], 'shots': []}
        holes[hi]['shots'].append(shot)

    return holes

def get_preferred_tee(tees, preference='Championship'):
    """Get the best tee position based on preference order."""
    order = ['Championship', 'Tournament', 'Back', 'Member', 'Challenge']
    for t in order:
        for tee in tees:
            if tee['type'] == t:
                return tee
    return tees[0] if tees else None

def get_medium_pin(pins):
    """Get a medium difficulty pin, fall back to first."""
    for pin in pins:
        if pin['difficulty'] == 'Medium':
            return pin
    return pins[0] if pins else None

def calculate_yardage(tee_pos, pin_pos):
    """Calculate yardage from tee to pin."""
    dist_m = distance_2d(tee_pos, pin_pos)
    return int(meters_to_yards(dist_m))

def generate_tscn(course_name, data, holes, output_path):
    """Generate a Godot 4 .tscn file for the course."""

    lines = []

    # Header
    lines.append('[gd_scene format=3]')
    lines.append('')
    lines.append('[ext_resource type="Script" path="res://green.gd" id="1_green"]')
    lines.append('[ext_resource type="Script" path="res://tee.gd" id="2_tee"]')
    lines.append('')

    # Sub-resources for shapes
    lines.append('# --- Shared Collision Shapes ---')
    lines.append('[sub_resource type="CylinderShape3D" id="TeeShape"]')
    lines.append('radius = 5.0')
    lines.append('height = 1.0')
    lines.append('')
    lines.append('[sub_resource type="BoxShape3D" id="GreenShape"]')
    lines.append('size = Vector3(22, 0.5, 16)')
    lines.append('')
    lines.append('[sub_resource type="CylinderMesh" id="TeeMesh"]')
    lines.append('top_radius = 5.0')
    lines.append('bottom_radius = 5.0')
    lines.append('height = 0.05')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="TeeMat"]')
    lines.append('albedo_color = Color(0.15, 0.5, 0.12, 1)')
    lines.append('')
    lines.append('[sub_resource type="PlaneMesh" id="GreenMesh"]')
    lines.append('size = Vector2(22, 16)')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="GreenMat"]')
    lines.append('albedo_color = Color(0.08, 0.42, 0.08, 1)')
    lines.append('')
    lines.append('[sub_resource type="CylinderMesh" id="FlagpoleMesh"]')
    lines.append('top_radius = 0.03')
    lines.append('bottom_radius = 0.03')
    lines.append('height = 3.0')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="FlagpoleMat"]')
    lines.append('albedo_color = Color(0.9, 0.9, 0.9, 1)')
    lines.append('')
    lines.append('[sub_resource type="BoxMesh" id="FlagMesh"]')
    lines.append('size = Vector3(0.6, 0.4, 0.02)')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="FlagMat"]')
    lines.append('albedo_color = Color(1.0, 0.1, 0.1, 1)')
    lines.append('')
    lines.append('[sub_resource type="CylinderMesh" id="CupMesh"]')
    lines.append('top_radius = 0.27')
    lines.append('bottom_radius = 0.27')
    lines.append('height = 0.05')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="CupMat"]')
    lines.append('albedo_color = Color(0.05, 0.05, 0.05, 1)')
    lines.append('')
    lines.append('[sub_resource type="CylinderMesh" id="TeePegMesh"]')
    lines.append('top_radius = 0.02')
    lines.append('bottom_radius = 0.04')
    lines.append('height = 0.05')
    lines.append('')
    lines.append('[sub_resource type="StandardMaterial3D" id="TeePegMat"]')
    lines.append('albedo_color = Color(0.8, 0.3, 0.1, 1)')
    lines.append('')

    # Root node
    lines.append(f'[node name="{course_name}" type="Node3D"]')
    lines.append('')

    # Sort holes by index
    sorted_holes = sorted(holes.items())

    for hole_idx, hole_data in sorted_holes:
        hole_num = hole_idx + 1
        tees = hole_data['tees']
        pins = hole_data['pins']

        if not tees or not pins:
            print(f"  Skipping hole {hole_num} - missing tee or pin data")
            continue

        # Pick best tee and pin
        best_tee = get_preferred_tee(tees)
        best_pin = get_medium_pin(pins)

        tee_gpos = pg_to_godot(best_tee['position'])
        pin_gpos = pg_to_godot(best_pin['position'])

        par = par_str_to_int(best_tee.get('par', '_4'))
        yardage = calculate_yardage(best_tee['position'], best_pin['position'])
        stroke_index = best_tee.get('strokeIndex', hole_num)

        print(f"  Hole {hole_num}: Par {par}, {yardage} yds, SI {stroke_index}")

        # --- Hole group node ---
        lines.append(f'[node name="Hole{hole_num}" type="Node3D" parent="."]')
        lines.append(f'# Hole {hole_num} | Par {par} | {yardage} yds | SI {stroke_index}')
        lines.append('')

        # --- Tee Area ---
        lines.append(f'[node name="TeeBox{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {tee_gpos["x"]:.3f}, {tee_gpos["y"]:.3f}, {tee_gpos["z"]:.3f})')
        lines.append('mesh = SubResource("TeeMesh")')
        lines.append('surface_material_override/0 = SubResource("TeeMat")')
        lines.append('')

        lines.append(f'[node name="TeeArea{hole_num}" type="Area3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {tee_gpos["x"]:.3f}, {tee_gpos["y"]+0.3:.3f}, {tee_gpos["z"]:.3f})')
        lines.append('script = ExtResource("2_tee")')
        lines.append(f'hole_number = {hole_num}')
        lines.append(f'par = {par}')
        lines.append(f'yardage = {yardage}')
        lines.append('')

        lines.append(f'[node name="TeeCollision{hole_num}" type="CollisionShape3D" parent="Hole{hole_num}/TeeArea{hole_num}"]')
        lines.append('shape = SubResource("TeeShape")')
        lines.append('')

        # Tee peg
        lines.append(f'[node name="TeePeg{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {tee_gpos["x"]:.3f}, {tee_gpos["y"]+0.03:.3f}, {tee_gpos["z"]-1.0:.3f})')
        lines.append('mesh = SubResource("TeePegMesh")')
        lines.append('surface_material_override/0 = SubResource("TeePegMat")')
        lines.append('')

        # All tee markers for this hole (Championship/Tournament/Member etc)
        for tee in tees:
            tee_type = tee['type']
            tp = pg_to_godot(tee['position'])
            lines.append(f'[node name="Tee_{tee_type}_{hole_num}" type="Node3D" parent="Hole{hole_num}"]')
            lines.append(f'# {tee_type} tee - {calculate_yardage(tee["position"], best_pin["position"])} yds')
            lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {tp["x"]:.3f}, {tp["y"]:.3f}, {tp["z"]:.3f})')
            lines.append('')

        # --- Green ---
        lines.append(f'[node name="Green{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {pin_gpos["x"]:.3f}, {pin_gpos["y"]+0.02:.3f}, {pin_gpos["z"]:.3f})')
        lines.append('mesh = SubResource("GreenMesh")')
        lines.append('surface_material_override/0 = SubResource("GreenMat")')
        lines.append('')

        lines.append(f'[node name="GreenArea{hole_num}" type="Area3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {pin_gpos["x"]:.3f}, {pin_gpos["y"]+0.02:.3f}, {pin_gpos["z"]:.3f})')
        lines.append('script = ExtResource("1_green")')
        lines.append(f'stimp = 8.0')
        lines.append(f'par = {par}')
        lines.append(f'hole_number = {hole_num}')
        lines.append('')

        lines.append(f'[node name="GreenCollision{hole_num}" type="CollisionShape3D" parent="Hole{hole_num}/GreenArea{hole_num}"]')
        lines.append('shape = SubResource("GreenShape")')
        lines.append('')

        # --- Flagstick ---
        lines.append(f'[node name="Flagstick{hole_num}" type="Node3D" parent="Hole{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {pin_gpos["x"]:.3f}, {pin_gpos["y"]:.3f}, {pin_gpos["z"]:.3f})')
        lines.append('')

        lines.append(f'[node name="Pole{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}/Flagstick{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, 0, 1.5, 0)')
        lines.append('mesh = SubResource("FlagpoleMesh")')
        lines.append('surface_material_override/0 = SubResource("FlagpoleMat")')
        lines.append('')

        lines.append(f'[node name="Flag{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}/Flagstick{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, 0.35, 2.9, 0)')
        lines.append('mesh = SubResource("FlagMesh")')
        lines.append('surface_material_override/0 = SubResource("FlagMat")')
        lines.append('')

        lines.append(f'[node name="Cup{hole_num}" type="MeshInstance3D" parent="Hole{hole_num}/Flagstick{hole_num}"]')
        lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, 0, 0.01, 0)')
        lines.append('mesh = SubResource("CupMesh")')
        lines.append('surface_material_override/0 = SubResource("CupMat")')
        lines.append('')

        # All pin positions as markers
        for pin in pins:
            pp = pg_to_godot(pin['position'])
            diff = pin['difficulty']
            lines.append(f'[node name="Pin_{diff}_{hole_num}_{pin["orderIndex"]}" type="Node3D" parent="Hole{hole_num}"]')
            lines.append(f'# {diff} pin position')
            lines.append(f'transform = Transform3D(1,0,0, 0,1,0, 0,0,1, {pp["x"]:.3f}, {pp["y"]:.3f}, {pp["z"]:.3f})')
            lines.append('')

    # Write file
    content = '\n'.join(lines)
    with open(output_path, 'w') as f:
        f.write(content)

    print(f"\nWrote: {output_path}")

def generate_metadata(course_name, data, holes, output_dir):
    """Generate a companion JSON with hole metadata for the game to read."""
    meta = {
        'name': data.get('name', course_name),
        'author': data.get('author', 'Unknown'),
        'holes': []
    }

    sorted_holes = sorted(holes.items())
    for hole_idx, hole_data in sorted_holes:
        hole_num = hole_idx + 1
        tees = hole_data['tees']
        pins = hole_data['pins']

        if not tees or not pins:
            continue

        best_tee = get_preferred_tee(tees)
        best_pin = get_medium_pin(pins)

        tee_gpos = pg_to_godot(best_tee['position'])
        pin_gpos = pg_to_godot(best_pin['position'])
        par = par_str_to_int(best_tee.get('par', '_4'))
        yardage = calculate_yardage(best_tee['position'], best_pin['position'])

        hole_meta = {
            'hole': hole_num,
            'par': par,
            'yardage': yardage,
            'stroke_index': best_tee.get('strokeIndex', hole_num),
            'tee': tee_gpos,
            'pin': pin_gpos,
            'all_tees': [],
            'all_pins': []
        }

        for tee in tees:
            hole_meta['all_tees'].append({
                'type': tee['type'],
                'position': pg_to_godot(tee['position']),
                'yardage': calculate_yardage(tee['position'], best_pin['position'])
            })

        for pin in pins:
            hole_meta['all_pins'].append({
                'difficulty': pin['difficulty'],
                'position': pg_to_godot(pin['position'])
            })

        meta['holes'].append(hole_meta)

    meta_path = os.path.join(output_dir, course_name + '_meta.json')
    with open(meta_path, 'w') as f:
        json.dump(meta, f, indent=2)
    print(f"Wrote metadata: {meta_path}")
    return meta

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    desc_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(desc_path)

    if not os.path.exists(desc_path):
        print(f"Error: File not found: {desc_path}")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    print(f"Reading: {desc_path}")
    data = parse_description(desc_path)

    course_name = data.get('name', 'Unknown Course').replace(' ', '_').replace("'", '')
    author = data.get('author', 'Unknown')
    print(f"Course: {data.get('name', 'Unknown')} by {author}")

    holes = build_hole_data(data)
    print(f"Found {len(holes)} holes\n")

    # Print scorecard
    print("SCORECARD:")
    print("-" * 40)
    total_par = 0
    sorted_holes = sorted(holes.items())
    for hole_idx, hole_data in sorted_holes:
        hole_num = hole_idx + 1
        tees = hole_data['tees']
        pins = hole_data['pins']
        if tees and pins:
            best_tee = get_preferred_tee(tees)
            best_pin = get_medium_pin(pins)
            par = par_str_to_int(best_tee.get('par', '_4'))
            yardage = calculate_yardage(best_tee['position'], best_pin['position'])
            total_par += par
            print(f"  Hole {hole_num:2d}: Par {par}  {yardage:4d} yds  SI {best_tee.get('strokeIndex', '?'):2}")
    print(f"  Total Par: {total_par}")
    print("-" * 40)

    # Generate scene file
    scene_filename = course_name + '.tscn'
    scene_path = os.path.join(output_dir, scene_filename)
    print(f"\nGenerating scene: {scene_filename}")
    generate_tscn(course_name, data, holes, scene_path)

    # Generate metadata
    generate_metadata(course_name, data, holes, output_dir)

    print(f"\nDone! Copy {scene_filename} to your solo-golf project")
    print(f"Open Godot, double click the scene file, and all 18 holes will be positioned correctly.")
    print(f"\nNote: You still need terrain geometry - this places tees, greens and flags only.")

if __name__ == '__main__':
    main()
