# Auto-generated terrain setup for Sunset Valley GC
# Paste this into your Terrain3D node script or call from main.gd

# Terrain3D import settings:
#   Heightmap PNG: Sunset_Valley_GC_heightmap.png
#   Size: 1024x1024
#   World size X/Z: 1145.4m
#   Height scale Y: 56.0m
#   Origin offset: (573.5, 2.5, 662.0)

const COURSE_NAME = "Sunset Valley GC"
const WORLD_SIZE = 1145.4
const HEIGHT_SCALE = 56.0
const TERRAIN_ORIGIN = Vector3(573.45, 2.46, 661.97)
const MIN_ELEVATION = 2.46
const MAX_ELEVATION = 30.48

func setup_terrain(terrain_node):
	terrain_node.position = TERRAIN_ORIGIN
	# Set size and height in Terrain3D inspector:
	# storage.size = 1024
	# storage.height_range = Vector2(2.5, 36.1)
	print("Terrain setup for: ", COURSE_NAME)
