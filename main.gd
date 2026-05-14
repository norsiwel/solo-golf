extends Node3D

func _ready():
	_start_spline_loader()
	call_deferred("_load_course")

func _start_spline_loader():
	var loader_script = load("res://courses/The_Old_Course_spline_loader.gd")
	if not loader_script:
		push_warning("Main: spline loader script not found")
		return
	var loader = Node3D.new()
	loader.name = "SplineMeshLoader"
	loader.set_script(loader_script)
	add_child(loader)

func _load_course():
	# Always expect GameState.current_course to be set by CourseSelectScreen.
	# If somehow empty (dev shortcut), fall back to The Old Course.
	if not GameState.current_course.is_empty():
		_setup_hole_owg(GameState.current_course, 1)
	else:
		# Dev fallback — load built-in Old Course directly
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
	# Hide fallback ground for OWG
	var fallback = get_node_or_null("FallbackGround")
	if fallback:
		fallback.visible = false

	var player = get_node_or_null("Player")
	if not player:
		push_error("Main: Missing Player node for OWG setup")
		return

	var extract_path = course_data.get("extract_path", "")

	# ── Step 1: Load baked terrain.tscn ───────────────────────────────────
	# Remove any previous baked terrain
	var old_terrain = get_node_or_null("BakedTerrain")
	if old_terrain:
		old_terrain.queue_free()
		await get_tree().process_frame

	var terrain_tscn_path = extract_path + "terrain/terrain.tscn"
	var terrain_node: Node3D = null
	var hole_terrain = get_node_or_null("HoleTerrain")

	if FileAccess.file_exists(terrain_tscn_path):
		# Godot 4 can't load user:// .tscn at runtime via load()
		# So we instantiate via GDScript parsing instead
		var global_path = ProjectSettings.globalize_path(terrain_tscn_path)
		var packed = ResourceLoader.load(global_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if packed:
			terrain_node = packed.instantiate()
			terrain_node.name = "BakedTerrain"
			add_child(terrain_node)
			print("Main: Loaded baked terrain.tscn ✓")

			# Load splatmap textures onto the baked terrain's MeshInstance3D
			if extract_path != "" and hole_terrain and hole_terrain.has_method("load_textures"):
				hole_terrain.load_textures(extract_path + "textures")
				# Apply shader material from hole_terrain to baked mesh
				var baked_mesh = terrain_node.get_node_or_null("MeshInstance3D")
				if baked_mesh and hole_terrain._owg_splatmap_tex:
					var mat := ShaderMaterial.new()
					var shader := Shader.new()
					shader.code = hole_terrain.SPLAT_SHADER
					mat.shader = shader
					mat.set_shader_parameter("splatmap", hole_terrain._owg_splatmap_tex)
					var f_tex = hole_terrain._owg_fairway_tex if hole_terrain._owg_fairway_tex else load("res://assets/terrain/surface_fairway.png")
					var g_tex = hole_terrain._owg_green_tex if hole_terrain._owg_green_tex else load("res://assets/terrain/surface_green.png")
					var r_tex = hole_terrain._owg_rough_tex if hole_terrain._owg_rough_tex else load("res://assets/terrain/surface_rough.png")
					mat.set_shader_parameter("fairway_tex", f_tex)
					mat.set_shader_parameter("green_tex", g_tex)
					mat.set_shader_parameter("rough_tex", r_tex)
					mat.set_shader_parameter("uv_scale", 12.0)
					var terrain_meta = course_data.get("terrain", {})
					mat.set_shader_parameter("owg_size_x", terrain_meta.get("terrain_size_x", 2271.0))
					mat.set_shader_parameter("owg_size_z", terrain_meta.get("terrain_size_z", 2271.0))
					baked_mesh.material_override = mat
					print("Main: Splatmap material applied to baked terrain ✓")

			# Also load heightmap into hole_terrain for height queries
			var hm_path = extract_path + "terrain/heightmap.png"
			if hole_terrain and hole_terrain.has_method("load_heightmap"):
				hole_terrain.load_heightmap(hm_path)
	else:
		push_warning("Main: terrain.tscn not found at " + terrain_tscn_path + " — falling back to dynamic terrain")
		if hole_terrain and hole_terrain.has_method("load_heightmap"):
			var hm_path = course_data.get("heightmap_path", "")
			if hm_path != "":
				hole_terrain.load_heightmap(hm_path)
		if extract_path != "" and hole_terrain and hole_terrain.has_method("load_textures"):
			hole_terrain.load_textures(extract_path + "textures")

	# ── Step 2: Get tee and pin positions ─────────────────────────────────
	var tee_pos := Vector3.ZERO
	var pin_pos := Vector3.ZERO
	var par := 4

	for hole in course_data.get("holes", []):
		if hole.get("hole_number") != hole_num:
			continue
		for tee in hole.get("tees", []):
			if tee.get("type") == "Championship":
				var tp = tee.get("position", {})
				tee_pos = Vector3(tp.get("x", 0.0), tp.get("y", 0.0), tp.get("z", 0.0))
				par = int(str(tee.get("par", "4")).replace("_", ""))
				break
		var pins = hole.get("pins", [])
		if pins.size() > 0:
			var pp = pins[0].get("position", {})
			pin_pos = Vector3(pp.get("x", 0.0), pp.get("y", 0.0), pp.get("z", 0.0))
		break

	if tee_pos == Vector3.ZERO:
		push_error("Main: OWG hole %d championship tee not found" % hole_num)
		return

	# ── Step 3: Wait for physics so raycasts work ──────────────────────────
	# Baked terrain.tscn has collision — wait 3 frames before raycasting
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Ground tee/pin via raycast into the baked collision
	tee_pos.y = _raycast_ground_y(tee_pos.x, tee_pos.z)
	pin_pos.y = _raycast_ground_y(pin_pos.x, pin_pos.z)
	# Fallback to terrain query if raycast misses
	if tee_pos.y == 0.0 and hole_terrain and hole_terrain.has_method("get_height_at"):
		tee_pos.y = hole_terrain.get_height_at(tee_pos.x, tee_pos.z)
	if pin_pos.y == 0.0 and hole_terrain and hole_terrain.has_method("get_height_at"):
		pin_pos.y = hole_terrain.get_height_at(pin_pos.x, pin_pos.z)

	print("Main: tee_pos=", tee_pos, " pin_pos=", pin_pos)

	# ── Step 4: Place HoleGeometry ─────────────────────────────────────────
	var hole_geo = get_node_or_null("HoleGeometry")
	if hole_geo:
		var play_dir = Vector3(pin_pos.x - tee_pos.x, 0.0, pin_pos.z - tee_pos.z).normalized()

		var flagstick = hole_geo.get_node_or_null("Flagstick")
		if flagstick:
			flagstick.global_position = Vector3(pin_pos.x, pin_pos.y, pin_pos.z)
			flagstick.visible = true

		var tee_box = hole_geo.get_node_or_null("TeeBox")
		if tee_box:
			tee_box.global_position = Vector3(tee_pos.x, tee_pos.y + 0.005, tee_pos.z)
			tee_box.rotation.y = atan2(-play_dir.x, -play_dir.z) + PI * 0.5
			tee_box.visible = true

		var tee_peg = hole_geo.get_node_or_null("TeePeg")
		if tee_peg:
			tee_peg.global_position = Vector3(tee_pos.x, tee_pos.y + 0.06, tee_pos.z)
			tee_peg.visible = true

		var green_area = hole_geo.get_node_or_null("GreenArea")
		if green_area:
			green_area.global_position = pin_pos
			green_area.hole_number = hole_num
			green_area.par = par
			green_area.stimp = randf_range(8.0, 13.0)
			green_area.visible = true
			var col_shape = CylinderShape3D.new()
			col_shape.radius = 24.0
			col_shape.height = 1.0
			for child in green_area.get_children():
				if child is CollisionShape3D:
					child.shape = col_shape
					break
			var cup = green_area.get_node_or_null("Cup")
			if cup:
				cup.global_position = Vector3(pin_pos.x, pin_pos.y + 0.005, pin_pos.z)
			player.green_node = green_area

		var tee_area = hole_geo.get_node_or_null("TeeArea")
		if tee_area:
			tee_area.global_position = Vector3(tee_pos.x, tee_pos.y + 0.3, tee_pos.z)
			tee_area.hole_number = hole_num
			tee_area.par = par
			tee_area.visible = true

	# ── Step 5: Spawn player ───────────────────────────────────────────────
	player.global_position = Vector3(tee_pos.x, tee_pos.y + 2.0, tee_pos.z)

	if pin_pos != Vector3.ZERO:
		var orient_dir = Vector3(pin_pos.x - tee_pos.x, 0.0, pin_pos.z - tee_pos.z).normalized()
		var hand_offset := PI * 0.5 if player.right_handed else -PI * 0.5
		player.yaw = atan2(-orient_dir.x, -orient_dir.z) + hand_offset
		player.rotation.y = player.yaw
		player.pitch = 0.0
		player.get_node("Camera3D").rotation.x = 0.0
		player.aim_point = player.global_position + (-player.global_transform.basis.z.normalized()) * 250.0

	# ── Step 6: Reset game state ───────────────────────────────────────────
	player.stroke_count = 0
	player.on_green = false
	player.aim_locked = false
	var firmness := randf_range(0.7, 1.3)
	var condition_str := "Wet" if firmness < 0.85 else ("Firm" if firmness > 1.15 else "Normal")

	if player.ball:
		player.ball.reset()
		player.ball.course_firmness = firmness
		player.ball.cup_pos = pin_pos
		player.ball.global_position = Vector3(tee_pos.x, tee_pos.y + 0.08, tee_pos.z)
		player.ball.visible = true

	if player.address_screen:
		player.address_screen.set_putting_mode(false)

	# ── Step 7: HUD and objects ────────────────────────────────────────────
	var aim_label = player.get_node_or_null("HUD/AimLabel")
	if aim_label:
		aim_label.text = "%s  |  Hole %d  Par %d  |  %s  |  V to aim" % [
			course_data.get("name", "OWG Course"), hole_num, par, condition_str
		]

	var hole_map = get_node_or_null("HoleMap")
	if hole_map and hole_map.has_method("set_map_image"):
		if extract_path != "":
			var dir = DirAccess.open(extract_path + "textures")
			if dir:
				dir.list_dir_begin()
				var fn = dir.get_next()
				while fn != "":
					if "oh2.png" in fn.to_lower() or "overhead" in fn.to_lower():
						hole_map.set_map_image(extract_path + "textures/" + fn)
						break
					fn = dir.get_next()

	_spawn_owg_objects(course_data.get("objects", []))

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Main: OWG hole %d — player spawned at %s" % [hole_num, str(player.global_position)])


func _spawn_owg_objects(objects: Array) -> void:
	# Remove previous OWG objects
	var container = get_node_or_null("OWGObjects")
	if container:
		container.queue_free()

	container = Node3D.new()
	container.name = "OWGObjects"
	add_child(container)

	var hole_terrain = get_node_or_null("HoleTerrain")
	if hole_terrain and hole_terrain.has_method("spawn_unity_objects"):
		hole_terrain.spawn_unity_objects(objects, container)
	else:
		print("Main: Missing HoleTerrain or spawn_unity_objects method")

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

		# Use CSG for slightly better looking buildings (roofs)
		var building := CSGCombiner3D.new()
		building.name = lname
		building.use_collision = true # Allows viewfinder raycast
		
		# Main block
		var base := CSGBox3D.new()
		base.size = Vector3(lw, lh, ld)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.85
		base.material = mat
		building.add_child(base)
		
		# Add a simple peaked roof
		var roof_h := lh * 0.4
		var roof := CSGBox3D.new()
		roof.size = Vector3(lw + 0.5, roof_h, ld + 0.5)
		roof.position.y = lh * 0.5 + roof_h * 0.2
		roof.rotation.x = deg_to_rad(15.0) # Slight tilt
		var roof_mat = mat.duplicate()
		roof_mat.albedo_color = col.darkened(0.3)
		roof.material = roof_mat
		building.add_child(roof)
		
		building.global_position = Vector3(lx, ground_y + lh * 0.5, lz)
		add_child(building)

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
	
	if not GameState.current_course.is_empty():
		cm.current_hole = next
		_setup_hole_owg(GameState.current_course, next)
	else:
		_setup_hole(next)
