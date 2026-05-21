shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Up to 6 splatmaps (PG courses can have many texture layers)
uniform sampler2D splat0 : source_color;
uniform sampler2D splat1 : source_color;
uniform sampler2D splat2 : source_color;
uniform sampler2D splat3 : source_color;
uniform sampler2D splat4 : source_color;
uniform sampler2D splat5 : source_color;

uniform sampler2D fairway_texture : source_color;
uniform sampler2D rough_texture : source_color;
uniform sampler2D green_texture : source_color;
uniform sampler2D bunker_texture : source_color;
uniform sampler2D sand_texture : source_color;
uniform sampler2D base_texture : source_color;  // satellite/overhead photo
uniform float texture_scale = 8.0;

uniform float owg_size_x = 2271.0;
uniform float owg_size_z = 2271.0;

// Which splatmap (0-5) and channel (0=R,1=G,2=B,3=A) for each surface
uniform ivec2 ch_fairway = ivec2(1, 2);
uniform ivec2 ch_rough   = ivec2(0, 1);
uniform ivec2 ch_green   = ivec2(0, 2);
uniform ivec2 ch_bunker  = ivec2(0, 3);
uniform ivec2 ch_sand    = ivec2(1, 0);
uniform ivec2 ch_base    = ivec2(0, 0);  // satellite layer

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float sample_channel(vec2 uv, ivec2 map_ch) {
	vec4 s;
	if      (map_ch.x == 0) s = texture(splat0, uv);
	else if (map_ch.x == 1) s = texture(splat1, uv);
	else if (map_ch.x == 2) s = texture(splat2, uv);
	else if (map_ch.x == 3) s = texture(splat3, uv);
	else if (map_ch.x == 4) s = texture(splat4, uv);
	else                    s = texture(splat5, uv);
	if      (map_ch.y == 0) return s.r;
	else if (map_ch.y == 1) return s.g;
	else if (map_ch.y == 2) return s.b;
	else                    return s.a;
}

void fragment() {
	vec2 splat_uv = vec2(
		clamp(1.0 + world_pos.x / max(owg_size_x, 1.0), 0.0, 1.0),
		clamp(-world_pos.z / max(owg_size_z, 1.0), 0.0, 1.0)
	);

	float w_fairway = sample_channel(splat_uv, ch_fairway);
	float w_rough   = sample_channel(splat_uv, ch_rough);
	float w_green   = sample_channel(splat_uv, ch_green);
	float w_bunker  = sample_channel(splat_uv, ch_bunker);
	float w_sand    = sample_channel(splat_uv, ch_sand);
	float w_base    = sample_channel(splat_uv, ch_base);

	vec2 tiled_uv = world_pos.xz / max(texture_scale, 0.1);

	vec4 fairway = texture(fairway_texture, tiled_uv);
	vec4 rough   = texture(rough_texture,   tiled_uv);
	vec4 green   = texture(green_texture,   tiled_uv);
	vec4 bunker  = texture(bunker_texture,  tiled_uv);
	vec4 sand    = texture(sand_texture,    tiled_uv);
	vec4 base    = texture(base_texture, splat_uv);

	// Overlay tiling textures on top of satellite base
	vec4 col = base;
	col = mix(col, fairway, w_fairway);
	col = mix(col, rough,   w_rough);
	col = mix(col, green,   w_green);
	col = mix(col, bunker,  w_bunker);
	col = mix(col, sand,    w_sand);

	ALBEDO    = col.rgb;
	ROUGHNESS = mix(0.85, 0.55, w_green);
	METALLIC  = 0.0;
}
