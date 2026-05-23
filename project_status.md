# Open World Golf — Project Status

## Current State (May 21 2026 — Evening)

### WORKING ✅
- Full scene flow: title → golfer_select → course_select → intro
- Player walks AND CLIMBS HILLS on real terrain
- HeightMapShape3D collision — mesh and collision same grid, no holes
- Water plane at terrain minimum height with Area3D hazard trigger
- Slope/height preview shader (UV2.x fix applied, testing in progress)
- SurfaceTool smooth normals
- Wind system, sky, environment
- 4 courses converted with v2 converter
- Practice Range as active test course

### IN PROGRESS 🔄
- Terrain shader color classification (UV2.x fix just applied, not yet confirmed)
- Shader shows green mountains (normals work) but height check still debugging

### NOT WORKING YET ❌
- Viewfinder — stubs only, Golf-O-Matic not connected
- Address screen — needs viewfinder first
- Ball physics — not tested
- Proper tee spawn (hardcoded to 750,500,300 for testing)

### NEXT SESSION PRIORITIES
1. Confirm terrain shader works (green flat, tan slope, grey cliff, blue water)
2. Wire Golf-O-Matic viewfinder from solo-golf-backup/player.gd
3. Address screen
4. Ball drop test
5. Reconvert all 4 courses with v2 converter + terrain_heights.json

## Key Coordinates (Practice Range)
- Terrain: origin (0,0,0), size 1501×600m, Y range 117-253m
- Water plane: y=118.13
- Player spawn: (750, 500, 300) — falls onto surface
- Tee: (495, 50, 285) in course.json

## Session History
### May 21 2026
- Rebuilt entire terrain pipeline with terrain_generator_new.gd
- pg_to_owg_converter_v2.py now outputs terrain_heights.json
- HeightMapShape3D uses same downsampled grid as visual mesh
- Water plane + Area3D hazard added
- Slope/height shader with UV2.x world Y workaround
- Player confirmed walking and climbing hills on Practice Range

## Session May 23 2026 — Texture & Mesh Pipeline

### FIXED THIS SESSION ✅
- Camera far clip 100→3000m (terrain was being clipped out of view)
- Splatmap textures now apply: terrain_generator_new reads splat_layers.json,
  4-layer splatmap shader (terrain_splatmap.gdshader)
- Splatmap orientation: flipped vertically in converter to match heightmap
- Terrain backface culling fixed: cull_disabled + forced upward normals
  (was showing only half the hills, other half invisible/walkable)
- Removed old texture_map material system (course_loader.apply_terrain_material gone)
- intro.gd now loads terrain from SELECTED course's extract_path
  (was hardcoded to hole_01.tscn = practice range for ALL courses)
- get_terrain_height() raycast method added for proper per-course spawn
- Ball placed on tee at hole start, player faces pin, visible ball mesh
  (ball_texture2.png from assets/balls)
- All 4 courses reconverted from Steam PG sources:
  /home/ron/.local/share/Steam/steamapps/common/Perfect Golf/Courses/
  (zip the course folder first, then convert)
- Ported mesh + object extraction from old converter (v3) into v2:
  extract_meshes() + extract_objects() with v2 identity coords
  Practice Range: 90 meshes, 264 placements extracted into course.json "objects"

### KNOWN ISSUE — NEXT SESSION 🔄
- Object placement coords don't fully align with terrain:
  objects Y:46-215 Z:85-1303 vs terrain Y:117-253 Z:0-600
  Need coordinate calibration between Unity object world-transforms and
  the terrain_heights.json mapping
- No Godot-side mesh loader yet: need code in intro.gd/hole_loader to read
  course_data["objects"] and instantiate each .obj at its position/rotation/scale
- Spline meshes (fairways/greens/bunkers/yardage flags) are what make it look
  like the splash image — terrain splat is just base ground (dirt/rock/grass)

### CONVERTER NOTES
- pg_to_owg_converter_v2.py is now the complete converter (terrain + meshes + objects)
- v2 keeps Unity coords unchanged (identity), heightmap flipud only
- Steam PG courses are loose folders — zip before converting:
  zip -j /tmp/course.zip "PATH/coursename/"*
