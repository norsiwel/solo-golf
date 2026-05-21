# Open World Golf — Project Status

## Current State (May 20 2026 — Late Evening)

### WORKING ✅
- Full scene flow: title → golfer_select → course_select → intro
- Player walks on terrain with collision
- Surface detection (Fairway/Rough/Bunker labels in HUD)
- Wind system with HUD indicator
- Sky and environment (procedural)
- Course loading from OWG zips (extraction, staging, preloading)
- TerrainGenerator builds hole patch from heightmap PNG
- Textures loading (splatmap partially working)
- 4 courses converted and ready: Woody's, Practice Range, Sunset Valley, Old Course

### NOT WORKING YET ❌
- Viewfinder (V key) — stubs only, needs Golf-O-Matic overlay wired up
- Address screen — needs viewfinder aim first
- Ball physics — not tested yet
- Splatmap UV scaling — textures show but wrong scale
- Course-specific hole scenes (all use hole_01 → Woody's terrain)

### NEXT SESSION PRIORITIES
1. Wire up viewfinder (Golf-O-Matic image + HUD nodes)
2. Fix splatmap UV scaling
3. Test ball drop and shot
4. Build proper per-course hole scene system

## Architecture
- main scene: intro.tscn (lobby shell)
- hole scenes: courses/hole_01.tscn → hole_scene.gd → terrain_generator.gd
- flow: course_select → CourseLoader extracts zip → GameState.current_course → intro.gd → HoleLoader → hole_scene.gd
