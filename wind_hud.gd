extends CanvasLayer

var wind_dir := Vector3.ZERO
var wind_speed := 0.0
var wind_control: Control
var speed_label: Label
var desc_label: Label

func _ready():
	layer = 5
	_build_ui()
	call_deferred("_connect_wind")

func _connect_wind():
	var wind = get_tree().current_scene.get_node_or_null("WindSystem")
	if wind:
		wind.connect("wind_changed", _on_wind_changed)
		_on_wind_changed(wind.wind_direction, wind.wind_speed_mph)

func _build_ui():
	# Container panel top-left
	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT,   0.0)
	panel.set_anchor(SIDE_TOP,    0.0)
	panel.set_anchor(SIDE_RIGHT,  0.16)
	panel.set_anchor(SIDE_BOTTOM, 0.13)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.55)
	ps.border_color = Color(0.5, 0.7, 1.0, 0.5)
	ps.border_width_bottom = 1
	ps.border_width_right = 1
	ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Custom drawn arrow control
	wind_control = WindArrow.new()
	wind_control.set_anchor(SIDE_LEFT,   0.0)
	wind_control.set_anchor(SIDE_TOP,    0.0)
	wind_control.set_anchor(SIDE_RIGHT,  0.08)
	wind_control.set_anchor(SIDE_BOTTOM, 0.13)
	add_child(wind_control)

	# Speed label
	speed_label = Label.new()
	speed_label.text = "-- mph"
	speed_label.set_anchor(SIDE_LEFT,   0.08)
	speed_label.set_anchor(SIDE_TOP,    0.005)
	speed_label.set_anchor(SIDE_RIGHT,  0.16)
	speed_label.set_anchor(SIDE_BOTTOM, 0.065)
	speed_label.add_theme_font_size_override("font_size", 15)
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(speed_label)

	# Description label
	desc_label = Label.new()
	desc_label.text = "CALM"
	desc_label.set_anchor(SIDE_LEFT,   0.08)
	desc_label.set_anchor(SIDE_TOP,    0.065)
	desc_label.set_anchor(SIDE_RIGHT,  0.16)
	desc_label.set_anchor(SIDE_BOTTOM, 0.125)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1))
	add_child(desc_label)

func _on_wind_changed(direction: Vector3, speed_mph: float):
	wind_dir = direction
	wind_speed = speed_mph
	if wind_control:
		wind_control.wind_dir = direction
		wind_control.wind_speed = speed_mph
		wind_control.queue_redraw()
	_update_labels()

func _update_labels():
	if speed_label:
		if wind_speed < 1.0:
			speed_label.text = "CALM"
		else:
			speed_label.text = "%.0f mph" % wind_speed
	if desc_label:
		if wind_speed < 2:
			desc_label.text = ""
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
		elif wind_speed < 8:
			desc_label.text = "Light"
			desc_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		elif wind_speed < 15:
			desc_label.text = "Moderate"
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
		elif wind_speed < 22:
			desc_label.text = "Strong"
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1))
		else:
			desc_label.text = "GALE!"
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1))

# Inner class - draws the wind arrow directly
class WindArrow extends Control:
	var wind_dir := Vector3.ZERO
	var wind_speed := 0.0

	func _draw():
		var center = size / 2.0
		var max_len = min(size.x, size.y) * 0.42

		if wind_speed < 1.0:
			# Calm - draw a small circle
			draw_arc(center, max_len * 0.25, 0, TAU, 16, Color(0.5, 0.5, 0.5, 0.6), 2.0)
			return

		# Map wind direction to screen space
		# wind_dir.x = left/right on screen, wind_dir.z = away/toward camera
		# We show where wind is PUSHING the ball (opposite of wind source)
		var screen_x = wind_dir.x
		var screen_y = -wind_dir.z   # negative because forward is -z in Godot

		var arrow_dir = Vector2(screen_x, screen_y).normalized()

		# Arrow length scales with wind speed (max at 25mph)
		var strength = clamp(wind_speed / 25.0, 0.1, 1.0)
		var arrow_len = max_len * (0.3 + strength * 0.7)

		var tip = center + arrow_dir * arrow_len
		var tail = center - arrow_dir * arrow_len * 0.4

		# Color by strength
		var col: Color
		if wind_speed < 8:
			col = Color(0.4, 1.0, 0.4, 1.0)
		elif wind_speed < 15:
			col = Color(1.0, 0.9, 0.2, 1.0)
		elif wind_speed < 22:
			col = Color(1.0, 0.5, 0.1, 1.0)
		else:
			col = Color(1.0, 0.15, 0.15, 1.0)

		# Line width scales with strength too
		var line_w = 2.0 + strength * 3.0

		# Draw shaft
		draw_line(tail, tip, col, line_w, true)

		# Draw arrowhead
		var perp = Vector2(-arrow_dir.y, arrow_dir.x)
		var head_size = 6.0 + strength * 6.0
		var left_wing  = tip - arrow_dir * head_size + perp * head_size * 0.5
		var right_wing = tip - arrow_dir * head_size - perp * head_size * 0.5
		draw_line(tip, left_wing,  col, line_w, true)
		draw_line(tip, right_wing, col, line_w, true)

		# Draw tail feathers for strong wind
		if wind_speed > 10:
			var feather_pos = tail + arrow_dir * arrow_len * 0.15
			draw_line(feather_pos, feather_pos + perp * head_size * 0.4, col, line_w * 0.7, true)
			draw_line(feather_pos, feather_pos - perp * head_size * 0.4, col, line_w * 0.7, true)
		if wind_speed > 18:
			var feather_pos2 = tail + arrow_dir * arrow_len * 0.35
			draw_line(feather_pos2, feather_pos2 + perp * head_size * 0.3, col, line_w * 0.5, true)
			draw_line(feather_pos2, feather_pos2 - perp * head_size * 0.3, col, line_w * 0.5, true)
