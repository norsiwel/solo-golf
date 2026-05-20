extends CanvasLayer

signal play_again
signal next_hole

# Persistent score tracking across all holes
var scores: Dictionary = {}     # hole_number -> strokes
var hole_pars: Dictionary = {}  # hole_number -> par
var hole_yards: Dictionary = {} # hole_number -> yardage
var total_holes := 18

func _ready():
	layer = 20
	visible = false

func record_score(hole: int, par: int, yardage: int, strokes: int):
	scores[hole] = strokes
	hole_pars[hole] = par
	hole_yards[hole] = yardage

func show_hole_result(hole: int, par: int, yardage: int, strokes: int):
	record_score(hole, par, yardage, strokes)
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_card(hole, par, yardage, strokes)

# Legacy compatibility
func show_scorecard(hole: int, par: int, yardage: int, strokes: int):
	show_hole_result(hole, par, yardage, strokes)

func reset_scores():
	scores.clear()
	hole_pars.clear()
	hole_yards.clear()

func _build_card(current_hole: int, par: int, yardage: int, strokes: int):
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	var score_diff = strokes - par
	var score_name = _score_name(score_diff)
	var score_color = _score_color(score_diff)

	# Full screen semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main panel - wider for full scorecard
	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT,   0.05)
	panel.set_anchor(SIDE_TOP,    0.04)
	panel.set_anchor(SIDE_RIGHT,  0.95)
	panel.set_anchor(SIDE_BOTTOM, 0.96)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.06, 0.04, 0.98)
	ps.border_color = Color(0.5, 0.65, 0.3, 0.9)
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.corner_radius_top_left = 8
	ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_left = 8
	ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Course title
	var title = Label.new()
	title.text = "THE OLD COURSE — ST ANDREWS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchor(SIDE_LEFT,   0.05)
	title.set_anchor(SIDE_TOP,    0.05)
	title.set_anchor(SIDE_RIGHT,  0.95)
	title.set_anchor(SIDE_BOTTOM, 0.11)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4, 1))
	add_child(title)

	# This hole result - prominent
	var result_lbl = Label.new()
	result_lbl.text = "%s  —  Hole %d  Par %d  %d yds  (%d strokes)" % [
		score_name, current_hole, par, yardage, strokes]
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.set_anchor(SIDE_LEFT,   0.05)
	result_lbl.set_anchor(SIDE_TOP,    0.11)
	result_lbl.set_anchor(SIDE_RIGHT,  0.95)
	result_lbl.set_anchor(SIDE_BOTTOM, 0.18)
	result_lbl.add_theme_font_size_override("font_size", 18)
	result_lbl.add_theme_color_override("font_color", score_color)
	add_child(result_lbl)

	# Scorecard grid
	_build_scorecard_grid(current_hole)

	# Totals row
	_build_totals_row(current_hole)

	# Buttons
	var btn_container = HBoxContainer.new()
	btn_container.set_anchor(SIDE_LEFT,   0.2)
	btn_container.set_anchor(SIDE_TOP,    0.88)
	btn_container.set_anchor(SIDE_RIGHT,  0.8)
	btn_container.set_anchor(SIDE_BOTTOM, 0.96)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)
	add_child(btn_container)

	var again_btn = _make_button("↺  Replay Hole")
	again_btn.connect("pressed", _on_play_again)
	btn_container.add_child(again_btn)

	# Only show Next Hole if not finished
	if current_hole < total_holes:
		var next_btn = _make_button("Next Hole →")
		next_btn.connect("pressed", _on_next_hole)
		btn_container.add_child(next_btn)
	else:
		var finish_btn = _make_button("🏆  Final Score")
		finish_btn.connect("pressed", _on_next_hole)
		btn_container.add_child(finish_btn)

	var select_btn = _make_button("⛳  Course Select")
	select_btn.connect("pressed", _on_course_select)
	btn_container.add_child(select_btn)

func _build_scorecard_grid(current_hole: int):
	# Determine which holes to show - show 9 at a time
	# Front 9 or back 9 depending on current hole
	var show_front = current_hole <= 9
	var start_hole = 1 if show_front else 10
	var end_hole = 9 if show_front else 18

	var half_label = Label.new()
	half_label.text = "FRONT 9" if show_front else "BACK 9"
	half_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	half_label.set_anchor(SIDE_LEFT,   0.06)
	half_label.set_anchor(SIDE_TOP,    0.19)
	half_label.set_anchor(SIDE_RIGHT,  0.3)
	half_label.set_anchor(SIDE_BOTTOM, 0.24)
	half_label.add_theme_font_size_override("font_size", 13)
	half_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	add_child(half_label)

	# Column headers
	var col_w = 0.085
	var start_x = 0.07
	var header_y = 0.24

	var headers = ["HOLE", "YDS", "PAR", "SCORE", "+/-"]
	for i in headers.size():
		var h = Label.new()
		h.text = headers[i]
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.set_anchor(SIDE_LEFT,   start_x + i * col_w)
		h.set_anchor(SIDE_TOP,    header_y)
		h.set_anchor(SIDE_RIGHT,  start_x + (i+1) * col_w)
		h.set_anchor(SIDE_BOTTOM, header_y + 0.05)
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1))
		add_child(h)

	# Draw separator line
	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.6, 0.3, 0.5)
	sep.set_anchor(SIDE_LEFT,   0.06)
	sep.set_anchor(SIDE_TOP,    header_y + 0.05)
	sep.set_anchor(SIDE_RIGHT,  0.94)
	sep.set_anchor(SIDE_BOTTOM, header_y + 0.055)
	add_child(sep)

	# Hole rows
	var row_h = 0.048
	for hole_num in range(start_hole, end_hole + 1):
		var row_y = header_y + 0.06 + (hole_num - start_hole) * row_h
		var is_current = hole_num == current_hole
		var has_score = scores.has(hole_num)

		# Row highlight for current hole
		if is_current:
			var highlight = ColorRect.new()
			highlight.color = Color(0.15, 0.25, 0.12, 0.6)
			highlight.set_anchor(SIDE_LEFT,   0.06)
			highlight.set_anchor(SIDE_TOP,    row_y - 0.003)
			highlight.set_anchor(SIDE_RIGHT,  0.94)
			highlight.set_anchor(SIDE_BOTTOM, row_y + row_h - 0.003)
			add_child(highlight)

		var par_val = hole_pars.get(hole_num, 4)
		var yds_val = hole_yards.get(hole_num, 0)
		var score_val = scores.get(hole_num, 0)
		var diff = score_val - par_val if has_score else 0

		var col_data = [
			str(hole_num),
			str(yds_val) if yds_val > 0 else "---",
			str(par_val),
			str(score_val) if has_score else "-",
			("%+d" % diff) if has_score else ""
		]

		for i in col_data.size():
			var lbl = Label.new()
			lbl.text = col_data[i]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.set_anchor(SIDE_LEFT,   start_x + i * col_w)
			lbl.set_anchor(SIDE_TOP,    row_y)
			lbl.set_anchor(SIDE_RIGHT,  start_x + (i+1) * col_w)
			lbl.set_anchor(SIDE_BOTTOM, row_y + row_h)
			lbl.add_theme_font_size_override("font_size", 13)
			# Color the score column
			if i == 3 and has_score:
				lbl.add_theme_color_override("font_color", _score_color(diff))
			elif i == 4 and has_score:
				lbl.add_theme_color_override("font_color", _score_color(diff))
			elif is_current:
				lbl.add_theme_color_override("font_color", Color(1, 1, 0.8, 1))
			else:
				lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
			add_child(lbl)

func _build_totals_row(current_hole: int):
	# Calculate totals for played holes
	var total_strokes = 0
	var total_par = 0
	var holes_played = 0
	for hole_num in scores.keys():
		total_strokes += scores[hole_num]
		total_par += hole_pars.get(hole_num, 4)
		holes_played += 1

	if holes_played == 0:
		return

	var diff = total_strokes - total_par
	var diff_str = "E" if diff == 0 else ("%+d" % diff)

	var sep = ColorRect.new()
	sep.color = Color(0.4, 0.6, 0.3, 0.5)
	sep.set_anchor(SIDE_LEFT,   0.06)
	sep.set_anchor(SIDE_TOP,    0.735)
	sep.set_anchor(SIDE_RIGHT,  0.94)
	sep.set_anchor(SIDE_BOTTOM, 0.738)
	add_child(sep)

	var totals_y = 0.74
	var col_w = 0.085
	var start_x = 0.07

	var totals_data = [
		"TOTAL", "", str(total_par), str(total_strokes), diff_str
	]
	for i in totals_data.size():
		var lbl = Label.new()
		lbl.text = totals_data[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchor(SIDE_LEFT,   start_x + i * col_w)
		lbl.set_anchor(SIDE_TOP,    totals_y)
		lbl.set_anchor(SIDE_RIGHT,  start_x + (i+1) * col_w)
		lbl.set_anchor(SIDE_BOTTOM, totals_y + 0.05)
		lbl.add_theme_font_size_override("font_size", 15)
		if i == 3 or i == 4:
			lbl.add_theme_color_override("font_color", _score_color(diff))
		else:
			lbl.add_theme_color_override("font_color", Color(1, 1, 0.6, 1))
		add_child(lbl)

	# Running vs par summary
	var summary = Label.new()
	var played_str = "%d of %d holes" % [holes_played, total_holes]
	summary.text = "%s — %s — %s" % [played_str, diff_str + " to par", _score_name(diff)]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.set_anchor(SIDE_LEFT,   0.05)
	summary.set_anchor(SIDE_TOP,    0.80)
	summary.set_anchor(SIDE_RIGHT,  0.95)
	summary.set_anchor(SIDE_BOTTOM, 0.87)
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", _score_color(diff))
	add_child(summary)

func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 44)
	btn.add_theme_font_size_override("font_size", 16)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.2, 0.1, 0.95)
	bs.border_color = Color(0.4, 0.65, 0.3, 0.8)
	bs.border_width_left = 1
	bs.border_width_right = 1
	bs.border_width_top = 1
	bs.border_width_bottom = 1
	bs.corner_radius_top_left = 5
	bs.corner_radius_top_right = 5
	bs.corner_radius_bottom_left = 5
	bs.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", bs)
	var bs_h = bs.duplicate()
	bs_h.bg_color = Color(0.15, 0.3, 0.15, 0.95)
	btn.add_theme_stylebox_override("hover", bs_h)
	return btn

func _score_name(diff: int) -> String:
	match diff:
		-3: return "ALBATROSS 🦅🦅🦅"
		-2: return "EAGLE 🦅🦅"
		-1: return "BIRDIE 🐦"
		0:  return "PAR"
		1:  return "BOGEY"
		2:  return "DOUBLE BOGEY"
		3:  return "TRIPLE BOGEY"
		_:
			if diff <= -4: return "INCREDIBLE 🏆"
			if diff > 0:   return "+%d" % diff
			return "PAR"

func _score_color(diff: int) -> Color:
	if diff <= -2: return Color(1.0, 0.85, 0.0, 1)
	if diff == -1: return Color(0.3, 0.9, 0.3, 1)
	if diff == 0:  return Color(0.9, 0.9, 0.9, 1)
	if diff == 1:  return Color(1.0, 0.6, 0.2, 1)
	return Color(0.9, 0.2, 0.2, 1)

func _on_play_again():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("play_again")

func _on_next_hole():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("next_hole")

func _on_course_select():
	visible = false
	GameState.current_course = {}
	GameState.preloaded_heightmap = null
	GameState.preloaded_textures = {}
	GameState.preloaded_splatmap = null
	GameState.preloaded_holes = {}
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")
