shader_type canvas_item;
render_mode unshaded;

varying float canvas_x;
varying vec4 vertex_tint;

void vertex() {
	canvas_x = VERTEX.x;
	vertex_tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Keep the face and red armor bright while leaving the reaper emblem readable.
	float shoulder_fade = 1.0 - smoothstep(1040.0, 1290.0, canvas_x);
	COLOR = vec4(art.rgb, art.a * shoulder_fade) * vertex_tint;
}
