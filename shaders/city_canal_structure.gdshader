shader_type canvas_item;

// Procedural architectural material for Central City's recessed canal.
//
// The owning mesh writes the concrete albedo into COLOR.rgb and normalized
// face depth into COLOR.a (0 = top edge, 1 = bottom edge). UV carries the
// display/world position so subtle aggregate variation stays continuous across
// separately authored wall polygons.
//
// This is intentionally restrained: water remains the visual focus. The goal
// is to make the basin read as built concrete/stone instead of flat ColorRect
// geometry, without adding bespoke texture assets.
uniform float world_scale : hint_range(0.002, 0.08, 0.001) = 0.018;
uniform float aggregate_strength : hint_range(0.0, 0.12, 0.005) = 0.032;
uniform float vertical_darkening : hint_range(0.0, 0.45, 0.01) = 0.18;
uniform float top_bevel_strength : hint_range(0.0, 0.25, 0.01) = 0.10;
uniform float top_bevel_width : hint_range(0.02, 0.35, 0.01) = 0.12;
uniform float bottom_ao_strength : hint_range(0.0, 0.35, 0.01) = 0.12;
uniform float bottom_ao_width : hint_range(0.05, 0.45, 0.01) = 0.24;
uniform float cool_depth_tint : hint_range(0.0, 0.25, 0.01) = 0.06;
uniform vec3 depth_tint_color : source_color = vec3(0.20, 0.31, 0.34);

varying vec3 authored_color;
varying float authored_depth;
varying vec2 world_coord;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 eased = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
}

void vertex() {
	authored_color = COLOR.rgb;
	authored_depth = clamp(COLOR.a, 0.0, 1.0);
	world_coord = UV;
}

void fragment() {
	float depth = authored_depth;

	// Two low-amplitude scales prevent a perfectly uniform slab without making
	// the wall look noisy or rocky.
	float aggregate_large = value_noise(world_coord * world_scale);
	float aggregate_fine = value_noise(
		world_coord * world_scale * 3.1 + vec2(7.2, -4.6)
	);
	float aggregate = (
		(aggregate_large - 0.5) * 0.68
		+ (aggregate_fine - 0.5) * 0.32
	) * aggregate_strength;

	vec3 concrete = authored_color * (1.0 + aggregate);
	concrete *= 1.0 - depth * vertical_darkening;

	// A restrained upper bevel catches the same city lighting as the pavement,
	// while lower AO visually seats the wall against the basin floor/water.
	float top_bevel = 1.0 - smoothstep(
		0.0,
		max(top_bevel_width, 0.001),
		depth
	);
	concrete += vec3(top_bevel_strength) * top_bevel;

	float bottom_ao = smoothstep(
		1.0 - bottom_ao_width,
		1.0,
		depth
	);
	concrete *= 1.0 - bottom_ao * bottom_ao_strength;

	// Subtle cool shift toward the bottom suggests reflected water without
	// painting the concrete cyan.
	float cool_mix = depth * cool_depth_tint;
	concrete = mix(concrete, depth_tint_color, cool_mix);

	COLOR = vec4(clamp(concrete, vec3(0.0), vec3(1.0)), 1.0);
}
