shader_type canvas_item;
// Subtle breathing for a full-body standing portrait drawn on a padded rect.
// The legs stay fixed; from the hips up the body is lifted a few pixels on each
// inhale (the torso stretches slightly) and the chest widens a hair.
uniform sampler2D portrait : filter_linear_mipmap, repeat_disable;
// Fraction of the rect above the image, so the lifted head is never clipped.
uniform float pad = 0.02;
// Head lift as a fraction of the image height.
uniform float amp = 0.0042;
uniform float period = 3.8;
// Image-space heights: chest band and the hips below which nothing moves.
uniform float chest = 0.26;
uniform float hips = 0.5;
uniform float body_center = 0.45;
uniform float widen = 0.0035;

void fragment() {
	float y = (UV.y - pad) / (1.0 - pad);
	float breath = 0.5 - 0.5 * cos(TIME * 6.2831853 / period);
	vec2 uv = vec2(UV.x, y + amp * breath * smoothstep(hips, chest, y));
	float band = exp(-pow((y - chest) / 0.09, 2.0));
	uv.x = body_center + (uv.x - body_center) / (1.0 + widen * breath * band);
	vec4 color = texture(portrait, uv);
	if (uv.y < 0.0 || uv.y > 1.0) color.a = 0.0;
	COLOR = color * COLOR;
}
