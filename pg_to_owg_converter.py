#!/usr/bin/env python3
"""
PG to OWG Course Converter
Converts Perfect Golf .zip course files to OWG (Open World Golf) Godot format.

Usage:
    python3 pg_to_owg_converter.py [options] [file1.zip file2.zip ...]

Options:
    --output, -o    Output directory for OWG zips (default: current directory)
    --debug         Enable verbose diagnostic output
    --tscn          Build terrain.tscn (large, optional — not used by runtime loader)

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
import math
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
#  Coordinate conversion (FIXED)
#  Unity: Right-handed, Y-up, Z-forward
#  Godot: Right-handed, Y-up, -Z-forward
#  Conversion: flip X and Z axes, adjust rotations
# ─────────────────────────────────────────────

def unity_to_godot_pos(x, y, z):
    """
    Unity to Godot position conversion.
    Flip both X and Z for proper orientation in Godot.
    """
    return (-x, y, -z)


def unity_to_godot_rot(x, y, z):
    """
    Convert Unity Euler angles (degrees) to Godot Euler angles (radians).
    Unity: Yaw (Y), Pitch (X), Roll (Z)
    Godot: Yaw (Y), Pitch (X), Roll (Z) with different sign conventions.
    """
    # Convert degrees to radians
    x_rad = math.radians(x)
    y_rad = math.radians(y)
    z_rad = math.radians(z)
    
    # Adjust for coordinate system difference
    return (-x_rad, -y_rad, z_rad)


def unity_quat_to_godot(qx, qy, qz, qw):
    """
    Convert Unity quaternion to Godot quaternion with coordinate transform.
    Unity quaternion (x, y, z, w) to Godot (x, y, z, w).
    Apply coordinate transform: (x, y, z) -> (-x, y, -z)
    """
    return (-qx, qy, -qz, qw)


def sanitize_name(name):
    return "".join(c if c.isalnum() or c in "-_ " else "_" for c in name).strip().replace(" ", "-")


# ─────────────────────────────────────────────
#  Heightmap extraction (FIXED: water level baked)
# ─────────────────────────────────────────────

def extract_heightmap(terrain_data, output_dir, water_plane_y=None):
    """
    Extract Unity terrain heightmap and save as 16-bit PNG for Godot.
    Unity stores heights as unsigned shorts (0-65535).
    Water level is baked into the heightmap (subtract minimum)
    Returns meta dict or None on failure.
    """
    try:
        hm = terrain_data.m_Heightmap
        width = hm.m_Width
        height = hm.m_Height
        heights = hm.m_Heights
        scale = hm.m_Scale

        info(f"Heightmap: {width}x{height}, scale X={scale.x:.3f} Y={scale.y:.3f} Z={scale.z:.3f}")
        dbg(f"Raw heights array length: {len(heights)}, expected: {width * height}")

        if len(heights) != width * height:
            warn(f"Height array length mismatch: got {len(heights)}, expected {width * height}")

        # Convert to numpy float32 for processing
        arr = np.array(heights, dtype=np.float32).reshape(height, width)
        effective_scale_y = scale.y * 2.0

        # Normalize to 0-1 range
        norm_array = arr / 65535.0
        
        # Calculate actual heights in meters
        actual_heights = norm_array * effective_scale_y
        
        # Determine water level: use water plane if provided, otherwise heightmap minimum
        if water_plane_y is not None:
            water_level = float(water_plane_y)
            info(f"Using water plane as reference: Y={water_level:.3f}m")
            # Shift heightmap so water plane becomes 0
            shift_meters = water_level
            shift_normalized = shift_meters / effective_scale_y
            norm_array = norm_array - shift_normalized
            norm_array = np.clip(norm_array, 0.0, 1.0)
            actual_heights = norm_array * effective_scale_y
        else:
            water_level = float(actual_heights.min())
            info(f"Using heightmap minimum as water level: {water_level:.3f}m")
            # Subtract minimum to set water level to 0
            shift_normalized = norm_array.min()
            norm_array = norm_array - shift_normalized
            actual_heights = norm_array * effective_scale_y

        dbg(f"Height array stats (normalized): min={norm_array.min():.4f} max={norm_array.max():.4f} mean={norm_array.mean():.4f}")
        dbg(f"Height array stats (meters): min={actual_heights.min():.2f} max={actual_heights.max():.2f}")

        if actual_heights.max() == 0:
            warn("Heightmap is completely flat (all zeros) — terrain data may not have extracted correctly")
        else:
            info(f"Height range: {actual_heights.min():.2f} – {actual_heights.max():.2f} meters")

        # Correct orientation (verified to 0m error against all 18 tee positions):
        # transpose rows/cols then flip both axes
        norm_array = norm_array.T
        norm_array = np.flipud(norm_array)
        norm_array = np.fliplr(norm_array)

        # Convert back to uint16 for PNG (0-65535 range)
        uint16_arr = (norm_array * 65535).clip(0, 65535).astype(np.uint16)

        # Save as 16-bit PNG
        terrain_dir = os.path.join(output_dir, "terrain")
        os.makedirs(terrain_dir, exist_ok=True)
        heightmap_path = os.path.join(terrain_dir, "heightmap.png")

        img = Image.fromarray(uint16_arr, mode='I;16')
        img.save(heightmap_path)

        info(f"Heightmap saved: {width}x{height} 16-bit PNG ✓")

        terrain_size_x = width * scale.x
        terrain_size_z = height * scale.z
        real_height_range = float(actual_heights.max() - actual_heights.min())

        info(f"Terrain world size: {terrain_size_x:.1f} x {terrain_size_z:.1f} units")
        info(f"Height range (adjusted): 0 – {real_height_range:.2f} m")

        # Store the adjusted heights array for .tscn generation
        adjusted_heights = (norm_array * effective_scale_y).flatten()

        meta = {
            "width": width,
            "height": height,
            "scale_x": scale.x,
            "scale_y": effective_scale_y,
            "scale_z": scale.z,
            "terrain_size_x": terrain_size_x,
            "terrain_size_z": terrain_size_z,
            "water_level": round(water_level, 4),
            "height_min_m": round(float(actual_heights.min()), 4),
            "height_max_m": round(float(actual_heights.max()), 4),
            "height_range_m": round(real_height_range, 4),
        }

        meta_path = os.path.join(terrain_dir, "terrain_meta.json")
        with open(meta_path, "w") as f:
            json.dump(meta, f, indent=2)
        dbg(f"terrain_meta.json written")

        # Also write terrain_heights.json for TerrainGenerator (new script)
        # Heights are normalized 0..1 in the correct Godot orientation
        heights_json = {
            "name": "Terrain",
            "position": [0.0, 0.0, 0.0],
            "size": [terrain_size_x, effective_scale_y, terrain_size_z],
            "heightmapWidth": width,
            "heightmapHeight": height,
            "heightsAreNormalized": True,
            "heights": norm_array.flatten().tolist(),
        }
        heights_path = os.path.join(terrain_dir, "terrain_heights.json")
        with open(heights_path, "w") as f:
            json.dump(heights_json, f)
        info(f"terrain_heights.json written ({width}x{height} heights) ✓")

        return meta, uint16_arr, adjusted_heights

    except AttributeError as e:
        err(f"TerrainData missing expected attribute: {e}")
        dbg(f"Available attributes: {[a for a in dir(terrain_data) if not a.startswith('__')]}")
        return None, None, None
    except Exception as e:
        err(f"Heightmap extraction failed: {e}")
        if DEBUG:
            import traceback; traceback.print_exc()
        return None, None, None


# ─────────────────────────────────────────────
#  Godot .tscn generation with proper materials (FIXED)
# ─────────────────────────────────────────────

def build_tscn(height_uint16, adjusted_heights, meta, output_dir, splat_layers=None, texture_map=None, course_safe_name="course"):
    """
    Build a Godot 4 .tscn with:
      - StaticBody3D (root)
        - CollisionShape3D (HeightMapShape3D — full resolution)
        - MeshInstance3D (ArrayMesh — downsampled visual with real vertex heights)
    FIXED: Added proper material support with splatmaps and shader
    """
    info("Building terrain .tscn with baked heightmap and materials...")

    width = meta["width"]
    height_n = meta["height"]
    scale_x = meta["scale_x"]
    scale_y = meta["scale_y"]
    scale_z = meta["scale_z"]
    size_x = meta["terrain_size_x"]
    size_z = meta["terrain_size_z"]

    # Use adjusted heights for collision (water level already baked)
    shape_heights = adjusted_heights

    # ── Collision shape (full resolution) ──────────────────────────
    CHUNK = 16
    float_strs = [f"{v:.4f}" for v in shape_heights]
    lines = []
    for i in range(0, len(float_strs), CHUNK):
        lines.append(", ".join(float_strs[i:i+CHUNK]))
    packed_data = ",\n".join(lines)
    info(f"Packed {len(shape_heights)} height values for HeightMapShape3D")

    # ── Visual mesh (downsampled to MESH_RES x MESH_RES) ───────────
    MESH_RES = 256
    step_r = max(1, (height_n - 1) // (MESH_RES - 1))
    step_c = max(1, (width - 1) // (MESH_RES - 1))
    rows = list(range(0, height_n, step_r))
    cols = list(range(0, width, step_c))
    if rows[-1] != height_n - 1:
        rows.append(height_n - 1)
    if cols[-1] != width - 1:
        cols.append(width - 1)
    mr = len(rows)
    mc = len(cols)

    # Reconstruct 2D height array from adjusted_heights
    h2d = np.array(adjusted_heights).reshape(height_n, width)

    # Build vertex list with corrected coordinate transform
    verts = []
    normals = []
    uvs = []

    for ri, r in enumerate(rows):
        for ci, c in enumerate(cols):
            # Center mesh at origin — X and Z centered, Y at actual height
            wx = (c - width/2) * scale_x
            wy = float(h2d[r, c])
            wz = (r - height_n/2) * scale_z
            verts.append((wx, wy, wz))
            uvs.append((c / width, r / height_n))

            # Finite-difference normal
            def hs(rr, cc):
                rr = max(0, min(height_n-1, rr))
                cc = max(0, min(width-1, cc))
                return float(h2d[rr, cc])
            dx = hs(r, c+1) - hs(r, c-1)
            dz = hs(r+1, c) - hs(r-1, c)
            nx, ny, nz = dx, 2.0 * scale_x, -dz
            length = (nx*nx + ny*ny + nz*nz) ** 0.5 or 1.0
            normals.append((nx/length, ny/length, nz/length))

    # Build index list
    indices = []
    for ri in range(mr - 1):
        for ci in range(mc - 1):
            i00 = ri * mc + ci
            i10 = i00 + 1
            i01 = i00 + mc
            i11 = i01 + 1
            indices += [i00, i01, i10, i10, i01, i11]

    info(f"Visual mesh: {mr}x{mc} = {len(verts)} verts, {len(indices)//3} tris")

    # Pack arrays
    def pack_v3(arr):
        parts = [f"{x:.4f}, {y:.4f}, {z:.4f}" for x, y, z in arr]
        return "PackedVector3Array(" + ", ".join(parts) + ")"

    def pack_v2(arr):
        parts = [f"{u:.5f}, {v:.5f}" for u, v in arr]
        return "PackedVector2Array(" + ", ".join(parts) + ")"

    def pack_i32(arr):
        CHUNK = 24
        rows_out = []
        for i in range(0, len(arr), CHUNK):
            rows_out.append(", ".join(str(x) for x in arr[i:i+CHUNK]))
        return "PackedInt32Array(" + ",\n".join(rows_out) + ")"

    verts_str = pack_v3(verts)
    normals_str = pack_v3(normals)
    uvs_str = pack_v2(uvs)
    idx_str = pack_i32(indices)

    # ── Build proper material with shader (FIXED) ──────────────────
    material_resources = []
    material_lines = []
    shader_lines = []
    
    # Check if we have splat layers
    has_splats = splat_layers and len(splat_layers) > 0
    
    if has_splats:
        # Create shader
        shader_lines.append('[sub_resource type="Shader" id="Shader_terrain"]')
        shader_lines.append('code = """')
        shader_lines.append('shader_type spatial;')
        shader_lines.append('')
        shader_lines.append('uniform sampler2D albedo_0;')
        shader_lines.append('uniform sampler2D albedo_1;')
        shader_lines.append('uniform sampler2D albedo_2;')
        shader_lines.append('uniform sampler2D albedo_3;')
        shader_lines.append('uniform sampler2D splatmap;')
        shader_lines.append('uniform float uv_scale = 4.0;')
        shader_lines.append('')
        shader_lines.append('void fragment() {')
        shader_lines.append('    vec4 splat = texture(splatmap, UV);')
        shader_lines.append('    vec4 color = vec4(0.0);')
        shader_lines.append('    color += texture(albedo_0, UV * uv_scale) * splat.r;')
        shader_lines.append('    color += texture(albedo_1, UV * uv_scale) * splat.g;')
        shader_lines.append('    color += texture(albedo_2, UV * uv_scale) * splat.b;')
        shader_lines.append('    color += texture(albedo_3, UV * uv_scale) * splat.a;')
        shader_lines.append('    ALBEDO = color.rgb;')
        shader_lines.append('    ROUGHNESS = 0.8;')
        shader_lines.append('    METALLIC = 0.0;')
        shader_lines.append('}')
        shader_lines.append('"""')
        shader_lines.append('')
        
        material_resources.extend(shader_lines)
        
        # Create shader material
        material_lines.append('[sub_resource type="ShaderMaterial" id="ShaderMaterial_terrain"]')
        material_lines.append('shader = SubResource("Shader_terrain")')
        
        # Add texture parameters from extracted textures
        tex_added = 0
        for i, layer in enumerate(splat_layers[:4]):  # Max 4 layers
            tex_name = layer.get("texture_name", f"layer_{i}")
            tex_path = os.path.join("textures", f"{tex_name}.png")
            if os.path.exists(os.path.join(output_dir, tex_path)):
                res_path = f"res://courses/OWG-{course_safe_name}/textures/{tex_name}.png"
                material_lines.append(f'shader_parameter/albedo_{i} = load("{res_path}")')
                tex_added += 1
        
        # Add splatmap if available
        splatmap_path = None
        for i in range(len(splat_layers)):
            test_path = os.path.join("terrain", "splat", f"alphamap_{i}.png")
            if os.path.exists(os.path.join(output_dir, test_path)):
                splatmap_path = test_path
                break
        
        if splatmap_path:
            res_splat = f"res://courses/OWG-{course_safe_name}/terrain/splat/alphamap_0.png"
            material_lines.append(f'shader_parameter/splatmap = load("{res_splat}")')
        
        # If no textures found, use fallback
        if tex_added == 0:
            warn("No textures found for splat layers, using fallback material")
            has_splats = False
    
    if not has_splats:
        # Fallback standard material
        material_lines.append('[sub_resource type="StandardMaterial3D" id="StandardMaterial_terrain"]')
        material_lines.append('albedo_color = Color(0.3, 0.5, 0.2, 1.0)')
        material_lines.append('roughness = 0.8')
        material_lines.append('metallic = 0.0')
        material_lines.append('uv1_scale = Vector3(4.0, 4.0, 1.0)')
    
    material_str = "\n".join(material_lines)
    material_resources_str = "\n".join(material_resources)
    
    # Select material reference
    material_ref = 'SubResource("ShaderMaterial_terrain")' if has_splats else 'SubResource("StandardMaterial_terrain")'
    
    # Build complete TSCN with proper transforms (FIXED)
    tscn = f"""[gd_scene load_steps={3 + len(material_resources)} format=3 uid="uid://owg_terrain"]

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
{material_resources_str}
{material_str}

[node name="OWGTerrain" type="StaticBody3D"]
metadata/owg_terrain = true
metadata/terrain_size_x = {size_x:.3f}
metadata/terrain_size_z = {size_z:.3f}
metadata/scale_y = {scale_y:.3f}
metadata/scale_x = {scale_x:.4f}
metadata/scale_z = {scale_z:.4f}
metadata/water_level = {meta["water_level"]:.4f}

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("HeightMapShape3D_1")
transform = Transform3D({scale_x:.4f}, 0, 0, 0, 1, 0, 0, 0, {scale_z:.4f}, {-(width/2)*scale_x:.4f}, 0, {-(height_n/2)*scale_z:.4f})

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("ArrayMesh_1")
material_override = {material_ref}
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
#  Splat / surface texture extraction (FIXED)
# ─────────────────────────────────────────────

SURFACE_PATTERNS = {
    "fairway":   ["o_fairwayplain", "fairwayplain", "fairwaycross", "o_fairway",
                  "skygrass_fair", "fairway2", "fairway1", "fairway", "fair",
                  "base_fairway"],
    "rough":     ["terrainrough", "meshlightrough", "o_rough2desat", "o_rough",
                  "rough2", "rough1", "rough", "deep_rough", "deeprough",
                  "heavyrough", "grass_dry", "grass_light"],
    "deep_rough": ["deeprough", "deep_rough", "heavyrough"],
    "bunker":    ["bunkersandoverhead", "bunkersandrake", "bunkerdirt",
                  "bunker", "sand", "trap"],
    "green":     ["pickupgreen", "skygrass_green", "o_greenfringe", "greenfringe",
                  "green", "putting"],
    "fringe":    ["fringe", "collar", "apron"],
    "water":     ["water", "pond", "lake"],
    "path":      ["gravelpathplain", "gravelpath", "gravel", "cartpath",
                  "woodchips", "path", "cart", "road"],
    "tee":       ["tee_box", "teebox", "tee"],
}

def classify_texture(name):
    lower = name.lower()
    for surface, patterns in SURFACE_PATTERNS.items():
        for p in patterns:
            if p in lower:
                return surface
    return "unknown"


def extract_splat_maps(terrain_data, output_dir):
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
                # Apply the same orientation correction used for the heightmap
                # (T + flipud + fliplr) so the splatmap UV matches the heightmap UV.
                mode = img.mode
                arr = np.array(img)
                if arr.ndim == 3:
                    arr = arr.transpose(1, 0, 2)
                    arr = np.flipud(arr)
                    arr = np.fliplr(arr)
                else:
                    arr = arr.T
                    arr = np.flipud(arr)
                    arr = np.fliplr(arr)
                img = Image.fromarray(arr.astype(np.uint8), mode=mode)

                out_path = os.path.join(splat_dir, f"alphamap_{i}.png")
                img.save(out_path)
                alpha_count += 1
                dbg(f"Alphamap {i}: {img.size} {img.mode}")
        except Exception as e:
            warn(f"Could not extract alphamap {i}: {e}")

    info(f"Extracted {alpha_count} alphamap(s)")

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
            layer["surface_type"] = classify_texture(tex.m_Name)
            dbg(f"Splat layer {i}: '{tex.m_Name}' → {layer['surface_type']}")
        except Exception:
            layer["texture_name"] = f"layer_{i}"
            layer["surface_type"] = "unknown"
        layers.append(layer)

    info(f"Splat layers: {len(layers)} ({sum(1 for l in layers if l['surface_type'] != 'unknown')} classified)")

    layers_path = os.path.join(splat_dir, "splat_layers.json")
    with open(layers_path, "w") as f:
        json.dump(layers, f, indent=2)

    return layers


# ─────────────────────────────────────────────
#  Texture extraction (FIXED paths)
# ─────────────────────────────────────────────

def extract_textures(env, output_dir):
    tex_dir = os.path.join(output_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)

    extracted = 0
    skipped = 0
    texture_map = {}

    for obj in env.objects:
        if obj.type.name != "Texture2D":
            continue
        try:
            data = obj.read()
            img = data.image
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
                texture_map[surface] = f"{safe_name}.png"

        except Exception as ex:
            skipped += 1
            dbg(f"Skipped texture: {ex}")

    info(f"Textures: {extracted} extracted, {skipped} skipped")
    info(f"Classified: {list(texture_map.keys())}")

    map_path = os.path.join(tex_dir, "texture_map.json")
    with open(map_path, "w") as f:
        json.dump(texture_map, f, indent=2)

    return extracted, texture_map


# ─────────────────────────────────────────────
#  Mesh extraction
# ─────────────────────────────────────────────

def extract_meshes(env, output_dir):
    mesh_dir = os.path.join(output_dir, "meshes")
    os.makedirs(mesh_dir, exist_ok=True)

    extracted = 0
    mesh_map = {}

    for obj in env.objects:
        if obj.type.name != "Mesh":
            continue
        try:
            data = obj.read()
            obj_data = data.export()
            if not obj_data:
                continue
            
            safe_name = sanitize_name(data.m_Name)
            if not safe_name:
                safe_name = f"Mesh_{obj.path_id}"
            
            fname = f"{safe_name}.obj"
            fpath = os.path.join(mesh_dir, fname)
            
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
#  Transform hierarchy helpers (FIXED quaternion conversion)
# ─────────────────────────────────────────────

def _quat_rotate(qx, qy, qz, qw, vx, vy, vz):
    cx = qy*vz - qz*vy
    cy = qz*vx - qx*vz
    cz = qx*vy - qy*vx
    dx = qy*cz - qz*cy
    dy = qz*cx - qx*cz
    dz = qx*cy - qy*cx
    return (vx + 2.0*qw*cx + 2.0*dx,
            vy + 2.0*qw*cy + 2.0*dy,
            vz + 2.0*qw*cz + 2.0*dz)


def _quat_mul(ax, ay, az, aw, bx, by, bz, bw):
    return (aw*bx + ax*bw + ay*bz - az*by,
            aw*by - ax*bz + ay*bw + az*bx,
            aw*bz + ax*by - ay*bx + az*bw,
            aw*bw - ax*bx - ay*by - az*bz)


# ─────────────────────────────────────────────
#  Object placement extraction (FIXED coordinates)
# ─────────────────────────────────────────────

def extract_objects(env, mesh_map, output_dir):
    info("Extracting object placements...")

    transform_map = {}
    for obj in env.objects:
        if obj.type.name == "Transform":
            try:
                transform_map[obj.path_id] = obj.read()
            except Exception:
                pass
    if DEBUG:
        dbg(f"Transform map: {len(transform_map)} entries")

    def _world_trs(transform):
        chain = []
        current = transform
        visited = set()
        while current is not None:
            tid = id(current)
            if tid in visited:
                break
            visited.add(tid)
            chain.append(current)
            father = getattr(current, "m_Father", None)
            if father is None:
                break
            try:
                pid = getattr(father, "path_id", 0)
                if pid == 0 or pid not in transform_map:
                    break
                current = transform_map[pid]
            except Exception:
                break

        wx, wy, wz = 0.0, 0.0, 0.0
        wrx, wry, wrz, wrw = 0.0, 0.0, 0.0, 1.0
        wsx, wsy, wsz = 1.0, 1.0, 1.0

        for t in reversed(chain):
            lp = t.m_LocalPosition
            lr = t.m_LocalRotation
            ls = t.m_LocalScale
            slx, sly, slz = lp.x * wsx, lp.y * wsy, lp.z * wsz
            rx, ry, rz = _quat_rotate(wrx, wry, wrz, wrw, slx, sly, slz)
            wx += rx
            wy += ry
            wz += rz
            wrx, wry, wrz, wrw = _quat_mul(wrx, wry, wrz, wrw, lr.x, lr.y, lr.z, lr.w)
            wsx *= ls.x
            wsy *= ls.y
            wsz *= ls.z

        return wx, wy, wz, (wrx, wry, wrz, wrw), (wsx, wsy, wsz)

    def _resolve_components(data):
        components = getattr(data, "m_Component", []) or getattr(data, "m_Components", [])
        mesh_filter = transform = None
        for c in components:
            c_ptr = None
            if isinstance(c, tuple):
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
            if not c_ptr:
                continue
            try:
                c_obj = c_ptr.read()
                ctype = type(c_obj).__name__
                if ctype == "MeshFilter":
                    mesh_filter = c_obj
                elif ctype == "Transform":
                    transform = c_obj
            except Exception:
                continue
        return transform, mesh_filter

    objects = []
    water_level = None

    for obj in env.objects:
        if obj.type.name != "GameObject":
            continue
        try:
            data = obj.read()
            name = getattr(data, "m_Name", f"GO_{obj.path_id}")
            transform, mesh_filter = _resolve_components(data)

            # Record water plane but don't skip it (we need its Y)
            if "pp_waterplane" in name.lower() and transform:
                _, wy, _, _, _ = _world_trs(transform)
                water_level = float(wy)
                info(f"Found water plane at Y={water_level:.3f}m")

            if not mesh_filter or not transform:
                continue

            mesh_ptr = getattr(mesh_filter, "m_Mesh", None)
            if not mesh_ptr:
                continue
            mesh_path = mesh_map.get(mesh_ptr.path_id)
            if not mesh_path:
                continue

            wx, wy, wz, (qx, qy, qz, qw), (sx, sy, sz) = _world_trs(transform)

            # Skip prefab templates at origin
            if wx == 0.0 and wy == 0.0 and wz == 0.0:
                continue

            # Apply Unity to Godot coordinate transform
            gx, gy, gz = unity_to_godot_pos(wx, wy, wz)
            gqx, gqy, gqz, gqw = unity_quat_to_godot(qx, qy, qz, qw)
            
            objects.append({
                "name": name,
                "mesh": mesh_path,
                "position": {"x": gx, "y": gy, "z": gz},
                "rotation": {"x": gqx, "y": gqy, "z": gqz, "w": gqw},
                "scale": {"x": sx, "y": sy, "z": sz},
            })

        except Exception as ex:
            dbg(f"Skipped object {obj.path_id}: {ex}")

    info(f"Objects: {len(objects)} placements found")
    return objects, water_level


# ─────────────────────────────────────────────
#  Course JSON conversion (FIXED water level handling)
# ─────────────────────────────────────────────

def convert_course_json(description_data, terrain_meta, objects, water_level, output_dir):
    """Convert PG course description JSON to OWG format."""
    info("Converting course metadata...")

    def convert_pos(pos_dict, apply_water_offset=True):
        x, y, z = pos_dict["x"], pos_dict["y"], pos_dict["z"]
        gx, gy, gz = unity_to_godot_pos(x, y, z)
        # Subtract water level so Y=0 in game = water plane in Unity
        # Terrain heightmap is already shifted by this same amount
        if apply_water_offset and water_level is not None:
            gy -= water_level
        return {"x": gx, "y": gy, "z": gz}

    holes = {}

    for tee in description_data.get("tees", []):
        idx = tee["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["tees"].append({
            "type": tee["type"],
            "par": tee["par"].replace("_", ""),
            "stroke_index": tee["strokeIndex"],
            "position": convert_pos(tee["position"], True),
            "order": tee["orderIndex"],
        })

    for pin in description_data.get("pins", []):
        idx = pin["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["pins"].append({
            "difficulty": pin["difficulty"],
            "position": convert_pos(pin["position"], True),
            "order": pin["orderIndex"],
        })

    for shot in description_data.get("shots", []):
        idx = shot["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["shots"].append({
            "position": convert_pos(shot["position"], True),
            "order": shot["orderIndex"],
        })

    holes_list = []
    for i in sorted(holes.keys()):
        h = holes[i]
        h["hole_number"] = i + 1
        h["tees"] = sorted(h["tees"], key=lambda t: t["order"])
        h["pins"] = sorted(h["pins"], key=lambda p: p["order"])
        h["shots"] = sorted(h["shots"], key=lambda s: s["order"])
        holes_list.append(h)

    dbg(f"Converted {len(holes_list)} holes")

    owg_course = {
        "format": "OWG-1.0",
        "name": description_data.get("name", "Unknown Course"),
        "author": description_data.get("author", "Unknown"),
        "author_version": description_data.get("authorVersion", "1.0"),
        "platform_original": "Unity/PerfectGolf",
        "converted_by": "pg_to_owg_converter v3",
        "coordinate_system": "Godot (right-handed Y-up, X/Z flipped from Unity)",
        "geo": {
            "x": description_data.get("geoX", 0),
            "y": description_data.get("geoY", 0),
            "z": description_data.get("geoZ", 0),
            "utm_zone": description_data.get("utmZone", 0),
        },
        "terrain": terrain_meta or {},
        "holes": holes_list,
        "hole_count": len(holes_list),
        "splash_image": description_data.get("splashName", ""),
        "flag_image": description_data.get("flagName", ""),
        "offset": description_data.get("offset", 0),
        "objects": objects,
        "water_plane_y": water_level
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
#  Diagnostics
# ─────────────────────────────────────────────

def dump_bundle_contents(env):
    print("\n  [DEBUG] Bundle contents:")
    type_map = {}
    for obj in env.objects:
        t = obj.type.name
        type_map.setdefault(t, []).append(getattr(obj.read(), 'm_Name', '?'))
    for t, names in sorted(type_map.items(), key=lambda x: -len(x[1])):
        if len(names) <= 5:
            print(f"    {t} ({len(names)}): {', '.join(names)}")
        else:
            print(f"    {t} ({len(names)}): {', '.join(names[:5])} ...")


# ─────────────────────────────────────────────
#  Main conversion
# ─────────────────────────────────────────────

def convert_course(zip_path, output_base_dir, build_tscn_file=False):
    zip_name = Path(zip_path).stem
    print(f"\n{'='*60}")
    print(f"Converting: {zip_name}")
    print(f"{'='*60}")

    with tempfile.TemporaryDirectory() as tmpdir:
        work_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(work_dir)

        print("\n[1/7] Reading zip contents...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()
            desc_file = next((n for n in names if n.endswith(".description")), None)
            unity_file = next((n for n in names if n.endswith(".unity3d")), None)

            if not desc_file or not unity_file:
                err("Missing .description or .unity3d file")
                return False

            info(f"Description: {desc_file}")
            info(f"Unity bundle: {unity_file}")

            desc_raw = zf.read(desc_file).decode("utf-8")
            description_data = json.loads(desc_raw)
            course_name = description_data.get("name", zip_name)
            safe_name = sanitize_name(course_name)

            zf.extract(unity_file, tmpdir)
            unity_path = os.path.join(tmpdir, unity_file)

            out_dir = os.path.join(tmpdir, f"OWG-{safe_name}")
            os.makedirs(out_dir, exist_ok=True)

            print("\n[2/7] Loading Unity assets...")
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

            print("\n[3/7] Extracting objects and water plane...")
            tex_count, texture_map = extract_textures(env, out_dir)
            mesh_count, mesh_map = extract_meshes(env, out_dir)
            objects, water_plane_y = extract_objects(env, mesh_map, out_dir)

            print("\n[4/7] Extracting terrain...")
            terrain_meta = None
            height_uint16 = None
            adjusted_heights = None
            splat_layers = []

            for obj in env.objects:
                if obj.type.name == "TerrainData":
                    terrain_data = obj.read()
                    terrain_meta, height_uint16, adjusted_heights = extract_heightmap(
                        terrain_data, out_dir, water_plane_y
                    )
                    splat_layers = extract_splat_maps(terrain_data, out_dir)
                    break

            if not terrain_meta:
                warn("No terrain found - course will be flat")
                terrain_meta = {}

            if build_tscn_file and adjusted_heights is not None:
                print("\n[5/6] Building terrain.tscn (optional)...")
                build_tscn(height_uint16, adjusted_heights, terrain_meta, out_dir, splat_layers, texture_map, safe_name)

            convert_course_json(description_data, terrain_meta, objects, water_plane_y, out_dir)
            copy_images(zf, description_data, out_dir)

        output_zip_name = f"OWG-{safe_name}.zip"
        output_zip_path = os.path.join(output_base_dir, output_zip_name)

        step = "6/6" if build_tscn_file else "5/5"
        print(f"\n[{step}] Packaging → {output_zip_name}...")
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
            for root, dirs, files in os.walk(out_dir):
                for file in files:
                    full_path = os.path.join(root, file)
                    arcname = os.path.relpath(full_path, out_dir)
                    out_zip.write(full_path, arcname)

        size_mb = os.path.getsize(output_zip_path) / 1024 / 1024
        info(f"Done! {output_zip_path} ({size_mb:.1f} MB)")
        return True


# ─────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────

def main():
    global DEBUG

    parser = argparse.ArgumentParser(description="Convert Perfect Golf course zips to OWG Godot format")
    parser.add_argument("zips", nargs="*", help="Specific zip files to convert")
    parser.add_argument("--output", "-o", default=".", help="Output directory for OWG zips")
    parser.add_argument("--debug", action="store_true", help="Enable verbose diagnostic output")
    parser.add_argument("--tscn", action="store_true", help="Build terrain.tscn (large file, not used by runtime loader)")
    args = parser.parse_args()

    DEBUG = args.debug
    build_tscn_file = args.tscn

    if args.zips:
        zip_files = [Path(z) for z in args.zips if Path(z).exists()]
    else:
        zip_files = [p for p in Path(".").glob("*.zip") if not p.stem.startswith("OWG-")]

    if not zip_files:
        print("No PG course zip files found.")
        return

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"PG → OWG Course Converter v3 (FIXED)")
    print(f"Found {len(zip_files)} course(s)")
    print(f"Output: {output_dir.resolve()}")

    results = []
    for zip_file in zip_files:
        try:
            success = convert_course(str(zip_file), str(output_dir), build_tscn_file)
            results.append((zip_file.name, success))
        except Exception as e:
            print(f"\nERROR: {e}")
            if DEBUG:
                import traceback
                traceback.print_exc()
            results.append((zip_file.name, False))

    print(f"\n{'='*60}")
    print("SUMMARY")
    for name, ok in results:
        print(f"  {'✓' if ok else '✗'} {name}")
    print(f"\n{sum(1 for _, ok in results if ok)}/{len(results)} successful")


if __name__ == "__main__":
    main()
