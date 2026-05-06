extends CanvasLayer

signal shot_confirmed(power: float, accuracy: float, draw_fade: float, loft: float, club: Dictionary)

const CLUBS = [
	{"name": "Driver", "full_yards": 300},
	{"name": "3W", "full_yards": 260},
	{"name": "5W", "full_yards": 240},
	{"name": "4I", "full_yards": 220},
	{"name": "5I", "full_yards": 205},
	{"name": "6I", "full_yards": 190},
	{"name": "7I", "full_yards": 175},
	{"name": "8I", "full_yards": 160},
	{"name": "9I", "full_yards": 145},
	{"name": "PW", "full_yards": 130},
	{"name": "GW", "full_yards": 115},
	{"name": "SW", "full_yards": 95},
	{"name": "LW", "full_yards": 75},
	{"name": "Putter", "full_yards": 30},
]

var selected_club_index := 0
var club_labels: Array[Label] = []
var selected_club_label: Label

enum MeterState { IDLE, POWER, ACCURACY, DONE }
var state := MeterState.IDLE
var meter_value := 0.0
var meter_speed := 0.53  # normal shot speed - 1/3 slower than before
var power := 0.0
var accuracy := 0.0
var draw_fade := 0.0
var loft := 0.0

var meter_bar: ColorRect
var meter_fill: ColorRect
var power_marker: ColorRect
var click_hint: Label
var power_label: Label
var draw_slider: HSlider
var loft_slider: HSlider
var ball_image: TextureRect
var draw_label: Label
var loft_label: Label

# Layout constants - right side panel
const PANEL_LEFT  := 0.62
const PANEL_RIGHT := 1.00
const PANEL_TOP   := 0.00
const PANEL_BOT   := 1.00
# Meter within the panel (in screen space)
const METER_L := 0.635
const METER_R := 0.675
const METER_T := 0.22
const METER_B := 0.65

func _ready():
	layer = 10
	visible = false
	_build_ui()

func _build_ui():
	# Ball indicator (white = normal, yellow = putting)
	ball_image = TextureRect.new()
	ball_image.name = "BallImage"
	ball_image.set_anchor(SIDE_LEFT, 0.915)
	ball_image.set_anchor(SIDE_TOP, 0.02)
	ball_image.set_anchor(SIDE_RIGHT, 0.975)
	ball_image.set_anchor(SIDE_BOTTOM, 0.09)
	ball_image.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	ball_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ball_tex = load("res://assets/ball_white.png")
	if ball_tex:
		ball_image.texture = ball_tex
	add_child(ball_image)

	# Semi-transparent right side panel only - course still visible on left
	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	panel.set_anchor(SIDE_TOP,   PANEL_TOP)
	panel.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	panel.set_anchor(SIDE_BOTTOM,PANEL_BOT)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.0)
	ps.border_color = Color(0.6, 0.6, 0.4, 0.3)
	ps.border_width_left = 2
	ps.border_width_top = 0
	ps.border_width_right = 0
	ps.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Title
	var title = Label.new()
	title.text = "ADDRESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	title.set_anchor(SIDE_TOP,   0.02)
	title.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	title.set_anchor(SIDE_BOTTOM,0.07)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 0.6, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 4)
	add_child(title)
	meter_bar = ColorRect.new()
	meter_bar.color = Color(0.15, 0.15, 0.15, 1.0)
	meter_bar.set_anchor(SIDE_LEFT,  METER_L)
	meter_bar.set_anchor(SIDE_TOP,   METER_T)
	meter_bar.set_anchor(SIDE_RIGHT, METER_R)
	meter_bar.set_anchor(SIDE_BOTTOM,METER_B)
	add_child(meter_bar)

	# Meter fill
	meter_fill = ColorRect.new()
	meter_fill.color = Color(0.2, 0.85, 0.2, 1.0)
	meter_fill.set_anchor(SIDE_LEFT,  METER_L)
	meter_fill.set_anchor(SIDE_TOP,   METER_B)
	meter_fill.set_anchor(SIDE_RIGHT, METER_R)
	meter_fill.set_anchor(SIDE_BOTTOM,METER_B)
	add_child(meter_fill)

	# Power marker
	power_marker = ColorRect.new()
	power_marker.color = Color(1.0, 0.9, 0.1, 1.0)
	power_marker.set_anchor(SIDE_LEFT,  METER_L - 0.005)
	power_marker.set_anchor(SIDE_RIGHT, METER_R + 0.005)
	power_marker.set_anchor(SIDE_TOP,   METER_B)
	power_marker.set_anchor(SIDE_BOTTOM,METER_B + 0.004)
	power_marker.visible = false
	add_child(power_marker)

	# Meter % labels
	for pct in [100, 75, 50, 25]:
		var lbl = Label.new()
		lbl.text = "%d" % pct
		var anchor_y = METER_B - (pct / 100.0) * (METER_B - METER_T)
		lbl.set_anchor(SIDE_LEFT,  METER_R + 0.005)
		lbl.set_anchor(SIDE_TOP,   anchor_y - 0.015)
		lbl.set_anchor(SIDE_RIGHT, METER_R + 0.04)
		lbl.set_anchor(SIDE_BOTTOM,anchor_y + 0.015)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		add_child(lbl)

	# Click hint
	click_hint = Label.new()
	click_hint.text = "CLICK to start"
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_hint.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	click_hint.set_anchor(SIDE_TOP,   0.66)
	click_hint.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	click_hint.set_anchor(SIDE_BOTTOM,0.71)
	click_hint.add_theme_font_size_override("font_size", 14)
	click_hint.add_theme_color_override("font_color", Color(1, 1, 0.3, 1))
	click_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	click_hint.add_theme_constant_override("outline_size", 4)
	add_child(click_hint)

	# Power/status label
	power_label = Label.new()
	power_label.text = ""
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	power_label.set_anchor(SIDE_TOP,   0.71)
	power_label.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	power_label.set_anchor(SIDE_BOTTOM,0.76)
	power_label.add_theme_font_size_override("font_size", 13)
	power_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	power_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	power_label.add_theme_constant_override("outline_size", 3)
	add_child(power_label)

	# Club bag — single vertical list, Tab to cycle
	var bag_title = Label.new()
	bag_title.text = "— CLUB BAG —"
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_title.set_anchor(SIDE_LEFT,  0.63)
	bag_title.set_anchor(SIDE_TOP,   0.02)
	bag_title.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	bag_title.set_anchor(SIDE_BOTTOM,0.07)
	bag_title.add_theme_font_size_override("font_size", 13)
	bag_title.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	bag_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	bag_title.add_theme_constant_override("outline_size", 3)
	add_child(bag_title)

	var club_list = VBoxContainer.new()
	club_list.name = "ClubList"
	club_list.set_anchor(SIDE_LEFT,  0.63)
	club_list.set_anchor(SIDE_TOP,   0.07)
	club_list.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	club_list.set_anchor(SIDE_BOTTOM,0.77)
	club_list.add_theme_constant_override("separation", 1)
	add_child(club_list)

	for i in CLUBS.size():
		var club = CLUBS[i]
		var label = Label.new()
		label.text = "  %s  %dy" % [club["name"], club["full_yards"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		club_list.add_child(label)
		club_labels.append(label)

	# Large selected club readout above the meter
	selected_club_label = Label.new()
	selected_club_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_club_label.set_anchor(SIDE_LEFT,  METER_L - 0.04)
	selected_club_label.set_anchor(SIDE_TOP,   0.10)
	selected_club_label.set_anchor(SIDE_RIGHT, METER_R + 0.04)
	selected_club_label.set_anchor(SIDE_BOTTOM,0.20)
	selected_club_label.add_theme_font_size_override("font_size", 14)
	selected_club_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1))
	selected_club_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	selected_club_label.add_theme_constant_override("outline_size", 4)
	add_child(selected_club_label)

	# Draw/fade label and slider (A/D keys)
	draw_label = Label.new()
	draw_label.text = "A/D: Straight"
	draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_label.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	draw_label.set_anchor(SIDE_TOP,   0.77)
	draw_label.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	draw_label.set_anchor(SIDE_BOTTOM,0.81)
	draw_label.add_theme_font_size_override("font_size", 13)
	draw_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8, 1))
	draw_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	draw_label.add_theme_constant_override("outline_size", 4)
	add_child(draw_label)

	draw_slider = HSlider.new()
	draw_slider.min_value = -1.0
	draw_slider.max_value = 1.0
	draw_slider.step = 0.05
	draw_slider.value = 0.0
	draw_slider.set_anchor(SIDE_LEFT,  PANEL_LEFT + 0.02)
	draw_slider.set_anchor(SIDE_TOP,   0.82)
	draw_slider.set_anchor(SIDE_RIGHT, PANEL_RIGHT - 0.01)
	draw_slider.set_anchor(SIDE_BOTTOM,0.86)
	draw_slider.connect("value_changed", _on_draw_changed)
	add_child(draw_slider)

	# Loft label and slider (W/S keys)
	loft_label = Label.new()
	loft_label.text = "W/S: Mid Loft"
	loft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loft_label.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	loft_label.set_anchor(SIDE_TOP,   0.87)
	loft_label.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	loft_label.set_anchor(SIDE_BOTTOM,0.91)
	loft_label.add_theme_font_size_override("font_size", 13)
	loft_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8, 1))
	loft_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	loft_label.add_theme_constant_override("outline_size", 4)
	add_child(loft_label)

	loft_slider = HSlider.new()
	loft_slider.min_value = -1.0
	loft_slider.max_value = 1.0
	loft_slider.step = 0.05
	loft_slider.value = 0.0
	loft_slider.set_anchor(SIDE_LEFT,  PANEL_LEFT + 0.02)
	loft_slider.set_anchor(SIDE_TOP,   0.91)
	loft_slider.set_anchor(SIDE_RIGHT, PANEL_RIGHT - 0.01)
	loft_slider.set_anchor(SIDE_BOTTOM,0.95)
	loft_slider.connect("value_changed", _on_loft_changed)
	add_child(loft_slider)

	# ESC hint
	var esc_hint = Label.new()
	esc_hint.text = "ESC = cancel"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_hint.set_anchor(SIDE_LEFT,  PANEL_LEFT)
	esc_hint.set_anchor(SIDE_TOP,   0.96)
	esc_hint.set_anchor(SIDE_RIGHT, PANEL_RIGHT)
	esc_hint.set_anchor(SIDE_BOTTOM,1.00)
	esc_hint.add_theme_font_size_override("font_size", 11)
	esc_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	add_child(esc_hint)

	_update_club_highlight()

func _on_draw_changed(val): draw_fade = val
func _on_loft_changed(val): loft = val

func open_screen():
	visible = true
	state = MeterState.IDLE
	meter_value = 0.0
	power = 0.0
	accuracy = 0.0
	power_marker.visible = false
	click_hint.text = "CLICK to start"
	power_label.text = ""
	_update_meter_visual(0.0)
	_update_club_highlight()
	_update_slider_labels()

func close_screen():
	visible = false
	state = MeterState.IDLE

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				if event.shift_pressed:
					_select_previous_club()
				else:
					_select_next_club()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				draw_fade = clamp(draw_fade - 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				draw_fade = clamp(draw_fade + 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_UP, KEY_W:
				loft = clamp(loft + 0.1, -1.0, 1.0)
				loft_slider.value = loft
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				loft = clamp(loft - 0.1, -1.0, 1.0)
				loft_slider.value = loft
				_update_slider_labels()
				get_viewport().set_input_as_handled()

func _select_next_club():
	selected_club_index = (selected_club_index + 1) % CLUBS.size()
	_update_club_highlight()

func _select_previous_club():
	selected_club_index = (selected_club_index - 1 + CLUBS.size()) % CLUBS.size()
	_update_club_highlight()

func select_club(index: int):
	selected_club_index = clamp(index, 0, CLUBS.size() - 1)
	_update_club_highlight()

func _update_club_highlight():
	for i in club_labels.size():
		var label = club_labels[i]
		var club = CLUBS[i]
		if i == selected_club_index:
			label.text = "▶ %s  %dy" % [club["name"], club["full_yards"]]
			label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2, 1))
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			label.add_theme_constant_override("outline_size", 3)
		else:
			label.text = "  %s  %dy" % [club["name"], club["full_yards"]]
			label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_constant_override("outline_size", 0)
	var club = CLUBS[selected_club_index]
	if selected_club_label:
		selected_club_label.text = "%s  %dy" % [club["name"], club["full_yards"]]

func _update_slider_labels():
	var draw_text = "Straight"
	if draw_fade < -0.15:
		draw_text = "Draw %d%%" % int(abs(draw_fade) * 100)
	elif draw_fade > 0.15:
		draw_text = "Fade %d%%" % int(draw_fade * 100)
	var loft_text = "Mid Loft"
	if loft > 0.15:
		loft_text = "Hi Loft %d%%" % int(loft * 100)
	elif loft < -0.15:
		loft_text = "Lo Loft %d%%" % int(abs(loft) * 100)
	if draw_label:
		draw_label.text = "A/D: " + draw_text
	if loft_label:
		loft_label.text = "W/S: " + loft_text

func _handle_click():
	match state:
		MeterState.IDLE:
			state = MeterState.POWER
			meter_value = 0.0
			click_hint.text = "CLICK — set power"
		MeterState.POWER:
			power = meter_value
			state = MeterState.ACCURACY
			meter_value = 0.0
			power_label.text = "Power: %d%%" % int(power * 100)
			click_hint.text = "CLICK — accuracy"
			power_marker.visible = true
		MeterState.ACCURACY:
			accuracy = 1.0 - abs(meter_value - power)
			accuracy = clamp(accuracy, 0.0, 1.0)
			state = MeterState.DONE
			click_hint.text = ""
			emit_signal("shot_confirmed", power, accuracy, draw_fade, loft, CLUBS[selected_club_index])

func _process(delta):
	if not visible:
		return
	if state == MeterState.POWER or state == MeterState.ACCURACY:
		meter_value = fmod(meter_value + meter_speed * delta, 1.0)
		_update_meter_visual(meter_value)
		if meter_value > 0.85:
			meter_fill.color = Color(0.9, 0.2, 0.1, 1.0)
		elif meter_value > 0.65:
			meter_fill.color = Color(0.9, 0.75, 0.1, 1.0)
		else:
			meter_fill.color = Color(0.2, 0.85, 0.2, 1.0)

func _update_meter_visual(val: float):
	var screen_h = get_viewport().get_visible_rect().size.y
	var screen_w = get_viewport().get_visible_rect().size.x
	var bar_top    = screen_h * METER_T
	var bar_bottom = screen_h * METER_B
	var bar_left   = screen_w * METER_L
	var bar_right  = screen_w * METER_R
	var bar_h  = bar_bottom - bar_top
	var fill_h = bar_h * val
	meter_bar.position  = Vector2(bar_left, bar_top)
	meter_bar.size      = Vector2(bar_right - bar_left, bar_h)
	meter_fill.position = Vector2(bar_left, bar_bottom - fill_h)
	meter_fill.size     = Vector2(bar_right - bar_left, max(fill_h, 1))
	if power_marker.visible:
		var marker_y = bar_bottom - (bar_h * power)
		power_marker.position = Vector2(bar_left - 4, marker_y - 2)
		power_marker.size     = Vector2(bar_right - bar_left + 8, 4)

func set_putting_mode(enabled: bool, stimp: float = 8.0):
	if enabled:
		for i in range(CLUBS.size()):
			if CLUBS[i].name == "Putter":
				selected_club_index = i
				break
		meter_speed = 0.22 + (stimp / 13.0) * 0.15  # stimp 8 = ~0.31 putting speed
		if draw_slider: draw_slider.visible = false
		if selected_club_label:
			selected_club_label.text = "Putter  Stimp:%.0f" % stimp
		# Show yellow ball for putting
		if ball_image:
			var tex = load("res://assets/ball_yellow.png")
			if tex: ball_image.texture = tex
	else:
		meter_speed = 0.53  # restore normal shot speed
		if draw_slider: draw_slider.visible = true
		_update_club_highlight()
		# Restore white ball
		if ball_image:
			var tex = load("res://assets/ball_white.png")
			if tex: ball_image.texture = tex
