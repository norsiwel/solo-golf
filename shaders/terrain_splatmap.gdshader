shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Splatmap — R=layer0, G=layer1, B=layer2, A=layer3
uniform sampler2D splatmap : source_color, hint_default_white;

// Layer textures — hint_default_black so missing layers contribute nothing
uniform sampler2D layer0_texture : source_color, hint_default_black;
uniform sampler2D layer1_texture : source_color, hint_default_black;
uniform sampler2D layer2_texture : source_color, hint_default_black;
uniform sampler2D layer3_texture : source_color, hint_default_black;

// Per-layer tile sizes in metres (from splat_layers.json)
uniform float layer0_tile = 15.0;
uniform float layer1_tile = 40.0;
uniform float layer2_tile = 20.0;
uniform float layer3_tile = 15.0;

// Terrain world dimensions for splatmap UV
uniform float owg_size_x = 1501.0;
uniform float owg_size_z = 600.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Splatmap UV — terrain origin 0,0,0, X right, Z forward
	vec2 splat_uv = vec2(
		clamp(world_pos.x / max(owg_size_x, 1.0), 0.0, 1.0),
		clamp(world_pos.z / max(owg_size_z, 1.0), 0.0, 1.0)
	);
	vec4 splat = texture(splatmap, splat_uv);

	// Normalize weights so they always sum to 1.0
	float total = splat.r + splat.g + splat.b + splat.a;
	if (total < 0.001) total = 1.0;
	vec4 w = splat / total;

	// Sample each layer at its own tile scale
	vec4 c0 = texture(layer0_texture, world_pos.xz / max(layer0_tile, 0.1));
	vec4 c1 = texture(layer1_texture, world_pos.xz / max(layer1_tile, 0.1));
	vec4 c2 = texture(layer2_texture, world_pos.xz / max(layer2_tile, 0.1));
	vec4 c3 = texture(layer3_texture, world_pos.xz / max(layer3_tile, 0.1));

	vec4 final_color = c0 * w.r + c1 * w.g + c2 * w.b + c3 * w.a;

	ALBEDO    = final_color.rgb;
	ROUGHNESS = 0.75;
	METALLIC  = 0.0;
}
