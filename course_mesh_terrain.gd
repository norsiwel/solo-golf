extends StaticBody3D
class_name CourseMeshTerrain

# Loads a pre-converted GLB mesh from the extracted Unity course assets
# and provides walkable collision for the player.
#
# The mesh is in the source game's LOCAL coordinate space, centered near (0,0,0).
# mesh_offset positions it so the mesh lines up with the course's world coordinates.
#
# Default offset = course center: Vector3(1175.1, -23.6, -1093.6)
#   (X/Z = centroid of all 18 tee/pin positions; Y = -(Unity terrain Y ≈ 23.6)
#    because the game normalizes terrain Y to 0 but the mesh Y is relative to 0)
#
# Adjust mesh_offset in the inspector until the ground looks right.

@export var mesh_path: String = "res://courses/Spline_Mesh_4516.glb"
@export var mesh_offset: Vector3 = Vector3(1175.1, -23.6, -1093.6)
@export var build_on_ready: bool = true

var _mesh_instance: MeshInstance3D

func _ready():
	if build_on_ready:
		call_deferred("build")

func build():
	if not ResourceLoader.exists(mesh_path):
		push_warning("CourseMeshTerrain: mesh not found: " + mesh_path)
		return

	var scene = load(mesh_path)
	if not scene:
		push_error("CourseMeshTerrain: failed to load " + mesh_path)
		return

	var inst = scene.instantiate()
	position = mesh_offset

	# Walk the imported scene to grab the first MeshInstance3D
	var mesh_node = _find_mesh(inst)
	if not mesh_node or not mesh_node.mesh:
		push_error("CourseMeshTerrain: no mesh found in " + mesh_path)
		inst.queue_free()
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh_node.mesh
	add_child(_mesh_instance)
	inst.queue_free()

	# Build ConcavePolygonShape3D from the mesh for per-triangle collision
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(_mesh_instance.mesh.get_faces())
	var col = CollisionShape3D.new()
	col.shape = shape
	add_child(col)

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

func get_height_at(world_x: float, world_z: float) -> float:
	# Raycast downward to sample terrain height at any world XZ position
	var space = get_world_3d().direct_space_state
	var from = Vector3(world_x, 100.0, world_z)
	var to   = Vector3(world_x, -10.0, world_z)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_layer
	var result = space.intersect_ray(query)
	if result:
		return result.position.y
	return 0.0
