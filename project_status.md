# Open World Golf — Project Status

## Current State (May 19 2026 — Evening Session)

### Working ✅
- Full gameplay loop: walk → aim → shoot → roll → putt → hole-out → scorecard
- Title screen → course selector → game → ESC back
- Both OWG zips load: The Old Course and Sunset Valley GC
- Player spawns on terrain (fallback chain: raycast → heightmap → course.json Y)
- Walking up hills with collision working
- Water plane at Y=0 (datum), sized to full terrain
- Splatmap UV fixed: u=1+world_x/size_x matches heightmap formula exactly
- Multi-splatmap shader: reads correct channel per course from splat_channel_map.json
- 16-bit heightmap: FORMAT_RF conversion gives correct pixel.r values
- Asset staging pipeline: user://runtime/ holds all active course assets
- Cache stamp: second load of same course skips extraction entirely
- Course select screen: anchor-based layout, splash image as card
- Loading overlay: big % counter, green→yellow→white, Cancel button
- Scorecard: Course Select button to return to selector
- Wind system, viewfinder, shot tracer, putting, scorecard all intact

### Needs Testing / Known Issues 🔲
- Terrain textures: splatmap channel map built from splat_layers.json — needs visual verify
- Heightmap FORMAT_RF: debug print added, need to confirm pixel.r ~0.02 for SV tee
- Water plane: visible on Sunset Valley (no water on hole 1) — correct behavior
- Billboard trees: still placeholder cones/boxes, real textures are in the zip
- Multi-hole: only hole 1 terrain built

### Next Session Priorities
1. Verify terrain textures showing correctly with new channel map
2. Remove debug print from load_heightmap once confirmed
3. Player profile screen (name, sex, handedness)
4. 9-hole mode implementation in main.gd
5. Normal maps on terrain shader (biggest visual quality jump)
6. Billboard trees from extracted course textures

## Session History (May 19 2026 — Evening)

**Asset Pipeline**
- AssetStager autoload: stages all course files to user://runtime/
- CoursePreloader autoload: pre-loads heightmap+textures into GameState memory
- Cache stamp: zip mod time check, skips re-extraction on repeat loads
- splat_layers.json → splat_channel_map.json: per-course texture layer mapping

**Terrain Shader Overhaul**
- terrain_splatmap.gdshader: now supports 6 splatmaps (PG courses have up to 24 layers)
- Per-course channel uniforms: ch_fairway/rough/green/bunker/sand as ivec2(map,channel)
- Splatmap UV formula corrected to match heightmap exactly
- 16-bit PNG heightmap: convert(FORMAT_RF) before use

**Water Plane**
- Added _setup_water_plane() in main.gd
- Rendered at Y=0 (Unity water plane datum), 120% terrain size
- Semi-transparent blue, high specularity

**Course Select UI**
- Replaced VBoxContainer with anchor-based layout (like CSS absolute)
- Splash image IS the card — course title/author baked into image by convention
- Buttons always at bottom: 9 Hole / 18 Hole / 🎲 Random / ▶ PLAY
- Back button top-left returns to title screen
- Cancel button on loading overlay
- Large % counter with color shift during load

**Spawn Height Fix**
- Fallback chain: raycast → heightmap.get_height_at() → course.json Y value
- course.json Y is already water-plane corrected, guaranteed correct

## File Inventory (additions this session)
- `asset_stager.gd` — NEW autoload, stages course to user://runtime/
- `course_preloader.gd` — NEW autoload, pre-loads assets into GameState memory
- `game_state.gd` — added preloaded_* fields and player profile vars
- `course_loader.gd` — cache stamp, granular progress, calls AssetStager
- `terrain_generator.gd` — FORMAT_RF, multi-splat, channel map, _owg_all_splats
- `terrain_splatmap.gdshader` — 6 splatmap inputs, per-course channel uniforms
- `main.gd` — water plane, spawn fallback chain
- `scorecard.gd` — Course Select button
- `scenes/course_select.tscn` — full anchor-based rewrite
- `course_select.gd` — back button, cancel, themed buttons
