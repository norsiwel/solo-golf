extends Node
## OWG Post-Processing Environment
## Attach to Main node or call setup_environment() from main.gd
## Provides ACES tonemapping, glow, and SSAO for visual quality

func _ready() -> void:
	setup_environment()

func setup_environment() -> void:
	# Remove any existing WorldEnvironment
	var existing = get_parent().get_node_or_null("OWGWorldEnvironment")
	if existing:
		existing.queue_free()

	var world_env = WorldEnvironment.new()
	world_env.name = "OWGWorldEnvironment"

	var env = Environment.new()

	# Sky — procedural for now, replaced when skybox textures are loaded
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color    = Color(0.18, 0.42, 0.82)
	sky_mat.sky_horizon_color = Color(0.65, 0.82, 0.98)
	sky_mat.ground_bottom_color  = Color(0.20, 0.48, 0.18)
	sky_mat.ground_horizon_color = Color(0.38, 0.58, 0.30)
	sky_mat.sun_angle_max = 28.0
	sky.sky_material = sky_mat
	env.sky = sky

	# Ambient light from sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6

	# ACES tonemapping — cinematic look, handles bright highlights well
	env.tonemap_mode    = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.0

	# Glow — subtle bloom on bright surfaces (water glints, sky)
	env.glow_enabled   = true
	env.glow_intensity = 0.6
	env.glow_strength  = 0.8
	env.glow_bloom     = 0.05
	env.glow_normalized = true

	# SSAO — ambient occlusion for terrain creases and grass shadows
	env.ssao_enabled   = true
	env.ssao_radius    = 1.2
	env.ssao_intensity = 1.2
	env.ssao_power     = 1.5

	# Subtle depth of field at distance (fairway haze)
	# Disabled by default — enable for screenshots
	# env.dof_blur_far_enabled   = true
	# env.dof_blur_far_distance  = 400.0
	# env.dof_blur_far_transition = 200.0
	# env.dof_blur_far_amount    = 0.02

	# Adjustment — slight saturation boost for golf greens
	env.adjustment_enabled    = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast   = 1.05
	env.adjustment_saturation = 1.15

	world_env.environment = env
	get_parent().add_child(world_env)

	print("OWG: Environment set — ACES tonemap, glow, SSAO, +15% saturation")
