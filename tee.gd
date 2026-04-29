extends Area3D

@export var hole_number := 1
@export var par := 3
@export var yardage := 180

var connected_player = null

signal player_on_tee

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody3D:
		connected_player = body
		emit_signal("player_on_tee")
		if connected_player.has_method("on_player_at_tee"):
			connected_player.on_player_at_tee(hole_number, par, yardage)

func _on_body_exited(body):
	if body is CharacterBody3D:
		connected_player = null
