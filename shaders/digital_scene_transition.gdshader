shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 primary_color : source_color = vec4(0.10, 0.86, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.43, 0.08, 1.0);
uniform vec4 void_color : source_color = vec4(0.004, 0.012, 0.028, 1.0);
uniform float phase_seed = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
	vec2 centered = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	float radius = length(centered);

	vec2 grid_size = vec2(max(28.0, 24.0 * aspect), 24.0);
	vec2 grid_uv = UV * grid_size;
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv);
	float random_value = hash21(cell + vec2(phase_seed * 13.7, phase_seed * 7.9));

	float outward = clamp(radius * 0.68, 0.0, 0.52);
	float vertical_bias = (1.0 - UV.y) * 0.12;
	float threshold = clamp(0.10 + outward + vertical_bias + random_value * 0.25, 0.08, 0.92);
	float coverage = smoothstep(threshold - 0.08, threshold + 0.015, progress);

	float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float cell_edge = 1.0 - smoothstep(0.025, 0.085, edge_distance);
	float scan_wave = 0.5 + 0.5 * sin(UV.y * 260.0 - TIME * 18.0 + random_value * 6.28318);
	float data_pulse = smoothstep(0.84, 1.0, scan_wave) * coverage;

	float ring_radius = mix(0.02, 0.78, progress);
	float ring = exp(-abs(radius - ring_radius) * 34.0) * smoothstep(0.03, 0.20, progress);
	float inner_ring = exp(-abs(radius - ring_radius * 0.58) * 54.0) * smoothstep(0.10, 0.35, progress) * 0.55;

	float column_noise = hash21(vec2(floor(UV.x * 72.0), floor(TIME * 7.0 + phase_seed * 19.0)));
	float data_rain = step(0.91, column_noise) * smoothstep(0.08, 0.72, progress) * (0.25 + 0.75 * scan_wave);

	float accent_mix = step(0.82, random_value) * 0.72 + ring * 0.55;
	vec3 digital = mix(primary_color.rgb, accent_color.rgb, clamp(accent_mix, 0.0, 1.0));
	vec3 color = mix(void_color.rgb, digital, 0.18 + cell_edge * 0.22 + data_pulse * 0.32);
	color += primary_color.rgb * (ring * 0.62 + inner_ring * 0.26 + data_rain * 0.18);
	color += accent_color.rgb * ring * 0.24;

	float full_lock = smoothstep(0.78, 0.995, progress);
	float alpha = max(coverage * (0.88 + cell_edge * 0.08), ring * 0.82);
	alpha = max(alpha, data_rain * 0.42);
	alpha = mix(alpha, 1.0, full_lock);

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
