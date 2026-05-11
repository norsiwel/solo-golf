# Open World Golf — Project Status

## Current State (May 2026)

### Working
- Full gameplay loop: walk → aim → shoot → roll → putt → hole-out → scorecard
- Title screen (Open-world-title.png) → course selector → game → ESC back to selector
- Course selector: card UI with splash images, course name/author/holes, ▶ Play button
- Both courses load and are playable: The Old Course (OWG) and Sunset Valley GC (OWG)
- Runtime heightmap terrain with correct coordinate math (verified 0.001m vs Unity)
- Shot tracer (yellow line), wind system, viewfinder rangefinder
- Putting system with stimp, cup detection, hole-out animation
- Scorecard with play-again / next-hole
- Water level datum: heightmap minimum used to zero-floor all Y positions in course.json
- Object extraction: real world positions via Transform hierarchy walk (7237/881 objects)
- Flagstick Y snapped to terrain surface via raycast in main.gd

### Session Progress (2026-05-11)

**Water level datum**
- `height_min` computed from corrected heightmap array (min of uint16 values × scale_y)
- Stored in `terrain_meta.json` as `water_level`
- All tee/pin/shot Y positions shifted by `-water_level` in course.json
- Terrain floor now sits at Y=0; ponds at or below zero
- Old Course: water_level=12.248m. Sunset Valley: water_level=0.000m
- PP_waterplane extraction via Transform hierarchy walk (Old Course: 23.43m Unity Y)

**Object extraction fix**
- Previous: all 7284/963 objects had position (0,0,0) — were prefab templates
- Fix: build `transform_map` (path_id → Transform) for all Transform objects, then walk
  `m_Father` chain root→leaf accumulating TRS with quaternion composition
- Helpers: `_quat_rotate`, `_quat_mul`, `_world_trs` (module-level + inner closures)
- Origin filter drops exact-(0,0,0) results (prefab definitions, not scene instances)
- Result: 7237 real placed objects (Old Course), 881 (Sunset Valley)
- Waterplane world Y now also computed via hierarchy walk

**Other fixes**
- `r_s: float =` explicit type hint in ball.gd (GDScript type inference fix)
- Flagstick positioned at `_raycast_ground_y()` Y rather than raw pin_pos.y
- Debug prints in terrain_generator.gd: splatmap tex state, origin/bounds/collision info
- Visual mesh offset reverted to `_origin` (no +0.02 offset needed)

### In Progress
- Terrain walkability — HeightMapShape3D collision alignment needs in-engine verification
- Splatmap textures — shader blending; debug prints will confirm tex load state
- Course objects — 7237 objects have real positions but render as placeholder boxes

### Next Session Priorities

1. **Verify terrain walkability** — confirm player walks on hills, not through them
2. **Splatmap shader** — read debug output; confirm fairway/rough/green blend is applying
3. **Course objects** — billboard sprites for trees; filter LOD variants (keep _LOD0 only)
4. **Water planes** — render semi-transparent plane at water_level Y in Godot
   - `course.json` already contains `water_level` (PP_waterplane Unity Y or null)
   - ball.gd water detection: Y < water_plane_y within bounds → water hazard
5. **Multi-hole terrain** — subsequent holes need terrain rebuild; currently only hole 1

## File Inventory

### Core Game Scripts
- main.gd — hole setup, OWG path, landmarks, flagstick Y raycast
- player.gd — ESC → course selector, all gameplay controls
- ball.gd — MasterShotEngine, flight/roll/putt, tracer, surface detection
- terrain_generator.gd — resolution=256, margin=120, corrected UV sampling, debug prints
- course_loader.gd — extracts all files from OWG zip on load
- course_select.gd — HSplitContainer card UI
- title_screen.gd — scans courses in background thread

### Converter
- pg_to_owg_converter.py — heightmap: T+flipud+fliplr+scale_y×2, water_level datum,
  Transform hierarchy walk for real world object positions
  Run: `python3 pg_to_owg_converter.py <course.zip> -o courses/`
  Old Course: zip from Steam install dir first (no native zip in PG Steam folder)
  Then delete `user://courses/<name>/` cache before testing in Godot

### Course Packages (res://courses/)
- OWG-The-Old-Course.zip — reconverted ✓ (water_level=12.248m, 7237 objects)
- OWG-Sunset-Valley-GC.zip — reconverted ✓ (water_level=0.000m, 881 objects)

### Reference Data (not in game)
- /home/ron/Downloads/PG-golf courses/ — original PG zip files
- /home/ron/.local/share/Steam/steamapps/common/Perfect Golf/ — PG game install
  St Andrews: standrewsv1/standrewsv1.unity3d + standrewsv1.description (zip manually)

## Architecture Notes

### Why Runtime Terrain (not baked .tscn)
The baked terrain.tscn approach was tried and abandoned. The 137MB text .tscn
with ArrayMesh vertices had coordinate alignment issues between visual mesh and
collision shape. Runtime `build_from_hole()` samples the heightmap PNG directly
using world coordinates — simpler, correct, and proven to work.

### Coordinate System
- Unity: left-handed, X right, Y up, Z forward
- Godot: right-handed, X right, Y up, Z forward
- Conversion: Godot_X = -Unity_X (X axis flipped)
- Terrain UV: u = 1 + world_x/size_x, v = 1 - world_z/size_z

### Water Level Datum
- `terrain_meta["water_level"]` = heightmap minimum in metres (floor of terrain)
- Applied as Y offset to all tee/pin/shot positions during conversion
- `course.json["water_level"]` = PP_waterplane Unity Y (actual water surface height)
- For Old Course: terrain floor=12.248m, water surface=23.43m → ponds ~11m deep

### OWG Package Format
```
course.json          — holes, tees, pins, terrain meta, water_level, objects, splash
terrain/
  heightmap.png      — 16-bit grayscale, orientation corrected (T+flipud+fliplr)
  terrain_meta.json  — width, height, scale_x/y/z, terrain_size_x/z, water_level
  splat/
    alphamap_0..N.png — surface blend maps (R=fairway, G=green, B=rough)
    splat_layers.json
textures/            — all Unity Texture2D assets as PNG
images/              — splash.jpg, flag.jpg
meshes/              — placed scene objects as .obj files
```
