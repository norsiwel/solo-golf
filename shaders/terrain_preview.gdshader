shader_type spatial;
render_mode unshaded;

void fragment() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ALBEDO = world_normal * 0.5 + 0.5;
}
