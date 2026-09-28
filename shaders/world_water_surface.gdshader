shader_type canvas_item;

// Reusable stylized 2D/2.5D water.
//
// UV carries continuous isometric grid coordinates so every water polygon
// shares one world-space flow. For authored basins, vertex COLOR.rg contains
// normalized basin coordinates (0..1), giving the shader a real edge-to-center
// depth signal instead of faking depth with a moving colour field.
//
// Screen reading is intentionally limited to one subtle refraction sample.
// Godot performs the back-buffer copy once for the first screen-reading
// CanvasItem in a frame, then reuses it for the remaining water fragments.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 deep_color : source_color = vec4(0.010, 0.330, 0.540, 1.0);
uniform vec4 body_color : source_color = vec4(0.020, 0.640, 0.800, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.090, 0.805, 0.900, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.420, 0.955, 1.000, 1.0);
uniform vec4 crest_color : source_color = vec4(0.800, 1.000, 1.000, 1.0);
uniform vec4 underwater_tint : source_color = vec4(0.44, 0.88, 0.96, 1.0);

uniform bool use_basin_depth = false;
uniform vec2 flow_direction = vec2(0.70710678, 0.70710678);
uniform float flow_speed : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float cross_flow_speed : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float wave_scale : hint_range(0.2, 5.0, 0.05) = 1.15;
uniform float wave_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float caustic_scale : hint_range(0.2, 6.0, 0.05) = 1.55;
uniform float caustic_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float caustic_speed : hint_range(0.0, 2.0, 0.01) = 0.42;
uniform float crest_strength : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float depth_strength : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float refraction_pixels : hint_range(0.0, 4.0, 0.05) = 1.10;
uniform float refraction_visibility : hint_range(0.0, 0.5, 0.01) = 0.20;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.98;

varying vec2 basin_uv;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = sin(dot(p, vec2(41.0, 289.0)));
	return fract(vec2(262144.0, 32768.0) * n);
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

// Distance between the closest and second-closest animated Worley sites.
// Near a cell boundary the distances converge, producing irregular organic
// caustic lines rather than a square lattice.
float cellular_edge(vec2 p, float animation_time) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 8.0;
	float second_nearest = 8.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 seed = hash22(cell + neighbour);
			vec2 moving_site = 0.5 + 0.34 * sin(
				vec2(animation_time * 0.83, animation_time * 1.07)
				+ 6.2831853 * seed
			);
			float distance_to_site = length(neighbour + moving_site - local);
			if (distance_to_site < nearest) {
				second_nearest = nearest;
				nearest = distance_to_site;
			} else if (distance_to_site < second_nearest) {
				second_nearest = distance_to_site;
			}
		}
	}

	float boundary_distance = max(second_nearest - nearest, 0.0);
	return 1.0 - smoothstep(0.028, 0.115, boundary_distance);
}

void vertex() {
	basin_uv = COLOR.rg;
}

void fragment() {
	vec2 flow = flow_direction;
	float flow_length = max(length(flow), 0.001);
	flow /= flow_length;
	vec2 cross_flow = vec2(flow.y, -flow.x);

	float time = TIME;
	vec2 primary_position = UV - flow * time * flow_speed;
	vec2 secondary_position = (
		UV
		- flow * time * flow_speed * 0.46
		+ cross_flow * time * cross_flow_speed
	);

	// Two independently moving fields create local turbulence and sideways
	// motion while the overall body still travels downstream.
	float primary_noise = value_noise(primary_position * wave_scale);
	float secondary_noise = value_noise(
		secondary_position * wave_scale * 1.73 + vec2(8.7, -3.4)
	);
	vec2 distortion = vec2(
		primary_noise - 0.5,
		secondary_noise - 0.5
	) * wave_strength;
	float turbulence = (
		(primary_noise - 0.5) * 0.62
		+ (secondary_noise - 0.5) * 0.38
	) * wave_strength;

	// Basin depth comes from geometry, not from a repeating shader pattern.
	// The centre is optically deeper, the edge shallower, and tiny turbulence
	// keeps the gradient from looking perfectly computer-generated.
	float physical_depth = 0.56;
	if (use_basin_depth) {
		float edge_distance = min(
			min(basin_uv.x, 1.0 - basin_uv.x),
			min(basin_uv.y, 1.0 - basin_uv.y)
		);
		physical_depth = smoothstep(0.015, 0.43, edge_distance);
	}
	float depth = clamp(
		physical_depth + turbulence * 0.10,
		0.0,
		1.0
	);

	vec3 base_water = mix(
		shallow_color.rgb,
		body_color.rgb,
		smoothstep(0.02, 0.48, depth)
	);
	base_water = mix(
		base_water,
		deep_color.rgb,
		smoothstep(0.46, 1.0, depth) * depth_strength
	);

	// Refract the already-rendered basin floor/walls by a little over one
	// screen pixel. Keeping this subtle preserves the crisp pixel-art scene.
	vec2 refraction_offset = distortion * SCREEN_PIXEL_SIZE * refraction_pixels;
	vec2 refracted_uv = clamp(
		SCREEN_UV + refraction_offset,
		SCREEN_PIXEL_SIZE,
		vec2(1.0) - SCREEN_PIXEL_SIZE
	);
	vec3 refracted_scene = texture(screen_texture, refracted_uv).rgb;
	refracted_scene *= underwater_tint.rgb;

	float visible_bottom = refraction_visibility;
	if (use_basin_depth) {
		visible_bottom *= mix(1.0, 0.34, depth);
	}
	vec3 water = mix(base_water, refracted_scene, visible_bottom);

	// Organic moving caustic network. Domain warping and animated Worley sites
	// avoid the rigid checkerboard that the previous version produced.
	vec2 caustic_position = (
		primary_position
		+ distortion * 0.42
		+ cross_flow * (secondary_noise - 0.5) * 0.20
	) * caustic_scale;
	float caustic = cellular_edge(
		caustic_position,
		time * caustic_speed
	);
	float caustic_breakup = mix(
		0.42,
		1.0,
		value_noise(secondary_position * 2.35 + vec2(-2.0, 5.0))
	);
	caustic *= caustic_breakup;
	caustic *= mix(1.0, 0.55, depth);
	water = mix(
		water,
		caustic_color.rgb,
		clamp(caustic * caustic_strength, 0.0, 0.62)
	);

	// Long but broken surface crests cross the downstream motion. They drift,
	// appear and dissolve instead of translating as one texture sheet.
	float down_axis = dot(primary_position, flow);
	float across_axis = dot(secondary_position, cross_flow);
	float crest_field = (
		sin(down_axis * 6.4 + distortion.x * 3.1 - time * 0.62)
		+ 0.55 * sin(across_axis * 4.8 + distortion.y * 4.0 + time * 0.37)
	);
	float crest = smoothstep(1.05, 1.48, crest_field);
	float crest_breakup = smoothstep(
		0.54,
		0.92,
		value_noise(secondary_position * 3.2 + vec2(3.0, 11.0))
	);
	crest *= crest_breakup * crest_strength;
	water = mix(
		water,
		crest_color.rgb,
		clamp(crest, 0.0, 0.48)
	);

	// Keep the material in Godot's normal CanvasItem lighting path so the
	// existing day/night modulation and local lamps continue to affect it.
	COLOR = vec4(water, opacity);
}
