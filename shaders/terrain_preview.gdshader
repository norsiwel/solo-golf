shader_type spatial;
render_mode unshaded;

void fragment() {
	// Encode world Y as color to see what value we're getting
	// If terrain is at 117-253m, normalized = (h-117)/136
	float h = WORLD_POSITION.y;
	float normalized = clamp((h - 100.0) / 200.0, 0.0, 1.0);
	// normalized=0 -> black, normalized=0.5 -> red, normalized=1 -> white
	ALBEDO = vec3(normalized, normalized * 0.5, 0.0);
}
