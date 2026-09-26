shader_type canvas_item;
render_mode unshaded;

// Central City's overworld paving is deliberately independent from the 64x32
// gameplay cell size. UV is authored in logical world-grid coordinates by
// CentralCityArt, then subdivided here so one gameplay cell reads as many small
// continuous paving stones instead of one visible board tile.
uniform float pavers_per_cell : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float grout_width : hint_range(0.02, 0.14, 0.005) = 0.055;
uniform float stone_variation : hint_range(0.0, 0.18, 0.005) = 0.065;
uniform float district_variation : hint_range(0.0, 0.10, 0.005) = 0.025;
uniform float grout_darkening : hint_range(0.0, 0.65, 0.01) = 0.36;
uniform float edge_highlight : hint_range(0.0, 0.12, 0.005) = 0.035;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 paving = UV * pavers_per_cell;
	vec2 stone_id = floor(paving);
	vec2 local = fract(paving);

	// Deterministic per-stone variation keeps the surface from reading as a
	// checkerboard while remaining stable between runs and across section seams.
	float stone_noise = hash21(stone_id + vec2(17.0, 31.0));
	float stone_shift = (stone_noise - 0.5) * 2.0 * stone_variation;

	// Very broad, low-amplitude variation creates the gentle gray-area changes
	// visible in the visual target without revealing the gameplay grid.
	vec2 district_id = floor(stone_id / 13.0);
	float district_noise = hash21(district_id + vec2(71.0, 19.0));
	float district_shift = (district_noise - 0.5) * 2.0 * district_variation;

	float edge_distance = min(
		min(local.x, 1.0 - local.x),
		min(local.y, 1.0 - local.y)
	);
	float grout = 1.0 - smoothstep(grout_width, grout_width + 0.035, edge_distance);

	// A tiny directional bevel keeps each paver readable as pavement rather than
	// a gameplay tile. It follows the two isometric ground axes.
	float leading_edge = max(
		1.0 - smoothstep(grout_width + 0.01, grout_width + 0.07, local.x),
		1.0 - smoothstep(grout_width + 0.01, grout_width + 0.07, local.y)
	);
	leading_edge *= 1.0 - grout;

	vec4 authored = COLOR;
	vec3 stone = authored.rgb * (1.0 + stone_shift + district_shift);
	stone += vec3(edge_highlight) * leading_edge;
	stone *= 1.0 - grout * grout_darkening;

	COLOR = vec4(clamp(stone, vec3(0.0), vec3(1.0)), authored.a);
}
