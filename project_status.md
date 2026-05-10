# Open World Golf — Project Status

## Current State (May 2026)

### Working
- Full gameplay loop: walk → aim → shoot → roll → putt → hole-out → scorecard
- Title screen (Open-world-title.png) → course selector → game → ESC back to selector
- Course selector: card UI with splash images, course name/author/holes, ▶ Play button
- Both courses load and are playable: The Old Course (built-in) and Sunset Valley GC (OWG)
- Runtime heightmap terrain with correct coordinate math (verified 0.001m vs Unity)
- Shot tracer (yellow line), wind system, viewfinder rangefinder
- Putting system with stimp, cup detection, hole-out animation
- Scorecard with play-again / next-hole

### Heightmap Breakthrough (this session)
The OWG converter was extracting Unity heightmaps with wrong orientation AND wrong scale.
Fix: `arr = arr.T; arr = np.flipud(arr); arr = np.fliplr(arr); scale_y *= 2.0`
Result: 0.001m mean error across all 18 Sunset Valley tee positions.
UV sampling in GDScript: `u = 1.0 + world_x/size_x`, `v = 1.0 - world_z/size_z`

### In Progress
- Terrain walkability — HeightMapShape3D collision should now work with corrected
  heightmap, but needs in-engine verification. Player should stand on hills not float.
- Splatmap textures — case-insensitive file_map lookup added, should now find
  SplatAlpha_0.png correctly for Sunset Valley

### Next Session Priorities

1. **Verify terrain walkability** — run Sunset Valley, confirm player walks on hills
2. **Water planes** — extract PP_waterplane Y from unity3d bundle, render in Godot
   - PG uses flat planes at fixed Y; terrain sculpted below = pond
   - Extract from MonoBehaviour/Transform in the course bundle
   - Store in course.json as water_planes array
3. **Splatmap textures** — confirm fairway/rough/green shader is applying correctly
4. **Course objects** — replace placeholder boxes with billboard sprites for trees
5. **Old Course reconversion** — apply the same heightmap fix to standrewsv1.zip
   (currently uses hand-crafted meta with hardcoded constants)

## File Inventory

### Core Game Scripts
- main.gd — hole setup, OWG path, landmarks (NO baked terrain.tscn loading)
- player.gd — ESC → course selector, all gameplay controls
- terrain_generator.gd — resolution=256, margin=120, corrected UV sampling
- course_loader.gd — extracts all files from OWG zip on load
- course_select.gd — HSplitContainer card UI
- title_screen.gd — scans courses in background thread

### Converter
- pg_to_owg_converter.py — FIXED: scale_y*2, T+flipud+fliplr orientation
  Run: `python3 pg_to_owg_converter.py <course.zip> -o courses/`
  Then delete user://courses/<name>/ cache before testing

### Course Packages (res://courses/)
- OWG-The-Old-Course.zip — needs reconversion with fixed heightmap math
- OWG-Sunset-Valley-GC.zip — reconverted with correct orientation ✓

### Reference Data (not in game)
- /home/ron/Downloads/PG-golf courses/ — original PG zip files
- /home/ron/.local/share/Steam/steamapps/common/Perfect Golf/ — PG game install
  (useful for studying water plane format, course designer)

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

### OWG Package Format
```
course.json          — holes, tees, pins, terrain meta, splash image name
terrain/
  heightmap.png      — 16-bit grayscale, orientation corrected
  terrain_meta.json  — width, height, scale_x/y/z, terrain_size_x/z
  splat/
    alphamap_0..N.png — surface blend maps (R=fairway, G=green, B=rough)
    splat_layers.json
  terrain.tscn       — baked scene (not currently used)
textures/            — all Unity Texture2D assets as PNG
images/              — splash.jpg, flag.jpg
```
