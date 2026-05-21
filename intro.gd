extends Node3D
## intro.gd — Game session shell. Holds persistent systems only.
## Does NOT touch terrain, geometry, or hole data directly.
## All course/hole logic lives in the hole scene loaded into CurrentHole.

@onready var current_hole_root: Node3D = $CurrentHole
@onready var hole_loader: Node         = $HoleLoader

var _course_data: Dictionary = {}
var _current_hole_num: int   = 1


func _ready() -> void:
	_setup_environment()
	if GameState.current_course.is_empty():
		# DEV: load Woody's directly for testing
		var f = FileAccess.open("res://courses/woodys_test/course.json", FileAccess.READ)
		if f:
			var json = JSON.new()
			if json.parse(f.get_as_text()) == OK:
				GameState.current_course = json.get_data()
				GameState.current_course["safe_name"] = "woodys_test"
				print("DEV: loaded Woody's course.json for testing")
			f.close()
		else:

			push_warning("Main: no course loaded — returning to course select")
			get_tree().change_scene_to_file("res://scenes/course_select.tscn")
			return

	_course_data   = GameState.current_course
	_current_hole_num = GameState.current_hole

	print("Main: loaded course — %s" % _course_data.get("name", "Unknown"))
	print("Main: starting hole %d" % _current_hole_num)

	hole_loader.hole_loaded.connect(_on_hole_loaded)
	hole_loader.hole_load_failed.connect(_on_hole_load_failed)

	_load_hole(_current_hole_num)


## Called by scorecard / HUD when player advances to next hole.
func go_to_next_hole() -> void:
	_current_hole_num += 1
	var total = _course_data.get("holes", []).size()
	if _current_hole_num > total:
		_finish_round()
		return
	GameState.current_hole = _current_hole_num
	_load_hole(_current_hole_num)


func _load_hole(hole_num: int) -> void:
	# For now load directly from res://courses/woodys_test terrain
	# TODO: build proper per-course hole scene from extract_path
	var hole_scene := "res://courses/hole_%02d.tscn" % hole_num
	if FileAccess.file_exists(hole_scene):
		hole_loader.load_hole(hole_scene)
	else:
		push_warning("No hole scene for hole %d" % hole_num)
		_on_hole_load_failed(hole_scene)


func _on_hole_loaded(hole_node: Node3D) -> void:
	print("Main: hole %d loaded → %s" % [_current_hole_num, hole_node.name])
	
	# DEBUG: Add a bright red marker at origin so we can see scale/position
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 20, 4)
	marker.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 0)
	marker.material_override = mat
	marker.position = Vector3(0, 10, 0)
	hole_node.add_child(marker)
	
	var player = get_node_or_null("Player")
	if player:
		player.global_position = Vector3(0, 200.0, 0)
		player.rotation = Vector3.ZERO
		print("Main: player spawned above terrain center")


func _on_hole_load_failed(path: String) -> void:
	push_error("Main: failed to load hole scene: " + path)


func _finish_round() -> void:
	print("Main: round complete!")
	# TODO: show final scorecard then return to course select
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env       := Environment.new()
	var sky       := Sky.new()
	var sky_mat   := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.18, 0.42, 0.82)
	sky_mat.sky_horizon_color    = Color(0.65, 0.82, 0.98)
	sky_mat.ground_bottom_color  = Color(0.20, 0.48, 0.18)
	sky_mat.ground_horizon_color = Color(0.38, 0.58, 0.30)
	sky_mat.sun_angle_max        = 30.0
	sky.sky_material             = sky_mat
	env.background_mode          = Environment.BG_SKY
	env.sky                      = sky
	env.ambient_light_source     = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy     = 1.0
	env.tonemap_mode             = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure         = 1.0
	world_env.environment        = env
	add_child(world_env)
	print("intro: environment ready")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/course_select.tscn")
		elif event.keycode == KEY_F1:
			var mode = Input.get_mouse_mode()
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE if mode == Input.MOUSE_MODE_CAPTURED
				else Input.MOUSE_MODE_CAPTURED
			)


# ── Course data helpers ───────────────────────────────────────────────────

func _get_hole_data(hole_num: int) -> Dictionary:
	for hole in _course_data.get("holes", []):
		if hole.get("hole_number") == hole_num:
			return hole
	return {}


func _get_tee_position(hole_data: Dictionary) -> Vector3:
	for tee in hole_data.get("tees", []):
		if tee.get("type") == "Championship":
			var p = tee.get("position", {})
			return Vector3(p.get("x", 0.0), p.get("y", 2.0), p.get("z", 0.0))
	return Vector3(0, 2, 0)


func _get_par(hole_data: Dictionary) -> int:
	for tee in hole_data.get("tees", []):
		if tee.get("type") == "Championship":
			return int(str(tee.get("par", "4")).replace("_", ""))
	return 4


func _get_yardage(hole_data: Dictionary) -> float:
	for tee in hole_data.get("tees", []):
		if tee.get("type") == "Championship":
			var tee_pos = tee.get("position", {})
			var pins    = hole_data.get("pins", [])
			if pins.size() > 0:
				var pin_pos = pins[0].get("position", {})
				var tv = Vector3(tee_pos.get("x",0), 0, tee_pos.get("z",0))
				var pv = Vector3(pin_pos.get("x",0), 0, pin_pos.get("z",0))
				return tv.distance_to(pv) * 1.0936  # metres to yards
	return 0.0
