shader_type spatial;
render_mode unshaded;

void fragment() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - world_normal.y;

	// Ignore height entirely — just show slope
	if (slope < 0.08) {
		ALBEDO = vec3(0.1, 0.65, 0.1);       // flat — bright green
	} else if (slope < 0.25) {
		ALBEDO = vec3(0.45, 0.55, 0.15);     // rolling — olive
	} else {
		ALBEDO = vec3(0.65, 0.5, 0.25);      // steep — tan
	}
}
