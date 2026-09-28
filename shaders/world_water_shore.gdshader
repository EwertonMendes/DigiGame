shader_type canvas_item;

// Shoreline/swash for the reusable water system.
//
// COLOR.a is authored bank distance (0 = bank, 1 = open water). Unlike a
// scrolling strip, the wave centre actually advances into the basin and
// recedes again, with local phase variation so the whole shoreline does not
// breathe in perfect sync.
uniform vec4 foam_color : source_color = vec4(0.70, 0.985, 1.00, 0.88);
uniform vec4 secondary_color : source_color = vec4(0.12, 0.74, 0.90, 0.54);
uniform float shore_speed : hint_range(0.0, 2.0, 0.01) = 0.34;
uniform float shore_strength : hint_range(0.0, 1.5, 0.01) = 0.72;
uniform float secondary_strength : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float world_scale : hint_range(0.001, 0.1, 0.001) = 0.022;
uniform float crest_width : hint_range(0.02, 0.25, 0.005) = 0.050;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float soft_band(float coordinate, float center, float width) {
	float distance_to_center = abs(coordinate - center);
	return 1.0 - smoothstep(width, width * 1.90, distance_to_center);
}

void fragment() {
	float bank_depth = clamp(COLOR.a, 0.0, 1.0);
	vec2 p = UV * world_scale;

	// Stable coordinate along the authored edge. The mixed axes keep the
	// variation continuous across diagonal isometric shore segments.
	float along_bank = p.x * 0.77 + p.y * 0.41;
	float segment_noise = hash11(floor(along_bank * 3.0));
	float local_phase = segment_noise * 0.17;

	// Triangle-wave motion gives us a real swash: advance -> peak -> recede.
	float cycle = fract(TIME * shore_speed + local_phase);
	float advance = 1.0 - abs(cycle * 2.0 - 1.0);
	advance = smoothstep(0.0, 1.0, advance);

	float wobble = (
		sin(along_bank * 6.2 + TIME * 0.43) * 0.020
		+ sin(along_bank * 10.7 - TIME * 0.31) * 0.010
	);
	float primary_center = 0.10 + advance * 0.38 + wobble;
	float primary = soft_band(bank_depth, primary_center, crest_width);

	// A second smaller ripple follows half a cycle behind. It prevents the
	// shoreline from looking like one mechanically breathing outline.
	float secondary_cycle = fract(cycle + 0.52);
	float secondary_advance = 1.0 - abs(secondary_cycle * 2.0 - 1.0);
	float secondary_center = (
		0.12
		+ smoothstep(0.0, 1.0, secondary_advance) * 0.28
		- wobble * 0.55
	);
	float secondary = soft_band(
		bank_depth,
		secondary_center,
		crest_width * 0.78
	);

	float breakup = 0.68 + 0.32 * (
		0.5 + 0.5 * sin(along_bank * 12.4 + TIME * 0.58 + segment_noise * 4.0)
	);
	float bank_fade = (
		smoothstep(0.012, 0.055, bank_depth)
		* (1.0 - smoothstep(0.78, 0.98, bank_depth))
	);

	float primary_alpha = primary * breakup * (0.72 + advance * 0.28);
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
		clamp(primary_alpha * 1.30, 0.0, 1.0)
	);
	float source_alpha = mix(
		secondary_color.a,
		foam_color.a,
		clamp(primary_alpha * 1.30, 0.0, 1.0)
	);
	COLOR = vec4(foam, alpha * source_alpha);
}
