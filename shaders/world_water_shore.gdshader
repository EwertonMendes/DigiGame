shader_type canvas_item;

// COLOR.a is a normalized shoreline-depth coordinate written by WorldWater:
// 0.0 touches the bank and 1.0 points toward open water. UV carries continuous
// world coordinates, letting the crest move along and across every edge strip.
uniform vec4 foam_color : source_color = vec4(0.72, 0.98, 0.95, 0.90);
uniform vec4 secondary_color : source_color = vec4(0.22, 0.70, 0.73, 0.50);
uniform float shore_speed : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float shore_strength : hint_range(0.0, 1.5, 0.01) = 0.88;
uniform float secondary_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float world_scale : hint_range(0.001, 0.1, 0.001) = 0.018;
uniform float crest_width : hint_range(0.02, 0.25, 0.005) = 0.075;

float soft_band(float coordinate, float center, float width) {
	float distance_to_center = abs(coordinate - center);
	return 1.0 - smoothstep(width, width * 2.15, distance_to_center);
}

void fragment() {
	float bank_depth = clamp(COLOR.a, 0.0, 1.0);
	vec2 p = UV * world_scale;
	float phase = (
		dot(p, normalize(vec2(0.91, 0.41))) * 7.4
		+ TIME * shore_speed
	);
	float wobble = (
		sin(phase)
		+ sin(phase * 1.73 + p.y * 2.6 - TIME * shore_speed * 0.37) * 0.42
	);

	float primary_center = 0.23 + wobble * 0.035;
	float secondary_center = 0.60 + sin(phase * 0.71 + 2.2) * 0.055;
	float primary = soft_band(bank_depth, primary_center, crest_width);
	float secondary = soft_band(bank_depth, secondary_center, crest_width * 0.82);

	float breakup = 0.72 + 0.28 * (
		0.5 + 0.5 * sin(p.x * 12.1 - p.y * 7.7 + TIME * 0.83 + wobble)
	);
	float bank_fade = (
		smoothstep(0.015, 0.075, bank_depth)
		* (1.0 - smoothstep(0.88, 1.0, bank_depth))
	);
	float primary_alpha = primary * breakup;
	float secondary_alpha = secondary * secondary_strength;
	float alpha = clamp(
		(primary_alpha + secondary_alpha)
		* bank_fade
		* shore_strength,
		0.0,
		1.0
	);

	vec3 foam = mix(
		secondary_color.rgb,
		foam_color.rgb,
		clamp(primary_alpha * 1.25, 0.0, 1.0)
	);
	float source_alpha = mix(
		secondary_color.a,
		foam_color.a,
		clamp(primary_alpha * 1.25, 0.0, 1.0)
	);
	COLOR = vec4(foam, alpha * source_alpha);
}
