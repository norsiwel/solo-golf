#!/usr/bin/env python3
"""
terrain_from_course.py — Solo Golf Terrain Generator

Reads a course _meta.json file and generates:
  1. A greyscale heightmap PNG the Godot Terrain3D plugin can import
  2. A GDScript snippet to set up the terrain node with correct scale

The terrain is inferred by interpolating between all known elevation
points (tees, pins) using Radial Basis Function (RBF) interpolation,
then adding procedural noise for natural variation between sample points.

Usage:
    python3 terrain_from_course.py courses/The_Old_Course_meta.json
    python3 terrain_from_course.py courses/Sunset_Valley_GC_meta.json --size 2048

Output:
    courses/The_Old_Course_heightmap.png
    courses/The_Old_Course_terrain_setup.gd
"""

import json
import sys
import os
import math
import struct

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def distance_2d(ax, az, bx, bz):
    return math.sqrt((ax - bx)**2 + (az - bz)**2)

def rbf_interpolate(points, query_x, query_z, epsilon=80.0):
    """
    Radial Basis Function interpolation.
    points: list of (x, z, y_elevation)
    Returns interpolated elevation at (query_x, query_z)
    """
    if not points:
        return 0.0
    
    # Gaussian RBF weights
    weights = []
    total_weight = 0.0
    for px, pz, py in points:
        d = distance_2d(query_x, query_z, px, pz)
        w = math.exp(-(d / epsilon) ** 2)
        weights.append((w, py))
        total_weight += w
    
    if total_weight < 1e-10:
        # Too far from all points — use nearest
        nearest = min(points, key=lambda p: distance_2d(query_x, query_z, p[0], p[2]))
        return nearest[2]
    
    value = sum(w * py for w, py in weights) / total_weight
    return value

def simple_noise(x, z, scale=0.015, octaves=4):
    """
    Simple pseudo-random noise using sine waves.
    No external library needed.
    """
    v = 0.0
    amp = 1.0
    freq = scale
    for i in range(octaves):
        v += amp * math.sin(x * freq * 7.3891 + z * freq * 5.1234 + i * 2.718)
        v += amp * math.sin(x * freq * 3.1415 - z * freq * 8.9012 + i * 1.414)
        amp *= 0.5
        freq *= 2.0
    return v * 0.5  # normalize roughly to -1..1

def generate_heightmap(meta_path, output_size=1024, noise_strength=0.3):
    """Generate a heightmap PNG from course metadata."""
    
    with open(meta_path) as f:
        meta = json.load(f)
    
    course_name = meta.get("name", "Unknown")
    holes = meta.get("holes", [])
    
    print(f"Course: {course_name}")
    print(f"Holes: {len(holes)}")
    
    # Collect all known elevation sample points (world X, Z, Y)
    elevation_points = []
    
    all_x = []
    all_z = []
    
    for hole in holes:
        # Tee position
        tee = hole.get("tee", {})
        if tee:
            tx = tee.get("x", 0)
            tz = -tee.get("z", 0)  # PG to Godot Z flip
            ty = tee.get("y", 0)
            elevation_points.append((tx, tz, ty))
            all_x.append(tx); all_z.append(tz)
        
        # Pin position
        pin = hole.get("pin", {})
        if pin:
            px = pin.get("x", 0)
            pz = -pin.get("z", 0)
            py = pin.get("y", 0)
            elevation_points.append((px, pz, py))
            all_x.append(px); all_z.append(pz)
        
        # All tee variants
        for t in hole.get("all_tees", []):
            p = t.get("position", {})
            if p:
                elevation_points.append((p.get("x",0), -p.get("z",0), p.get("y",0)))
                all_x.append(p.get("x",0)); all_z.append(-p.get("z",0))
        
        # All pin variants  
        for p in hole.get("all_pins", []):
            pos = p.get("position", {})
            if pos:
                elevation_points.append((pos.get("x",0), -pos.get("z",0), pos.get("y",0)))
                all_x.append(pos.get("x",0)); all_z.append(-pos.get("z",0))
    
    if not elevation_points:
        print("ERROR: No elevation points found in metadata")
        sys.exit(1)
    
    print(f"Elevation sample points: {len(elevation_points)}")
    
    # Find world bounds with padding
    min_x = min(all_x) - 100
    max_x = max(all_x) + 100
    min_z = min(all_z) - 100
    max_z = max(all_z) + 100
    
    world_w = max_x - min_x
    world_h = max_z - min_z
    world_size = max(world_w, world_h)
    
    # Center the square
    cx = (min_x + max_x) / 2
    cz = (min_z + max_z) / 2
    min_x = cx - world_size / 2
    max_x = cx + world_size / 2
    min_z = cz - world_size / 2
    max_z = cz + world_size / 2
    
    print(f"World bounds: X {min_x:.0f} to {max_x:.0f}, Z {min_z:.0f} to {max_z:.0f}")
    print(f"World size: {world_size:.0f}m x {world_size:.0f}m")
    
    # Find elevation range
    min_y = min(p[2] for p in elevation_points)
    max_y = max(p[2] for p in elevation_points)
    elev_range = max(max_y - min_y, 1.0)
    
    print(f"Elevation range: {min_y:.1f}m to {max_y:.1f}m ({elev_range:.1f}m total)")
    
    # Scale RBF epsilon relative to course size
    epsilon = world_size * 0.12
    
    # Generate heightmap pixels
    print(f"Generating {output_size}x{output_size} heightmap...")
    pixels = bytearray(output_size * output_size)
    
    for row in range(output_size):
        if row % 128 == 0:
            print(f"  Row {row}/{output_size}...")
        for col in range(output_size):
            # Map pixel to world coords
            wx = min_x + (col / output_size) * (max_x - min_x)
            wz = min_z + (row / output_size) * (max_z - min_z)
            
            # RBF interpolated elevation
            elev = rbf_interpolate(elevation_points, wx, wz, epsilon)
            
            # Add gentle noise for natural variation between sample points
            noise = simple_noise(wx, wz) * noise_strength * elev_range
            elev += noise
            
            # Normalize to 0-255
            t = clamp((elev - min_y) / elev_range, 0.0, 1.0)
            pixels[row * output_size + col] = int(t * 255)
    
    # Write PNG manually (no PIL needed — pure Python)
    import zlib
    
    def png_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = zlib.crc32(chunk) & 0xffffffff
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', crc)
    
    # PNG header
    png_data = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr = struct.pack('>IIBBBBB', output_size, output_size, 8, 0, 0, 0, 0)
    png_data += png_chunk(b'IHDR', ihdr)
    
    # IDAT chunk (image data)
    raw_data = b''
    for row in range(output_size):
        raw_data += b'\x00'  # filter type None
        raw_data += bytes(pixels[row * output_size:(row + 1) * output_size])
    
    compressed = zlib.compress(raw_data, 6)
    png_data += png_chunk(b'IDAT', compressed)
    
    # IEND chunk
    png_data += png_chunk(b'IEND', b'')
    
    # Save heightmap
    base_dir = os.path.dirname(meta_path)
    base_name = os.path.splitext(os.path.basename(meta_path))[0].replace('_meta', '')
    
    heightmap_path = os.path.join(base_dir, base_name + '_heightmap.png')
    with open(heightmap_path, 'wb') as f:
        f.write(png_data)
    print(f"\nHeightmap saved: {heightmap_path}")
    
    # Generate GDScript terrain setup snippet
    terrain_scale_x = world_size
    terrain_scale_z = world_size  
    terrain_scale_y = elev_range * 2.0  # give headroom
    terrain_offset_x = (min_x + max_x) / 2
    terrain_offset_z = (min_z + max_z) / 2
    terrain_offset_y = min_y
    
    gd_path = os.path.join(base_dir, base_name + '_terrain_setup.gd')
    with open(gd_path, 'w') as f:
        f.write(f'''# Auto-generated terrain setup for {course_name}
# Paste this into your Terrain3D node script or call from main.gd

# Terrain3D import settings:
#   Heightmap PNG: {os.path.basename(heightmap_path)}
#   Size: {output_size}x{output_size}
#   World size X/Z: {terrain_scale_x:.1f}m
#   Height scale Y: {terrain_scale_y:.1f}m
#   Origin offset: ({terrain_offset_x:.1f}, {terrain_offset_y:.1f}, {terrain_offset_z:.1f})

const COURSE_NAME = "{course_name}"
const WORLD_SIZE = {world_size:.1f}
const HEIGHT_SCALE = {terrain_scale_y:.1f}
const TERRAIN_ORIGIN = Vector3({terrain_offset_x:.2f}, {terrain_offset_y:.2f}, {terrain_offset_z:.2f})
const MIN_ELEVATION = {min_y:.2f}
const MAX_ELEVATION = {max_y:.2f}

func setup_terrain(terrain_node):
    terrain_node.position = TERRAIN_ORIGIN
    # Set size and height in Terrain3D inspector:
    # storage.size = {output_size}
    # storage.height_range = Vector2({min_y:.1f}, {max_y + terrain_scale_y * 0.1:.1f})
    print("Terrain setup for: ", COURSE_NAME)
''')
    
    print(f"Terrain setup script: {gd_path}")
    
    # Summary
    print(f"""
=== TERRAIN GENERATION COMPLETE ===
Course:     {course_name}
Size:       {world_size:.0f}m x {world_size:.0f}m
Elevation:  {min_y:.1f}m - {max_y:.1f}m ({elev_range:.1f}m range)
Samples:    {len(elevation_points)} known elevation points
Heightmap:  {output_size}x{output_size} greyscale PNG
Noise:      {noise_strength} strength natural variation

Next steps:
1. Install Godot Terrain3D plugin (github.com/TokisanGames/Terrain3D)
2. Add Terrain3D node to main.tscn
3. Import {os.path.basename(heightmap_path)} as heightmap
4. Set terrain size to {world_size:.0f} and height range to {terrain_scale_y:.0f}
5. Position terrain at ({terrain_offset_x:.0f}, {terrain_offset_y:.0f}, {terrain_offset_z:.0f})
6. The ground StaticBody in main.tscn can then be removed
""")
    
    return heightmap_path

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    meta_path = sys.argv[1]
    size = 1024
    noise = 0.3
    
    for arg in sys.argv[2:]:
        if arg.startswith('--size='):
            size = int(arg.split('=')[1])
        elif arg.startswith('--noise='):
            noise = float(arg.split('=')[1])
    
    if not os.path.exists(meta_path):
        print(f"Error: File not found: {meta_path}")
        sys.exit(1)
    
    generate_heightmap(meta_path, size, noise)
