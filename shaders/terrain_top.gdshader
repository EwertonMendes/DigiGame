shader_type canvas_item;
render_mode unshaded;

// Kenney's 132x83 landscape tiles include a top diamond plus visible side walls.
// The tactical board uses only the top face so adjacent cells read as one coherent surface.
const float TOP_FACE_HEIGHT = 64.0 / 83.0;

void fragment() {
	if (UV.y > TOP_FACE_HEIGHT) {
		discard;
	}

	vec2 top_uv = vec2(UV.x, UV.y / TOP_FACE_HEIGHT);
	float diamond = abs(top_uv.x - 0.5) * 2.0 + abs(top_uv.y - 0.5) * 2.0;
	if (diamond > 1.0) {
		discard;
	}

	COLOR = texture(TEXTURE, UV) * COLOR;
}
