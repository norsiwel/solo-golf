# Solo Golf — CLAUDE.md

## Project Summary

Godot 4.6 single-player golf simulation. The Old Course, St Andrews — hole 1 fully playable (par 4, ~375 yards). MasterShotEngine equations for carry/roll/putt. 3-click meter for shot power/accuracy. Viewfinder rangefinder with zoom. OVB (over-the-ball) first-person setup. Tee→shot→ball→scoring loop. Uses Jolt 3D physics.

OWG (Open World Golf) course loading system is in place: pre-game course selection screen (Quick Round / 9 Holes / Full Round), ZIP-based course packages, runtime heightmap terrain generation. Viewport: 1152×648, stretch mode canvas_items/expand.

## Directory Structure

```
solo-golf/
├── project.godot                    # Godot 4.6, Forward Plus, Autoload: GameState
├── main.tscn                        # Full 3D scene — terrain, tee, green, flag, player
├── main.gd                          # Hole setup, landmarks, Swilcan Burn, course conditions
├── player.gd                        # Camera, WASD, viewfinder, OVB, HUD, putting, game state
├── ball.gd                          # MasterShotEngine flight/rollout/putting/HOLING, tracer ribbon
├── address_screen.gd                # 3-click meter, club bag, draw/fade, loft sliders
├── green.gd                         # GreenArea3D, cup detection, stimp, check_hole_out()
├── tee.gd                           # TeeArea3D, emits player_on_tee signal
├── scorecard.gd                     # Post-hole score display, play-again / next-hole
├── terrain_generator.gd             # HeightMapShape3D terrain (used for The Old Course built-in)
├── course_manager.gd                # JSON loading + OWG zip path; normalises positions
├── course_loader.gd                 # OWG: scans OWG-*.zip, extracts terrain.scn + splash
├── course_select.gd                 # OWG: pre-game course selection screen controller
├── game_state.gd                    # Autoload (GameState): cross-scene course/scoring state
├── course_shapes_loader.gd          # OSM green polygon → GreenArea collision + GreenMesh
├── course_selector.gd               # In-game CanvasLayer course selector (existing JSON courses)
├── courses/
│   ├── The_Old_Course_meta.json     # 18-hole tee/pin/par data
│   ├── The_Old_Course_shapes.json   # Green polygons (OSM)
│   ├── The_Old_Course_osm_shapes.json  # Water/fairway/rough shapes (OSM)
│   ├── The_Old_Course_heightmap.png # Grayscale elevation image (editor-imported)
│   ├── The_Old_Course_mesh_placement.json  # Spline mesh positions (loader disabled)
│   └── The_Old_Course_spline_loader.gd    # Disabled — meshes had no material → fake water
│   └── OWG-*.zip                    # Drop OWG course packages here (scanned at startup)
├── assets/
│   ├── St.Andrews-course-map-1-18.png  # Full course map (M key)
│   └── terrain/                     # Fairway/green/rough textures
├── shot-generator-equations.txt    # MasterShotEngine reference equations
├── owg_course_system.md            # OWG course system design doc
├── pg_to_owg_converter.py          # Perfect Golf → OWG ZIP converter
└── project_status.md               # Operating rules for AI agents
```

## Critical Operating Rules

1. **Commit before any change** — git is the backup
2. **Preserve working functionality** — prefer non-destructive additions
3. **Small, reversible changes** — no large refactors
4. **Don't remove code without justification**
5. **Respect project structure** — follow existing file organisation
6. **Update CLAUDE.md and project_status.md** whenever committing significant changes

## Architecture

### Signal Flow — Gameplay Loop

```
TeeArea (player enters)
  → tee.gd emits player_on_tee
  → player.on_player_at_tee(): resets putting, selects Driver, shows hole info

Player walks to ball (within 1 m) → OVB activates
  → player faces perpendicular to target (flag to left for right-handers)
  → OVB label shows "V to aim | Space to address"

Player aims:
  V key → viewfinder opens (12° FOV, mouse-wheel zoom 6°–30°)
           viewfinder starts oriented at flag/aim_point
           scroll for zoom, look anywhere (360°)
           crosshair red + "FLAG Xyd" when within 60 px of flag
           shows yardage to any solid object; "---" when aimed at sky
           left-click locks aim (green border), aim_point recorded
  Escape → closes viewfinder

On green — no viewfinder needed:
  mouse look to aim direction
  right-click → lock putt aim in current facing direction
  left-click (aim locked) → open address screen

Space (aim locked off-green) or left-click (on green) → address screen
  → 3-click meter: click start, click power, click accuracy
  → shot_confirmed(power, accuracy, draw_fade, loft, club) emitted
  → player._on_shot_confirmed(): stroke_count++, ball.launch()

Ball states: IDLE → FLYING → ROLLING → CAM_HOLD → STOPPED
  FLYING: parametric arc, tracer ribbon updated, ball-cam follows
  ROLLING: _init_rollout() called ONCE at landing; linear decel using
           _roll_total / _roll_done / _roll_spd0; slope deflects dir
  CAM_HOLD: 2.5 s camera hold on landing, then STOPPED + ball_stopped signal
  → player._on_ball_stopped(): surface detection, green check, HUD update

On green (ball stopped):
  → green.check_hole_out() if dist ≤ cup_radius (0.27 m) → ball_holed_out
  → player._on_ball_holed_out() → ball.hole_out() starts HOLING animation
  → HOLING: ball lerps to cup, shrinks, sinks → ball_holed signal
  → player._on_ball_holed() → scorecard.show_hole_result()

Scorecard:
  → play_again → _setup_hole(same) resets everything
  → next_hole  → go_to_next_hole() (increments, wraps at 18)
```

### Key Script Responsibilities

| Script | Extends | Responsibility |
|--------|---------|----------------|
| player.gd | CharacterBody3D | Camera, WASD, viewfinder (V/zoom/aim), OVB, green putting controls, HUD, signals |
| ball.gd | Node3D | MasterShotEngine launch, rollout, putt rolling, HOLING animation, tracer ribbon |
| address_screen.gd | CanvasLayer (10) | Club selection, 3-click meter, draw/fade slider, loft slider, putting mode |
| green.gd | Area3D | Green zone, stimp, cup position, check_hole_out() |
| tee.gd | Area3D | Tee zone detection, hole metadata |
| scorecard.gd | CanvasLayer (20) | Score naming, colour coding, play-again/next-hole |
| terrain_generator.gd | StaticBody3D | HeightMapShape3D terrain from editor-imported PNG; surface type; colour zones |
| course_manager.gd | Node | JSON loading + OWG zip setup; position normalisation to hole-1 origin |
| course_loader.gd | Node (CourseLoader) | Scans OWG-*.zip; extracts terrain.scn + splash; emits course_ready |
| course_select.gd | Control (CourseSelectScreen) | Pre-game course picker; hands course_data to GameState; changes scene |
| game_state.gd | Node (Autoload: GameState) | Cross-scene state: current_course, hole, scorecard, tee type |
| main.gd | Node3D | Hole setup, landmarks (StaticBody3D), Swilcan Burn water plane |

### MasterShotEngine (ball.gd)

**Carry** (non-putt):
```
C = club_yards_m / D_MAX           # club factor (D_MAX = 250 m)
L = lie_factor                     # tee/fairway=1.0, rough=0.85, deep_rough=0.70, bunker=0.50
L_f = 1.0 + loft * 0.15           # high loft = slightly more carry
carry = D_MAX * power * C * L * accuracy * L_f
lateral = draw_fade * 15.0 + (1-accuracy) * 15.0 * random(-1..1)
```

**Rollout** (computed ONCE in `_init_rollout()` at moment of landing):
```
_roll_total = carry * F_surface * loft_roll_mod * 0.10 * course_firmness
F_surface: fairway=1.0, rough=0.75, deep_rough=0.60, green=0.80, bunker/water=0.0
loft_roll_mod = clamp(1.0 - loft*0.5, 0.02, 1.5)
course_firmness: 0.7=Wet, 1.0=Normal, 1.3=Firm (random each hole)
_roll_spd0 = clamp(_roll_total * 1.5, 0.3, 10.0)
Linear decel: spd = _roll_spd0 * (1 - _roll_done / _roll_total)
```

**Putt** (MasterShotEngine formula):
```
roll_dist = dist_to_pin * (stimp / 8.0) * power
lateral = accuracy_error * random
stimp: randomised 8–13 each hole
```

### Viewfinder System

- V key opens viewfinder (FOV starts 12°)
- Mouse wheel: scroll up = zoom in (min 6°), scroll down = zoom out (max 30°)
- Starts oriented toward flag/aim_point (tee shot convenience)
- Pitch: ±1.4 rad (can look ground to sky)
- Flag snap: 60 px radius → red crosshair + "FLAG Xyd"
- Raycast 700 m → shows yardage to terrain, buildings, any StaticBody3D
- No hit (sky): shows "---", aim_point set to horizontal forward at 450 m
- Left-click locks aim; Space opens address if aim locked (off green)

### OVB (Over-the-Ball) System

- Triggers when player walks within 1 m of stopped visible ball
- Player body oriented PERPENDICULAR to shot direction (flag to LEFT for right-handers)
- No overhead stance cam — pure first-person with OVB info label overlay
- WASD / mouse exits OVB zone naturally; returning re-triggers
- aim_locked resets on enter AND exit AND shot confirmed
- On green: replaced by putting cursor (+) and right-click/left-click controls

### Water Detection (Swilcan Burn only)

Water in `ball.gd _point_in_water()` uses 6 circles (7 m radius) along the burn centreline.
Only the Swilcan Burn is water on hole 1. Other "water" meshes from Unity assets are suppressed.
Visual: thin 10×130 m water plane at the burn centre in main.gd `_setup_swilcan_burn()`.

### Per-Hole Randomisation (main.gd `_setup_hole()`)

- `green_area.stimp` = `randf_range(8.0, 13.0)` — green speed
- `ball.course_firmness` = `randf_range(0.7, 1.3)` — rollout modifier (Wet/Normal/Firm)
- Both shown in HUD at hole start

### Landmark Buildings (main.gd `_setup_landmarks()`)

Hole 1 only. Each is a StaticBody3D + BoxMesh + BoxShape3D (raycast-visible):
- LM_RA_Clubhouse — grey stone, NE of 1st tee
- LM_Hamilton_Grand — cream, along 18th fairway side
- LM_OldCourseHotel — red-brown, corner of 17th
- LM_Town_A, LM_Town_B — sandy, south (St Andrews town)

### Club Bag (address_screen.gd)

Driver 300y, 3W 260, 5W 240, 4I 220, 5I 205, 6I 190, 7I 175, 8I 160, 9I 145, PW 130, GW 115, SW 95, LW 75, Putter 30y. Tab/Shift+Tab to cycle. Putter auto-selected on green.

### Key Controls

| Key / Input | Action |
|------------|--------|
| WASD | Walk |
| Mouse | Look (always free, 360° horizontal) |
| V (hold) | Open viewfinder |
| Mouse wheel | Zoom viewfinder (6°–30°) |
| Left-click (VF) | Lock aim |
| Space | Open address screen (aim must be locked off-green) |
| Right-click (green) | Lock putt aim in current facing direction |
| Left-click (green, aim locked) | Open address screen for putt |
| M | Toggle full-screen St Andrews course map |
| H | Toggle left/right handed |
| Escape | Close address screen / release mouse |

### OWG Course Loading System

**Flow:**
```
Launch → course_select.tscn (CourseSelectScreen)
  → CourseLoader.scan_available_courses() scans res://courses/ for OWG-*.zip
  → Player picks course, clicks Play
  → CourseLoader.load_course(zip_path):
      extracts terrain/terrain.scn → user://courses/<name>/terrain/terrain.scn
      extracts images/<splash> for preview
      emits course_ready(course_data)
  → GameState.current_course = course_data
  → change_scene_to_file("res://main.tscn")
  → course_manager._ready(): GameState not empty → _setup_from_owg_data()
      ResourceLoader.load(terrain_scene_path).instantiate() → "OWGTerrain" node
      HoleTerrain (TerrainGenerator) disabled — OWG terrain handles collision
  → main.gd._setup_hole(): skips build_from_hole() if OWGTerrain present
```

**OWG ZIP package format (`OWG-<CourseName>.zip`):**
```
course.json              # name, author, hole_count, splash_image, holes[]{hole_number, tees[], pins[]}
terrain/terrain.scn      # pre-baked Godot binary scene: StaticBody3D + MeshInstance3D + CollisionShape3D
images/<splash.jpg>      # optional splash image for course select screen
```

**Terrain loading (Option A — active):** `course_loader.gd` extracts `terrain/heightmap.png` and `terrain/terrain_meta.json` from the ZIP to `user://courses/<name>/terrain/`. `CourseManager._setup_from_owg_data()` calls `hole_terrain.load_heightmap(path)` (sets `_hm_image`), then `hole_terrain.build_from_hole(tee, pin, all_tees, all_pins)` to construct the mesh and `HeightMapShape3D` collision at runtime.

**Known gap:** `_sample_real_height()` in `terrain_generator.gd` still uses hardcoded Old Course UV constants. For OWG courses these need to be replaced by values from `terrain_meta.json` (scale_x, scale_y, terrain_size_x/z).

**course_select.tscn** lives at `res://scenes/course_select.tscn` and is authored as a text scene (not requiring the editor). Node tree:
```
CourseSelectScreen (Control) ← course_select.gd; anchors 0/0/1/1, offsets 0
├── Background (ColorRect)     ← anchors 0/0/1/1, offsets 0
├── VBoxContainer              ← anchors 4%/5%/42%/97%
│   ├── TitleLabel             ← 20px, clip_text=true
│   ├── CourseList (ItemList)  ← size_flags_vertical EXPAND+FILL
│   ├── ModeButtons (HBoxContainer)
│   │   ├── QuickRoundButton   ← _start_load("quick")
│   │   ├── NineHolesButton    ← _start_load("nine")
│   │   └── FullRoundButton    ← _start_load("full") / Enter key
│   └── LoadingLabel           ← visible=false until loading
└── Panel                      ← anchors 44%/5%/97%/97%
    ├── SplashImage (TextureRect)
    ├── CourseName (Label)
    ├── Author (Label)
    └── HoleCount (Label)
```
Root Control and Background must use **explicit anchor values** (not `anchors_preset`), plus `offset_*=0`, or Godot may override them and collapse the layout.

## Known Limitations / TODO

- Rollout still needs tuning (feels fast on firm conditions)
- Green detection uses distance checks — could use OSM polygon for precision
- No audio
- Spline mesh loader disabled (meshes had no material, caused visual water)
- Multi-hole navigation works but only hole 1 has terrain/landmarks
- Hole-out animation timing: scorecard shows after 0.8 s animation completes
- Buildings are placeholder boxes — no real models yet

## Dependencies

- Godot 4.6 with Forward Plus rendering
- Jolt Physics 3D
