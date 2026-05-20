extends Control
## golfer_select.gd
## Shown after title screen.
## - If profiles exist: scrollable list with Play / New / Delete
## - If no profiles: create form shown immediately
## On confirm: sets ProfileManager.active, pushes to GameState, goes to course_select

# ── node refs ─────────────────────────────────────────────────────────────
@onready var list_panel      = $ListPanel
@onready var golfer_list     = %GolferList
@onready var btn_new_golfer  = %BtnNewGolfer
@onready var btn_play        = %BtnPlay
@onready var create_form     = $CreateForm
@onready var name_input      = %NameInput
@onready var btn_male        = %BtnMale
@onready var btn_female      = %BtnFemale
@onready var btn_right       = %BtnRight
@onready var btn_left        = %BtnLeft
@onready var btn_cancel      = %BtnCancel
@onready var btn_create      = %BtnCreate
@onready var validation_hint = %ValidationHint
@onready var back_btn        = $BackButton

# ── state ─────────────────────────────────────────────────────────────────
var _profiles: Array = []        # cached list from ProfileManager
var _selected: int   = -1        # index into _profiles
var _row_buttons: Array = []     # one HBoxContainer per profile row


func _ready() -> void:
	_apply_theme()
	_connect_signals()
	_refresh()


# ── boot logic ────────────────────────────────────────────────────────────

func _refresh() -> void:
	_profiles = ProfileManager.list_profiles()

	if _profiles.is_empty():
		_show_form(false)   # no cancel — this is the only path
	else:
		_show_list()
		_rebuild_list()
		# Auto-select last active, or first
		var last = ProfileManager.get_last_active()
		var target := 0
		if not last.is_empty():
			for i in range(_profiles.size()):
				if _profiles[i].name == last.name:
					target = i
					break
		_select(target)


func _show_list() -> void:
	list_panel.visible = true
	create_form.visible = false


func _show_form(can_cancel: bool) -> void:
	list_panel.visible = false
	create_form.visible = true
	btn_cancel.visible = can_cancel
	name_input.text = ""
	btn_male.button_pressed   = true
	btn_female.button_pressed = false
	btn_right.button_pressed  = true
	btn_left.button_pressed   = false
	validation_hint.text = ""
	name_input.grab_focus()


# ── profile list ─────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in golfer_list.get_children():
		child.queue_free()
	_row_buttons.clear()

	for i in range(_profiles.size()):
		var p = _profiles[i]

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.theme_override_constants_separation = 8

		# Main select button — name + gender + hand
		var sex_icon  = "♂" if p.get("sex", "M") == "M" else "♀"
		var hand_icon = "R" if p.get("right_handed", true) else "L"
		var label_btn = Button.new()
		label_btn.text = "%s  %s  [%s]" % [p.name, sex_icon, hand_icon]
		label_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		label_btn.flat = true
		label_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_btn.add_theme_font_size_override("font_size", 17)
		var idx = i
		label_btn.pressed.connect(func(): _select(idx))

		# Delete button
		var del_btn = Button.new()
		del_btn.text = "✕"
		del_btn.flat = true
		del_btn.custom_minimum_size = Vector2(36, 36)
		del_btn.add_theme_font_size_override("font_size", 14)
		del_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
		del_btn.pressed.connect(func(): _confirm_delete(idx))

		row.add_child(label_btn)
		row.add_child(del_btn)
		golfer_list.add_child(row)
		_row_buttons.append({"row": row, "btn": label_btn, "del": del_btn})

	_update_row_styles()


func _select(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	_selected = index
	var p = _profiles[index]
	btn_play.text = "▶  Play as %s" % p.name
	btn_play.disabled = false
	_update_row_styles()


func _update_row_styles() -> void:
	for i in range(_row_buttons.size()):
		var btn: Button = _row_buttons[i].btn
		var is_sel = (i == _selected)
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(5)
		s.content_margin_left   = 12
		s.content_margin_right  = 8
		s.content_margin_top    = 7
		s.content_margin_bottom = 7
		if is_sel:
			s.bg_color     = Color(0.15, 0.32, 0.15, 1.0)
			s.border_color = Color(0.45, 0.80, 0.35, 1.0)
			s.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.55, 1))
		else:
			s.bg_color     = Color(0.07, 0.12, 0.07, 0.9)
			s.border_color = Color(0.25, 0.40, 0.25, 0.4)
			s.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.82, 0.90, 0.76, 1))
		btn.add_theme_stylebox_override("normal",  s)
		var h = s.duplicate(); h.bg_color = Color(0.11, 0.20, 0.11, 1)
		btn.add_theme_stylebox_override("hover",   h)


func _confirm_delete(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var pname = _profiles[index].name
	# Simple confirmation via OS dialog isn't available in Godot 4 without plugin,
	# so we do a second-press pattern: first press turns the button red + "Sure?",
	# second press within the same session deletes.
	var del_btn: Button = _row_buttons[index].del
	if del_btn.text == "✕":
		del_btn.text = "?"
		del_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		# Reset after 3 seconds if not confirmed
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(del_btn):
				del_btn.text = "✕"
				del_btn.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 0.8))
		)
	else:
		ProfileManager.delete_profile(pname)
		_refresh()


# ── create form ───────────────────────────────────────────────────────────

func _on_btn_male_pressed() -> void:
	btn_male.button_pressed   = true
	btn_female.button_pressed = false

func _on_btn_female_pressed() -> void:
	btn_female.button_pressed = true
	btn_male.button_pressed   = false

func _on_btn_right_pressed() -> void:
	btn_right.button_pressed = true
	btn_left.button_pressed  = false

func _on_btn_left_pressed() -> void:
	btn_left.button_pressed  = true
	btn_right.button_pressed = false

func _on_btn_create_pressed() -> void:
	var raw_name = name_input.text.strip_edges()
	if raw_name.length() < 2:
		validation_hint.text = "Name must be at least 2 characters."
		return
	# Check for duplicate
	for p in ProfileManager.list_profiles():
		if p.name.to_lower() == raw_name.to_lower():
			validation_hint.text = "A golfer named '%s' already exists." % raw_name
			return

	var profile := {
		"name":         raw_name,
		"sex":          "M" if btn_male.button_pressed else "F",
		"right_handed": btn_right.button_pressed,
		"last_active":  true,
	}
	ProfileManager.save_profile(profile)
	ProfileManager.set_active(raw_name)
	_go_to_course_select()


func _on_btn_cancel_pressed() -> void:
	_show_list()


# ── play ─────────────────────────────────────────────────────────────────

func _on_btn_play_pressed() -> void:
	if _selected < 0 or _selected >= _profiles.size():
		return
	ProfileManager.set_active(_profiles[_selected].name)
	_go_to_course_select()


func _go_to_course_select() -> void:
	get_tree().change_scene_to_file("res://scenes/course_select.tscn")


# ── keyboard nav ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if create_form.visible:
		return   # let form handle its own input
	match event.keycode:
		KEY_UP:
			_select(max(_selected - 1, 0))
		KEY_DOWN:
			_select(min(_selected + 1, _profiles.size() - 1))
		KEY_ENTER, KEY_KP_ENTER:
			_on_btn_play_pressed()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


# ── signal wiring ─────────────────────────────────────────────────────────

func _connect_signals() -> void:
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	btn_new_golfer.pressed.connect(func(): _show_form(true))
	btn_play.pressed.connect(_on_btn_play_pressed)
	btn_male.pressed.connect(_on_btn_male_pressed)
	btn_female.pressed.connect(_on_btn_female_pressed)
	btn_right.pressed.connect(_on_btn_right_pressed)
	btn_left.pressed.connect(_on_btn_left_pressed)
	btn_create.pressed.connect(_on_btn_create_pressed)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)


# ── theme ─────────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	# Play button — bold green
	var play_n = StyleBoxFlat.new()
	play_n.bg_color = Color(0.10, 0.45, 0.10, 1.0)
	play_n.border_color = Color(0.4, 0.85, 0.3, 1.0)
	play_n.set_border_width_all(2); play_n.set_corner_radius_all(8)
	play_n.content_margin_left = 18; play_n.content_margin_right = 18
	var play_h = play_n.duplicate(); play_h.bg_color = Color(0.15, 0.58, 0.15, 1)
	var play_d = play_n.duplicate()
	play_d.bg_color = Color(0.08, 0.18, 0.08, 0.5)
	play_d.border_color = Color(0.25, 0.40, 0.25, 0.35)
	btn_play.add_theme_stylebox_override("normal",   play_n)
	btn_play.add_theme_stylebox_override("hover",    play_h)
	btn_play.add_theme_stylebox_override("disabled", play_d)

	# Toggle buttons (gender + hand) — shared helper
	for btn in [btn_male, btn_female, btn_right, btn_left]:
		_style_toggle(btn)

	# Create button
	var cr_n = play_n.duplicate()
	btn_create.add_theme_stylebox_override("normal", cr_n)
	var cr_h = play_h.duplicate()
	btn_create.add_theme_stylebox_override("hover", cr_h)
	btn_create.add_theme_color_override("font_color", Color(0.95, 1.0, 0.6, 1))

	# New Golfer button
	var new_n = StyleBoxFlat.new()
	new_n.bg_color = Color(0.08, 0.22, 0.30, 1.0)
	new_n.border_color = Color(0.30, 0.65, 0.85, 0.9)
	new_n.set_border_width_all(2); new_n.set_corner_radius_all(8)
	new_n.content_margin_left = 14; new_n.content_margin_right = 14
	var new_h = new_n.duplicate(); new_h.bg_color = Color(0.12, 0.30, 0.40, 1)
	btn_new_golfer.add_theme_stylebox_override("normal", new_n)
	btn_new_golfer.add_theme_stylebox_override("hover",  new_h)
	btn_new_golfer.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0, 1))

	# Name input
	var ni = StyleBoxFlat.new()
	ni.bg_color = Color(0.06, 0.12, 0.06, 1)
	ni.border_color = Color(0.35, 0.55, 0.30, 0.8)
	ni.set_border_width_all(1); ni.set_corner_radius_all(6)
	ni.content_margin_left = 10
	name_input.add_theme_stylebox_override("normal", ni)
	name_input.add_theme_stylebox_override("focus",  ni)
	name_input.add_theme_color_override("font_color",             Color(0.90, 0.95, 0.80, 1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.45, 0.58, 0.42, 0.8))
	name_input.add_theme_font_size_override("font_size", 18)


func _style_toggle(btn: Button) -> void:
	var on_s = StyleBoxFlat.new()
	on_s.bg_color = Color(0.15, 0.42, 0.15, 1); on_s.border_color = Color(0.45, 0.85, 0.35, 1)
	on_s.set_border_width_all(2); on_s.set_corner_radius_all(7)
	var off_s = StyleBoxFlat.new()
	off_s.bg_color = Color(0.08, 0.14, 0.08, 1); off_s.border_color = Color(0.28, 0.45, 0.25, 0.6)
	off_s.set_border_width_all(1); off_s.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("pressed", on_s)
	btn.add_theme_stylebox_override("normal",  off_s)
	btn.add_theme_stylebox_override("hover",   off_s)
	btn.add_theme_color_override("font_color",         Color(0.88, 0.95, 0.75, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.60, 1))
