extends Node3D

# Ball flight parameters
var power := 0.0
var accuracy := 0.0
var draw_fade := 0.0
var loft := 0.0
var club_yards := 240.0
var is_putt := false
var stimp := 8.0

# Internal state
enum BallState { IDLE, FLYING, ROLLING, HOLING, STOPPED, CAM_HOLD }
var state := BallState.IDLE
var velocity := Vector3.ZERO
var time_in_flight := 0.0
var start_pos := Vector3.ZERO
var land_pos := Vector3.ZERO
var roll_dir := Vector3.ZERO
var current_max_distance_meters := 220.0
var cup_pos := Vector3.ZERO
var hole_timer := 0.0
var in_bunker_flag := false
var landed_surface := "fairway"

# Mesh placement data for surface detection (loaded once)
var _placement_data: Array = []
var _placement_loaded := false


# Ball camera
var ball_cam: Camera3D
var cam_timer := 0.0
var player_cam: Camera3D = null
const CAM_HOLD_TIME := 2.5

signal ball_holed
# surface: "fairway", "rough", "deep_rough", "bunker", "water", "green", "tee"
signal ball_stopped(position: Vector3, surface: String)

# Tracer
var tracer_points: Array[Vector3] = []
var _tracer_mesh: MeshInstance3D = null

const YARDS_TO_METERS := 0.9144
const BASE_ROLLOUT := 0.10
const FLIGHT_SPEED := 2.5
const PUTT_SPEED := 1.5

func _ready():
	_setup_tracer()
	_setup_ball_cam()
	_load_placement_data()
	_load_osm_water()

func _load_placement_data() -> void:
	_placement_loaded = true
	var f = FileAccess.open("res://courses/The_Old_Course_mesh_placement.json", FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data and data.has("placements"):
		_placement_data = data["placements"]

func _load_osm_water() -> void:
	pass  # replaced by circle checks in _point_in_water

func _point_in_water(wx: float, wz: float) -> bool:
	# Swilcan Burn: circles along the creek centre-line, 7m radius each
	# Creek crosses hole 1 fairway roughly from NE to SW in front of the green
	const R2 := 49.0  # 7m radius squared
	const CREEK_PTS: Array = [
		[-258.0, 60.0], [-268.0, 38.0], [-278.0, 18.0],
		[-290.0, 4.0],  [-305.0, -8.0], [-316.0, -22.0]
	]
	for pt in CREEK_PTS:
		var dx: float = wx - pt[0]
		var dz: float = wz - pt[1]
		if dx * dx + dz * dz < R2:
			return true
	return false

func _get_terrain_y(world_x: float, world_z: float) -> float:
	var space := get_world_3d().direct_space_state
	if not space:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(world_x, 500.0, world_z),
		Vector3(world_x, -50.0, world_z)
	)
	var result := space.intersect_ray(query)
	if result:
		return result.position.y
	return 0.0

func _get_terrain_normal(world_x: float, world_z: float) -> Vector3:
	var scene := get_tree().current_scene
	if scene:
		var terrain := scene.get_node_or_null("HoleTerrain")
		if terrain and terrain.has_method("get_normal_at"):
			return terrain.get_normal_at(world_x, world_z)
	return Vector3.UP

func _get_surface_type(world_x: float, world_z: float) -> String:
	# Precise water check using actual OSM creek polygon shapes
	if _point_in_water(world_x, world_z):
		return "water"
	# Check mesh placement zones for bunker/fairway classification
	for entry in _placement_data:
		var ex: float = entry.get("godot_x", 0.0)
		var ez: float = entry.get("godot_z", 0.0)
		var ms: Array = entry.get("mesh_size", [1.0, 1.0])
		var hw: float = ms[0] * 0.5
		var hd: float = ms[1] * 0.5
		if abs(world_x - ex) < hw and abs(world_z - ez) < hd:
			var type: String = entry.get("type", "rough")
			if type == "bunker":
				return "bunker"
			if type == "fairway":
				return "fairway"
	# Fall back to terrain zone
	var scene = get_tree().current_scene
	if scene:
		var terrain = scene.get_node_or_null("HoleTerrain")
		if terrain and terrain.has_method("get_surface_type"):
			return terrain.get_surface_type(world_x, world_z)
	return "rough"

func _setup_ball_cam():
	ball_cam = Camera3D.new()
	ball_cam.name = "BallCam"
	ball_cam.fov = 55.0
	ball_cam.current = false
	add_child(ball_cam)

func _setup_tracer():
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tracer_mesh = MeshInstance3D.new()
	_tracer_mesh.name = "BallTracer"
	_tracer_mesh.material_override = mat
	var scene = get_tree().current_scene
	if scene:
		scene.call_deferred("add_child", _tracer_mesh)
	else:
		call_deferred("add_child", _tracer_mesh)

func launch(from: Vector3, p_power: float, p_accuracy: float, p_draw_fade: float, p_loft: float, aim_target: Vector3, p_club_yards: float, p_is_putt: bool = false, p_stimp: float = 8.0):
	power = p_power
	accuracy = p_accuracy
	draw_fade = p_draw_fade
	loft = p_loft
	club_yards = p_club_yards
	is_putt = p_is_putt
	stimp = p_stimp
	current_max_distance_meters = club_yards * YARDS_TO_METERS

	global_position = from
	start_pos = from
	time_in_flight = 0.0
	tracer_points.clear()
	visible = true
	in_bunker_flag = false
	landed_surface = "fairway"

	var forward = aim_target - from
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()
	var right = Vector3(forward.z, 0.0, -forward.x).normalized()

	if is_putt:
		var max_putt_meters = (stimp / 8.0) * 10.0
		var distance = power * max_putt_meters
		var accuracy_error = (1.0 - accuracy) * 0.8
		var total_lateral = accuracy_error * (randf() - 0.5) * 2.0
		land_pos = from + forward * distance + right * total_lateral
		land_pos.y = _get_terrain_y(land_pos.x, land_pos.z) + 0.08
		roll_dir = (land_pos - from).normalized()
		roll_dir.y = 0.0
		state = BallState.ROLLING
		scale = Vector3(1.0, 1.0, 1.0)
		# No ball cam for putts
	else:
		var distance = power * current_max_distance_meters
		var accuracy_error = (1.0 - accuracy) * 15.0
		var curve_offset = draw_fade * distance * 0.12
		var total_lateral = curve_offset + (accuracy_error * (randf() - 0.5) * 2.0)
		land_pos = from + forward * distance + right * total_lateral
		land_pos.y = _get_terrain_y(land_pos.x, land_pos.z) + 0.08
		# Apply wind effect to landing position
		var wind = get_tree().current_scene.get_node_or_null("WindSystem")
		if wind:
			land_pos = wind.apply_to_ball(from, land_pos, power, loft)
			land_pos.y = _get_terrain_y(land_pos.x, land_pos.z) + 0.08
		roll_dir = (land_pos - from).normalized()
		roll_dir.y = 0.0
		state = BallState.FLYING
		cam_timer = 0.0
		# Store reference to player cam so we can restore it
		var scene = get_tree().current_scene
		if scene:
			var player = scene.get_node_or_null("Player")
			if player:
				player_cam = player.get_node_or_null("Camera3D")
		if ball_cam:
			ball_cam.current = true

func _update_ball_cam():
	if ball_cam == null or not ball_cam.current:
		return
	# Position camera behind and slightly above the ball, looking forward
	var behind = -roll_dir * 6.0 + Vector3(0, 3.0, 0)
	ball_cam.global_position = global_position + behind
	ball_cam.look_at(global_position + roll_dir * 5.0, Vector3.UP)

func _restore_player_cam():
	if player_cam:
		player_cam.current = true
	if ball_cam:
		ball_cam.current = false

func _process(delta):
	if state == BallState.IDLE or state == BallState.STOPPED:
		return

	if state == BallState.FLYING:
		time_in_flight += delta * FLIGHT_SPEED
		if time_in_flight >= 1.0:
			time_in_flight = 1.0
			state = BallState.ROLLING
			global_position = land_pos

		var t = time_in_flight
		var base_height = power * 25.0
		var loft_mult = 1.0 + loft * 0.6
		var peak_height = base_height * loft_mult
		var arc_y = peak_height * 4.0 * t * (1.0 - t)
		var new_pos = start_pos.lerp(land_pos, t)
		# Interpolate ground elevation between start and land, then add arc
		new_pos.y = lerp(start_pos.y, land_pos.y, t) + arc_y

		# Scale ball gently with distance so it stays visible without becoming a beachball
		var cam = get_viewport().get_camera_3d()
		if cam and not ball_cam.current:
			var dist = global_position.distance_to(cam.global_position)
			var scale_factor = clamp(dist * 0.012, 1.0, 2.5)
			scale = Vector3(scale_factor, scale_factor, scale_factor)
		else:
			scale = Vector3(1.0, 1.0, 1.0)

		global_position = new_pos
		tracer_points.append(new_pos)
		_draw_tracer()
		_update_ball_cam()

	elif state == BallState.ROLLING:
		if is_putt:
			# Putt rolls from start_pos toward land_pos, decelerating
			var total_dist = start_pos.distance_to(land_pos)
			if total_dist < 0.01:
				state = BallState.STOPPED
				emit_signal("ball_stopped", global_position, "green")
				return
			var dist_so_far = global_position.distance_to(start_pos)
			var progress = clamp(dist_so_far / total_dist, 0.0, 1.0)
			# Ease out deceleration
			var roll_speed = clamp((1.0 - progress) * total_dist * PUTT_SPEED, 0.02, 15.0)
			global_position += roll_dir * roll_speed * delta
			global_position.y = _get_terrain_y(global_position.x, global_position.z) + 0.08
			scale = Vector3(1.0, 1.0, 1.0)
			# Check if reached or passed land_pos
			var new_dist = global_position.distance_to(start_pos)
			if new_dist >= total_dist or roll_speed <= 0.05:
				global_position.x = land_pos.x
				global_position.z = land_pos.z
				global_position.y = _get_terrain_y(land_pos.x, land_pos.z) + 0.08
				# Check cup — 0.5m gives a small "gimme" without triggering on putt start position
				if cup_pos != Vector3.ZERO:
					var dist_to_cup = Vector2(global_position.x, global_position.z).distance_to(
						Vector2(cup_pos.x, cup_pos.z))
					if dist_to_cup < 0.5:
						state = BallState.HOLING
						hole_timer = 0.0
						return
				state = BallState.STOPPED
				emit_signal("ball_stopped", global_position, "green")
		else:
			var rollout_pct := BASE_ROLLOUT
			if loft < -0.15:
				rollout_pct = 0.18
			elif loft > 0.15:
				rollout_pct = 0.04
			var surface := _get_surface_type(global_position.x, global_position.z)
			if surface == "bunker" or surface == "water":
				rollout_pct = 0.02
				in_bunker_flag = surface == "bunker"
				landed_surface = surface
			var roll_distance := power * current_max_distance_meters * rollout_pct
			var roll_speed := roll_distance * 0.8

			# Slope: deflect roll direction and adjust speed based on terrain gradient
			var normal := _get_terrain_normal(global_position.x, global_position.z)
			var gravity := Vector3(0.0, -1.0, 0.0)
			# Slope force = component of gravity tangent to terrain surface, projected to XZ
			var slope_3d := gravity - gravity.dot(normal) * normal
			var slope_xz := Vector3(slope_3d.x, 0.0, slope_3d.z)
			if slope_xz.length() > 0.005:
				roll_dir = (roll_dir + slope_xz.normalized() * slope_xz.length() * 0.35).normalized()
				var slope_along := slope_xz.normalized().dot(roll_dir)
				roll_speed = roll_speed * (1.0 + slope_along * slope_xz.length() * 0.6)

			global_position += roll_dir * roll_speed * delta
			global_position.y = _get_terrain_y(global_position.x, global_position.z) + 0.08
			roll_speed = move_toward(roll_speed, 0, roll_speed * delta * 2.0)
			_update_ball_cam()
			var dist_rolled = global_position.distance_to(land_pos)
			if dist_rolled >= roll_distance or roll_speed <= 0.01:
				# Sample final surface type at rest position
				landed_surface = _get_surface_type(global_position.x, global_position.z)
				if cup_pos != Vector3.ZERO:
					var dist_to_cup = Vector2(global_position.x, global_position.z).distance_to(
						Vector2(cup_pos.x, cup_pos.z))
					if dist_to_cup < 1.5:
						state = BallState.HOLING
						hole_timer = 0.0
						_restore_player_cam()
						return
				scale = Vector3(2.0, 2.0, 2.0)
				state = BallState.CAM_HOLD
				cam_timer = 0.0

	elif state == BallState.CAM_HOLD:
		# Camera holds on ball landing position
		cam_timer += delta
		# Slowly lower camera to ground level for dramatic look
		if ball_cam and ball_cam.current:
			var target_pos = global_position + Vector3(0, 1.5, 0) + (-roll_dir * 4.0)
			ball_cam.global_position = ball_cam.global_position.lerp(target_pos, delta * 2.0)
			ball_cam.look_at(global_position, Vector3.UP)
		if cam_timer >= CAM_HOLD_TIME:
			state = BallState.STOPPED
			_restore_player_cam()
			emit_signal("ball_stopped", global_position, landed_surface)

	elif state == BallState.HOLING:
		hole_timer += delta
		# Slide toward cup
		var t = clamp(hole_timer * 3.0, 0.0, 1.0)
		global_position = global_position.lerp(
			Vector3(cup_pos.x, global_position.y, cup_pos.z), t * delta * 4.0)
		# Shrink as it drops in
		var s = clamp(1.0 - (hole_timer / 0.6), 0.0, 1.0)
		scale = Vector3(max(s, 0.05), max(s, 0.05), max(s, 0.05))
		global_position.y = cup_pos.y - clamp(hole_timer * 0.5, 0.0, 0.3)
		if hole_timer >= 0.8:
			visible = false
			state = BallState.STOPPED
			emit_signal("ball_holed")


func _draw_tracer():
	if not _tracer_mesh:
		return
	var n := tracer_points.size()
	if n < 2:
		_tracer_mesh.mesh = null
		return
	const W := 0.18  # half-width of the ribbon in metres
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n - 1):
		var a := tracer_points[i]
		var b := tracer_points[i + 1]
		var d := b - a
		if d.length_squared() < 0.0001:
			continue
		d = d.normalized()
		var r := d.cross(Vector3.UP)
		if r.length_squared() < 0.01:
			r = d.cross(Vector3.RIGHT)
		r = r.normalized() * W
		var u := d.cross(r.normalized()).normalized() * W
		# Two perpendicular quads per segment — solid from all viewing angles
		_tracer_quad(st, a - r, a + r, b + r, b - r)
		_tracer_quad(st, a - u, a + u, b + u, b - u)
	_tracer_mesh.mesh = st.commit()

func _tracer_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3):
	st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)
	st.add_vertex(p1); st.add_vertex(p3); st.add_vertex(p4)

func is_stopped() -> bool:
	return state == BallState.STOPPED or state == BallState.IDLE

func reset():
	state = BallState.IDLE
	is_putt = false
	in_bunker_flag = false
	landed_surface = "fairway"
	tracer_points.clear()
	if _tracer_mesh:
		_tracer_mesh.mesh = null
	_restore_player_cam()
	visible = false
