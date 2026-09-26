shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent : source_color = vec4(0.35, 0.92, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.2, 4.0, 0.05) = 1.15;
uniform float scan_strength : hint_range(0.0, 0.25, 0.01) = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float pulse = 0.92 + 0.08 * sin(TIME * pulse_speed * 6.2831853);
	float scan = 1.0 - scan_strength * step(0.5, fract((UV.y + TIME * 0.05) * 32.0));
	tex.rgb *= accent.rgb * pulse * scan;
	tex.a *= accent.a;
	COLOR = tex;
}
