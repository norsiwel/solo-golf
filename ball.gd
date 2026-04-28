extends Node3D

# Ball flight parameters - set before calling launch()
var power := 0.0
var accuracy := 0.0
var draw_fade := 0.0   # -1 draw, 0 straight, 1 fade
var loft := 0.0        # -1 low, 0 normal, 1 high
var club_yards := 240.0

# Internal state
enum BallState { IDLE, FLYING, ROLLING, STOPPED }
var state := BallState.IDLE
var velocity := Vector3.ZERO
var time_in_flight := 0.0
var start_pos := Vector3.ZERO
var land_pos := Vector3.ZERO
var roll_dir := Vector3.ZERO
var current_max_distance_meters := 220.0

# Tracer
var tracer_points: Array[Vector3] = []
var tracer_mesh: ImmediateMesh
var tracer_instance: MeshInstance3D

# Constants
const YARDS_TO_METERS := 0.9144
const BASE_ROLLOUT := 0.10
const FLIGHT_SPEED := 2.5           # how fast we animate the flight

signal ball_stopped(position: Vector3)

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

	# The tracer points are global-world points, so keep the tracer in the main scene,
	# not as a moving child of the ball.
	var scene = get_tree().current_scene
	if scene:
		scene.call_deferred("add_child", tracer_instance)
	else:
		call_deferred("add_child", tracer_instance)

func launch(from: Vector3, p_power: float, p_accuracy: float, p_draw_fade: float, p_loft: float, aim_target: Vector3, p_club_yards: float):
	power = p_power
	accuracy = p_accuracy
	draw_fade = p_draw_fade
	loft = p_loft
	club_yards = p_club_yards
	current_max_distance_meters = club_yards * YARDS_TO_METERS

	global_position = from
	start_pos = from
	state = BallState.FLYING
	time_in_flight = 0.0
	tracer_points.clear()
	visible = true

	# Calculate landing position from the locked aim point, not camera-facing yaw.
	var forward = aim_target - from
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()
	var right = Vector3(forward.z, 0.0, -forward.x).normalized()

	var distance = power * current_max_distance_meters
	var accuracy_error = (1.0 - accuracy) * 15.0
	var curve_offset = draw_fade * distance * 0.12
	var total_lateral = curve_offset + (accuracy_error * (randf() - 0.5) * 2.0)

	land_pos = from + forward * distance + right * total_lateral
	land_pos.y = 0.025

	roll_dir = (land_pos - from).normalized()
	roll_dir.y = 0.0

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
		var rollout_pct = BASE_ROLLOUT
		if loft < -0.15:
			rollout_pct = 0.18
		elif loft > 0.15:
			rollout_pct = 0.04
		var roll_distance = power * current_max_distance_meters * rollout_pct
		var roll_speed = roll_distance * 0.8

		global_position += roll_dir * roll_speed * delta
		roll_speed = move_toward(roll_speed, 0, roll_speed * delta * 2.0)

		var dist_rolled = global_position.distance_to(land_pos)
		if dist_rolled >= roll_distance or roll_speed <= 0.01:
			state = BallState.STOPPED
			scale = Vector3(2.0, 2.0, 2.0)
			emit_signal("ball_stopped", global_position)

func _draw_tracer():
	if tracer_mesh == null or tracer_instance == null:
		return
	tracer_mesh.clear_surfaces()
	if tracer_points.size() < 2:
		return
	tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in tracer_points:
		# Convert world-space shot points into the tracer's local space.
		tracer_mesh.surface_add_vertex(tracer_instance.to_local(pt))
	tracer_mesh.surface_end()

func reset():
	state = BallState.IDLE
	tracer_points.clear()
	if tracer_mesh:
		tracer_mesh.clear_surfaces()
	visible = false
