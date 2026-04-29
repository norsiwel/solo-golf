extends CharacterBody3D

@export var mouse_sensitivity := 0.002
@export var walk_speed := 5.0
@export var gravity := 9.8

var yaw := 0.0
var pitch := 0.0

# Viewfinder state
var viewfinder_active := false
var aim_point := Vector3.ZERO
var aim_yardage := 0.0
var aim_locked := false
var vf_yaw := 0.0
var vf_pitch := 0.0

# Address screen
var address_screen: CanvasLayer
var addressing := false
var ball: Node3D
var on_green := false
var stroke_count := 0
var green_node = null
var scorecard: CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_sky()
	_setup_hud()
	_setup_address_screen()
	# Connect green after scene is ready
	call_deferred("_connect_green")

func _setup_sky():
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.45, 0.85)
	sky_mat.sky_horizon_color = Color(0.7, 0.85, 1.0)
	sky_mat.ground_bottom_color = Color(0.2, 0.55, 0.15)
	sky_mat.ground_horizon_color = Color(0.4, 0.6, 0.3)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	get_viewport().get_camera_3d().environment = env

func _setup_address_screen():
	address_screen = preload("res://address_screen.gd").new()
	add_child(address_screen)
	address_screen.connect("shot_confirmed", _on_shot_confirmed)
	# Set up ball node
	ball = preload("res://ball.gd").new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	sphere.surface_set_material(0, mat)
	var ball_vis = MeshInstance3D.new()
	ball_vis.mesh = sphere
	ball.add_child(ball_vis)
	get_parent().call_deferred("add_child", ball)
	ball.visible = false
	ball.connect("ball_holed", _on_ball_holed)
	# Set up scorecard
	scorecard = preload("res://scorecard.gd").new()
	add_child(scorecard)
	scorecard.connect("play_again", _on_play_again)
	scorecard.connect("next_hole", _on_next_hole)

func _setup_hud():
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var vf_border = Panel.new()
	vf_border.name = "VFBorder"
	vf_border.visible = false
	vf_border.set_anchor(SIDE_LEFT, 0.35)
	vf_border.set_anchor(SIDE_TOP, 0.3)
	vf_border.set_anchor(SIDE_RIGHT, 0.65)
	vf_border.set_anchor(SIDE_BOTTOM, 0.7)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.border_color = Color(1.0, 0.9, 0.3, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	vf_border.add_theme_stylebox_override("panel", style)
	canvas.add_child(vf_border)

	var crosshair = Label.new()
	crosshair.name = "Crosshair"
	crosshair.text = "+"
	crosshair.visible = false
	crosshair.set_anchor(SIDE_LEFT, 0.5)
	crosshair.set_anchor(SIDE_TOP, 0.5)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	canvas.add_child(crosshair)

	var yardage_label = Label.new()
	yardage_label.name = "YardageLabel"
	yardage_label.text = "--- yds"
	yardage_label.visible = false
	yardage_label.set_anchor(SIDE_LEFT, 0.5)
	yardage_label.set_anchor(SIDE_TOP, 0.62)
	yardage_label.add_theme_font_size_override("font_size", 28)
	yardage_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	canvas.add_child(yardage_label)

	var vf_hint = Label.new()
	vf_hint.name = "VFHint"
	vf_hint.text = "Move mouse to aim  |  Left click to lock"
	vf_hint.visible = false
	vf_hint.set_anchor(SIDE_LEFT, 0.5)
	vf_hint.set_anchor(SIDE_TOP, 0.68)
	vf_hint.add_theme_font_size_override("font_size", 14)
	vf_hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	canvas.add_child(vf_hint)

	var aim_label = Label.new()
	aim_label.name = "AimLabel"
	aim_label.text = ""
	aim_label.set_anchor(SIDE_LEFT, 0.5)
	aim_label.set_anchor(SIDE_TOP, 0.08)
	aim_label.add_theme_font_size_override("font_size", 20)
	aim_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	canvas.add_child(aim_label)

func _input(event):
	if addressing:
		return

	if event is InputEventMouseMotion:
		if viewfinder_active:
			vf_yaw -= event.relative.x * mouse_sensitivity
			vf_pitch -= event.relative.y * mouse_sensitivity
			vf_pitch = clamp(vf_pitch, -1.0, 0.3)
			rotation.y = vf_yaw
			$Camera3D.rotation.x = vf_pitch
		else:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, -1.2, 1.2)
			rotation.y = yaw
			$Camera3D.rotation.x = pitch

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if viewfinder_active:
				_lock_aim()

	if event is InputEventKey:
		if event.keycode == KEY_V:
			if event.pressed and not viewfinder_active:
				_open_viewfinder()
			elif not event.pressed and viewfinder_active:
				_close_viewfinder()
		if event.pressed:
			if event.keycode == KEY_SPACE and not viewfinder_active:
				if aim_locked:
					_open_address()
				else:
					$HUD/AimLabel.text = "Use V to aim first!"
			if event.keycode == KEY_ESCAPE:
				if addressing:
					_close_address()
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _open_viewfinder():
	viewfinder_active = true
	vf_yaw = yaw
	vf_pitch = pitch
	# Zoom in like a real rangefinder
	$Camera3D.fov = 25.0
	$HUD/VFBorder.visible = true
	$HUD/Crosshair.visible = true
	$HUD/YardageLabel.visible = true
	$HUD/VFHint.visible = true

func _lock_aim():
	aim_locked = true
	var hud_aim = $HUD/AimLabel
	if aim_yardage > 0:
		hud_aim.text = "AIM SET: %d yds" % int(aim_yardage)
	else:
		hud_aim.text = "AIM SET"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3)
	style.border_color = Color(0.3, 1.0, 0.3, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	$HUD/VFBorder.add_theme_stylebox_override("panel", style)

func _close_viewfinder():
	viewfinder_active = false
	# Restore normal FOV
	$Camera3D.fov = 75.0
	$HUD/VFBorder.visible = false
	$HUD/Crosshair.visible = false
	$HUD/YardageLabel.visible = false
	$HUD/VFHint.visible = false
	yaw = vf_yaw
	pitch = 0.0
	$Camera3D.rotation.x = 0.0

func _open_address():
	addressing = true
	var shot_dir = aim_point - global_position
	shot_dir.y = 0.0
	if shot_dir.length() < 0.01:
		shot_dir = -global_transform.basis.z
		shot_dir.y = 0.0
	shot_dir = shot_dir.normalized()
	ball.global_position = global_position + shot_dir * 1.2
	ball.global_position.y = 0.025
	ball.visible = true
	address_screen.open_screen()

func _close_address():
	addressing = false
	address_screen.close_screen()

func _connect_green():
	green_node = get_parent().get_node_or_null("GreenArea")
	if green_node:
		green_node.connected_player = self
		green_node.connect("ball_holed_out", _on_ball_holed_out)

func on_player_at_tee(hole: int, par: int, yardage: int):
	# Reset putting mode when back on tee
	on_green = false
	address_screen.set_putting_mode(false)
	$HUD/AimLabel.text = "Hole %d  Par %d  %d yds  |  V to aim  Space to address" % [hole, par, yardage]

func on_ball_entered_green(stimp: float, cup_world_pos: Vector3):
	on_green = true
	# Tell the ball where the cup is so it can roll in
	if ball:
		ball.cup_pos = cup_world_pos
		ball.stimp = stimp
	$HUD/AimLabel.text = "On the green!  Stimp: %.0f  |  Putter selected  |  Press Space to putt" % stimp
	address_screen.set_putting_mode(true, stimp)

func _on_ball_holed_out(strokes: int):
	on_green = false
	ball.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	scorecard.show_scorecard(1, 3, 180, strokes)

func _on_ball_holed():
	# Ball animation finished dropping into cup
	on_green = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	scorecard.show_scorecard(1, 3, 180, stroke_count)

func _on_play_again():
	stroke_count = 0
	on_green = false
	aim_locked = false
	ball.reset()
	ball.cup_pos = Vector3.ZERO
	ball.visible = false
	$HUD/AimLabel.text = ""
	address_screen.set_putting_mode(false)
	global_position = Vector3(0, 2.0, 0)
	yaw = 0.0
	pitch = 0.0
	rotation.y = 0.0
	$Camera3D.rotation.x = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_next_hole():
	# Placeholder for future holes
	_on_play_again()

func _on_shot_confirmed(p_power: float, p_accuracy: float, p_draw_fade: float, p_loft: float, club: Dictionary):
	_close_address()
	stroke_count += 1
	var launch_pos = ball.global_position
	ball.connect("ball_stopped", _on_ball_stopped, CONNECT_ONE_SHOT)
	var club_yards = float(club.get("full_yards", 240))
	var p_is_putt = club.get("name", "") == "Putter"
	var p_stimp = ball.stimp if p_is_putt else 8.0
	ball.launch(launch_pos, p_power, p_accuracy, p_draw_fade, p_loft, aim_point, club_yards, p_is_putt, p_stimp)
	var msg = $HUD/AimLabel
	if p_is_putt:
		msg.text = "Putt %d!  Pwr:%d%%  Acc:%d%%" % [stroke_count, int(p_power * 100), int(p_accuracy * 100)]
	else:
		msg.text = "Shot %d! %s %dy  Pwr:%d%%  Acc:%d%%  %s  Loft:%s" % [
			stroke_count,
			str(club.get("name", "Club")),
			int(club_yards),
			int(p_power * 100),
			int(p_accuracy * 100),
			"Draw" if p_draw_fade < -0.1 else ("Fade" if p_draw_fade > 0.1 else "Straight"),
			"Hi" if p_loft > 0.1 else ("Lo" if p_loft < -0.1 else "Mid")
		]

func _on_ball_stopped(pos: Vector3, in_bunker: bool):
	var dist_yards = global_position.distance_to(pos) * 1.094
	if in_bunker:
		$HUD/AimLabel.text = "In the bunker! %.0f yds away  |  Press W to walk" % dist_yards
	else:
		$HUD/AimLabel.text = "Ball stopped - %.0f yds away  |  Press W to walk" % dist_yards
	if green_node and on_green:
		green_node.check_hole_out(pos, stroke_count)

func _physics_process(delta):
	if viewfinder_active:
		_update_yardage()

	if addressing:
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

func _update_yardage():
	var camera = $Camera3D
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * 500.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	# Check if crosshair is near the flagstick - snap to it
	var flag_node = get_parent().get_node_or_null("Flagstick")
	var snapped_to_flag := false
	if flag_node:
		var flag_pos = flag_node.global_position
		# Project flag position onto screen and check distance to center
		var flag_screen = camera.unproject_position(flag_pos)
		var screen_center = get_viewport().get_visible_rect().size / 2.0
		var screen_dist = flag_screen.distance_to(screen_center)
		if screen_dist < 60.0:  # within 60 pixels of crosshair
			var dist_meters = global_position.distance_to(flag_pos)
			aim_yardage = dist_meters * 1.094
			aim_point = flag_pos
			aim_point.y = 0.0
			snapped_to_flag = true
			$HUD/YardageLabel.text = "📍 FLAG  %d yds" % int(aim_yardage)
			# Turn crosshair red to show snap
			$HUD/Crosshair.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))

	if not snapped_to_flag:
		$HUD/Crosshair.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		if result:
			var dist_meters = global_position.distance_to(result.position)
			aim_yardage = dist_meters * 1.094
			aim_point = result.position
			$HUD/YardageLabel.text = "%d yds" % int(aim_yardage)
		else:
			aim_yardage = 0.0
			$HUD/YardageLabel.text = "--- yds"
