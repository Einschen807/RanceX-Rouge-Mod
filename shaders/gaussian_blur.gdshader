shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float blur_pixels = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Separable Gaussian: horizontal pass, explicit screen copy, vertical pass.
	// Dense samples avoid the visible ghost outlines of widely spaced taps.
	vec2 step_uv = direction * SCREEN_PIXEL_SIZE * (blur_pixels / 5.0);
	vec3 result = vec3(0.0);
	float total = 0.0;
	for (int i = -15; i <= 15; i++) {
		float weight = exp(-float(i * i) / 50.0);
		result += texture(screen_texture, SCREEN_UV + step_uv * float(i)).rgb * weight;
		total += weight;
	}
	result /= total;
	COLOR = vec4(result * (1.0 - darkness), 1.0);
}
