shader_type canvas_item;

// Bright stylized canal edge. UV here is screen/world-space position, while
// COLOR.a stores normalized distance from the bank (0 = bank, 1 = open water).
// The animation deliberately travels toward +Y, i.e. down the screen.
uniform vec4 foam_color : source_color = vec4(0.320, 0.930, 1.000, 0.88);
uniform vec4 secondary_color : source_color = vec4(0.080, 0.690, 0.860, 0.50);
uniform float shore_speed : hint_range(0.0, 2.0, 0.01) = 0.42;
uniform float shore_strength : hint_range(0.0, 1.5, 0.01) = 0.72;
uniform float secondary_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float world_scale : hint_range(0.001, 0.1, 0.001) = 0.020;
uniform float crest_width : hint_range(0.02, 0.25, 0.005) = 0.055;

float soft_band(float coordinate, float center, float width) {
	float distance_to_center = abs(coordinate - center);
	return 1.0 - smoothstep(width, width * 1.85, distance_to_center);
}

void fragment() {
	float bank_depth = clamp(COLOR.a, 0.0, 1.0);

	// Positive visual travel: sample at p - velocity*time.
	vec2 p = UV * world_scale - vec2(0.0, TIME * shore_speed);
	float along_bank = p.x * 5.40 + p.y * 1.15;
	float wobble = sin(along_bank) * 0.018 + sin(along_bank * 1.83 + 1.7) * 0.010;

	// One crisp luminous edge and a much weaker interior echo. This matches
	// the prototype better than broad white foam bands.
	float primary = soft_band(bank_depth, 0.11 + wobble, crest_width);
	float secondary = soft_band(
		bank_depth,
		0.43 + sin(along_bank * 0.72) * 0.025,
		crest_width * 0.78
	);

	float breakup = 0.78 + 0.22 * (0.5 + 0.5 * sin(along_bank * 2.35 + p.y * 3.2));
	float bank_fade = (
		smoothstep(0.015, 0.060, bank_depth)
		* (1.0 - smoothstep(0.80, 0.98, bank_depth))
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

	vec3 edge_color = mix(
		secondary_color.rgb,
		foam_color.rgb,
		clamp(primary_alpha * 1.35, 0.0, 1.0)
	);
	float source_alpha = mix(
		secondary_color.a,
		foam_color.a,
		clamp(primary_alpha * 1.35, 0.0, 1.0)
	);
	COLOR = vec4(edge_color, alpha * source_alpha);
}
