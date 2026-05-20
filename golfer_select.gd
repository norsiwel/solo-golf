extends Control
## golfer_select.gd
## Player setup screen — locker room background with name/gender/hand selection.
## Saves to ProfileManager, then routes to course_select or golfer list.

# ── Player setup values ───────────────────────────────────────────────────
var player_name:     String = ""
var selected_gender: String = "Male"
var selected_hand:   String = "Right"

# ── UI nodes ──────────────────────────────────────────────────────────────
var name_input:      LineEdit
var male_button:     Button
var female_button:   Button
var right_button:    Button
var left_button:     Button
var continue_button: Button
var back_button:     Button
var hint_label:      Label

# ── Returning golfer list (right side) ────────────────────────────────────
var list_panel:      VBoxContainer
var golfer_list:     VBoxContainer
var btn_new_golfer:  Button
var btn_play:        Button
var scroll:          ScrollContainer
var _profiles:       Array = []
var _selected:       int   = -1
var _row_buttons:    Array = []


func _ready() -> void:
	# Background image — fills screen
	var bg := TextureRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.stretch_mode  = TextureRect.STRETCH_SCALE
	bg.texture       = load("res://assets/Player-select.png")
	add_child(bg)

	create_ui()
	_build_list_panel()
	_refresh()


# ══════════════════════════════════════════════════════════════════════════
#  UI — your layout, exactly as designed
# ══════════════════════════════════════════════════════════════════════════

func create_ui() -> void:
	# Back to title
	back_button = Button.new()
	back_button.text     = "◀  Title"
	back_button.position = Vector2(12, 12)
	back_button.size     = Vector2(100, 36)
	back_button.add_theme_font_size_override("font_size", 13)
	back_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	add_child(back_button)

	# Name input
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter Name"
	name_input.position = Vector2(82, 300)
	name_input.size     = Vector2(420, 58)
	name_input.add_theme_font_size_override("font_size", 22)
	add_child(name_input)

	# Gender buttons
	male_button   = _make_button("MALE",         Vector2(82,  425), Vector2(195, 72))
	female_button = _make_button("FEMALE",       Vector2(305, 425), Vector2(195, 72))

	# Hand buttons
	right_button  = _make_button("RIGHT HANDED", Vector2(82,  570), Vector2(195, 72))
	left_button   = _make_button("LEFT HANDED",  Vector2(305, 570), Vector2(195, 72))

	# Continue button
	continue_button = _make_button("⛳  CONTINUE", Vector2(82, 725), Vector2(420, 72))
	_style_continue(continue_button)

	# Validation hint
	hint_label = Label.new()
	hint_label.position = Vector2(82, 808)
	hint_label.size     = Vector2(420, 28)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.2, 1))
	add_child(hint_label)

	# Wire signals
	male_button.pressed.connect(func():   select_gender("Male"))
	female_button.pressed.connect(func(): select_gender("Female"))
	right_button.pressed.connect(func():  select_hand("Right"))
	left_button.pressed.connect(func():   select_hand("Left"))
	continue_button.pressed.connect(save_player_info)

	update_button_states()


func _make_button(label: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text       = label
	b.position   = pos
	b.size       = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	add_child(b)
	return b


func _style_continue(b: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.40, 0.10, 0.90)
	s.border_color = Color(0.40, 0.85, 0.28, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	var h := s.duplicate(); h.bg_color = Color(0.15, 0.55, 0.15, 0.95)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover",  h)
	b.add_theme_color_override("font_color", Color(0.95, 1.0, 0.55, 1))
	b.add_theme_font_size_override("font_size", 20)


# ══════════════════════════════════════════════════════════════════════════
#  SELECTION LOGIC
# ══════════════════════════════════════════════════════════════════════════

func select_gender(value: String) -> void:
	selected_gender = value
	update_button_states()


func select_hand(value: String) -> void:
	selected_hand = value
	update_button_states()


func update_button_states() -> void:
	set_button_selected(male_button,   selected_gender == "Male")
	set_button_selected(female_button, selected_gender == "Female")
	set_button_selected(right_button,  selected_hand == "Right")
	set_button_selected(left_button,   selected_hand == "Left")


func set_button_selected(button: Button, active: bool) -> void:
	if active:
		button.modulate = Color(0.55, 0.95, 0.40, 1.0)
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 0.85)


# ══════════════════════════════════════════════════════════════════════════
#  SAVE & CONTINUE
# ══════════════════════════════════════════════════════════════════════════

func save_player_info() -> void:
	player_name = name_input.text.strip_edges()

	if player_name == "":
		name_input.placeholder_text = "⚠  Name Required"
		hint_label.text = "Please enter your name."
		return

	# Check for duplicate
	for p in ProfileManager.list_profiles():
		if p.name.to_lower() == player_name.to_lower():
			# Existing profile — just activate and go
			ProfileManager.set_active(player_name)
			get_tree().change_scene_to_file("res://scenes/course_select.tscn")
			return

	# New profile
	var profile := {
		"name":         player_name,
		"sex":          "M" if selected_gender == "Male" else "F",
		"right_handed": selected_hand == "Right",
		"last_active":  true,
	}
	ProfileManager.save_profile(profile)
	ProfileManager.set_active(player_name)
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


# ══════════════════════════════════════════════════════════════════════════
#  RETURNING GOLFER LIST — right side panel
# ══════════════════════════════════════════════════════════════════════════

func _build_list_panel() -> void:
	list_panel = VBoxContainer.new()
	list_panel.anchor_left   = 0.36
	list_panel.anchor_top    = 0.52
	list_panel.anchor_right  = 0.74
	list_panel.anchor_bottom = 0.88
	list_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	list_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	list_panel.add_theme_constant_override("separation", 8)
	add_child(list_panel)

	var title := Label.new()
	title.text = "— or select existing golfer —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.70, 0.85, 0.60, 0.85))
	list_panel.add_child(title)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(scroll)

	golfer_list = VBoxContainer.new()
	golfer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	golfer_list.add_theme_constant_override("separation", 6)
	scroll.add_child(golfer_list)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	list_panel.add_child(btns)

	btn_play = Button.new()
	btn_play.text = "▶  Play as …"
	btn_play.custom_minimum_size = Vector2(180, 44)
	btn_play.disabled = true
	btn_play.add_theme_font_size_override("font_size", 17)
	btn_play.add_theme_color_override("font_color", Color(0.95, 1.0, 0.55, 1))
	btn_play.pressed.connect(_on_btn_play_pressed)
	btns.add_child(btn_play)

	btn_new_golfer = Button.new()
	btn_new_golfer.text = "＋ New"
	btn_new_golfer.custom_minimum_size = Vector2(100, 44)
	btn_new_golfer.add_theme_font_size_override("font_size", 15)
	btn_new_golfer.pressed.connect(_on_new_golfer_pressed)
	btns.add_child(btn_new_golfer)


func _refresh() -> void:
	_profiles = ProfileManager.list_profiles()
	_rebuild_list()

	# Auto-fill last active golfer into the form
	var last = ProfileManager.get_last_active()
	if not last.is_empty():
		name_input.text  = last.name
		player_name      = last.name
		selected_gender  = "Male" if last.get("sex", "M") == "M" else "Female"
		selected_hand    = "Right" if last.get("right_handed", true) else "Left"
		update_button_states()


func _rebuild_list() -> void:
	for c in golfer_list.get_children():
		c.queue_free()
	_row_buttons.clear()

	for i in range(_profiles.size()):
		var p    = _profiles[i]
		var row  := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var sex  = "♂" if p.get("sex","M") == "M" else "♀"
		var hand = "R" if p.get("right_handed", true) else "L"
		var lbl  := Button.new()
		lbl.text = "%s  %s [%s]" % [p.name, sex, hand]
		lbl.flat = true
		lbl.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 15)
		var idx = i
		lbl.pressed.connect(func(): _select(idx))

		var del := Button.new()
		del.text = "✕"
		del.flat = true
		del.custom_minimum_size = Vector2(32, 32)
		del.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
		del.pressed.connect(func(): _confirm_delete(idx))

		row.add_child(lbl)
		row.add_child(del)
		golfer_list.add_child(row)
		_row_buttons.append({"btn": lbl, "del": del})

	_update_row_styles()


func _select(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	_selected = index
	var p = _profiles[index]
	btn_play.text    = "▶  Play as %s" % p.name
	btn_play.disabled = false
	# Fill form with selected profile
	name_input.text  = p.name
	selected_gender  = "Male" if p.get("sex","M") == "M" else "Female"
	selected_hand    = "Right" if p.get("right_handed", true) else "Left"
	update_button_states()
	_update_row_styles()


func _update_row_styles() -> void:
	for i in range(_row_buttons.size()):
		var b: Button = _row_buttons[i].btn
		b.add_theme_color_override("font_color",
			Color(1.0, 0.96, 0.40, 1) if i == _selected
			else Color(0.82, 0.90, 0.76, 1)
		)


func _confirm_delete(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var del_btn: Button = _row_buttons[index].del
	if del_btn.text == "✕":
		del_btn.text = "?"
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(del_btn) and del_btn.text == "?":
				del_btn.text = "✕"
		)
	else:
		ProfileManager.delete_profile(_profiles[index].name)
		_refresh()


func _on_btn_play_pressed() -> void:
	if _selected < 0 or _selected >= _profiles.size():
		return
	ProfileManager.set_active(_profiles[_selected].name)
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


func _on_new_golfer_pressed() -> void:
	_selected = -1
	name_input.text   = ""
	name_input.grab_focus()
	btn_play.disabled = true
	btn_play.text     = "▶  Play as …"
	_update_row_styles()


# ══════════════════════════════════════════════════════════════════════════
#  KEYBOARD NAV
# ══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if name_input.has_focus():
		return
	match event.keycode:
		KEY_UP:     _select(max(_selected - 1, 0))
		KEY_DOWN:   _select(min(_selected + 1, _profiles.size() - 1))
		KEY_ENTER, KEY_KP_ENTER:
			if _selected >= 0:
				_on_btn_play_pressed()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
