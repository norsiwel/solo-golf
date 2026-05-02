extends Node

signal course_loaded(course_name: String, meta: Dictionary)
signal hole_changed(hole_number: int, par: int, yardage: int)

var current_course_name := ""
var current_course_node: Node3D = null
var current_hole := 0
var course_meta := {}
var available_courses: Array[String] = []

func _ready():
	_scan_courses()

	# Auto-load the first found course so the world is not empty.
	if available_courses.size() > 0:
		load_course(available_courses[0])
	else:
		push_warning("CourseManager: No courses found in res://courses/")


func _scan_courses():
	available_courses.clear()

	var dir = DirAccess.open("res://courses/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()

		while fname != "":
			if fname.ends_with("_meta.json"):
				var course = fname.replace("_meta.json", "")

				# Only list courses that also have a matching scene.
				if FileAccess.file_exists("res://courses/%s.tscn" % course):
					available_courses.append(course)
				else:
					push_warning("CourseManager: Metadata exists but scene missing for %s" % course)

			fname = dir.get_next()

		dir.list_dir_end()

	print("CourseManager: Found %d courses: %s" % [available_courses.size(), str(available_courses)])


func scan_courses():
	_scan_courses()
	return available_courses


func get_available_courses() -> Array[String]:
	return available_courses


func load_course(course_name: String) -> bool:
	var meta_path = "res://courses/%s_meta.json" % course_name
	var scene_path = "res://courses/%s.tscn" % course_name

	if not FileAccess.file_exists(meta_path):
		push_error("CourseManager: No metadata found for %s" % course_name)
		return false

	if not FileAccess.file_exists(scene_path):
		push_error("CourseManager: No scene found for %s" % course_name)
		return false

	var f = FileAccess.open(meta_path, FileAccess.READ)
	if not f:
		push_error("CourseManager: Could not open metadata file: %s" % meta_path)
		return false

	var json = JSON.new()
	var parse_result = json.parse(f.get_as_text())
	f.close()

	if parse_result != OK:
		push_error("CourseManager: Failed to parse metadata JSON for %s" % course_name)
		return false

	course_meta = json.get_data()

	if current_course_node and is_instance_valid(current_course_node):
		current_course_node.queue_free()
		current_course_node = null

	_remove_old_course_objects()

	var scene = load(scene_path)
	if not scene:
		push_error("CourseManager: Failed to load scene %s" % scene_path)
		return false

	current_course_node = scene.instantiate()
	current_course_node.name = course_name

	get_tree().current_scene.add_child(current_course_node)

	current_course_name = course_name
	current_hole = 1

	emit_signal("course_loaded", course_name, course_meta)
	print("CourseManager: Loaded %s" % course_meta.get("name", course_name))

	call_deferred("_reconnect_player_green")

	return true


func _reconnect_player_green():
	var green_area = _find_first_green_area(get_tree().current_scene)

	if green_area:
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player and player.has_method("connect_green_to_new_course"):
			player.connect_green_to_new_course(green_area)
	else:
		push_warning("CourseManager: No GreenArea found in loaded course")


func _find_first_green_area(node: Node) -> Area3D:
	if node.name.begins_with("GreenArea") and node is Area3D:
		return node

	for child in node.get_children():
		var found = _find_first_green_area(child)
		if found:
			return found

	return null


func _remove_old_course_objects():
	var nodes_to_remove = [
		"Ground", "GreenArea", "Green", "GreenCollision", "Flagstick",
		"FlagBody", "FlagCollision", "TeeArea", "TeeBox", "TeeCollision", "Tee",
		"Bunker1", "Bunker1Area", "Bunker1Collision",
		"Bunker2", "Bunker2Area", "Bunker2Collision",
		"Tree1", "Tree2", "Tree3", "Tree4", "Tree5"
	]

	var scene = get_tree().current_scene

	for node_name in nodes_to_remove:
		var node = scene.get_node_or_null(node_name)
		if node:
			node.queue_free()

	for child in scene.get_children():
		if child.name.begins_with("Hole") and child is Node3D:
			child.queue_free()


func get_hole_data(hole_number: int) -> Dictionary:
	if course_meta.is_empty():
		return {}

	var holes = course_meta.get("holes", [])
	for h in holes:
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
	return Vector3(tee.get("x", 0), tee.get("y", 0), -tee.get("z", 0))


func get_pin_position(hole_number: int) -> Vector3:
	var hole = get_hole_data(hole_number)

	if hole.is_empty():
		return Vector3.ZERO

	var pin = hole.get("pin", {})
	return Vector3(pin.get("x", 0), pin.get("y", 0), -pin.get("z", 0))


func get_total_holes() -> int:
	return course_meta.get("holes", []).size()


func get_course_name() -> String:
	return course_meta.get("name", current_course_name)
