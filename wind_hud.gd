extends CanvasLayer

# Wind HUD - shows wind direction arrow, speed and description
# Sits top-left of screen, always visible during play

var wind_dir := Vector3.ZERO
var wind_speed := 0.0
var arrow_label: Label
var speed_label: Label
var desc_label: Label
var arrow_rotation := 0.0

func _ready():
	layer = 5
	_build_ui()
	# Connect to wind system
	call_deferred("_connect_wind")

func _connect_wind():
	var wind = get_tree().current_scene.get_node_or_null("WindSystem")
	if wind:
		wind.connect("wind_changed", _on_wind_changed)
		_on_wind_changed(wind.wind_direction, wind.wind_speed_mph)

func _build_ui():
	# Background panel - top left
	var panel = Panel.new()
	panel.set_anchor(SIDE_LEFT,  0.0)
	panel.set_anchor(SIDE_TOP,   0.0)
	panel.set_anchor(SIDE_RIGHT, 0.18)
	panel.set_anchor(SIDE_BOTTOM,0.14)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.55)
	ps.border_color = Color(0.5, 0.7, 1.0, 0.6)
	ps.border_width_bottom = 1
	ps.border_width_right = 1
	ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Wind arrow - big Unicode arrow that rotates via label
	arrow_label = Label.new()
	arrow_label.text = "➤"
	arrow_label.set_anchor(SIDE_LEFT,  0.01)
	arrow_label.set_anchor(SIDE_TOP,   0.01)
	arrow_label.set_anchor(SIDE_RIGHT, 0.07)
	arrow_label.set_anchor(SIDE_BOTTOM,0.09)
	arrow_label.add_theme_font_size_override("font_size", 28)
	arrow_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1))
	add_child(arrow_label)

	# Speed
	speed_label = Label.new()
	speed_label.text = "0 mph"
	speed_label.set_anchor(SIDE_LEFT,  0.07)
	speed_label.set_anchor(SIDE_TOP,   0.01)
	speed_label.set_anchor(SIDE_RIGHT, 0.18)
	speed_label.set_anchor(SIDE_BOTTOM,0.07)
	speed_label.add_theme_font_size_override("font_size", 16)
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(speed_label)

	# Description
	desc_label = Label.new()
	desc_label.text = "CALM"
	desc_label.set_anchor(SIDE_LEFT,  0.01)
	desc_label.set_anchor(SIDE_TOP,   0.08)
	desc_label.set_anchor(SIDE_RIGHT, 0.18)
	desc_label.set_anchor(SIDE_BOTTOM,0.14)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	add_child(desc_label)

func _on_wind_changed(direction: Vector3, speed_mph: float):
	wind_dir = direction
	wind_speed = speed_mph
	_update_display()

func _update_display():
	if speed_label:
		speed_label.text = "%.0f mph" % wind_speed
	if desc_label:
		# Get compass relative to player-facing (south = into screen = headwind)
		var angle = rad_to_deg(atan2(wind_dir.x, wind_dir.z))
		if angle < 0: angle += 360
		var dirs = ["N","NE","E","SE","S","SW","W","NW"]
		var compass = dirs[int((angle + 22.5) / 45.0) % 8]
		if wind_speed < 2:
			desc_label.text = "CALM"
			desc_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
		elif wind_speed < 8:
			desc_label.text = "Light  %s" % compass
			desc_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		elif wind_speed < 15:
			desc_label.text = "Moderate  %s" % compass
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
		elif wind_speed < 22:
			desc_label.text = "Strong  %s" % compass
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1))
		else:
			desc_label.text = "GALE  %s" % compass
			desc_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1))

func _process(_delta):
	if arrow_label == null or wind_speed < 1.0:
		if arrow_label:
			arrow_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.6))
		return
	# Rotate arrow to show wind direction on screen
	# Wind blows FROM the direction shown
	var screen_angle = rad_to_deg(atan2(wind_dir.x, wind_dir.z))
	arrow_label.rotation_degrees = screen_angle
	# Color based on speed
	if wind_speed < 8:
		arrow_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	elif wind_speed < 15:
		arrow_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
	elif wind_speed < 22:
		arrow_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1))
	else:
		arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1))
