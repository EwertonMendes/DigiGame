shader_type canvas_item;
render_mode unshaded, blend_add;

// Brackeys predrawn sheets contain very soft/semi-transparent pixels that look
// rectangular when a whole frame is stretched behind a UI card. This material
// turns those frames into a composited accent: weak pixels are removed, the frame
// perimeter is feathered, and only the authored bright VFX remains visible.
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.20;
uniform float alpha_softness : hint_range(0.001, 0.5) = 0.18;
uniform float edge_fade : hint_range(0.0, 0.5) = 0.12;
uniform float intensity : hint_range(0.0, 2.0) = 0.75;
uniform vec2 frame_uv_offset = vec2(0.0);
uniform vec2 frame_uv_size = vec2(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 local_uv = clamp((UV - frame_uv_offset) / max(frame_uv_size, vec2(0.0001)), vec2(0.0), vec2(1.0));

	// The source alpha is the most reliable signal in these CC0 predrawn sheets.
	// Raising the floor removes the low-opacity rectangular wash visible in UI use.
	float authored_alpha = smoothstep(alpha_cutoff, alpha_cutoff + alpha_softness, tex.a);

	// Feather the frame bounds so even authored pixels touching the atlas cell edge
	// cannot reveal the rectangular 6x5 frame silhouette.
	vec2 border_distance = min(local_uv, vec2(1.0) - local_uv);
	float edge_mask = 1.0;
	if (edge_fade > 0.0001) {
		edge_mask = smoothstep(0.0, edge_fade, border_distance.x)
			* smoothstep(0.0, edge_fade, border_distance.y);
	}

	vec3 color = tex.rgb * tint.rgb;
	float alpha = authored_alpha * edge_mask * tint.a * intensity;
	COLOR = vec4(color * alpha, alpha);
}
