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
	emit_signal("load_progress", "Extracting assets...", 0.2)

	# Extract ALL files from the ZIP to the user directory
	var files = reader.get_files()
	for i in range(files.size()):
		var fpath = files[i]
		if fpath.ends_with("/"): # skip directories
			continue
		
		var bytes = reader.read_file(fpath)
		_write_file(extract_path + fpath, bytes)
		
		if i % 10 == 0:
			emit_signal("load_progress", "Extracting %d/%d..." % [i, files.size()], 0.2 + 0.5 * (float(i)/files.size()))

	# Set paths for specific known assets
	if FileAccess.file_exists(extract_path + "terrain/heightmap.png"):
		current_course["heightmap_path"] = extract_path + "terrain/heightmap.png"
	
	var splash = current_course.get("splash_image", "")
	if splash != "" and FileAccess.file_exists(extract_path + "images/" + splash):
		current_course["splash_local_path"] = extract_path + "images/" + splash

	reader.close()

	current_course["extract_path"] = extract_path

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


## Get all tee positions for a hole (sorted by difficulty/order)
func get_tee_positions(hole_number: int) -> Array:
	if current_course.is_empty():
		return []
	for hole in current_course.get("holes", []):
		if hole.get("hole_number") == hole_number:
			var tees = []
			for tee in hole.get("tees", []):
				var p = tee["position"]
				tees.append({
					"type": tee.get("type", "Unknown"),
					"position": Vector3(p.x, p.y, p.z),
					"par": tee.get("par", 4),
					"stroke_index": tee.get("stroke_index", 0),
				})
			return tees
	return []


## Get the championship tee position (most common use case)
func get_championship_tee(hole_number: int) -> Vector3:
	var tees = get_tee_positions(hole_number)
	for tee in tees:
		if tee.type == "Championship":
			return tee.position
	# Fallback to first tee if Championship not found
	if tees.size() > 0:
		return tees[0].position
	return Vector3.ZERO


## Get all pin positions for a hole with difficulty ratings
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
					"difficulty": pin.get("difficulty", "Medium"),
					"order": pin.get("order", 0),
				})
			# Sort by difficulty order
			pins.sort_custom(func(a, b): return a.order < b.order)
			return pins
	return []


## Get the par for a hole
func get_par(hole_number: int) -> int:
	var tees = get_tee_positions(hole_number)
	if tees.size() > 0:
		return tees[0].get("par", 4)
	return 4


## Get terrain heightmap path (for Terrain3D or custom terrain node)
func get_heightmap_path() -> String:
	return current_course.get("heightmap_path", "")


## Get terrain metadata
func get_terrain_meta() -> Dictionary:
	return current_course.get("terrain", {})


## Get all objects (trees, buildings, etc.) placed on the course
func get_course_objects() -> Array:
	return current_course.get("objects", [])


## Get water plane Y level (used for shaders and collision)
func get_water_level() -> float:
	var terrain_meta = get_terrain_meta()
	return terrain_meta.get("water_level", 0.0)


## Check if a course is currently loaded
func is_course_loaded() -> bool:
	return not current_course.is_empty()


## Unload the current course (free memory)
func unload_course() -> void:
	current_course = {}