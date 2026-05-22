shader_type spatial;
render_mode unshaded;

uniform float water_height = 118.0;

void fragment() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - world_normal.y;
	float h = WORLD_POSITION.y;

	if (h < water_height) {
		ALBEDO = vec3(0.05, 0.2, 0.8);       // water
	} else if (slope < 0.08) {
		ALBEDO = vec3(0.1, 0.65, 0.1);       // flat playable
	} else if (slope < 0.25) {
		ALBEDO = vec3(0.45, 0.55, 0.15);     // rolling
	} else {
		ALBEDO = vec3(0.65, 0.5, 0.25);      // steep
	}
}
