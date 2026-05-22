# Open World Golf — CLAUDE.md

## Project Summary
Godot 4.6 single-player first-person walking golf simulation. Personal project, no distribution.
Target: 502 courses loaded dynamically from OWG-*.zip packages.
Full gameplay loop: walk to ball, aim with Golf-O-Matic viewfinder, address screen, shot, ball flight, rollout, putting, hole-out, scorecard. Uses Jolt 3D physics. No player avatar — first person only.

## Active Project Directory
`/home/ron/open-world-golf/` — THIS IS THE ONLY ACTIVE PROJECT
`/home/ron/solo-golf-backup/` — backup only, do not edit
GitHub: https://github.com/norsiwel/solo-golf (branch: main)

## Scene Flow
```
title_screen → golfer_select → course_select → intro.tscn
    ↓ CourseLoader extracts OWG-*.zip to user://courses/<name>/
    ↓ GameState.current_course = course_data
intro.tscn (lobby shell)
    ↓ HoleLoader loads courses/hole_01.tscn into CurrentHole
hole_01.tscn → terrain_generator_new.gd builds terrain from terrain_heights.json
    ↓ Player spawns at (750, 500, 300) and falls onto surface
```

## Key Files
```
intro.tscn / intro.gd              — lobby shell
terrain_generator_new.gd           — NEW terrain builder from terrain_heights.json
                                     Uses HeightMapShape3D (sampled grid)
                                     Same sample_step for mesh AND collision
                                     Adds water plane + Area3D hazard
                                     Slope/height shader via UV2.x trick
shaders/terrain_preview.gdshader   — slope+height visualization shader
                                     Uses UV2.x for world Y (WORLD_POSITION.y broken)
                                     MODEL_MATRIX * NORMAL for world normals
pg_to_owg_converter_v2.py          — ACTIVE converter (use this one)
                                     Outputs terrain_heights.json (world Y, not normalized)
                                     No X flip (unity_to_godot_pos returns unchanged)
courses/hole_01.tscn               — points to practice_range_test terrain
courses/practice_range_test/       — extracted Practice Range test data
terrain_generator.gd               — LEGACY (class_name removed, kept for reference)
```

## Terrain Architecture (established May 21 2026)
```
pg_to_owg_converter_v2.py:
  Raw Unity heights 1025x1025
       ↓
  Saved as terrain_heights.json:
    heightsAreNormalized: false
    heights: world Y values (117-253m for practice range)
    position: [0,0,0]
    size: [1501, 1000, 600]

terrain_generator_new.gd at runtime:
  Load terrain_heights.json
       ↓
  Downsample once with sample_step=4 → 257x257 grid
       ↓
  Build visual mesh from sampled heights
  Build HeightMapShape3D from SAME sampled heights
  → Perfect alignment, no holes in collision
```

## Terrain Coordinate System
- Terrain origin: (0, 0, 0)
- Terrain extends: X [0..1501], Y [117..253], Z [0..600]
- Tee position (practice range): (495, 50, 285) — Y is local not world
- Player spawn: (750, 500, 300) — drops from above onto surface
- Water plane: Y = terrain_min + 0.5 = ~118m
- No X flip from Unity coords — everything uses Unity world space

## Shader Notes
- `WORLD_POSITION.y` broken in Godot 4.6 spatial shaders
- Fix: pass vertex Y through UV2.x in vertex shader, read UV2.x in fragment
- `MODEL_MATRIX * vec4(NORMAL, 0.0)` gives correct world-space normals
- `render_mode unshaded` essential for debugging — eliminates lighting confusion

## Courses Available
- OWG-Practice-Range.zip — 1 hole, flat range, ACTIVE TEST COURSE
- OWG-Woody_s-Practice-Area.zip — 9 holes
- OWG-Sunset-Valley-GC.zip — 18 holes
- OWG-The-Old-Course.zip — 18 holes

PG source files: /home/ron/Downloads/PG-golf courses/
New terrain scripts: /home/ron/open-world-golf/new scripts/

## What Works (May 21 2026 evening)
- Full scene flow title → golfer → course → game ✅
- Player walks and climbs hills on real terrain ✅
- HeightMapShape3D collision solid — same grid as mesh ✅
- Water plane + Area3D hazard trigger ✅
- Slope/height shader (debugging — UV2 fix in progress) ✅
- SurfaceTool.generate_normals() for smooth normals ✅
- Wind system, sky, environment ✅
- 4 courses converted with v2 converter ✅

## What Needs Work Next Session
1. Verify terrain shader shows green/tan/grey/blue correctly
2. Wire up viewfinder (Golf-O-Matic) — stubs only
3. Address screen and shot mechanics
4. Ball physics test
5. Reconvert all 4 courses with v2 converter
6. Proper tee spawn using terrain height query

## Critical Rules
1. Use pg_to_owg_converter_v2.py — NOT the old converter
2. terrain_generator_new.gd — NOT terrain_generator.gd (legacy)
3. Same sample_step for BOTH mesh and collision
4. UV2.x not WORLD_POSITION.y in shaders
5. MODEL_MATRIX * NORMAL for world-space normals
6. Commit before changes — git is the backup
