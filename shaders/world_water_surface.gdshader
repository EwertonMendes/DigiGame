shader_type canvas_item;

// Stylized texture-free water for the isometric overworld.
//
// UV is expressed in continuous gameplay-grid coordinates. In that coordinate
// system +X/+Y together correspond to visually moving down the isometric
// screen. flow_direction is therefore the ACTUAL visual travel direction:
// the pattern is sampled at UV - flow * time so positive flow really moves
// toward positive flow instead of the inverted phase semantics used before.
uniform vec4 deep_color : source_color = vec4(0.015, 0.300, 0.500, 1.0);
uniform vec4 body_color : source_color = vec4(0.015, 0.565, 0.755, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.735, 0.855, 1.0);
uniform vec4 line_color : source_color = vec4(0.220, 0.900, 0.980, 1.0);
uniform vec4 crest_color : source_color = vec4(0.660, 0.985, 1.000, 1.0);

uniform vec2 flow_direction = vec2(0.70710678, 0.70710678);
uniform float flow_speed : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float pattern_scale : hint_range(0.5, 6.0, 0.05) = 2.35;
uniform float line_width : hint_range(0.01, 0.16, 0.005) = 0.045;
uniform float line_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float ripple_scale : hint_range(0.25, 4.0, 0.05) = 1.15;
uniform float ripple_strength : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float depth_strength : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.98;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float grid_line(float value, float width) {
	float cell = fract(value);
	float distance_to_edge = min(cell, 1.0 - cell);
	return 1.0 - smoothstep(width, width + 0.035, distance_to_edge);
}

void fragment() {
	vec2 flow = flow_direction;
	float flow_length = max(length(flow), 0.001);
	flow /= flow_length;

	// f(UV - velocity * time) moves the visible pattern IN the velocity
	// direction. This makes flow_direction intuitive and deterministic.
	float time = TIME * flow_speed;
	vec2 advected = UV - flow * time;

	// Isometric screen-space axes reconstructed from gameplay-grid UVs.
	float down_axis = (advected.x + advected.y) * 0.5;
	float across_axis = advected.x - advected.y;

	// Fine, slightly irregular cyan network. This replaces the old broad,
	// blurry white blobs with the crisp digital-water language from the city
	// concept: small facets/ripples that read clearly at gameplay zoom.
	float warp = (
		sin(down_axis * 3.20 + sin(across_axis * 1.35) * 0.55)
		+ sin(across_axis * 2.10 - down_axis * 0.85) * 0.35
	) * 0.055;
	vec2 pattern = advected * pattern_scale;
	float line_a = grid_line(pattern.x + warp, line_width);
	float line_b = grid_line(pattern.y - warp, line_width);
	float network = max(line_a, line_b);

	// Break the network into organic segments while keeping hard readable
	// contours; no low-frequency cloud/glow masks are used.
	vec2 network_cell = floor(pattern);
	float breakup = mix(0.50, 1.0, hash21(network_cell));
	network *= breakup;

	// Subtle broad depth bands keep the surface dimensional without turning
	// the canal navy/black. They also travel with the same downward flow.
	float depth_wave = 0.5 + 0.5 * sin(
		down_axis * 1.30
		+ sin(across_axis * 0.72) * 0.75
	);
	float depth_cross = 0.5 + 0.5 * sin(
		across_axis * 0.86
		- down_axis * 0.48
		+ 1.70
	);
	float depth = clamp(
		0.50
		+ (depth_wave - 0.5) * depth_strength
		+ (depth_cross - 0.5) * 0.12,
		0.0,
		1.0
	);

	vec3 water = mix(
		deep_color.rgb,
		body_color.rgb,
		smoothstep(0.12, 0.78, depth)
	);
	water = mix(
		water,
		shallow_color.rgb,
		smoothstep(0.62, 0.96, depth) * 0.34
	);

	// Long, thin moving crests run mostly across the canal while travelling
	// downward. They remain narrow and cyan-white instead of becoming blobs.
	float crest_phase = (
		down_axis * ripple_scale * 6.28318
		+ sin(across_axis * 2.35) * 0.82
	);
	float crest_wave = max(0.0, 0.5 + 0.5 * sin(crest_phase));
	float crest = pow(crest_wave, 11.0);
	float crest_break = 0.58 + 0.42 * (
		0.5 + 0.5 * sin(across_axis * 6.20 + down_axis * 1.35)
	);
	crest *= crest_break * ripple_strength;

	float network_highlight = network * line_strength;
	water = mix(
		water,
		line_color.rgb,
		clamp(network_highlight, 0.0, 0.62)
	);
	water = mix(
		water,
		crest_color.rgb,
		clamp(crest, 0.0, 0.52)
	);

	// Stay inside the normal CanvasItem lighting pipeline so Central City's
	// day/night modulation and local lamps still affect the water.
	COLOR = vec4(water, opacity * COLOR.a);
}
