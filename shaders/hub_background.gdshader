shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float vignette = smoothstep(0.82, 0.18, distance(uv, vec2(0.5)));
	vec2 grid_uv = fract(uv * vec2(26.0, 15.0));
	float grid = step(0.975, grid_uv.x) + step(0.975, grid_uv.y);
	vec3 deep = vec3(0.012, 0.035, 0.055);
	vec3 teal = vec3(0.018, 0.105, 0.120);
	vec3 color = mix(deep, teal, uv.y * 0.55 + vignette * 0.18);
	color += vec3(0.01, 0.08, 0.09) * grid * (0.20 + vignette * 0.35);
	COLOR = vec4(color, 1.0);
}
