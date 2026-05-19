# Open World Golf — CLAUDE.md

## Project Summary

Godot 4.6 single-player first-person walking golf simulation. Personal project, no distribution.
Two playable courses: The Old Course St Andrews and Sunset Valley GC (Perfect Golf conversions).
Full gameplay loop: walk to ball, aim with viewfinder, address screen, shot, ball flight with tracer,
rollout, putting, hole-out, scorecard. Uses Jolt 3D physics. No player avatar — first person only.

## Active Project Directory

`/home/ron/open-world-golf/` — THIS IS THE ONLY ACTIVE PROJECT
`/home/ron/solo-golf-backup/` — backup only, do not edit
GitHub: https://github.com/norsiwel/solo-golf (branch: main)

## Directory Structure

```
open-world-golf/
├── project.godot                    # Godot 4.6, Forward Plus, Autoload: GameState
├── main.tscn / main.gd              # Game scene, hole setup, OWG setup, landmarks
├── player.gd                        # Camera, WASD+jump+crouch, viewfinder, OVB, HUD
├── ball.gd                          # MasterShotEngine flight/rollout/putting/holing
├── address_screen.gd                # 3-click meter, club bag, draw/fade, loft
├── green.gd / tee.gd                # Area3D detection nodes
├── scorecard.gd                     # Post-hole score display
├── terrain_generator.gd             # Runtime heightmap terrain (HeightMapShape3D)
├── terrain_splatmap.gdshader        # PBR splatmap shader (fairway/rough/green/bunker/sand)
├── shaders/terrain_shader.gdshader  # Alias copy of terrain_splatmap.gdshader
├── owg_environment.gd               # ACES tonemap + glow + SSAO post-processing
├── course_loader.gd                 # Scans/extracts OWG-*.zip, apply_terrain_material()
├── course_manager.gd                # Legacy JSON loader (dev fallback only)
├── course_select.gd                 # Card-based course selector UI
├── title_screen.gd                  # Entry point — scans courses, shows title image
├── game_state.gd                    # Autoload: current_course dict cross-scene
├── course_shapes_loader.gd          # OSM green polygon → collision
├── alphamap_reader.gd               # Multi-layer splatmap surface detection
├── hole_map.gd                      # M key overhead course map
├── wind_system.gd / wind_hud.gd     # Wind simulation and arrow HUD
├── flag_animator.gd                 # Flag waving animation
├── pg_to_owg_converter.py           # Perfect Golf → OWG converter (main tool)
├── build_tscn.py                    # Standalone terrain.tscn builder function
├── extract_textures.py              # Standalone texture extractor function
├── scenes/
│   ├── title_screen.tscn            # Entry point (run with F5)
│   └── course_select.tscn           # Course selector card UI
├── courses/
│   ├── OWG-The-Old-Course.zip       # St Andrews — 332MB, water_level=21.5m
│   ├── OWG-Sunset-Valley-GC.zip     # Sunset Valley — 680MB, water_level=10.9m
│   ├── Terrain_Data/                # Terrain3D .res files (partial coverage)
│   └── The_Old_Course_*.json/png    # Legacy built-in data
├── assets/terrain/                  # Fallback surface textures
└── tools/                           # Pipeline helper scripts
```

## Critical Operating Rules

1. **Always use F5** to run — starts title_screen.tscn → course selector → game
   F6 on main.tscn triggers dev fallback (loads zip directly, works but no selector UI)
2. **Commit before any change** — git is the backup
3. **Preserve working functionality** — prefer non-destructive additions
4. **Small, reversible changes** — no large refactors
5. **Update CLAUDE.md and project_status.md** whenever committing
6. **Delete user:// cache** before testing after reconversion:
   `rm -rf ~/.local/share/godot/app_userdata/*/courses/OWG-*`

## Scene Flow

```
title_screen.tscn  (Open-world-title.png, scans courses, ENTER)
    ↓
course_select.tscn  (card UI: splash image, course name, author, holes, ▶ Play)
    ↓  CourseLoader.load_course(zip_path) → extracts to user://courses/<name>/
GameState.current_course = course_data dict
    ↓
main.tscn  (_setup_hole_owg → terrain + tee + objects)  ESC → course_select
```

## Heightmap Coordinate System (CRITICAL — verified 0.001m error)

```python
effective_scale_y = scale.y * 2.0   # Unity uses scale*2 internally
arr = arr.T           # transpose rows/cols
arr = np.flipud(arr)  # flip rows
arr = np.fliplr(arr)  # flip cols
```

Godot sampling in `_sample_real_height()`:
```gdscript
u = clamp(1.0 + world_x / size_x, 0.0, 1.0)
v = clamp(1.0 - world_z / size_z, 0.0, 1.0)
```

## Water Level System

Courses use water plane Y as the datum (Y=0 in game = water plane in Unity).
- `pg_to_owg_converter.py` subtracts `water_plane_y` from ALL tee/pin/shot Y positions
- Heightmap is also shifted by the same amount during extraction
- St Andrews: water_plane_y=21.5m → tee Y becomes ~3.1m, pin Y ~0.7m
- Sunset Valley: water_plane_y=10.9m → tee Y becomes ~9.3m
- `course.json["water_plane_y"]` stores the original Unity water plane Y

## Terrain Generator (terrain_generator.gd)

- `resolution=256`, `margin=120.0` — 256×256 grid around hole bounds
- `build_from_hole(tee, pin, all_tees, all_pins)` — samples heightmap per grid point
- Collision: `Transform3D` with `Basis(Vector3(_step_x,0,0), Vector3(0,1,0), Vector3(0,0,_step_z))`
  positioned at bounds center — avoids Jolt scale+position bug
- Splatmap shader: `terrain_splatmap.gdshader` (PBR, world-space UV, 5 channels)
- Shader UV: `u = -world_x / size_x`, `v = world_z / size_z`
- Fallback: inline SPLAT_SHADER const if .gdshader file not found

## OWG Converter (pg_to_owg_converter.py)

Run: `python3 pg_to_owg_converter.py <course.zip> --output courses/`
Dependencies: `pip install UnityPy Pillow numpy`

Pipeline:
1. Extract TerrainData → heightmap.png (T+flipud+fliplr, water_level shifted)
2. Extract splatmaps → terrain/splat/alphamap_0..N.png
3. Extract Texture2D → textures/ with texture_map.json classification
4. Extract Meshes → meshes/*.obj
5. Extract objects via Transform hierarchy walk → real world positions
6. Build terrain.tscn (43MB baked StaticBody3D — NOT loaded at runtime, for reference)
7. Convert course.json (tee/pin/shot positions, water_level subtracted from Y)
8. Package → OWG-<CourseName>.zip

## OWG Package Format

```
course.json          — holes (tees/pins/shots), terrain meta, water_plane_y, objects
terrain/
  heightmap.png      — 2049×2049 16-bit grayscale, water-level-shifted
  terrain_meta.json  — width, height, scale_x/y/z, terrain_size_x/z, water_level
  terrain.tscn       — 43MB baked terrain (reference only, not runtime loaded)
  splat/
    alphamap_0..N.png — splatmaps (R=fairway, G=rough, B=green, A=bunker)
    splat_layers.json
textures/
  texture_map.json   — {surface: filename} classification
  *.png              — all Unity Texture2D assets
images/
  splash.jpg, flag.jpg
meshes/
  *.obj              — placed scene objects
```

## Key Controls

| Key | Action |
|-----|--------|
| WASD | Walk |
| Space (walking) | Jump |
| C (hold) | Crouch |
| V | Open viewfinder (hold) |
| Mouse wheel | Zoom viewfinder |
| Left-click (VF) | Lock aim |
| Space (aim locked) | Address screen |
| Right-click (green) | Lock putt aim |
| H | Toggle handedness |
| M | Overhead hole map |
| ESC | Back to course selector |

## Known Issues / Next Session Priorities

1. **Splatmap textures null** — textures load correctly via CourseLoader zip extraction
   when using F5. Dev fallback (F6) now also loads zip via CourseLoader.
2. **Player spawn position** — tee Y now correct (3.1m for St Andrews) but
   may still need verification that player lands on terrain not underground
3. **Collision shape alignment** — Transform3D fix applied, needs in-game verification
4. **Blue ball diamond** — ball mesh/material may fail when textures don't load;
   should resolve when zip extracts properly via F5
5. **Course objects** — 7237 objects spawn as placeholder boxes/green cubes
   (billboard trees not yet mapped from extracted textures to ASSET_MAP)
6. **Water planes** — water_plane_y stored in course.json, not yet rendered in game
7. **Multi-hole terrain** — only hole 1 terrain built; subsequent holes need rebuild
8. **Terrain3D** — plugin installed, data in courses/Terrain_Data/ but covers
   limited area; Terrain3D.data.get_height() used if available as primary query

## Dependencies

- Godot 4.6, Forward Plus, Jolt Physics 3D
- Terrain3D plugin in addons/terrain_3d/
- Python: UnityPy, Pillow, numpy (for converter)
