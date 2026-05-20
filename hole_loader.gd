## hole_loader.gd
## Attached to Main — handles dynamic loading of hole scenes
## into the CurrentHole container node.
##
## Usage:
##   HoleLoader.load_hole("res://courses/hole_01.tscn")
##   HoleLoader.load_hole_by_number(3)
##
## Emits:
##   hole_loaded(hole_node: Node3D)   — after successful instantiation
##   hole_load_failed(path: String)   — if load returns null

extends Node
class_name HoleLoader

signal hole_loaded(hole_node: Node3D)
signal hole_load_failed(path: String)

const HOLE_PATH_TEMPLATE := "res://courses/hole_%02d.tscn"

var current_hole: Node3D = null

@onready var _hole_root: Node3D = get_node("/root/Main/CurrentHole")


## Load a hole scene by its res:// path.
## The previous hole (if any) is freed first.
func load_hole(path: String) -> void:
	# Free previous hole — tears down terrain, geometry, physics bodies
	if current_hole:
		current_hole.queue_free()
		current_hole = null
		# Let the engine process the free before adding the new scene
		await get_tree().process_frame

	# Load the packed scene
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("HoleLoader: could not load hole scene: " + path)
		emit_signal("hole_load_failed", path)
		return

	# Instantiate into CurrentHole
	current_hole = packed.instantiate() as Node3D
	if current_hole == null:
		push_error("HoleLoader: instantiate() returned null for: " + path)
		emit_signal("hole_load_failed", path)
		return

	# Reset root transforms — no inherited offsets, no surprises
	current_hole.position = Vector3.ZERO
	current_hole.rotation = Vector3.ZERO
	current_hole.scale    = Vector3.ONE

	_hole_root.add_child(current_hole)
	emit_signal("hole_loaded", current_hole)
	print("HoleLoader: loaded → ", path)


## Convenience method — load by hole number (1-based).
func load_hole_by_number(hole_num: int) -> void:
	var path := HOLE_PATH_TEMPLATE % hole_num
	load_hole(path)


## Unload (free) the current hole without loading a new one.
func unload_hole() -> void:
	if current_hole:
		current_hole.queue_free()
		current_hole = null
		print("HoleLoader: current hole unloaded")


## Returns true if a hole is currently instantiated.
func has_hole() -> bool:
	return current_hole != null and is_instance_valid(current_hole)
