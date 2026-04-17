shader_type canvas_item;

// This grabs the pixels behind the UI element
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Sliders for you to adjust in the Inspector!
uniform float blur_amount : hint_range(0.0, 5.0) = 4.5;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // Black with 60% opacity

void fragment() {
	// Blurs the background
	vec4 bg = textureLod(screen_texture, SCREEN_UV, blur_amount);
	// Mixes the blur with your dark tint color
	COLOR = mix(bg, tint_color, tint_color.a);
}