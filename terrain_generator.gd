extends StaticBody3D
class_name TerrainGenerator

# Builds walkable terrain mesh + collision from course waypoints
# Uses HeightMapShape3D for reliable CharacterBody3D collision
# Attach to a StaticBody3D node, call build_from_hole() from main.gd

@export var resolution: int = 128
@export var margin: float = 80.0
@export var noise_strength: float = 0.4
@export var noise_scale: float = 0.025

# Heightmap sampling constants (The Old Course — normalized coordinate system)
# UV formula: u = 1 - (world_x + 1785.42) / 2156.9 ; v = (166.66 - world_z) / 2156.9
const HM_PATH := "res://courses/The_Old_Course_heightmap.png"
const GRASS_UV_SCALE := 12.0        # metres per texture repeat
const HM_WORLD_SIZE: float = 2156.9
const HM_X_OFFSET: float = 1785.42   # normalized_x + this = shifted Unity X
const HM_Z_ZERO: float = 166.66      # Unity Z at normalized world Z = 0
const HM_HEIGHT_SCALE: float = 6.4   # 0-255 maps to 0–6.4 m (Unity elevation)
const HM_Y_BASE: float = 21.92       # Unity minimum elevation (m)
const HM_Y_GODOT_OFFSET: float = -23.6  # converts Unity Y → Godot world Y

var _hm_image: Image = null

var _heightmap: PackedFloat32Array
var _width: int
var _depth: int
var _origin: Vector3
var _step_x: float
var _step_z: float
var _bounds: AABB
var _path: Array[Vector3] = []
var _tee: Vector3
var _pin: Vector3

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	if ResourceLoader.exists(HM_PATH):
		_hm_image = Image.load_from_file(HM_PATH)
		print("TerrainGenerator: heightmap loaded %dx%d" % [_hm_image.get_width(), _hm_image.get_height()])
	else:
		push_warning("TerrainGenerator: heightmap not found, using noise")

func _sample_real_height(world_x: float, world_z: float) -> float:
	# Map normalized Godot world coords → heightmap UV → Godot Y
	var u: float = 1.0 - (world_x + HM_X_OFFSET) / HM_WORLD_SIZE
	var v: float = (HM_Z_ZERO - world_z) / HM_WORLD_SIZE
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var px: int = int(u * float(_hm_image.get_width() - 1))
	var py: int = int(v * float(_hm_image.get_height() - 1))
	var raw: float = _hm_image.get_pixel(px, py).r  # 0.0–1.0
	return raw * HM_HEIGHT_SCALE + HM_Y_BASE + HM_Y_GODOT_OFFSET

## Load a heightmap from an absolute or user:// path (OWG extracted course).
## Replaces the built-in heightmap; subsequent build_from_hole() calls use it.
func load_heightmap(path: String) -> void:
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_error("TerrainGenerator: Failed to load heightmap from " + path)
		return
	_hm_image = img
	# Read optional terrain_meta.json for scale overrides alongside the heightmap
	var meta_path = path.get_base_dir() + "/terrain_meta.json"
	if FileAccess.file_exists(meta_path):
		var meta = _load_terrain_meta(meta_path)
		print("TerrainGenerator: terrain_meta loaded — scale_y=%.2f scale_x=%.2f" % [
			meta.get("scale_y", HM_HEIGHT_SCALE),
			meta.get("scale_x", 1.0)
		])
	print("TerrainGenerator: heightmap loaded from %s (%dx%d)" % [path, img.get_width(), img.get_height()])


func _load_terrain_meta(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.new()
	json.parse(f.get_as_text())
	return json.get_data()


func build_from_hole(tee: Vector3, pin: Vector3, all_tees: Array = [], all_pins: Array = []):
	# Collect all known points
	var points: Array[Vector3] = [tee, pin]
	for t in all_tees:
		points.append(Vector3(t.get("x", 0), 0, t.get("z", 0)))
	for p in all_pins:
		points.append(Vector3(p.get("x", 0), 0, p.get("z", 0)))

	# Build bounding box with margin
	_bounds = AABB(points[0], Vector3.ZERO)
	for p in points:
		_bounds = _bounds.expand(p)
	_bounds = _bounds.grow(margin)
	_origin = _bounds.position
	_origin.y = 0

	_width = resolution
	_depth = resolution
	_step_x = _bounds.size.x / (_width - 1)
	_step_z = _bounds.size.z / (_depth - 1)

	# Noise fallback (light, only used when heightmap is unavailable)
	var noise := FastNoiseLite.new()
	noise.seed = int(tee.x * 100 + pin.z * 100) % 65536
	noise.frequency = noise_scale
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	_tee = tee
	_pin = pin
	var path: Array[Vector3] = [tee, pin]
	_path = path

	_heightmap = PackedFloat32Array()
	_heightmap.resize(_width * _depth)

	for z in _depth:
		for x in _width:
			var world: Vector3 = _origin + Vector3(x * _step_x, 0, z * _step_z)
			var h: float
			if _hm_image:
				h = _sample_real_height(world.x, world.z)
				# Blend in tiny noise to break up flat-pixel repetition
				h += noise.get_noise_2d(world.x, world.z) * noise_strength * 0.15
			else:
				var base_y: float = _interpolate_path_elevation(world, path)
				var dist: float = _distance_to_path(world, path)
				var noise_mult: float = clamp(dist / 30.0, 0.0, 1.0)
				h = base_y + noise.get_noise_2d(world.x, world.z) * noise_strength * noise_mult
			_heightmap[z * _width + x] = maxf(h, 0.0)

	# Smooth the heightmap to turn sharp pixel edges into rolling swales
	if _hm_image:
		_smooth_heightmap(3)

	# Remove old children
	for child in get_children():
		child.queue_free()

	# Collision shape
	var shape = HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	shape.map_data = _heightmap
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	# Scale each cell to match actual terrain step size, then center
	var cell_sx = _bounds.size.x / (_width - 1)
	var cell_sz = _bounds.size.z / (_depth - 1)
	_collision_shape.scale = Vector3(cell_sx, 1.0, cell_sz)
	_collision_shape.position = Vector3(
		_origin.x + _bounds.size.x * 0.5,
		0,
		_origin.z + _bounds.size.z * 0.5
	)
	add_child(_collision_shape)

	# Visual mesh
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _generate_mesh()
	_mesh_instance.position = _origin
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	var fairway_tex = load("res://assets/terrain/surface_fairway_alt.png")
	if fairway_tex:
		mat.albedo_texture = fairway_tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	print("TerrainGenerator: Built %dx%d terrain for hole" % [_width, _depth])

func get_height_at(world_x: float, world_z: float) -> float:
	if _heightmap.is_empty():
		return 0.0
	var lx: float = (world_x - _origin.x) / _step_x
	var lz: float = (world_z - _origin.z) / _step_z
	var xi: int = clamp(int(lx), 0, _width - 2)
	var zi: int = clamp(int(lz), 0, _depth - 2)
	var fx: float = lx - xi
	var fz: float = lz - zi
	var h00: float = _heightmap[zi * _width + xi]
	var h10: float = _heightmap[zi * _width + xi + 1]
	var h01: float = _heightmap[(zi + 1) * _width + xi]
	var h11: float = _heightmap[(zi + 1) * _width + xi + 1]
	return lerp(lerp(h00, h10, fx), lerp(h01, h11, fx), fz)

func get_normal_at(world_x: float, world_z: float) -> Vector3:
	if _heightmap.is_empty():
		return Vector3.UP
	var s: float = maxf(_step_x, _step_z)
	var hl: float = get_height_at(world_x - s, world_z)
	var hr: float = get_height_at(world_x + s, world_z)
	var hd: float = get_height_at(world_x, world_z - s)
	var hu: float = get_height_at(world_x, world_z + s)
	return Vector3(hl - hr, 2.0 * s, hd - hu).normalized()

func get_surface_type(world_x: float, world_z: float) -> String:
	if _heightmap.is_empty():
		return "rough"
	var world = Vector3(world_x, 0, world_z)
	var tee_d = world.distance_to(_tee)
	var pin_d = world.distance_to(_pin)
	if tee_d < 8.0:
		return "tee"
	if pin_d < 24.0:
		return "green"
	var d = _distance_to_path(world, _path)
	if d < 22.0:
		return "fairway"
	if d < 55.0:
		return "rough"
	return "deep_rough"

func _interpolate_path_elevation(pos: Vector3, path: Array) -> float:
	if path.size() < 2:
		return 0.0
	var best = 0.0
	var best_dist = INF
	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i + 1]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq < 0.001:
			continue
		var t = clamp((pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
		var proj = p1.lerp(p2, t)
		var d = pos.distance_to(proj)
		if d < best_dist:
			best_dist = d
			best = lerp(p1.y, p2.y, t)
	return best

func _distance_to_path(pos: Vector3, path: Array) -> float:
	var min_d = INF
	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i + 1]
		var seg = p2 - p1
		var seg_len_sq = seg.length_squared()
		if seg_len_sq < 0.001:
			continue
		var t = clamp((pos - p1).dot(seg) / seg_len_sq, 0.0, 1.0)
		var proj = p1.lerp(p2, t)
		var d = pos.distance_to(proj)
		if d < min_d:
			min_d = d
	return min_d

func _zone_color(world_x: float, world_z: float) -> Color:
	var world = Vector3(world_x, 0, world_z)
	var d = _distance_to_path(world, _path)
	var tee_d = world.distance_to(_tee)
	var pin_d = world.distance_to(_pin)

	# Multiplied with fairway texture albedo — near-white = pure texture colour
	if tee_d < 8.0:
		return Color(1.0, 0.92, 0.72)   # sandy warmth for tee box
	if pin_d < 24.0:
		return Color(0.80, 1.0, 0.70)   # bright green tint for putting green
	if d < 22.0:
		return Color(1.0, 1.0, 1.0)     # pure texture on fairway
	if d < 55.0:
		return Color(0.78, 0.86, 0.68)  # slightly dark/yellow for semi-rough
	return Color(0.55, 0.70, 0.48)      # noticeably darker deep rough

func _generate_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(_depth - 1):
		for x in range(_width - 1):
			var i00 = z * _width + x
			var wx00 = _origin.x + x * _step_x
			var wz00 = _origin.z + z * _step_z
			var wx10 = wx00 + _step_x
			var wz01 = wz00 + _step_z
			var p00 = Vector3(x * _step_x,       _heightmap[i00],              z * _step_z)
			var p10 = Vector3((x+1) * _step_x,   _heightmap[i00 + 1],          z * _step_z)
			var p01 = Vector3(x * _step_x,       _heightmap[i00 + _width],     (z+1) * _step_z)
			var p11 = Vector3((x+1) * _step_x,   _heightmap[i00 + _width + 1], (z+1) * _step_z)
			var c00 = _zone_color(wx00, wz00)
			var c10 = _zone_color(wx10, wz00)
			var c01 = _zone_color(wx00, wz01)
			var c11 = _zone_color(wx10, wz01)
			st.set_color(c00); st.set_uv(Vector2(wx00 / GRASS_UV_SCALE, wz00 / GRASS_UV_SCALE)); st.add_vertex(p00)
			st.set_color(c01); st.set_uv(Vector2(wx00 / GRASS_UV_SCALE, wz01 / GRASS_UV_SCALE)); st.add_vertex(p01)
			st.set_color(c10); st.set_uv(Vector2(wx10 / GRASS_UV_SCALE, wz00 / GRASS_UV_SCALE)); st.add_vertex(p10)
			st.set_color(c10); st.set_uv(Vector2(wx10 / GRASS_UV_SCALE, wz00 / GRASS_UV_SCALE)); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(Vector2(wx00 / GRASS_UV_SCALE, wz01 / GRASS_UV_SCALE)); st.add_vertex(p01)
			st.set_color(c11); st.set_uv(Vector2(wx10 / GRASS_UV_SCALE, wz01 / GRASS_UV_SCALE)); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

func _smooth_heightmap(passes: int) -> void:
	var sm := PackedFloat32Array()
	sm.resize(_width * _depth)
	for _p in passes:
		for z in _depth:
			for x in _width:
				var sum := 0.0
				var cnt := 0
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx2 := x + dx
						var nz2 := z + dz
						if nx2 >= 0 and nx2 < _width and nz2 >= 0 and nz2 < _depth:
							sum += _heightmap[nz2 * _width + nx2]
							cnt += 1
				sm[z * _width + x] = sum / float(cnt)
		_heightmap = sm
