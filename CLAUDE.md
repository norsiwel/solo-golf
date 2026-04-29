# Solo Golf — CLAUDE.md

## Project Summary

Godot 4.6 single-player golf simulation. Parametric ball physics (not real rigidbody), 3-click meter for shot power/accuracy, viewfinder rangefinder, tee→shot→ball→scoring gameplay loop. Currently a single 180-yard par-3 hole. Uses Jolt 3D physics.

## Directory Structure

```
solo-golf/
├── project.godot          # Godot 4.6, Forward Plus, main scene: res://main.tscn
├── main.tscn              # Full 3D scene — ground, trees, tee, green, bunkers, flag
├── node_3d.tscn           # Empty stub, unused
├── player.gd              # Central controller: camera, input, viewfinder, HUD, game state
├── ball.gd                # Parametric ball flight/roll/holing animation
├── address_screen.gd      # Shot metering UI (3-click meter, club bag, draw/fade, loft)
├── green.gd               # Green Area3D zone + cup detection, stimp/par config
├── tee.gd                 # Tee box Area3D zone, emits player_on_tee
├── scorecard.gd           # Post-hole score display with play-again / next-hole
├── pg_converter.py        # Perfect Golf .description → Godot .tscn course importer
├── commit-backup.sh       # Git commit + push helper
└── project_status.md      # Operating rules for AI agents
```

## Critical Operating Rules

1. **Backup before any change** — use `commit-backup.sh` or commit to git
2. **Preserve working functionality** — prefer non-destructive additions
3. **Small, reversible changes** — no large refactors
4. **Don't remove code without justification** — comment out if unsure
5. **Respect project structure** — follow existing file organization

## Architecture

### Signal Flow — Gameplay Loop

```
TeeArea (player enters)
  → tee.gd emits player_on_tee
  → player.on_player_at_tee() resets putting, shows hole info

Player aims (V key → viewfinder, click → lock, Space → address)
  → address screen opens, 3-click meter runs
  → address_screen emits shot_confirmed(power, accuracy, draw_fade, loft, club)
  → player._on_shot_confirmed(): stroke_count++, ball.launch()

Ball states: IDLE → FLYING → ROLLING → STOPPED  (or → HOLING on cup drop)
  → ball emits ball_stopped(position, in_bunker)
  → player shows distance, calls green.check_hole_out() if on green

Cup hit:
  → ball enters HOLING animation → emits ball_holed
  → green.gd emits ball_holed_out(strokes)
  → player shows scorecard

Scorecard:
  → emits play_again or next_hole (both reset to tee currently)
```

### Key Script Responsibilities

| Script | Extends | Responsibility |
|--------|---------|----------------|
| player.gd | CharacterBody3D | Camera, WASD move, input, viewfinder, HUD, game state, signal wiring |
| ball.gd | Node3D | Parametric flight arc, rollout, putting, bunker detection, hole-out animation, tracer |
| address_screen.gd | CanvasLayer (10) | Club selection, 3-click power/accuracy meter, draw/fade, loft sliders |
| green.gd | Area3D | Green zone, stimp/par export, cup position, `check_hole_out()` |
| tee.gd | Area3D | Tee zone detection, hole metadata |
| scorecard.gd | CanvasLayer (20) | Score naming, color coding, play-again/next-hole buttons |

### Ball Physics (Not Real Physics)

Ball flight uses a parametric curve: `peak_height * 4.0 * t * (1.0 - t)`. Landing position calculated from power, club yards, accuracy error, and draw/fade offset. Rollout is a percentage of flight distance modified by loft and bunker status. Putting mode uses stimps-based max distance with ease-out deceleration. Holing animation: lerp to cup, shrink, sink below ground over 0.7s.

### Viewfinder System

- Press V to toggle (FOV narrows to 25)
- Flag snap: within 60px of flagstick → snap to flag, red crosshair
- Left-click locks aim, green border
- Raycast in `_update_yardage()` shows distance
- Aim must be locked before Space can open address screen

### Club Bag (from address_screen.gd)

Driver 300y, 3W 260, 5W 240, 4I 220, 5I 205, 6I 190, 7I 175, 8I 160, 9I 145, PW 130, GW 115, SW 95, LW 75, Putter 30y. Tab/Shift+Tab to cycle.

### Main Scene Layout (main.tscn)

Tee at origin, green at (0, 0.02, -165), flagstick at (0, 0, -165). Bunkers at (-16, -163) and (14, -170). Five trees scattered on fairway. Ground is 400×400 plane. Green is 22×16 box. Cup radius: 0.27m.

### pg_converter.py

Reads Perfect Golf `.description` JSON from a zip → generates Godot `.tscn` scene files per hole. Handles coordinate transform (Unity left-handed → Godot right-handed, flips Z). Picks preferred tee (Championship > Tournament > Back > Member > Challenge) and medium pin. Outputs companion metadata JSON.

## Known Limitations

- Scorecard hardcoded to hole 1 / par 3 / 180 yards — not dynamic
- `_on_next_hole` just calls `_on_play_again` — no multi-hole support
- Ball has no collision shape — green `body_entered` won't fire, hole-out checked manually after `ball_stopped`
- Bunker detection uses manual position checks (fragile, not Area3D signals)
- No audio
- UI minimal / unpolished
- Course data from only one hardcoded hole

## Dependencies

- Godot 4.6 with Forward Plus rendering
- Jolt Physics 3D
