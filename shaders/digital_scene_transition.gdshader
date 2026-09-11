shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 primary_color : source_color = vec4(0.38, 0.78, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.64, 0.48, 1.0, 1.0);
uniform vec4 cover_color : source_color = vec4(0.035, 0.07, 0.15, 1.0);
uniform float phase_seed = 0.0;
uniform float cell_pixels : hint_range(18.0, 48.0) = 28.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float box_mask(vec2 point, vec2 center, vec2 half_size, float feather) {
	vec2 distance_to_box = abs(point - center) - half_size;
	float edge = max(distance_to_box.x, distance_to_box.y);
	return 1.0 - smoothstep(-feather, feather, edge);
}

void fragment() {
	vec2 pixel = UV / max(SCREEN_PIXEL_SIZE, vec2(0.000001));
	vec2 grid_uv = pixel / max(cell_pixels, 1.0);
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv);

	float random_value = hash21(cell + vec2(phase_seed * 17.3, phase_seed * 9.1));
	float random_b = hash21(cell.yx + vec2(phase_seed * 5.7, phase_seed * 23.9));

	// The cells arrive in a soft diagonal wave, but enough per-cell variation is
	// retained that the screen reads as flowing data rather than a wipe.
	float diagonal = clamp(UV.x * 0.56 + (1.0 - UV.y) * 0.44, 0.0, 1.0);
	float radial = clamp(length((UV - vec2(0.5)) * vec2(0.72, 1.0)) * 1.15, 0.0, 1.0);
	float order = clamp(
		0.10 + diagonal * 0.30 + radial * 0.16 + random_value * 0.38,
		0.06,
		0.92
	);
	float coverage = smoothstep(order - 0.095, order + 0.035, progress);

	// Keep the tiles alive throughout the effect. Their interior highlight moves
	// independently, while the tile itself gently breathes instead of flickering.
	float breathe = 0.5 + 0.5 * sin(TIME * (3.2 + random_b * 1.8) + random_value * 6.28318);
	float drift_phase = TIME * (0.32 + random_value * 0.18) + random_b * 7.0;
	vec2 spark_center = vec2(
		0.18 + 0.64 * fract(random_value * 4.7 + drift_phase * 0.15),
		0.18 + 0.64 * fract(random_b * 5.3 - drift_phase * 0.11)
	);
	float spark = box_mask(local, spark_center, vec2(0.075 + random_b * 0.025), 0.035);

	float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float edge = 1.0 - smoothstep(0.028, 0.105, edge_distance);
	float inner = smoothstep(0.08, 0.18, edge_distance);

	// A moving data band gives the whole mosaic a directional pulse without
	// introducing a separate full-screen transition card.
	float flow_position = fract(TIME * 0.42 + phase_seed * 0.13);
	float flow_distance = abs(fract(UV.x * 0.62 + UV.y * 0.38 - flow_position + 0.5) - 0.5);
	float flow_band = 1.0 - smoothstep(0.015, 0.075, flow_distance);
	flow_band *= smoothstep(0.08, 0.62, progress) * (1.0 - smoothstep(0.88, 1.0, progress));

	float accent_pick = smoothstep(0.68, 0.98, random_value + breathe * 0.10);
	vec3 tile_color = mix(primary_color.rgb, accent_color.rgb, accent_pick * 0.58);
	vec3 color = mix(cover_color.rgb, tile_color, 0.58 + breathe * 0.10);
	color += primary_color.rgb * edge * 0.14;
	color += vec3(0.93, 0.98, 1.0) * spark * coverage * (0.18 + breathe * 0.22);
	color += mix(primary_color.rgb, accent_color.rgb, 0.45) * flow_band * 0.24;
	color = mix(color, vec3(0.92, 0.97, 1.0), flash * 0.48);

	float tile_alpha = coverage * (0.70 + inner * 0.14 + edge * 0.08 + breathe * 0.035);
	tile_alpha = max(tile_alpha, flow_band * 0.12);

	// Only the final few percent fully seal the old scene. This hides the actual
	// scene swap without making the player sit on a visibly separate loading card.
	float seal = smoothstep(0.955, 1.0, progress);
	float alpha = mix(tile_alpha, 1.0, seal);
	alpha = max(alpha, flash * 0.22);

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
