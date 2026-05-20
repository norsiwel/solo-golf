# Open World Golf — UI Handoff for Godot 4

This package contains 7 HTML mockups of the game's UI screens. **They are visual specs, not runtime code.** Your job is to recreate them as native Godot 4 `Control` scenes so the UI is lightweight, responsive, and ships cleanly to all platforms.

## What's in the box

```
godot-export/                  ← standalone HTMLs, one per screen
  main_menu.html
  course_select.html
  hud.html                     ← in-game heads-up display (address shot)
  pause_menu.html
  scorecard.html               ← post-round summary
  player_profile.html
  settings.html

screens/*.jsx                  ← React source for each screen (read these for exact values)
Golf Game UX.html              ← all 7 screens on one canvas for side-by-side reference
```

**Open the HTML files in a browser** alongside Godot. Use browser devtools (right-click → Inspect) to pick exact colors, measure spacing, and read computed font sizes.

---

## 1. Project setup

### Display
- **Base resolution:** 1280 × 800 (the mockups are designed at this size)
- Project Settings → Display → Window:
  - Viewport Width: `1280`, Height: `800`
  - Stretch Mode: `canvas_items`
  - Stretch Aspect: `expand` (so 16:10 / 16:9 both work cleanly)

### Fonts
Both fonts are Google Fonts — download the `.ttf` files and put them in `res://ui/fonts/`:

- **Barlow Condensed** — all UI headings, buttons, menu items (use weights 600 / 700 / 800 / 900)
- **Barlow** — body text, stat values, paragraph copy (weights 400 / 500 / 600)

Import each as a `FontFile` resource.

### Theme resource
Create `res://ui/theme.tres` and define the color/font/size constants there. Every screen scene should use this theme so global tweaks propagate.

---

## 2. Design tokens

Define these as `Color` constants in a singleton (`res://ui/Tokens.gd`) or as theme overrides:

### Colors

| Token | Hex / RGBA | Where used |
|---|---|---|
| `bg_deep` | `#060d06` | Outer background, modal underlays |
| `bg_panel` | `#0a120a` | Default screen background |
| `bg_panel_2` | `#0e1f0e` | Top of gradients |
| `bg_panel_3` | `#1a3020` | Mid-gradient highlight |
| `surface` | `rgba(255,255,255,0.04)` | Card / panel fills |
| `surface_hover` | `rgba(255,255,255,0.08)` | Card hover state |
| `border` | `rgba(255,255,255,0.08)` | Hairline dividers |
| `border_strong` | `rgba(255,255,255,0.15)` | Card borders |
| `text_primary` | `#ffffff` | Headings, active items |
| `text_secondary` | `rgba(255,255,255,0.55)` | Inactive menu items, labels |
| `text_muted` | `rgba(255,255,255,0.3)` | Footer, version text |
| `text_dim` | `rgba(255,255,255,0.2)` | Disabled / placeholder dashes |
| `accent_green` | `rgba(120,200,80,0.9)` → `#78c850` | Primary accent — active states, glows, "good" stats |
| `accent_green_soft` | `rgba(160,210,120,0.7)` | Slogans, sub-text under titles |
| `accent_green_glow` | `rgba(120,200,80,0.4)` | Text shadows on hover |
| `warn_red` | `rgba(200,80,60,0.9)` | "Missed fairway" ✗, bogey indicators |
| `gold` | `rgba(220,180,80,0.9)` | Eagle / best score highlights (sparingly) |

### Spacing scale
`4 / 6 / 8 / 12 / 16 / 24 / 32 / 48 / 80 / 110` — match these values; don't invent new ones.

### Type scale
| Use | Family | Weight | Size | Letter-spacing |
|---|---|---|---|---|
| Title (game logo) | Barlow Condensed | 800 | 64 | 10 |
| Slogan | Barlow Condensed | 400 | 16 | 8 |
| Active menu item | Barlow Condensed | 800 | 42 | 4 |
| Inactive menu item | Barlow Condensed | 600 | 28 | 4 |
| Section label | Barlow Condensed | 600 | 10–12 | 2–3 |
| Stat value (big) | Barlow Condensed | 800 | 32–48 | 1 |
| Body | Barlow | 400 | 14 | 0 |
| Footer / meta | Barlow | 400 | 12 | 2 |

---

## 3. Screen-by-screen build order

Build in this order — each one teaches a pattern you'll reuse.

### 🏷 `main_menu.tscn` (start here)
**Pattern:** static layout, hover states, gradient background.
- `Control` (full rect)
  - `ColorRect` background (`bg_panel`)
  - `TextureRect` or `ColorRect` with shader for the diagonal gradient
  - `VBoxContainer` (top-centered) — flag SVG icon + title + slogan
  - `VBoxContainer` (left-aligned, vertically centered) — menu items
  - `HBoxContainer` (bottom bar) — version + copyright

**Hover behavior:** when mouse enters a menu item, animate the leading dash from 16px → 32px and shift its color from `text_dim` to `accent_green`. Use `Tween` with 0.15s duration.

The `<svg>` flag icon → recreate as a small `Control` with custom `_draw()`, or export as PNG and use `TextureRect`.

### 🎯 `hud.tscn` (in-game overlay)
**Pattern:** transparent overlay with corner anchors.
- Anchor each cluster to a corner (`Control.set_anchors_preset(PRESET_TOP_LEFT)`, etc.)
- Top-left: hole info + par
- Top-right: score, putts
- Bottom-center: club selector + power meter (this is the interactive bit — see HUD JSX)
- Bottom-left: wind indicator (animated arrow)
- Bottom-right: distance to pin

The power meter is the main interactive element. In Godot, build it as a `Control` with custom `_draw()` — three arcs, animated fill driven by a `0.0–1.0` float.

### 📋 `course_select.tscn`
**Pattern:** carousel with 3-card view.
- Center card scaled `1.0`, side cards scaled `0.85` and dimmed
- Use `AnimationPlayer` to slide between states
- Three CTA buttons at the bottom: **9 HOLES / 18 HOLES / RANDOM TEE**

### 📊 `scorecard.tscn`
**Pattern:** data table.
- Use `GridContainer` with `columns = 19` (Hole + 18 cells), or two `HBoxContainer`s for front-9 / back-9
- Cells display par, score, putts, fairway hit (✓ / ✗ / —), GIR
- Color score cells by relative-to-par: birdie=green ring, bogey=red ring, par=neutral

### ⚙️ `settings.tscn`, `pause_menu.tscn`, `player_profile.tscn`
**Pattern:** standard `VBoxContainer` lists with section labels.
- Settings: rows of `Label` + control (slider / checkbox / option button)
- Pause menu: dim the game behind with a `ColorRect` at `Color(0,0,0,0.7)`
- Profile: stat grid (use `GridContainer` with `columns = 3`)

---

## 4. Reference port — Main Menu in Godot

Here's the Main Menu translated to a `.gd` script so you have a concrete starting point:

```gdscript
# res://ui/screens/main_menu.gd
extends Control

@onready var menu_items: Array[Label] = [
    $MenuList/Play,
    $MenuList/CourseSelect,
    $MenuList/PlayerProfile,
    $MenuList/Settings,
    $MenuList/Quit,
]

const COLOR_ACCENT := Color(0.47, 0.78, 0.31, 0.9)
const COLOR_INACTIVE := Color(1, 1, 1, 0.55)
const COLOR_ACTIVE := Color(1, 1, 1, 0.95)

func _ready() -> void:
    for i in menu_items.size():
        var item := menu_items[i]
        item.mouse_entered.connect(_on_hover.bind(i))
        item.mouse_exited.connect(_on_unhover.bind(i))
        item.gui_input.connect(_on_click.bind(i))

func _on_hover(idx: int) -> void:
    var indicator: ColorRect = menu_items[idx].get_node("Indicator")
    var label: Label = menu_items[idx].get_node("Text")
    var tween := create_tween().set_parallel(true)
    tween.tween_property(indicator, "custom_minimum_size:x", 32.0, 0.15)
    tween.tween_property(indicator, "color", COLOR_ACCENT, 0.15)
    tween.tween_property(label, "modulate", COLOR_ACTIVE, 0.15)

func _on_unhover(idx: int) -> void:
    # reverse...

func _on_click(idx: int, event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.pressed):
        return
    match idx:
        0: get_tree().change_scene_to_file("res://ui/screens/course_select.tscn")
        1: get_tree().change_scene_to_file("res://ui/screens/course_select.tscn")
        2: get_tree().change_scene_to_file("res://ui/screens/player_profile.tscn")
        3: get_tree().change_scene_to_file("res://ui/screens/settings.tscn")
        4: get_tree().quit()
```

**Scene tree:**
```
MainMenu (Control)
├── Background (ColorRect, bg_panel)
├── Gradient (ColorRect with shader, OR TextureRect)
├── HorizonGlow (ColorRect with radial-gradient shader)
├── TopBar (ColorRect, 3px tall, gradient)
├── Logo (VBoxContainer, anchored top-center)
│   ├── FlagIcon (TextureRect)
│   ├── Title (Label, "OPEN WORLD GOLF")
│   └── Slogan (Label, "WALK THE WALK")
├── MenuList (VBoxContainer, anchored left, vertically centered)
│   ├── Play (HBoxContainer)
│   │   ├── Indicator (ColorRect, 16x2)
│   │   └── Text (Label)
│   ├── CourseSelect
│   ├── PlayerProfile
│   ├── Settings
│   └── Quit
└── Footer (HBoxContainer, anchored bottom)
    ├── Version
    └── Copyright
```

---

## 5. Patterns to reuse

### Gradient backgrounds
The mockups use a lot of `linear-gradient` and `radial-gradient`. Two ways to do this in Godot:
1. **Cheap:** create a 1×N pixel `GradientTexture2D` and stretch it with a `TextureRect`.
2. **Right way:** write a `CanvasItem` shader that takes start/end colors as uniforms — then you can recolor the whole UI from one place.

I recommend option 2 — it's 8 lines of shader code and saves you from maintaining PNGs.

### Hover/active animations
**Always use `Tween`, never `_process`.** 0.15s duration, `TRANS_QUAD`, `EASE_OUT` — that's the timing the mockups feel like.

### Text shadows / glows
The active menu item has `text-shadow: 0 0 30px rgba(120,200,80,0.4)`. In Godot, achieve this with:
- A duplicate `Label` behind, modulated to `accent_green_glow`, with a blur shader, OR
- A `BackBufferCopy` + glow shader on the parent (heavier but reusable)

### "Walk the Walk" — game design hook
The slogan implies traversal/exploration. If you're adding mechanics around walking the course (vs. fast-travel between shots), surface that on the title screen with a subtle animation — e.g. a small footstep trail under the logo.

---

## 6. Validation checklist

Before declaring a screen done, side-by-side compare it to the HTML at 1280×800:

- [ ] Background gradient matches (use browser color picker on the HTML)
- [ ] Title typography is Barlow Condensed 800, not a system font
- [ ] All hover states animate over 0.15s
- [ ] Letter-spacing on uppercase labels is non-zero (the look depends on it)
- [ ] No element uses pure black `#000` or pure white `#fff` for backgrounds — always tinted
- [ ] Spacing values come from the scale (`4/6/8/12/16/24/32/48`)

---

## 7. When to ask the design source for help

Reach back out to the designer (me, via Claude in this project) for:
- New screens not in the mockups (e.g. multiplayer lobby, achievement popup)
- Animation specs (the mockups are static — if you need exit/transition motion, ask)
- Asset requests — the flag icon, footstep textures, course thumbnails are all placeholders
- Tweaks to existing screens — make the change in the JSX so the spec stays canonical

The **JSX files in `screens/`** are the source of truth. If you find a discrepancy between a `.html` export and the `.jsx`, trust the JSX — the HTMLs are just bundled wrappers.

Good luck — ship it. ⛳
