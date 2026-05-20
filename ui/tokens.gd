extends Node
# Open World Golf — Design Tokens
# Add as Autoload: Project Settings → Globals → +
# Use anywhere as Tokens.cream, Tokens.accent_lime, etc.

# ── Brand colors ────────────────────────────────────────────────
# Forest green panel (used for menus, side panels, dark UI fills)
const panel_green        := Color(0.110, 0.220, 0.157, 0.92)
const panel_green_solid  := Color(0.110, 0.220, 0.157, 1.0)
const panel_green_deep   := Color(0.055, 0.117, 0.078, 1.0)  # near-black green for backgrounds

# Cream/beige (text, cards, buttons)
const cream              := Color(0.910, 0.875, 0.780, 1.0)        # #e8dfc7
const cream_dim          := Color(0.910, 0.875, 0.780, 0.55)
const cream_subtle       := Color(0.910, 0.875, 0.780, 0.18)
const cream_card         := Color(0.831, 0.804, 0.714, 1.0)        # #d4cdb6 — selected card bg
const cream_card_dim     := Color(0.733, 0.702, 0.620, 1.0)        # #bbb39e — unselected card bg

# Lime accent (focus rings, active states, "good")
const accent_lime        := Color(0.784, 0.878, 0.439, 1.0)        # #c8e070
const accent_lime_glow   := Color(0.784, 0.878, 0.439, 0.45)
const accent_lime_soft   := Color(0.784, 0.878, 0.439, 0.18)

# Status colors
const score_birdie       := Color(0.471, 0.784, 0.314, 0.9)        # green ring
const score_eagle        := Color(0.831, 0.686, 0.216, 1.0)        # gold
const score_bogey        := Color(0.784, 0.314, 0.235, 0.85)       # red-orange
const score_double       := Color(0.706, 0.157, 0.157, 0.9)        # deeper red

# In-game HUD chrome (sits over the 3D viewport)
const hud_navy           := Color(0.078, 0.149, 0.251, 0.88)
const hud_navy_deep      := Color(0.055, 0.102, 0.180, 0.92)
const hud_stroke         := Color(1.0, 1.0, 1.0, 0.22)

# Dark text on cream (used inside cream buttons/cards)
const dark_text          := Color(0.173, 0.227, 0.165, 1.0)        # #2c3a2a

# ── Spacing scale ────────────────────────────────────────────────
const sp_4 := 4
const sp_6 := 6
const sp_8 := 8
const sp_12 := 12
const sp_16 := 16
const sp_24 := 24
const sp_32 := 32
const sp_48 := 48

# ── Border radius ────────────────────────────────────────────────
const radius_sm := 6
const radius_md := 8
const radius_lg := 12
const radius_pill := 28

# ── Type sizes (sized for 1280×800 base; scale up proportionally for 1920×1080) ──
const fs_title    := 48     # screen titles
const fs_heading  := 26     # section headings  
const fs_button   := 16     # primary buttons
const fs_card     := 22     # course names, big numbers
const fs_body     := 14     # body text
const fs_label    := 12     # section labels (uppercase)
const fs_meta     := 11     # meta text, captions
const fs_tiny     := 10     # tiny tags, badges

# ── Typography ───────────────────────────────────────────────────
# Two font stacks are used:
#   Inter (UI screens — menus, locker room, settings, scorecard chrome)
#   Barlow Condensed (HUD overlay — tight letter-spacing reads well over 3D)
# Download free from Google Fonts and import as FontFile resources at:
#   res://ui/fonts/Inter-Regular.ttf
#   res://ui/fonts/Inter-SemiBold.ttf
#   res://ui/fonts/Inter-Bold.ttf
#   res://ui/fonts/BarlowCondensed-SemiBold.ttf
#   res://ui/fonts/BarlowCondensed-Bold.ttf

# Letter-spacing presets (set in label theme overrides)
# Caps headings: 4px (label letter_spacing → 4)
# Body uppercase: 2px
# Body normal: 0
