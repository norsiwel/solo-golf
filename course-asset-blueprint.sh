# course_blueprint_spawner.gd
extends Node3D

@export var tree_scenes: Array[PackedScene]
@export var bunker_scene: PackedScene
@export var wildlife_scene: PackedScene
@export var blueprint_path: String = "res://courses/The_Old_Course_blueprint.json"

func _ready():
    build_from_blueprint()

func build_from_blueprint():
    var file = FileAccess.open(blueprint_path, FileAccess.READ)
    if not file: return
    var blueprint = JSON.parse_string(file.get_as_text())
    file.close()

    for hole in blueprint.holes:
        _spawn_assets(hole.assets)

func _spawn_assets(assets: Dictionary):
    # Spawn Trees
    for tree in assets.trees:
        var pos = Vector3(tree.position[0], tree.position[1], tree.position[2])
        var scene = tree_scenes[tree.variation - 1] if tree.variation <= tree_scenes.size() else tree_scenes[0]
        var inst = scene.instantiate()
        inst.position = pos
        inst.rotation.y = randf_range(0, TAU)
        add_child(inst)

    # Spawn Hazards
    for hazard in assets.hazards:
        var pos = Vector3(hazard.position[0], hazard.position[1], hazard.position[2])
        var inst = bunker_scene.instantiate()
        inst.position = pos
        inst.scale = Vector3.ONE * (hazard.radius / 6.0)
        add_child(inst)

    # Spawn Wildlife
    for wildlife in assets.wildlife_spawns:
        var pos = Vector3(wildlife.position[0], wildlife.position[1], wildlife.position[2])
        var inst = wildlife_scene.instantiate()
        inst.position = pos
        inst.set_meta("idle_radius", wildlife.idle_radius)
        add_child(inst)