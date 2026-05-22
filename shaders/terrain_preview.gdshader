shader_type spatial;

uniform float water_height = 120.0;

void fragment() {
	float h = WORLD_POSITION.y;
	vec3 n = normalize(NORMAL);
	float slope = 1.0 - abs(n.y);

	vec3 color;
	if (h < water_height) {
		color = vec3(0.1, 0.3, 0.8); // water
	} else if (slope > 0.5) {
		color = vec3(0.5, 0.5, 0.5); // cliffs
	} else if (slope > 0.15) {
		color = vec3(0.7, 0.6, 0.3); // rough/slopes
	} else {
		color = vec3(0.15, 0.65, 0.15); // flat playable
	}

	// Apply simple lighting from normal
	float light = clamp(dot(n, normalize(vec3(0.5, 1.0, 0.3))), 0.2, 1.0);
	ALBEDO = color * light;
}
