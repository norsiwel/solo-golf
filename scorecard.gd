extends CanvasLayer

signal play_again
signal next_hole

func _ready():
	layer = 20
	visible = false

func show_scorecard(hole: int, par: int, yardage: int, strokes: int):
	visible = true
	_build_card(hole, par, yardage, strokes)

func _build_card(hole: int, par: int, yardage: int, strokes: int):
	# Clear previous
	for child in get_children():
		child.queue_free()

	var score_diff = strokes - par
	var score_name = _score_name(score_diff)
	var score_color = _score_color(score_diff)

	# Dark overlay
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Card panel
	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT, 0.30)
	panel.set_anchor(SIDE_TOP, 0.15)
	panel.set_anchor(SIDE_RIGHT, 0.70)
	panel.set_anchor(SIDE_BOTTOM, 0.85)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.08, 0.97)
	ps.border_color = Color(0.7, 0.7, 0.5, 0.8)
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.corner_radius_top_left = 10
	ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10
	ps.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Title
	var title = Label.new()
	title.text = "SCORECARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchor(SIDE_LEFT, 0.30)
	title.set_anchor(SIDE_TOP, 0.17)
	title.set_anchor(SIDE_RIGHT, 0.70)
	title.set_anchor(SIDE_BOTTOM, 0.22)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))
	add_child(title)

	# Hole info row
	_add_row("HOLE", str(hole), Color(0.8, 0.8, 0.8, 1), 0.25)
	_add_row("PAR", str(par), Color(0.8, 0.8, 0.8, 1), 0.33)
	_add_row("YARDAGE", "%d yds" % yardage, Color(0.8, 0.8, 0.8, 1), 0.41)
	_add_row("STROKES", str(strokes), Color(1.0, 1.0, 1.0, 1), 0.49)

	# Score name - big and colored
	var score_label = Label.new()
	score_label.text = score_name
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchor(SIDE_LEFT, 0.30)
	score_label.set_anchor(SIDE_TOP, 0.57)
	score_label.set_anchor(SIDE_RIGHT, 0.70)
	score_label.set_anchor(SIDE_BOTTOM, 0.65)
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", score_color)
	add_child(score_label)

	# Score relative to par
	var rel = "E" if score_diff == 0 else ("%+d" % score_diff)
	var rel_label = Label.new()
	rel_label.text = rel
	rel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rel_label.set_anchor(SIDE_LEFT, 0.30)
	rel_label.set_anchor(SIDE_TOP, 0.65)
	rel_label.set_anchor(SIDE_RIGHT, 0.70)
	rel_label.set_anchor(SIDE_BOTTOM, 0.71)
	rel_label.add_theme_font_size_override("font_size", 28)
	rel_label.add_theme_color_override("font_color", score_color)
	add_child(rel_label)

	# Play again button
	var again_btn = Button.new()
	again_btn.text = "Play Again"
	again_btn.set_anchor(SIDE_LEFT, 0.33)
	again_btn.set_anchor(SIDE_TOP, 0.74)
	again_btn.set_anchor(SIDE_RIGHT, 0.50)
	again_btn.set_anchor(SIDE_BOTTOM, 0.81)
	again_btn.add_theme_font_size_override("font_size", 16)
	again_btn.connect("pressed", _on_play_again)
	add_child(again_btn)

	# Next hole button
	var next_btn = Button.new()
	next_btn.text = "Next Hole"
	next_btn.set_anchor(SIDE_LEFT, 0.52)
	next_btn.set_anchor(SIDE_TOP, 0.74)
	next_btn.set_anchor(SIDE_RIGHT, 0.68)
	next_btn.set_anchor(SIDE_BOTTOM, 0.81)
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.connect("pressed", _on_next_hole)
	add_child(next_btn)

func _add_row(label_text: String, value_text: String, color: Color, top_anchor: float):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.set_anchor(SIDE_LEFT, 0.35)
	lbl.set_anchor(SIDE_TOP, top_anchor)
	lbl.set_anchor(SIDE_RIGHT, 0.52)
	lbl.set_anchor(SIDE_BOTTOM, top_anchor + 0.07)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.set_anchor(SIDE_LEFT, 0.52)
	val.set_anchor(SIDE_TOP, top_anchor)
	val.set_anchor(SIDE_RIGHT, 0.67)
	val.set_anchor(SIDE_BOTTOM, top_anchor + 0.07)
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", color)
	add_child(val)

func _score_name(diff: int) -> String:
	match diff:
		-3: return "ALBATROSS! 🦅🦅🦅"
		-2: return "EAGLE! 🦅🦅"
		-1: return "BIRDIE! 🐦"
		0:  return "PAR 👍"
		1:  return "BOGEY"
		2:  return "DOUBLE BOGEY"
		3:  return "TRIPLE BOGEY"
		_:
			if diff < -3:
				return "INCREDIBLE! 🏆"
			return "+%d  KEEP TRYING!" % diff

func _score_color(diff: int) -> Color:
	if diff <= -2: return Color(1.0, 0.85, 0.0, 1)   # gold
	if diff == -1: return Color(0.3, 0.9, 0.3, 1)    # green birdie
	if diff == 0:  return Color(0.8, 0.8, 0.8, 1)    # white par
	if diff == 1:  return Color(1.0, 0.6, 0.2, 1)    # orange bogey
	return Color(0.9, 0.2, 0.2, 1)                    # red double+

func _on_play_again():
	visible = false
	emit_signal("play_again")

func _on_next_hole():
	visible = false
	emit_signal("next_hole")
