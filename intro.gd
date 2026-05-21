extends Node3D
## intro.gd — Game session shell. Holds persistent systems only.
## Does NOT touch terrain, geometry, or hole data directly.
## All course/hole logic lives in the hole scene loaded into CurrentHole.

@onready var current_hole_root: Node3D = $CurrentHole
@onready var hole_loader: Node         = $HoleLoader

var _course_data: Dictionary = {}
var _current_hole_num: int   = 1


func _ready() -> void:
	if GameState.current_course.is_empty():
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
	var extract_path: String = _course_data.get("extract_path", "")
	var hole_scene := "user://courses/%s/hole_%02d.tscn" % [
		_course_data.get("safe_name", "course"), hole_num
	]

	# If the per-hole tscn doesn't exist yet, build it first then load
	if not FileAccess.file_exists(hole_scene):
		_build_hole_scene(hole_num, extract_path, hole_scene)
	else:
		hole_loader.load_hole(hole_scene)


func _build_hole_scene(hole_num: int, extract_path: String, out_path: String) -> void:
	# HoleBuilder lives in the hole scene — for now stub with a flat placeholder
	# TODO: move terrain_generator logic here in next session
	push_warning("Main: hole scene not found for hole %d — using flat placeholder" % hole_num)
	hole_loader.load_hole_by_number(hole_num)


func _on_hole_loaded(hole_node: Node3D) -> void:
	print("Main: hole %d loaded → %s" % [_current_hole_num, hole_node.name])

	# Position player at tee
	var player = get_node_or_null("Player")
	if player and player.has_method("on_player_at_tee"):
		var hole_data = _get_hole_data(_current_hole_num)
		var tee_pos   = _get_tee_position(hole_data)
		var par       = _get_par(hole_data)
		var yardage   = _get_yardage(hole_data)
		player.global_position = tee_pos
		player.on_player_at_tee(_current_hole_num, par, yardage)


func _on_hole_load_failed(path: String) -> void:
	push_error("Main: failed to load hole scene: " + path)


func _finish_round() -> void:
	print("Main: round complete!")
	# TODO: show final scorecard then return to course select
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


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
