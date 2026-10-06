shader_type canvas_item;
render_mode unshaded;

uniform float reveal = 0.0;
uniform float wipe = 0.0;
uniform float flash = 0.0;
uniform bool silhouette = false;
uniform bool black_matte = false;
uniform float focus_x = 0.46;
uniform vec4 flash_color : source_color = vec4(0.89, 0.97, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.36, 0.70, 1.0, 1.0);

varying vec4 vertex_tint;

void vertex() {
	// Fragment COLOR already contains TEXTURE on a TextureRect. Preserve only
	// the vertex modulation so the portrait retains the source image brightness.
	vertex_tint = COLOR;
}

void fragment() {
	vec4 tint = vertex_tint;
	vec4 art = texture(TEXTURE, UV);
	// Match the supplied pure-black matte without modifying the source artwork.
	float matte = black_matte ? smoothstep(0.0, 0.008, max(art.r, max(art.g, art.b))) : 1.0;
	float opening = smoothstep(-0.025, 0.025, reveal - abs(UV.x - focus_x));
	float departure = 1.0 - smoothstep(wipe - 0.025, wipe + 0.025, 1.0 - UV.x);
	float bottom = 1.0 - smoothstep(0.84, 1.0, UV.y);
	vec3 color = silhouette ? accent.rgb : mix(art.rgb, flash_color.rgb, flash);
	COLOR = vec4(color, art.a * matte * opening * (1.0 - departure) * bottom) * tint;
}
