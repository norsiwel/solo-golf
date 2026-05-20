extends CharacterBody3D

## MOVEMENT SETTINGS
@export var walk_speed: float = 3.5      # Normal walking (m/s)
@export var brisk_speed: float = 5.0     # Shift to walk faster
@export var crouch_speed: float = 1.5    # Crouched (reading greens)
@export var sprint_speed: float = 6.0    # Sprint (escape bunkers)
@export var acceleration: float = 12.0
@export var friction: float = 10.0
@export var air_control: float = 0.3
@export var gravity: float = 20.0
@export var jump_velocity: float = 4.5

## STAMINA SYSTEM (for sprinting)
@export var max_stamina: float = 100.0
@export var stamina_drain_sprint: float = 30.0
@export var stamina_regen: float = 20.0
var current_stamina: float = 100.0
var is_exhausted: bool = false

## CAMERA SETTINGS
@export var mouse_sensitivity: float = 0.002
var yaw: float = 0.0
var pitch: float = 0.0

## CROUCH SYSTEM
var is_crouching: bool = false
var normal_height: float = 1.8
var crouch_height: float = 0.9
var current_camera_height: float = 1.8

## STATE MACHINE
enum PlayerState {
	WALKING,
	CROUCHING,
	SPRINTING,
	SWINGING,
	IN_AIR,
	IN_BUNKER,
	IN_WATER
}
var current_state: PlayerState = PlayerState.WALKING

## SURFACE DETECTION
var current_surface: String = "fairway"
var is_on_green: bool = false
var is_in_bunker: bool = false
var is_in_water: bool = false

## CAMERA BONUS FEATURES
var bob_frequency: float = 2.0
var bob_amplitude: float = 0.05
var bob_time: float = 0.0

## EXISTING GOLF VARIABLES (preserved from your script)
var viewfinder_active := false
var aim_point := Vector3.ZERO
var aim_yardage := 0.0
var aim_locked := false
var vf_yaw := 0.0
var vf_pitch := 0.0
var addressing := false
var ball: Node3D
var on_green := false
var on_tee := false
var stroke_count := 0
var green_node = null
var scorecard: CanvasLayer
var putt_aim_active := false
var putt_aim_offset := 0.0
var _near_ball := false
var _stance_cam: Camera3D = null
var right_handed := true

## NODES
@onready var camera: Camera3D = $Camera3D
var head: Node3D  # built in _setup_head, not a scene node
var hud: CanvasLayer  # built in _setup_hud
#@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio  # TODO: add sounds
#@onready var jump_audio: AudioStreamPlayer3D = $JumpAudio
#@onready var land_audio: AudioStreamPlayer3D = $LandAudio

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_hud()
	_setup_address_screen()
	_setup_head()
	call_deferred("_connect_green")
	
	print("=== GOLFER READY ===")
	print("Controls: WASD = walk | Shift = brisk/sprint | C = crouch | Space = jump")
	print("Golf: V = rangefinder | Space near ball = address | LMB = swing")

func _setup_head():
	# Setup head node for camera bobbing
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	camera.reparent(head)
	camera.position = Vector3(0, normal_height, 0)
	head.position = Vector3(0, 0, 0)

func _setup_hud():
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	
	# Crosshair
	var crosshair = Label.new()
	crosshair.name = "Crosshair"
	crosshair.text = "·"
	crosshair.visible = true
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchor(SIDE_LEFT, 0.5)
	crosshair.set_anchor(SIDE_TOP, 0.5)
	crosshair.add_theme_font_size_override("font_size", 24)
	crosshair.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	canvas.add_child(crosshair)
	
	# Stamina bar
	var stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.position = Vector2(20, 20)
	stamina_bar.size = Vector2(200, 20)
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	stamina_bar.visible = true
	canvas.add_child(stamina_bar)
	
	# Surface indicator
	var surface_label = Label.new()
	surface_label.name = "SurfaceLabel"
	surface_label.position = Vector2(20, 50)
	surface_label.add_theme_font_size_override("font_size", 14)
	surface_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	canvas.add_child(surface_label)
	
	# Speed indicator (optional - for debugging)
	var speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.position = Vector2(20, 80)
	speed_label.add_theme_font_size_override("font_size", 12)
	speed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	canvas.add_child(speed_label)
	
	# Green reading overlay (appears when crouching on green)
	var green_overlay = ColorRect.new()
	green_overlay.name = "GreenOverlay"
	green_overlay.color = Color(0.2, 0.4, 0.2, 0.3)
	green_overlay.position = Vector2(0, 0)
	green_overlay.size = Vector2(100, 100)
	green_overlay.visible = false
	canvas.add_child(green_overlay)
	
	# Store references
	hud = canvas

func _setup_address_screen():
	# Your existing address screen setup
	pass

func _input(event):
	# Don't process movement input during golf swing
	if addressing:
		return
	
	# Mouse look
	if event is InputEventMouseMotion and not viewfinder_active:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.4, 1.4)
		rotation.y = yaw
		camera.rotation.x = pitch
	
	# Viewfinder mode (V key)
	if event is InputEventKey and event.keycode == KEY_V:
		if event.pressed:
			_open_viewfinder()
		else:
			_close_viewfinder()
	
	# Jump (Space)
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if is_on_floor() and not viewfinder_active and not addressing:
			_jump()
	
	# Crouch (C key - toggle)
	if event is InputEventKey and event.keycode == KEY_C:
		if event.pressed:
			_start_crouch()
		else:
			_stop_crouch()
	
	# Your existing golf input handlers
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if on_green and not addressing:
				_lock_putt_aim_facing()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if viewfinder_active:
				_lock_aim()
			elif on_green and aim_locked and not addressing:
				_open_address()
	
	# ESC to release mouse
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	_update_stamina(delta)
	_update_surface_detection()
	
	var speed = _get_current_speed()
	var movement = _get_movement_input()
	
	# Apply terrain speed modifier
	speed *= _get_terrain_speed_modifier()
	
	# Apply movement
	if is_on_floor():
		if movement.length() > 0:
			velocity.x = move_toward(velocity.x, movement.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, movement.z * speed, acceleration * delta)
			_play_footstep_sound(delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
	else:
		# Air control
		if movement.length() > 0:
			velocity.x += movement.x * air_control * delta
			velocity.z += movement.z * air_control * delta
		velocity.y -= gravity * delta
	
	move_and_slide()
	
	# Landing sound
	if is_on_floor() and velocity.y <= 0 and _was_in_air:
		_play_land_sound()
	
	_was_in_air = !is_on_floor()
	
	# Update camera bobbing
	_update_camera_bobbing(delta)
	
	# Update crouch height
	_update_crouch_height(delta)
	
	# Update HUD
	_update_hud()
	
	# Your existing golf physics
	_check_ball_stance()
	if viewfinder_active:
		_update_yardage()

var _was_in_air: bool = false

func _get_movement_input() -> Vector3:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	
	input_dir = input_dir.normalized()
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func _get_current_speed() -> float:
	match current_state:
		PlayerState.SPRINTING:
			return sprint_speed
		PlayerState.CROUCHING:
			return crouch_speed
		PlayerState.IN_BUNKER:
			return walk_speed * 0.5
		_:
			return brisk_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

func _get_terrain_speed_modifier() -> float:
	match current_surface:
		"fairway", "green", "path", "tee":
			return 1.0
		"rough":
			return 0.7
		"deep_rough":
			return 0.4
		"bunker":
			return 0.3
		"water":
			return 0.0
		_:
			return 0.8

func _update_surface_detection():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),
		global_position + Vector3(0, -0.5, 0)
	)
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.has_meta("surface_type"):
		var new_surface = result.collider.get_meta("surface_type")
		if new_surface != current_surface:
			current_surface = new_surface
			_on_surface_changed()
		
		is_in_bunker = current_surface == "bunker"
		is_in_water = current_surface == "water"
		is_on_green = current_surface == "green"
		
		# Update state based on bunker
		if is_in_bunker and current_state != PlayerState.IN_BUNKER:
			current_state = PlayerState.IN_BUNKER
		elif not is_in_bunker and current_state == PlayerState.IN_BUNKER:
			current_state = PlayerState.WALKING

func _on_surface_changed():
	# Visual feedback - screen tint
	var tint = hud.get_node_or_null("SurfaceTint")
	if not tint:
		tint = ColorRect.new()
		tint.name = "SurfaceTint"
		tint.position = Vector2(0, 0)
		tint.size = Vector2(1920, 1080)
		hud.add_child(tint)
	
	match current_surface:
		"rough":
			tint.color = Color(0.3, 0.4, 0.2, 0.1)
			hud/SurfaceLabel.text = "ROUGH - Slower movement"
		"deep_rough":
			tint.color = Color(0.2, 0.3, 0.1, 0.2)
			hud/SurfaceLabel.text = "DEEP ROUGH - Very slow"
		"bunker":
			tint.color = Color(0.8, 0.7, 0.5, 0.15)
			hud/SurfaceLabel.text = "BUNKER - Use sprint+jump to escape"
		"green":
			tint.color = Color(0.2, 0.5, 0.2, 0.05)
			hud/SurfaceLabel.text = "GREEN - Crouch to read putts"
		"fairway":
			tint.color = Color(0, 0, 0, 0)
			hud/SurfaceLabel.text = "FAIRWAY"
		_:
			hud/SurfaceLabel.text = ""

func _start_crouch():
	if current_state == PlayerState.SWINGING:
		return
	
	is_crouching = true
	current_state = PlayerState.CROUCHING
	current_camera_height = crouch_height
	
	# Show green reading overlay on greens
	if is_on_green:
		var overlay = hud/GreenOverlay
		if overlay:
			overlay.visible = true
			_show_green_contours()

func _stop_crouch():
	# Check if there's room to stand
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, crouch_height, 0),
		global_position + Vector3(0, normal_height, 0)
	)
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		is_crouching = false
		current_state = PlayerState.WALKING
		current_camera_height = normal_height
		
		var overlay = hud/GreenOverlay
		if overlay:
			overlay.visible = false

func _update_crouch_height(delta):
	var target = current_camera_height
	var current = camera.position.y
	var new_y = move_toward(current, target, delta * 8.0)
	camera.position.y = new_y

func _jump():
	if is_in_water:
		return
	
	var jump_power = jump_velocity
	if is_in_bunker:
		# Explosive jump out of sand
		jump_power = jump_velocity * 1.5
		# Add forward momentum
		var forward = -camera.global_transform.basis.z
		velocity.x += forward.x * 5.0
		velocity.z += forward.z * 5.0
		_show_bunker_escape_effect()
	
	velocity.y = jump_power
	current_state = PlayerState.IN_AIR
	#jump_audio.play()  # TODO: add sounds

func _show_bunker_escape_effect():
	# Flash white and show text
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.position = Vector2(0, 0)
	flash.size = Vector2(1920, 1080)
	hud.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	await tween.finished
	flash.queue_free()
	
	var label = hud.get_node_or_null("BunkerEscape")
	if not label:
		label = Label.new()
		label.name = "BunkerEscape"
		label.position = Vector2(960, 540)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1, 1, 0))
		hud.add_child(label)
	
	label.text = "⚡ BUNKER ESCAPE! ⚡"
	label.position = Vector2(960 - label.size.x / 2, 540)
	await get_tree().create_timer(1.5).timeout
	label.text = ""

func _update_stamina(delta):
	if current_state == PlayerState.SPRINTING and is_on_floor():
		current_stamina -= stamina_drain_sprint * delta
		
		if current_stamina <= 0:
			current_stamina = 0
			is_exhausted = true
			_stop_sprint()
			
			# Show exhausted message
			var exhausted_label = Label.new()
			exhausted_label.text = "GASPING FOR AIR..."
			exhausted_label.position = Vector2(960, 400)
			exhausted_label.add_theme_font_size_override("font_size", 18)
			hud.add_child(exhausted_label)
			await get_tree().create_timer(2.0).timeout
			exhausted_label.queue_free()
			is_exhausted = false
	else:
		current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
	
	# Update stamina bar
	var stamina_bar = hud/StaminaBar
	if stamina_bar:
		stamina_bar.value = current_stamina
		
		# Change color based on stamina level
		if current_stamina < 30:
			stamina_bar.modulate = Color(1, 0.3, 0.3)
		elif current_stamina < 60:
			stamina_bar.modulate = Color(1, 0.8, 0.3)
		else:
			stamina_bar.modulate = Color(0.3, 1, 0.3)

func _start_sprint():
	if current_stamina > 10 and not is_exhausted and not is_in_bunker:
		current_state = PlayerState.SPRINTING
		# FOV increase for sprint feel
		var tween = create_tween()
		tween.tween_property(camera, "fov", 80.0, 0.2)

func _stop_sprint():
	if current_state == PlayerState.SPRINTING:
		current_state = PlayerState.WALKING
		var tween = create_tween()
		tween.tween_property(camera, "fov", 75.0, 0.2)

func _play_footstep_sound(delta):
	if not is_on_floor():
		return
	
	# Calculate step timing based on speed
	var step_interval = 0.5 / (velocity.length() / walk_speed)
	if step_interval < 0.15:
		step_interval = 0.15
	
	if Time.get_ticks_msec() / 1000.0 > _last_footstep + step_interval:
		_last_footstep = Time.get_ticks_msec() / 1000.0
		
		# Select footstep sound based on surface
	# TODO: add sounds -- sound_map and footstep_audio disabled until sounds folder exists
	#var sound_map = {
		#"fairway": preload("res://sounds/footstep_grass.wav"),
		#"rough": preload("res://sounds/footstep_rough.wav"),
		#"green": preload("res://sounds/footstep_grass_short.wav"),
		#"bunker": preload("res://sounds/footstep_sand.wav"),
		#"path": preload("res://sounds/footstep_gravel.wav"),
		#"tee": preload("res://sounds/footstep_grass.wav"),
	#}
	#var sound = sound_map.get(current_surface, sound_map["fairway"])
	#if sound:
		#footstep_audio.stream = sound
		#footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		#footstep_audio.volume_db = -10 if current_state == PlayerState.CROUCHING else -5
		#footstep_audio.play()

var _last_footstep: float = 0.0

func _play_land_sound():
	pass  # TODO: add sounds
	#if land_audio.stream:
		#land_audio.pitch_scale = randf_range(0.8, 1.2)
		#land_audio.volume_db = -15 + (abs(velocity.y) * 2)
		#land_audio.play()

func _update_camera_bobbing(delta):
	if is_on_floor() and velocity.length() > 0.5 and current_state != PlayerState.SWINGING:
		var speed_factor = velocity.length() / walk_speed
		bob_time += delta * bob_frequency * speed_factor
		var bob_y = sin(bob_time) * bob_amplitude
		var bob_x = cos(bob_time * 0.5) * bob_amplitude * 0.3
		
		head.position.y = current_camera_height + bob_y
		head.rotation.z = bob_x
	else:
		head.position.y = move_toward(head.position.y, current_camera_height, delta * 10.0)
		head.rotation.z = move_toward(head.rotation.z, 0.0, delta * 10.0)

func _update_hud():
	var speed_label = hud/SpeedLabel
	if speed_label:
		var speed_kph = velocity.length() * 3.6
		speed_label.text = "%d km/h" % speed_kph

func _show_green_contours():
	# Show green grid overlay for putting
	var overlay = hud/GreenOverlay
	if overlay and green_node:
		overlay.visible = true
		overlay.size = get_viewport().get_visible_rect().size
		
		# Draw slope arrows (simplified)
		var slope = _get_green_slope_at_position()
		var arrow = Label.new()
		arrow.text = "▼" if slope > 0 else "▲"
		arrow.add_theme_font_size_override("font_size", 48)
		arrow.position = Vector2(overlay.size.x / 2 - 30, overlay.size.y / 2 - 30)
		overlay.add_child(arrow)
		
		var slope_text = Label.new()
		slope_text.text = "%d%% slope" % abs(slope * 100)
		slope_text.position = Vector2(overlay.size.x / 2 - 50, overlay.size.y / 2 + 20)
		overlay.add_child(slope_text)

func _get_green_slope_at_position() -> float:
	# Sample terrain normal at current position
	var terrain = get_node("/root/Game/TerrainGenerator")
	if terrain and terrain.has_method("get_normal_at"):
		var normal = terrain.get_normal_at(global_position.x, global_position.z)
		return Vector3.UP.angle_to(normal)
	return 0.0

# ============ YOUR EXISTING GOLF FUNCTIONS (preserved) ============

func _open_viewfinder():
	viewfinder_active = true
	# Your existing viewfinder code
	pass

func _close_viewfinder():
	viewfinder_active = false
	# Your existing close code
	pass

func _lock_aim():
	aim_locked = true
	# Your existing lock aim code
	pass

func _lock_putt_aim_facing():
	aim_locked = true
	# Your existing putt aim code
	pass

func _open_address():
	addressing = true
	# Your existing address code
	pass

func _close_address():
	addressing = false
	# Your existing close address code
	pass

func _update_yardage():
	# Your existing yardage code
	pass

func _check_ball_stance():
	# Your existing ball stance code
	pass

func _connect_green():
	# Your existing green connection code
	pass

func _on_shot_confirmed(p_power, p_accuracy, p_draw_fade, p_loft, club):
	# Your existing shot confirmed code
	pass

func _on_ball_stopped(pos, surface):
	# Your existing ball stopped code
	pass

func on_player_at_tee(hole, par, yardage):
	on_green = false
	on_tee = true
	# Your existing tee code
	pass

func on_ball_entered_green(stimp, cup_world_pos):
	on_green = true
	# Your existing green entry code
	pass

func _on_ball_holed():
	# Your existing holed code
	pass

func _on_play_again():
	# Your existing play again code
	pass

func _on_next_hole():
	# Your existing next hole code
	pass
