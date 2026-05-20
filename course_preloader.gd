extends Node
## CoursePreloader — runs after AssetStager completes.
## Loads the heightmap, textures, and splatmap into memory-ready objects
## and caches them in GameState so main.gd has zero load work to do.
##
## Called by AssetStager.stage_course() — do not call directly.

signal preload_complete()
signal preload_progress(step: String, percent: float)

const RT_HEIGHTMAP    = "user://runtime/heightmap.png"
const RT_TERRAIN_META = "user://runtime/terrain_meta.json"
const RT_TEXTURE_MAP  = "user://runtime/texture_map.json"
const RT_TEXTURES_DIR = "user://runtime/textures/"
const RT_SPLAT_DIR    = "user://runtime/splat/"


func preload_course(course_data: Dictionary) -> void:
	emit_signal("preload_progress", "Loading heightmap...", 0.85)

	# 1. Heightmap image — convert to FORMAT_RF so get_pixel().r is 0..1
	var hm_img = Image.load_from_file(ProjectSettings.globalize_path(RT_HEIGHTMAP))
	if hm_img:
		if hm_img.get_format() != Image.FORMAT_RF:
			hm_img.convert(Image.FORMAT_RF)
		GameState.preloaded_heightmap = hm_img
		print("CoursePreloader: heightmap loaded %dx%d fmt=%d" % [hm_img.get_width(), hm_img.get_height(), hm_img.get_format()])
	else:
		push_warning("CoursePreloader: heightmap not found")

	# 2. Terrain meta
	emit_signal("preload_progress", "Reading terrain data...", 0.88)
	var meta = _load_json(RT_TERRAIN_META)
	GameState.preloaded_terrain_meta = meta

	# 3. Texture map
	var texture_map = _load_json(RT_TEXTURE_MAP)

	# 4. Load surface textures into ImageTexture objects
	emit_signal("preload_progress", "Loading surface textures...", 0.90)
	var textures = {}
	var surface_keys = {
		"fairway": ["fairway", "tee"],
		"rough":   ["rough"],
		"green":   ["green"],
		"bunker":  ["bunker"],
		"sand":    ["sand", "path"],
	}
	for surface in surface_keys:
		for key in surface_keys[surface]:
			if key in texture_map:
				var path = RT_TEXTURES_DIR + texture_map[key]
				var img = Image.load_from_file(ProjectSettings.globalize_path(path))
				if img:
					img.generate_mipmaps()
					textures[surface] = ImageTexture.create_from_image(img)
					break
		# Placeholder if still missing
		if surface not in textures:
			textures[surface] = _make_placeholder(_placeholder_color(surface))
	GameState.preloaded_textures = textures
	print("CoursePreloader: %d surface textures ready" % textures.size())

	# 5. Splatmap
	emit_signal("preload_progress", "Loading splatmap...", 0.93)
	var splat_tex = null
	var splat_img = null
	var sd = DirAccess.open(RT_SPLAT_DIR)
	if sd:
		sd.list_dir_begin()
		var fn = sd.get_next()
		while fn != "":
			if "alphamap_0" in fn.to_lower():
				var img = Image.load_from_file(ProjectSettings.globalize_path(RT_SPLAT_DIR + fn))
				if img:
					img.generate_mipmaps()
					splat_img = img
					splat_tex = ImageTexture.create_from_image(img)
					print("CoursePreloader: splatmap ready — ", fn)
					break
			fn = sd.get_next()
	GameState.preloaded_splatmap     = splat_tex
	GameState.preloaded_splatmap_img = splat_img

	# 6. Cache hole 1 tee/pin positions
	emit_signal("preload_progress", "Calculating start position...", 0.96)
	_cache_hole_positions(course_data)

	emit_signal("preload_progress", "Ready to play!", 1.0)
	emit_signal("preload_complete")


func _cache_hole_positions(course_data: Dictionary) -> void:
	var holes_cache = {}
	for hole in course_data.get("holes", []):
		var hole_num = hole.get("hole_number", 0)
		var tee_pos = Vector3.ZERO
		var pin_pos = Vector3.ZERO
		var par = 4
		for tee in hole.get("tees", []):
			if tee.get("type") == "Championship":
				var p = tee.get("position", {})
				tee_pos = Vector3(p.get("x",0), p.get("y",0), p.get("z",0))
				par = int(str(tee.get("par","4")).replace("_",""))
				break
		if tee_pos == Vector3.ZERO and hole.get("tees", []).size() > 0:
			var p = hole["tees"][0].get("position", {})
			tee_pos = Vector3(p.get("x",0), p.get("y",0), p.get("z",0))
		var pins = hole.get("pins", [])
		if pins.size() > 0:
			var p = pins[0].get("position", {})
			pin_pos = Vector3(p.get("x",0), p.get("y",0), p.get("z",0))
		holes_cache[hole_num] = {
			"tee": tee_pos, "pin": pin_pos, "par": par,
			"tees_raw": hole.get("tees", []),
			"pins_raw": hole.get("pins", []),
			"shots_raw": hole.get("shots", []),
		}
	GameState.preloaded_holes = holes_cache
	print("CoursePreloader: %d holes cached" % holes_cache.size())


func _load_json(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	return json.get_data()


func _make_placeholder(color: Color) -> ImageTexture:
	var img = Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _placeholder_color(surface: String) -> Color:
	match surface:
		"fairway": return Color(0.25, 0.55, 0.20)
		"green":   return Color(0.15, 0.65, 0.22)
		"rough":   return Color(0.30, 0.42, 0.18)
		"bunker":  return Color(0.78, 0.68, 0.42)
		"sand":    return Color(0.82, 0.74, 0.50)
	return Color(0.4, 0.4, 0.4)
