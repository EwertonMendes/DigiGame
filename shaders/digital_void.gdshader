shader_type canvas_item;
render_mode unshaded;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += value_noise(p) * amplitude;
		p = p * 2.03 + vec2(4.17, 9.31);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	vec2 drift = vec2(TIME * 0.012, -TIME * 0.008);
	float cloud_a = fbm(uv * 3.2 + drift);
	float cloud_b = fbm(uv * 5.0 - drift * 0.7 + vec2(7.4, 1.3));
	float nebula = smoothstep(0.28, 0.82, cloud_a * 0.72 + cloud_b * 0.38);

	vec3 deep = vec3(0.006, 0.012, 0.035);
	vec3 blue = vec3(0.015, 0.105, 0.18);
	vec3 violet = vec3(0.105, 0.035, 0.16);
	vec3 color = mix(deep, blue, nebula);
	color = mix(color, violet, smoothstep(0.58, 0.88, cloud_b) * 0.45);

	vec2 grid_uv = fract((uv + vec2(TIME * 0.0018, -TIME * 0.0010)) * vec2(32.0, 18.0));
	float grid_x = 1.0 - smoothstep(0.0, 0.035, min(grid_uv.x, 1.0 - grid_uv.x));
	float grid_y = 1.0 - smoothstep(0.0, 0.035, min(grid_uv.y, 1.0 - grid_uv.y));
	float digital_grid = max(grid_x, grid_y) * (0.12 + 0.18 * nebula);
	color += vec3(0.02, 0.18, 0.24) * digital_grid;

	vec2 star_scale = vec2(88.0, 50.0);
	vec2 star_cell = floor(uv * star_scale);
	vec2 star_local = fract(uv * star_scale) - 0.5;
	float random_star = hash21(star_cell);
	float star_shape = 1.0 - smoothstep(0.0, 0.075, length(star_local));
	float twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(TIME * (1.0 + random_star * 2.4) + random_star * 31.0));
	float star = step(0.965, random_star) * star_shape * twinkle;
	color += mix(vec3(0.35, 0.85, 1.0), vec3(1.0, 0.45, 0.82), random_star) * star * 1.4;

	float data_pulse = pow(max(0.0, sin((uv.x + uv.y * 0.62 + TIME * 0.035) * 43.0)), 30.0);
	color += vec3(0.02, 0.20, 0.26) * data_pulse * nebula * 0.28;

	vec2 centered = uv - 0.5;
	float vignette = smoothstep(0.86, 0.20, length(centered * vec2(1.0, 0.78)));
	color *= 0.58 + 0.42 * vignette;

	COLOR = vec4(color, 1.0);
}
