shader_type canvas_item;

// Texture-free world water. UV is expected to be a continuous world/grid
// coordinate supplied by the owning area, so separate polygons do not reveal
// seams and no scrolling texture asset is required.
uniform vec4 deep_color : source_color = vec4(0.010, 0.090, 0.155, 1.0);
uniform vec4 body_color : source_color = vec4(0.020, 0.285, 0.385, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.060, 0.500, 0.555, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.620, 0.940, 0.920, 1.0);
uniform vec2 flow_direction = vec2(0.88, 0.42);
uniform float flow_speed : hint_range(0.0, 2.0, 0.01) = 0.28;
uniform float wave_scale : hint_range(0.05, 2.0, 0.01) = 0.48;
uniform float detail_scale : hint_range(0.1, 4.0, 0.01) = 1.16;
uniform float wave_strength : hint_range(0.0, 1.5, 0.01) = 0.86;
uniform float highlight_strength : hint_range(0.0, 1.5, 0.01) = 0.62;
uniform float sparkle_strength : hint_range(0.0, 1.0, 0.01) = 0.14;
uniform float depth_bias : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.98;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

void fragment() {
	vec2 flow = flow_direction;
	float flow_length = max(length(flow), 0.001);
	flow /= flow_length;
	vec2 cross_flow = vec2(-flow.y, flow.x);
	float time = TIME * flow_speed;

	vec2 p = UV * wave_scale;
	float primary = sin(
		dot(p, flow) * 6.28318
		+ time
		+ sin(dot(p, cross_flow) * 2.35 - time * 0.42) * 0.72
	);
	float crossing = sin(
		dot(p, cross_flow) * 8.10
		- time * 0.74
		+ primary * 0.64
	);
	float long_swell = sin(
		dot(p, normalize(vec2(0.64, -0.77))) * 3.45
		+ time * 0.31
	);

	float coarse_noise = value_noise(UV * detail_scale + flow * time * 0.18);
	float fine_noise = value_noise(
		UV * detail_scale * 2.15
		- cross_flow * time * 0.14
		+ vec2(7.3, -3.1)
	);

	float height_field = (
		primary * 0.42
		+ crossing * 0.30
		+ long_swell * 0.16
		+ (coarse_noise - 0.5) * 0.30
	) * wave_strength;

	float depth_field = clamp(
		depth_bias
		+ height_field * 0.24
		+ (coarse_noise - 0.5) * 0.20,
		0.0,
		1.0
	);
	vec3 water_color = mix(deep_color.rgb, body_color.rgb, smoothstep(0.18, 0.66, depth_field));
	water_color = mix(
		water_color,
		shallow_color.rgb,
		smoothstep(0.58, 0.92, depth_field) * 0.70
	);

	float crest_source = (
		0.50
		+ primary * 0.24
		+ crossing * 0.18
		+ (fine_noise - 0.5) * 0.22
	);
	float crest = smoothstep(0.68, 0.88, crest_source);
	float broken_crest = mix(0.34, 1.0, smoothstep(0.20, 0.86, fine_noise));
	float glint = crest * broken_crest * highlight_strength;

	float sparkle_phase = 0.5 + 0.5 * sin(
		UV.x * 14.7
		+ UV.y * 9.1
		+ TIME * 1.35
		+ coarse_noise * 5.2
	);
	float sparkle = (
		smoothstep(0.955, 0.995, sparkle_phase)
		* smoothstep(0.66, 0.94, fine_noise)
		* sparkle_strength
	);

	float highlight_mix = clamp(glint * 0.72 + sparkle, 0.0, 0.78);
	water_color = mix(water_color, highlight_color.rgb, highlight_mix);

	// Intentionally remains in the normal CanvasItem lighting pipeline so
	// CanvasModulate and nearby PointLight2D sources affect the water.
	COLOR = vec4(water_color, opacity * COLOR.a);
}
