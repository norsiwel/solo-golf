# Project Status — Solo Golf (AI Agent Version)

## Purpose

This document is for **AI coding agents** working on Solo Golf. It gives current state, active issues, and mandatory operating rules.

---

## ⚠️ CRITICAL OPERATING RULES

1. **Commit to git before any change** — this is the backup
2. **Preserve working functionality** — non-destructive additions preferred
3. **Small, reversible changes** — no large refactors without explicit instruction
4. **Update CLAUDE.md and this file** after any significant commit
5. **Respect project structure** — follow existing file organisation

---

## Current State (2026-05-07)

**Stage:** Mid Development — OWG course loading end-to-end working; player spawns and shoots on OWG terrain

### What Works
- Full shot loop: tee → OVB → viewfinder aim → address screen → shot → rollout → scoring
- MasterShotEngine carry/rollout/putt equations integrated in ball.gd
- OVB (over-the-ball) first-person setup with perpendicular address stance
- Viewfinder: 12° FOV, mouse-wheel zoom 6°–30°, 360° spin, yardage to any solid object
- Putting: mouse look to aim, right-click set, left-click putt, auto-putter on green
- Green detection: terrain zone (24 m from pin) + proximity check (40 m from green centre)
- Swilcan Burn: visual water plane + precise circle-based hazard detection
- Course conditions: random stimp (8–13) and firmness (Wet/Normal/Firm) each hole
- Rollout: computed once at landing, linear deceleration, slope-aware
- Tracer: solid ribbon (cross-section quads), ends at landing point
- Ball-cam follows shot in flight with sky environment
- Hole-out: only via green.gd check_hole_out (0.27 m), HOLING animation plays
- Landmark buildings as StaticBody3D (raycast-visible from viewfinder)
- Full-screen course map (M key) showing St.Andrews-course-map-1-18.png
- Multi-hole structure via CourseManager (only hole 1 terrain/landmarks built)
- **OWG course select screen** — visible at 1152×648, Quick/9/Full Round buttons, Enter key
- **OWG course loading** — GameState autoload, CourseLoader ZIP scanner, extracts heightmap + splash
- **OWG terrain generation** — runtime PNG loading → load_heightmap() → build_from_hole() with correct UV mapping from terrain_meta.json (scale_y=50.25, terrain_size 2271×2271)
- **OWG player spawn** — _setup_hole_owg() reads championship tee from course.json, spawns +2 m above tee, orients perpendicular to pin, resets ball/stroke/HUD
- **OWG shooting works** — MasterShotEngine + rollout functioning on OWG terrain surface

### Active Issues / Needs Work

#### OWG Visual (next session)
- **Terrain has no texture** — TerrainGenerator still uses `res://assets/terrain/surface_fairway_alt.png`; extracted OWG textures at `user://courses/OWG-The-Old-Course/textures/` are not applied
- **Course objects not placed** — flagstick, tee markers, and landmark buildings are missing on OWG path; `_setup_hole_owg()` does not yet instantiate scene geometry for these

#### Existing (Old Course path)
- Rollout distance may feel too long or short — needs in-game tuning
- Green detection still occasionally misses (OSM polygon check would be more precise)
- Putting ball occasionally doesn't appear — green detection fallback in _open_address helps
- Buildings are placeholder boxes — no real 3D models
- No audio
- Spline mesh loader is disabled (meshes had no material, caused "water everywhere" visual)
- Scorecard shows after 0.8 s HOLING animation — feels slightly delayed
- Course only playable as hole 1; next-hole wraps but terrain/landmarks not rebuilt for other holes

---

## File-by-File Quick Reference

| File | Last Major Change | Notes |
|------|------------------|-------|
| ball.gd | MasterShotEngine + rollout refactor | _init_rollout() called once at landing |
| player.gd | OVB, viewfinder, putting controls | on_tee flag, vf_yaw starts at flag |
| main.gd | _setup_hole_owg() for OWG path | reads tee/pin from course.json, spawns player |
| terrain_generator.gd | OWG UV mapping + timing fix | _owg_size_x/z/y vars; _sample_real_height() branches on OWG vs Old Course |
| course_manager.gd | _setup_from_owg_data() deferred | call_deferred fixes _ready() race with TerrainGenerator |
| game_state.gd | NEW — Autoload | Cross-scene: current_course, hole, scorecard, play_mode |
| course_loader.gd | NEW — CourseLoader class | Scans OWG-*.zip, extracts heightmap.png + terrain_meta.json + splash |
| course_select.gd | NEW — CourseSelectScreen | Pre-game picker; Quick/9/Full Round buttons; Enter key |
| scenes/course_select.tscn | NEW | Explicit anchors 0/0/1/1 + display stretch settings fix viewport |
| hole_map.gd | Replaced with static course image | M key |
| courses/The_Old_Course_spline_loader.gd | Disabled (return early) | Re-enable when meshes have materials |
| course_shapes_loader.gd | Green polygon from OSM shapes JSON | |

---

## Development Priorities

### High (next session)
- **Apply OWG textures to terrain** — use fairway/rough PNGs from `user://courses/OWG-The-Old-Course/textures/` in TerrainGenerator material
- **Place course objects on OWG path** — flagstick, tee markers, and buildings from course.json positions in `_setup_hole_owg()`
- Tune rollout distances (course condition feel)

### Medium
- Green detection for OWG courses (OSM polygon not available; use pin-distance fallback or course.json green data)
- Replace placeholder landmark boxes with simple 3D models
- Re-enable spline meshes with grass material overrides
- Multi-hole OWG support (call _setup_hole_owg() for holes 2–18)

### Low
- Audio — even basic crowd/ball sounds
- AI opponents
- Weather system (visual rain/wind effects)
- Leaderboard / persistent scoring

---

## OWG Course Package Format

A valid OWG course ZIP (`OWG-<Name>.zip`) must contain:
```
course.json              # name, author, hole_count, holes[]{hole_number, tees[], pins[]}
terrain/heightmap.png    # 2049×2049 16-bit grayscale — extracted to user://courses/<name>/
terrain/terrain_meta.json  # scale_y, terrain_size_x/z for UV mapping
images/<splash>          # optional preview image for course select screen
textures/*.png           # fairway, rough, bunker textures — not yet applied to terrain
```

**Coordinate system:** OWG JSON uses Godot coordinates (Unity X flipped: Godot_x = -Unity_x, z unchanged).
- Hole 1 championship tee: (-1882, 24.61, 181.82)
- Terrain covers Godot x: 0 → -2271, z: 0 → 2271
- UV mapping: `u = -world_x / terrain_size_x`, `v = world_z / terrain_size_z`

**Timing rule:** `CourseManager._setup_from_owg_data()` is called via `call_deferred()` so it runs after all `_ready()` calls complete, including `TerrainGenerator._ready()`. `main.gd._load_standrews()` is also deferred, and fires after `_setup_from_owg_data()` (CourseManager's deferred call is queued first). This guarantees terrain collision exists when the player is spawned.
