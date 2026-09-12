shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 primary_color : source_color = vec4(0.38, 0.78, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.64, 0.48, 1.0, 1.0);
uniform vec4 cover_color : source_color = vec4(0.035, 0.07, 0.15, 1.0);
uniform float phase_seed = 0.0;
uniform float cell_pixels : hint_range(4.0, 16.0) = 8.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 pixel = UV / max(SCREEN_PIXEL_SIZE, vec2(0.000001));
	vec2 grid_uv = pixel / max(cell_pixels, 1.0);
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv);

	float random_value = hash21(cell + vec2(phase_seed * 11.7, phase_seed * 7.3));
	float diagonal = UV.x * 0.55 + (1.0 - UV.y) * 0.45;
	float order = clamp(0.08 + diagonal * 0.36 + random_value * 0.46, 0.04, 0.94);
	float coverage = smoothstep(order - 0.11, order + 0.025, progress);

	// One inexpensive pulse per low-resolution cell keeps the data blocks alive.
	// The shader runs in a ~320px-long-edge SubViewport, so even weak mobile GPUs
	// animate only a small fraction of the device's physical pixels.
	float pulse = 0.5 + 0.5 * sin(TIME * 3.8 + random_value * 6.28318);
	float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float edge = 1.0 - smoothstep(0.035, 0.13, edge_distance);

	vec2 spark_center = vec2(
		0.22 + 0.56 * fract(random_value * 5.17 + TIME * 0.11),
		0.22 + 0.56 * fract(random_value * 8.43 - TIME * 0.08)
	);
	vec2 spark_delta = abs(local - spark_center);
	float spark = 1.0 - smoothstep(0.06, 0.13, max(spark_delta.x, spark_delta.y));

	float flow_phase = fract(UV.x * 0.58 + UV.y * 0.42 - TIME * 0.34 + phase_seed * 0.07);
	float flow_distance = min(flow_phase, 1.0 - flow_phase);
	float flow = 1.0 - smoothstep(0.018, 0.075, flow_distance);
	flow *= smoothstep(0.10, 0.55, progress) * (1.0 - smoothstep(0.88, 1.0, progress));

	float accent_amount = step(0.72, random_value) * 0.48 + pulse * 0.10;
	vec3 tile_color = mix(primary_color.rgb, accent_color.rgb, accent_amount);
	vec3 color = mix(cover_color.rgb, tile_color, 0.62 + pulse * 0.08);
	color += primary_color.rgb * edge * 0.12;
	color += vec3(0.94, 0.98, 1.0) * spark * coverage * (0.12 + pulse * 0.18);
	color += mix(primary_color.rgb, accent_color.rgb, 0.45) * flow * 0.18;
	color = mix(color, vec3(0.94, 0.98, 1.0), flash * 0.42);

	float tile_alpha = coverage * (0.74 + edge * 0.09 + pulse * 0.035);
	tile_alpha = max(tile_alpha, flow * 0.10);
	float seal = smoothstep(0.965, 1.0, progress);
	float alpha = mix(tile_alpha, 1.0, seal);
	alpha = max(alpha, flash * 0.16);

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
