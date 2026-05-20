extends Control
## golfer_select.gd
## Fully code-driven — no dependency on hand-written .tscn node paths
## First run: create form only. Returning: profile list + New Golfer option.

# ── node refs (built in _build_ui) ───────────────────────────────────────
var list_panel:      VBoxContainer
var golfer_list:     VBoxContainer
var btn_new_golfer:  Button
var btn_play:        Button
var create_form:     VBoxContainer
var name_input:      LineEdit
var btn_male:        Button
var btn_female:      Button
var btn_right:       Button
var btn_left:        Button
var btn_cancel:      Button
var btn_create:      Button
var validation_hint: Label
var scroll:          ScrollContainer

# ── state ─────────────────────────────────────────────────────────────────
var _profiles: Array = []
var _selected: int   = -1
var _row_buttons: Array = []


func _ready() -> void:
	_build_ui()
	_refresh()


# ══════════════════════════════════════════════════════════════════════════
#  UI BUILDER
# ══════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# Background
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.07, 0.04, 1)
	add_child(bg)

	# Header
	var header := Label.new()
	header.anchor_right  = 1.0
	header.anchor_bottom = 0.09
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	header.text = "⛳  Open World Golf — Golfer Select"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.4, 1))
	add_child(header)

	# Back button
	var back := Button.new()
	back.anchor_top    = 0.01
	back.anchor_bottom = 0.08
	back.anchor_right  = 0.10
	back.offset_left   = 8
	back.text = "◀  Title"
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	add_child(back)

	# Hint bar
	var hint := Label.new()
	hint.anchor_top    = 0.94
	hint.anchor_right  = 1.0
	hint.anchor_bottom = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.text = "↑ ↓ to select  |  Enter to play  |  ESC = title"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.55, 0.4, 0.75))
	add_child(hint)

	_build_list_panel()
	_build_create_form()


func _build_list_panel() -> void:
	list_panel = VBoxContainer.new()
	list_panel.anchor_left   = 0.20
	list_panel.anchor_top    = 0.10
	list_panel.anchor_right  = 0.80
	list_panel.anchor_bottom = 0.92
	list_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	list_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	list_panel.add_theme_constant_override("separation", 10)
	add_child(list_panel)

	var title := Label.new()
	title.text = "Select Golfer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.75, 0.90, 0.65, 1))
	list_panel.add_child(title)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	list_panel.add_child(scroll)

	golfer_list = VBoxContainer.new()
	golfer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	golfer_list.add_theme_constant_override("separation", 6)
	scroll.add_child(golfer_list)

	var list_btns := HBoxContainer.new()
	list_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	list_btns.add_theme_constant_override("separation", 16)
	list_panel.add_child(list_btns)

	btn_new_golfer = Button.new()
	btn_new_golfer.text = "＋  New Golfer"
	btn_new_golfer.custom_minimum_size = Vector2(160, 48)
	btn_new_golfer.add_theme_font_size_override("font_size", 16)
	btn_new_golfer.pressed.connect(func(): _show_form(true))
	list_btns.add_child(btn_new_golfer)

	btn_play = Button.new()
	btn_play.text = "▶  Play as …"
	btn_play.custom_minimum_size = Vector2(200, 48)
	btn_play.disabled = true
	btn_play.add_theme_font_size_override("font_size", 20)
	btn_play.add_theme_color_override("font_color", Color(0.95, 1.0, 0.6, 1))
	btn_play.pressed.connect(_on_btn_play_pressed)
	list_btns.add_child(btn_play)


func _build_create_form() -> void:
	create_form = VBoxContainer.new()
	create_form.visible = false
	create_form.anchor_left   = 0.25
	create_form.anchor_top    = 0.12
	create_form.anchor_right  = 0.75
	create_form.anchor_bottom = 0.90
	create_form.grow_horizontal = Control.GROW_DIRECTION_BOTH
	create_form.grow_vertical   = Control.GROW_DIRECTION_BOTH
	create_form.add_theme_constant_override("separation", 22)
	add_child(create_form)

	var form_title := Label.new()
	form_title.text = "Create New Golfer"
	form_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_title.add_theme_font_size_override("font_size", 20)
	form_title.add_theme_color_override("font_color", Color(0.75, 0.90, 0.65, 1))
	create_form.add_child(form_title)

	# Name
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.65, 1))
	create_form.add_child(name_label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name…"
	name_input.max_length = 24
	name_input.custom_minimum_size = Vector2(0, 44)
	name_input.add_theme_font_size_override("font_size", 18)
	create_form.add_child(name_input)

	# Gender
	var gender_label := Label.new()
	gender_label.text = "Gender"
	gender_label.add_theme_font_size_override("font_size", 15)
	gender_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.65, 1))
	create_form.add_child(gender_label)

	var gender_row := HBoxContainer.new()
	gender_row.add_theme_constant_override("separation", 12)
	create_form.add_child(gender_row)

	btn_male = Button.new()
	btn_male.text = "♂  Male"
	btn_male.toggle_mode = true
	btn_male.button_pressed = true
	btn_male.custom_minimum_size = Vector2(110, 44)
	btn_male.add_theme_font_size_override("font_size", 16)
	btn_male.pressed.connect(_on_btn_male_pressed)
	gender_row.add_child(btn_male)

	btn_female = Button.new()
	btn_female.text = "♀  Female"
	btn_female.toggle_mode = true
	btn_female.custom_minimum_size = Vector2(110, 44)
	btn_female.add_theme_font_size_override("font_size", 16)
	btn_female.pressed.connect(_on_btn_female_pressed)
	gender_row.add_child(btn_female)

	# Handedness
	var hand_label := Label.new()
	hand_label.text = "Handedness"
	hand_label.add_theme_font_size_override("font_size", 15)
	hand_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.65, 1))
	create_form.add_child(hand_label)

	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 12)
	create_form.add_child(hand_row)

	btn_right = Button.new()
	btn_right.text = "Right"
	btn_right.toggle_mode = true
	btn_right.button_pressed = true
	btn_right.custom_minimum_size = Vector2(110, 44)
	btn_right.add_theme_font_size_override("font_size", 16)
	btn_right.pressed.connect(_on_btn_right_pressed)
	hand_row.add_child(btn_right)

	btn_left = Button.new()
	btn_left.text = "Left"
	btn_left.toggle_mode = true
	btn_left.custom_minimum_size = Vector2(110, 44)
	btn_left.add_theme_font_size_override("font_size", 16)
	btn_left.pressed.connect(_on_btn_left_pressed)
	hand_row.add_child(btn_left)

	# Validation hint
	validation_hint = Label.new()
	validation_hint.text = ""
	validation_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	validation_hint.add_theme_font_size_override("font_size", 13)
	validation_hint.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3, 1))
	create_form.add_child(validation_hint)

	# Action buttons
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	create_form.add_child(actions)

	btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.visible = false
	btn_cancel.custom_minimum_size = Vector2(120, 44)
	btn_cancel.add_theme_font_size_override("font_size", 15)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)
	actions.add_child(btn_cancel)

	btn_create = Button.new()
	btn_create.text = "✔  Create & Play"
	btn_create.custom_minimum_size = Vector2(200, 44)
	btn_create.add_theme_font_size_override("font_size", 18)
	btn_create.add_theme_color_override("font_color", Color(0.95, 1.0, 0.6, 1))
	btn_create.pressed.connect(_on_btn_create_pressed)
	actions.add_child(btn_create)


# ══════════════════════════════════════════════════════════════════════════
#  LOGIC  (unchanged from original)
# ══════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	_profiles = ProfileManager.list_profiles()
	if _profiles.is_empty():
		_show_form(false)
	else:
		_show_list()
		_rebuild_list()
		var last = ProfileManager.get_last_active()
		var target := 0
		if not last.is_empty():
			for i in range(_profiles.size()):
				if _profiles[i].name == last.name:
					target = i
					break
		_select(target)


func _show_list() -> void:
	list_panel.visible  = true
	create_form.visible = false


func _show_form(can_cancel: bool) -> void:
	list_panel.visible  = false
	create_form.visible = true
	btn_cancel.visible  = can_cancel
	name_input.text     = ""
	btn_male.button_pressed   = true
	btn_female.button_pressed = false
	btn_right.button_pressed  = true
	btn_left.button_pressed   = false
	validation_hint.text = ""
	name_input.grab_focus()


func _rebuild_list() -> void:
	for child in golfer_list.get_children():
		child.queue_free()
	_row_buttons.clear()

	for i in range(_profiles.size()):
		var p = _profiles[i]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var sex_icon  = "♂" if p.get("sex", "M") == "M" else "♀"
		var hand_icon = "R" if p.get("right_handed", true) else "L"
		var lbl := Button.new()
		lbl.text = "%s  %s  [%s]" % [p.name, sex_icon, hand_icon]
		lbl.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.flat = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 17)
		var idx = i
		lbl.pressed.connect(func(): _select(idx))

		var del := Button.new()
		del.text = "✕"
		del.flat = true
		del.custom_minimum_size = Vector2(36, 36)
		del.add_theme_font_size_override("font_size", 14)
		del.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
		del.pressed.connect(func(): _confirm_delete(idx))

		row.add_child(lbl)
		row.add_child(del)
		golfer_list.add_child(row)
		_row_buttons.append({"row": row, "btn": lbl, "del": del})

	_update_row_styles()


func _select(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	_selected = index
	btn_play.text = "▶  Play as %s" % _profiles[index].name
	btn_play.disabled = false
	_update_row_styles()


func _update_row_styles() -> void:
	for i in range(_row_buttons.size()):
		var btn: Button = _row_buttons[i].btn
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(5)
		s.content_margin_left = 12; s.content_margin_right = 8
		s.content_margin_top  = 7;  s.content_margin_bottom = 7
		if i == _selected:
			s.bg_color = Color(0.15, 0.32, 0.15, 1)
			s.border_color = Color(0.45, 0.80, 0.35, 1)
			s.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55, 1))
		else:
			s.bg_color = Color(0.07, 0.12, 0.07, 0.9)
			s.border_color = Color(0.25, 0.40, 0.25, 0.4)
			s.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.82, 0.90, 0.76, 1))
		btn.add_theme_stylebox_override("normal", s)


func _confirm_delete(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var del_btn: Button = _row_buttons[index].del
	if del_btn.text == "✕":
		del_btn.text = "?"
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(del_btn) and del_btn.text == "?":
				del_btn.text = "✕"
				del_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
		)
	else:
		ProfileManager.delete_profile(_profiles[index].name)
		_refresh()


func _on_btn_male_pressed() -> void:
	btn_male.button_pressed = true; btn_female.button_pressed = false

func _on_btn_female_pressed() -> void:
	btn_female.button_pressed = true; btn_male.button_pressed = false

func _on_btn_right_pressed() -> void:
	btn_right.button_pressed = true; btn_left.button_pressed = false

func _on_btn_left_pressed() -> void:
	btn_left.button_pressed = true; btn_right.button_pressed = false


func _on_btn_create_pressed() -> void:
	var raw := name_input.text.strip_edges()
	if raw.length() < 2:
		validation_hint.text = "Name must be at least 2 characters."
		return
	for p in ProfileManager.list_profiles():
		if p.name.to_lower() == raw.to_lower():
			validation_hint.text = "A golfer named '%s' already exists." % raw
			return
	var profile := {
		"name":         raw,
		"sex":          "M" if btn_male.button_pressed else "F",
		"right_handed": btn_right.button_pressed,
		"last_active":  true,
	}
	ProfileManager.save_profile(profile)
	ProfileManager.set_active(raw)
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


func _on_btn_cancel_pressed() -> void:
	_show_list()


func _on_btn_play_pressed() -> void:
	if _selected < 0 or _selected >= _profiles.size():
		return
	ProfileManager.set_active(_profiles[_selected].name)
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if create_form.visible:
		return
	match event.keycode:
		KEY_UP:    _select(max(_selected - 1, 0))
		KEY_DOWN:  _select(min(_selected + 1, _profiles.size() - 1))
		KEY_ENTER, KEY_KP_ENTER: _on_btn_play_pressed()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
