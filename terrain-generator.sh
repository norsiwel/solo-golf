extends StaticBody3D
class_name TerrainGenerator

@export var resolution: int = 128
@export var margin: float = 60.0          # Meters beyond fairway edges
@export var noise_strength: float = 1.5   # Elevation variation (meters)
@export var noise_scale: float = 0.03     # Frequency of terrain rolls
@export var terrain_material: StandardMaterial3D

var _heightmap: PackedFloat32Array
var _width: int
var _depth: int
var _origin: Vector3

func build_from_waypoints(waypoints: Array, pin_pos: Vector3, tee_pos: Vector3) -> void:
	# 1. Calculate bounding box + padding
	var all_points = waypoints.duplicate()
	all_points.append(pin_pos)
	all_points.append(tee_pos)
	var bounds = AABB(all_points[0], Vector3.ZERO)
	for p in all_points:
		bounds = bounds.expand(p)
	bounds = bounds.grow(margin)
	_origin = bounds.position
	_width = resolution
	_depth = resolution

	# 2. Initialize heightmap
	_heightmap = PackedFloat32Array()
	_heightmap.resize(_width * _depth)

	# 3. Noise setup
	var noise = FastNoiseLite.new()
	noise.seed = hash(str(waypoints.size()) + str(pin_pos))
	noise.frequency = noise_scale
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	# 4. Sample elevations
	var step_x = bounds.size.x / _width
	var step_z = bounds.size.z / _depth

	for z in _depth:
		for x in _width:
			var world_pos = _origin + Vector3(x * step_x, 0, z * step_z)
			var base_height = _interpolate_path_elevation(world_pos, waypoints)
			var dist_to_path = _distance_to_path(world_pos, waypoints)
			
			# Noise fades outside fairway corridor
			var corridor_width = 35.0
			var falloff = clamp(1.0 - (dist_to_path / corridor_width), 0.0, 1.0)
			var noise_val = noise.get_noise_2d(world_pos.x, world_pos.z) * noise_strength * falloff
			
			_heightmap[z * _width + x] = base_height + noise_val

	# 5. Create collision
	var shape = HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	shape.map_data = _heightmap
	var col = CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	# 6. Create visual mesh
	var mesh = _generate_mesh()
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if terrain_material:
		mi.material_override = terrain_material
	add_child(mi)

func _interpolate_path_elevation(pos: Vector3, path: Array) -> float:
	if path.size() < 2: return pos.y
	var closest_dist = INF
	var height = 0.0
	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i+1]
		var t = clamp((pos - p1).dot(p2 - p1) / p1.distance_squared_to(p2), 0.0, 1.0)
		var projected = p1.lerp(p2, t)
		var dist = pos.distance_to(projected)
		if dist < closest_dist:
			closest_dist = dist
			height = lerp(p1.y, p2.y, t)
	return height

func _distance_to_path(pos: Vector3, path: Array) -> float:
	var min_dist = INF
	for i in range(path.size() - 1):
		var p1 = path[i]
		var p2 = path[i+1]
		var t = clamp((pos - p1).dot(p2 - p1) / p1.distance_squared_to(p2), 0.0, 1.0)
		var projected = p1.lerp(p2, t)
		var dist = pos.distance_to(projected)
		if dist < min_dist:
			min_dist = dist
	return min_dist

func _generate_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step_x = _width - 1
	var step_z = _depth - 1
	
	for z in range(step_z):
		for x in range(step_x):
			var i00 = z * _width + x
			var i10 = i00 + 1
			var i01 = i00 + _width
			var i11 = i01 + 1
			
			var p00 = Vector3(x, _heightmap[i00], z)
			var p10 = Vector3(x+1, _heightmap[i10], z)
			var p01 = Vector3(x, _heightmap[i01], z+1)
			var p11 = Vector3(x+1, _heightmap[i11], z+1)
			
			# Triangle 1
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			# Triangle 2
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p11)
	
	st.generate_normals()
	return st.commit()