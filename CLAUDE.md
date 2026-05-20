# Open World Golf — CLAUDE.md

## Project Summary

Godot 4.6 single-player first-person walking golf simulation. Personal project, no distribution.
Target: 502 courses loaded dynamically from OWG-*.zip packages.
Full gameplay loop: walk to ball, aim with viewfinder, address screen, shot, ball flight with tracer,
rollout, putting, hole-out, scorecard. Uses Jolt 3D physics. No player avatar — first person only.

## Active Project Directory

`/home/ron/open-world-golf/` — THIS IS THE ONLY ACTIVE PROJECT
`/home/ron/solo-golf-backup/` — backup only, do not edit
GitHub: https://github.com/norsiwel/solo-golf (branch: main)

## Architectural Philosophy (established May 20 2026)

**main.tscn is the lobby, not the game.**
- main.tscn holds only persistent systems: UI, environment, wind, player, managers
- NO baked terrain, NO hole geometry, NO procedural meshes in main.tscn ever
- All hole content loads dynamically into CurrentHole (empty Node3D) at runtime
- Broken terrain can never corrupt the entire project again

## Scene Flow

```
title_screen.tscn   (Open-world-title.png, scans courses, ENTER)
    ↓
golfer_select.tscn  (profile list or create form → sets ProfileManager.active)
    ↓
course_select.tscn  (splash image, course name, 9/18 holes, ▶ Play)
    ↓  CourseLoader.load_course(zip_path) → extracts to user://courses/<name>/
GameState.current_course = course_data dict
    ↓
main.tscn           (lobby shell — loads hole scene into CurrentHole)
    ↓  HoleLoader.load_hole_by_number(n) → instantiates into Main/CurrentHole
```

## Directory Structure

```
open-world-golf/
├── project.godot                    # Godot 4.6, Forward Plus
│                                    # Autoloads: GameState, AssetStager,
│                                    #   CoursePreloader, ProfileManager
├── main.tscn                        # Lobby shell — NO terrain/geometry
├── Old_bad_Main.tscn                # Salvage backup — DO NOT USE
├── main.gd                          # Needs rewrite as thin coordinator
├── hole_loader.gd                   # Dynamic hole scene loader
├── profile_manager.gd               # Autoload: golfer profile save/load
├── golfer_select.gd                 # Golfer select/create screen logic
├── player.gd                        # Camera, WASD, viewfinder, OVB, HUD
├── ball.gd                          # MasterShotEngine flight/rollout/putting
├── address_screen.gd                # 3-click meter, club bag, draw/fade, loft
├── green.gd / tee.gd                # Area3D detection nodes
├── scorecard.gd                     # Post-hole score display
├── terrain_generator.gd             # Runtime heightmap terrain
├── terrain_splatmap.gdshader        # PBR splatmap shader
├── owg_environment.gd               # Post-processing (ACES, glow, SSAO)
├── course_loader.gd                 # Scans/extracts OWG-*.zip
├── course_manager.gd                # Legacy JSON loader (dev fallback)
├── course_select.gd                 # Course selector UI logic
├── title_screen.gd                  # Entry point
├── game_state.gd                    # Autoload: cross-scene state
├── asset_stager.gd                  # Autoload: stages assets to user://runtime/
├── course_preloader.gd              # Autoload: pre-loads assets into memory
├── wind_system.gd / wind_hud.gd     # Wind simulation and HUD
├── hole_map.gd                      # M key overhead course map
├── flag_animator.gd                 # Flag waving
├── scenes/
│   ├── title_screen.tscn            # Entry point (F5)
│   ├── golfer_select.tscn           # NEW — profile list + create form
│   └── course_select.tscn           # Course selector
├── courses/
│   ├── OWG-*.zip                    # Course packages
│   └── The_Old_Course_*.json/png    # Legacy data
└── tools/                           # Pipeline helper scripts
```

## Autoloads (project.godot)

| Name | File | Purpose |
|------|------|---------|
| GameState | game_state.gd | Cross-scene state: current course, hole, player vars |
| AssetStager | asset_stager.gd | Stages extracted course files to user://runtime/ |
| CoursePreloader | course_preloader.gd | Pre-loads heightmap+textures into GameState memory |
| ProfileManager | profile_manager.gd | Golfer profiles: save/load/delete from user://profiles/ |

## main.tscn Node Structure

```
Main (Node3D) [main.gd — needs rewrite]
├── UI (CanvasLayer)
│   ├── WindHUD
│   └── HoleMap
├── WorldEnvironment
├── Sun (DirectionalLight3D)
├── WindSystem (Node3D)
├── Player (CharacterBody3D)
│   ├── CollisionShape3D
│   └── Camera3D
├── Ball (Node3D — placeholder, managed by Player)
├── CameraRig (Node3D)
├── CourseManager (Node)
├── CourseLoader (Node)
├── HoleLoader (Node)      ← loads hole scenes dynamically
├── ProfileManager (Node)
└── CurrentHole (Node3D)   ← EMPTY — hole scenes mount here at runtime
```

## Profile System

Profiles saved to `user://profiles/<name>.json`:
```json
{ "name": "Ron", "sex": "M", "right_handed": true, "last_active": true }
```
- `ProfileManager.set_active(name)` marks last_active and pushes to GameState
- On golfer_select load: auto-selects last_active profile
- First run (no profiles): shows create form directly, no cancel option

## OWG Package Format

```
course.json          — holes (tees/pins/shots), terrain meta, water_plane_y, objects
terrain/
  heightmap.png      — 2049×2049 16-bit grayscale, water-level-shifted
  splat/alphamap_0..N.png
textures/
  texture_map.json   — {surface: filename}
images/
  splash.jpg
```

## Heightmap Coordinate System (CRITICAL)

```python
arr = arr.T; arr = np.flipud(arr); arr = np.fliplr(arr)
effective_scale_y = scale.y * 2.0
```
Godot sampling: `u = clamp(1.0 + world_x/size_x, 0.0, 1.0)` / `v = clamp(1.0 - world_z/size_z, 0.0, 1.0)`

## Critical Operating Rules

1. **F5 to run** — title_screen.tscn is main scene
2. **main.tscn is the lobby** — never put terrain or hole geometry in it
3. **Commit before any change** — git is the backup
4. **Update CLAUDE.md and project_status.md** on every commit
5. **Delete user:// cache** when testing after reconversion:
   `rm -rf ~/.local/share/godot/app_userdata/*/courses/OWG-*`

## Key Controls

| Key | Action |
|-----|--------|
| WASD | Walk |
| V | Open viewfinder |
| Space (aim locked) | Address screen |
| M | Overhead hole map |
| ESC | Back to course selector |
| F1 | Toggle mouse capture (debug) |
