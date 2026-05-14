extends StaticBody3D
class_name TerrainGenerator

# Builds walkable terrain mesh + collision from course waypoints
# Uses HeightMapShape3D for reliable CharacterBody3D collision
# Attach to a StaticBody3D node, call build_from_hole() from main.gd

@export var resolution: int = 256
@export var margin: float = 120.0
@export var noise_strength: float = 0.4
@export var noise_scale: float = 0.025

# Heightmap sampling constants (The Old Course — normalized coordinate system)
# UV formula: u = 1 - (world_x + 1785.42) / 2156.9 ; v = (166.66 - world_z) / 2156.9
const HM_PATH := "res://courses/The_Old_Course_heightmap.png"
const GRASS_UV_SCALE := 12.0        # metres per texture repeat
const HM_WORLD_SIZE: float = 2271.1  # The Old Course terrain size (from meta)
const HM_X_OFFSET: float = 2271.1
const HM_Z_ZERO: float = 0.0
const HM_HEIGHT_SCALE: float = 100.497  # scale_y * 2
const HM_Y_BASE: float = 0.0
const HM_Y_GODOT_OFFSET: float = 0.0

var _hm_image: Image = null
var _owg_fairway_tex: Texture2D = null
var _owg_rough_tex: Texture2D = null
var _owg_green_tex: Texture2D = null
var _owg_splatmap_tex: Texture2D = null
var _owg_splatmap_image: Image = null

# Map Unity Prefab names to local Godot assets
const ASSET_MAP = {
	"Tree_Conifer": "res://assets/terrain/tree_conifer.png", # Placeholder: should be .tscn/.glb
	"Tree_Conifer_Small": "res://assets/terrain/tree_conifer_small.png",
	"Bush": "res://assets/terrain/bush.png",
	"Bush_Billboard": "res://assets/terrain/bush_billboard.png",
}

const SPLAT_SHADER = """
shader_type spatial;

uniform sampler2D splatmap : source_color, filter_linear;
uniform sampler2D fairway_tex : source_color, filter_linear_mipmap;
uniform sampler2D green_tex : source_color, filter_linear_mipmap;
uniform sampler2D rough_tex : source_color, filter_linear_mipmap;

uniform vec4 green_tint : source_color = vec4(0.15, 0.58, 0.14, 1.0);
uniform float uv_scale = 12.0;
uniform float owg_size_x = 2271.0;
uniform float owg_size_z = 2271.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Splatmap UV must match heightmap sampling formula (verified 0.001m error):
	// u = 1 + world_x / size_x,  v = 1 - world_z / size_z
	float safe_size_x = max(owg_size_x, 1.0);
	float safe_size_z = max(owg_size_z, 1.0);
	vec2 s_uv = vec2(1.0 + world_pos.x / safe_size_x, 1.0 - world_pos.z / safe_size_z);
	s_uv = clamp(s_uv, 0.0, 1.0);
	vec3 splat = texture(splatmap, s_uv).rgb;
	
	vec2 detail_uv = world_pos.xz / max(uv_scale, 0.1);
	
	vec3 fairway = texture(fairway_tex, detail_uv).rgb;
	vec3 green = texture(green_tex, detail_uv).rgb * green_tint.rgb;
	vec3 rough = texture(rough_tex, detail_uv).rgb;
	
	// Blend based on RGB: R=Fairway, G=Green, B=Rough
	vec3 final_color = fairway * splat.r + green * splat.g + rough * splat.b;
	
	// Fallback to fairway if splat is empty
	float total = splat.r + splat.g + splat.b;
	if (total < 0.1) {
		final_color = fairway;
	} else {
		final_color /= total; // normalize if overlap
	}
	
	ALBEDO = final_color * COLOR.rgb;
	ROUGHNESS = 0.85;
}
"""

# Set by load_heightmap() when an OWG course is active; zero = use Old Course constants
var _owg_size_x: float = 0.0
var _owg_size_z: float = 0.0
var _owg_scale_y: float = 0.0

## Surface zone data from course geometry
var _surface_tees:          Array[Vector3] = []
var _surface_pins:          Array[Vector3] = []
var _surface_shots:         Array[Vector3] = []  # fairway spine waypoints
var _surface_red_stakes:    Array[Vector3] = []  # bunker / lateral hazard edges
var _surface_yellow_stakes: Array[Vector3] = []  # water hazard edges

## Called from main.gd after OWG hole data is loaded.
func set_surface_zones(tees: Array, pins: Array, shots: Array, objects: Array) -> void:
	_surface_tees.clear()
	_surface_pins.clear()
	_surface_shots.clear()
	_surface_red_stakes.clear()
	_surface_yellow_stakes.clear()
	for t in tees:
		_surface_tees.append(Vector3(t.get("x",0), 0, t.get("z",0)))
	for p in pins:
		_surface_pins.append(Vector3(p.get("x",0), 0, p.get("z",0)))
	for s in shots:
		var sp = s.get("position", s)
		_surface_shots.append(Vector3(sp.get("x",0), 0, sp.get("z",0)))
	for obj in objects:
		var n = obj.get("prefab_name", "").to_lower()
		var pos_d = obj.get("position", {})
		var pos = Vector3(pos_d.get("x",0), 0, pos_d.get("z",0))
		if "stakered" in n or "stake_red" in n:
			_surface_red_stakes.append(pos)
		elif "stakeyellow" in n or "stake_yellow" in n:
			_surface_yellow_stakes.append(pos)
	print("TerrainGenerator: surface zones — %d tees %d pins %d shots %d red %d yellow" % [
		_surface_tees.size(), _surface_pins.size(), _surface_shots.size(),
		_surface_red_stakes.size(), _surface_yellow_stakes.size()])

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
	# OWG path: CourseManager will call load_heightmap() after all _ready() calls finish.
	# Skip loading the built-in PNG here so it can't overwrite the OWG image.
	if not GameState.current_course.is_empty():
		return
	if ResourceLoader.exists(HM_PATH):
		_hm_image = Image.load_from_file(HM_PATH)
		print("TerrainGenerator: heightmap loaded %dx%d" % [_hm_image.get_width(), _hm_image.get_height()])
	else:
		push_warning("TerrainGenerator: heightmap not found, using noise")

func _sample_real_height(world_x: float, world_z: float) -> float:
	if _owg_size_x > 0.0:
		# Heightmap saved with: transpose + flipud + fliplr
		# Verified 0m error: u = 1-(-wx/sx) = 1+wx/sx, v = 1 - wz/sz
		var u: float = clampf(1.0 + world_x / _owg_size_x, 0.0, 1.0)
		var v: float = clampf(1.0 - world_z / _owg_size_z, 0.0, 1.0)
		var px: int = int(u * float(_hm_image.get_width()  - 1))
		var py: int = int(v * float(_hm_image.get_height() - 1))
		return _hm_image.get_pixel(px, py).r * _owg_scale_y
	# Old Course built-in heightmap — hardcoded Unity→Godot constants
	var u: float = 1.0 - (world_x + HM_X_OFFSET) / HM_WORLD_SIZE
	var v: float = (HM_Z_ZERO - world_z) / HM_WORLD_SIZE
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var px: int = int(u * float(_hm_image.get_width()  - 1))
	var py: int = int(v * float(_hm_image.get_height() - 1))
	return _hm_image.get_pixel(px, py).r * HM_HEIGHT_SCALE + HM_Y_BASE + HM_Y_GODOT_OFFSET

## Load a heightmap from an absolute or user:// path (OWG extracted course).
## Replaces the built-in heightmap; subsequent build_from_hole() calls use it.
func load_heightmap(path: String) -> void:
	# Globalize user:// paths for Image.load_from_file()
	var global_path = ProjectSettings.globalize_path(path)
	var img = Image.load_from_file(global_path)
	if img == null:
		# Try the path as-is as fallback
		img = Image.load_from_file(path)
	if img == null:
		push_error("TerrainGenerator: Failed to load heightmap from " + path)
		_owg_size_x = 0.0
		return
	_hm_image = img
	var meta_path = path.get_base_dir() + "/terrain_meta.json"
	var global_meta = ProjectSettings.globalize_path(meta_path)
	var actual_meta = global_meta if FileAccess.file_exists(global_meta) else meta_path
	if FileAccess.file_exists(actual_meta):
		var meta = _load_terrain_meta(actual_meta)
		_owg_size_x  = meta.get("terrain_size_x", 0.0)
		_owg_size_z  = meta.get("terrain_size_z", 0.0)
		_owg_scale_y = meta.get("scale_y",         0.0)
		print("TerrainGenerator: OWG meta — size %.1fx%.1f m, scale_y %.2f" % [
			_owg_size_x, _owg_size_z, _owg_scale_y
		])
	else:
		push_warning("TerrainGenerator: no terrain_meta.json alongside " + path)
		_owg_size_x = 0.0
	print("TerrainGenerator: OWG heightmap loaded %dx%d from %s" % [
		img.get_width(), img.get_height(), path
	])


func _load_terrain_meta(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.new()
	json.parse(f.get_as_text())
	return json.get_data()


## Load textures from an absolute or user:// path (OWG extracted course).
func load_textures(dir_path: String) -> void:
	# Globalize user:// path for DirAccess and Image loading
	var global_dir = ProjectSettings.globalize_path(dir_path)
	var actual_dir = global_dir if DirAccess.dir_exists_absolute(global_dir) else dir_path
	var file_map = {}
	var dir = DirAccess.open(actual_dir)
	if not dir:
		push_warning("TerrainGenerator: Cannot open texture dir: " + actual_dir)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			file_map[file_name.to_lower()] = file_name
		file_name = dir.get_next()
	dir.list_dir_end()

	print("TerrainGenerator: scanning %d textures in: %s" % [file_map.size(), dir_path])

	# Helper: load first match from a list of candidate lowercase names
	var _load_first = func(candidates: Array) -> ImageTexture:
		for cname in candidates:
			if cname in file_map:
				var img = Image.load_from_file(actual_dir + "/" + file_map[cname])
				if img:
					print("TerrainGenerator: loaded " + file_map[cname])
					return ImageTexture.create_from_image(img)
		for key in file_map:
			for cname in candidates:
				var stem = cname.replace(".png", "")
				if stem in key and key.ends_with(".png"):
					var img = Image.load_from_file(actual_dir + "/" + file_map[key])
					if img:
						print("TerrainGenerator: loaded (partial) " + file_map[key])
						return ImageTexture.create_from_image(img)
		return null

	_owg_fairway_tex = _load_first.call(["fairway.png", "fairway2.png", "o_fairwayplain.png", "base_fairway.png", "surface_fairway.png", "skygrass_fair.png"])
	_owg_green_tex   = _load_first.call(["green.png", "skygrass_green.png", "o_greenfringe.png", "pickupgreen.png", "surface_green.png"])
	_owg_rough_tex   = _load_first.call(["terrainrough.png", "o_rough2desat.png", "meshlightrough.png", "base_rough1.png", "surface_rough.png"])

	# Splatmap — try alphamaps from terrain/splat/ first, then textures folder
	var splat_candidates = ["splatalpha_0.png", "splatalpha 0.png", "splatmap.png", "alphamap_0.png", "alphamap.png"]
	_owg_splatmap_tex = null
	_owg_splatmap_image = null

	# Try textures folder
	for cname in splat_candidates:
		if cname in file_map:
			var img = Image.load_from_file(actual_dir + "/" + file_map[cname])
			if img:
				_owg_splatmap_image = img
				_owg_splatmap_tex = ImageTexture.create_from_image(img)
				print("TerrainGenerator: loaded splatmap: " + file_map[cname])
				break

	# Try terrain/splat/ subfolder
	if not _owg_splatmap_tex:
		var splat_dir = actual_dir.get_base_dir() + "/terrain/splat"
		var sd = DirAccess.open(splat_dir)
		if sd:
			sd.list_dir_begin()
			var fn = sd.get_next()
			while fn != "":
				if fn.to_lower() in splat_candidates or "alphamap" in fn.to_lower():
					var img = Image.load_from_file(splat_dir + "/" + fn)
					if img:
						_owg_splatmap_image = img
						_owg_splatmap_tex = ImageTexture.create_from_image(img)
						print("TerrainGenerator: loaded splatmap from terrain/splat/: " + fn)
						break
				fn = sd.get_next()

	if not _owg_splatmap_tex:
		push_warning("TerrainGenerator: No splatmap found — terrain will use flat color zones")


func build_from_hole(tee: Vector3, pin: Vector3, all_tees: Array = [], all_pins: Array = []):
	# Cleanup previous terrain to prevent Z-fighting and "under the surface" issues
	if _mesh_instance:
		_mesh_instance.queue_free()
		_mesh_instance = null
	if _collision_shape:
		_collision_shape.queue_free()
		_collision_shape = null
		
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
	# HeightMapShape3D in Godot 4 centers itself at origin.
	# Scale x/z so each cell = one step. Position at bounds center.
	var shape = HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	shape.map_data = _heightmap
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = shape
	_collision_shape.scale = Vector3(_step_x, 1.0, _step_z)
	# Position is in LOCAL space BEFORE scale is applied, so divide by step to get cell-space center
	_collision_shape.position = _origin + Vector3(_bounds.size.x * 0.5, 0.0, _bounds.size.z * 0.5)
	add_child(_collision_shape)

	# Visual mesh
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _generate_mesh()
	_mesh_instance.position = _origin
	
	if _owg_splatmap_tex:
		var mat := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SPLAT_SHADER
		mat.shader = shader
		mat.set_shader_parameter("splatmap", _owg_splatmap_tex)
		
		# Fallbacks for all textures
		var f_tex = _owg_fairway_tex if _owg_fairway_tex else load("res://assets/terrain/surface_fairway.png")
		var g_tex = _owg_green_tex if _owg_green_tex else load("res://assets/terrain/surface_green.png")
		var r_tex = _owg_rough_tex if _owg_rough_tex else load("res://assets/terrain/surface_rough.png")
		
		mat.set_shader_parameter("fairway_tex", f_tex)
		mat.set_shader_parameter("green_tex", g_tex)
		mat.set_shader_parameter("rough_tex", r_tex)
		
		mat.set_shader_parameter("uv_scale", GRASS_UV_SCALE)
		mat.set_shader_parameter("owg_size_x", _owg_size_x)
		mat.set_shader_parameter("owg_size_z", _owg_size_z)
		mat.set_shader_parameter("green_tint", Color(0.15, 0.58, 0.14))
		_mesh_instance.material_override = mat
	else:
		# No splatmap — use vertex color zones + tiled grass texture
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.92
		mat.metallic = 0.0
		# Use UV1 for the tiled texture (set per-vertex in _generate_mesh)
		var base_tex = _owg_fairway_tex
		if base_tex == null:
			base_tex = load("res://assets/terrain/surface_fairway.png")
		if base_tex == null:
			base_tex = load("res://assets/terrain/grass.png")
		if base_tex:
			mat.albedo_texture = base_tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			# UV1 scale is handled per-vertex in _generate_mesh (GRASS_UV_SCALE)
		_mesh_instance.material_override = mat
	
	add_child(_mesh_instance)
	print("Terrain debug: origin=", _origin, " bounds=", _bounds.size, " collision_pos=", _collision_shape.position, " collision_scale=", _collision_shape.scale)
	print("TerrainGenerator: splatmap tex = ", _owg_splatmap_tex, " fairway = ", _owg_fairway_tex)

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
	var world := Vector3(world_x, 0, world_z)

	# --- Pin / Green check first ---
	for pin in _surface_pins:
		if world.distance_to(pin) < 22.0:
			return "green"
	if world.distance_to(_pin) < 22.0:
		return "green"

	# --- Tee check ---
	for tee in _surface_tees:
		if world.distance_to(tee) < 10.0:
			return "tee"
	if world.distance_to(_tee) < 10.0:
		return "tee"

	# --- Red stake = bunker proximity ---
	for stake in _surface_red_stakes:
		if world.distance_to(stake) < 12.0:
			return "bunker"

	# --- Yellow stake = water hazard ---
	for stake in _surface_yellow_stakes:
		if world.distance_to(stake) < 8.0:
			return "water"

	# --- Fairway spine: tee → shots → pin ---
	var spine: Array[Vector3] = []
	spine.append_array(_surface_tees if not _surface_tees.is_empty() else [_tee])
	spine.append_array(_surface_shots)
	spine.append_array(_surface_pins if not _surface_pins.is_empty() else [_pin])
	if spine.size() < 2:
		spine = [_tee, _pin]

	var d := _distance_to_path(world, spine)
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
	if _owg_splatmap_image:
		return Color.WHITE # splatmap handles all coloring via shader
		
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

## Reads Unity object list (JSON) and spawns Godot scenes at those positions.
## Rules: Godot_x = -Unity_x.
func spawn_unity_objects(object_list: Array, container: Node3D) -> void:
	if not container:
		return
		
	# Clear previous objects
	for child in container.get_children():
		child.queue_free()
		
	print("TerrainGenerator: Spawning %d Unity objects..." % object_list.size())
	
	var count := 0
	for obj in object_list:
		if count >= 2000:
			print("TerrainGenerator: Reached 2000 object limit, skipping rest")
			break
			
		var prefab_name: String = obj.get("prefab_name", obj.get("name", "Unknown"))
		
		# Skip terrain/surface objects and water planes
		var lname = prefab_name.to_lower()
		if "terrain" in lname or "green" in lname or "fairway" in lname \
				or "rough" in lname or "bunker" in lname or "water" in lname \
				or "ocean" in lname or "lake" in lname or "pond" in lname \
				or "sea" in lname or "river" in lname:
			continue
			
		var unity_pos = obj.get("position", {"x":0, "y":0, "z":0})
		var unity_rot = obj.get("rotation", {"x":0, "y":0, "z":0, "w":1})
		var unity_scale = obj.get("scale", {"x":1, "y":1, "z":1})
		
		# Conversion: Godot_x = -Unity_x
		var godot_pos = Vector3(-unity_pos.x, unity_pos.y, unity_pos.z)
		var godot_quat = Quaternion(unity_rot.x, unity_rot.y, unity_rot.z, unity_rot.w)
		var godot_scale = Vector3(unity_scale.x, unity_scale.y, unity_scale.z)
		
		# Ground the object using the heightmap if available
		godot_pos.y = get_height_at(godot_pos.x, godot_pos.z)
		
		# Find Godot asset
		var asset_path = ASSET_MAP.get(prefab_name, "")
		
		# Generic fallbacks
		if asset_path == "":
			if "tree" in lname or "conifer" in lname:
				asset_path = ASSET_MAP["Tree_Conifer"]
			elif "bush" in lname:
				asset_path = ASSET_MAP["Bush"]
		
		var node: Node3D
		# PNG billboard check FIRST — trees and bushes use billboard sprites
		if asset_path != "" and asset_path.ends_with(".png"):
			var sprite = Sprite3D.new()
			var tex = load(asset_path)
			if tex:
				sprite.texture = tex
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.double_sided = true
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			if "tree" in lname or "conifer" in lname:
				sprite.pixel_size = 0.022
			elif "bush" in lname:
				sprite.pixel_size = 0.006
			else:
				sprite.pixel_size = 0.01
			node = sprite
		elif asset_path != "" and (asset_path.ends_with(".tscn") or asset_path.ends_with(".glb")):
			var scene = load(asset_path)
			if scene:
				node = scene.instantiate()

		# Fallback — always create something so node is never null
		if not node:
			var mi = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(1, 2, 1)
			mi.mesh = box
			var mat = StandardMaterial3D.new()
			if "tree" in lname or "conifer" in lname or "bush" in lname:
				mat.albedo_color = Color(0.2, 0.5, 0.2)
			elif "build" in lname or "house" in lname or "hotel" in lname:
				mat.albedo_color = Color(0.7, 0.65, 0.55)
			else:
				mat.albedo_color = Color(0.6, 0.55, 0.5)
			mi.material_override = mat
			node = mi

		container.add_child(node)
		node.global_position = godot_pos
		node.quaternion = godot_quat
		node.scale = godot_scale
		count += 1
