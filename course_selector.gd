extends CanvasLayer

signal course_selected(course_name: String)

var course_manager: Node = null
var buttons: Array[Button] = []

func _ready():
	layer = 20
	visible = false
	_build_ui()

func show_selector():
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_populate_courses()

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT,   0.25)
	panel.set_anchor(SIDE_TOP,    0.1)
	panel.set_anchor(SIDE_RIGHT,  0.75)
	panel.set_anchor(SIDE_BOTTOM, 0.9)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.06, 0.97)
	ps.border_color = Color(0.4, 0.6, 0.3, 0.8)
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

	var title = Label.new()
	title.text = "SELECT COURSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchor(SIDE_LEFT,   0.25)
	title.set_anchor(SIDE_TOP,    0.12)
	title.set_anchor(SIDE_RIGHT,  0.75)
	title.set_anchor(SIDE_BOTTOM, 0.2)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4, 1))
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Solo Golf"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchor(SIDE_LEFT,   0.25)
	subtitle.set_anchor(SIDE_TOP,    0.19)
	subtitle.set_anchor(SIDE_RIGHT,  0.75)
	subtitle.set_anchor(SIDE_BOTTOM, 0.25)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 0.8))
	add_child(subtitle)

	# Course list container
	var list = VBoxContainer.new()
	list.name = "CourseList"
	list.set_anchor(SIDE_LEFT,   0.27)
	list.set_anchor(SIDE_TOP,    0.26)
	list.set_anchor(SIDE_RIGHT,  0.73)
	list.set_anchor(SIDE_BOTTOM, 0.78)
	list.add_theme_constant_override("separation", 10)
	add_child(list)

	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "Exit Game"
	quit_btn.custom_minimum_size = Vector2(0, 50)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.set_anchor(SIDE_LEFT,   0.27)
	quit_btn.set_anchor(SIDE_TOP,    0.82)
	quit_btn.set_anchor(SIDE_RIGHT,  0.73)
	quit_btn.set_anchor(SIDE_BOTTOM, 0.9)
	var qbs = StyleBoxFlat.new()
	qbs.bg_color = Color(0.2, 0.1, 0.1, 0.9)
	qbs.border_color = Color(1.0, 0.4, 0.4, 0.8)
	qbs.border_width_left = 1
	qbs.border_width_right = 1
	qbs.border_width_top = 1
	qbs.border_width_bottom = 1
	qbs.corner_radius_top_left = 6
	qbs.corner_radius_top_right = 6
	qbs.corner_radius_bottom_left = 6
	qbs.corner_radius_bottom_right = 6
	quit_btn.add_theme_stylebox_override("normal", qbs)
	var qbs_hover = qbs.duplicate()
	qbs_hover.bg_color = Color(0.3, 0.15, 0.15, 0.95)
	quit_btn.add_theme_stylebox_override("hover", qbs_hover)
	quit_btn.connect("pressed", _on_quit_pressed)
	add_child(quit_btn)

func _populate_courses():
	var list = get_node("CourseList")
	# Clear existing buttons
	for b in buttons:
		b.queue_free()
	buttons.clear()

	course_manager = get_tree().current_scene.get_node_or_null("CourseManager")
	if not course_manager:
		_add_error_label("No CourseManager found in scene")
		return

	# Re-scan for courses in case new ones were added
	course_manager._scan_courses()

	var courses = course_manager.get_available_courses()
	if courses.is_empty():
		_add_error_label("No courses found in res://courses/")
		return

	for course_name in courses:
		# Load meta for display info
		var meta_path = "res://courses/%s_meta.json" % course_name
		var display_name = course_name.replace("_", " ")
		var info_text = ""

		if FileAccess.file_exists(meta_path):
			var f = FileAccess.open(meta_path, FileAccess.READ)
			var json = JSON.new()
			json.parse(f.get_as_text())
			f.close()
			var meta = json.get_data()
			display_name = meta.get("name", display_name)
			var author = meta.get("author", "")
			var holes = meta.get("holes", [])
			var total_par = 0
			for h in holes:
				total_par += h.get("par", 4)
			if holes.size() > 0:
				info_text = "%d holes  Par %d" % [holes.size(), total_par]
				if author != "":
					info_text += "  by %s" % author

		var btn = Button.new()
		btn.text = display_name
		btn.tooltip_text = info_text
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 18)

		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.1, 0.18, 0.1, 0.9)
		bs.border_color = Color(0.4, 0.65, 0.3, 0.7)
		bs.border_width_left = 1
		bs.border_width_right = 1
		bs.border_width_top = 1
		bs.border_width_bottom = 1
		bs.corner_radius_top_left = 6
		bs.corner_radius_top_right = 6
		bs.corner_radius_bottom_left = 6
		bs.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", bs)

		var bs_hover = bs.duplicate()
		bs_hover.bg_color = Color(0.15, 0.28, 0.15, 0.95)
		btn.add_theme_stylebox_override("hover", bs_hover)

		# Info label below button name
		if info_text != "":
			var info_lbl = Label.new()
			info_lbl.text = info_text
			info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info_lbl.add_theme_font_size_override("font_size", 12)
			info_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 0.8))
			var vbox = VBoxContainer.new()
			vbox.add_child(btn)
			vbox.add_child(info_lbl)
			list.add_child(vbox)
		else:
			list.add_child(btn)

		btn.connect("pressed", _on_course_selected.bind(course_name))
		buttons.append(btn)

func _add_error_label(text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	get_node("CourseList").add_child(lbl)

func _on_course_selected(course_name: String):
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("course_selected", course_name)

func _on_quit_pressed():
	get_tree().quit()
