#!/usr/bin/env python3
"""
Convert Unity 5.x extracted Mesh .dat files to .obj format.
Handles The Old Course spline mesh and other mesh types.

Usage:
  python3 unity_mesh_to_obj.py <input.dat> [output.obj]
  python3 unity_mesh_to_obj.py --batch <input_dir> <output_dir>
"""

import struct
import sys
import os
import math


def read_u32(data, off):
    return struct.unpack_from('<I', data, off)[0]

def read_i32(data, off):
    return struct.unpack_from('<i', data, off)[0]

def read_f32(data, off):
    return struct.unpack_from('<f', data, off)[0]

def read_f16(data, off):
    # IEEE 754 half-precision
    h = struct.unpack_from('<H', data, off)[0]
    sign = (h >> 15) & 1
    exp  = (h >> 10) & 0x1F
    mant = h & 0x3FF
    if exp == 0:
        val = math.ldexp(mant, -24) * (-1 if sign else 1)
    elif exp == 31:
        val = float('-inf') if sign else float('inf')
    else:
        val = math.ldexp(mant + 1024, exp - 25) * (-1 if sign else 1)
    return val

def align4(n):
    return (n + 3) & ~3

def read_string(data, off):
    length = read_u32(data, off)
    name = data[off+4:off+4+length].decode('utf-8', errors='replace').rstrip('\x00')
    end = off + 4 + align4(length)
    return name, end

FORMAT_SIZES = {
    0: 4,   # float32
    1: 2,   # float16
    2: 1,   # unorm8
    3: 1,   # snorm8
    4: 2,   # unorm16
    5: 2,   # snorm16
    6: 1,   # uint8
    7: 1,   # sint8
    8: 2,   # uint16
    9: 2,   # sint16
    10: 4,  # uint32
    11: 4,  # sint32 (in Unity 5.x this was float32 equiv)
}

def read_component(data, off, fmt):
    """Read one component value given Unity vertex format code."""
    if fmt == 0:   # float32
        return struct.unpack_from('<f', data, off)[0]
    elif fmt == 1: # float16
        return read_f16(data, off)
    elif fmt == 2: # unorm8
        return struct.unpack_from('B', data, off)[0] / 255.0
    elif fmt == 3: # snorm8
        v = struct.unpack_from('b', data, off)[0]
        return max(v / 127.0, -1.0)
    elif fmt == 4: # unorm16
        return struct.unpack_from('<H', data, off)[0] / 65535.0
    elif fmt == 5: # snorm16
        v = struct.unpack_from('<h', data, off)[0]
        return max(v / 32767.0, -1.0)
    elif fmt == 11: # sint32 / float32 alias in Unity 5
        return struct.unpack_from('<f', data, off)[0]
    else:
        return 0.0


def parse_mesh(data, verbose=False):
    """
    Parse a Unity 5.x binary Mesh .dat file.
    Returns dict with vertices, uvs, normals, indices.
    """
    off = 0

    # Name
    name, off = read_string(data, off)

    # SubMesh array
    sub_count = read_u32(data, off)
    off += 4
    submeshes = []
    for _ in range(sub_count):
        first_byte = read_u32(data, off)
        index_count = read_u32(data, off+4)
        topology = read_i32(data, off+8)
        first_vertex = read_u32(data, off+12)
        vertex_count = read_u32(data, off+16)
        # AABB: 2 * Vector3 = 24 bytes
        submeshes.append({
            'first_byte': first_byte,
            'index_count': index_count,
            'topology': topology,
            'first_vertex': first_vertex,
            'vertex_count': vertex_count,
        })
        off += 44

    if verbose:
        print(f"  Name: {name}")
        for i, sm in enumerate(submeshes):
            print(f"  SubMesh[{i}]: indices={sm['index_count']}, verts={sm['vertex_count']}")

    # Skip BlendShapes (4 empty TypedArrays = 16 bytes of zeros)
    off += 16

    # Skip BindPose array count (0)
    off += 4

    # Skip BoneNameHashes array count (0)
    off += 4

    # Skip RootBoneNameHash (uint32)
    off += 4

    # Flags: MeshCompression(u8), IsReadable(u8), KeepVerts(u8), KeepIndices(u8)
    mesh_compression = data[off]
    off += 4  # 4 bytes packed

    if mesh_compression != 0:
        raise ValueError(f"Compressed mesh not supported (compression={mesh_compression})")

    # IndexBuffer TypedArray
    idx_byte_count = read_u32(data, off)
    off += 4
    idx_data = data[off:off+idx_byte_count]
    off += align4(idx_byte_count)

    # Unknown uint32 (= 0 in all observed files, possibly UVInfo or CompressedMesh stub)
    off += 4

    # VertexData
    current_channels = read_u32(data, off)  # bitmask
    off += 4
    vert_count = read_u32(data, off)
    off += 4

    # Channels TypedArray (count + 8 * ChannelInfo)
    channel_count = read_u32(data, off)
    off += 4
    channels = []
    for _ in range(channel_count):
        stream  = data[off]
        ch_off  = data[off+1]
        fmt     = data[off+2]
        dim     = data[off+3]
        channels.append({'stream': stream, 'offset': ch_off, 'format': fmt, 'dim': dim})
        off += 4

    # Vertex buffer bytes TypedArray
    buf_size = read_u32(data, off)
    off += 4
    vert_buffer = data[off:off+buf_size]

    if vert_count == 0 or buf_size == 0:
        return None

    stride = buf_size // vert_count

    # Find position channel (channel 0), normal (channel 1), UV (channel 3)
    pos_ch   = channels[0] if len(channels) > 0 and channels[0]['dim'] > 0 else None
    norm_ch  = channels[1] if len(channels) > 1 and channels[1]['dim'] > 0 else None
    uv_ch    = channels[3] if len(channels) > 3 and channels[3]['dim'] > 0 else None

    if pos_ch is None:
        return None

    pos_size = FORMAT_SIZES.get(pos_ch['format'], 4)

    # Extract vertices
    positions = []
    normals   = []
    uvs       = []

    for i in range(vert_count):
        base = i * stride

        # Position (XYZ)
        p_off = base + pos_ch['offset']
        x = read_component(vert_buffer, p_off,               pos_ch['format'])
        y = read_component(vert_buffer, p_off + pos_size,    pos_ch['format'])
        z = read_component(vert_buffer, p_off + pos_size*2,  pos_ch['format'])
        positions.append((x, y, z))

        # Normal
        if norm_ch and norm_ch['dim'] >= 3:
            n_size = FORMAT_SIZES.get(norm_ch['format'], 4)
            n_off = base + norm_ch['offset']
            nx = read_component(vert_buffer, n_off,            norm_ch['format'])
            ny = read_component(vert_buffer, n_off + n_size,   norm_ch['format'])
            nz = read_component(vert_buffer, n_off + n_size*2, norm_ch['format'])
            normals.append((nx, ny, nz))

        # UV
        if uv_ch and uv_ch['dim'] >= 2:
            u_size = FORMAT_SIZES.get(uv_ch['format'], 4)
            u_off = base + uv_ch['offset']
            u = read_component(vert_buffer, u_off,           uv_ch['format'])
            v = read_component(vert_buffer, u_off + u_size,  uv_ch['format'])
            uvs.append((u, v))

    # Parse index buffer (uint16)
    indices = list(struct.unpack_from(f'<{len(idx_data)//2}H', idx_data))

    if verbose:
        if positions:
            xs = [p[0] for p in positions]
            ys = [p[1] for p in positions]
            zs = [p[2] for p in positions]
            print(f"  Vertices: {vert_count}, stride: {stride}")
            print(f"  X: [{min(xs):.2f}, {max(xs):.2f}]  Y: [{min(ys):.2f}, {max(ys):.2f}]  Z: [{min(zs):.2f}, {max(zs):.2f}]")

    return {
        'name': name,
        'positions': positions,
        'normals': normals,
        'uvs': uvs,
        'indices': indices,
        'submeshes': submeshes,
    }


def write_obj(mesh, out_path):
    """Write mesh data to .obj file."""
    with open(out_path, 'w') as f:
        f.write(f"# Converted from Unity .dat mesh: {mesh['name']}\n")
        f.write(f"# Vertices: {len(mesh['positions'])}, Triangles: {len(mesh['indices'])//3}\n\n")
        f.write(f"o {mesh['name'].replace(' ', '_')}\n\n")

        for x, y, z in mesh['positions']:
            f.write(f"v {x:.6f} {y:.6f} {z:.6f}\n")

        if mesh['uvs']:
            f.write("\n")
            for u, v in mesh['uvs']:
                f.write(f"vt {u:.6f} {1.0-v:.6f}\n")  # flip V for OBJ convention

        if mesh['normals']:
            f.write("\n")
            for nx, ny, nz in mesh['normals']:
                f.write(f"vn {nx:.6f} {ny:.6f} {nz:.6f}\n")

        f.write("\n")
        idx = mesh['indices']
        has_uv = bool(mesh['uvs'])
        has_nm = bool(mesh['normals'])

        for i in range(0, len(idx) - 2, 3):
            a, b, c = idx[i]+1, idx[i+1]+1, idx[i+2]+1
            if has_uv and has_nm:
                f.write(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}\n")
            elif has_uv:
                f.write(f"f {a}/{a} {b}/{b} {c}/{c}\n")
            elif has_nm:
                f.write(f"f {a}//{a} {b}//{b} {c}//{c}\n")
            else:
                f.write(f"f {a} {b} {c}\n")


def convert_file(in_path, out_path=None, verbose=True):
    if out_path is None:
        base = os.path.splitext(in_path)[0]
        out_path = base + '.obj'

    with open(in_path, 'rb') as f:
        data = f.read()

    try:
        mesh = parse_mesh(data, verbose=verbose)
        if mesh is None or not mesh['positions']:
            if verbose:
                print(f"  Skipped: no vertex data")
            return False
        write_obj(mesh, out_path)
        if verbose:
            print(f"  Wrote: {out_path}")
        return True
    except Exception as e:
        if verbose:
            print(f"  Error: {e}")
        return False


def batch_convert(in_dir, out_dir, pattern=None, verbose=False):
    os.makedirs(out_dir, exist_ok=True)
    files = sorted(f for f in os.listdir(in_dir) if f.endswith('.dat'))
    if pattern:
        files = [f for f in files if pattern.lower() in f.lower()]

    ok = 0
    for fname in files:
        in_path = os.path.join(in_dir, fname)
        safe_name = fname.replace(' ', '_').replace('#', '').replace('.dat', '.obj')
        out_path = os.path.join(out_dir, safe_name)
        if verbose:
            print(f"Converting: {fname}")
        if convert_file(in_path, out_path, verbose=verbose):
            ok += 1

    print(f"Converted {ok}/{len(files)} files")


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)

    if args[0] == '--batch':
        if len(args) < 3:
            print("Usage: --batch <input_dir> <output_dir> [pattern]")
            sys.exit(1)
        pattern = args[3] if len(args) > 3 else None
        batch_convert(args[1], args[2], pattern=pattern, verbose=True)
    else:
        out = args[1] if len(args) > 1 else None
        convert_file(args[0], out, verbose=True)
