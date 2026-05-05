extends Node3D

func _ready():
	_start_spline_loader()
	call_deferred("_load_standrews")

func _start_spline_loader():
	var loader_script = load("res://courses/The_Old_Course_spline_loader.gd")
	if not loader_script:
		push_warning("Main: spline loader script not found")
		return
	var loader = Node3D.new()
	loader.name = "SplineMeshLoader"
	loader.set_script(loader_script)
	add_child(loader)

func _load_standrews():
	var cm = get_node_or_null("CourseManager")
	var player = get_node_or_null("Player")
	var hole_geo = get_node_or_null("HoleGeometry")

	if not cm or not player or not hole_geo:
		push_error("Main: Missing required nodes")
		return

	if not cm.load_course("The_Old_Course"):
		push_error("Main: Failed to load The Old Course")
		return

	_setup_hole(1)

func _setup_hole(hole_num: int):
	var cm = get_node_or_null("CourseManager")
	var player = get_node_or_null("Player")
	var hole_geo = get_node_or_null("HoleGeometry")
	var fallback = get_node_or_null("FallbackGround")

	var hole = cm.go_to_hole(hole_num)
	if hole.is_empty():
		push_error("Main: No data for hole %d" % hole_num)
		return

	var tee = cm.get_tee_position(hole_num)
	var pin = cm.get_pin_position(hole_num)

	# Build per-hole terrain from tee/pin waypoints
	var hole_terrain = get_node_or_null("HoleTerrain")
	if hole_terrain and hole_terrain.has_method("build_from_hole"):
		var all_tees = hole.get("all_tees", [])
		var all_pins = hole.get("all_pins", [])
		hole_terrain.build_from_hole(
			Vector3(tee.x, 0, tee.z),
			Vector3(pin.x, 0, pin.z),
			all_tees, all_pins
		)
		# Keep fallback ground visible as collision safety net
	
	# Get actual ground heights from terrain
	var tee_y = 0.1
	var pin_y = 0.1
	if hole_terrain and hole_terrain.has_method("get_height_at"):
		tee_y = hole_terrain.get_height_at(tee.x, tee.z)
		pin_y = hole_terrain.get_height_at(pin.x, pin.z)

	# Position hole geometry
	var hole_geo_nodes = {
		"TeeBox":   Vector3(tee.x, tee_y + 0.01, tee.z),
		"TeePeg":   Vector3(tee.x, tee_y + 0.03, tee.z - 1.0),
		"Green":    Vector3(pin.x, pin_y + 0.02, pin.z),
		"Flagstick":Vector3(pin.x, pin_y, pin.z),
	}
	for node_name in hole_geo_nodes:
		var n = hole_geo.get_node_or_null(node_name)
		if n: n.global_position = hole_geo_nodes[node_name]

	var tee_area = hole_geo.get_node_or_null("TeeArea")
	if tee_area:
		tee_area.global_position = Vector3(tee.x, tee_y + 0.3, tee.z)
		tee_area.hole_number = hole.get("hole", hole_num)
		tee_area.par = hole.get("par", 4)
		tee_area.yardage = hole.get("yardage", 0)

	var green_area = hole_geo.get_node_or_null("GreenArea")
	if green_area:
		green_area.global_position = Vector3(pin.x, pin_y + 0.02, pin.z)
		green_area.hole_number = hole.get("hole", hole_num)
		green_area.par = hole.get("par", 4)

	player.green_node = green_area

	# Spawn player above tee — use terrain height if available
	var spawn_y = max(tee_y, 0.0) + 1.8
	player.global_position = Vector3(tee.x, spawn_y, tee.z)

	# Face player toward pin
	var dir = Vector3(pin.x - tee.x, 0, pin.z - tee.z).normalized()
	player.yaw = atan2(-dir.x, -dir.z)
	player.rotation.y = player.yaw
	player.pitch = 0.0
	player.get_node("Camera3D").rotation.x = 0.0

	# Reset game state
	player.stroke_count = 0
	player.on_green = false
	player.aim_locked = false
	player.aim_point = Vector3(pin.x, pin_y, pin.z)
	if player.ball:
		player.ball.reset()
		player.ball.cup_pos = Vector3.ZERO
		player.ball.visible = false
	player.address_screen.set_putting_mode(false)

	# Update HUD
	player.get_node("HUD/AimLabel").text = "The Old Course  |  Hole %d  Par %d  %d yds  |  V to aim" % [
		hole_num, hole.get("par", 4), hole.get("yardage", 0)
	]

	# Update hole map
	var hole_map = get_node_or_null("HoleMap")
	if hole_map and hole_map.has_method("load_hole"):
		hole_map.load_hole(hole_num)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func go_to_next_hole():
	var cm = get_node_or_null("CourseManager")
	if not cm:
		return
	var next = cm.current_hole + 1
	if next > cm.get_total_holes():
		next = 1  # loop back to hole 1
	_setup_hole(next)
