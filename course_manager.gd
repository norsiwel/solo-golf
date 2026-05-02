extends Node

signal course_loaded(course_name: String, meta: Dictionary)
signal hole_changed(hole_number: int, par: int, yardage: int)

var current_course_name := ""
var current_hole := 0
var course_meta := {}
var available_courses: Array[String] = []

func _ready():
	_scan_courses()
	# Do NOT auto-load - wait for player to select from CourseSelector

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
			var course = fname.replace("_meta.json", "")
			available_courses.append(course)
		fname = dir.get_next()
	dir.list_dir_end()
	print("CourseManager: Found %d courses: %s" % [available_courses.size(), str(available_courses)])

func get_available_courses() -> Array[String]:
	return available_courses

func load_course(course_name: String) -> bool:
	var meta_path = "res://courses/%s_meta.json" % course_name
	if not FileAccess.file_exists(meta_path):
		push_error("CourseManager: No metadata found for %s" % course_name)
		return false

	var f = FileAccess.open(meta_path, FileAccess.READ)
	if not f:
		push_error("CourseManager: Could not open: %s" % meta_path)
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

	emit_signal("course_loaded", course_name, course_meta)
	print("CourseManager: Loaded metadata for %s" % course_meta.get("name", course_name))
	return true

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
	return Vector3(tee.get("x", 0), tee.get("y", 0), tee.get("z", 0))

func get_pin_position(hole_number: int) -> Vector3:
	var hole = get_hole_data(hole_number)
	if hole.is_empty():
		return Vector3.ZERO
	var pin = hole.get("pin", {})
	return Vector3(pin.get("x", 0), pin.get("y", 0), pin.get("z", 0))

func get_total_holes() -> int:
	return course_meta.get("holes", []).size()

func get_course_name() -> String:
	return course_meta.get("name", current_course_name)
