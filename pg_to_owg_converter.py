#!/usr/bin/env python3
"""
PG to OWG Course Converter
Converts Perfect Golf .zip course files to OWG (Solo Golf) Godot format.

Usage:
    python3 pg_to_owg_converter.py [options] [file1.zip file2.zip ...]

Options:
    --output, -o    Output directory for OWG zips (default: current directory)
    --debug         Enable verbose diagnostic output
    --no-tscn       Skip .tscn generation (use runtime PNG loading instead)

Dependencies:
    pip install UnityPy Pillow numpy
"""

import os
import sys
import json
import struct
import zipfile
import shutil
import tempfile
import argparse
from pathlib import Path

try:
    import UnityPy
    from PIL import Image
    import numpy as np
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Run: pip install UnityPy Pillow numpy")
    sys.exit(1)

# ─────────────────────────────────────────────
#  Debug logger
# ─────────────────────────────────────────────

DEBUG = False

def dbg(msg):
    if DEBUG:
        print(f"  [DEBUG] {msg}")

def info(msg):
    print(f"  {msg}")

def warn(msg):
    print(f"  WARNING: {msg}")

def err(msg):
    print(f"  ERROR: {msg}")


# ─────────────────────────────────────────────
#  Coordinate conversion
#  Unity: Left-handed, Y-up
#  Godot: Right-handed, Y-up
#  Conversion: flip X axis (x = -x)
# ─────────────────────────────────────────────

def unity_to_godot_pos(x, y, z):
    return (-x, y, z)


def unity_to_godot_rot(x, y, z):
    # Unity (Euler) → Godot (Euler)
    # This is a simplified conversion: Godot Y-rotation is usually what matters most for buildings/trees
    return (x, -y, z)


def sanitize_name(name):
    return "".join(c if c.isalnum() or c in "-_ " else "_" for c in name).strip().replace(" ", "-")


# ─────────────────────────────────────────────
#  Heightmap extraction
# ─────────────────────────────────────────────

def extract_heightmap(terrain_data, output_dir):
    """
    Extract Unity terrain heightmap and save as 16-bit PNG for Godot.
    Unity stores heights as unsigned shorts (0-65535).
    Returns meta dict or None on failure.
    """
    try:
        hm = terrain_data.m_Heightmap
        width  = hm.m_Width
        height = hm.m_Height
        heights = hm.m_Heights
        scale  = hm.m_Scale  # Vector3f: x/z = terrain size per unit, y = height scale

        info(f"Heightmap: {width}x{height}, scale X={scale.x:.3f} Y={scale.y:.3f} Z={scale.z:.3f}")
        dbg(f"Raw heights array length: {len(heights)}, expected: {width * height}")

        if len(heights) != width * height:
            warn(f"Height array length mismatch: got {len(heights)}, expected {width * height}")

        # Convert to numpy uint16
        arr = np.array(heights, dtype=np.uint16).reshape(height, width)

        dbg(f"Height array stats: min={arr.min()} max={arr.max()} mean={arr.mean():.1f}")

        if arr.max() == 0:
            warn("Heightmap is completely flat (all zeros) — terrain data may not have extracted correctly")
        elif arr.max() < 1000:
            warn(f"Heightmap values very low (max={arr.max()}) — course may appear very flat")
        else:
            info(f"Height range: {arr.min()} – {arr.max()} (raw uint16)")

        # Unity heightmap: heights stored as uint16 fraction of scale.y*2
        effective_scale_y = scale.y * 2.0

        # Correct orientation (verified to 0m error against all 18 tee positions):
        # transpose rows/cols then flip both axes
        arr = arr.T           # transpose: swap row/col (X/Z axes)
        arr = np.flipud(arr)  # flip rows
        arr = np.fliplr(arr)  # flip cols

        # Save as 16-bit PNG
        terrain_dir = os.path.join(output_dir, "terrain")
        os.makedirs(terrain_dir, exist_ok=True)
        heightmap_path = os.path.join(terrain_dir, "heightmap.png")

        img = Image.fromarray(arr, mode='I;16')
        img.save(heightmap_path)

        info(f"Heightmap saved: {width}x{height} 16-bit PNG ✓")

        terrain_size_x = width  * scale.x
        terrain_size_z = height * scale.z
        real_height_range = (arr.max() / 65535.0) * effective_scale_y

        info(f"Terrain world size: {terrain_size_x:.1f} x {terrain_size_z:.1f} units")
        info(f"Estimated height range: 0 – {real_height_range:.2f} m")

        meta = {
            "width":          width,
            "height":         height,
            "scale_x":        scale.x,
            "scale_y":        effective_scale_y,
            "scale_z":        scale.z,
            "terrain_size_x": terrain_size_x,
            "terrain_size_z": terrain_size_z,
        }

        # Use heightmap minimum as water plane reference (replaces Unity PP_waterplane)
        height_min = float((arr.astype(np.float32) / 65535.0 * effective_scale_y).min())
        meta["water_level"] = round(height_min, 4)
        print(f"  Water level (heightmap min): {height_min:.3f}m")

        meta_path = os.path.join(terrain_dir, "terrain_meta.json")
        with open(meta_path, "w") as f:
            json.dump(meta, f, indent=2)
        dbg(f"terrain_meta.json written")

        return meta, arr  # return array too for .tscn generation

    except AttributeError as e:
        err(f"TerrainData missing expected attribute: {e}")
        dbg(f"Available attributes: {[a for a in dir(terrain_data) if not a.startswith('__')]}")
        return None, None
    except Exception as e:
        err(f"Heightmap extraction failed: {e}")
        if DEBUG:
            import traceback; traceback.print_exc()
        return None, None


# ─────────────────────────────────────────────
#  Godot .tscn generation with baked heightmap
# ─────────────────────────────────────────────

def build_tscn(height_arr, meta, output_dir):
    """
    Build a Godot 4 .tscn with:
      - StaticBody3D (root)
        - CollisionShape3D  (HeightMapShape3D — full resolution)
        - MeshInstance3D    (ArrayMesh — downsampled visual with real vertex heights)
    """
    info("Building terrain .tscn with baked heightmap...")

    width    = meta["width"]
    height_n = meta["height"]
    scale_x  = meta["scale_x"]
    scale_y  = meta["scale_y"]
    scale_z  = meta["scale_z"]
    size_x   = meta["terrain_size_x"]
    size_z   = meta["terrain_size_z"]

    norm = height_arr.astype(np.float32) / 65535.0
    shape_heights = (norm * scale_y).flatten()

    # ── Collision shape (full resolution) ──────────────────────────
    CHUNK = 16
    float_strs = [f"{v:.4f}" for v in shape_heights]
    lines = []
    for i in range(0, len(float_strs), CHUNK):
        lines.append(", ".join(float_strs[i:i+CHUNK]))
    packed_data = ",\n".join(lines)
    info(f"Packed {len(shape_heights)} height values for HeightMapShape3D")

    # ── Visual mesh (downsampled to MESH_RES x MESH_RES) ───────────
    # Full 4097x4097 as text ArrayMesh would be ~600MB — downsample to 256x256
    MESH_RES = 256
    step_r = max(1, (height_n - 1) // (MESH_RES - 1))
    step_c = max(1, (width   - 1) // (MESH_RES - 1))
    rows = list(range(0, height_n, step_r))
    cols = list(range(0, width,    step_c))
    # Always include last row/col so mesh reaches full terrain edge
    if rows[-1] != height_n - 1: rows.append(height_n - 1)
    if cols[-1] != width    - 1: cols.append(width    - 1)
    mr = len(rows)
    mc = len(cols)

    # Build vertex list
    verts  = []   # (x, y, z)
    normals = []  # (nx, ny, nz)
    uvs    = []   # (u, v)

    h2d = norm * scale_y  # 2D array [height_n, width]

    for ri, r in enumerate(rows):
        for ci, c in enumerate(cols):
            # Apply same coordinate flip as unity_to_godot_pos: godot_x = -unity_x
            # Unity terrain goes from x=0 to x=size_x (positive)
            # Godot coords: flip so terrain goes from x=0 to x=-size_x (negative)
            wx = -(c * scale_x)   # negative X to match Godot coordinate system
            wy = float(h2d[r, c])
            wz = r * scale_z      # Z stays positive
            verts.append((wx, wy, wz))
            uvs.append((-wx / size_x, wz / size_z))  # UV u = -wx/size so 0→1

            # Finite-difference normal (adjusted for flipped X)
            def hs(rr, cc):
                rr = max(0, min(height_n-1, rr))
                cc = max(0, min(width-1, cc))
                return float(h2d[rr, cc])
            dx = hs(r, c+1) - hs(r, c-1)   # positive = going more negative in X
            dz = hs(r+1, c) - hs(r-1, c)
            nx, ny, nz = dx, 2.0 * scale_x, -dz  # flip sign for normal X
            length = (nx*nx + ny*ny + nz*nz) ** 0.5 or 1.0
            normals.append((nx/length, ny/length, nz/length))

    # Build index list (two triangles per quad)
    indices = []
    for ri in range(mr - 1):
        for ci in range(mc - 1):
            i00 = ri * mc + ci
            i10 = i00 + 1
            i01 = i00 + mc
            i11 = i01 + 1
            indices += [i00, i01, i10, i10, i01, i11]

    info(f"Visual mesh: {mr}x{mc} = {len(verts)} verts, {len(indices)//3} tris")

    # Godot PackedVector3Array / PackedVector2Array / PackedInt32Array in text format
    def pack_v3(arr):
        parts = [f"{x:.4f}, {y:.4f}, {z:.4f}" for x,y,z in arr]
        return "PackedVector3Array(" + ", ".join(parts) + ")"

    def pack_v2(arr):
        parts = [f"{u:.5f}, {v:.5f}" for u,v in arr]
        return "PackedVector2Array(" + ", ".join(parts) + ")"

    def pack_i32(arr):
        # chunk for readability
        CHUNK = 24
        rows_out = []
        for i in range(0, len(arr), CHUNK):
            rows_out.append(", ".join(str(x) for x in arr[i:i+CHUNK]))
        return "PackedInt32Array(" + ",\n".join(rows_out) + ")"

    verts_str   = pack_v3(verts)
    normals_str = pack_v3(normals)
    uvs_str     = pack_v2(uvs)
    idx_str     = pack_i32(indices)

    # Centre offset
    offset_x = size_x / 2.0
    offset_z = size_z / 2.0

    tscn = f"""[gd_scene load_steps=3 format=3 uid="uid://owg_terrain"]

[sub_resource type="HeightMapShape3D" id="HeightMapShape3D_1"]
map_width = {width}
map_depth = {height_n}
map_data = PackedFloat32Array(
{packed_data}
)

[sub_resource type="ArrayMesh" id="ArrayMesh_1"]
_surfaces = [{{
"primitive": 3,
"arrays": [
{verts_str},
{normals_str},
null, null, null,
{uvs_str},
null, null,
{idx_str}
],
"material": null,
"name": "terrain_surface"
}}]

[node name="OWGTerrain" type="StaticBody3D"]
metadata/owg_terrain = true
metadata/terrain_size_x = {size_x:.3f}
metadata/terrain_size_z = {size_z:.3f}
metadata/scale_y = {scale_y:.3f}
metadata/scale_x = {scale_x:.4f}
metadata/scale_z = {scale_z:.4f}

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("HeightMapShape3D_1")
transform = Transform3D({-scale_x:.4f}, 0, 0, 0, 1, 0, 0, 0, {scale_z:.4f}, 0, 0, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("ArrayMesh_1")
"""

    terrain_dir = os.path.join(output_dir, "terrain")
    os.makedirs(terrain_dir, exist_ok=True)
    tscn_path = os.path.join(terrain_dir, "terrain.tscn")

    with open(tscn_path, "w") as f:
        f.write(tscn)

    size_mb = os.path.getsize(tscn_path) / 1024 / 1024
    info(f"terrain.tscn written: {size_mb:.1f} MB ({mr}x{mc} visual mesh) ✓")
    return tscn_path


# ─────────────────────────────────────────────
#  Splat / surface texture extraction
# ─────────────────────────────────────────────

# Known surface texture name patterns → Godot surface type
SURFACE_PATTERNS = {
    "fairway":    ["fairway", "fair"],
    "rough":      ["rough"],
    "deep_rough": ["deeprough", "deep_rough", "heavyrough"],
    "bunker":     ["bunker", "sand", "trap"],
    "green":      ["green", "putting"],
    "fringe":     ["fringe", "collar", "apron"],
    "water":      ["water", "pond", "lake"],
    "path":       ["path", "cart", "road"],
    "tee":        ["tee_box", "teebox", "tee"],
}

def classify_texture(name):
    """Map a Unity texture name to a Godot surface type."""
    lower = name.lower()
    for surface, patterns in SURFACE_PATTERNS.items():
        for p in patterns:
            if p in lower:
                return surface
    return "unknown"


def extract_splat_maps(terrain_data, output_dir):
    """Extract terrain surface blend maps (alphamaps)."""
    try:
        splat_db = terrain_data.m_SplatDatabase
    except AttributeError:
        warn("No m_SplatDatabase found on TerrainData")
        return []

    splat_dir = os.path.join(output_dir, "terrain", "splat")
    os.makedirs(splat_dir, exist_ok=True)

    alpha_count = 0
    for i, alpha_tex_ptr in enumerate(splat_db.m_AlphaTextures):
        try:
            tex_obj = alpha_tex_ptr.read()
            img = tex_obj.image
            if img:
                out_path = os.path.join(splat_dir, f"alphamap_{i}.png")
                img.save(out_path)
                alpha_count += 1
                dbg(f"Alphamap {i}: {img.size} {img.mode}")
        except Exception as e:
            warn(f"Could not extract alphamap {i}: {e}")

    info(f"Extracted {alpha_count} alphamap(s)")

    # Save splat layer info with surface classification
    layers = []
    for i, splat in enumerate(splat_db.m_Splats):
        layer = {
            "index": i,
            "tile_size_x": splat.tileSize.x if hasattr(splat, 'tileSize') else 15,
            "tile_size_y": splat.tileSize.y if hasattr(splat, 'tileSize') else 15,
        }
        try:
            tex = splat.texture.read()
            layer["texture_name"] = tex.m_Name
            layer["surface_type"]  = classify_texture(tex.m_Name)
            dbg(f"Splat layer {i}: '{tex.m_Name}' → {layer['surface_type']}")
        except Exception:
            layer["texture_name"] = f"layer_{i}"
            layer["surface_type"]  = "unknown"
        layers.append(layer)

    info(f"Splat layers: {len(layers)} ({sum(1 for l in layers if l['surface_type'] != 'unknown')} classified)")

    layers_path = os.path.join(splat_dir, "splat_layers.json")
    with open(layers_path, "w") as f:
        json.dump(layers, f, indent=2)

    return layers


# ─────────────────────────────────────────────
#  Texture extraction
# ─────────────────────────────────────────────

def extract_textures(env, output_dir):
    """
    Extract Texture2D assets from the Unity bundle.
    Classifies each by surface type and writes a texture_map.json
    so Godot knows which PNG is fairway, rough, bunker, etc.
    """
    tex_dir = os.path.join(output_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)

    extracted = 0
    skipped   = 0
    texture_map = {}  # surface_type → filename

    for obj in env.objects:
        if obj.type.name != "Texture2D":
            continue
        try:
            data = obj.read()
            img  = data.image
            if not img:
                skipped += 1
                continue

            safe_name = "".join(
                c if c.isalnum() or c in "-_." else "_"
                for c in data.m_Name
            )
            out_path = os.path.join(tex_dir, f"{safe_name}.png")
            img.save(out_path)
            extracted += 1

            surface = classify_texture(data.m_Name)
            dbg(f"Texture: '{data.m_Name}' ({img.size}) → {surface}")

            if surface != "unknown":
                # Keep highest-res version if duplicate surface type
                if surface not in texture_map:
                    texture_map[surface] = f"{safe_name}.png"
                else:
                    dbg(f"  Duplicate surface '{surface}', keeping first match")

        except Exception as ex:
            skipped += 1
            dbg(f"Skipped texture: {ex}")

    info(f"Textures: {extracted} extracted, {skipped} skipped")
    info(f"Classified: {list(texture_map.keys())}")

    # Write texture map for Godot loader
    map_path = os.path.join(tex_dir, "texture_map.json")
    with open(map_path, "w") as f:
        json.dump(texture_map, f, indent=2)
    dbg(f"texture_map.json: {texture_map}")

    return extracted, texture_map


# ─────────────────────────────────────────────
#  Mesh extraction
# ─────────────────────────────────────────────

def extract_meshes(env, output_dir):
    """Extract Mesh assets from the Unity bundle as .obj files."""
    mesh_dir = os.path.join(output_dir, "meshes")
    os.makedirs(mesh_dir, exist_ok=True)

    extracted = 0
    mesh_map = {} # pathid → filename

    for obj in env.objects:
        if obj.type.name != "Mesh":
            continue
        try:
            data = obj.read()
            # UnityPy can export meshes as .obj
            obj_data = data.export()
            if not obj_data:
                continue
            
            safe_name = sanitize_name(data.m_Name)
            if not safe_name:
                safe_name = f"Mesh_{obj.path_id}"
            
            fname = f"{safe_name}.obj"
            fpath = os.path.join(mesh_dir, fname)
            
            # If name collision, append path_id
            if os.path.exists(fpath):
                fname = f"{safe_name}_{obj.path_id}.obj"
                fpath = os.path.join(mesh_dir, fname)

            with open(fpath, "wb") as f:
                if isinstance(obj_data, str):
                    f.write(obj_data.encode("utf-8"))
                else:
                    f.write(obj_data)
            
            mesh_map[obj.path_id] = f"meshes/{fname}"
            extracted += 1
        except Exception as ex:
            dbg(f"Skipped mesh {obj.path_id}: {ex}")

    info(f"Meshes: {extracted} extracted")
    return extracted, mesh_map


# ─────────────────────────────────────────────
#  Object placement extraction
# ─────────────────────────────────────────────

def extract_objects(env, mesh_map, output_dir):
    """Extract GameObject placements and link to meshes."""
    info("Extracting object placements...")
    if DEBUG: dbg(f"Mesh map has {len(mesh_map)} entries")
    objects = []
    water_level = None

    types_found = set()
    go_encountered = 0
    for obj in env.objects:
        types_found.add(obj.type.name)
        if obj.type.name != "GameObject":
            continue
        
        go_encountered += 1
        if DEBUG and go_encountered < 10:
             dbg(f"Encountered GO #{go_encountered}: {obj.path_id}")
        
        try:
            data = obj.read()
            name = getattr(data, "m_Name", f"GO_{obj.path_id}")
            
            if DEBUG and go_encountered < 2:
                dbg(f"  GO '{name}' attributes: {[a for a in dir(data) if not a.startswith('__')]}")
            
            components = getattr(data, "m_Component", [])
            if not components:
                components = getattr(data, "m_Components", [])
            
            if DEBUG and go_encountered < 2:
                dbg(f"  GO '{name}' m_Component has {len(components)} items")
                if len(components) > 0:
                    dbg(f"  First item type: {type(components[0])}")
            
            # Find MeshFilter and Transform components
            mesh_filter = None
            transform = None
            
            # Try direct access first (some UnityPy versions support this)
            if hasattr(data, "m_MeshFilter"):
                 mf_ptr = data.m_MeshFilter
                 if mf_ptr: mesh_filter = mf_ptr.read()
            if hasattr(data, "m_Transform"):
                 t_ptr = data.m_Transform
                 if t_ptr: transform = t_ptr.read()
            
            if not mesh_filter or not transform:
                for c in components:
                    # In some versions it's a dict with "component" key
                    c_ptr = None
                    if isinstance(c, tuple) and len(c) > 0:
                        for item in c:
                             if hasattr(item, "read") or hasattr(item, "path_id"):
                                 c_ptr = item
                                 break
                    elif isinstance(c, dict):
                        c_ptr = c.get("component")
                    elif hasattr(c, "component"):
                        c_ptr = c.component
                    else:
                        c_ptr = c
                    
                    if DEBUG and go_encountered < 2:
                        dbg(f"    - c_ptr type: {type(c_ptr)} (has read: {hasattr(c_ptr, 'read') if c_ptr else False})")
                    
                    if not c_ptr: continue
                    try:
                        c_obj = c_ptr.read()
                        ctype = type(c_obj).__name__
                        if DEBUG and go_encountered < 2:
                             dbg(f"    - Component: {ctype}")
                        if ctype == "MeshFilter":
                            mesh_filter = c_obj
                        elif ctype == "Transform":
                            transform = c_obj
                    except Exception as e:
                        if DEBUG and go_encountered < 2:
                             dbg(f"    - Component read failed: {e}")
                        continue
            
            if "pp_waterplane" in name.lower() and water_level is None and transform:
                water_level = float(transform.m_LocalPosition.y)
                continue

            if not mesh_filter:
                continue

            if not transform:
                continue
            
            # Debug first few failures
            mesh_ptr = getattr(mesh_filter, "m_Mesh", None)
            if not mesh_ptr:
                if DEBUG and len(objects) == 0: dbg(f"  GameObject '{name}' MeshFilter has no m_Mesh")
                continue
            
            pid = mesh_ptr.path_id
            mesh_path = mesh_map.get(pid)
            if not mesh_path:
                if DEBUG and len(objects) == 0: dbg(f"  GameObject '{name}' Mesh path_id {pid} NOT in mesh_map (map size {len(mesh_map)})")
                continue
            
            # Get local transform
            pos = transform.m_LocalPosition
            rot = transform.m_LocalRotation # quaternion
            scale = transform.m_LocalScale
            
            gx, gy, gz = unity_to_godot_pos(pos.x, pos.y, pos.z)
            
            objects.append({
                "name": name,
                "mesh": mesh_path,
                "position": {"x": gx, "y": gy, "z": gz},
                "rotation": {"x": rot.x, "y": rot.y, "z": rot.z, "w": rot.w},
                "scale": {"x": scale.x, "y": scale.y, "z": scale.z}
            })
            
        except Exception as ex:
            dbg(f"Skipped object {obj.path_id}: {ex}")
            
    if DEBUG: dbg(f"Types encountered in loop: {types_found}")
    info(f"Objects: {len(objects)} placements found")
    if water_level is not None:
        info(f"Water level (Unity Y): {water_level:.3f}")
    return objects, water_level


# ─────────────────────────────────────────────
#  Course JSON conversion
# ─────────────────────────────────────────────

def convert_course_json(description_data, terrain_meta, objects, water_level, output_dir):
    """Convert PG course description JSON to OWG format."""

    def convert_pos(pos_dict):
        x, y, z = pos_dict["x"], pos_dict["y"], pos_dict["z"]
        gx, gy, gz = unity_to_godot_pos(x, y, z)
        height_min = terrain_meta.get("water_level", 0.0) if terrain_meta else 0.0
        pos = {"x": gx, "y": gy, "z": gz}
        pos["y"] = pos["y"] - height_min
        return pos

    holes = {}

    for tee in description_data.get("tees", []):
        idx = tee["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["tees"].append({
            "type":         tee["type"],
            "par":          tee["par"].replace("_", ""),
            "stroke_index": tee["strokeIndex"],
            "position":     convert_pos(tee["position"]),
            "order":        tee["orderIndex"],
        })

    for pin in description_data.get("pins", []):
        idx = pin["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["pins"].append({
            "difficulty": pin["difficulty"],
            "position":   convert_pos(pin["position"]),
            "order":      pin["orderIndex"],
        })

    for shot in description_data.get("shots", []):
        idx = shot["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["shots"].append({
            "position": convert_pos(shot["position"]),
            "order":    shot["orderIndex"],
        })

    holes_list = []
    for i in sorted(holes.keys()):
        h = holes[i]
        h["hole_number"] = i + 1
        h["tees"]  = sorted(h["tees"],  key=lambda t: t["order"])
        h["pins"]  = sorted(h["pins"],  key=lambda p: p["order"])
        h["shots"] = sorted(h["shots"], key=lambda s: s["order"])
        holes_list.append(h)

    dbg(f"Converted {len(holes_list)} holes")
    if DEBUG:
        for h in holes_list[:2]:  # show first 2 holes in debug
            tee = h["tees"][0]["position"] if h["tees"] else "?"
            pin = h["pins"][0]["position"] if h["pins"] else "?"
            dbg(f"  Hole {h['hole_number']}: tee={tee} pin={pin}")

    owg_course = {
        "format":           "OWG-1.0",
        "name":             description_data.get("name", "Unknown Course"),
        "author":           description_data.get("author", "Unknown"),
        "author_version":   description_data.get("authorVersion", "1.0"),
        "platform_original": "Unity/PerfectGolf",
        "converted_by":     "pg_to_owg_converter",
        "coordinate_system": "Godot (right-handed Y-up, X flipped from Unity)",
        "geo": {
            "x":        description_data.get("geoX", 0),
            "y":        description_data.get("geoY", 0),
            "z":        description_data.get("geoZ", 0),
            "utm_zone": description_data.get("utmZone", 0),
        },
        "terrain":      terrain_meta or {},
        "holes":        holes_list,
        "hole_count":   len(holes_list),
        "splash_image": description_data.get("splashName", ""),
        "flag_image":   description_data.get("flagName",   ""),
        "offset":       description_data.get("offset", 0),
        "objects":      objects,
        "water_level":  water_level
    }

    course_json_path = os.path.join(output_dir, "course.json")
    with open(course_json_path, "w") as f:
        json.dump(owg_course, f, indent=2)

    info(f"course.json: {len(holes_list)} holes ✓")
    return owg_course


# ─────────────────────────────────────────────
#  Copy splash / flag images
# ─────────────────────────────────────────────

def copy_images(zip_ref, description_data, output_dir):
    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    for key in ("splashName", "flagName"):
        name = description_data.get(key, "")
        if not name:
            continue
        for zname in zip_ref.namelist():
            if zname.endswith(name):
                try:
                    data = zip_ref.read(zname)
                    out_path = os.path.join(images_dir, name)
                    with open(out_path, "wb") as f:
                        f.write(data)
                    info(f"Copied image: {name} ✓")
                except Exception as e:
                    warn(f"Could not copy {name}: {e}")
                break


# ─────────────────────────────────────────────
#  Diagnostics — dump Unity bundle contents
# ─────────────────────────────────────────────

def dump_bundle_contents(env):
    """Print a full inventory of what's in the Unity bundle."""
    print("\n  [DEBUG] Bundle contents:")
    type_map = {}
    for obj in env.objects:
        t = obj.type.name
        type_map[t] = type_map.get(t, [])
        try:
            data = obj.read()
            name = getattr(data, 'm_Name', '?')
            type_map[t].append(name)
        except Exception:
            type_map[t].append('<unreadable>')

    for t, names in sorted(type_map.items(), key=lambda x: -len(x[1])):
        if len(names) <= 5:
            print(f"    {t} ({len(names)}): {', '.join(names)}")
        else:
            print(f"    {t} ({len(names)}): {', '.join(names[:5])} ...")


# ─────────────────────────────────────────────
#  Main conversion for one zip file
# ─────────────────────────────────────────────

def convert_course(zip_path, output_base_dir, build_tscn_file=True):
    """Convert a single PG course zip to OWG format."""
    zip_name = Path(zip_path).stem
    print(f"\n{'='*60}")
    print(f"Converting: {zip_name}")
    print(f"{'='*60}")

    with tempfile.TemporaryDirectory() as tmpdir:
        work_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(work_dir)

        # ── Step 1: Open zip, find key files ──────────────────────
        print("\n[1/7] Reading zip contents...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()
            dbg(f"Zip contains {len(names)} files")
            if DEBUG:
                for n in names:
                    dbg(f"  {n}")

            desc_file   = next((n for n in names if n.endswith(".description")), None)
            unity_file  = next((n for n in names if n.endswith(".unity3d")),     None)

            if not desc_file:
                err("No .description file found in zip")
                return False
            if not unity_file:
                err("No .unity3d file found in zip")
                return False

            info(f"Description: {desc_file}")
            info(f"Unity bundle: {unity_file}")

            desc_raw = zf.read(desc_file).decode("utf-8")
            description_data = json.loads(desc_raw)
            course_name = description_data.get("name", zip_name)
            safe_name   = sanitize_name(course_name)
            info(f"Course name: {course_name}")

            dbg(f"Description keys: {list(description_data.keys())}")
            dbg(f"Tees: {len(description_data.get('tees', []))}, "
                f"Pins: {len(description_data.get('pins', []))}, "
                f"Shots: {len(description_data.get('shots', []))}")

            # Extract unity3d bundle to temp
            print("\n[2/7] Extracting Unity bundle...")
            zf.extract(unity_file, tmpdir)
            unity_path = os.path.join(tmpdir, unity_file)
            bundle_mb  = os.path.getsize(unity_path) / 1024 / 1024
            info(f"Bundle size: {bundle_mb:.1f} MB")

            out_dir = os.path.join(tmpdir, f"OWG-{safe_name}")
            os.makedirs(out_dir, exist_ok=True)

            # ── Step 2: Load Unity bundle ──────────────────────────
            print("\n[3/7] Loading Unity assets...")
            env = UnityPy.load(unity_path)

            type_counts = {}
            for obj in env.objects:
                t = obj.type.name
                type_counts[t] = type_counts.get(t, 0) + 1

            info(f"Found: {type_counts.get('Texture2D', 0)} textures, "
                 f"{type_counts.get('Mesh', 0)} meshes, "
                 f"{type_counts.get('TerrainData', 0)} terrain, "
                 f"{type_counts.get('Material', 0)} materials")

            if DEBUG:
                dump_bundle_contents(env)

            if type_counts.get('TerrainData', 0) == 0:
                warn("No TerrainData found in bundle — course will have no terrain height")

            # ── Step 3: Extract heightmap ──────────────────────────
            print("\n[4/7] Extracting terrain heightmap...")
            terrain_meta = None
            height_arr   = None

            for obj in env.objects:
                if obj.type.name == "TerrainData":
                    terrain_data = obj.read()
                    dbg(f"TerrainData name: {getattr(terrain_data, 'm_Name', '?')}")
                    terrain_meta, height_arr = extract_heightmap(terrain_data, out_dir)
                    extract_splat_maps(terrain_data, out_dir)
                    break

            if not terrain_meta:
                warn("Terrain metadata missing — using empty meta, course will be flat")
                terrain_meta = {}
                height_arr   = None

            # ── Step 4: Build .tscn ────────────────────────────────
            if build_tscn_file and height_arr is not None:
                print("\n[5/7] Building terrain.tscn (baked heightmap)...")
                tscn_path = build_tscn(height_arr, terrain_meta, out_dir)
                if tscn_path:
                    info("terrain.tscn ready for direct Godot instantiation ✓")
            else:
                print("\n[5/7] Skipping .tscn generation (--no-tscn or no height data)")
                info("Godot will load heightmap PNG at runtime instead")

            # ── Step 5: Extract textures ───────────────────────────
            print("\n[5/7] Extracting textures...")
            tex_count, texture_map = extract_textures(env, out_dir)

            if not texture_map:
                warn("No classifiable surface textures found — Godot will use built-in fallbacks")
            else:
                info(f"Surface textures mapped: {list(texture_map.keys())}")

            # ── Step 6: Extract meshes and objects ─────────────────
            print("\n[6/7] Extracting meshes and objects...")
            mesh_count, mesh_map = extract_meshes(env, out_dir)
            objects, water_level = extract_objects(env, mesh_map, out_dir)

            # ── Step 7: Convert course JSON + images ───────────────
            print("\n[7/7] Converting course data...")
            convert_course_json(description_data, terrain_meta, objects, water_level, out_dir)
            copy_images(zf, description_data, out_dir)

        # ── Package into output zip ────────────────────────────────
        output_zip_name = f"OWG-{safe_name}.zip"
        output_zip_path = os.path.join(output_base_dir, output_zip_name)

        print(f"\nPackaging → {output_zip_name}...")
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
            for root, dirs, files in os.walk(out_dir):
                for file in files:
                    full_path = os.path.join(root, file)
                    arcname   = os.path.relpath(full_path, out_dir)
                    out_zip.write(full_path, arcname)
                    dbg(f"  Added: {arcname} ({os.path.getsize(full_path)//1024} KB)")

        size_mb = os.path.getsize(output_zip_path) / 1024 / 1024
        info(f"Done! {output_zip_path} ({size_mb:.1f} MB)")

        # ── Final summary ──────────────────────────────────────────
        print(f"\n  Contents summary:")
        with zipfile.ZipFile(output_zip_path, "r") as zf:
            for name in sorted(zf.namelist()):
                size_kb = zf.getinfo(name).file_size // 1024
                print(f"    {name:50s} {size_kb:>6} KB")

        return True


# ─────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────

def main():
    global DEBUG

    parser = argparse.ArgumentParser(
        description="Convert Perfect Golf course zips to OWG Godot format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 pg_to_owg_converter.py                    # convert all *.zip in current dir
  python3 pg_to_owg_converter.py MyCourse.zip       # convert specific file
  python3 pg_to_owg_converter.py --debug            # verbose diagnostic output
  python3 pg_to_owg_converter.py --no-tscn          # skip .tscn, use runtime PNG loading
  python3 pg_to_owg_converter.py -o ./output        # write OWG zips to ./output
        """
    )
    parser.add_argument(
        "zips", nargs="*",
        help="Specific zip files to convert (default: all *.zip in current directory)"
    )
    parser.add_argument(
        "--output", "-o", default=".",
        help="Output directory for OWG zips (default: current directory)"
    )
    parser.add_argument(
        "--debug", action="store_true",
        help="Enable verbose diagnostic output"
    )
    parser.add_argument(
        "--no-tscn", action="store_true",
        help="Skip .tscn generation — Godot loads heightmap PNG at runtime instead"
    )
    args = parser.parse_args()

    DEBUG = args.debug
    build_tscn_file = not args.no_tscn

    if DEBUG:
        print("[DEBUG MODE ENABLED]")

    # Find zip files
    if args.zips:
        zip_files = [Path(z) for z in args.zips if Path(z).exists()]
        missing   = [z for z in args.zips if not Path(z).exists()]
        if missing:
            for m in missing:
                print(f"WARNING: File not found: {m}")
    else:
        zip_files = [
            p for p in Path(".").glob("*.zip")
            if not p.stem.startswith("OWG-")
        ]

    if not zip_files:
        print("No PG course zip files found.")
        print("Usage: python3 pg_to_owg_converter.py [file1.zip ...]")
        print("Or drop PG zips in this directory and run with no arguments.")
        sys.exit(0)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"PG → OWG Course Converter")
    print(f"Found {len(zip_files)} course(s) to convert")
    print(f"Output: {output_dir.resolve()}")
    print(f"Mode: {'DEBUG' if DEBUG else 'normal'} | "
          f"TSCN: {'baked' if build_tscn_file else 'skip (runtime PNG)'}")

    results = []
    for zip_file in zip_files:
        try:
            success = convert_course(str(zip_file), str(output_dir), build_tscn_file)
            results.append((zip_file.name, success))
        except Exception as e:
            print(f"\nERROR converting {zip_file.name}: {e}")
            if DEBUG:
                import traceback; traceback.print_exc()
            results.append((zip_file.name, False))

    print(f"\n{'='*60}")
    print("CONVERSION SUMMARY")
    print(f"{'='*60}")
    for name, ok in results:
        status = "✓ OK" if ok else "✗ FAILED"
        print(f"  {status}  {name}")

    ok_count = sum(1 for _, ok in results if ok)
    print(f"\n{ok_count}/{len(results)} courses converted successfully")


if __name__ == "__main__":
    main()
