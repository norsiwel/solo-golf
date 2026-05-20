# Open World Golf — Godot Theme

Two files for Claude Code to use:

## `theme.tres`
A native Godot 4.6 Theme resource with the cream-and-forest-green design.
Place it at `res://ui/theme.tres` and assign it to the root Control of each scene.

Defines:
- **Panel** — dark forest green card surface with soft shadow
- **Button** — cream pill button with lime hover ring (use for SELECT, CONTINUE, PLAY)
- **Label** — cream text default
- **LineEdit** — name input style with lime focus glow
- **OptionCard** (custom type) — gender / handedness cards: cream bg, lime ring when selected

## `tokens.gd`
Design constants as named GDScript values. Add as an Autoload at Project Settings → Globals → name it `Tokens`.

Then anywhere in code:
```gdscript
$Panel.modulate = Tokens.cream
get_node("FocusRing").color = Tokens.accent_lime
```

Use this for cases where the Theme can't express it — programmatic tweens, custom `_draw()`, or 1-off element overrides.

## Font setup
Both files reference Inter and Barlow Condensed (free Google Fonts). Import the `.ttf` files into `res://ui/fonts/` and set them on the theme:

```
Inter-Regular.ttf       — body text
Inter-SemiBold.ttf      — section labels (uppercase, letter_spacing=2)
Inter-Bold.ttf          — buttons, headings (letter_spacing=4)
BarlowCondensed-Bold.ttf — HUD overlay only (tight type over 3D viewport)
```

In `theme.tres`, double-click the resource in the Godot editor and drag each font into `default_font` (and individual control font slots if you want overrides per-type).

## Resolution
The HTML mockups are designed at **1280 × 800**. If you ship at 1920 × 1080 (or other), all numeric token values (font sizes, padding, radii) scale linearly: multiply by 1.5 for 1920×1080. Theme handles this once you set the project viewport size in Project Settings.
