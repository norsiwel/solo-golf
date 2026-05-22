shader_type spatial;

uniform float water_height = 118.0;

void fragment() {
	float h = WORLD_POSITION.y;

	// NORMAL is in view space — use VIEW_MATRIX to get world normal
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - abs(world_normal.y);

	vec3 color;
	if (h <= water_height) {
		color = vec3(0.1, 0.3, 0.8);   // water/low
	} else if (slope > 0.5) {
		color = vec3(0.5, 0.5, 0.5);   // cliffs
	} else if (slope > 0.15) {
		color = vec3(0.7, 0.6, 0.3);   // rough/slopes
	} else {
		color = vec3(0.15, 0.65, 0.15); // flat playable
	}

	float light = clamp(dot(world_normal, normalize(vec3(0.5, 1.0, 0.3))), 0.2, 1.0);
	ALBEDO = color * light;
}
