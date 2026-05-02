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
	var fallback = get_node_or_null("FallbackGround")

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

	# Check if Terrain3D is active for this course
	var terrain = get_node_or_null("Terrain3D")
	var has_terrain = terrain != null and terrain.visible
	# Show fallback ground only if no terrain
	if fallback:
		fallback.visible = not has_terrain

	# Get positions from metadata
	var tee = cm.get_tee_position(1)
	var pin = cm.get_pin_position(1)

	# If terrain exists, adjust Y to terrain height
	# Otherwise use metadata Y (which is correct for flat ground too)
	var tee_y = tee.y
	var pin_y = pin.y
	if has_terrain:
		# Terrain3D height query if available
		if terrain.has_method("get_height"):
			tee_y = terrain.get_height(Vector2(tee.x, tee.z))
			pin_y = terrain.get_height(Vector2(pin.x, pin.z))

	# Move hole geometry - position the group node
	# Then position children relative to it at ground level
	hole_geo.global_position = Vector3.ZERO  # reset group

	var tee_box  = hole_geo.get_node_or_null("TeeBox")
	var tee_area = hole_geo.get_node_or_null("TeeArea")
	var tee_peg  = hole_geo.get_node_or_null("TeePeg")
	var green    = hole_geo.get_node_or_null("Green")
	var green_area = hole_geo.get_node_or_null("GreenArea")
	var flagstick  = hole_geo.get_node_or_null("Flagstick")

	if tee_box:  tee_box.global_position  = Vector3(tee.x, tee_y + 0.01, tee.z)
	if tee_area: tee_area.global_position = Vector3(tee.x, tee_y + 0.3, tee.z)
	if tee_peg:  tee_peg.global_position  = Vector3(tee.x, tee_y + 0.03, tee.z - 1.0)
	if green:    green.global_position    = Vector3(pin.x, pin_y + 0.02, pin.z)
	if flagstick: flagstick.global_position = Vector3(pin.x, pin_y, pin.z)

	if tee_area:
		tee_area.hole_number = hole.get("hole", 1)
		tee_area.par         = hole.get("par", 4)
		tee_area.yardage     = hole.get("yardage", 0)

	if green_area:
		green_area.global_position = Vector3(pin.x, pin_y + 0.02, pin.z)
		green_area.hole_number = hole.get("hole", 1)
		green_area.par = hole.get("par", 4)

	# Give player reference to green
	player.green_node = green_area

	# Teleport player to tee
	player.global_position = Vector3(tee.x, tee_y + 1.8, tee.z)
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
	player.get_node("HUD/AimLabel").text = "%s  |  Hole %d  Par %d  %d yds  |  V to aim" % [
		cm.get_course_name(),
		hole.get("hole", 1),
		hole.get("par", 4),
		hole.get("yardage", 0)
	]

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
