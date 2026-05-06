extends Node
class_name CourseShapesLoader

# Loads The_Old_Course_shapes.json and builds Godot collision / visual geometry
# for greens. Coordinates in the JSON are in Unity/meta world space; this loader
# normalises them to Godot world space (tee 1 = origin) before use.
#
# Usage in main.gd _setup_hole():
#   CourseShapesLoader.apply_green_shape(green_area_node, hole_num, ground_y)
#   CourseShapesLoader.apply_green_mesh(green_mesh_node, hole_num, ground_y)

const SHAPES_PATH := "res://courses/The_Old_Course_shapes.json"

# Tee 1 world origin in the shapes JSON coordinate system
# (Unity world X, meta-convention Z = -Unity_Z)
const ORIGIN_X := 1882.06
const ORIGIN_Z := -181.82

static var _data: Dictionary = {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var file = FileAccess.open(SHAPES_PATH, FileAccess.READ)
	if not file:
		push_error("CourseShapesLoader: cannot open " + SHAPES_PATH)
		return
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result is Dictionary:
		_data = result

# Normalise a raw shapes-JSON X coordinate to Godot world X
static func _nx(raw_x: float) -> float:
	return raw_x - ORIGIN_X

# Normalise a raw shapes-JSON Z coordinate to Godot world Z
static func _nz(raw_z: float) -> float:
	return raw_z - ORIGIN_Z


# -- Green shapes ----------------------------------------------------------

static func get_green_polygon(hole_num: int) -> Array:
	_load()
	for g in _data.get("greens", []):
		if g.get("hole") == hole_num:
			return g.get("shape", [])
	return []

static func get_green_center(hole_num: int) -> Dictionary:
	_load()
	for g in _data.get("greens", []):
		if g.get("hole") == hole_num:
			return g.get("center", {})
	return {}

# Returns the green centre in Godot world space as a Vector3 (y = ground_y)
static func get_green_center_godot(hole_num: int, ground_y: float = 0.0) -> Vector3:
	var c = get_green_center(hole_num)
	if c.is_empty():
		return Vector3.ZERO
	return Vector3(_nx(c.get("x", 0.0)), ground_y, _nz(c.get("z", 0.0)))


static func apply_green_shape(green_area: Area3D, hole_num: int, ground_y: float = 0.0) -> void:
	var poly = get_green_polygon(hole_num)
	if poly.is_empty():
		return

	var center = get_green_center(hole_num)
	var cx := _nx(center.get("x", 0.0))
	var cz := _nz(center.get("z", 0.0))

	green_area.global_position = Vector3(cx, ground_y + 0.02, cz)

	# Flat extrusion ±0.3 m in Y so the convex hull has volume
	var pts := PackedVector3Array()
	for p in poly:
		var lx: float = _nx(p.x) - cx
		var lz: float = _nz(p.z) - cz
		pts.append(Vector3(lx, -0.3, lz))
		pts.append(Vector3(lx,  0.3, lz))

	var col_shape = ConvexPolygonShape3D.new()
	col_shape.points = pts

	var found := false
	for child in green_area.get_children():
		if child is CollisionShape3D:
			child.shape = col_shape
			found = true
			break
	if not found:
		var cs = CollisionShape3D.new()
		cs.shape = col_shape
		green_area.add_child(cs)


static func apply_green_mesh(mesh_instance: MeshInstance3D, hole_num: int,
							ground_y: float = 0.0, height_fn: Callable = Callable()) -> void:
	var poly = get_green_polygon(hole_num)
	if poly.is_empty():
		return

	var center = get_green_center(hole_num)
	var cx := _nx(center.get("x", 0.0))
	var cz := _nz(center.get("z", 0.0))

	mesh_instance.global_position = Vector3(cx, ground_y + 0.012, cz)

	# Fresh material — avoids inheriting uv1_scale / albedo_texture from the scene asset
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.62, 0.20)
	mat.roughness = 0.95
	mesh_instance.set_surface_override_material(0, mat)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Pre-compute centroid height offset (local Y = terrain_h - ground_y)
	var yc := 0.0
	if height_fn.is_valid():
		yc = height_fn.call(cx, cz) - ground_y

	var n = poly.size()
	# Centroid-fan triangulation. generate_normals() handles per-face normals.
	for i in n:
		var a = poly[i]
		var b = poly[(i + 1) % n]
		var ax := _nx(a.x) - cx
		var az := _nz(a.z) - cz
		var bx := _nx(b.x) - cx
		var bz := _nz(b.z) - cz
		var ya := 0.0
		var yb := 0.0
		if height_fn.is_valid():
			ya = height_fn.call(_nx(a.x), _nz(a.z)) - ground_y
			yb = height_fn.call(_nx(b.x), _nz(b.z)) - ground_y
		var va = Vector3(ax, ya, az)
		var vb = Vector3(bx, yb, bz)
		var vc = Vector3(0.0, yc, 0.0)

		st.set_uv(Vector2(0.5, 0.5));                              st.add_vertex(vc)
		st.set_uv(Vector2(ax / 60.0 + 0.5, az / 60.0 + 0.5));    st.add_vertex(va)
		st.set_uv(Vector2(bx / 60.0 + 0.5, bz / 60.0 + 0.5));    st.add_vertex(vb)

	st.generate_normals()
	mesh_instance.mesh = st.commit()
