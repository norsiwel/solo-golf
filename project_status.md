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

## Current State (2026-05-06)

**Stage:** Mid Development — playable hole 1, most core systems working

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

### Active Issues / Needs Work
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
| main.gd | Landmarks, Swilcan Burn, course conditions | firmness + stimp randomised here |
| terrain_generator.gd | Green zone 14→24 m | |
| hole_map.gd | Replaced with static course image | M key |
| courses/The_Old_Course_spline_loader.gd | Disabled (return early) | Re-enable when meshes have materials |
| course_shapes_loader.gd | Green polygon from OSM shapes JSON | |

---

## Development Priorities

### High
- Tune rollout distances (course condition feel)
- Audio — even basic crowd/ball sounds
- Fix remaining green detection edge cases

### Medium
- Replace placeholder landmark boxes with simple 3D models
- Re-enable spline meshes with grass material overrides
- Multi-hole terrain build (per-hole terrain generator call)

### Low
- AI opponents
- Weather system (visual rain/wind effects)
- Leaderboard / persistent scoring
