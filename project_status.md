# Open World Golf — Project Status

## Current State (May 20 2026 — Evening)

### Architecture ✅ (completed this session)
- main.tscn rebuilt as clean lobby shell — NO terrain, NO hole geometry
- Old_bad_Main.tscn preserved as salvage/reference backup
- CurrentHole node: empty Node3D, runtime container for dynamic hole scenes
- hole_loader.gd: load_hole(path), load_hole_by_number(n), unload_hole()
- Profile system fully built (see below)
- Scene flow: title → golfer_select → course_select → main ✅

### Profile System ✅ (new this session)
- profile_manager.gd: autoload singleton, saves to user://profiles/<name>.json
- golfer_select.tscn + golfer_select.gd: full select/create/delete screen
- Fields: name, gender (M/F), handedness (R/L)
- last_active flag: auto-selects previous golfer on return
- First run: create form shown directly (no cancel)
- Returning: scrollable list, New Golfer button, two-press delete confirm
- Keyboard nav: ↑↓ / Enter / ESC
- Duplicate name detection on create
- ProfileManager added to project.godot autoloads

### Still Working ✅ (from previous sessions)
- Full gameplay loop: walk → aim → shoot → roll → putt → hole-out → scorecard
- Both OWG zips load: The Old Course and Sunset Valley GC
- Player spawns on terrain with correct tee Y
- Splatmap shader running
- Course select screen with splash images, search, random
- Wind system, viewfinder, shot tracer, putting, scorecard

### Needs Work 🔲
- main.gd: still the old monolithic version — needs rewrite as thin coordinator
  (reads GameState.current_course, calls HoleLoader, positions Player)
- Terrain textures: solid green — satellite base not rendering through shader
- Swilcan Burn: _setup_swilcan_burn() not called from _setup_hole_owg()
- Viewfinder bug: changes player position
- Billboard trees: still placeholder geometry

## Next Session Priorities

1. **Rewrite main.gd** as thin coordinator — this is the key remaining framework piece
   - Read GameState.current_course (populated by course_select)
   - Call HoleLoader.load_hole_by_number(GameState.current_hole)
   - Pass tee/pin to Player for positioning
   - Handle go_to_next_hole() cleanly
   - Move all terrain/geometry/water/objects code INTO hole scenes
2. Fix terrain satellite texture rendering
3. Fix viewfinder position bug
4. Add Swilcan Burn call

## Session History

### May 20 2026 — Architecture Rebuild
**Problem:** main.tscn had baked terrain and hole geometry embedded directly.
Caused instability, broken terrain loading, transform inheritance issues.

**Solution:** Rebuilt entire scene architecture.

Files created/changed:
- `main.tscn` — rebuilt as clean lobby shell
- `Old_bad_Main.tscn` — old scene preserved as backup
- `hole_loader.gd` — new dynamic hole loading script
- `profile_manager.gd` — new autoload for golfer profiles
- `golfer_select.gd` — new golfer select/create screen
- `scenes/golfer_select.tscn` — new scene
- `title_screen.gd` — redirect changed to golfer_select
- `project.godot` — ProfileManager added to autoloads
- `CLAUDE.md` — rewritten to reflect new architecture
- `project_status.md` — this file

### May 19 2026 — Asset Pipeline
- AssetStager, CoursePreloader autoloads
- Cache stamp: skip re-extraction on repeat loads
- Splatmap shader overhaul (6 splatmap inputs, per-course channel map)
- Water plane system
- Course select UI anchor-based rewrite
- Spawn height fallback chain

### Earlier Sessions
- Full gameplay loop implemented
- Both OWG courses working
- HeightMapShape3D collision with Jolt
- Viewfinder, address screen, shot engine, scorecard
