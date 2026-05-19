shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D splatmap : source_color;
uniform sampler2D fairway_texture : source_color;
uniform sampler2D rough_texture : source_color;
uniform sampler2D green_texture : source_color;
uniform sampler2D bunker_texture : source_color;
uniform sampler2D sand_texture : source_color;
uniform float texture_scale = 8.0;

// World-space UV for splatmap (matches converter UV formula)
uniform float owg_size_x = 2271.0;
uniform float owg_size_z = 2271.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Splatmap sampled using world-space UV (matches converter: u=-wx/sx, v=wz/sz)
	vec2 splat_uv = vec2(
		clamp(-world_pos.x / max(owg_size_x, 1.0), 0.0, 1.0),
		clamp( world_pos.z / max(owg_size_z, 1.0), 0.0, 1.0)
	);
	vec4 splat = texture(splatmap, splat_uv);

	// Detail textures tiled by texture_scale metres
	vec2 tiled_uv = world_pos.xz / max(texture_scale, 0.1);

	vec4 fairway = texture(fairway_texture, tiled_uv);
	vec4 rough    = texture(rough_texture,   tiled_uv);
	vec4 green    = texture(green_texture,   tiled_uv);
	vec4 bunker   = texture(bunker_texture,  tiled_uv);
	vec4 sand     = texture(sand_texture,    tiled_uv);

	// Blend: R=fairway, G=rough, B=green, A=bunker, remainder=sand/base
	float used = splat.r + splat.g + splat.b + splat.a;
	vec4 final_color =
		fairway * splat.r +
		rough   * splat.g +
		green   * splat.b +
		bunker  * splat.a +
		sand    * max(0.0, 1.0 - used);

	ALBEDO    = final_color.rgb;
	ROUGHNESS = 0.7;
	METALLIC  = 0.0;
}
