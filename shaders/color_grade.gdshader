shader_type canvas_item;
// A room's colour grade (see scripts/color_grade.gd), over everything drawn
// below its layer: on a full-screen rect, it reads the screen and regrades it.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 shadow_tint : source_color = vec3(1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0);
uniform bool use_lut = false;
uniform sampler2D lut : filter_linear;
uniform float lut_strength = 1.0;
// Toward grey, on top of the grade: the room drains on your last heart.
uniform float desaturate = 0.0;

const float LUT_SIZE = 16.0;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// A 256x16 strip of sixteen 16x16 squares: red across a square, green down
// it, blue from square to square (blended between the two nearest).
vec3 apply_lut(vec3 c) {
	float b = c.b * (LUT_SIZE - 1.0);
	float s0 = floor(b);
	float s1 = min(s0 + 1.0, LUT_SIZE - 1.0);
	vec2 uv = vec2((c.r * (LUT_SIZE - 1.0) + 0.5) / (LUT_SIZE * LUT_SIZE), (c.g * (LUT_SIZE - 1.0) + 0.5) / LUT_SIZE);
	vec3 low = texture(lut, uv + vec2(s0 / LUT_SIZE, 0.0)).rgb;
	vec3 high = texture(lut, uv + vec2(s1 / LUT_SIZE, 0.0)).rgb;
	return mix(low, high, b - s0);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb * brightness;
	c = (c - 0.5) * contrast + 0.5;
	float luma = dot(c, LUMA);
	c = mix(vec3(luma), c, saturation);
	c *= mix(shadow_tint, highlight_tint, smoothstep(0.0, 1.0, luma));
	c = clamp(c, 0.0, 1.0);
	if (use_lut) {
		c = mix(c, apply_lut(c), lut_strength);
	}
	c = mix(c, vec3(dot(c, LUMA)), desaturate);
	COLOR = vec4(c, 1.0);
}
