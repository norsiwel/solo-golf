extends CanvasLayer

signal shot_confirmed(power: float, accuracy: float, draw_fade: float, loft: float)

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
	panel.set_anchor(SIDE_LEFT, 0.35)
	panel.set_anchor(SIDE_TOP, 0.1)
	panel.set_anchor(SIDE_RIGHT, 0.65)
	panel.set_anchor(SIDE_BOTTOM, 0.88)
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
	title.set_anchor(SIDE_LEFT, 0.35)
	title.set_anchor(SIDE_TOP, 0.12)
	title.set_anchor(SIDE_RIGHT, 0.65)
	title.set_anchor(SIDE_BOTTOM, 0.17)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(title)

	meter_bar = ColorRect.new()
	meter_bar.color = Color(0.15, 0.15, 0.15, 1.0)
	meter_bar.set_anchor(SIDE_LEFT, 0.47)
	meter_bar.set_anchor(SIDE_TOP, 0.19)
	meter_bar.set_anchor(SIDE_RIGHT, 0.53)
	meter_bar.set_anchor(SIDE_BOTTOM, 0.60)
	add_child(meter_bar)

	meter_fill = ColorRect.new()
	meter_fill.color = Color(0.2, 0.85, 0.2, 1.0)
	meter_fill.set_anchor(SIDE_LEFT, 0.47)
	meter_fill.set_anchor(SIDE_TOP, 0.60)
	meter_fill.set_anchor(SIDE_RIGHT, 0.53)
	meter_fill.set_anchor(SIDE_BOTTOM, 0.60)
	add_child(meter_fill)

	power_marker = ColorRect.new()
	power_marker.color = Color(1.0, 0.9, 0.1, 1.0)
	power_marker.set_anchor(SIDE_LEFT, 0.46)
	power_marker.set_anchor(SIDE_RIGHT, 0.54)
	power_marker.set_anchor(SIDE_TOP, 0.60)
	power_marker.set_anchor(SIDE_BOTTOM, 0.602)
	power_marker.visible = false
	add_child(power_marker)

	click_hint = Label.new()
	click_hint.text = "CLICK to start swing"
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_hint.set_anchor(SIDE_LEFT, 0.35)
	click_hint.set_anchor(SIDE_TOP, 0.62)
	click_hint.set_anchor(SIDE_RIGHT, 0.65)
	click_hint.set_anchor(SIDE_BOTTOM, 0.67)
	click_hint.add_theme_font_size_override("font_size", 16)
	click_hint.add_theme_color_override("font_color", Color(1, 1, 0.3, 1))
	add_child(click_hint)

	power_label = Label.new()
	power_label.text = ""
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.set_anchor(SIDE_LEFT, 0.35)
	power_label.set_anchor(SIDE_TOP, 0.67)
	power_label.set_anchor(SIDE_RIGHT, 0.65)
	power_label.set_anchor(SIDE_BOTTOM, 0.72)
	power_label.add_theme_font_size_override("font_size", 16)
	power_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(power_label)

	var draw_label = Label.new()
	draw_label.text = "< LEFT = Draw  |  RIGHT = Fade >"
	draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_label.set_anchor(SIDE_LEFT, 0.35)
	draw_label.set_anchor(SIDE_TOP, 0.73)
	draw_label.set_anchor(SIDE_RIGHT, 0.65)
	draw_label.set_anchor(SIDE_BOTTOM, 0.77)
	draw_label.add_theme_font_size_override("font_size", 13)
	draw_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	add_child(draw_label)

	draw_slider = HSlider.new()
	draw_slider.min_value = -1.0
	draw_slider.max_value = 1.0
	draw_slider.step = 0.05
	draw_slider.value = 0.0
	draw_slider.set_anchor(SIDE_LEFT, 0.37)
	draw_slider.set_anchor(SIDE_TOP, 0.78)
	draw_slider.set_anchor(SIDE_RIGHT, 0.63)
	draw_slider.set_anchor(SIDE_BOTTOM, 0.83)
	draw_slider.connect("value_changed", _on_draw_changed)
	add_child(draw_slider)

	var loft_label = Label.new()
	loft_label.text = "UP = High Loft  |  DOWN = Low Loft"
	loft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loft_label.set_anchor(SIDE_LEFT, 0.37)
	loft_label.set_anchor(SIDE_TOP, 0.84)
	loft_label.set_anchor(SIDE_RIGHT, 0.63)
	loft_label.set_anchor(SIDE_BOTTOM, 0.88)
	loft_label.add_theme_font_size_override("font_size", 13)
	loft_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	add_child(loft_label)

	loft_slider = HSlider.new()
	loft_slider.min_value = -1.0
	loft_slider.max_value = 1.0
	loft_slider.step = 0.05
	loft_slider.value = 0.0
	loft_slider.set_anchor(SIDE_LEFT, 0.37)
	loft_slider.set_anchor(SIDE_TOP, 0.88)
	loft_slider.set_anchor(SIDE_RIGHT, 0.63)
	loft_slider.set_anchor(SIDE_BOTTOM, 0.93)
	loft_slider.connect("value_changed", _on_loft_changed)
	add_child(loft_slider)

	var esc_hint = Label.new()
	esc_hint.text = "ESC to cancel"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_hint.set_anchor(SIDE_LEFT, 0.35)
	esc_hint.set_anchor(SIDE_TOP, 0.94)
	esc_hint.set_anchor(SIDE_RIGHT, 0.65)
	esc_hint.set_anchor(SIDE_BOTTOM, 0.98)
	esc_hint.add_theme_font_size_override("font_size", 12)
	esc_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	add_child(esc_hint)

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

func close_screen():
	visible = false
	state = MeterState.IDLE

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click()
	# Arrow keys for draw/fade and loft
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				draw_fade = clamp(draw_fade - 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
			KEY_RIGHT:
				draw_fade = clamp(draw_fade + 0.1, -1.0, 1.0)
				draw_slider.value = draw_fade
				_update_slider_labels()
			KEY_UP:
				loft = clamp(loft + 0.1, -1.0, 1.0)
				loft_slider.value = loft
				_update_slider_labels()
			KEY_DOWN:
				loft = clamp(loft - 0.1, -1.0, 1.0)
				loft_slider.value = loft
				_update_slider_labels()

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
			emit_signal("shot_confirmed", power, accuracy, draw_fade, loft)

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
	# Use pixel positions instead of anchors for reliable animation
	var screen_h = get_viewport().get_visible_rect().size.y
	var screen_w = get_viewport().get_visible_rect().size.x
	var bar_top = screen_h * 0.19
	var bar_bottom = screen_h * 0.60
	var bar_left = screen_w * 0.47
	var bar_right = screen_w * 0.53
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
