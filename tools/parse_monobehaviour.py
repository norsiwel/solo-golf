#!/usr/bin/env python3
"""
parse_monobehaviour.py — Extract green shapes, OB lines and hazards
from AssetStudio exported MonoBehaviour .dat files.

Usage:
    python3 tools/parse_monobehaviour.py <extracted_assets_dir> <course_meta.json>

Example:
    python3 tools/parse_monobehaviour.py \
        "assets/extracted assets" \
        courses/The_Old_Course_meta.json

Outputs:
    courses/The_Old_Course_shapes.json  — green polygons, OB lines, hazards
"""

import struct
import os
import sys
import json
import math
import glob
import re

def read_floats(data):
    """Extract all plausible 4-byte floats from binary data."""
    floats = []
    for i in range(0, len(data) - 3, 4):
        try:
            v = struct.unpack_from('<f', data, i)[0]
            if not math.isnan(v) and not math.isinf(v):
                floats.append(v)
        except:
            pass
    return floats

def read_vector3_array(data, origin_x=0.0, origin_z=0.0):
    """
    Extract a sequence of Vector3 from binary data.
    Looks for runs of 3 consecutive floats that look like XYZ coords.
    Returns list of (x, y, z) tuples normalized to course origin.
    """
    floats = read_floats(data)
    points = []
    
    # Look for triplets where X and Z are in plausible world range
    # St Andrews world coords are roughly 0-3000 range
    i = 0
    while i < len(floats) - 2:
        x = floats[i]
        y = floats[i+1] 
        z = floats[i+2]
        # Plausible world coordinate range
        if (500 < x < 4000 and 
            0 < y < 200 and 
            -2000 < z < 2000):
            # Normalize to course origin
            nx = x - origin_x
            nz = z - origin_z
            points.append((nx, y, nz))
            i += 3
        else:
            i += 1
    return points

def extract_strings(data):
    """Extract readable ASCII strings from binary data."""
    return [s.decode('ascii', errors='ignore') 
            for s in re.findall(b'[\x20-\x7e]{4,}', data)]

def parse_hazard(fpath, origin_x, origin_z):
    """Parse a Hazard .dat file for water/OB boundary splines."""
    with open(fpath, 'rb') as f:
        data = f.read()
    
    strings = extract_strings(data)
    
    # Determine hazard type
    hazard_type = "water"
    for s in strings:
        sl = s.lower()
        if 'out of bounds' in sl or 'ob' in sl:
            hazard_type = "ob"
            break
        elif 'water' in sl or 'lateral' in sl:
            hazard_type = "water"
            break
        elif 'bunker' in sl:
            hazard_type = "bunker"
            break
    
    points = read_vector3_array(data, origin_x, origin_z)
    
    return {
        "type": hazard_type,
        "points": [{"x": round(p[0], 2), "y": round(p[1], 2), "z": round(p[2], 2)} 
                   for p in points],
        "source": os.path.basename(fpath)
    }

def estimate_green_shape(pin_positions, radius=12.0):
    """
    Generate an approximate green polygon from pin cluster.
    Uses convex hull of pin positions expanded by radius.
    """
    if not pin_positions:
        return []
    
    if len(pin_positions) == 1:
        # Single pin - generate circle
        cx, cz = pin_positions[0]
        pts = []
        for i in range(12):
            a = i * math.tau / 12
            pts.append({"x": round(cx + math.cos(a)*radius, 2), 
                        "z": round(cz + math.sin(a)*radius, 2)})
        return pts
    
    # Multiple pins - find extent and create ellipse around them
    xs = [p[0] for p in pin_positions]
    zs = [p[1] for p in pin_positions]
    cx = sum(xs) / len(xs)
    cz = sum(zs) / len(zs)
    
    # Radius in each direction from centroid
    max_dx = max(abs(x - cx) for x in xs) + radius
    max_dz = max(abs(z - cz) for z in zs) + radius
    
    # Generate ellipse
    pts = []
    for i in range(16):
        a = i * math.tau / 16
        pts.append({"x": round(cx + math.cos(a)*max_dx, 2),
                    "z": round(cz + math.sin(a)*max_dz, 2)})
    return pts

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    
    assets_dir = sys.argv[1]
    meta_path = sys.argv[2]
    mono_dir = os.path.join(assets_dir, "MonoBehaviour")
    
    if not os.path.exists(mono_dir):
        print(f"Error: MonoBehaviour dir not found: {mono_dir}")
        sys.exit(1)
    
    if not os.path.exists(meta_path):
        print(f"Error: Meta file not found: {meta_path}")
        sys.exit(1)
    
    # Load course metadata
    with open(meta_path) as f:
        meta = json.load(f)
    
    course_name = meta.get("name", "Unknown")
    holes = meta.get("holes", [])
    
    # Get origin (hole 1 tee) for normalization
    h1_tee = holes[0].get("tee", {}) if holes else {}
    origin_x = h1_tee.get("x", 0.0) + 1882.0  # un-normalize back to world coords
    origin_z = h1_tee.get("z", 0.0)
    
    print(f"Parsing MonoBehaviour data for: {course_name}")
    print(f"Origin: X={origin_x:.1f} Z={origin_z:.1f}")
    
    output = {
        "course": course_name,
        "greens": [],
        "hazards": [],
        "ob_lines": []
    }
    
    # --- Build green shapes from pin cluster positions ---
    print("\nBuilding green shapes from pin positions...")
    for hole in holes:
        hole_num = hole.get("hole", 0)
        all_pins = hole.get("all_pins", [])
        
        # Collect pin XZ positions for this hole
        pin_positions = []
        for p in all_pins:
            pos = p.get("position", {})
            if pos:
                pin_positions.append((pos.get("x", 0), pos.get("z", 0)))
        
        # Also use main pin
        main_pin = hole.get("pin", {})
        if main_pin:
            pin_positions.append((main_pin.get("x", 0), main_pin.get("z", 0)))
        
        if not pin_positions:
            continue
        
        # Determine green size hint from yardage
        yardage = hole.get("yardage", 400)
        if yardage < 200:  # short par 3 - smaller green
            green_radius = 9.0
        elif yardage > 500:  # long par 5 - larger green
            green_radius = 15.0
        else:
            green_radius = 12.0
        
        shape = estimate_green_shape(pin_positions, green_radius)
        
        output["greens"].append({
            "hole": hole_num,
            "par": hole.get("par", 4),
            "yardage": yardage,
            "pin_count": len(pin_positions),
            "shape": shape,
            "center": {
                "x": round(sum(p[0] for p in pin_positions) / len(pin_positions), 2),
                "z": round(sum(p[1] for p in pin_positions) / len(pin_positions), 2)
            }
        })
        print(f"  Hole {hole_num}: {len(pin_positions)} pins, radius {green_radius:.0f}m, {len(shape)} polygon points")
    
    # --- Parse Hazard .dat files ---
    print("\nParsing hazard files...")
    hazard_files = glob.glob(os.path.join(mono_dir, "Hazard*.dat"))
    
    for fpath in sorted(hazard_files):
        try:
            h = parse_hazard(fpath, origin_x, origin_z)
            if h["points"]:
                if h["type"] == "ob":
                    output["ob_lines"].append(h)
                else:
                    output["hazards"].append(h)
                print(f"  {os.path.basename(fpath)}: {h['type']} - {len(h['points'])} points")
        except Exception as e:
            print(f"  Warning: Could not parse {os.path.basename(fpath)}: {e}")
    
    # Save output
    base = os.path.splitext(meta_path)[0].replace("_meta", "")
    out_path = base + "_shapes.json"
    with open(out_path, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\nOutput: {out_path}")
    print(f"  Greens: {len(output['greens'])}")
    print(f"  Hazards: {len(output['hazards'])}")
    print(f"  OB lines: {len(output['ob_lines'])}")
    print("\nNext step: Load shapes.json in hole_map.gd for accurate green outlines")
    print("           Load hazards into main.tscn as Area3D water/OB zones")

if __name__ == "__main__":
    main()
