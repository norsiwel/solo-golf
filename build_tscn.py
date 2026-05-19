def build_tscn(height_uint16, adjusted_heights, meta, output_dir, splat_layers=None, texture_map=None):
    """
    Build a Godot 4 .tscn with proper texture application.
    FIXED: Now actually applies the extracted textures to the terrain.
    """
    info("Building terrain .tscn with textures...")

    width    = meta["width"]
    height_n = meta["height"]
    scale_x  = meta["scale_x"]
    scale_y  = meta["scale_y"]
    scale_z  = meta["scale_z"]
    size_x   = meta["terrain_size_x"]
    size_z   = meta["terrain_size_z"]

    # Use adjusted heights for collision
    shape_heights = adjusted_heights

    # ── Collision shape ──────────────────────────────────────────
    CHUNK = 16
    float_strs = [f"{v:.4f}" for v in shape_heights]
    lines = []
    for i in range(0, len(float_strs), CHUNK):
        lines.append(", ".join(float_strs[i:i+CHUNK]))
    packed_data = ",\n".join(lines)
    info(f"Packed {len(shape_heights)} height values")

    # ── Visual mesh ──────────────────────────────────────────────
    MESH_RES = 256
    step_r = max(1, (height_n - 1) // (MESH_RES - 1))
    step_c = max(1, (width   - 1) // (MESH_RES - 1))
    rows = list(range(0, height_n, step_r))
    cols = list(range(0, width,    step_c))
    if rows[-1] != height_n - 1: rows.append(height_n - 1)
    if cols[-1] != width    - 1: cols.append(width    - 1)
    mr = len(rows)
    mc = len(cols)

    h2d = np.array(adjusted_heights).reshape(height_n, width)

    verts = []
    normals = []
    uvs = []

    for ri, r in enumerate(rows):
        for ci, c in enumerate(cols):
            wx = -(c * scale_x)
            wy = float(h2d[r, c])
            wz = r * scale_z
            verts.append((wx, wy, wz))
            uvs.append((-wx / size_x, wz / size_z))

            def hs(rr, cc):
                rr = max(0, min(height_n-1, rr))
                cc = max(0, min(width-1, cc))
                return float(h2d[rr, cc])
            dx = hs(r, c+1) - hs(r, c-1)
            dz = hs(r+1, c) - hs(r-1, c)
            nx, ny, nz = dx, 2.0 * scale_x, -dz
            length = (nx*nx + ny*ny + nz*nz) ** 0.5 or 1.0
            normals.append((nx/length, ny/length, nz/length))

    indices = []
    for ri in range(mr - 1):
        for ci in range(mc - 1):
            i00 = ri * mc + ci
            i10 = i00 + 1
            i01 = i00 + mc
            i11 = i01 + 1
            indices += [i00, i01, i10, i10, i01, i11]

    info(f"Visual mesh: {len(verts)} verts, {len(indices)//3} tris")

    def pack_v3(arr):
        parts = [f"{x:.4f}, {y:.4f}, {z:.4f}" for x,y,z in arr]
        return "PackedVector3Array(" + ", ".join(parts) + ")"

    def pack_v2(arr):
        parts = [f"{u:.5f}, {v:.5f}" for u,v in arr]
        return "PackedVector2Array(" + ", ".join(parts) + ")"

    def pack_i32(arr):
        CHUNK = 24
        rows_out = []
        for i in range(0, len(arr), CHUNK):
            rows_out.append(", ".join(str(x) for x in arr[i:i+CHUNK]))
        return "PackedInt32Array(" + ",\n".join(rows_out) + ")"

    verts_str   = pack_v3(verts)
    normals_str = pack_v3(normals)
    uvs_str     = pack_v2(uvs)
    idx_str     = pack_i32(indices)

    # ── Build material with actual textures ───────────────────────
    # Find which textures we have
    tex_dir = os.path.join(output_dir, "textures")
    has_textures = os.path.exists(tex_dir) and len(os.listdir(tex_dir)) > 0
    
    material_lines = []
    shader_params = []
    
    if has_textures and texture_map:
        info(f"Applying textures: {list(texture_map.keys())}")
        
        # Create a proper ShaderMaterial
        material_lines.append('[sub_resource type="ShaderMaterial" id="ShaderMaterial_terrain"]')
        
        # Reference the shader (create it if it doesn't exist, or use built-in)
        material_lines.append('shader = SubResource("Shader_terrain")')
        
        # Add texture parameters based on what we extracted
        for surface, tex_file in texture_map.items():
            tex_path = f"res://textures/{tex_file}"
            material_lines.append(f'shader_parameter/{surface}_texture = load("{tex_path}")')
            shader_params.append(surface)
        
        # Add splatmap if it exists
        splat_dir = os.path.join(output_dir, "terrain", "splat")
        if os.path.exists(splat_dir):
            splat_files = [f for f in os.listdir(splat_dir) if f.endswith(".png")]
            if splat_files:
                material_lines.append(f'shader_parameter/splatmap = load("res://terrain/splat/{splat_files[0]}")')
        
        # Add tiling parameter
        material_lines.append('shader_parameter/texture_scale = 8.0')
        
    else:
        # Fallback to standard material with color
        info("No textures found - using colored fallback material")
        material_lines.append('[sub_resource type="StandardMaterial3D" id="StandardMaterial_terrain"]')
        material_lines.append('albedo_color = Color(0.2, 0.5, 0.15, 1.0)')
        material_lines.append('roughness = 0.8')
        material_lines.append('metallic = 0.0')
    
    # ── Create the shader resource ─────────────────────────────────
    shader_code = '''[sub_resource type="Shader" id="Shader_terrain"]
code = "shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D splatmap : source_color;
uniform sampler2D fairway_texture : source_color;
uniform sampler2D rough_texture : source_color;
uniform sampler2D green_texture : source_color;
uniform sampler2D bunker_texture : source_color;
uniform sampler2D sand_texture : source_color;
uniform float texture_scale = 8.0;

void fragment() {
    vec4 splat = texture(splatmap, UV);
    vec2 tiled_uv = UV * texture_scale;
    
    vec4 fairway = texture(fairway_texture, tiled_uv);
    vec4 rough = texture(rough_texture, tiled_uv);
    vec4 green = texture(green_texture, tiled_uv);
    vec4 bunker = texture(bunker_texture, tiled_uv);
    
    vec4 final_color = 
        fairway * splat.r +
        rough * splat.g +
        green * splat.b +
        bunker * splat.a;
    
    ALBEDO = final_color.rgb;
    ROUGHNESS = 0.7;
    METALLIC = 0.0;
}"
'''
    
    material_str = "\n".join(material_lines)
    
    # ── Write the .tscn file ──────────────────────────────────────
    tscn = f"""[gd_scene load_steps=4 format=3 uid="uid://owg_terrain"]

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

{shader_code}

{material_str}

[node name="OWGTerrain" type="StaticBody3D"]
metadata/owg_terrain = true
metadata/terrain_size_x = {size_x:.3f}
metadata/terrain_size_z = {size_z:.3f}
metadata/scale_y = {scale_y:.3f}
metadata/water_level = {meta["water_level"]:.4f}

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("HeightMapShape3D_1")
transform = Transform3D({-scale_x:.4f}, 0, 0, 0, 1, 0, 0, 0, {scale_z:.4f}, 0, 0, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("ArrayMesh_1")
material_override = SubResource("ShaderMaterial_terrain")
"""

    terrain_dir = os.path.join(output_dir, "terrain")
    os.makedirs(terrain_dir, exist_ok=True)
    tscn_path = os.path.join(terrain_dir, "terrain.tscn")

    with open(tscn_path, "w") as f:
        f.write(tscn)

    size_mb = os.path.getsize(tscn_path) / 1024 / 1024
    info(f"terrain.tscn written: {size_mb:.1f} MB ✓")
    
    if has_textures and texture_map:
        info(f"  → Textures applied: {', '.join(texture_map.keys())}")
    else:
        info(f"  → No textures found, using fallback material")
    
    return tscn_path