extends Node3D

func _ready():
	var terrain = self
	if terrain.has_method("add_region"):
		terrain.add_region(Vector2i(0, 0))
