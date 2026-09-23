shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float sway_strength : hint_range(0.0, 4.0, 0.05) = 2.5;

void vertex() {
	float canopy_weight = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.55);
	float primary = sin(TIME * 1.02 + phase + UV.y * 1.35);
	float gust = sin(TIME * 0.37 + phase * 1.73 + UV.y * 2.2);
	float sway = (primary + gust * 0.38) * sway_strength;
	VERTEX.x += sway * canopy_weight;
	VERTEX.y += abs(sway) * canopy_weight * 0.10;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
