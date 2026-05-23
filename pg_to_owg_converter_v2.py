#!/usr/bin/env python3
"""
PG to OWG Course Converter
Converts Perfect Golf .zip course files to OWG (Solo Golf) Godot format.

Usage:
    1. Place this script in a directory
    2. Drop one or more PG course .zip files in the same directory
    3. Run: python3 pg_to_owg_converter.py
    4. Output: OWG-<CourseName>.zip files ready to drop into your Godot project

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
#  Coordinate conversion
#  Unity: Left-handed, Y-up
#  Godot: Right-handed, Y-up
#  Conversion: flip X axis (x = -x)
# ─────────────────────────────────────────────

def unity_to_godot_pos(x, y, z):
    """Keep Unity coordinates — both Unity and Godot are Y-up, X-flip causes misalignment."""
    return (x, y, z)


def sanitize_name(name):
    """Convert course name to safe filename."""
    return "".join(c if c.isalnum() or c in "-_ " else "_" for c in name).strip().replace(" ", "-")


# ─────────────────────────────────────────────
#  Heightmap extraction
# ─────────────────────────────────────────────

def extract_heightmap(terrain_data, output_dir):
    """
    Extract Unity terrain heightmap and save as 16-bit PNG for Godot.
    Unity stores heights as unsigned shorts (0-65535).
    """
    hm = terrain_data.m_Heightmap
    width = hm.m_Width    # 2049
    height = hm.m_Height  # 2049
    heights = hm.m_Heights
    scale = hm.m_Scale    # Vector3f - x/z = terrain size per unit, y = height scale

    print(f"  Heightmap: {width}x{height}, scale Y={scale.y:.3f}")

    # Convert to numpy array
    arr = np.array(heights, dtype=np.uint16).reshape(height, width)

    # Unity heightmap is stored bottom-to-top, flip vertically for Godot
    arr = np.flipud(arr)

    # Save as 16-bit PNG
    img = Image.fromarray(arr, mode='I;16')
    heightmap_path = os.path.join(output_dir, "terrain", "heightmap.png")
    os.makedirs(os.path.dirname(heightmap_path), exist_ok=True)
    img.save(heightmap_path)

    # Save terrain metadata for Godot's TerrainGenerator
    meta = {
        "width": width,
        "height": height,
        "scale_x": scale.x,
        "scale_y": scale.y,
        "scale_z": scale.z,
        "terrain_size_x": width * scale.x,
        "terrain_size_z": height * scale.z,
    }
    meta_path = os.path.join(output_dir, "terrain", "terrain_meta.json")
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2)

    print(f"  Terrain world size: {meta['terrain_size_x']:.1f} x {meta['terrain_size_z']:.1f} units")

    # Also output terrain_heights.json for TerrainGeneratorNew
    # Heights in actual world Y metres, position at [0,0,0]
    # Player spawns at Unity world coords from course.json tee positions
    norm = np.array(heights, dtype=np.float32) / 65535.0
    flipped = np.flipud(norm.reshape(height, width))
    world_heights = (flipped * scale.y).flatten().tolist()
    heights_json = {
        "name": "Terrain",
        "position": [0.0, 0.0, 0.0],
        "size": [meta["terrain_size_x"], scale.y, meta["terrain_size_z"]],
        "heightmapWidth": width,
        "heightmapHeight": height,
        "heightsAreNormalized": False,
        "heights": world_heights,
    }
    heights_path = os.path.join(output_dir, "terrain", "terrain_heights.json")
    with open(heights_path, "w") as f:
        json.dump(heights_json, f)
    print(f"  terrain_heights.json written ✓")

    return meta


# ─────────────────────────────────────────────
#  Splat / surface texture extraction
# ─────────────────────────────────────────────

def extract_splat_maps(terrain_data, output_dir):
    """
    Extract terrain surface blend maps (alphamaps).
    These define where fairway/rough/sand/etc appear on the terrain.
    """
    splat_db = terrain_data.m_SplatDatabase
    splat_dir = os.path.join(output_dir, "terrain", "splat")
    os.makedirs(splat_dir, exist_ok=True)

    # Extract alpha blend textures
    alpha_count = 0
    for i, alpha_tex_ptr in enumerate(splat_db.m_AlphaTextures):
        try:
            tex_obj = alpha_tex_ptr.read()
            img = tex_obj.image
            if img:
                # Flip vertically to match heightmap orientation (Unity bottom-to-top)
                img = Image.fromarray(np.flipud(np.array(img)))
                out_path = os.path.join(splat_dir, f"alphamap_{i}.png")
                img.save(out_path)
                alpha_count += 1
        except Exception as e:
            print(f"  Warning: Could not extract alphamap {i}: {e}")

    print(f"  Extracted {alpha_count} alphamap(s)")

    # Save splat layer info (which texture goes on which layer)
    layers = []
    for i, splat in enumerate(splat_db.m_Splats):
        layer = {
            "index": i,
            "tile_size_x": splat.tileSize.x if hasattr(splat.tileSize, 'x') else 15,
            "tile_size_y": splat.tileSize.y if hasattr(splat.tileSize, 'y') else 15,
        }
        # Try to get texture name
        try:
            tex = splat.texture.read()
            layer["texture_name"] = tex.m_Name
        except Exception:
            layer["texture_name"] = f"layer_{i}"
        layers.append(layer)

    layers_path = os.path.join(splat_dir, "splat_layers.json")
    with open(layers_path, "w") as f:
        json.dump(layers, f, indent=2)

    print(f"  Splat layers: {len(layers)}")
    return layers


# ─────────────────────────────────────────────
#  Texture extraction
# ─────────────────────────────────────────────

def extract_textures(env, output_dir):
    """Extract all Texture2D assets from the bundle."""
    tex_dir = os.path.join(output_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)

    extracted = 0
    skipped = 0
    for obj in env.objects:
        if obj.type.name == "Texture2D":
            try:
                data = obj.read()
                img = data.image
                if img:
                    safe_name = "".join(
                        c if c.isalnum() or c in "-_." else "_"
                        for c in data.m_Name
                    )
                    out_path = os.path.join(tex_dir, f"{safe_name}.png")
                    img.save(out_path)
                    extracted += 1
            except Exception:
                skipped += 1

    print(f"  Textures: {extracted} extracted, {skipped} skipped")
    return extracted


# ─────────────────────────────────────────────
#  Course JSON data conversion
# ─────────────────────────────────────────────

def convert_course_json(description_data, terrain_meta, output_dir):
    """
    Convert PG course description JSON to OWG format.
    Flips X coordinates from Unity (left-handed) to Godot (right-handed).
    """

    def convert_pos(pos_dict):
        x, y, z = pos_dict["x"], pos_dict["y"], pos_dict["z"]
        gx, gy, gz = unity_to_godot_pos(x, y, z)
        return {"x": gx, "y": gy, "z": gz}

    # Build holes data - group tees and pins by holeIndex
    holes = {}

    for tee in description_data.get("tees", []):
        idx = tee["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["tees"].append({
            "type": tee["type"],
            "par": tee["par"].replace("_", ""),
            "stroke_index": tee["strokeIndex"],
            "position": convert_pos(tee["position"]),
            "order": tee["orderIndex"],
        })

    for pin in description_data.get("pins", []):
        idx = pin["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["pins"].append({
            "difficulty": pin["difficulty"],
            "position": convert_pos(pin["position"]),
            "order": pin["orderIndex"],
        })

    for shot in description_data.get("shots", []):
        idx = shot["holeIndex"]
        if idx not in holes:
            holes[idx] = {"tees": [], "pins": [], "shots": []}
        holes[idx]["shots"].append({
            "position": convert_pos(shot["position"]),
            "order": shot["orderIndex"],
        })

    # Sort holes by index
    holes_list = []
    for i in sorted(holes.keys()):
        h = holes[i]
        h["hole_number"] = i + 1
        # Sort tees/pins by order
        h["tees"] = sorted(h["tees"], key=lambda t: t["order"])
        h["pins"] = sorted(h["pins"], key=lambda p: p["order"])
        holes_list.append(h)

    # Build OWG course format
    owg_course = {
        "format": "OWG-1.0",
        "name": description_data.get("name", "Unknown Course"),
        "author": description_data.get("author", "Unknown"),
        "author_version": description_data.get("authorVersion", "1.0"),
        "platform_original": description_data.get("platform", "Unity"),
        "converted_by": "pg_to_owg_converter",
        "coordinate_system": "Godot (right-handed Y-up, X flipped from Unity)",
        "geo": {
            "x": description_data.get("geoX", 0),
            "y": description_data.get("geoY", 0),
            "z": description_data.get("geoZ", 0),
            "utm_zone": description_data.get("utmZone", 0),
        },
        "terrain": terrain_meta,
        "holes": holes_list,
        "hole_count": len(holes_list),
        "splash_image": description_data.get("splashName", ""),
        "flag_image": description_data.get("flagName", ""),
        "offset": description_data.get("offset", 0),
    }

    course_json_path = os.path.join(output_dir, "course.json")
    with open(course_json_path, "w") as f:
        json.dump(owg_course, f, indent=2)

    print(f"  Course JSON: {len(holes_list)} holes converted")
    return owg_course


# ─────────────────────────────────────────────
#  Copy splash/flag images
# ─────────────────────────────────────────────

def copy_images(zip_ref, description_data, output_dir):
    """Copy splash and flag images from the PG zip."""
    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    for key in ("splashName", "flagName"):
        name = description_data.get(key, "")
        if not name:
            continue
        # Find in zip (search all paths)
        for zname in zip_ref.namelist():
            if zname.endswith(name):
                try:
                    data = zip_ref.read(zname)
                    out_path = os.path.join(images_dir, name)
                    with open(out_path, "wb") as f:
                        f.write(data)
                    print(f"  Copied image: {name}")
                except Exception as e:
                    print(f"  Warning: Could not copy {name}: {e}")
                break


# ─────────────────────────────────────────────
#  Main conversion for one zip file
# ─────────────────────────────────────────────

def convert_course(zip_path, output_base_dir):
    """Convert a single PG course zip to OWG format."""
    zip_name = Path(zip_path).stem
    print(f"\n{'='*60}")
    print(f"Converting: {zip_name}")
    print(f"{'='*60}")

    with tempfile.TemporaryDirectory() as tmpdir:
        work_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(work_dir)

        # Step 1: Open zip and find key files
        print("\n[1/6] Reading zip contents...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            names = zf.namelist()

            # Find description JSON
            desc_file = next((n for n in names if n.endswith(".description")), None)
            unity_file = next((n for n in names if n.endswith(".unity3d")), None)

            if not desc_file:
                print("  ERROR: No .description file found in zip")
                return False
            if not unity_file:
                print("  ERROR: No .unity3d file found in zip")
                return False

            print(f"  Description: {desc_file}")
            print(f"  Unity bundle: {unity_file} ({os.path.getsize(zip_path)//1024//1024}MB zip)")

            # Read description
            desc_raw = zf.read(desc_file).decode("utf-8")
            description_data = json.loads(desc_raw)
            course_name = description_data.get("name", zip_name)
            safe_name = sanitize_name(course_name)
            print(f"  Course name: {course_name}")

            # Extract unity3d to temp
            print("\n[2/6] Extracting Unity bundle (this may take a minute)...")
            zf.extract(unity_file, tmpdir)
            unity_path = os.path.join(tmpdir, unity_file)

            # Set up output dir named after course
            out_dir = os.path.join(tmpdir, f"OWG-{safe_name}")
            os.makedirs(out_dir, exist_ok=True)

            # Step 2: Load Unity bundle
            print("\n[3/6] Loading Unity assets...")
            env = UnityPy.load(unity_path)

            # Count asset types
            type_counts = {}
            for obj in env.objects:
                t = obj.type.name
                type_counts[t] = type_counts.get(t, 0) + 1
            print(f"  Found: {type_counts.get('Texture2D', 0)} textures, "
                  f"{type_counts.get('Mesh', 0)} meshes, "
                  f"{type_counts.get('TerrainData', 0)} terrain data")

            # Step 3: Extract heightmap
            print("\n[4/6] Extracting terrain heightmap...")
            terrain_meta = None
            for obj in env.objects:
                if obj.type.name == "TerrainData":
                    terrain_data = obj.read()
                    terrain_meta = extract_heightmap(terrain_data, out_dir)
                    extract_splat_maps(terrain_data, out_dir)
                    break

            if not terrain_meta:
                print("  WARNING: No TerrainData found, using empty terrain meta")
                terrain_meta = {}

            # Step 4: Extract textures
            print("\n[5/6] Extracting textures...")
            extract_textures(env, out_dir)

            # Step 5: Convert course JSON
            print("\n[6/6] Converting course data...")
            convert_course_json(description_data, terrain_meta, out_dir)
            copy_images(zf, description_data, out_dir)

        # Step 6: Package into output zip
        output_zip_name = f"OWG-{safe_name}.zip"
        output_zip_path = os.path.join(output_base_dir, output_zip_name)

        print(f"\nPackaging → {output_zip_name}...")
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as out_zip:
            for root, dirs, files in os.walk(out_dir):
                for file in files:
                    full_path = os.path.join(root, file)
                    arcname = os.path.relpath(full_path, out_dir)
                    out_zip.write(full_path, arcname)

        size_mb = os.path.getsize(output_zip_path) / 1024 / 1024
        print(f"Done! {output_zip_path} ({size_mb:.1f} MB)")
        return True


# ─────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Convert Perfect Golf course zips to OWG Godot format"
    )
    parser.add_argument(
        "zips",
        nargs="*",
        help="Specific zip files to convert (default: all *.zip in current directory)"
    )
    parser.add_argument(
        "--output", "-o",
        default=".",
        help="Output directory for OWG zips (default: current directory)"
    )
    args = parser.parse_args()

    # Find zip files to process
    if args.zips:
        zip_files = [Path(z) for z in args.zips if Path(z).exists()]
    else:
        # Auto-find all zips in current dir, skip any that already start with OWG-
        zip_files = [
            p for p in Path(".").glob("*.zip")
            if not p.stem.startswith("OWG-")
        ]

    if not zip_files:
        print("No PG course zip files found.")
        print("Usage: python3 pg_to_owg_converter.py [file1.zip file2.zip ...]")
        print("Or drop PG zips in this directory and run with no arguments.")
        sys.exit(0)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"OWG Course Converter")
    print(f"Found {len(zip_files)} course(s) to convert")
    print(f"Output: {output_dir.resolve()}")

    results = []
    for zip_file in zip_files:
        try:
            success = convert_course(str(zip_file), str(output_dir))
            results.append((zip_file.name, success))
        except Exception as e:
            print(f"\nERROR converting {zip_file.name}: {e}")
            import traceback
            traceback.print_exc()
            results.append((zip_file.name, False))

    # Summary
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
