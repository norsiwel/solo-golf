extends Node
## AssetStager — Autoload
## After a course loads, call stage_course(course_data) to copy all
## assets into user://runtime/ so the rest of the game always reads
## from fixed, known paths regardless of which course is active.
##
## Add to Project Settings → Autoloads as "AssetStager"

const RUNTIME_DIR       = "user://runtime/"
const RT_TEXTURES_DIR   = "user://runtime/textures/"
const RT_SPLAT_DIR      = "user://runtime/splat/"
const RT_HEIGHTMAP      = "user://runtime/heightmap.png"
const RT_TERRAIN_META   = "user://runtime/terrain_meta.json"
const RT_COURSE_JSON    = "user://runtime/course.json"
const RT_TEXTURE_MAP    = "user://runtime/texture_map.json"

signal staging_complete()
signal staging_failed(reason: String)

var is_staged: bool = false
var _current_course_data: Dictionary = {}


func _ready() -> void:
	_ensure_dirs()


func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RT_TEXTURES_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RT_SPLAT_DIR))


## Main entry point — call this right after CourseLoader emits course_ready.
func stage_course(course_data: Dictionary) -> void:
	is_staged = false
	_current_course_data = course_data
	_ensure_dirs()

	var extract_path: String = course_data.get("extract_path", "")
	if extract_path == "":
		emit_signal("staging_failed", "course_data has no extract_path")
		return

	print("AssetStager: staging from ", extract_path)

	# 1. course.json
	_copy_file(extract_path + "course.json", RT_COURSE_JSON)

	# 2. Heightmap
	var hm_src = extract_path + "terrain/heightmap.png"
	if FileAccess.file_exists(hm_src):
		_copy_file(hm_src, RT_HEIGHTMAP)
	else:
		push_warning("AssetStager: heightmap not found at " + hm_src)

	# 3. Terrain meta
	var tm_src = extract_path + "terrain/terrain_meta.json"
	if FileAccess.file_exists(tm_src):
		_copy_file(tm_src, RT_TERRAIN_META)

	# 4. Splatmaps — copy all alphamap_N.png from terrain/splat/
	_clear_dir(RT_SPLAT_DIR)
	var splat_src = extract_path + "terrain/splat/"
	var sd = DirAccess.open(splat_src)
	if sd:
		sd.list_dir_begin()
		var fn = sd.get_next()
		while fn != "":
			if fn.ends_with(".png") or fn.ends_with(".json"):
				_copy_file(splat_src + fn, RT_SPLAT_DIR + fn)
			fn = sd.get_next()
		sd.list_dir_end()
		print("AssetStager: splatmaps staged from ", splat_src)
	else:
		push_warning("AssetStager: no terrain/splat/ folder in extracted course")

	# 5. Textures — copy ALL pngs from textures/
	_clear_dir(RT_TEXTURES_DIR)
	var tex_src = extract_path + "textures/"
	var td = DirAccess.open(tex_src)
	if td:
		var count = 0
		td.list_dir_begin()
		var tfn = td.get_next()
		while tfn != "":
			if tfn.ends_with(".png") or tfn.ends_with(".jpg") or tfn.ends_with(".json"):
				_copy_file(tex_src + tfn, RT_TEXTURES_DIR + tfn)
				count += 1
			tfn = td.get_next()
		td.list_dir_end()
		print("AssetStager: %d texture files staged" % count)
	else:
		push_warning("AssetStager: no textures/ folder in extracted course")

	# 6. Build a clean texture_map.json at runtime/texture_map.json
	#    by scanning what's actually present and classifying by filename
	_build_texture_map()

	is_staged = true
	print("AssetStager: staging complete ✓")

	# Hand off to CoursePreloader singleton to load assets into memory
	CoursePreloader.preload_progress.connect(func(step, pct):
		emit_signal("staging_complete")
	, CONNECT_ONE_SHOT)
	CoursePreloader.preload_complete.connect(func():
		emit_signal("staging_complete")
	, CONNECT_ONE_SHOT)
	CoursePreloader.preload_course(_current_course_data)


## Build texture_map.json AND a splat_channel_map.json that maps
## surface types to specific splatmap+channel combos from splat_layers.json
func _build_texture_map() -> void:
	var td = DirAccess.open(RT_TEXTURES_DIR)
	if not td:
		return

	var files: Dictionary = {}
	td.list_dir_begin()
	var fn = td.get_next()
	while fn != "":
		if fn.ends_with(".png"):
			files[fn.to_lower()] = fn
		fn = td.get_next()
	td.list_dir_end()

	var candidates: Dictionary = {
		"fairway":  ["o_fairwayplain", "fairwayplain", "fairway2", "fairway",
					 "skygrass_fair", "base_fairway"],
		"rough":    ["o_rough2desat", "terrainrough", "meshlightrough",
					 "rough2", "rough1", "base_rough"],
		"green":    ["pickupgreen", "skygrass_green", "o_greenfringe",
					 "greenfringe", "green.png"],
		"bunker":   ["bunkersandoverhead2", "bunkersandrake", "bunkersandoverhead",
					 "bunkerdirt", "bunker"],
		"sand":     ["bunkersod", "wood_sand", "sand"],
		"path":     ["gravelpathplain", "gravelpath", "gravel", "cartpath", "path"],
		"tee":      ["teered", "tee_surface", "tee"],
		"water":    ["pp_watertexture", "water_surface", "water"],
		"fairway_normal": ["grass_normal_1", "grass_normal", "fairway_normal"],
		"rough_normal":   ["grass_normal_3", "grass_normal_2", "rough_normal"],
	}

	var result: Dictionary = {}
	for surface in candidates:
		for keyword in candidates[surface]:
			var found = _find_file_with(files, keyword)
			if found != "":
				result[surface] = found
				break

	# Also read splat_layers.json to build channel map
	# Maps surface type to {alphamap, channel} so shader knows which splat to sample
	var splat_channel_map = _build_splat_channel_map(result)

	var f = FileAccess.open(RT_TEXTURE_MAP, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()
		print("AssetStager: texture_map built — ", result)

	var f2 = FileAccess.open(RUNTIME_DIR + "splat_channel_map.json", FileAccess.WRITE)
	if f2:
		f2.store_string(JSON.stringify(splat_channel_map, "\t"))
		f2.close()
		print("AssetStager: splat_channel_map — ", splat_channel_map)


func _build_splat_channel_map(texture_map: Dictionary) -> Dictionary:
	# Read splat_layers.json to find which alphamap/channel has fairway, rough, green, bunker
	var layers_path = RT_SPLAT_DIR + "splat_layers.json"
	var f = FileAccess.open(layers_path, FileAccess.READ)
	if not f:
		# Default mapping — assume standard PG layout
		return {"fairway": {"map": 0, "ch": 0}, "rough": {"map": 0, "ch": 1},
				"green": {"map": 0, "ch": 2}, "bunker": {"map": 0, "ch": 3}}

	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		return {}
	f.close()
	var layers = json.get_data()

	# surface_type keywords → our surface names
	var type_map = {
		"fairway": "fairway", "fair": "fairway", "tee": "fairway",
		"rough": "rough", "deep_rough": "rough",
		"green": "green", "fringe": "green",
		"bunker": "bunker", "sand": "bunker",
		"water": "water", "path": "path",
	}
	# texture name keywords as fallback
	var name_map = {
		"fairway": "fairway", "fairwayplain": "fairway", "skygrass_fair": "fairway",
		"rough": "rough", "terrainrough": "rough", "meshlightrough": "rough",
		"green": "green", "pickupgreen": "green", "greenfringe": "green",
		"bunker": "bunker", "bunkersand": "bunker", "bunkerdirt": "bunker",
	}

	var result = {}
	for layer in layers:
		var idx: int = layer.get("index", 0)
		var alphamap_idx = idx / 4
		var channel_idx  = idx % 4

		# Layer 0 with full-terrain tile size = satellite/overhead photo → mark as "base"
		var tile_x = layer.get("tile_size_x", 5.0)
		if idx == 0 and tile_x > 100.0:
			if "base" not in result:
				result["base"] = {"map": alphamap_idx, "ch": channel_idx}
			continue  # don't classify as a surface type

		# Try surface_type first
		var stype = layer.get("surface_type", "unknown").to_lower()
		var surface = type_map.get(stype, "")

		# Fall back to texture name matching
		if surface == "":
			var tname = layer.get("texture_name", "").to_lower()
			for key in name_map:
				if key in tname:
					surface = name_map[key]
					break

		# For duplicate surface entries, keep the one with more coverage (higher index = later layer usually wins)
		if surface != "":
			result[surface] = {"map": alphamap_idx, "ch": channel_idx}

	return result


## Find first file whose lowercase name contains the keyword substring.
func _find_file_with(files: Dictionary, keyword: String) -> String:
	for key in files:
		if keyword in key:
			return files[key]
	return ""


## Copy a file from src to dst (both user:// or res:// paths are fine).
func _copy_file(src: String, dst: String) -> void:
	var gsrc = ProjectSettings.globalize_path(src)
	var gdst = ProjectSettings.globalize_path(dst)
	DirAccess.make_dir_recursive_absolute(gdst.get_base_dir())
	var fa = FileAccess.open(src, FileAccess.READ)
	if not fa:
		fa = FileAccess.open(gsrc, FileAccess.READ)
	if not fa:
		push_warning("AssetStager: cannot read " + src)
		return
	var data = fa.get_buffer(fa.get_length())
	fa.close()
	var fw = FileAccess.open(dst, FileAccess.WRITE)
	if not fw:
		fw = FileAccess.open(gdst, FileAccess.WRITE)
	if not fw:
		push_warning("AssetStager: cannot write " + dst)
		return
	fw.store_buffer(data)
	fw.close()


## Remove all files in a user:// directory (not recursive).
func _clear_dir(dir_path: String) -> void:
	var d = DirAccess.open(dir_path)
	if not d:
		return
	d.list_dir_begin()
	var fn = d.get_next()
	while fn != "":
		if not d.current_is_dir():
			d.remove(fn)
		fn = d.get_next()
	d.list_dir_end()
