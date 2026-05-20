extends Control
## golfer_select.gd
## Fully code-driven — no dependency on hand-written .tscn node paths
## First run: create form only. Returning: profile list + New Golfer option.

# ── node refs (built in _build_ui) ───────────────────────────────────────
var list_panel:      VBoxContainer
var golfer_list:     VBoxContainer
var btn_new_golfer:  Button
var btn_play:        Button
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

	# ── Full screen background image ─────────────────────────────────────
	var bg := TextureRect.new()
	bg.anchor_right          = 1.0
	bg.anchor_bottom         = 1.0
	bg.expand_mode           = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode          = TextureRect.STRETCH_SCALE
	bg.texture               = load("res://assets/Player-select.png")
	add_child(bg)

	# Sidebar is dark in the image already — no tint needed

	# ── Back button — top left ─────────────────────────────────────────
	var back := Button.new()
	back.position             = Vector2(12, 12)
	back.size                 = Vector2(100, 36)
	back.text                 = "◀  Title"
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	add_child(back)

	# ── Instructions — below logo, above name field ───────────────────
	# (logo ends ~y=200, name box painted at ~y=255)
	# Nothing needed — image has "CREATE YOUR PLAYER" painted in

	# ── Name LineEdit — over the painted PLAYER NAME box ─────────────
	name_input                = LineEdit.new()
	name_input.position       = Vector2(130, 320)
	name_input.size           = Vector2(390, 52)
	name_input.placeholder_text = "Enter your name…"
	name_input.max_length     = 24
	name_input.add_theme_font_size_override("font_size", 22)
	var ni_style              = StyleBoxFlat.new()
	ni_style.bg_color         = Color(0.06, 0.12, 0.06, 0.80)
	ni_style.border_color     = Color(0.40, 0.75, 0.28, 0.85)
	ni_style.set_border_width_all(2)
	ni_style.set_corner_radius_all(5)
	ni_style.content_margin_left = 12
	name_input.add_theme_stylebox_override("normal", ni_style)
	name_input.add_theme_stylebox_override("focus",  ni_style)
	name_input.add_theme_color_override("font_color",             Color(0.92, 0.97, 0.82, 1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.50, 0.62, 0.44, 0.75))
	add_child(name_input)

	# ── Gender buttons — over painted MALE / FEMALE cards ────────────
	btn_male                  = Button.new()
	btn_male.position         = Vector2(130, 492)
	btn_male.size             = Vector2(188, 100)
	btn_male.text             = "♂  MALE"
	btn_male.toggle_mode      = true
	btn_male.button_pressed   = true
	btn_male.add_theme_font_size_override("font_size", 22)
	btn_male.pressed.connect(_on_btn_male_pressed)
	add_child(btn_male)

	btn_female                = Button.new()
	btn_female.position       = Vector2(330, 492)
	btn_female.size           = Vector2(188, 100)
	btn_female.text           = "♀  FEMALE"
	btn_female.toggle_mode    = true
	btn_female.add_theme_font_size_override("font_size", 22)
	btn_female.pressed.connect(_on_btn_female_pressed)
	add_child(btn_female)

	# ── Handedness buttons — over painted RIGHT/LEFT HANDED cards ─────
	btn_right                 = Button.new()
	btn_right.position        = Vector2(130, 634)
	btn_right.size            = Vector2(188, 100)
	btn_right.text            = "RIGHT"
	btn_right.toggle_mode     = true
	btn_right.button_pressed  = true
	btn_right.add_theme_font_size_override("font_size", 22)
	btn_right.pressed.connect(_on_btn_right_pressed)
	add_child(btn_right)

	btn_left                  = Button.new()
	btn_left.position         = Vector2(330, 634)
	btn_left.size             = Vector2(188, 100)
	btn_left.text             = "LEFT"
	btn_left.toggle_mode      = true
	btn_left.add_theme_font_size_override("font_size", 22)
	btn_left.pressed.connect(_on_btn_left_pressed)
	add_child(btn_left)

	# ── Validation hint ───────────────────────────────────────────────
	validation_hint           = Label.new()
	validation_hint.position  = Vector2(130, 748)
	validation_hint.size      = Vector2(390, 30)
	validation_hint.text      = ""
	validation_hint.add_theme_font_size_override("font_size", 14)
	validation_hint.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1))
	add_child(validation_hint)

	# ── Step Onto The Course button ───────────────────────────────────
	btn_create                = Button.new()
	btn_create.position       = Vector2(130, 784)
	btn_create.size           = Vector2(390, 60)
	btn_create.text           = "⛳  STEP ONTO THE COURSE"
	btn_create.add_theme_font_size_override("font_size", 20)
	btn_create.add_theme_color_override("font_color", Color(0.95, 1.0, 0.55, 1))
	btn_create.pressed.connect(_on_btn_create_pressed)
	add_child(btn_create)

	# ── Cancel / back to list ─────────────────────────────────────────
	btn_cancel                = Button.new()
	btn_cancel.position       = Vector2(130, 854)
	btn_cancel.size           = Vector2(390, 40)
	btn_cancel.text           = "◀  Back to Golfer List"
	btn_cancel.visible        = false
	btn_cancel.add_theme_font_size_override("font_size", 15)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)
	add_child(btn_cancel)

	# ── Hint bar ──────────────────────────────────────────────────────
	var hint                  = Label.new()
	hint.anchor_top           = 0.96
	hint.anchor_right         = 1.0
	hint.anchor_bottom        = 1.0
	hint.grow_horizontal      = Control.GROW_DIRECTION_BOTH
	hint.text                 = "Enter to confirm  |  ESC = title"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.45, 0.7))
	add_child(hint)

	_build_list_panel()
	# create_form not needed — form IS the main layout now


func _build_list_panel() -> void:
	# Returning golfer list — floats over right side of image
	list_panel = VBoxContainer.new()
	list_panel.anchor_left   = 0.35
	list_panel.anchor_top    = 0.55
	list_panel.anchor_right  = 0.72
	list_panel.anchor_bottom = 0.88
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
	scroll.custom_minimum_size = Vector2(100, 80)
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
	btn_new_golfer.custom_minimum_size = Vector2(260, -72)
	btn_new_golfer.add_theme_font_size_override("font_size", 16)
	btn_new_golfer.pressed.connect(func(): _show_form(true))
	list_btns.add_child(btn_new_golfer)

	btn_play = Button.new()
	btn_play.text = "▶  Play as …"
	btn_play.custom_minimum_size = Vector2(300, -72)
	btn_play.disabled = true
	btn_play.add_theme_font_size_override("font_size", 20)
	btn_play.add_theme_color_override("font_color", Color(0.95, 1.0, 0.6, 1))
	btn_play.pressed.connect(_on_btn_play_pressed)
	list_btns.add_child(btn_play)



# ══════════════════════════════════════════════════════════════════════════
#  LOGIC
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
	# Left sidebar form always visible — returning golfer can still edit
	name_input.editable  = false
	btn_create.text      = "▶  Play as Selected"

func _show_form(can_cancel: bool) -> void:
	list_panel.visible   = false
	name_input.editable  = true
	btn_create.text      = "✔  Step Onto The Course"
	btn_cancel.visible   = can_cancel
	name_input.text      = ""
	btn_male.button_pressed   = true
	btn_female.button_pressed = false
	btn_right.button_pressed  = true
	btn_left.button_pressed   = false
	validation_hint.text = ""
	name_input.grab_focus()
	_refresh_toggles()


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
		del.custom_minimum_size = Vector2(136, -84)
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
	_refresh_toggles()

func _on_btn_female_pressed() -> void:
	btn_female.button_pressed = true; btn_male.button_pressed = false
	_refresh_toggles()

func _on_btn_right_pressed() -> void:
	btn_right.button_pressed = true; btn_left.button_pressed = false
	_refresh_toggles()

func _on_btn_left_pressed() -> void:
	btn_left.button_pressed = true; btn_right.button_pressed = false
	_refresh_toggles()

func _refresh_toggles() -> void:
	_set_toggle_style(btn_male,   btn_male.button_pressed)
	_set_toggle_style(btn_female, btn_female.button_pressed)
	_set_toggle_style(btn_right,  btn_right.button_pressed)
	_set_toggle_style(btn_left,   btn_left.button_pressed)

func _set_toggle_style(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(7)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top  = 8;  s.content_margin_bottom = 8
	if active:
		s.bg_color     = Color(0.12, 0.45, 0.12, 0.65)
		s.border_color = Color(0.50, 0.95, 0.35, 1.0)
		s.set_border_width_all(3)
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55, 1))
	else:
		s.bg_color     = Color(0.0, 0.0, 0.0, 0.0)
		s.border_color = Color(0.0, 0.0, 0.0, 0.0)
		s.set_border_width_all(0)
		btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.0))
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("pressed",  s)
	btn.add_theme_stylebox_override("hover",    s)
	btn.add_theme_stylebox_override("focus",    s)


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
	if list_panel.visible and name_input.has_focus():
		return
	match event.keycode:
		KEY_UP:    _select(max(_selected - 1, 0))
		KEY_DOWN:  _select(min(_selected + 1, _profiles.size() - 1))
		KEY_ENTER, KEY_KP_ENTER: _on_btn_play_pressed()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
