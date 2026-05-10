# alphamap_reader.gd
# Terrain surface alphamap reader for Open World Golf
# 
# PURPOSE:
#   1. VISUAL  — provides blend weights for terrain shader to mix surface textures
#   2. GAMEPLAY — detects surface type at any world position for shot/ball physics
#
# USAGE:
#   Drop this file into res://
#   In terrain_generator.gd _ready() or after OWG terrain loads:
#
#     var amap = AlphamapReader.new()
#     amap.load_alphamaps("user://courses/OWG-The-Old-Course/terrain/splat/",
#                         "user://courses/OWG-The-Old-Course/terrain/splat/splat_layers.json",
#                          terrain_size_x, terrain_size_z)
#
#   Surface detection (for ball.gd):
#     var surface = amap.get_surface_at(ball_world_x, ball_world_z)
#     # returns "fairway", "rough", "bunker", "green", "deep_rough", "water" etc
#
#   Blend weights (for terrain shader):
#     var weights = amap.get_blend_weights(world_x, world_z)
#     # returns Dictionary { "fairway": 0.8, "rough": 0.2, "bunker": 0.0 ... }
#
# COORDINATE SYSTEM:
#   Matches terrain_generator.gd UV mapping:
#     u = -world_x / terrain_size_x
#     v =  world_z / terrain_size_z
#
# SURFACE TYPE STRINGS (match ball.gd landing_surface values):
#   "fairway", "rough", "deep_rough", "bunker", "green",
#   "fringe", "water", "tee", "path", "unknown"

extends Node
class_name AlphamapReader

# ─────────────────────────────────────────────
#  Internal state
# ─────────────────────────────────────────────

# Array of Image objects, one per splat layer
var _alphamaps: Array[Image] = []

# Array of surface type strings, parallel to _alphamaps
# e.g. ["fairway", "rough", "bunker", "green"]
var _surface_types: Array[String] = []

# Terrain world dimensions (from terrain_meta.json)
var _terrain_size_x: float = 2271.0
var _terrain_size_z: float = 2271.0

# Whether alphamaps loaded successfully
var _loaded: bool = false

# Fallback surface when no alphamap data available
const FALLBACK_SURFACE = "fairway"

# Priority order when two layers have equal weight
# Higher index = higher priority
const SURFACE_PRIORITY = {
	"unknown":    0,
	"path":       1,
	"water":      2,
	"tee":        3,
	"fringe":     4,
	"fairway":    5,
	"rough":      6,
	"deep_rough": 7,
	"bunker":     8,
	"green":      9,
}


# ─────────────────────────────────────────────
#  Loading
# ─────────────────────────────────────────────

func load_alphamaps(splat_dir: String, layers_json_path: String,
					terrain_size_x: float, terrain_size_z: float) -> bool:
	"""
	Load alphamap PNGs and layer metadata from the OWG course package.
	Call this after terrain loads, before any surface queries.
	
	splat_dir:        path to directory containing alphamap_0.png, alphamap_1.png ...
	layers_json_path: path to splat_layers.json (written by converter)
	terrain_size_x/z: world size of terrain in metres
	"""
	_alphamaps.clear()
	_surface_types.clear()
	_loaded = false
	_terrain_size_x = terrain_size_x
	_terrain_size_z = terrain_size_z

	# Load layer metadata
	var layers = _load_layers_json(layers_json_path)
	if layers.is_empty():
		push_warning("AlphamapReader: No layer data found at %s" % layers_json_path)
		return false

	# Load each alphamap PNG
	var loaded_count = 0
	for layer in layers:
		var idx          = layer.get("index", loaded_count)
		var surface_type = layer.get("surface_type", "unknown")
		var png_path     = splat_dir.path_join("alphamap_%d.png" % idx)

		var img = _load_image(png_path)
		if img:
			_alphamaps.append(img)
			_surface_types.append(surface_type)
			loaded_count += 1
			print("AlphamapReader: Layer %d = '%s' (%dx%d)" % [
				idx, surface_type, img.get_width(), img.get_height()])
		else:
			push_warning("AlphamapReader: Could not load alphamap_%d.png — layer '%s' skipped" % [
				idx, surface_type])

	if loaded_count == 0:
		push_warning("AlphamapReader: No alphamaps loaded from %s" % splat_dir)
		return false

	_loaded = true
	print("AlphamapReader: Loaded %d alphamap layer(s) — surface detection active" % loaded_count)
	return true


func _load_layers_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("AlphamapReader: splat_layers.json not found at %s" % path)
		return []
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_warning("AlphamapReader: Could not open %s" % path)
		return []
	var json = JSON.new()
	var err  = json.parse(f.get_as_text())
	f.close()
	if err != OK:
		push_warning("AlphamapReader: JSON parse error in %s" % path)
		return []
	var data = json.get_data()
	if data is Array:
		return data
	push_warning("AlphamapReader: splat_layers.json root is not an Array")
	return []


func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_warning("AlphamapReader: Failed to load image %s (error %d)" % [path, err])
		return null
	# Convert to RGBA for consistent pixel sampling
	img.convert(Image.FORMAT_RGBA8)
	return img


# ─────────────────────────────────────────────
#  Core UV mapping
#  Matches terrain_generator.gd convention:
#    u = -world_x / terrain_size_x
#    v =  world_z / terrain_size_z
# ─────────────────────────────────────────────

func _world_to_uv(world_x: float, world_z: float) -> Vector2:
	var u = clamp(-world_x / _terrain_size_x, 0.0, 1.0)
	var v = clamp( world_z / _terrain_size_z, 0.0, 1.0)
	return Vector2(u, v)


func _sample_alphamap(img: Image, uv: Vector2) -> float:
	"""Sample a single alphamap at UV coordinates. Returns 0.0–1.0."""
	var px = int(uv.x * (img.get_width()  - 1))
	var py = int(uv.y * (img.get_height() - 1))
	px = clamp(px, 0, img.get_width()  - 1)
	py = clamp(py, 0, img.get_height() - 1)
	# Red channel holds the blend weight
	return img.get_pixel(px, py).r


# ─────────────────────────────────────────────
#  Public API — Gameplay
# ─────────────────────────────────────────────

func get_surface_at(world_x: float, world_z: float) -> String:
	"""
	Return the dominant surface type at a world position.
	Used by ball.gd to determine landing_surface for shot modifiers.
	
	Returns one of: "fairway", "rough", "deep_rough", "bunker", "green",
	                "fringe", "water", "tee", "path", "unknown"
	"""
	if not _loaded or _alphamaps.is_empty():
		return FALLBACK_SURFACE

	var uv = _world_to_uv(world_x, world_z)

	var best_surface = "unknown"
	var best_weight  = 0.0
	var best_priority = -1

	for i in range(_alphamaps.size()):
		var weight   = _sample_alphamap(_alphamaps[i], uv)
		var surface  = _surface_types[i]
		var priority = SURFACE_PRIORITY.get(surface, 0)

		# Pick highest weight; break ties by priority
		if weight > best_weight or (weight == best_weight and priority > best_priority):
			best_weight   = weight
			best_surface  = surface
			best_priority = priority

	# If all weights are near zero, default to rough (off-course area)
	if best_weight < 0.05:
		return "rough"

	return best_surface


func get_surface_weight(world_x: float, world_z: float, surface_type: String) -> float:
	"""
	Return the blend weight (0.0–1.0) of a specific surface type at world position.
	Useful for partial surface effects (e.g. ball on edge of bunker).
	"""
	if not _loaded:
		return 0.0

	var uv = _world_to_uv(world_x, world_z)

	for i in range(_alphamaps.size()):
		if _surface_types[i] == surface_type:
			return _sample_alphamap(_alphamaps[i], uv)

	return 0.0


func is_on_surface(world_x: float, world_z: float, surface_type: String,
				   threshold: float = 0.5) -> bool:
	"""
	Quick check: is this position predominantly a given surface type?
	threshold: minimum weight to count as 'on' that surface (default 0.5)
	"""
	return get_surface_weight(world_x, world_z, surface_type) >= threshold


# ─────────────────────────────────────────────
#  Public API — Visual (terrain shader)
# ─────────────────────────────────────────────

func get_blend_weights(world_x: float, world_z: float) -> Dictionary:
	"""
	Return all surface blend weights at a world position.
	Used by terrain shader to mix surface textures.
	
	Returns: { "fairway": 0.8, "rough": 0.15, "bunker": 0.05, ... }
	"""
	var weights = {}

	if not _loaded:
		weights[FALLBACK_SURFACE] = 1.0
		return weights

	var uv    = _world_to_uv(world_x, world_z)
	var total = 0.0

	for i in range(_alphamaps.size()):
		var w = _sample_alphamap(_alphamaps[i], uv)
		weights[_surface_types[i]] = w
		total += w

	# Normalise so weights sum to 1.0
	if total > 0.0:
		for key in weights:
			weights[key] /= total
	else:
		weights[FALLBACK_SURFACE] = 1.0

	return weights


func get_blend_array(world_x: float, world_z: float) -> PackedFloat32Array:
	"""
	Return blend weights as a flat float array, in layer order.
	Useful for passing directly to a shader uniform.
	"""
	var arr = PackedFloat32Array()
	arr.resize(_alphamaps.size())

	if not _loaded:
		return arr

	var uv    = _world_to_uv(world_x, world_z)
	var total = 0.0

	for i in range(_alphamaps.size()):
		var w  = _sample_alphamap(_alphamaps[i], uv)
		arr[i] = w
		total += w

	# Normalise
	if total > 0.0:
		for i in range(arr.size()):
			arr[i] /= total

	return arr


# ─────────────────────────────────────────────
#  Utility / Debug
# ─────────────────────────────────────────────

func is_loaded() -> bool:
	return _loaded


func get_layer_count() -> int:
	return _alphamaps.size()


func get_surface_types() -> Array[String]:
	return _surface_types.duplicate()


func debug_position(world_x: float, world_z: float) -> String:
	"""
	Return a human-readable debug string for a world position.
	Call from ball.gd or player.gd during testing.
	
	Example output:
	  "Surface: FAIRWAY (w=0.87) | rough=0.10 bunker=0.03"
	"""
	if not _loaded:
		return "AlphamapReader: not loaded"

	var uv      = _world_to_uv(world_x, world_z)
	var surface = get_surface_at(world_x, world_z)
	var weights = get_blend_weights(world_x, world_z)

	var parts = []
	for key in weights:
		if weights[key] > 0.02:
			parts.append("%s=%.2f" % [key, weights[key]])

	return "Surface: %s | uv=(%.3f,%.3f) | %s" % [
		surface.to_upper(), uv.x, uv.y, " ".join(parts)]


func print_debug(world_x: float, world_z: float) -> void:
	"""Print surface debug info — call from ball.gd _on_ball_stopped() during testing."""
	print("AlphamapReader: ", debug_position(world_x, world_z))
