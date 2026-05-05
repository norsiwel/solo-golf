#!/usr/bin/env python3
"""
Convert .obj mesh file to .glb (binary glTF) for Godot import.

Usage:
  python3 obj_to_glb.py input.obj output.glb
"""

import sys
import struct
import json
import base64
import os

def parse_obj(path):
    positions = []
    normals = []
    uvs = []
    faces = []  # list of face-vertex tuples (v_idx, vt_idx, vn_idx) - 1-based

    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if parts[0] == 'v':
                positions.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == 'vn':
                normals.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == 'vt':
                uvs.append((float(parts[1]), float(parts[2])))
            elif parts[0] == 'f':
                verts = []
                for token in parts[1:]:
                    subs = token.split('/')
                    v  = int(subs[0]) - 1
                    vt = int(subs[1]) - 1 if len(subs) > 1 and subs[1] else -1
                    vn = int(subs[2]) - 1 if len(subs) > 2 and subs[2] else -1
                    verts.append((v, vt, vn))
                # triangulate (fan)
                for i in range(1, len(verts) - 1):
                    faces.append((verts[0], verts[i], verts[i+1]))

    return positions, normals, uvs, faces


def build_glb(positions, normals, uvs, faces):
    """Build minimal binary glTF 2.0 with positions, optional normals, and triangle indices."""

    # Build flat vertex data - deindex (simple, no vertex welding)
    out_pos = []
    out_nrm = []
    out_uv  = []
    out_idx = []

    # For large meshes, avoid full deindexing; instead create indexed with existing indices
    # Check if all faces use per-position-index normals/uvs consistently
    # For simplicity: deindex completely (one vertex per face-corner)
    vert_map = {}
    idx_list = []
    flat_pos = []
    flat_nrm = []
    flat_uv  = []

    for tri in faces:
        for (vi, vti, vni) in tri:
            key = (vi, vti, vni)
            if key not in vert_map:
                vert_map[key] = len(flat_pos)
                flat_pos.append(positions[vi])
                if vni >= 0 and normals:
                    flat_nrm.append(normals[vni])
                if vti >= 0 and uvs:
                    flat_uv.append(uvs[vti])
            idx_list.append(vert_map[key])

    n_verts = len(flat_pos)
    n_idx   = len(idx_list)

    # Build binary buffers
    pos_bytes  = b''.join(struct.pack('<3f', *p) for p in flat_pos)
    nrm_bytes  = b''.join(struct.pack('<3f', *n) for n in flat_nrm) if flat_nrm and len(flat_nrm)==n_verts else b''
    uv_bytes   = b''.join(struct.pack('<2f', *u) for u in flat_uv)  if flat_uv  and len(flat_uv)==n_verts  else b''

    # Use uint32 indices for large meshes, uint16 otherwise
    if n_verts > 65535:
        idx_bytes = b''.join(struct.pack('<I', i) for i in idx_list)
        idx_component = 5125  # UNSIGNED_INT
    else:
        idx_bytes = b''.join(struct.pack('<H', i) for i in idx_list)
        idx_component = 5123  # UNSIGNED_SHORT

    def pad4(b):
        pad = (4 - len(b) % 4) % 4
        return b + b'\x00' * pad

    pos_bytes  = pad4(pos_bytes)
    nrm_bytes  = pad4(nrm_bytes)
    uv_bytes   = pad4(uv_bytes)
    idx_bytes  = pad4(idx_bytes)

    # Compute bounding box
    xs = [p[0] for p in flat_pos]
    ys = [p[1] for p in flat_pos]
    zs = [p[2] for p in flat_pos]

    # Build bufferViews and accessors
    buffers_data = []
    buffer_views = []
    accessors = []
    prim_attrs = {}

    offset = 0

    def add_view(data, target):
        nonlocal offset
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target}
        buffer_views.append(bv)
        buffers_data.append(data)
        idx = len(buffer_views) - 1
        offset += len(data)
        return idx

    def add_accessor(bv_idx, component_type, count, type_str, min_v=None, max_v=None):
        acc = {
            "bufferView": bv_idx,
            "componentType": component_type,
            "count": count,
            "type": type_str,
        }
        if min_v is not None:
            acc["min"] = min_v
            acc["max"] = max_v
        accessors.append(acc)
        return len(accessors) - 1

    # Indices (ELEMENT_ARRAY_BUFFER = 34963)
    idx_bv  = add_view(idx_bytes, 34963)
    idx_acc = add_accessor(idx_bv, idx_component, n_idx, "SCALAR")
    prim_attrs["indices"] = idx_acc  # stored separately

    # Positions (ARRAY_BUFFER = 34962)
    pos_bv  = add_view(pos_bytes, 34962)
    pos_acc = add_accessor(pos_bv, 5126, n_verts, "VEC3",
                           [min(xs), min(ys), min(zs)],
                           [max(xs), max(ys), max(zs)])
    prim_attrs["POSITION"] = pos_acc

    if nrm_bytes:
        nrm_bv  = add_view(nrm_bytes, 34962)
        nrm_acc = add_accessor(nrm_bv, 5126, n_verts, "VEC3")
        prim_attrs["NORMAL"] = nrm_acc

    if uv_bytes:
        uv_bv  = add_view(uv_bytes, 34962)
        uv_acc = add_accessor(uv_bv, 5126, n_verts, "VEC2")
        prim_attrs["TEXCOORD_0"] = uv_acc

    combined = b''.join(buffers_data)

    # JSON chunk
    attrs_without_idx = {k: v for k, v in prim_attrs.items() if k != "indices"}
    gltf_json = {
        "asset": {"version": "2.0", "generator": "unity-mesh-converter"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0}],
        "meshes": [{
            "primitives": [{
                "attributes": attrs_without_idx,
                "indices": prim_attrs["indices"],
                "mode": 4,  # TRIANGLES
            }]
        }],
        "bufferViews": buffer_views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(combined)}],
    }

    json_bytes = json.dumps(gltf_json, separators=(',', ':')).encode('utf-8')
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b' ' * json_pad

    bin_pad = (4 - len(combined) % 4) % 4
    combined += b'\x00' * bin_pad

    # GLB header + JSON chunk + BIN chunk
    json_chunk = struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes  # JSON
    bin_chunk  = struct.pack('<II', len(combined),   0x004E4942) + combined    # BIN
    header = struct.pack('<III', 0x46546C67, 2, 12 + len(json_chunk) + len(bin_chunk))

    return header + json_chunk + bin_chunk


def convert(obj_path, glb_path):
    print(f"  Parsing {os.path.basename(obj_path)}...")
    positions, normals, uvs, faces = parse_obj(obj_path)
    print(f"  {len(positions)} positions, {len(normals)} normals, {len(faces)} triangles")
    glb = build_glb(positions, normals, uvs, faces)
    with open(glb_path, 'wb') as f:
        f.write(glb)
    print(f"  Wrote {glb_path} ({len(glb)//1024}KB)")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
