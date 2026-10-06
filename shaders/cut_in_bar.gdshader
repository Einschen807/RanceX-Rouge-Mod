shader_type canvas_item;
render_mode unshaded;

uniform sampler2D portrait_texture : filter_linear;
uniform bool portrait_enabled = false;
uniform vec4 accent : source_color = vec4(0.25, 0.79, 0.61, 1.0);
uniform vec4 portrait_rect = vec4(-425.0, -100.0, 1470.0, 819.0);
uniform vec2 frame_extent = vec2(1180.0, 378.0);
uniform vec2 drawer_extent = vec2(1192.0, 390.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float travel = -1.0;
uniform float portrait_push = 0.0;
uniform float flash = 0.0;
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;
uniform float slash_progress : hint_range(0.0, 1.0) = 0.0;
uniform float slash_strength : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n * 91.345 + 17.73) * 47453.5453);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 pixel = UV * drawer_extent;
	vec2 shift = travel * vec2(355.0, -135.0);
	vec2 screen = pixel - shift;
	// Screen top and left form two sides. Only the hypotenuse is drawn.
	float slope = frame_extent.y / frame_extent.x;
	vec2 direction = normalize(vec2(1.0, -slope));
	vec2 normal = vec2(-direction.y, direction.x);
	float edge = (frame_extent.y - pixel.y - pixel.x * slope) / sqrt(1.0 + slope * slope);
	float mask = smoothstep(-1.0, 1.0, edge);
	float sweep = dot(pixel, direction);
	float sweep_start = -frame_extent.y * normal.x - 12.0;
	float sweep_length = frame_extent.x * direction.x - sweep_start + 12.0;
	mask *= 1.0 - smoothstep(sweep_start + reveal * sweep_length - 10.0, sweep_start + reveal * sweep_length + 2.0, sweep);
	mask *= smoothstep(sweep_start + wipe * sweep_length - 12.0, sweep_start + wipe * sweep_length, sweep);
	mask *= step(0.001, reveal) * (1.0 - step(0.999, wipe));
	vec2 p = vec2(dot(screen, direction), dot(screen, normal));
	float v = clamp(p.y / frame_extent.y, 0.0, 1.0);
	float dark_band = smoothstep(0.38, 0.96, v);
	float grain = hash(floor(p.x / 4.0) + floor(p.y / 2.0) * 113.0);
	float hatching = 1.0 - smoothstep(0.05, 0.18, fract((p.x + p.y * 2.8) / 23.0));
	vec3 background = mix(accent.rgb * 0.23, vec3(0.018, 0.027, 0.036) + accent.rgb * 0.055, dark_band);
	background += accent.rgb * (grain * 0.022 + hatching * dark_band * 0.033);
	float opacity = mix(0.94, 0.67, dark_band);
	// Fine dark lines are slow and tightly spaced; they sit behind brighter layers.
	float lane = floor(p.y / 4.5);
	float seed = hash(lane);
	float cycle = mod(p.x - clock * (520.0 + seed * 180.0) + hash(lane + 19.0) * 1600.0, 1600.0);
	float length = 220.0 + hash(lane + 31.0) * 520.0;
	float streak = (1.0 - smoothstep(length - 24.0, length, cycle)) * smoothstep(0.0, 60.0, cycle);
	streak *= step(0.23, seed) * (1.0 - smoothstep(0.07, 0.21, abs(fract(p.y / 4.5) - 0.45)));
	background = mix(background, accent.rgb * 0.06, streak * 0.7);
	// Medium accent strokes move roughly twice as fast and have irregular lengths.
	float medium_lane = floor(p.y / 17.0);
	float medium_seed = hash(medium_lane + 8.0);
	float medium_cycle = mod(p.x - clock * (1100.0 + medium_seed * 300.0) + medium_seed * 1800.0, 1800.0);
	float medium_body = smoothstep(0.0, 70.0, medium_cycle) * (1.0 - smoothstep(350.0, 620.0, medium_cycle));
	float medium_stroke = 1.0 - smoothstep(0.035, 0.095, abs(fract(p.y / 17.0) - 0.30 - medium_seed * 0.35));
	background += accent.rgb * medium_body * medium_stroke * step(0.27, medium_seed) * 0.62;
	// Sparse thick white-accent lines are fastest, with a faint wider glow.
	float impact_lane = floor(p.y / 49.0);
	float impact_seed = hash(impact_lane + 111.0);
	float impact_cycle = mod(p.x - clock * (2200.0 + impact_seed * 500.0) + impact_seed * 1600.0, 1600.0);
	float impact_length = 280.0 + hash(impact_lane + 18.0) * 580.0;
	float impact_body = smoothstep(0.0, 80.0, impact_cycle) * (1.0 - smoothstep(impact_length - 90.0, impact_length, impact_cycle));
	float impact_width = 0.035 + impact_seed * 0.038;
	float impact_distance = abs(fract(p.y / 49.0) - (0.2 + impact_seed * 0.5));
	float impact_stroke = 1.0 - smoothstep(impact_width * 0.45, impact_width, impact_distance);
	float impact_glow = 1.0 - smoothstep(impact_width, impact_width * 2.8, impact_distance);
	background += mix(accent.rgb, vec3(0.87, 0.99, 0.98), 0.76) * impact_body * (impact_stroke * 0.92 + impact_glow * 0.10) * step(0.22, impact_seed);
	opacity = max(opacity, clamp(medium_body * medium_stroke * 0.9 + impact_body * impact_stroke, 0.0, 1.0));
	vec3 result = background;
	if (portrait_enabled) {
		vec2 portrait_position = portrait_rect.xy + portrait_push * vec2(310.0, -145.0);
		vec2 uv = (pixel - portrait_position) / portrait_rect.zw;
		vec4 art = texture(portrait_texture, clamp(uv, vec2(0.0), vec2(1.0)));
		art.a *= step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
		// Composite an opaque portrait over the translucent background.
		float combined_alpha = art.a + opacity * (1.0 - art.a);
		result = (art.rgb * art.a + result * opacity * (1.0 - art.a)) / max(combined_alpha, 0.001);
		opacity = combined_alpha;
	}
	// A single outlined diagonal; there are no inset top/left frame edges.
	float black_rim = 1.0 - smoothstep(-0.5, 1.0, edge);
	result = mix(result, vec3(0.008, 0.012, 0.018), black_rim);
	float rim = (1.0 - smoothstep(1.3, 3.5, edge)) * smoothstep(-0.2, 0.9, edge);
	result = mix(result, mix(accent.rgb, vec3(0.97), 0.72), rim);
	float stripe = 1.0 - smoothstep(0.0, 1.3, abs(edge - 7.0));
	result = mix(result, accent.rgb, clamp(stripe * 0.9, 0.0, 1.0));
	opacity = max(opacity, max(black_rim, max(rim, stripe)));
	// Three converging etched accents carry the eye toward the needle-like tip.
	float tip_zone = smoothstep(frame_extent.x * 0.65, frame_extent.x * 0.86, pixel.x);
	float chevron_lane = mod(pixel.x + pixel.y * 1.8, 72.0);
	float chevron = (1.0 - smoothstep(1.0, 3.0, abs(chevron_lane - 35.0))) * tip_zone * (1.0 - smoothstep(10.0, 40.0, edge));
	result += mix(accent.rgb, vec3(0.85, 0.98, 1.0), 0.7) * chevron * 0.55;
	// Two brief foreground slashes sweep over both portrait and frame at entry.
	float slash_center = mix(-300.0, frame_extent.x + 430.0, slash_progress);
	float slash_distance = abs(sweep - slash_center);
	float slash_tail = smoothstep(-360.0, -100.0, sweep - slash_center) * (1.0 - smoothstep(0.0, 16.0, sweep - slash_center));
	float slash_edge = 1.0 - smoothstep(1.5, 4.5, abs(edge - 13.0));
	float slash_inner = 1.0 - smoothstep(1.0, 3.0, abs(edge - 62.0));
	float slash = (slash_edge + slash_inner * 0.72) * slash_tail * slash_strength;
	float slash_glow = exp(-slash_distance / 100.0) * exp(-abs(edge - 13.0) / 14.0) * slash_strength;
	result = mix(result, vec3(0.91, 1.0, 1.0), clamp(slash, 0.0, 1.0));
	result += vec3(0.70, 0.97, 1.0) * slash_glow * 0.24;
	opacity = max(opacity, clamp(slash + slash_glow * 0.4, 0.0, 1.0));
	float head = exp(-abs(sweep - (sweep_start + reveal * sweep_length)) / 18.0) * (1.0 - reveal);
	result += vec3(0.85, 0.96, 1.0) * head * 0.6;
	result = mix(result, vec3(0.96, 1.0, 0.99), clamp(flash, 0.0, 1.0));
	COLOR = vec4(result, mask * opacity) * tint;
}
