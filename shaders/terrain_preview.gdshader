shader_type spatial;

uniform float water_height = 2.0;

void fragment() {
	float h = WORLD_POSITION.y;
	vec3 n = normalize(NORMAL);
	float slope = 1.0 - n.y;
	vec3 color;
	if (h < water_height) {
		color = vec3(0.1, 0.3, 0.8); // water
	}
	else if (slope > 0.6) {
		color = vec3(0.5, 0.5, 0.5); // cliffs
	}
	else if (slope > 0.3) {
		color = vec3(0.7, 0.6, 0.3); // rough/bunker-ish
	}
	else {
		color = vec3(0.1, 0.7, 0.1); // flat playable
	}
	ALBEDO = color;
}
