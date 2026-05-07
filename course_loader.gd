extends Node
class_name CourseLoader

signal course_ready(course_data: Dictionary)
signal load_progress(step: String, percent: float)
signal load_failed(reason: String)

const COURSES_DIR = "res://courses/"
const EXTRACT_DIR = "user://courses/"

var current_course: Dictionary = {}


## Scan the courses directory and return a list of available courses.
## Returns Array of Dicts: [{name, zip_path, splash_name, hole_count, author, terrain_size}]
func scan_available_courses() -> Array:
	var courses = []
	var dir = DirAccess.open(COURSES_DIR)
	if not dir:
		push_error("CourseLoader: courses directory not found at " + COURSES_DIR)
		return courses

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".zip") and file_name.begins_with("OWG-"):
			var zip_path = COURSES_DIR + file_name
			var info = _peek_course_zip(zip_path)
			if not info.is_empty():
				courses.append(info)
		file_name = dir.get_next()
	dir.list_dir_end()

	courses.sort_custom(func(a, b): return a.name < b.name)
	return courses


## Peek inside a zip to get course metadata without full extraction.
func _peek_course_zip(zip_path: String) -> Dictionary:
	var reader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		push_error("CourseLoader: Cannot open " + zip_path)
		return {}

	if not reader.file_exists("course.json"):
		reader.close()
		return {}

	var json_bytes = reader.read_file("course.json")
	reader.close()

	var json = JSON.new()
	if json.parse(json_bytes.get_string_from_utf8()) != OK:
		return {}

	var data = json.get_data()
	return {
		"name": data.get("name", "Unknown"),
		"author": data.get("author", ""),
		"hole_count": data.get("hole_count", 18),
		"zip_path": zip_path,
		"zip_name": zip_path.get_file(),
		"splash_name": data.get("splash_image", ""),
		"terrain_size": data.get("terrain", {}).get("terrain_size_x", 0),
	}


## Main entry point — load a course from its zip path.
## Emits course_ready(course_data) on success, load_failed(reason) on error.
func load_course(zip_path: String) -> void:
	emit_signal("load_progress", "Opening course package...", 0.0)

	var reader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		emit_signal("load_failed", "Cannot open: " + zip_path)
		return

	var zip_name = zip_path.get_file().get_basename()
	var extract_path = EXTRACT_DIR + zip_name + "/"

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(extract_path)
	)

	emit_signal("load_progress", "Reading course data...", 0.1)

	if not reader.file_exists("course.json"):
		emit_signal("load_failed", "Missing course.json in " + zip_path)
		reader.close()
		return

	var json_bytes = reader.read_file("course.json")
	_write_file(extract_path + "course.json", json_bytes)

	var json = JSON.new()
	if json.parse(json_bytes.get_string_from_utf8()) != OK:
		emit_signal("load_failed", "Invalid course.json")
		reader.close()
		return

	current_course = json.get_data()
	emit_signal("load_progress", "Loading terrain...", 0.2)

	# Option B (active): baked terrain scene — StaticBody3D + mesh + collision
	# authored in the Godot editor and saved as terrain/terrain.scn inside the ZIP.
	# Option A (fallback): raw float array at terrain/heightmap.f32 — if B proves
	# unworkable, swap to reading that file and feeding bytes directly into
	# HeightMapShape3D.map_data without the Godot import pipeline.
	var terrain_scene_local = ""
	for candidate in ["terrain/terrain.scn", "terrain/terrain.tscn"]:
		if reader.file_exists(candidate):
			var ext = candidate.get_extension()
			var dest = extract_path + "terrain/terrain." + ext
			_write_file(dest, reader.read_file(candidate))
			terrain_scene_local = dest
			break

	if terrain_scene_local == "":
		push_warning("CourseLoader: no baked terrain scene found in " + zip_path)

	emit_signal("load_progress", "Loading splash...", 0.7)

	var splash = current_course.get("splash_image", "")
	if splash != "" and reader.file_exists("images/" + splash):
		var bytes = reader.read_file("images/" + splash)
		_write_file(extract_path + "images/" + splash, bytes)
		current_course["splash_local_path"] = extract_path + "images/" + splash

	reader.close()

	current_course["extract_path"] = extract_path
	current_course["terrain_scene_path"] = terrain_scene_local

	emit_signal("load_progress", "Ready!", 1.0)
	emit_signal("course_ready", current_course)


## Write bytes to a user:// path, creating directories as needed.
func _write_file(path: String, data: PackedByteArray) -> void:
	var global = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(global.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()


## Get the championship tee position for a hole (Godot Vector3).
func get_tee_position(hole_number: int, tee_type: String = "Championship") -> Vector3:
	if current_course.is_empty():
		return Vector3.ZERO
	for hole in current_course.get("holes", []):
		if hole.get("hole_number") == hole_number:
			for tee in hole.get("tees", []):
				if tee.get("type") == tee_type:
					var p = tee["position"]
					return Vector3(p.x, p.y, p.z)
	return Vector3.ZERO


## Get all pin positions for a hole with difficulty ratings.
func get_pin_positions(hole_number: int) -> Array:
	if current_course.is_empty():
		return []
	for hole in current_course.get("holes", []):
		if hole.get("hole_number") == hole_number:
			var pins = []
			for pin in hole.get("pins", []):
				var p = pin["position"]
				pins.append({
					"position": Vector3(p.x, p.y, p.z),
					"difficulty": pin.get("difficulty", "Medium")
				})
			return pins
	return []
