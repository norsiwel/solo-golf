extends Node3D
## hole_scene.gd
## Loads terrain via TerrainGenerator and sets up a hole for play.
## Attach to the root node of any hole scene.

@export var heightmap_path: String = ""
@export var hole_number: int = 1

var terrain: StaticBody3D = null

func _ready() -> void:
	_build_terrain()

func _build_terrain() -> void:
	# OWG courses store their heightmap path in GameState; fall back to @export
	var hm_path: String = GameState.current_course.get("heightmap_path", heightmap_path)
	if hm_path == "":
		push_warning("HoleScene: no heightmap_path set")
		return

	terrain = preload("res://terrain_generator.gd").new()
	terrain.name = "HoleTerrain"
	add_child(terrain)

	terrain.load_heightmap(hm_path)

	var tee := Vector3.ZERO
	var pin := Vector3.ZERO
	var course: Dictionary = GameState.current_course
	if not course.is_empty():
		for hole: Dictionary in course.get("holes", []):
			if hole.get("hole_number") == hole_number:
				for t: Dictionary in hole.get("tees", []):
					if t.get("type") == "Championship":
						var p: Dictionary = t.get("position", {})
						tee = Vector3(p.get("x", 0), p.get("y", 0), p.get("z", 0))
				var pins: Array = hole.get("pins", [])
				if pins.size() > 0:
					var p: Dictionary = pins[0].get("position", {})
					pin = Vector3(p.get("x", 0), p.get("y", 0), p.get("z", 0))
				break

	print("HoleScene: building hole %d tee=%s pin=%s" % [hole_number, tee, pin])
	terrain.load_textures()
	terrain.build_from_hole(tee, pin)
	print("HoleScene: terrain built, tee height=%.2fm" % terrain.get_height_at(tee.x, tee.z))


## Called by intro.gd after hole loads to get the ground height at any world position.
func get_terrain_height(world_x: float, world_z: float) -> float:
	if terrain and terrain.has_method("get_height_at"):
		return terrain.get_height_at(world_x, world_z)
	return 0.0
