# Open World Golf — CLAUDE.md

## Project Summary

Godot 4.6 single-player walking golf simulation. Two playable courses: The Old Course St Andrews and Sunset Valley GC (Perfect Golf conversion). Full gameplay loop: walk to ball, aim with viewfinder, address screen, shot, ball flight with tracer, rollout, putting, hole-out, scorecard. Uses Jolt 3D physics.

OWG course loading system fully operational: title screen → course selector (card UI with splash images) → game. Runtime heightmap terrain with verified coordinate math (0.001m mean error vs Unity tee positions). ESC returns to course selector from anywhere in game.

## Directory Structure

```
open-world-golf/
├── project.godot                    # Godot 4.6, Forward Plus, Autoload: GameState
├── main.tscn / main.gd              # Game scene, hole setup, OWG setup, landmarks
├── player.gd                        # Camera, WASD, viewfinder, OVB, HUD, putting
├── ball.gd                          # MasterShotEngine flight/rollout/putting/holing, tracer
├── address_screen.gd                # 3-click meter, club bag, draw/fade, loft
├── green.gd                         # GreenArea3D, cup detection, stimp
├── tee.gd                           # TeeArea3D detection
├── scorecard.gd                     # Post-hole score display
├── terrain_generator.gd             # Runtime heightmap terrain (HeightMapShape3D)
├── course_manager.gd                # JSON/OWG loading, position normalisation
├── course_loader.gd                 # Scans/extracts OWG-*.zip packages
├── course_select.gd                 # Card-based course selector UI
├── title_screen.gd                  # Title screen with asset preload
├── game_state.gd                    # Autoload: cross-scene state
├── course_shapes_loader.gd          # OSM green polygon → collision
├── alphamap_reader.gd               # Multi-layer splatmap surface detection
├── hole_map.gd                      # Overhead course map display
├── wind_system.gd / wind_hud.gd     # Wind simulation and HUD
├── flag_animator.gd                 # Flag waving animation
├── scorecard.gd                     # Hole result display
├── scenes/
│   ├── title_screen.tscn            # Entry point: shows Open-world-title.png
│   ├── course_select.tscn           # HSplitContainer card selector
│   └── course_select.tscn           # Course selection UI
├── courses/
│   ├── The_Old_Course_*.json/png/gd # Built-in St Andrews data
│   ├── OWG-The-Old-Course.zip       # Converted OWG package
│   └── OWG-Sunset-Valley-GC.zip    # Converted OWG package
├── assets/terrain/                  # Fallback surface textures
├── tools/                           # Pipeline scripts (fetch_osm, obj_to_glb etc)
└── pg_to_owg_converter.py           # Perfect Golf → OWG converter (FIXED orientation)
```

## Critical Operating Rules

1. **Commit before any change** — git is the backup
2. **Preserve working functionality** — prefer non-destructive additions
3. **Small, reversible changes** — no large refactors
4. **Don't remove code without justification**
5. **Update CLAUDE.md and project_status.md** whenever committing

## Scene Flow

```
title_screen.tscn  (Open-world-title.png, scans courses, ENTER)
    ↓
course_select.tscn  (card UI: course name, author, holes, splash image, ▶ Play button)
    ↓  CourseLoader extracts zip → user://courses/<name>/
GameState.current_course = course_data
    ↓
main.tscn  (ESC → back to course_select)
```

## Heightmap Coordinate System (CRITICAL — verified 0.001m error)

Unity terrain heights are stored as uint16 fractions. Correct extraction:
```python
effective_scale_y = scale.y * 2.0   # Unity uses scale*2 internally
arr = arr.T           # transpose rows/cols
arr = np.flipud(arr)  # flip rows
arr = np.fliplr(arr)  # flip cols
```

Godot sampling in `_sample_real_height()`:
```gdscript
u = clamp(1.0 + world_x / size_x, 0.0, 1.0)   # world_x is negative
v = clamp(1.0 - world_z / size_z, 0.0, 1.0)
```

terrain_meta.json `scale_y` = Unity scale.y × 2.

## Terrain Generator (terrain_generator.gd)

- `resolution = 256`, `margin = 120.0` — builds 256×256 grid around hole bounds
- `build_from_hole(tee, pin, all_tees, all_pins)` — samples heightmap per grid point
- `HeightMapShape3D` scale = `Vector3(_step_x, 1.0, _step_z)`, positioned at bounds center
- Splatmap loaded via `load_textures()` — case-insensitive file_map lookup
- Shader blends fairway(R), green(G), rough(B) channels
- UV in shader: `u = -world_x / safe_size_x`, `v = world_z / safe_size_z`

## OWG Converter (pg_to_owg_converter.py)

Converts Perfect Golf .zip (unity3d bundle) → OWG .zip:
- Heightmap: extracted, orientation corrected (T+flipud+fliplr), scale_y×2
- Splatmaps: terrain/splat/alphamap_0..N.png
- Textures: all Texture2D assets → textures/ with classified texture_map.json
- course.json: all tees/pins/shots with Godot coords (X flipped)
- Visual mesh in terrain.tscn: 257×257 ArrayMesh with real vertex heights (NOT flat PlaneMesh)
- Water/ocean/lake objects filtered from spawn list

## Water Planes (TODO next session)

PG courses use `PP_waterplane` GameObjects at a fixed Y height. Terrain is sculpted
below that Y to create ponds. Strategy:
1. Extract PP_waterplane Y positions from MonoBehaviour/Transform in unity3d
2. Store in course.json as `water_planes: [{y, bounds}]`
3. Render as semi-transparent plane in Godot at that Y
4. ball.gd water detection uses Y < water_plane_y within bounds

Course designer: Perfect Golf is installed at Steam/steamapps/common/Perfect Golf.
Consider downloading PG course designer for reference on terrain sculpting format.

## Known Issues / TODO

- **Terrain not yet walkable for hills** — HeightMapShape3D collision alignment
  needs verification in-engine; the math is correct but physics body position
  may need adjustment
- Splatmap textures loading (case-insensitive fix applied) — verify in next run
- Water planes not yet extracted/rendered for OWG courses
- Course objects (trees, buildings) spawn as placeholder boxes
- No audio
- Old Course built-in path still uses original meta.json / heightmap constants
- Multi-hole navigation: only hole 1 terrain built; subsequent holes rebuild terrain

## Key Controls

| Key | Action |
|-----|--------|
| WASD | Walk |
| V | Open viewfinder (hold) |
| Mouse wheel | Zoom viewfinder |
| Left-click (VF) | Lock aim |
| Space | Address screen |
| Right-click (green) | Lock putt aim |
| H | Toggle handedness |
| ESC | Back to course selector |

## Dependencies

- Godot 4.6, Forward Plus, Jolt Physics 3D
- Python: UnityPy, Pillow, numpy (for converter)
