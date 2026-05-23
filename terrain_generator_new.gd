# terrain_generator.gd
# Godot 4.x
#
# Purpose:
#   Convert exported Unity TerrainData height information into a Godot scene that has:
#     - a visible terrain MeshInstance3D
#     - a matching StaticBody3D + CollisionShape3D
#     - optional saving as a baked .tscn
#
# Expected Unity terrain JSON:
#
# {
#   "position": [0, 0, 0],
#   "size": [2000, 200, 2000],
#   "heightmapWidth": 513,
#   "heightmapHeight": 513,
#   "heightsAreNormalized": true,
#   "heights": [0.0, 0.01, 0.02, ...]
# }
#
# Notes:
#   Unity Terrain height values from TerrainData.GetHeights() are normalized 0..1.
#   Final world Y = terrain_position.y + height * terrain_size.y
#
#   Godot and Unity both use Y-up, X/Z ground plane.
#   If terrain appears mirrored, try flip_z = true.
#   If terrain appears rotated/wrong, try swap_xz = true.
#
# Usage in editor or runtime:
#
#   var terrain := TerrainGenerator.new()
#   add_child(terrain)
#   terrain.load_from_json_file("res://converted/st_andrews_terrain.json")
#
# To save baked scene:
#
#   terrain.save_as_scene("res://converted/st_andrews_terrain.tscn")


extends Node3D
class_name TerrainGeneratorNew


@export var terrain_json_path: String = ""
@export var save_scene_path: String = ""
## Explicit path to extracted course folder (user:// path).
## Set this when loading from user:// so textures/splat can be found.
## Leave empty to derive from terrain_json_path (res:// only).
@export var extract_base_path: String = ""

@export_group("Coordinate Fixes")
@export var flip_z: bool = false
@export var flip_x: bool = false
@export var swap_xz: bool = false
@export var unity_to_godot_z_flip: bool = false

@export_group("Mesh Quality")
@export_range(1, 32, 1) var sample_step: int = 1
@export var generate_normals: bool = true

@export_group("Collision")
@export var create_collision: bool = true
@export var collision_layer: int = 1
@export var collision_mask: int = 1

@export_group("Water")
@export var add_water_plane: bool = false  # Disable until water Y is verified correct
@export_group("Debug")
@export var print_debug_info: bool = true
@export var add_debug_marker_at_origin: bool = true


var terrain_mesh_instance: MeshInstance3D
var terrain_body: StaticBody3D
var terrain_collision: CollisionShape3D

# Stored terrain bounds for spawn/height queries
var _min_h: float = 0.0
var _max_h: float = 0.0


## Query terrain height at world X/Z via downward raycast against collision.
## Returns the surface Y, or _max_h + 5 if no hit.
func get_terrain_height(world_x: float, world_z: float) -> float:
	if not is_inside_tree():
		return _max_h
	var space := get_world_3d().direct_space_state
	if not space:
		return _max_h
	var from := Vector3(world_x, _max_h + 100.0, world_z)
	var to   := Vector3(world_x, _min_h - 100.0, world_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_layer
	var result := space.intersect_ray(query)
	if result and result.has("position"):
		return result.position.y
	return _max_h + 5.0


func _ready() -> void:
	if terrain_json_path != "":
		var ok: bool = load_from_json_file(terrain_json_path)
		if ok and save_scene_path != "":
			save_as_scene(save_scene_path)


func load_from_json_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TerrainGenerator: Could not open JSON file: %s" % path)
		return false

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TerrainGenerator: JSON root must be a Dictionary/Object.")
		return false

	return build_from_unity_terrain_dict(parsed)


func build_from_unity_terrain_dict(data: Dictionary) -> bool:
	clear_existing_terrain()

	var position: Vector3 = _read_vec3(data.get("position", [0, 0, 0]))
	var size: Vector3 = _read_vec3(data.get("size", [1, 1, 1]))

	var width := int(data.get("heightmapWidth", data.get("width", 0)))
	var height := int(data.get("heightmapHeight", data.get("height", 0)))
	var heights = data.get("heights", [])
	var heights_are_normalized := bool(data.get("heightsAreNormalized", true))

	if width <= 1 or height <= 1:
		push_error("TerrainGenerator: Invalid heightmap dimensions: %s x %s" % [width, height])
		return false

	if typeof(heights) != TYPE_ARRAY:
		push_error("TerrainGenerator: 'heights' must be a flat Array.")
		return false

	if heights.size() < width * height:
		push_error("TerrainGenerator: heights array too small. Expected %d, got %d." % [width * height, heights.size()])
		return false

	# Build shared index arrays used by BOTH mesh and collision
	# This guarantees perfect alignment — same vertices, same grid
	var step: int = max(1, sample_step)
	var x_indices: Array[int] = []
	var z_indices: Array[int] = []
	var xi := 0
	while xi < width:
		x_indices.append(xi)
		xi += step
	if x_indices[-1] != width - 1:
		x_indices.append(width - 1)
	var zi := 0
	while zi < height:
		z_indices.append(zi)
		zi += step
	if z_indices[-1] != height - 1:
		z_indices.append(height - 1)

	# Find min/max heights for shader water level and water plane
	var min_h: float = float(heights[0])
	var max_h: float = float(heights[0])
	for i in range(heights.size()):
		var h := float(heights[i])
		if h < min_h: min_h = h
		if h > max_h: max_h = h

	# Store for height queries
	_min_h = min_h
	_max_h = max_h

	var mesh: ArrayMesh = _build_terrain_mesh(position, size, width, height, heights, heights_are_normalized, x_indices, z_indices)

	if mesh == null:
		return false

	terrain_mesh_instance = MeshInstance3D.new()
	terrain_mesh_instance.name = "TerrainVisual"
	terrain_mesh_instance.mesh = mesh
	terrain_mesh_instance.transform = Transform3D.IDENTITY

	# Try splatmap material first — falls back to preview shader if assets missing
	var applied := _apply_splatmap_material(terrain_mesh_instance, position, size, min_h, max_h)
	if not applied:
		# Fallback: slope/height preview shader
		var shader := load("res://shaders/terrain_preview.gdshader")
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			var water_h := min_h + 0.5
			mat.set_shader_parameter("water_height", water_h)
			mat.set_shader_parameter("terrain_min_y", min_h)
			mat.set_shader_parameter("terrain_max_y", max_h)
			terrain_mesh_instance.material_override = mat
			print("TerrainGeneratorNew: using preview shader (no splatmap found)")

	add_child(terrain_mesh_instance)
	terrain_mesh_instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	if create_collision:
		terrain_body = StaticBody3D.new()
		terrain_body.name = "TerrainBody"
		terrain_body.collision_layer = collision_layer
		terrain_body.collision_mask = collision_mask
		terrain_body.position = position
		add_child(terrain_body)

		terrain_collision = CollisionShape3D.new()
		terrain_collision.name = "TerrainCollision"

		var hm_shape := HeightMapShape3D.new()
		var cw := x_indices.size()
		var ch := z_indices.size()
		hm_shape.map_width = cw
		hm_shape.map_depth = ch

		# Sample heights at SAME x_indices/z_indices as the visual mesh
		var hm_data := PackedFloat32Array()
		hm_data.resize(cw * ch)
		for row in range(ch):
			for col in range(cw):
				var src_z := z_indices[row]
				var src_x := x_indices[col]
				var h: float = float(heights[src_z * width + src_x])
				hm_data[row * cw + col] = h if not heights_are_normalized else h * size.y

		hm_shape.map_data = hm_data

		# HeightMapShape3D is centered — position offset + scale to match mesh
		terrain_collision.position = Vector3(size.x * 0.5, 0.0, size.z * 0.5)
		terrain_collision.scale = Vector3(
			size.x / float(cw - 1),
			1.0,
			size.z / float(ch - 1)
		)
		terrain_collision.shape = hm_shape
		terrain_body.add_child(terrain_collision)

		print("TerrainGeneratorNew: mesh %dx%d collision %dx%d — same grid ✓" % [cw, ch, cw, ch])

	if add_debug_marker_at_origin:
		_add_debug_marker(position)
	if print_debug_info:
		_print_debug(position, size, width, height, heights_are_normalized)

	# Add water plane only if enabled
	if add_water_plane:
		_add_water_plane(position, size, min_h, max_h)

	return true


func _apply_splatmap_material(mesh_inst: MeshInstance3D, position: Vector3, size: Vector3, min_h: float, max_h: float) -> bool:
	# Use explicit extract_base_path if set, otherwise derive from terrain_json_path
	var base: String
	if extract_base_path != "":
		base = extract_base_path.rstrip("/") + "/"
	else:
		# Derive: terrain_json_path = ".../terrain/terrain_heights.json"
		base = terrain_json_path.get_base_dir().get_base_dir() + "/"

	var splat_path  := base + "terrain/splat/alphamap_0.png"
	var layers_path := base + "terrain/splat/splat_layers.json"
	var tex_dir     := base + "textures/"

	if not FileAccess.file_exists(splat_path):
		push_warning("TerrainGeneratorNew: no splatmap at " + splat_path)
		return false
	if not FileAccess.file_exists(layers_path):
		push_warning("TerrainGeneratorNew: no splat_layers.json at " + layers_path)
		return false

	# Load splatmap
	var splat_img := Image.load_from_file(ProjectSettings.globalize_path(splat_path))
	if not splat_img:
		push_warning("TerrainGeneratorNew: failed to load splatmap image")
		return false
	var splat_tex := ImageTexture.create_from_image(splat_img)

	# Load splat layer definitions
	var f := FileAccess.open(layers_path, FileAccess.READ)
	if not f:
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return false
	var layers: Array = json.get_data()
	f.close()

	# Build shader — 4-layer splatmap with per-layer tile size
	var shader := load("res://shaders/terrain_splatmap.gdshader")
	if not shader:
		# Fall back to existing terrain_shader.gdshader
		shader = load("res://shaders/terrain_shader.gdshader")
	if not shader:
		push_warning("TerrainGeneratorNew: no splatmap shader found")
		return false

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("splatmap", splat_tex)
	mat.set_shader_parameter("owg_size_x", size.x)
	mat.set_shader_parameter("owg_size_z", size.z)

	# Wire up each layer texture by index
	var param_names := ["layer0_texture", "layer1_texture", "layer2_texture", "layer3_texture"]
	var tile_params  := ["layer0_tile",    "layer1_tile",    "layer2_tile",    "layer3_tile"]
	for layer in layers:
		var idx: int = int(layer.get("index", -1))
		if idx < 0 or idx >= param_names.size():
			continue
		var tex_name: String = layer.get("texture_name", "")
		var tile_x: float    = float(layer.get("tile_size_x", 15.0))
		# Try .png first, then .jpg
		var tex_path := tex_dir + tex_name + ".png"
		if not FileAccess.file_exists(tex_path):
			tex_path = tex_dir + tex_name + ".jpg"
		if FileAccess.file_exists(tex_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
			if img:
				mat.set_shader_parameter(param_names[idx], ImageTexture.create_from_image(img))
				mat.set_shader_parameter(tile_params[idx], tile_x)
				print("TerrainGeneratorNew: layer%d = %s (tile %.1f)" % [idx, tex_name, tile_x])
		else:
			push_warning("TerrainGeneratorNew: layer%d texture not found: %s" % [idx, tex_path])

	mesh_inst.material_override = mat
	print("TerrainGeneratorNew: splatmap material applied ✓")
	return true


func _add_water_plane(position: Vector3, size: Vector3, min_h: float, max_h: float) -> void:
	var water_y := min_h + 0.5

	# Debug — verify coordinate alignment
	print("terrain origin: ", position)
	print("terrain size: ", size)
	print("terrain y min/max: %.2f / %.2f" % [min_h, max_h])
	print("water y: %.2f" % water_y)

	# Water center matches terrain center exactly — same coordinate system
	var center := Vector3(
		position.x + size.x * 0.5,
		water_y,
		position.z + size.z * 0.5
	)
	print("water center: ", center)

	# Visual water plane
	var water_mesh := MeshInstance3D.new()
	water_mesh.name = "WaterPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	water_mesh.mesh = plane
	water_mesh.position = center
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color       = Color(0.05, 0.25, 0.75, 0.75)
	water_mat.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness          = 0.05
	water_mat.metallic           = 0.1
	water_mesh.material_override = water_mat
	add_child(water_mesh)

	# Hazard trigger Area3D
	var area := Area3D.new()
	area.name = "WaterHazard"
	area.collision_layer = 4
	area.collision_mask  = 2
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 2.0, size.z)
	col.shape = box
	area.add_child(col)
	area.position = center
	add_child(area)


func save_as_scene(path: String) -> bool:
	if get_child_count() == 0:
		push_error("TerrainGenerator: Nothing to save.")
		return false

	# Save this node as the root.
	# All child resources, including ArrayMesh and ConcavePolygonShape3D,
	# should be stored as subresources in the .tscn.
	var packed := PackedScene.new()
	var result: int = packed.pack(self)

	if result != OK:
		push_error("TerrainGenerator: PackedScene.pack failed with error %s" % result)
		return false

	result = ResourceSaver.save(packed, path)

	if result != OK:
		push_error("TerrainGenerator: ResourceSaver.save failed with error %s for path %s" % [result, path])
		return false

	print("TerrainGenerator: Saved baked terrain scene to: %s" % path)
	return true


func clear_existing_terrain() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	terrain_mesh_instance = null
	terrain_body = null
	terrain_collision = null


func _build_terrain_mesh(
	position: Vector3,
	size: Vector3,
	width: int,
	height: int,
	heights: Array,
	heights_are_normalized: bool,
	x_indices: Array,
	z_indices: Array
) -> ArrayMesh:

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for zi in z_indices:
		for xi in x_indices:
			var v: Vector3 = _height_vertex(position, size, width, height, heights, heights_are_normalized, xi, zi)
			vertices.append(v)

			var u := float(xi) / float(width - 1)
			var vv := float(zi) / float(height - 1)
			uvs.append(Vector2(u, vv))

			if generate_normals:
				normals.append(Vector3.UP)

	var row_len := x_indices.size()
	var col_len := z_indices.size()

	for row in range(col_len - 1):
		for col in range(row_len - 1):
			var i0 := row * row_len + col
			var i1 := row * row_len + col + 1
			var i2 := (row + 1) * row_len + col
			var i3 := (row + 1) * row_len + col + 1

			# Triangle winding for Godot.
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)

			indices.append(i1)
			indices.append(i2)
			indices.append(i3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	if generate_normals:
		arrays[Mesh.ARRAY_NORMAL] = _calculate_normals(vertices, indices)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Use SurfaceTool to regenerate smooth normals for better shader quality
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	return st.commit()


func _height_vertex(
	position: Vector3,
	size: Vector3,
	width: int,
	height: int,
	heights: Array,
	heights_are_normalized: bool,
	x: int,
	z: int
) -> Vector3:
	var read_x := x
	var read_z := z

	if flip_x:
		read_x = width - 1 - read_x
	if flip_z:
		read_z = height - 1 - read_z

	var h_raw := float(heights[read_z * width + read_x])
	var y: float = h_raw * size.y if heights_are_normalized else h_raw

	var fx := float(x) / float(width - 1)
	var fz := float(z) / float(height - 1)

	var px := position.x + fx * size.x
	var py := position.y + y
	var pz := position.z + fz * size.z

	if swap_xz:
		var old_x := px
		px = position.x + fz * size.x
		pz = position.z + fx * size.z

	if unity_to_godot_z_flip:
		pz = -(position.z + fz * size.z)

	return Vector3(px, py, pz)


func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())

	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for i in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]

		var a := vertices[ia]
		var b := vertices[ib]
		var c := vertices[ic]

		var n := (b - a).cross(c - a).normalized()

		normals[ia] += n
		normals[ib] += n
		normals[ic] += n

	for i in range(normals.size()):
		if normals[i].length_squared() > 0.000001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	return normals


func _read_vec3(value) -> Vector3:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


func _add_debug_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "TerrainOriginDebugMarker"

	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 6.0

	marker.mesh = sphere
	marker.position = pos + Vector3(0, 5, 0)
	add_child(marker)
	marker.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


func _print_debug(position: Vector3, size: Vector3, width: int, height: int, heights_are_normalized: bool) -> void:
	print("")
	print("=== TerrainGenerator Debug ===")
	print("terrain position: ", position)
	print("terrain size:     ", size)
	print("heightmap:        ", width, " x ", height)
	print("sample_step:      ", sample_step)
	print("normalized:       ", heights_are_normalized)
	print("flip_x:           ", flip_x)
	print("flip_z:           ", flip_z)
	print("swap_xz:          ", swap_xz)
	print("z_flip:           ", unity_to_godot_z_flip)
	print("collision:        ", create_collision)
	print("==============================")
	print("")
