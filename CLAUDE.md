# Open World Golf — CLAUDE.md

## Project Summary
Godot 4.6 single-player first-person walking golf simulation. Personal project, no distribution.
Target: 502 courses loaded dynamically from OWG-*.zip packages.
Full gameplay loop: walk to ball, aim with Golf-O-Matic viewfinder, address screen, shot, ball flight, rollout, putting, hole-out, scorecard. Uses Jolt 3D physics. No player avatar — first person only.

## Active Project Directory
`/home/ron/open-world-golf/` — THIS IS THE ONLY ACTIVE PROJECT
`/home/ron/solo-golf-backup/` — backup only, do not edit
GitHub: https://github.com/norsiwel/solo-golf (branch: main)

## Architectural Philosophy (established May 20 2026)
**intro.tscn is the lobby, not the game.**
- intro.tscn holds only persistent systems: UI, environment, wind, player, managers
- NO baked terrain, NO hole geometry in intro.tscn ever
- Each hole built at runtime by hole_scene.gd → terrain_generator.gd
- Broken terrain can never corrupt the entire project

## Scene Flow
```
title_screen.tscn   → golfer_select.tscn → course_select.tscn
    ↓ CourseLoader extracts OWG-*.zip to user://courses/<name>/
    ↓ GameState.current_course = course_data
intro.tscn (lobby shell)
    ↓ HoleLoader instantiates hole_01.tscn into CurrentHole
hole_scene.gd → terrain_generator.gd builds terrain patch from heightmap
    ↓ Player spawned at tee position from course.json
```

## Key Files
```
intro.tscn / intro.gd          — lobby shell, thin coordinator
hole_scene.gd                  — builds terrain for a hole using terrain_generator
terrain_generator.gd           — builds mesh+collision from heightmap PNG
hole_loader.gd                 — dynamically loads/unloads hole scenes
course_loader.gd               — scans, extracts, stages OWG zip packages
course_select.gd / .tscn       — course browser UI
golfer_select.gd / .tscn       — player profile UI (locker room background)
profile_manager.gd             — autoload: saves profiles to user://profiles/
game_state.gd                  — autoload: cross-scene state
asset_stager.gd                — autoload: stages extracted assets to user://runtime/
course_preloader.gd            — autoload: pre-loads heightmap+textures into GameState
player.gd                      — CharacterBody3D: walking, camera, golf input
address_screen.gd              — shot setup UI
ball.gd                        — MasterShotEngine: flight/rollout/putting
wind_system.gd / wind_hud.gd   — wind simulation and HUD
pg_to_owg_converter.py         — converts Perfect Golf .zip to OWG format
```

## Autoloads (project.godot)
| Name | File | Purpose |
|------|------|---------|
| GameState | game_state.gd | Cross-scene state |
| AssetStager | asset_stager.gd | Stages course files to user://runtime/ |
| CoursePreloader | course_preloader.gd | Pre-loads heightmap+textures |
| ProfileManager | profile_manager.gd | Golfer profiles |
| Tokens | ui/tokens.gd | UI design tokens |

## Courses Available
- OWG-Woody_s-Practice-Area.zip — 9 holes (primary test course)
- OWG-Practice-Range.zip — 1 hole, flat
- OWG-Sunset-Valley-GC.zip — 18 holes
- OWG-The-Old-Course.zip — 18 holes, St Andrews

PG source files: /home/ron/Downloads/PG-golf courses/

## What Works (May 20 2026 evening)
- Full scene flow title → golfer → course → game ✅
- Player walks on terrain with collision ✅
- Surface detection (Fairway/Rough/Bunker in HUD) ✅
- Wind system ✅
- Sky and environment ✅
- Course loading from OWG zips ✅
- TerrainGenerator builds hole from heightmap ✅

## What Needs Work
- Viewfinder (V key) — Golf-O-Matic overlay, stubs only
- Address screen — needs viewfinder aim first
- Ball physics — not tested
- Splatmap UV scaling — textures load but wrong scale
- Per-course hole scenes — all courses use Woody's terrain for now

## Critical Rules
1. **intro.tscn is the lobby** — never put terrain in it
2. **Commit before changes** — git is the backup
3. **One script at a time** — test before moving on
4. **terrain_generator.gd works** — don't replace it with baked tscn approach
5. **pg_to_owg_converter.py** — converter outputs correct res:// paths with course safe_name prefix

## Controls
| Key | Action |
|-----|--------|
| WASD | Walk |
| V | Open viewfinder (stub) |
| Space (near ball, aim locked) | Address screen |
| M | Overhead hole map |
| ESC | Release mouse / back to course select |
| F1 | Toggle mouse capture |
