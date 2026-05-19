# Open World Golf — Project Status

## Current State (May 19 2026)

### Working ✅
- Full gameplay loop: walk → aim → shoot → roll → putt → hole-out → scorecard
- Title screen → course selector (card UI with splash images) → game → ESC back
- Both OWG zips load: The Old Course (332MB) and Sunset Valley GC (680MB)
- Runtime heightmap terrain visible with rolling hills — St Andrews shape confirmed
- Splatmap shader wired up (PBR burley/schlick, 5 surface channels)
- ACES tonemapping + glow + SSAO environment node
- Wind system, animated flag, viewfinder rangefinder
- Shot tracer, ball flight arc with ball camera
- Putting system with stimp, cup detection, hole-out animation
- Scorecard with play-again / next-hole
- Jump (Space) and crouch (C) controls for terrain navigation
- Water level datum: tee/pin Y positions correctly offset from water plane
  - St Andrews: tee Y=3.1m, pin Y=0.7m (verified from new zip)
  - Sunset Valley: tee Y=9.3m, pin Y=6.6m
- apply_terrain_material() in course_loader.gd with texture_map.json lookup
- Dev fallback (F6) now loads OWG zip via CourseLoader properly

### Needs Testing / Known Issues 🔲
- Player spawn: lands on terrain at correct Y? (screenshot showed wrong location — F6 key)
- Splatmap textures: were null in last test (used F6/dev fallback before fix)
- Collision shape: Transform3D fix applied, needs verification player walks on hills
- Ball appears as blue diamond shape — likely material load failure, should fix with F5
- Course objects: 7237 objects spawn as grey/green boxes (no billboard mapping yet)
- Water planes: water_plane_y in course.json but not rendered in Godot yet
- Multi-hole: only hole 1 terrain built

### What To Test Next Session
1. **F5 to run** (not F6) → course selector appears → pick The Old Course
2. Player should spawn at tee, standing on terrain ~3m above water plane
3. Check console for splatmap tex load — should NOT be null anymore
4. Walk around — do hills have collision?
5. V to aim at flag (375 yds) → shoot → walk → putt

## Session History (May 19 2026)

**Converter rewrite (pg_to_owg_converter.py)**
- Water plane as Y reference: all tee/pin/shot positions now offset by -water_plane_y
- Both courses reconverted with correct datum
- texture_map.json classification: fairway/rough/green/bunker/sand/path/tee/water

**Shader upgrade**
- terrain_splatmap.gdshader: PBR render_mode, diffuse_burley, specular_schlick_ggx
- World-space UV for splatmap: u=-world_x/size_x, v=world_z/size_z
- 5 channels: fairway(R) rough(G) green(B) bunker(A) sand(remainder)
- shaders/ directory alias for compatibility

**Environment node (owg_environment.gd)**
- ACES tonemapping, glow (intensity 0.6), SSAO (radius 1.2)
- +15% saturation adjustment, contrast 1.05
- Procedural sky with golf course colours

**course_loader.gd**
- apply_terrain_material() reads texture_map.json for actual filenames
- Passes owg_size_x/z to shader for correct UV mapping

**main.gd dev fallback**
- Now loads OWG zip via CourseLoader instead of legacy CourseManager
- Textures will extract properly even on F6 direct run

**Player controls**
- Jump: Space when walking freely (6 m/s, escapes terrain gaps)
- Crouch: hold C (camera 0.9m, good for reading putts)

## File Inventory

### Converter Pipeline
- `pg_to_owg_converter.py` — full pipeline: heightmap+splatmap+textures+meshes+objects+tscn
- `build_tscn.py` — standalone terrain.tscn builder (called by converter)
- `extract_textures.py` — standalone texture extractor (called by converter)
- `tools/` — fetch_osm, obj_to_glb, spline_mesh_placer, unity_mesh_to_obj

### Course Packages
- `courses/OWG-The-Old-Course.zip` — St Andrews, 18 holes, Par 72, water_level=21.5m
- `courses/OWG-Sunset-Valley-GC.zip` — Sunset Valley, 18 holes, Par 70, water_level=10.9m
- Original PG zips: `/home/ron/Downloads/PG-golf courses/`

### Reference
- `/home/ron/solo-golf-backup/` — old project backup, do not edit
- `/home/ron/open-world-golf-backup/` — pre-session backup
