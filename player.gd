extends CharacterBody3D

@export var mouse_sensitivity := 0.002
@export var walk_speed := 16.0
@export var gravity := 9.8
@export var right_handed := true   # false = left-handed (mirror stance)

var yaw := 0.0
var pitch := 0.0

# Viewfinder state
var viewfinder_active := false
var aim_point := Vector3.ZERO
var aim_yardage := 0.0
var aim_locked := false
var vf_yaw := 0.0
var vf_pitch := 0.0

# Game state
var address_screen: CanvasLayer
var addressing := false
var ball: Node3D
var on_green := false
var stroke_count := 0
var green_node = null
var scorecard: CanvasLayer

# Putting aim
var putt_aim_active := false
var putt_aim_offset := 0.0

# Auto-stance tracking
var _near_ball := false
var _stance_cam: Camera3D = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_sky()
	_setup_hud()
	_setup_address_screen()
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
	# Ball node
	ball = preload("res://ball.gd").new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.92, 0.12)  # yellow
	mat.roughness = 0.25
	mat.metallic = 0.0
	mat.metallic_specular = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.98, 0.95, 0.2)
	mat.emission_energy_multiplier = 0.7
	sphere.surface_set_material(0, mat)
	var ball_vis = MeshInstance3D.new()
	ball_vis.mesh = sphere
	ball.add_child(ball_vis)
	get_parent().call_deferred("add_child", ball)
	ball.visible = false
	ball.connect("ball_holed", _on_ball_holed)
	# Overhead stance camera — activated when player approaches the ball within 1 m
	_stance_cam = Camera3D.new()
	_stance_cam.name = "StanceCam"
	_stance_cam.fov = 50.0
	_stance_cam.current = false
	get_parent().call_deferred("add_child", _stance_cam)
	# Scorecard
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
	crosshair.text = ""
	crosshair.visible = false
	canvas.add_child(crosshair)

	var yardage_label = Label.new()
	yardage_label.name = "YardageLabel"
	yardage_label.text = "--- yds"
	yardage_label.visible = false
	yardage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yardage_label.set_anchor(SIDE_LEFT, 0.33)
	yardage_label.set_anchor(SIDE_TOP, 0.63)
	yardage_label.set_anchor(SIDE_RIGHT, 0.67)
	yardage_label.set_anchor(SIDE_BOTTOM, 0.70)
	yardage_label.add_theme_font_size_override("font_size", 22)
	yardage_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	yardage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	yardage_label.add_theme_constant_override("outline_size", 4)
	canvas.add_child(yardage_label)

	var vf_hint = Label.new()
	vf_hint.name = "VFHint"
	vf_hint.text = "Left click to lock aim"
	vf_hint.visible = false
	vf_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vf_hint.set_anchor(SIDE_LEFT, 0.33)
	vf_hint.set_anchor(SIDE_TOP, 0.70)
	vf_hint.set_anchor(SIDE_RIGHT, 0.67)
	vf_hint.set_anchor(SIDE_BOTTOM, 0.75)
	vf_hint.add_theme_font_size_override("font_size", 12)
	vf_hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	canvas.add_child(vf_hint)

	var aim_label = Label.new()
	aim_label.name = "AimLabel"
	aim_label.text = ""
	aim_label.set_anchor(SIDE_LEFT, 0.5)
	aim_label.set_anchor(SIDE_TOP, 0.08)
	aim_label.add_theme_font_size_override("font_size", 20)
	aim_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	aim_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	aim_label.add_theme_constant_override("outline_size", 4)
	canvas.add_child(aim_label)

	var putt_aim_label = Label.new()
	putt_aim_label.name = "PuttAimLabel"
	putt_aim_label.text = "← AIM →"
	putt_aim_label.visible = false
	putt_aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	putt_aim_label.set_anchor(SIDE_LEFT, 0.3)
	putt_aim_label.set_anchor(SIDE_TOP, 0.45)
	putt_aim_label.set_anchor(SIDE_RIGHT, 0.7)
	putt_aim_label.set_anchor(SIDE_BOTTOM, 0.55)
	putt_aim_label.add_theme_font_size_override("font_size", 22)
	putt_aim_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0, 1.0))
	putt_aim_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	putt_aim_label.add_theme_constant_override("outline_size", 4)
	canvas.add_child(putt_aim_label)

	# Putting cursor — centered crosshair visible on green when not addressing
	var putt_cursor = Label.new()
	putt_cursor.name = "PuttCursor"
	putt_cursor.text = "+"
	putt_cursor.visible = false
	putt_cursor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	putt_cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	putt_cursor.set_anchor(SIDE_LEFT, 0.5)
	putt_cursor.set_anchor(SIDE_TOP, 0.5)
	putt_cursor.set_anchor(SIDE_RIGHT, 0.5)
	putt_cursor.set_anchor(SIDE_BOTTOM, 0.5)
	putt_cursor.offset_left = -24
	putt_cursor.offset_right = 24
	putt_cursor.offset_top = -18
	putt_cursor.offset_bottom = 18
	putt_cursor.add_theme_font_size_override("font_size", 32)
	putt_cursor.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	putt_cursor.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	putt_cursor.add_theme_constant_override("outline_size", 4)
	canvas.add_child(putt_cursor)

	# OVB (over-the-ball) label — visible only when stance cam is active
	var ovb_label = Label.new()
	ovb_label.name = "OVBLabel"
	ovb_label.text = ""
	ovb_label.visible = false
	ovb_label.set_anchor(SIDE_LEFT, 0.01)
	ovb_label.set_anchor(SIDE_TOP, 0.42)
	ovb_label.set_anchor(SIDE_RIGHT, 0.45)
	ovb_label.set_anchor(SIDE_BOTTOM, 0.58)
	ovb_label.add_theme_font_size_override("font_size", 22)
	ovb_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	ovb_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	ovb_label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(ovb_label)

	# Viewfinder body — frame with transparent lens center
	var vf_image = TextureRect.new()
	vf_image.name = "VFImage"
	vf_image.visible = false
	vf_image.set_anchor(SIDE_LEFT, 0.25)
	vf_image.set_anchor(SIDE_TOP, 0.05)
	vf_image.set_anchor(SIDE_RIGHT, 0.75)
	vf_image.set_anchor(SIDE_BOTTOM, 0.95)
	vf_image.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	vf_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vf_image.modulate = Color(1, 1, 1, 1.0)
	var vf_tex = load("res://assets/golf_o_matic_realistic_body_transparent_lens.png")
	if vf_tex:
		vf_image.texture = vf_tex
	canvas.add_child(vf_image)

	# Viewfinder glass overlay — subtle lens sheen on top
	var vf_glass = TextureRect.new()
	vf_glass.name = "VFGlass"
	vf_glass.visible = false
	vf_glass.set_anchor(SIDE_LEFT, 0.25)
	vf_glass.set_anchor(SIDE_TOP, 0.05)
	vf_glass.set_anchor(SIDE_RIGHT, 0.75)
	vf_glass.set_anchor(SIDE_BOTTOM, 0.95)
	vf_glass.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	vf_glass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vf_glass.modulate = Color(1, 1, 1, 0.4)
	var vf_glass_tex = load("res://assets/golf_o_matic_realistic_glass_overlay.png")
	if vf_glass_tex:
		vf_glass.texture = vf_glass_tex
	canvas.add_child(vf_glass)

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
			# Exit OVB overhead cam on mouse move so player can scout freely
			if _near_ball and _stance_cam and _stance_cam.current:
				_stance_cam.current = false
				$Camera3D.current = true
				$HUD/OVBLabel.visible = false
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, -1.2, 1.2)
			rotation.y = yaw
			$Camera3D.rotation.x = pitch

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if on_green and not addressing:
				_lock_putt_aim_facing()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if viewfinder_active:
				_lock_aim()
			elif on_green and aim_locked and not addressing:
				_open_address()

	if event is InputEventKey:
		if event.keycode == KEY_V:
			if event.pressed:
				if not on_green and not viewfinder_active:
					_open_viewfinder()
			elif not event.pressed and viewfinder_active:
				_close_viewfinder()
		if event.pressed:
			if event.keycode == KEY_SPACE and not viewfinder_active:
				if on_green:
					_open_address()
				elif aim_locked:
					_open_address()
				else:
					$HUD/AimLabel.text = "Use V to aim first!"
			if event.keycode == KEY_H and not addressing:
				right_handed = not right_handed
				var side = "Right" if right_handed else "Left"
				$HUD/AimLabel.text = "%s-handed" % side
				# Re-orient stance immediately
				var main = get_parent()
				if main and main.has_method("_reorient_player"):
					main._reorient_player()
			if event.keycode == KEY_ESCAPE:
				if addressing:
					_close_address()
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _open_viewfinder():
	viewfinder_active = true
	# If OVB stance cam is active, hand off to first-person for the viewfinder
	if _stance_cam and _stance_cam.current:
		_stance_cam.current = false
		$Camera3D.current = true
	$HUD/OVBLabel.visible = false
	vf_yaw = yaw
	vf_pitch = pitch
	$Camera3D.fov = 25.0
	$HUD/VFImage.visible = true
	$HUD/VFGlass.visible = true
	$HUD/VFBorder.visible = false
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
	$Camera3D.fov = 75.0
	$HUD/VFImage.visible = false
	$HUD/VFGlass.visible = false
	$HUD/VFBorder.visible = false
	$HUD/Crosshair.visible = false
	$HUD/YardageLabel.visible = false
	$HUD/VFHint.visible = false
	yaw = vf_yaw
	pitch = 0.0
	$Camera3D.rotation.x = 0.0
	# If still in OVB zone, return to overhead stance cam
	if _near_ball and _stance_cam and _stance_cam.is_inside_tree():
		$Camera3D.current = false
		_stance_cam.current = true
		$HUD/OVBLabel.visible = true

func _lock_putt_aim_facing():
	aim_locked = true
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()
	aim_point = ball.global_position + fwd * 20.0
	$HUD/AimLabel.text = "AIM SET — left-click to putt  (Space also works)"

func _open_address():
	addressing = true
	var shot_dir: Vector3
	if on_green:
		# Ball stays on green surface where it stopped — use player facing as putt direction
		shot_dir = -global_transform.basis.z
		shot_dir.y = 0.0
		if shot_dir.length() > 0.01:
			shot_dir = shot_dir.normalized()
		aim_point = ball.global_position + shot_dir * 20.0
		# Ensure putter is selected
		address_screen.set_putting_mode(true, ball.stimp if ball else 8.0)
	else:
		shot_dir = aim_point - global_position
		shot_dir.y = 0.0
		if shot_dir.length() < 0.01:
			shot_dir = -global_transform.basis.z
			shot_dir.y = 0.0
		shot_dir = shot_dir.normalized()
		ball.global_position = global_position + shot_dir * 1.2
		ball.global_position.y = global_position.y - 0.8
		ball.visible = true
		var wind = get_parent().get_node_or_null("WindSystem")
		if wind:
			$HUD/AimLabel.text = "AIM: %d yds  |  %s" % [int(aim_yardage), wind.get_wind_description()]
	address_screen.open_screen()

func _close_address():
	addressing = false
	address_screen.close_screen()

func _connect_green():
	var hole_geo = get_parent().get_node_or_null("HoleGeometry")
	if hole_geo:
		green_node = hole_geo.get_node_or_null("GreenArea")
	if not green_node:
		green_node = get_parent().get_node_or_null("GreenArea")
	if green_node:
		green_node.connected_player = self
		if not green_node.is_connected("ball_holed_out", _on_ball_holed_out):
			green_node.connect("ball_holed_out", _on_ball_holed_out)

func on_player_at_tee(hole: int, par: int, yardage: int):
	on_green = false
	address_screen.set_putting_mode(false)
	address_screen.select_club(0)  # Driver
	$HUD/AimLabel.text = "Hole %d  Par %d  %d yds  |  V to aim  Space to address" % [hole, par, yardage]

func on_ball_entered_green(stimp: float, cup_world_pos: Vector3):
	on_green = true
	putt_aim_offset = 0.0
	if ball:
		ball.cup_pos = cup_world_pos
		ball.stimp = stimp
	$HUD/AimLabel.text = "On the green!  Stimp: %.0f  |  Mouse to aim  →  Right-click: set aim  →  Left-click: putt" % stimp
	address_screen.set_putting_mode(true, stimp)

func _on_ball_holed_out(strokes: int):
	on_green = false
	ball.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var cm = get_parent().get_node_or_null("CourseManager")
	var par = 4
	var yds = 0
	var hole_num = 1
	if cm:
		var hole = cm.get_hole_data(cm.current_hole)
		par = hole.get("par", 4)
		yds = hole.get("yardage", 0)
		hole_num = cm.current_hole
	scorecard.show_hole_result(hole_num, par, yds, strokes)

func _on_ball_holed():
	on_green = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var cm = get_parent().get_node_or_null("CourseManager")
	var par = 4
	var yds = 0
	var hole_num = 1
	if cm:
		var hole = cm.get_hole_data(cm.current_hole)
		par = hole.get("par", 4)
		yds = hole.get("yardage", 0)
		hole_num = cm.current_hole
	scorecard.show_hole_result(hole_num, par, yds, stroke_count)

func _on_play_again():
	# Replay same hole
	var main = get_parent()
	if main and main.has_method("_setup_hole"):
		var cm = main.get_node_or_null("CourseManager")
		if cm:
			main._setup_hole(cm.current_hole)

func _on_next_hole():
	var main = get_parent()
	if main and main.has_method("go_to_next_hole"):
		main.go_to_next_hole()

func _on_shot_confirmed(p_power: float, p_accuracy: float, p_draw_fade: float, p_loft: float, club: Dictionary):
	_close_address()
	_near_ball = false  # re-arm stance snap for next approach
	# Deactivate stance cam; ball_cam will take over during flight
	if _stance_cam:
		_stance_cam.current = false
	$Camera3D.current = true
	$HUD/OVBLabel.visible = false
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

func _on_ball_stopped(pos: Vector3, surface: String):
	var dist_yards = global_position.distance_to(pos) * 1.094
	match surface:
		"water":
			stroke_count += 1  # one-stroke penalty
			$HUD/AimLabel.text = "WATER! +1 penalty  %.0f yds away  |  Re-play from same spot" % dist_yards
		"bunker":
			$HUD/AimLabel.text = "In the bunker!  %.0f yds away  |  Press W to walk" % dist_yards
		"green":
			$HUD/AimLabel.text = "On the green!  Stimp: %.0f  |  Mouse aim  →  Right-click: set  →  Left-click: putt" % (green_node.stimp if green_node else 8.0)
		_:
			$HUD/AimLabel.text = "Ball stopped  %.0f yds away  |  Press W to walk" % dist_yards
	if surface == "water":
		return  # player must re-hit from same position; no green check
	# Also query terrain directly — placement data can mis-classify the green as fairway
	var terrain_surface := ""
	var hole_terrain = get_parent().get_node_or_null("HoleTerrain")
	if hole_terrain and hole_terrain.has_method("get_surface_type"):
		terrain_surface = hole_terrain.get_surface_type(pos.x, pos.z)
	# Check if ball landed on green
	if green_node and not on_green:
		var green_pos = green_node.global_position
		var dist_to_green = Vector2(pos.x, pos.z).distance_to(Vector2(green_pos.x, green_pos.z))
		if dist_to_green < 20.0 or surface == "green" or terrain_surface == "green":
			on_green = true
			var cup_world = green_node.get_cup_world_pos()
			ball.cup_pos = cup_world
			ball.stimp = green_node.stimp
			$HUD/AimLabel.text = "On the green!  Stimp: %.0f  |  Putter selected  |  Press Space to putt" % green_node.stimp
			address_screen.set_putting_mode(true, green_node.stimp)
			return
	if green_node and on_green:
		green_node.check_hole_out(pos, stroke_count)

func _physics_process(delta):
	_check_ball_stance()
	if _near_ball and _stance_cam and _stance_cam.is_inside_tree() and _stance_cam.current:
		_update_stance_cam()
	if viewfinder_active:
		_update_yardage()
	# Putting cursor: show on green when free to aim, hide otherwise
	$HUD/PuttCursor.visible = on_green and not addressing and not viewfinder_active
	if addressing:
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1

	# Exit OVB overhead cam on movement so player can walk and scout
	if input_dir != Vector2.ZERO and _near_ball and _stance_cam and _stance_cam.current:
		_stance_cam.current = false
		$Camera3D.current = true
		$HUD/OVBLabel.visible = false

	input_dir = input_dir.normalized()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	move_and_slide()

func _check_ball_stance() -> void:
	if addressing or viewfinder_active:
		return
	if not ball or not ball.visible:
		return
	if not ball.is_stopped():
		return
	var dx := global_position.x - ball.global_position.x
	var dz := global_position.z - ball.global_position.z
	var dist2d := sqrt(dx * dx + dz * dz)
	if not _near_ball and dist2d < 1.0:
		# On green aim at cup; everywhere else aim at last locked target
		var target: Vector3 = ball.cup_pos if (on_green and ball.cup_pos != Vector3.ZERO) else aim_point
		var play_dir := target - ball.global_position
		play_dir.y = 0.0
		if play_dir.length() > 0.5:
			play_dir = play_dir.normalized()
			var hand_offset := -PI * 0.5 if right_handed else PI * 0.5
			yaw = atan2(-play_dir.x, -play_dir.z) + hand_offset
			rotation.y = yaw
			pitch = 0.0
			$Camera3D.rotation.x = 0.0
		_near_ball = true
		# Switch to overhead stance camera and show OVB HUD
		if _stance_cam and _stance_cam.is_inside_tree():
			$Camera3D.current = false
			_stance_cam.current = true
		$HUD/OVBLabel.visible = true
	elif _near_ball and dist2d > 1.5:
		_near_ball = false
		# Return to player camera and hide OVB HUD
		if _stance_cam:
			_stance_cam.current = false
		$Camera3D.current = true
		$HUD/OVBLabel.visible = false

func _update_stance_cam() -> void:
	if not ball or not _stance_cam:
		return
	# Position camera 4 m above the ball looking straight down.
	# Use the player's facing direction as camera-up so the fairway / flag sit at
	# screen LEFT (player's left side = toward target in golf address stance).
	var forward := -global_transform.basis.z
	forward.y = 0.0
	var up := forward.normalized() if forward.length() > 0.1 else Vector3(1.0, 0.0, 0.0)
	_stance_cam.global_position = ball.global_position + Vector3(0, 4.0, 0)
	_stance_cam.look_at(ball.global_position, up)
	# Update OVB HUD bar
	var arrow := "←" if right_handed else "→"
	if on_green and ball.cup_pos != Vector3.ZERO:
		var cup_ft := int(ball.global_position.distance_to(ball.cup_pos) * 3.281)
		$HUD/OVBLabel.text = "%s CUP  %d ft\nV to aim  ·  SPACE to putt" % [arrow, cup_ft]
	else:
		var flag_yds := int(global_position.distance_to(aim_point) * 1.094)
		$HUD/OVBLabel.text = "%s FLAG  %d yds\nV to aim  ·  SPACE to shoot" % [arrow, flag_yds]

func _update_yardage():
	var camera = $Camera3D
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * 500.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	var hole_geo = get_parent().get_node_or_null("HoleGeometry")
	var flag_node = hole_geo.get_node_or_null("Flagstick") if hole_geo else null
	var snapped_to_flag := false

	if flag_node:
		var flag_pos = flag_node.global_position
		# Snap to camera eye-level height on the flag so the projected point
		# sits near screen center when looking straight at the pin, regardless
		# of the player's distance or standing height.
		var flag_snap = Vector3(flag_pos.x, camera.global_position.y, flag_pos.z)
		var flag_screen = camera.unproject_position(flag_snap)
		var screen_center = get_viewport().get_visible_rect().size / 2.0
		# Scale snap radius for the narrow (25°) viewfinder FOV vs normal (75°) — 3× wider.
		var snap_radius = 180.0
		if flag_screen.distance_to(screen_center) < snap_radius:
			var dist_meters = global_position.distance_to(flag_pos)
			aim_yardage = dist_meters * 1.094
			aim_point = flag_pos
			aim_point.y = global_position.y
			snapped_to_flag = true
			$HUD/YardageLabel.text = "FLAG  %d yds" % int(aim_yardage)
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
