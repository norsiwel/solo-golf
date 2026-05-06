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

	# Hide the flat fallback ground mesh now that heightmap terrain is active
	var fallback = get_node_or_null("FallbackGround")
	if fallback:
		var gm = fallback.get_node_or_null("GroundMesh")
		if gm:
			gm.visible = false

	# Get ground heights via downward raycast so player/geometry land on the actual surface
	var tee_y: float = maxf(_raycast_ground_y(tee.x, tee.z), 0.0)
	var pin_y: float = maxf(_raycast_ground_y(pin.x, pin.z), 0.0)

	# --- Tee box: rectangle perpendicular to tee→pin direction ---
	var play_dir = Vector3(pin.x - tee.x, 0, pin.z - tee.z).normalized()
	var tee_box = hole_geo.get_node_or_null("TeeBox")
	if tee_box:
		tee_box.global_position = Vector3(tee.x, tee_y + 0.005, tee.z)
		# Rotate tee box so its long axis is perpendicular to play direction
		tee_box.rotation.y = atan2(-play_dir.x, -play_dir.z) + PI * 0.5

	var tee_peg = hole_geo.get_node_or_null("TeePeg")
	if tee_peg:
		tee_peg.global_position = Vector3(tee.x, tee_y + 0.06, tee.z - play_dir.z * 0.5)

	# --- Flagstick at pin position ---
	var flagstick = hole_geo.get_node_or_null("Flagstick")
	if flagstick:
		flagstick.global_position = Vector3(pin.x, pin_y, pin.z)

	# --- Green: real polygon shape from shapes JSON ---
	var green_mesh = hole_geo.get_node_or_null("Green")
	if green_mesh:
		var height_fn := Callable()
		if hole_terrain and hole_terrain.has_method("get_height_at"):
			height_fn = Callable(hole_terrain, "get_height_at")
		CourseShapesLoader.apply_green_mesh(green_mesh, hole_num, pin_y, height_fn)

	# --- GreenArea collision: real polygon from shapes JSON ---
	var green_area = hole_geo.get_node_or_null("GreenArea")
	if green_area:
		CourseShapesLoader.apply_green_shape(green_area, hole_num, pin_y)
		green_area.hole_number = hole.get("hole", hole_num)
		green_area.par = hole.get("par", 4)

		# Cup at pin position (which may differ slightly from green centre)
		var cup = green_area.get_node_or_null("Cup")
		if cup:
			cup.global_position = Vector3(pin.x, pin_y + 0.005, pin.z)

	# --- Tee detection area ---
	var tee_area = hole_geo.get_node_or_null("TeeArea")
	if tee_area:
		tee_area.global_position = Vector3(tee.x, tee_y + 0.3, tee.z)
		tee_area.hole_number = hole.get("hole", hole_num)
		tee_area.par = hole.get("par", 4)
		tee_area.yardage = hole.get("yardage", 0)

	player.green_node = green_area

	# Spawn player above tee
	player.global_position = Vector3(tee.x, tee_y + 1.8, tee.z)

	# Face player perpendicular to play direction — golf address stance (left side toward target)
	player.yaw = atan2(-play_dir.x, -play_dir.z) - PI * 0.5
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

	# HUD
	player.get_node("HUD/AimLabel").text = "The Old Course  |  Hole %d  Par %d  %d yds  |  V to aim" % [
		hole_num, hole.get("par", 4), hole.get("yardage", 0)
	]

	var hole_map = get_node_or_null("HoleMap")
	if hole_map and hole_map.has_method("load_hole"):
		hole_map.load_hole(hole_num)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _raycast_ground_y(world_x: float, world_z: float) -> float:
	var space = get_world_3d().direct_space_state
	if not space:
		return 0.0
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(world_x, 500.0, world_z),
		Vector3(world_x, -50.0, world_z)
	)
	var result = space.intersect_ray(query)
	if result:
		return result.position.y
	return 0.0

func go_to_next_hole():
	var cm = get_node_or_null("CourseManager")
	if not cm:
		return
	var next = cm.current_hole + 1
	if next > cm.get_total_holes():
		next = 1
	_setup_hole(next)
