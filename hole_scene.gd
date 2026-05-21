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
	if heightmap_path == "":
		push_warning("HoleScene: no heightmap_path set")
		return

	terrain = preload("res://terrain_generator.gd").new()
	add_child(terrain)

	# Load heightmap — reads terrain_meta.json from same folder
	terrain.load_heightmap(heightmap_path)

	# Get tee/pin from GameState course data
	var tee := Vector3.ZERO
	var pin := Vector3.ZERO
	var course = GameState.current_course
	if not course.is_empty():
		for hole in course.get("holes", []):
			if hole.get("hole_number") == hole_number:
				for t in hole.get("tees", []):
					if t.get("type") == "Championship":
						var p = t.get("position", {})
						tee = Vector3(p.get("x", 0), p.get("y", 0), p.get("z", 0))
				var pins = hole.get("pins", [])
				if pins.size() > 0:
					var p = pins[0].get("position", {})
					pin = Vector3(p.get("x", 0), p.get("y", 0), p.get("z", 0))
				break

	print("HoleScene: building hole %d tee=%s pin=%s" % [hole_number, tee, pin])
	terrain.load_textures()
	terrain.build_from_hole(tee, pin)
