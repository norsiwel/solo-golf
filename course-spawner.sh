# course_spawner.gd
# Place this in your scene. It reads the JSON and instantiates the world.

extends Node3D

@export var tree_scene: PackedScene # Drag an AssetLib tree here
@export var bunker_scene: PackedScene # Drag an AssetLib bunker here
@export var flag_scene: PackedScene

var hole_data = {}

func load_and_build(json_path: String):
    var file = FileAccess.open(json_path, FileAccess.READ)
    hole_data = JSON.parse_string(file.get_as_text())
    build_hole()

func build_hole():
    # 1. Place Fixed Points
    _spawn_at(hole_data.tee_position, flag_scene) # Just a placeholder marker
    _spawn_at(hole_data.pin_position, flag_scene) # The actual flag

    # 2. Build Fairway "Corridor"
    var waypoints = hole_data.shots # Array of Vector3
    for i in range(waypoints.size() - 1):
        var start = waypoints[i]
        var end = waypoints[i+1]
        
        # 3. Generate Trees along the edges (Procedural Map)
        # We calculate the distance between points and scatter trees on the sides
        _scatter_trees(start, end)

    # 4. Generate Hazards based on distance to pin
    _spawn_strategic_hazards(hole_data.pin_position, hole_data.shots)

func _scatter_trees(start: Vector3, end: Vector3):
    var direction = (end - start).normalized()
    var distance = start.distance_to(end)
    var steps = distance / 10.0 # Place trees every 10 meters
    
    for i in steps:
        var point_on_path = start + (direction * i * 10)
        
        # Left Side Tree
        var left_pos = point_on_path + Vector3(-direction.z, 0, direction.x) * 20.0
        _spawn_at(left_pos, tree_scene)
        
        # Right Side Tree
        var right_pos = point_on_path + Vector3(direction.z, 0, -direction.x) * 20.0
        _spawn_at(right_pos, tree_scene)

func _spawn_strategic_hazards(pin_pos: Vector3, shots: Array):
    # Logic: If a shot point is ~120-150 yards from pin, spawn a bunker
    for shot in shots:
        var dist = shot.distance_to(pin_pos)
        if dist > 100 and dist < 150: # 100-150 meters approx
            # Spawn bunker slightly to the side of the landing zone
            var offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
            _spawn_at(shot + offset, bunker_scene)

func _spawn_at(pos: Vector3, scene: PackedScene):
    if scene:
        var inst = scene.instantiate()
        inst.position = pos
        add_child(inst)