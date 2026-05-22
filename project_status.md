# Open World Golf — Project Status

## Current State (May 21 2026)

### WORKING ✅
- Full scene flow: title → golfer_select → course_select → intro
- Player walks AND CLIMBS HILLS on real terrain
- HeightMapShape3D collision solid — no falling through
- Wind system with HUD
- Sky and environment (procedural)
- Course loading from OWG zips
- terrain_generator_new.gd builds terrain from terrain_heights.json
- pg_to_owg_converter_v2.py outputs correct terrain_heights.json
- Water plane visible at sea level
- Practice Range (1 hole, flat) working as test course

### NOT WORKING YET ❌
- Textures/splatmap — terrain is flat green, no surface variation
- Viewfinder (V key) — stubs only
- Address screen — needs viewfinder first
- Ball physics — not tested
- Course-specific hole scenes — all use practice range terrain

### NEXT SESSION PRIORITIES
1. Apply textures to terrain (splatmap shader)
2. Wire up viewfinder (Golf-O-Matic)
3. Test ball drop and shot
4. Reconvert all 4 courses with v2 converter

## Key Files
- terrain_generator_new.gd — builds terrain from terrain_heights.json
- pg_to_owg_converter_v2.py — converts PG zips, outputs terrain_heights.json
- courses/hole_01.tscn → courses/practice_range_test/terrain/terrain_heights.json
- intro.gd — spawns player at (750, 350, 300) above terrain center
