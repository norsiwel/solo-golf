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
var ball_mesh: MeshInstance3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_sky()
	_setup_hud()
	_setup_address_screen()

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
	$HUD/VFBorder.visible = false
	$HUD/Crosshair.visible = false
	$HUD/YardageLabel.visible = false
	$HUD/VFHint.visible = false
	yaw = vf_yaw
	pitch = 0.0
	$Camera3D.rotation.x = 0.0

func _open_address():
	addressing = true
	# Spawn ball 1.2m in front of player on the ground
	if ball_mesh == null:
		ball_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 1)
		sphere.surface_set_material(0, mat)
		ball_mesh.mesh = sphere
		get_parent().add_child(ball_mesh)
	var forward = -global_transform.basis.z
	ball_mesh.global_position = global_position + forward * 1.2
	ball_mesh.global_position.y = 0.025
	ball_mesh.visible = true
	address_screen.open_screen()

func _close_address():
	addressing = false
	address_screen.close_screen()

func _on_shot_confirmed(power: float, accuracy: float, draw_fade: float, loft: float):
	_close_address()
	# Ball flight will be added next
	var msg = $HUD/AimLabel
	msg.text = "Shot! Pwr:%d%% Acc:%d%% %s Loft:%s" % [
		int(power * 100),
		int(accuracy * 100),
		"Draw" if draw_fade < -0.1 else ("Fade" if draw_fade > 0.1 else "Straight"),
		"Hi" if loft > 0.1 else ("Lo" if loft < -0.1 else "Mid")
	]

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
	var to = from + (-camera.global_transform.basis.z * 500.0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if result:
		var dist_meters = global_position.distance_to(result.position)
		aim_yardage = dist_meters * 1.094
		aim_point = result.position
		$HUD/YardageLabel.text = "%d yds" % int(aim_yardage)
	else:
		aim_yardage = 0.0
		$HUD/YardageLabel.text = "--- yds"
