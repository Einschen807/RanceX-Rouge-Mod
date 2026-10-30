shader_type canvas_item;
// Gothic-lolita display cloth: black-violet velvet with a faint damask lattice,
// double silver trim and a scalloped white lace hem with eyelets.
uniform vec2 size = vec2(1340.0, 880.0);
uniform vec4 velvet_top : source_color = vec4(0.17, 0.07, 0.14, 0.95);
uniform vec4 velvet_bottom : source_color = vec4(0.05, 0.025, 0.06, 0.96);
uniform vec4 pattern : source_color = vec4(0.85, 0.62, 0.95, 1.0);
uniform vec4 trim : source_color = vec4(0.78, 0.72, 0.84, 0.9);
uniform vec4 lace : source_color = vec4(0.95, 0.92, 0.96, 0.93);
uniform float lace_depth = 30.0;
uniform float scallop = 30.0;

void fragment() {
	vec2 p = UV * size;
	float body_bottom = size.y - lace_depth;
	vec4 color = mix(velvet_top, velvet_bottom, UV.y);
	// Damask lattice: diamonds with a dot at each crossing.
	vec2 q = p / 72.0;
	vec2 r = vec2(q.x + q.y, q.x - q.y);
	vec2 f = abs(fract(r) - 0.5);
	float diamond = smoothstep(0.035, 0.0, abs(f.x + f.y - 0.36));
	float dots = smoothstep(0.07, 0.03, length(fract(q) - 0.5));
	color.rgb += (diamond * 0.045 + dots * 0.05) * pattern.rgb;
	// Velvet sheen fading toward the edges.
	vec2 c = UV - vec2(0.5, 0.42);
	color.rgb *= 1.0 - 0.35 * dot(c, c) * 2.2;
	// Double silver trim inset from the edges.
	float inset = min(min(p.x, size.x - p.x), min(p.y, body_bottom - p.y));
	float lines = smoothstep(1.6, 0.2, abs(inset - 14.0)) + 0.55 * smoothstep(1.0, 0.0, abs(inset - 21.0));
	color.rgb = mix(color.rgb, trim.rgb, clamp(lines, 0.0, 1.0) * trim.a);
	if (p.y > body_bottom) {
		// Scalloped lace hem with an eyelet in each scallop.
		float cx = mod(p.x, scallop) - scallop * 0.5;
		float dy = p.y - body_bottom;
		float shape = smoothstep(scallop * 0.56, scallop * 0.56 - 1.5, length(vec2(cx, dy)));
		float hole = smoothstep(3.6, 2.2, length(vec2(cx, dy - scallop * 0.24)));
		float edge = smoothstep(1.2, 0.0, abs(length(vec2(cx, dy)) - scallop * 0.47)) * 0.25;
		color = vec4(lace.rgb - edge, lace.a * shape * (1.0 - hole));
	}
	COLOR = color;
}
