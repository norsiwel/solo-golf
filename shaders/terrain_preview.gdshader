shader_type spatial;
render_mode unshaded;

void fragment() {
	float h = WORLD_POSITION.y;
	if (h < 118.0) {
		ALBEDO = vec3(0.0, 0.1, 1.0); // below water — blue
	} else {
		ALBEDO = vec3(0.0, 0.8, 0.0); // above water — green
	}
}
