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
enum BallState { IDLE, FLYING, ROLLING, HOLING, STOPPED }
var state := BallState.IDLE
var velocity := Vector3.ZERO
var time_in_flight := 0.0
var start_pos := Vector3.ZERO
var land_pos := Vector3.ZERO
var roll_dir := Vector3.ZERO
var current_max_distance_meters := 220.0
var cup_pos := Vector3.ZERO
var hole_timer := 0.0

signal ball_holed
signal ball_stopped(position: Vector3, in_bunker: bool)

# Tracer
var tracer_points: Array[Vector3] = []
var tracer_mesh: ImmediateMesh
var tracer_instance: MeshInstance3D

const YARDS_TO_METERS := 0.9144
const BASE_ROLLOUT := 0.10
const FLIGHT_SPEED := 2.5
const PUTT_SPEED := 1.5  # slower roll animation for putting

func _ready():
	_setup_tracer()

func _setup_tracer():
	tracer_mesh = ImmediateMesh.new()
	tracer_instance = MeshInstance3D.new()
	tracer_instance.mesh = tracer_mesh
	tracer_instance.name = "BallTracer"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_instance.material_override = mat
	var scene = get_tree().current_scene
	if scene:
		scene.call_deferred("add_child", tracer_instance)
	else:
		call_deferred("add_child", tracer_instance)

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

	var forward = aim_target - from
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()
	var right = Vector3(forward.z, 0.0, -forward.x).normalized()

	if is_putt:
		# Putting - no flight, goes straight to rolling on ground
		# Stimp 8 = medium speed. Max putt distance scales with stimp and power
		# Full power on stimp 8 = ~10 meters, stimp 12 = ~15 meters
		var max_putt_meters = (stimp / 8.0) * 10.0
		var distance = power * max_putt_meters
		# Putting accuracy error is much smaller - within ~0.5m at worst
		var accuracy_error = (1.0 - accuracy) * 0.8
		var total_lateral = accuracy_error * (randf() - 0.5) * 2.0
		land_pos = from + forward * distance + right * total_lateral
		land_pos.y = 0.025
		roll_dir = (land_pos - from).normalized()
		roll_dir.y = 0.0
		state = BallState.ROLLING  # skip flying entirely
		scale = Vector3(1.0, 1.0, 1.0)
	else:
		# Normal shot - full arc flight
		var distance = power * current_max_distance_meters
		var accuracy_error = (1.0 - accuracy) * 15.0
		var curve_offset = draw_fade * distance * 0.12
		var total_lateral = curve_offset + (accuracy_error * (randf() - 0.5) * 2.0)
		land_pos = from + forward * distance + right * total_lateral
		land_pos.y = 0.025
		roll_dir = (land_pos - from).normalized()
		roll_dir.y = 0.0
		state = BallState.FLYING

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
		new_pos.y = land_pos.y + arc_y

		var cam = get_viewport().get_camera_3d()
		if cam:
			var dist = global_position.distance_to(cam.global_position)
			var scale_factor = clamp(dist * 0.04, 1.0, 8.0)
			scale = Vector3(scale_factor, scale_factor, scale_factor)

		global_position = new_pos
		tracer_points.append(new_pos)
		_draw_tracer()

	elif state == BallState.ROLLING:
		var in_bunker := false
		var roll_distance: float
		var roll_speed: float

		if is_putt:
			# Putting roll - smooth deceleration, stays on ground
			roll_distance = start_pos.distance_to(land_pos)
			var progress = global_position.distance_to(start_pos) / max(roll_distance, 0.01)
			# Ease out - fast start slow finish like a real putt
			roll_speed = clamp((1.0 - progress) * roll_distance * PUTT_SPEED, 0.01, 20.0)
			global_position += roll_dir * roll_speed * delta
			global_position.y = 0.025  # keep on ground
			scale = Vector3(1.0, 1.0, 1.0)
		else:
			# Normal shot rollout
			var rollout_pct = BASE_ROLLOUT
			if loft < -0.15:
				rollout_pct = 0.18
			elif loft > 0.15:
				rollout_pct = 0.04
			in_bunker = _check_bunker()
			if in_bunker:
				rollout_pct = 0.02
			roll_distance = power * current_max_distance_meters * rollout_pct
			roll_speed = roll_distance * 0.8
			global_position += roll_dir * roll_speed * delta
			roll_speed = move_toward(roll_speed, 0, roll_speed * delta * 2.0)

		var dist_rolled = global_position.distance_to(start_pos if is_putt else land_pos)
		var stop_dist = start_pos.distance_to(land_pos) if is_putt else (power * current_max_distance_meters * BASE_ROLLOUT)

		if dist_rolled >= stop_dist or roll_speed <= 0.01:
			if cup_pos != Vector3.ZERO:
				var dist_to_cup = Vector2(global_position.x, global_position.z).distance_to(
					Vector2(cup_pos.x, cup_pos.z))
				if dist_to_cup < 1.5:
					state = BallState.HOLING
					hole_timer = 0.0
					return
			state = BallState.STOPPED
			if not is_putt:
				scale = Vector3(2.0, 2.0, 2.0)
			emit_signal("ball_stopped", global_position, in_bunker)

	elif state == BallState.HOLING:
		hole_timer += delta
		global_position = global_position.lerp(cup_pos, hole_timer * delta * 5.0)
		var s = clamp(1.0 - (hole_timer / 0.5), 0.05, 2.0) * 2.0
		scale = Vector3(s, s, s)
		global_position.y = cup_pos.y - (hole_timer * 0.3)
		if hole_timer >= 0.7:
			visible = false
			state = BallState.STOPPED
			emit_signal("ball_holed")

func _check_bunker() -> bool:
	var scene = get_tree().current_scene
	for bunker_name in ["Bunker1Area", "Bunker2Area"]:
		var bunker = scene.get_node_or_null(bunker_name)
		if bunker:
			var bunker_pos = bunker.global_position
			var col_name = "Bunker1Collision" if bunker_name == "Bunker1Area" else "Bunker2Collision"
			var bunker_col = bunker.get_node_or_null(col_name)
			if bunker_col and bunker_col.shape:
				var shape_size = bunker_col.shape.size
				var local_pos = global_position - bunker_pos
				if abs(local_pos.x) < shape_size.x / 2.0 and abs(local_pos.z) < shape_size.z / 2.0:
					return true
	return false

func _draw_tracer():
	if tracer_mesh == null or tracer_instance == null:
		return
	tracer_mesh.clear_surfaces()
	if tracer_points.size() < 2:
		return
	tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in tracer_points:
		tracer_mesh.surface_add_vertex(tracer_instance.to_local(pt))
	tracer_mesh.surface_end()

func reset():
	state = BallState.IDLE
	is_putt = false
	tracer_points.clear()
	if tracer_mesh:
		tracer_mesh.clear_surfaces()
	visible = false
