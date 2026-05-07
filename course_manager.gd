extends Node

signal course_loaded(course_name: String, meta: Dictionary)
signal hole_changed(hole_number: int, par: int, yardage: int)

var current_course_name := ""
var current_hole := 0
var course_meta := {}
var available_courses: Array[String] = []

# OWG zip-based loader — populated when coming from CourseSelectScreen
var owg_loader: CourseLoader

func _ready():
	_scan_courses()
	# OWG path: if CourseSelectScreen already loaded a course, set it up
	if not GameState.current_course.is_empty():
		_setup_from_owg_data(GameState.current_course)

func _scan_courses():
	available_courses.clear()
	var dir = DirAccess.open("res://courses/")
	if not dir:
		push_warning("CourseManager: Cannot open res://courses/")
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with("_meta.json"):
			available_courses.append(fname.replace("_meta.json", ""))
		fname = dir.get_next()
	dir.list_dir_end()
	print("CourseManager: Found %d courses: %s" % [available_courses.size(), str(available_courses)])

func get_available_courses() -> Array[String]:
	return available_courses

func load_course(course_name: String) -> bool:
	var meta_path = "res://courses/%s_meta.json" % course_name
	if not FileAccess.file_exists(meta_path):
		push_error("CourseManager: No metadata for %s" % course_name)
		return false
	var f = FileAccess.open(meta_path, FileAccess.READ)
	if not f:
		push_error("CourseManager: Cannot open %s" % meta_path)
		return false
	var json = JSON.new()
	var err = json.parse(f.get_as_text())
	f.close()
	if err != OK:
		push_error("CourseManager: JSON parse error for %s" % course_name)
		return false
	course_meta = json.get_data()
	current_course_name = course_name
	current_hole = 1
	_normalize_positions()
	emit_signal("course_loaded", course_name, course_meta)
	print("CourseManager: Loaded %s" % course_meta.get("name", course_name))
	return true

func _normalize_positions():
	# Offset all positions so hole 1 tee is at world origin X=0, Z=0
	# Flatten Y to ground level — terrain will handle elevation later
	var holes = course_meta.get("holes", [])
	if holes.is_empty():
		return
	var h1_tee = holes[0].get("tee", {})
	var origin_x = h1_tee.get("x", 0.0)
	var origin_z = h1_tee.get("z", 0.0)
	print("CourseManager: Origin offset X=%.1f Z=%.1f" % [origin_x, origin_z])
	for hole in holes:
		_offset_pos(hole.get("tee", {}), origin_x, origin_z)
		_offset_pos(hole.get("pin", {}), origin_x, origin_z)
		for t in hole.get("all_tees", []):
			_offset_pos(t.get("position", {}), origin_x, origin_z)
		for p in hole.get("all_pins", []):
			_offset_pos(p.get("position", {}), origin_x, origin_z)

func _offset_pos(pos: Dictionary, ox: float, oz: float):
	if pos.is_empty():
		return
	pos["x"] = pos.get("x", 0.0) - ox
	pos["z"] = pos.get("z", 0.0) - oz
	pos["y"] = 0.1  # ground level — terrain elevation applied later

func get_hole_data(hole_number: int) -> Dictionary:
	if course_meta.is_empty():
		return {}
	for h in course_meta.get("holes", []):
		if h.get("hole", 0) == hole_number:
			return h
	return {}

func go_to_hole(hole_number: int) -> Dictionary:
	var hole = get_hole_data(hole_number)
	if hole.is_empty():
		return {}
	current_hole = hole_number
	emit_signal("hole_changed", hole_number, hole.get("par", 4), hole.get("yardage", 0))
	return hole

func get_tee_position(hole_number: int) -> Vector3:
	var hole = get_hole_data(hole_number)
	if hole.is_empty():
		return Vector3.ZERO
	var tee = hole.get("tee", {})
	return Vector3(tee.get("x", 0), tee.get("y", 0.1), tee.get("z", 0))

func get_pin_position(hole_number: int) -> Vector3:
	var hole = get_hole_data(hole_number)
	if hole.is_empty():
		return Vector3.ZERO
	var pin = hole.get("pin", {})
	return Vector3(pin.get("x", 0), pin.get("y", 0.1), pin.get("z", 0))

func get_total_holes() -> int:
	return course_meta.get("holes", []).size()

func get_course_name() -> String:
	return course_meta.get("name", current_course_name)


# ── OWG ZIP-based loading ──────────────────────────────────────────────────

## Called when a course was loaded by CourseSelectScreen via CourseLoader.
## Passes the extracted heightmap to TerrainGenerator, then triggers build_from_hole()
## so the walkable mesh and HeightMapShape3D collision are constructed at runtime.
## Node paths assume CourseManager is a child of the main scene root.
func _setup_from_owg_data(course_data: Dictionary) -> void:
	var scene_root = get_parent()
	var hole_terrain = scene_root.get_node_or_null("HoleTerrain")

	# Load heightmap into TerrainGenerator so _sample_real_height() uses OWG data
	var heightmap_path = course_data.get("heightmap_path", "")
	if heightmap_path != "":
		if hole_terrain and hole_terrain.has_method("load_heightmap"):
			hole_terrain.load_heightmap(heightmap_path)
		else:
			push_warning("CourseManager: HoleTerrain missing or has no load_heightmap()")
	else:
		push_warning("CourseManager: OWG course has no heightmap_path in course_data")

	# Get hole 1 championship tee and first pin to define the terrain bounds
	var tee_pos = _owg_get_tee_vec3(course_data, 1, "Championship")
	var pins = _owg_get_pins(course_data, 1)
	var pin_pos = pins[0].position if pins.size() > 0 else Vector3.ZERO

	# Build walkable terrain mesh + HeightMapShape3D collision from the loaded heightmap
	if hole_terrain and hole_terrain.has_method("build_from_hole"):
		var all_tees_raw: Array = []
		var all_pins_raw: Array = []
		for hole in course_data.get("holes", []):
			if hole.get("hole_number") == 1:
				for t in hole.get("tees", []):
					all_tees_raw.append(t.get("position", {}))
				for p in hole.get("pins", []):
					all_pins_raw.append(p.get("position", {}))
				break
		hole_terrain.build_from_hole(tee_pos, pin_pos, all_tees_raw, all_pins_raw)

	print("CourseManager: OWG terrain built — ", course_data.get("name", "Unknown"))


func _owg_get_tee_vec3(course_data: Dictionary, hole_num: int, tee_type: String) -> Vector3:
	for hole in course_data.get("holes", []):
		if hole.get("hole_number") == hole_num:
			for tee in hole.get("tees", []):
				if tee.get("type") == tee_type:
					var p = tee.get("position", {})
					return Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
	return Vector3.ZERO


func _owg_get_pins(course_data: Dictionary, hole_num: int) -> Array:
	for hole in course_data.get("holes", []):
		if hole.get("hole_number") == hole_num:
			var pins = []
			for pin in hole.get("pins", []):
				var p = pin.get("position", {})
				pins.append({
					"position": Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0)),
					"difficulty": pin.get("difficulty", "Medium")
				})
			return pins
	return []
