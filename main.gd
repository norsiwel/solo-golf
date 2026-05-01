extends Node3D

func _ready():
	var selector = get_node_or_null("CourseSelector")
	if selector:
		selector.course_selected.connect(_on_course_selected)
		selector.show_selector()

func _on_course_selected(course_name: String):
	var cm = get_node_or_null("CourseManager")
	var player = get_node_or_null("Player")
	var hole_geo = get_node_or_null("HoleGeometry")
	if not cm or not player or not hole_geo:
		push_error("Main: Missing required nodes")
		return

	if not cm.load_course(course_name):
		push_error("Main: Failed to load course: " + course_name)
		return

	var hole = cm.go_to_hole(1)
	if hole.is_empty():
		push_error("Main: No hole 1 data")
		return

	# Get tee and pin world positions from metadata
	var tee = cm.get_tee_position(1)
	var pin = cm.get_pin_position(1)

	# Move tee geometry
	var tee_box = hole_geo.get_node_or_null("TeeBox")
	var tee_area = hole_geo.get_node_or_null("TeeArea")
	var tee_peg = hole_geo.get_node_or_null("TeePeg")
	if tee_box: tee_box.global_position = Vector3(tee.x, tee.y + 0.01, tee.z)
	if tee_area: tee_area.global_position = Vector3(tee.x, tee.y + 0.3, tee.z)
	if tee_peg:  tee_peg.global_position  = Vector3(tee.x, tee.y + 0.03, tee.z - 1.0)

	# Update tee metadata
	if tee_area:
		tee_area.hole_number = hole.get("hole", 1)
		tee_area.par         = hole.get("par", 4)
		tee_area.yardage     = hole.get("yardage", 400)

	# Move green geometry
	var green_mesh = hole_geo.get_node_or_null("Green")
	var green_area = hole_geo.get_node_or_null("GreenArea")
	if green_mesh: green_mesh.global_position = Vector3(pin.x, pin.y + 0.02, pin.z)
	if green_area:
		green_area.global_position = Vector3(pin.x, pin.y + 0.02, pin.z)
		green_area.hole_number = hole.get("hole", 1)
		green_area.par = hole.get("par", 4)

	# Move flagstick
	var flagstick = hole_geo.get_node_or_null("Flagstick")
	if flagstick: flagstick.global_position = Vector3(pin.x, pin.y, pin.z)

	# Update player green reference
	player.green_node = green_area

	# Teleport player to tee
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
	var par = hole.get("par", 4)
	var yds = hole.get("yardage", 0)
	player.get_node("HUD/AimLabel").text = "%s  |  Hole 1  Par %d  %d yds  |  V to aim" % [
		cm.get_course_name(), par, yds
	]

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
