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
var meter_speed := 0.8
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

func _ready():
	layer = 10
	visible = false
	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT, 0.20)
	panel.set_anchor(SIDE_TOP, 0.07)
	panel.set_anchor(SIDE_RIGHT, 0.82)
	panel.set_anchor(SIDE_BOTTOM, 0.94)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	ps.border_color = Color(0.8, 0.8, 0.8, 0.6)
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

	var title = Label.new()
	title.text = "ADDRESS THE BALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchor(SIDE_LEFT, 0.20)
	title.set_anchor(SIDE_TOP, 0.09)
	title.set_anchor(SIDE_RIGHT, 0.82)
	title.set_anchor(SIDE_BOTTOM, 0.14)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(title)

	# Club bag display, full-meter yardage shown for every club.
	var bag_title = Label.new()
	bag_title.text = "CLUB BAG  (Tab / Shift+Tab)"
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_title.set_anchor(SIDE_LEFT, 0.61)
	bag_title.set_anchor(SIDE_TOP, 0.17)
	bag_title.set_anchor(SIDE_RIGHT, 0.80)
	bag_title.set_anchor(SIDE_BOTTOM, 0.21)
	bag_title.add_theme_font_size_override("font_size", 14)
	bag_title.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	add_child(bag_title)

	var club_grid = GridContainer.new()
	club_grid.columns = 2
	club_grid.set_anchor(SIDE_LEFT, 0.61)
	club_grid.set_anchor(SIDE_TOP, 0.22)
	club_grid.set_anchor(SIDE_RIGHT, 0.80)
	club_grid.set_anchor(SIDE_BOTTOM, 0.78)
	club_grid.add_theme_constant_override("h_separation", 6)
	club_grid.add_theme_constant_override("v_separation", 5)
	add_child(club_grid)

	for i in CLUBS.size():
		var club = CLUBS[i]
		var label = Label.new()
		label.text = "%s  %dy" % [club["name"], club["full_yards"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(82, 25)
		label.add_theme_font_size_override("font_size", 13)
		club_grid.add_child(label)
		club_labels.append(label)

	selected_club_label = Label.new()
	selected_club_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_club_label.set_anchor(SIDE_LEFT, 0.60)
	selected_club_label.set_anchor(SIDE_TOP, 0.80)
	selected_club_label.set_anchor(SIDE_RIGHT, 0.81)
	selected_club_label.set_anchor(SIDE_BOTTOM, 0.86)
	selected_club_label.add_theme_font_size_override("font_size", 18)
	selected_club_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1))
	add_child(selected_club_label)

	meter_bar = ColorRect.new()
	meter_bar.color = Color(0.15, 0.15, 0.15, 1.0)
	meter_bar.set_anchor(SIDE_LEFT, 0.43)
	meter_bar.set_anchor(SIDE_TOP, 0.19)
	meter_bar.set_anchor(SIDE_RIGHT, 0.49)
	meter_bar.set_anchor(SIDE_BOTTOM, 0.60)
	add_child(meter_bar)

	meter_fill = ColorRect.new()
	meter_fill.color = Color(0.2, 0.85, 0.2, 1.0)
	meter_fill.set_anchor(SIDE_LEFT, 0.43)
	meter_fill.set_anchor(SIDE_TOP, 0.60)
	meter_fill.set_anchor(SIDE_RIGHT, 0.49)
	meter_fill.set_anchor(SIDE_BOTTOM, 0.60)
	add_child(meter_fill)

	power_marker = ColorRect.new()
	power_marker.color = Color(1.0, 0.9, 0.1, 1.0)
	power_marker.set_anchor(SIDE_LEFT, 0.42)
	power_marker.set_anchor(SIDE_RIGHT, 0.50)
	power_marker.set_anchor(SIDE_TOP, 0.60)
	power_marker.set_anchor(SIDE_BOTTOM, 0.602)
	power_marker.visible = false
	add_child(power_marker)

	click_hint = Label.new()
	click_hint.text = "CLICK to start swing"
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_hint.set_anchor(SIDE_LEFT, 0.25)
	click_hint.set_anchor(SIDE_TOP, 0.62)
	click_hint.set_anchor(SIDE_RIGHT, 0.56)
	click_hint.set_anchor(SIDE_BOTTOM, 0.67)
	click_hint.add_theme_font_size_override("font_size", 16)
	click_hint.add_theme_color_override("font_color", Color(1, 1, 0.3, 1))
	add_child(click_hint)

	power_label = Label.new()
	power_label.text = ""
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.set_anchor(SIDE_LEFT, 0.25)
	power_label.set_anchor(SIDE_TOP, 0.67)
	power_label.set_anchor(SIDE_RIGHT, 0.56)
	power_label.set_anchor(SIDE_BOTTOM, 0.72)
	power_label.add_theme_font_size_override("font_size", 16)
	power_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(power_label)

	var draw_label = Label.new()
	draw_label.text = "< LEFT = Draw  |  RIGHT = Fade >"
	draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_label.set_anchor(SIDE_LEFT, 0.24)
	draw_label.set_anchor(SIDE_TOP, 0.73)
	draw_label.set_anchor(SIDE_RIGHT, 0.57)
	draw_label.set_anchor(SIDE_BOTTOM, 0.77)
	draw_label.add_theme_font_size_override("font_size", 13)
	draw_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	add_child(draw_label)

	draw_slider = HSlider.new()
	draw_slider.min_value = -1.0
	draw_slider.max_value = 1.0
	draw_slider.step = 0.05
	draw_slider.value = 0.0
	draw_slider.set_anchor(SIDE_LEFT, 0.27)
	draw_slider.set_anchor(SIDE_TOP, 0.78)
	draw_slider.set_anchor(SIDE_RIGHT, 0.54)
	draw_slider.set_anchor(SIDE_BOTTOM, 0.83)
	draw_slider.connect("value_changed", _on_draw_changed)
	add_child(draw_slider)

	var loft_label = Label.new()
	loft_label.text = "UP = High Loft  |  DOWN = Low Loft"
	loft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loft_label.set_anchor(SIDE_LEFT, 0.24)
	loft_label.set_anchor(SIDE_TOP, 0.84)
	loft_label.set_anchor(SIDE_RIGHT, 0.57)
	loft_label.set_anchor(SIDE_BOTTOM, 0.88)
	loft_label.add_theme_font_size_override("font_size", 13)
	loft_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	add_child(loft_label)

	loft_slider = HSlider.new()
	loft_slider.min_value = -1.0
	loft_slider.max_value = 1.0
	loft_slider.step = 0.05
	loft_slider.value = 0.0
	loft_slider.set_anchor(SIDE_LEFT, 0.27)
	loft_slider.set_anchor(SIDE_TOP, 0.88)
	loft_slider.set_anchor(SIDE_RIGHT, 0.54)
	loft_slider.set_anchor(SIDE_BOTTOM, 0.93)
	loft_slider.connect("value_changed", _on_loft_changed)
	add_child(loft_slider)

	var esc_hint = Label.new()
	esc_hint.text = "ESC to cancel"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_hint.set_anchor(SIDE_LEFT, 0.20)
	esc_hint.set_anchor(SIDE_TOP, 0.94)
	esc_hint.set_anchor(SIDE_RIGHT, 0.82)
	esc_hint.set_anchor(SIDE_BOTTOM, 0.98)
	esc_hint.add_theme_font_size_override("font_size", 12)
	esc_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	add_child(esc_hint)

	_update_club_highlight()

func _on_draw_changed(val):
	draw_fade = val

func _on_loft_changed(val):
	loft = val

func open_screen():
	visible = true
	state = MeterState.IDLE
	meter_value = 0.0
	power = 0.0
	accuracy = 0.0
	power_marker.visible = false
	click_hint.text = "CLICK to start swing"
	power_label.text = ""
	_update_meter_visual(0.0)
	_update_club_highlight()

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
			KEY_LEFT:
				draw_fade = clamp(draw_fade - 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				draw_fade = clamp(draw_fade + 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_UP:
				loft = clamp(loft + 0.1, -1.0, 1.0)
				loft_slider.value = loft
				_update_slider_labels()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
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

func _update_club_highlight():
	for i in club_labels.size():
		var label = club_labels[i]
		if i == selected_club_index:
			label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1))
			label.add_theme_color_override("font_outline_color", Color(1, 1, 0.25, 1))
			label.add_theme_constant_override("outline_size", 8)
			label.add_theme_font_size_override("font_size", 15)
		else:
			label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
			label.add_theme_constant_override("outline_size", 0)
			label.add_theme_font_size_override("font_size", 13)
	var club = CLUBS[selected_club_index]
	if selected_club_label:
		selected_club_label.text = "Selected: %s  %dy" % [club["name"], club["full_yards"]]

func _update_slider_labels():
	var draw_text = "STRAIGHT"
	if draw_fade < -0.15:
		draw_text = "DRAW %d%%" % int(abs(draw_fade) * 100)
	elif draw_fade > 0.15:
		draw_text = "FADE %d%%" % int(draw_fade * 100)
	var loft_text = "MID LOFT"
	if loft > 0.15:
		loft_text = "HIGH LOFT %d%%" % int(loft * 100)
	elif loft < -0.15:
		loft_text = "LOW LOFT %d%%" % int(abs(loft) * 100)
	power_label.text = draw_text + "  |  " + loft_text

func _handle_click():
	match state:
		MeterState.IDLE:
			state = MeterState.POWER
			meter_value = 0.0
			click_hint.text = "CLICK to set power"
		MeterState.POWER:
			power = meter_value
			state = MeterState.ACCURACY
			meter_value = 0.0
			power_label.text = "Power: %d%%" % int(power * 100)
			click_hint.text = "CLICK for accuracy"
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
	var bar_top = screen_h * 0.19
	var bar_bottom = screen_h * 0.60
	var bar_left = screen_w * 0.43
	var bar_right = screen_w * 0.49
	var bar_h = bar_bottom - bar_top
	var fill_h = bar_h * val
	meter_bar.position = Vector2(bar_left, bar_top)
	meter_bar.size = Vector2(bar_right - bar_left, bar_h)
	meter_fill.position = Vector2(bar_left, bar_bottom - fill_h)
	meter_fill.size = Vector2(bar_right - bar_left, fill_h)
	if power_marker.visible:
		var marker_y = bar_bottom - (bar_h * power)
		power_marker.position = Vector2(bar_left - 4, marker_y - 2)
		power_marker.size = Vector2(bar_right - bar_left + 8, 4)
