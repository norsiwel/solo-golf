# Auto-generated terrain setup for The Old Course
# Paste this into your Terrain3D node script or call from main.gd

# Terrain3D import settings:
#   Heightmap PNG: The_Old_Course_heightmap.png
#   Size: 1024x1024
#   World size X/Z: 2156.9m
#   Height scale Y: 6.4m
#   Origin offset: (1175.1, 21.9, 1093.6)

const COURSE_NAME = "The Old Course"
const WORLD_SIZE = 2156.9
const HEIGHT_SCALE = 6.4
const TERRAIN_ORIGIN = Vector3(1175.09, 21.92, 1093.61)
const MIN_ELEVATION = 21.92
const MAX_ELEVATION = 25.09

func setup_terrain(terrain_node):
    terrain_node.position = TERRAIN_ORIGIN
    # Set size and height in Terrain3D inspector:
    # storage.size = 1024
    # storage.height_range = Vector2(21.9, 25.7)
    print("Terrain setup for: ", COURSE_NAME)
