extends MeshInstance3D

# Attach this script to the Flag MeshInstance3D node
# It rotates to face the wind and oscillates to simulate flapping

var wind_dir := Vector3.ZERO
var wind_speed := 0.0
var flap_time := 0.0
var base_rotation := 0.0

func _ready():
	# Find wind system
	var wind = get_tree().current_scene.get_node_or_null("WindSystem")
	if wind:
		wind.connect("wind_changed", _on_wind_changed)
		wind_dir = wind.wind_direction
		wind_speed = wind.wind_speed_mph

func _on_wind_changed(direction: Vector3, speed_mph: float):
	wind_dir = direction
	wind_speed = speed_mph

func _process(delta):
	flap_time += delta

	if wind_speed < 1.0:
		# Calm - flag hangs limp, slight droop
		rotation_degrees.z = -15.0
		rotation_degrees.y = base_rotation
		return

	# Face the wind direction (flag streams away from wind)
	var target_yaw = rad_to_deg(atan2(-wind_dir.x, -wind_dir.z))
	base_rotation = lerp_angle(base_rotation, target_yaw, delta * 2.0)
	rotation_degrees.y = base_rotation

	# Flapping oscillation - faster and bigger in stronger wind
	var flap_freq = 2.0 + wind_speed * 0.15
	var flap_amp = clamp(wind_speed * 0.4, 0.5, 12.0)
	var flap = sin(flap_time * flap_freq) * flap_amp
	var flap2 = sin(flap_time * flap_freq * 1.7) * flap_amp * 0.3  # secondary harmonic

	rotation_degrees.z = flap + flap2
	# Slight lift in strong wind
	rotation_degrees.x = clamp(wind_speed * 0.2, 0, 8.0)
