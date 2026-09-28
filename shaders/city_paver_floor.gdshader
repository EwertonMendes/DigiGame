shader_type canvas_item;

// This shader only authors the paving albedo. It intentionally remains in the
// normal CanvasItem lighting pipeline so CanvasModulate, DirectionalLight2D and
// nearby PointLight2D sources can shade the street at night.

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
// Region overlays yield to explicitly painted cells. The base ground material
// does not enable this mask, so every painted material remains in its batch.
uniform bool use_paint_mask = false;
uniform sampler2D paint_mask : filter_nearest, repeat_disable;
uniform vec2 paint_mask_origin = vec2(0.0);
uniform vec2 paint_mask_size = vec2(1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	if (use_paint_mask) {
		vec2 mask_cell = floor(UV + vec2(0.5)) - paint_mask_origin;
		if (all(greaterThanEqual(mask_cell, vec2(0.0))) && all(lessThan(mask_cell, paint_mask_size))) {
			if (texture(paint_mask, (mask_cell + vec2(0.5)) / paint_mask_size).r > 0.5) {
				discard;
			}
		}
	}
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
	float leading_edge = 1.0 - smoothstep(
		grout_width + 0.01, grout_width + 0.09, min(local.x, local.y)
	);
	float trailing_edge = 1.0 - smoothstep(
		grout_width + 0.01, grout_width + 0.09,
		min(1.0 - local.x, 1.0 - local.y)
	);
	leading_edge *= 1.0 - grout;
	trailing_edge *= 1.0 - grout;

	vec4 authored = COLOR;
	vec3 stone = authored.rgb * (1.0 + stone_shift + district_shift);
	stone += vec3(edge_highlight) * leading_edge;
	stone *= 1.0 - trailing_edge * 0.055;
	stone *= 1.0 - grout * grout_darkening;

	COLOR = vec4(clamp(stone, vec3(0.0), vec3(1.0)), authored.a);
}
