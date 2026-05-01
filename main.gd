extends Node3D

func _ready():
	# Wire course selector signal
	var selector = get_node_or_null("CourseSelector")
	if selector:
		selector.course_selected.connect(_on_course_selected)
		# Show selector on startup
		selector.show_selector()

func _on_course_selected(course_name: String):
	var cm = get_node_or_null("CourseManager")
	var player = get_node_or_null("Player")
	if not cm or not player:
		push_error("Main: Missing CourseManager or Player node")
		return

	# Load the course
	if not cm.load_course(course_name):
		push_error("Main: Failed to load course: " % course_name)
		return

	# Go to hole 1
	var hole = cm.go_to_hole(1)
	if hole.is_empty():
		push_error("Main: No hole 1 data for course: " % course_name)
		return

	# Teleport player to tee
	var tee = cm.get_tee_position(1)
	player.global_position = Vector3(tee.x, tee.y + 1.8, tee.z)
	player.yaw = 0.0
	player.pitch = 0.0
	player.rotation.y = 0.0
	player.get_node("Camera3D").rotation.x = 0.0

	# Reset game state
	player.stroke_count = 0
	player.on_green = false
	player.aim_locked = false
	if player.ball:
		player.ball.reset()
		player.ball.cup_pos = Vector3.ZERO
		player.ball.visible = false
	player.address_screen.set_putting_mode(false)

	# Update HUD
	player.get_node("HUD/AimLabel").text = "%s  |  Hole 1  Par %d  %d yds  |  V to aim" % [
		cm.get_course_name(),
		hole.get("par", 4),
		hole.get("yardage", 0)
	]

	# Update green node reference for this course
	var green = get_node_or_null("GreenArea")
	if green:
		player.green_node = green

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
