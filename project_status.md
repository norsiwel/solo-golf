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

## Current State (2026-05-07 — updated)

**Stage:** Mid Development — playable hole 1, OWG course loading system implemented

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
- OWG course loading: GameState autoload, CourseLoader ZIP scanner, CourseSelectScreen
- OWG terrain: runtime heightmap PNG loading → load_heightmap() → build_from_hole()
- Course select screen: visible at 1152×648, three play-mode buttons, Enter key support
- OWG-The-Old-Course.zip generated and placed in res://courses/ (284 MB, 18 holes)

### Active Issues / Needs Work
- Rollout distance may feel too long or short — needs in-game tuning
- Green detection still occasionally misses (OSM polygon check would be more precise)
- Putting ball occasionally doesn't appear — green detection fallback in _open_address helps
- Buildings are placeholder boxes — no real 3D models
- No audio
- Spline mesh loader is disabled (meshes had no material, caused "water everywhere" visual)
- Scorecard shows after 0.8 s HOLING animation — feels slightly delayed
- Course only playable as hole 1; next-hole wraps but terrain/landmarks not rebuilt for other holes
- OWG terrain height sampling still uses Old Course UV constants — needs calibration from terrain_meta.json for correct elevation on OWG courses
- Player/flagstick/green not yet positioned from OWG course data (only terrain built)

---

## File-by-File Quick Reference

| File | Last Major Change | Notes |
|------|------------------|-------|
| ball.gd | MasterShotEngine + rollout refactor | _init_rollout() called once at landing |
| player.gd | OVB, viewfinder, putting controls | on_tee flag, vf_yaw starts at flag |
| main.gd | OWG terrain skip + landmarks + Swilcan Burn | skips build_from_hole() if OWGTerrain present |
| terrain_generator.gd | Added load_heightmap() stub | Not used for OWG courses; built-in PNG still used for The Old Course |
| course_manager.gd | OWG zip path added | _setup_from_owg_data() instantiates baked terrain scene |
| game_state.gd | NEW — Autoload | Cross-scene: current_course, hole, scorecard, play_mode |
| course_loader.gd | NEW — CourseLoader class | Scans OWG-*.zip, extracts heightmap.png + splash |
| course_select.gd | NEW — CourseSelectScreen | Pre-game picker; Quick/9/Full Round buttons; Enter key |
| scenes/course_select.tscn | NEW | Built as .tscn; stretch mode + explicit anchors fix viewport |
| hole_map.gd | Replaced with static course image | M key |
| courses/The_Old_Course_spline_loader.gd | Disabled (return early) | Re-enable when meshes have materials |
| course_shapes_loader.gd | Green polygon from OSM shapes JSON | |

---

## Development Priorities

### High
- Calibrate OWG terrain height sampling to use terrain_meta.json scale values (not hardcoded Old Course constants)
- Position player, flagstick, and green from OWG course JSON data (currently only terrain is built)
- Test OWG full round end-to-end with OWG-The-Old-Course.zip
- Tune rollout distances (course condition feel)
- Audio — even basic crowd/ball sounds

### Medium
- Fix remaining green detection edge cases
- Replace placeholder landmark boxes with simple 3D models
- Re-enable spline meshes with grass material overrides
- Multi-hole terrain build (per-hole terrain generator call)

### Low
- AI opponents
- Weather system (visual rain/wind effects)
- Leaderboard / persistent scoring

---

## OWG Course Package Format

A valid OWG course ZIP (`OWG-<Name>.zip`) must contain:
- `course.json` — metadata (name, author, hole_count, splash_image, holes array)
- `terrain/terrain.scn` — pre-baked Godot scene (StaticBody3D + mesh + collision)
- `images/<splash>` — optional preview image

**Terrain baking:** author the terrain StaticBody3D in the Godot editor, then save as a binary `.scn`. Do not use runtime PNG heightmap loading — it bypasses the import pipeline. (Option A fallback: raw float array at `terrain/heightmap.f32` — see comment in course_loader.gd.)
