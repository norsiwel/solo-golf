# SOLO GOLF — Game Concept Document
### "It's golf. Just like the real life experience."

---

## Vision Statement

Solo Golf is a first-person golf simulation that recreates the complete experience of playing a real round of golf — not a game about golf, but golf itself rendered in a game engine. No avatars. No cheat cameras. No shortcuts. Just you, your rangefinder, your caddie's voice, and the course.

---

## Core Philosophy

Every design decision flows from one principle: **what would actually happen on a real golf course?**

- No overhead GPS view — you can only see what you can physically see
- No equipment upgrades — everyone plays the same clubs and ball
- No chat — the course self-moderates
- No lobbies — tee times replace waiting rooms
- No replays or cheat cams — you experienced the shot, that's enough
- No avatars — you ARE the golfer

---

## The Player Experience

### Walking the Course
The player is a `CharacterBody3D` moving through a fully realized 3D world at brisk walking speed. You physically walk from tee to ball to green. On a blind dogleg you walk to the corner to see what's ahead. On a long par 5 you don't walk all the way down to check the pin — you trust your caddie and your rangefinder.

This is load-bearing design. The immersion of the game depends entirely on the world being real, accurate and believable.

### The GOLF-O-MATIC Rangefinder
The signature UI element. A circular optical rangefinder that overlays on the actual 3D world view. Press V to raise it to your eye.

Displays:
- Raw distance to target (yards)
- Plays-like distance accounting for elevation change
- Elevation difference in feet (▲ uphill / ▼ downhill)
- Wind direction and speed (SE 12 MPH)
- Flag icon snaps to flagstick when in range

The rangefinder only shows what you can physically see. On a blind hole it shows distance to whatever you're pointing at — a tree, a bunker, a marker post. Not the pin you can't see.

### The Blind Dogleg — Design in Action
**Sample play sequence on a blind par 4 dogleg right:**

1. Player stands on tee. Can see fairway to the corner, trees beyond.
2. Raises GOLF-O-MATIC. Targets a tree at the dogleg corner. **130 yds.**
3. Puts rangefinder down. Walks to the tree at brisk walking speed.
4. From the corner the pin is now visible in the distance.
5. Raises GOLF-O-MATIC. Flag snaps. **130 yds to the pin.**
6. Walks back to the tee.
7. Decision: lay up safely to the corner, or hit a blind 3 wood over the trees?

*In multiplayer, all other players watch this entire recon walk wondering: now what is he thinking?*

---

## Shot System

### The 3-Click Meter — Fixed for Everyone
The shot meter is identical for every player, every club, every round. No upgrades, no player skill trees, no equipment differences.

This is intentional. The same meter for everyone means:
- **Muscle memory is a real skill** — after 100 rounds you know exactly where your sweet spot is
- **Pure skill gap** — better players win because they're better, not better equipped
- **No pay-to-win** — no equipment packs, no season passes, no advantage for spending money
- **Mirrors real golf** — tournament players use the same ball, same basic clubs

### Club Auto-Selection with Override
The caddie recommends the right club based on distance, wind, lie, elevation and pin position. The player can always override.

The caddie explains the reasoning rather than showing raw numbers:
- *"162 yards, slight helping wind, I've got the 7 iron in the bag"*
- *"Going with the 6? Playing it safe, good thinking with that pin position"*
- *"A 3 wood from 140 yards? This I have to see..."*

---

## The Shot Modifier System (~10 modifiers)

No two rounds play the same even on the same course. Modifiers stack multiplicatively against the base parametric ball flight.

**Environmental:**
- Wind speed and direction
- Wind gusts (changes mid-flight)
- Temperature (cold air = shorter distances)
- Rain (less run, softer landing)
- Altitude (thinner air on mountain courses)

**Course Conditions:**
- Fairway firmness (hard = run, soft = stops dead)
- Green speed / stimp rating
- Green firmness (checks up vs bounces through)
- Rough length

**Ball Condition:**
- Mud (unpredictable curve, which side determines direction)
- Scuff/damage from previous shots
- Wet ball reduces spin

**Lie:**
- Uphill / downhill stance
- Sidehill lie (ball above/below feet)
- Bunker stance
- Rough depth

The caddie communicates all of this in plain language. The player never sees a modifier percentage — they hear *"cold morning, ball won't fly as far, but the ground is firm so you'll get some run."*

---

## The Caddie Voice

The caddie is the voice of the game. Not an NPC, not a tutorial system — the living narrator of your round.

**Pre-shot:**
*"162 to the flag, wind left to right about 10mph, I'd take one more club"*

**Reading putts:**
*"Slight right to left break, maybe a ball outside right edge"*

**Course knowledge:**
*"Watch the Road Hole bunker on 17, it's eaten more cards than any other hole in golf"*

**Reacting to shots:**
*"Caught that a bit thin, should still find the fairway"*
*"Get in the hole! You'll be buying the drinks tonight!"*

**Weather:**
*"Getting a bit lively out here"*
*"That's us, straight to the bar"*
*"Course is playing long now, take more club everywhere"*
*"Worth coming back out for this view though"*

---

## The Ball

### Flight & Tracer
Parametric ball flight — not rigid body physics. Gives predictable, tunable feel at all distances from 300 yard drives to 17 yard chip-ins.

The tracer serves a practical purpose beyond visual flair:
- Ball in flight — full tracer arc visible
- Ball lands out of sight — tracer hangs in the air showing direction
- Player walks toward it — tracer fades as ball comes into physical view
- Ball visible — tracer gone, you found it naturally

**This teaches the course.** First round you follow the tracer everywhere. Tenth round you're already walking before it fades because you know the hole.

### Ball Visibility States
- **On the tee** — ball visible on the peg before you address it
- **In flight** — follow cam tracks with tracer arc
- **Putting** — ball visible rolling with tracer showing the line taken
- **Lost** — tracer hangs until you crest the hill

---

## Weather System

Weather is dynamic and consequential, not decorative.

**A round at St Andrews in October:**
- Tee off in clear morning conditions
- Wind picking up on the back nine
- Clouds rolling in from the North Sea
- First drops of rain on 14
- Heavy rain by 16
- Lightning on 17 — the Road Hole in a storm

**The Lightning Delay Cutscene:**
Lightning flashes over the Old Course. The horn sounds. Players scatter. Cut to the warm clubhouse interior — fire going, rain lashing the windows, your scorecard on the table, pint on the bar.

*"Press any key to resume when weather clears... or call it a day"*

**Resuming after the storm:**
- Course playing completely differently
- Greens much slower — stimp drops
- Fairways soft — ball stops dead, no run
- Wind may have shifted
- Temperature dropped — ball flying shorter
- But that golden post-storm light, possibly a rainbow over the Eden Estuary

**Mud:**
Ball lands in soggy rough and picks up mud. Caddie: *"You've got mud on the ball, going to do something unpredictable."* Which side the mud landed on determines the curve direction — genuine randomness. Can't clean it until you reach the green. Real golf rule.

---

## Cutscenes — Used Sparingly

Only moments that genuinely earn the interruption:

1. **Opening — First tee at St Andrews** — camera pulls back showing the town, the sea, the course. Sets the scene. Never again.
2. **Lightning delay** — clubhouse interior, fire, rain, pint on the bar. Player keys out when ready.
3. **Hole in one** — you've earned it.
4. **Final putt on 18** — ball drops, brief pull back to show the 18th green and the clubhouse. Fade.

Everything else stays first person. No replay of your chip-in birdie. You felt it. That's enough.

---

## Multiplayer

### No Avatars — Not Even in Multiplayer
Other players exist as balls, tracers and a leaderboard. No character models, no animation sync, no avatar cosmetics.

### Shared Active Player View
When any player hits, **everyone watches from that player's perspective.** Exactly like a real golf group — you all stop and watch each other's shots together.

This means:
- The recon walk creates genuine tension — everyone watches you walk to the corner wondering *what is he thinking?*
- A shared moment of drama when the blind 3 wood launches
- No complex multi-camera sync
- Minimal bandwidth — one authoritative view per shot

### No Lobbies — Tee Times
Players book a tee time: course, time of day, weather conditions. Others join like walking up to the first tee. No waiting room. No gray lobby screen. You're on the course or you're not.

### No Chat — Three Keys Only
- **N** — "Nice shot"
- **G** — "Good round" (unlocks on 18th green)
- **H** — Tip of the cap (after opponent holes out)

Trolls self-select out. There is nothing here for them.

### Turn Structure
- Your shot — everyone watches your view
- Walk to your ball — camera drifts down the fairway, others wait
- Furthest from the hole plays first (real golf rule)
- Max 4 players per group

---

## Course Authenticity

### Why Realism is Load-Bearing
The blind hole mechanic only works if trees actually block line of sight. The recon walk only matters if elevation actually hides the green. The rangefinder only has meaning if distances and slopes are accurate.

This is not a nice-to-have. The entire game design depends on courses being real.

### St Andrews Old Course
- 3.2 meters of total elevation variance — every centimeter matters
- LiDAR terrain data for accurate ground undulation
- Named bunkers (Hell Bunker, the Road Hole Bunker) feeling like real obstacles
- The town of St Andrews visible beyond the 18th
- Seagulls. The North Sea wind. October rain.

### Wildlife & Atmosphere
- Seagulls wheeling overhead at St Andrews
- Rabbits crossing the fairway mid-backswing
- Geese on water holes
- Bird calls changing by time of day
- That one crow that steals golf balls (it happens)
- Distant traffic on the road crossing the 17th
- The groundskeeper's mower in the early morning

None of it is gamified. The crow doesn't give you a quest. It just steals your ball.

---

## Course Pipeline

### Native Godot Course Designer
A Godot editor plugin for creating and importing courses:

**Import sources:**
- Perfect Golf `.description` files — tee/pin positions, par, yardage, stroke index
- LiDAR/DEM GeoTIFF — accurate terrain heightmaps
- OpenStreetMap data — bunker shapes, green outlines, fairway boundaries
- Any PNG heightmap

**Design tools:**
- Terrain3D for sculpting and surface painting (native to the stack)
- Click to place tees, pins, flags
- Draw bunker and hazard boundaries
- Set hole metadata

**Export:**
- `_meta.json` in standard format
- `.tscn` Godot scene file

### Community Courses
The course designer enables a community of builders. 400+ Perfect Golf courses provide a starting point for tee/pin data. The rest is built, refined and shared.

---

## Platform & Distribution

**Target: GOG.com**

- DRM-free — matches the game's philosophy of ownership and respect
- Audience appreciates depth, patience and craftsmanship
- No microtransaction pressure
- Buy once, play forever
- Moddable — course designer fits naturally
- Low infrastructure cost — shared view multiplayer requires minimal server overhead
- Community that writes reviews about respectful communities

*Pitch: "The only golf game that plays like actually playing golf."*

---

## Technical Stack

- **Engine:** Godot 4.4
- **Physics:** Jolt Physics 3D
- **Terrain:** Terrain3D plugin
- **Ball flight:** Parametric (not rigid body) — tunable, predictable feel
- **Rendering:** Forward Plus
- **Multiplayer:** Minimal sync — active player view, ball position, shot data, scores
- **Course tools:** Python converters + Godot editor plugin

---

## What Makes This Different

Every other golf game gives you:
- Overhead GPS showing exact pin position ❌
- Multiple camera angles and replays ❌
- Avatar customization and equipment upgrades ❌
- Chat and lobbies ❌
- Arcade power-ups and modes ❌

Solo Golf gives you:
- Only what you can physically see ✅
- One perspective — yours ✅
- Same clubs, same ball, pure skill ✅
- Three social keys and tee times ✅
- Just golf ✅

---

## Proof of Concept

The core loop is working. On a one-hole 180-yard par 3 test course, a 17-yard chip-in birdie was made and it **felt right.** No cutscene. No slow-mo replay. The ball went in and the feeling was enough.

That's how you know the design philosophy works.

---

*Document generated from design sessions, May 2026.*
*Development: Solo developer + Claude Code*