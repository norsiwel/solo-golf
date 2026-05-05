#!/usr/bin/env python3
"""
spline_mesh_placer.py — Map Spline Mesh geometry to world positions.

Unity exports Mesh .dat files (local space, centered at 0) and separate
Spline MonoBehaviour .dat files (world-space spline control points).
The two asset types share the same creation order so sorting by numeric ID
pairs them 1:1.

Usage:
    python3 tools/spline_mesh_placer.py <extracted_assets_dir> [--convert-all]

    --convert-all   Also batch-convert all Spline Mesh .dat -> OBJ -> GLB
                    (requires tools/unity_mesh_to_obj.py and tools/obj_to_glb.py)

Outputs:
    courses/The_Old_Course_mesh_placement.json
    courses/The_Old_Course_spline_meshes.gd   (auto-loader GDScript)

Coordinate transform (Unity left-handed -> Godot right-handed, tee-1 origin):
    godot_x = unity_x - ORIGIN_X
    godot_z = ORIGIN_Z_NEG - unity_z          (flips Z axis)
    ORIGIN_X = 1882.06  (tee 1 Unity world X)
    ORIGIN_Z_NEG = 181.82  (negated tee 1 Unity world Z, because meta stores -z)
"""

import struct
import math
import os
import sys
import json
import re
import glob
import subprocess

# Tee 1 world origin in Unity space (from The_Old_Course_meta.json + coordinate analysis)
ORIGIN_X = 1882.06
ORIGIN_Z = 181.82   # Unity_z of tee 1 (meta stores -181.82, which is -Unity_z)

def unity_to_godot(ux, uy, uz):
    return (ux - ORIGIN_X, uy, ORIGIN_Z - uz)


# ---------------------------------------------------------------------------
# Parse a Spline MonoBehaviour .dat file
# ---------------------------------------------------------------------------

def read_string_at(data, off):
    """Read a uint32-prefixed UTF-8 string."""
    length = struct.unpack_from('<I', data, off)[0]
    if length > 512 or length == 0:
        return None, off
    name = data[off+4:off+4+length].decode('utf-8', errors='replace').rstrip('\x00')
    end = off + 4 + ((length + 3) & ~3)
    return name, end


def is_world_coord(x, y, z):
    """Plausible St Andrews world-space triplet."""
    return (300 < x < 3500 and 0 < y < 150 and -500 < z < 3000)


def parse_spline_mono(fpath):
    """
    Extract name and world-space control points from a Spline MonoBehaviour.
    Returns {'name': str, 'points': [(x,y,z),...], 'centroid': (gx,gy,gz),
             'bounds': (min_x,max_x,min_z,max_z)}
    """
    with open(fpath, 'rb') as f:
        data = f.read()

    # Try to read a name string near the start (offset 44 based on observed format)
    name = "Unknown"
    for probe in [44, 40, 48, 36]:
        if probe + 4 > len(data):
            continue
        n, _ = read_string_at(data, probe)
        if n and 3 < len(n) < 64 and all(32 <= ord(c) < 127 for c in n):
            name = n
            break

    # Extract world-space Vector3 triplets
    points = []
    i = 0
    while i <= len(data) - 12:
        try:
            x = struct.unpack_from('<f', data, i)[0]
            y = struct.unpack_from('<f', data, i+4)[0]
            z = struct.unpack_from('<f', data, i+8)[0]
        except struct.error:
            i += 4
            continue
        if (not math.isnan(x) and not math.isnan(y) and not math.isnan(z)
                and is_world_coord(x, y, z)):
            points.append((x, y, z))
            i += 12
        else:
            i += 4

    if not points:
        return None

    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    zs = [p[2] for p in points]
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    cz = sum(zs) / len(zs)

    gx, gy, gz = unity_to_godot(cx, cy, cz)

    return {
        'name': name,
        'points': len(points),
        'centroid_unity': (round(cx,2), round(cy,2), round(cz,2)),
        'centroid_godot': (round(gx,2), round(gy,2), round(gz,2)),
        'bounds_unity': {
            'x': (round(min(xs),2), round(max(xs),2)),
            'y': (round(min(ys),2), round(max(ys),2)),
            'z': (round(min(zs),2), round(max(zs),2)),
        },
        'size': (round(max(xs)-min(xs),1), round(max(zs)-min(zs),1)),
    }


# ---------------------------------------------------------------------------
# Parse OBJ vertex extents (for already-converted meshes)
# ---------------------------------------------------------------------------

def obj_extents(obj_path):
    xs, ys, zs = [], [], []
    with open(obj_path) as f:
        for line in f:
            if line.startswith('v '):
                parts = line.split()
                xs.append(float(parts[1]))
                ys.append(float(parts[2]))
                zs.append(float(parts[3]))
    if not xs:
        return None
    return {
        'size': (round(max(xs)-min(xs),1), round(max(zs)-min(zs),1)),
        'vert_count': len(xs),
    }


# ---------------------------------------------------------------------------
# Classify spline name -> surface type
# ---------------------------------------------------------------------------

def classify_type(name):
    nl = name.lower()
    if 'fairway' in nl:
        return 'fairway'
    if 'green' in nl:
        return 'green'
    if 'rough' in nl or 'semi' in nl:
        return 'rough'
    if 'bunker' in nl or 'sand' in nl:
        return 'bunker'
    if 'path' in nl or 'cart' in nl:
        return 'path'
    if 'tee' in nl:
        return 'tee'
    if 'fringe' in nl or 'collar' in nl:
        return 'fringe'
    if 'water' in nl:
        return 'water'
    return 'other'


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)

    assets_dir = args[0]
    convert_all = '--convert-all' in args

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    mesh_dir    = os.path.join(assets_dir, 'Mesh')
    mono_dir    = os.path.join(assets_dir, 'MonoBehaviour')
    out_mesh_dir = os.path.join(project_dir, 'courses', 'meshes')
    os.makedirs(out_mesh_dir, exist_ok=True)

    # --- Collect and sort all Spline Mesh .dat files by numeric ID ---
    mesh_pattern = re.compile(r'^Spline Mesh #(\d+)\.dat$')
    mesh_files = []
    for fname in os.listdir(mesh_dir):
        m = mesh_pattern.match(fname)
        if m:
            mesh_files.append((int(m.group(1)), fname))
    mesh_files.sort()
    print(f"Found {len(mesh_files)} Spline Mesh .dat files")

    # --- Collect and sort all Spline MonoBehaviour files by numeric ID ---
    mono_pattern = re.compile(r'^Spline #(\d+)\.dat$')
    mono_files = []
    for fname in os.listdir(mono_dir):
        m = mono_pattern.match(fname)
        if m:
            mono_files.append((int(m.group(1)), fname))
    mono_files.sort()
    print(f"Found {len(mono_files)} Spline MonoBehaviour files")

    # --- Parse MonoBehaviours ---
    print("\nParsing MonoBehaviour spline data...")
    mono_data = []
    for mid, mfname in mono_files:
        fpath = os.path.join(mono_dir, mfname)
        info = parse_spline_mono(fpath)
        if info:
            info['mono_id'] = mid
            mono_data.append(info)
        else:
            mono_data.append({'mono_id': mid, 'name': 'Unknown', 'points': 0,
                               'centroid_godot': (0,0,0)})

    # --- Optional: batch convert all meshes ---
    if convert_all:
        print("\nConverting all Spline Mesh .dat -> OBJ -> GLB...")
        conv_script = os.path.join(script_dir, 'unity_mesh_to_obj.py')
        glb_script  = os.path.join(script_dir, 'obj_to_glb.py')
        converted = 0
        for mesh_id, mesh_fname in mesh_files:
            safe = mesh_fname.replace(' ', '_').replace('#', '').replace('.dat', '')
            obj_path = os.path.join(out_mesh_dir, safe + '.obj')
            glb_path = os.path.join(out_mesh_dir, safe + '.glb')
            if os.path.exists(glb_path):
                converted += 1
                continue
            dat_path = os.path.join(mesh_dir, mesh_fname)
            r = subprocess.run(['python3', conv_script, dat_path, obj_path],
                               capture_output=True)
            if r.returncode == 0 and os.path.exists(obj_path):
                r2 = subprocess.run(['python3', glb_script, obj_path, glb_path],
                                    capture_output=True)
                if r2.returncode == 0:
                    converted += 1
        print(f"  Converted/existing: {converted}/{len(mesh_files)}")

    # --- Get sizes of all available OBJ meshes ---
    mesh_sizes = {}
    for mesh_id, mesh_fname in mesh_files:
        safe_name = mesh_fname.replace(' ', '_').replace('#', '').replace('.dat', '')
        obj_path  = os.path.join(out_mesh_dir, safe_name + '.obj')
        if os.path.exists(obj_path):
            ext = obj_extents(obj_path)
            if ext:
                mesh_sizes[mesh_id] = (safe_name, ext['size'], ext['vert_count'])

    print(f"OBJ meshes with size data: {len(mesh_sizes)}")

    # --- Match converted meshes to MonoBehaviours by size similarity ---
    # The SplineMesh MonoBehaviour controls the PATH of the mesh; the mesh
    # geometry extends ~1-3x wider than the spline path on each side.
    # Strategy: for each converted mesh, find the MonoBehaviour whose spline
    # diagonal is closest to mesh_diagonal / EXPANSION (try 1.5–3.0).
    # Use a greedy nearest-neighbour approach (closest size first, no reuse).
    #
    # For very large meshes that exceed all MonoBehaviour sizes (whole-course
    # terrain slabs), fall back to the course centroid.

    def diag(sz):
        return math.sqrt(sz[0]**2 + sz[1]**2) if sz else 0

    # Pre-compute MonoBehaviour diagonals
    for mb in mono_data:
        mb['diag'] = diag(mb.get('size')) if mb.get('size') else 0

    available_mono = list(mono_data)  # will be consumed greedily

    mesh_to_mono = {}  # mesh_id -> mono entry
    # Sort converted meshes largest-first so the biggest mesh gets first pick
    sorted_converted = sorted(mesh_sizes.items(), key=lambda kv: -diag(kv[1][1]))

    EXPANSION = 2.0   # mesh is ~2x wider than spline extent on each axis
    COURSE_CENTER = (-620.0, 22.5, -640.0)  # approximate Godot course centroid

    for mesh_id, (safe_name, mesh_sz, _) in sorted_converted:
        target_diag = diag(mesh_sz) / EXPANSION

        # If target is larger than ALL remaining MonoBehaviours, this is a
        # whole-course slab — place at course centre.
        max_mb_diag = max((m['diag'] for m in available_mono), default=0)
        if target_diag > max_mb_diag * 1.5:
            mesh_to_mono[mesh_id] = {
                'mono_id': None,
                'name': 'CourseSlab',
                'centroid_godot': COURSE_CENTER,
                'size': mesh_sz,
                'diag': diag(mesh_sz),
            }
            continue

        # Nearest neighbour by diagonal size
        best = min(available_mono, key=lambda m: abs(m['diag'] - target_diag))
        mesh_to_mono[mesh_id] = best
        available_mono.remove(best)

    # --- Build placement list for converted GLBs ---
    placements = []
    for mesh_id, mesh_fname in mesh_files:
        safe_name = mesh_fname.replace(' ', '_').replace('#', '').replace('.dat', '')
        glb_rel   = f"courses/meshes/{safe_name}.glb"
        glb_abs   = os.path.join(project_dir, glb_rel)

        if not os.path.exists(glb_abs):
            continue   # skip unconverted meshes

        mb = mesh_to_mono.get(mesh_id)
        if not mb:
            continue

        mesh_info = mesh_sizes.get(mesh_id, (safe_name, None, 0))
        gx, gy, gz = mb.get('centroid_godot', COURSE_CENTER)
        stype = classify_type(mb.get('name', ''))

        entry = {
            'mesh_file':  glb_rel,
            'mesh_id':    mesh_id,
            'mono_id':    mb.get('mono_id'),
            'name':       mb.get('name', 'CourseSlab'),
            'type':       stype,
            'godot_x':    gx,
            'godot_y':    gy,
            'godot_z':    gz,
            'glb_exists': True,
            'spline_size': mb.get('size'),
            'mesh_size':  mesh_info[1],
        }
        placements.append(entry)

    # --- Stats ---
    by_type = {}
    for p in placements:
        by_type.setdefault(p['type'], 0)
        by_type[p['type']] += 1
    print("\nSurface type breakdown:")
    for t, n in sorted(by_type.items(), key=lambda x: -x[1]):
        print(f"  {t:12s}: {n}")
    print(f"\nTotal placements: {len(placements)}")

    # --- Write placement JSON ---
    out_json = os.path.join(project_dir, 'courses', 'The_Old_Course_mesh_placement.json')
    with open(out_json, 'w') as f:
        json.dump({'origin': {'unity_x': ORIGIN_X, 'unity_z': ORIGIN_Z},
                   'placements': placements}, f, indent=2)
    print(f"\nWrote: {out_json}")

    # --- Write GDScript auto-loader (only for GLBs that exist) ---
    gd_lines = [
        'extends Node3D',
        '# Auto-generated by spline_mesh_placer.py',
        '# Loads and places all converted Spline Mesh GLBs at their Unity world positions.',
        '',
        'const PLACEMENT_PATH = "res://courses/The_Old_Course_mesh_placement.json"',
        '',
        'func _ready():',
        '\t_load_meshes()',
        '',
        'func _load_meshes():',
        '\tvar file = FileAccess.open(PLACEMENT_PATH, FileAccess.READ)',
        '\tif not file: push_error("SplineMeshLoader: cannot open " + PLACEMENT_PATH); return',
        '\tvar data = JSON.parse_string(file.get_as_text())',
        '\tfile.close()',
        '\tif not data: return',
        '\tvar loaded := 0',
        '\tfor entry in data.placements:',
        '\t\tvar glb_path: String = "res://" + entry.mesh_file if not entry.mesh_file.begins_with("res://") else entry.mesh_file',
        '\t\tif not ResourceLoader.exists(glb_path): continue',
        '\t\tvar scene = load(glb_path)',
        '\t\tif not scene: continue',
        '\t\tvar inst = scene.instantiate()',
        '\t\tinst.position = Vector3(entry.godot_x, entry.godot_y, entry.godot_z)',
        '\t\tadd_child(inst)',
        '\t\tloaded += 1',
        '\tprint("SplineMeshLoader: placed %d meshes" % loaded)',
    ]
    gd_path = os.path.join(project_dir, 'courses', 'The_Old_Course_spline_loader.gd')
    with open(gd_path, 'w') as f:
        f.write('\n'.join(gd_lines) + '\n')
    print(f"Wrote: {gd_path}")

    # --- Preview all placements ---
    print("\nAll placements (mesh_id, type, Godot pos, size match):")
    for p in sorted(placements, key=lambda x: x['mesh_id']):
        ms = p['mesh_size']
        ss = p['spline_size']
        ratio = f"{diag(ms)/diag(ss):.1f}x" if ms and ss and diag(ss) > 0 else "slab"
        print(f"  #{p['mesh_id']} {p['name'][:28]:28s} {p['type']:8s} "
              f"({p['godot_x']:7.1f}, {p['godot_z']:7.1f})  ratio={ratio}")


if __name__ == '__main__':
    main()
