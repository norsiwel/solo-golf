extends Node3D

# Wind system - generates and manages wind for a hole
# Attach to Main scene as "WindSystem"

signal wind_changed(direction: Vector3, speed_mph: float)

@export var min_wind_mph := 0.0
@export var max_wind_mph := 25.0
@export var gust_chance := 0.3      # probability of gusts
@export var change_interval := 8.0  # seconds between wind shifts

var wind_direction := Vector3.ZERO  # normalized horizontal direction
var wind_speed_mph := 0.0
var gust_speed_mph := 0.0
var is_gusting := false
var change_timer := 0.0
var gust_timer := 0.0

# Current effective wind (base + gust)
var effective_wind: Vector3:
	get:
		var total_mph = wind_speed_mph + gust_speed_mph
		return wind_direction * (total_mph * 0.44704)  # mph to m/s

func _ready():
	randomize()
	_generate_wind()

func _generate_wind():
	# Random direction
	var angle = randf() * TAU
	wind_direction = Vector3(sin(angle), 0, cos(angle)).normalized()
	wind_speed_mph = randf_range(min_wind_mph, max_wind_mph)
	emit_signal("wind_changed", wind_direction, wind_speed_mph)

func _process(delta):
	change_timer += delta
	if change_timer >= change_interval:
		change_timer = 0.0
		# Gradually shift wind direction and speed
		var new_angle = atan2(wind_direction.x, wind_direction.z) + randf_range(-0.5, 0.5)
		wind_direction = Vector3(sin(new_angle), 0, cos(new_angle)).normalized()
		wind_speed_mph = clamp(wind_speed_mph + randf_range(-5, 5), min_wind_mph, max_wind_mph)
		emit_signal("wind_changed", wind_direction, wind_speed_mph)

	# Random gusts
	gust_timer += delta
	if not is_gusting and gust_timer > randf_range(3.0, 8.0):
		if randf() < gust_chance:
			is_gusting = true
			gust_speed_mph = randf_range(3.0, 10.0)
			gust_timer = 0.0
	elif is_gusting:
		gust_speed_mph = move_toward(gust_speed_mph, 0, delta * 8.0)
		if gust_speed_mph <= 0.1:
			is_gusting = false
			gust_speed_mph = 0.0

func get_wind_description() -> String:
	var total = wind_speed_mph + gust_speed_mph
	var dir = _compass_direction()
	if total < 2:
		return "CALM"
	elif total < 8:
		return "Light %s  %.0f mph" % [dir, total]
	elif total < 15:
		return "Moderate %s  %.0f mph" % [dir, total]
	elif total < 22:
		return "Strong %s  %.0f mph" % [dir, total]
	else:
		return "GALE %s  %.0f mph" % [dir, total]

func _compass_direction() -> String:
	var angle = rad_to_deg(atan2(wind_direction.x, wind_direction.z))
	if angle < 0: angle += 360
	var dirs = ["N","NE","E","SE","S","SW","W","NW","N"]
	return dirs[int((angle + 22.5) / 45.0) % 8]

func apply_to_ball(ball_start: Vector3, ball_land: Vector3, power: float, loft: float) -> Vector3:
	# Returns modified landing position after wind effect
	var flight_time = power * 4.0  # approximate seconds in air
	var wind_ms = wind_speed_mph + gust_speed_mph
	wind_ms *= 0.44704  # to m/s
	
	# Loft multiplier - high shots affected more
	var loft_mult = 1.0 + (loft + 1.0) * 0.4  # low=0.6x, normal=1.0x, high=1.4x
	
	# Lateral drift from crosswind
	var forward = (ball_land - ball_start).normalized()
	forward.y = 0
	var right = Vector3(forward.z, 0, -forward.x)
	
	var lateral_wind = wind_direction.dot(right) * wind_ms
	var head_tail_wind = wind_direction.dot(forward) * wind_ms
	
	# Lateral displacement
	var lateral_disp = lateral_wind * flight_time * loft_mult * 0.8
	# Headwind reduces distance, tailwind adds
	var distance_change = head_tail_wind * flight_time * loft_mult * 0.5
	
	var modified = ball_land
	modified += right * lateral_disp
	modified += forward * distance_change
	return modified
