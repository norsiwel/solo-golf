extends Area3D

# Green properties
@export var stimp := 8.0          # green speed 1-13, 8 is medium
@export var par := 3
@export var hole_number := 1

# Cup position relative to green center (set in editor or here)
var cup_local_pos := Vector3(0, 0, 0)  # center of green by default
var cup_radius := 0.27               # real hole radius in meters

# State
var ball_on_green := false
var connected_player = null

signal ball_entered_green
signal ball_holed_out(strokes: int)

func _ready():
	# Connect area signals
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		return
	# Ball entered green
	ball_on_green = true
	emit_signal("ball_entered_green")
	if connected_player:
		connected_player.on_ball_entered_green(stimp, get_cup_world_pos())

func _on_body_exited(body):
	if body.name == "Player":
		return
	ball_on_green = false

func get_cup_world_pos() -> Vector3:
	return global_position + cup_local_pos

func check_hole_out(ball_pos: Vector3, strokes: int) -> bool:
	var dist = Vector2(ball_pos.x, ball_pos.z).distance_to(
		Vector2(get_cup_world_pos().x, get_cup_world_pos().z))
	if dist <= cup_radius:
		emit_signal("ball_holed_out", strokes)
		return true
	return false
