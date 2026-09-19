shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float phase_seed = 0.0;
uniform float cell_pixels : hint_range(18.0, 48.0) = 30.0;
uniform vec4 primary_color : source_color = vec4(0.35, 0.86, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.58, 0.52, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// In a CanvasItem fragment shader, Godot already supplies COLOR multiplied
	// by the CanvasItem's default texture (when one exists). Sampling TEXTURE
	// again would square/darken textured UI — especially the Battle Operator's
	// dark full-screen backdrop — and can look like a black flash while the
	// transition material is active. Use the renderer-provided authored pixel
	// directly and only change its reveal/glow.
	vec4 source = COLOR;

	vec2 pixel = SCREEN_UV / max(SCREEN_PIXEL_SIZE, vec2(0.000001));
	vec2 grid_uv = pixel / max(cell_pixels, 1.0);
	vec2 cell = floor(grid_uv);
	vec2 local = fract(grid_uv);

	float random_value = hash21(cell + vec2(phase_seed * 17.3, phase_seed * 9.1));
	float random_b = hash21(cell.yx + vec2(phase_seed * 5.7, phase_seed * 23.9));

	// Lower-left is order 0 and upper-right is order 1. A restrained amount of
	// per-cell jitter keeps the result digital without becoming a plain wipe.
	float diagonal = clamp((SCREEN_UV.x + (1.0 - SCREEN_UV.y)) * 0.5, 0.0, 1.0);
	float order = clamp(diagonal * 0.82 + random_value * 0.18, 0.0, 1.0);

	// Exact endpoint guards are important. At progress 0 absolutely no menu
	// pixel may leak into the world; at progress 1 the authored UI must be exact.
	float reveal = 0.0;
	if (progress >= 0.9999) {
		reveal = 1.0;
	} else if (progress > 0.0001) {
		reveal = smoothstep(order - 0.055, order + 0.035, progress);
	}

	float active = step(0.001, progress) * (1.0 - step(0.999, progress));
	float frontier = (1.0 - smoothstep(0.015, 0.085, abs(progress - order))) * active;
	float edge_distance = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float cell_edge = 1.0 - smoothstep(0.025, 0.105, edge_distance);
	float pulse = 0.72 + 0.28 * sin(TIME * (5.0 + random_b * 2.0) + random_value * 6.28318);
	float glow = frontier * (0.18 + cell_edge * 0.42) * pulse;

	vec3 data_color = mix(primary_color.rgb, accent_color.rgb, random_b * 0.62);
	vec3 rgb = mix(source.rgb, data_color, clamp(glow * 0.56, 0.0, 0.58));
	rgb += data_color * frontier * cell_edge * 0.08;

	COLOR = vec4(rgb, source.a * reveal);
}
