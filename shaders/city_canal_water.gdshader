shader_type canvas_item;

// World-grid UVs make the surface continuous across authored canal regions.
// The two slow wave fields add motion without textures or per-frame CPU work.
uniform vec4 deep_color : source_color = vec4(0.018, 0.145, 0.205, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.045, 0.36, 0.43, 1.0);
uniform vec4 glint_color : source_color = vec4(0.29, 0.75, 0.77, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0, 0.01) = 0.42;

void fragment() {
	vec2 p = UV;
	float time = TIME * flow_speed;
	float broad = sin(p.x * 2.7 - p.y * 1.8 + time);
	float cross_wave = sin(p.x * 4.6 + p.y * 2.2 - time * 0.73 + broad * 0.42);
	float depth_mix = clamp(0.48 + broad * 0.17 + cross_wave * 0.11, 0.0, 1.0);
	float crest = smoothstep(0.67, 0.94, cross_wave * 0.55 + broad * 0.32 + 0.48);
	float glint = crest * (0.14 + 0.08 * sin(p.y * 5.1 + time * 0.55));
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, depth_mix);
	water = mix(water, glint_color.rgb, clamp(glint, 0.0, 0.23));
	COLOR = vec4(water, COLOR.a);
}
