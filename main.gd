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
	# OWG path: terrain already built by CourseManager._setup_from_owg_data().
	# Just place the player on the course.
	if not GameState.current_course.is_empty():
		_setup_hole_owg(GameState.current_course, 1)
		return

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


func _setup_hole_owg(course_data: Dictionary, hole_num: int) -> void:
	var player = get_node_or_null("Player")
	if not player:
		push_error("Main: Missing Player node for OWG setup")
		return

	# Pull championship tee + first pin from OWG course.json
	var tee_pos := Vector3.ZERO
	var pin_pos := Vector3.ZERO
	var par := 4

	for hole in course_data.get("holes", []):
		if hole.get("hole_number") != hole_num:
			continue
		for tee in hole.get("tees", []):
			if tee.get("type") == "Championship":
				var p = tee.get("position", {})
				tee_pos = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
				par = int(str(tee.get("par", "4")).replace("_", ""))
				break
		var pins = hole.get("pins", [])
		if pins.size() > 0:
			var p = pins[0].get("position", {})
			pin_pos = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
		break

	if tee_pos == Vector3.ZERO:
		push_error("Main: OWG hole %d championship tee not found" % hole_num)
		return

	# Spawn +2 m above tee — gravity settles player onto terrain surface
	player.global_position = Vector3(tee_pos.x, tee_pos.y + 2.0, tee_pos.z)

	# Orient perpendicular to tee→pin (flag to left for right-handers)
	if pin_pos != Vector3.ZERO:
		var play_dir = Vector3(pin_pos.x - tee_pos.x, 0.0, pin_pos.z - tee_pos.z).normalized()
		var hand_offset := -PI * 0.5 if player.right_handed else PI * 0.5
		player.yaw = atan2(-play_dir.x, -play_dir.z) + hand_offset
		player.rotation.y = player.yaw
		player.pitch = 0.0
		player.get_node("Camera3D").rotation.x = 0.0
		player.aim_point = pin_pos

	# Reset game state
	player.stroke_count = 0
	player.on_green = false
	player.aim_locked = false

	# Place ball on tee
	if player.ball:
		player.ball.reset()
		player.ball.course_firmness = randf_range(0.7, 1.3)
		player.ball.cup_pos = Vector3.ZERO
		player.ball.global_position = Vector3(tee_pos.x, tee_pos.y + 0.08, tee_pos.z)
		player.ball.visible = true

	if player.address_screen:
		player.address_screen.set_putting_mode(false)

	# HUD
	var aim_label = player.get_node_or_null("HUD/AimLabel")
	if aim_label:
		aim_label.text = "%s  |  Hole %d  Par %d  |  V to aim" % [
			course_data.get("name", "OWG Course"), hole_num, par
		]

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Main: OWG hole %d — player spawned at %s" % [hole_num, str(player.global_position)])

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

	# Build per-hole terrain from tee/pin waypoints (JSON/dev path).
	# OWG path: terrain already built by CourseManager._setup_from_owg_data().
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
		# Random stimp 8–13 each round (8=slow, 10=medium, 13=tour fast)
		green_area.stimp = randf_range(8.0, 13.0)

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

	# Face player perpendicular to play direction — golf address stance
	# Right-handed: left side toward target (-PI/2), Left-handed: right side toward target (+PI/2)
	var hand_offset := -PI * 0.5 if player.right_handed else PI * 0.5
	player.yaw = atan2(-play_dir.x, -play_dir.z) + hand_offset
	player.rotation.y = player.yaw
	player.pitch = 0.0
	player.get_node("Camera3D").rotation.x = 0.0

	# Reset game state
	player.stroke_count = 0
	player.on_green = false
	player.aim_locked = false
	player.aim_point = Vector3(pin.x, pin_y, pin.z)
	# Course conditions: firmness affects rollout distance
	var firmness := randf_range(0.7, 1.3)
	var condition_str := "Wet" if firmness < 0.85 else ("Firm" if firmness > 1.15 else "Normal")

	if player.ball:
		player.ball.reset()
		player.ball.course_firmness = firmness
		player.ball.cup_pos = Vector3.ZERO
		# Place ball on the tee peg so OVB shows it immediately
		player.ball.global_position = Vector3(tee.x, tee_y + 0.08, tee.z)
		player.ball.visible = true
	player.address_screen.set_putting_mode(false)

	# HUD
	player.get_node("HUD/AimLabel").text = "The Old Course  |  Hole %d  Par %d  %d yds  |  Course: %s  |  V to aim" % [
		hole_num, hole.get("par", 4), hole.get("yardage", 0), condition_str
	]

	var hole_map = get_node_or_null("HoleMap")
	if hole_map and hole_map.has_method("load_hole"):
		hole_map.load_hole(hole_num)

	# Creek visuals — only the Swilcan Burn crosses hole 1 (and 18)
	_setup_swilcan_burn()

	# Landmark buildings visible from hole 1
	if hole_num == 1:
		_setup_landmarks()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_landmarks() -> void:
	# Remove previous landmarks if replaying hole
	for old in get_children():
		if old.name.begins_with("LM_"):
			old.queue_free()

	# Each entry: [name, world_x, world_z, width, depth, height, Color]
	# Positions are Godot world coords relative to hole 1 tee at origin.
	# R&A Clubhouse — stone grey, just east-northeast of the 1st tee / 18th green
	# Old Course Hotel — large red-brown landmark at the corner of hole 17
	# Hamilton Grand — long cream building along the 18th fairway
	# Town row — two blocks representing St Andrews town south of the course
	var landmarks := [
		["LM_RA_Clubhouse",    88,  -95, 48, 18, 14, Color(0.62, 0.60, 0.58)],
		["LM_Hamilton_Grand",  55,  -65, 60, 14, 11, Color(0.85, 0.80, 0.65)],
		["LM_OldCourseHotel", 230,  180, 58, 38, 26, Color(0.52, 0.32, 0.26)],
		["LM_Town_A",         130, -170, 45, 20, 10, Color(0.72, 0.65, 0.55)],
		["LM_Town_B",          60, -210, 50, 18, 10, Color(0.68, 0.60, 0.50)],
	]

	for lm in landmarks:
		var lname: String = lm[0]
		var lx: float = lm[1]; var lz: float = lm[2]
		var lw: float = lm[3]; var ld: float = lm[4]; var lh: float = lm[5]
		var col: Color = lm[6]

		var ground_y := maxf(_raycast_ground_y(lx, lz), 0.0)

		var box := BoxMesh.new()
		box.size = Vector3(lw, lh, ld)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.85
		box.surface_set_material(0, mat)

		# StaticBody so the viewfinder raycast registers a distance hit
		var body := StaticBody3D.new()
		body.name = lname
		var mi := MeshInstance3D.new()
		mi.mesh = box
		body.add_child(mi)
		var col_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(lw, lh, ld)
		col_shape.shape = box_shape
		body.add_child(col_shape)
		body.global_position = Vector3(lx, ground_y + lh * 0.5, lz)
		add_child(body)

func _setup_swilcan_burn() -> void:
	# Remove old creek mesh if re-setting up hole
	var old = get_node_or_null("SwilcanBurn")
	if old:
		old.queue_free()

	# Creek centre from OSM data (Godot world coords, hole 1 normalised)
	var cx := -278.6
	var cz := 2.11
	var cy := maxf(_raycast_ground_y(cx, cz), 0.0) + 0.015

	# Thin water plane — 10m wide, 130m long, angled ~15° to follow the burn diagonal
	var water := MeshInstance3D.new()
	water.name = "SwilcanBurn"
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 130.0)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.35, 0.62, 0.88)
	mat.roughness = 0.06
	mat.metallic = 0.0
	mat.metallic_specular = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.set_surface_override_material(0, mat)
	water.global_position = Vector3(cx, cy, cz)
	water.rotation.y = deg_to_rad(15.0)  # slight diagonal, burn crosses fairway at ~15°
	add_child(water)

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

func _reorient_player():
	var player = get_node_or_null("Player")
	var cm = get_node_or_null("CourseManager")
	if not player or not cm:
		return
	var tee = cm.get_tee_position(cm.current_hole)
	var pin = cm.get_pin_position(cm.current_hole)
	var play_dir = Vector3(pin.x - tee.x, 0, pin.z - tee.z).normalized()
	var hand_offset := -PI * 0.5 if player.right_handed else PI * 0.5
	player.yaw = atan2(-play_dir.x, -play_dir.z) + hand_offset
	player.rotation.y = player.yaw
	player.pitch = 0.0
	player.get_node("Camera3D").rotation.x = 0.0

func go_to_next_hole():
	var cm = get_node_or_null("CourseManager")
	if not cm:
		return
	var next = cm.current_hole + 1
	if next > cm.get_total_holes():
		next = 1
	_setup_hole(next)
