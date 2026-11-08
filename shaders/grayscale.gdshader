shader_type canvas_item;
// Locked level pictures: grey and a bit dim. amount 1 = grey, 0 = full color.

uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(grey) * 0.75, amount), c.a);
}