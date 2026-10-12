shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Terrain Eden Eternal : couche de base + 4 couches peintes (carte de mélange RGBA)
// multipliées par la DarkMap (ombres précalculées) et la couleur des sommets.

uniform sampler2D blend_map : filter_linear, repeat_disable;
uniform sampler2D dark_map : filter_linear, repeat_disable, hint_default_white;
uniform sampler2D layer0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 repeats = vec4(4.0);   // répétitions par bloc, couches 0..3
uniform float repeat4 = 4.0;
uniform vec4 enabled = vec4(1.0);   // couches 1..4 présentes
uniform float brightness = 1.0;

void fragment() {
	if (COLOR.a < 0.5) {
		discard;  // trou dans le terrain (entrée de grotte, carrière...)
	}
	vec4 b = texture(blend_map, UV);
	vec3 c = texture(layer0, UV * repeats.x).rgb;
	c = mix(c, texture(layer1, UV * repeats.y).rgb, b.r * enabled.x);
	c = mix(c, texture(layer2, UV * repeats.z).rgb, b.g * enabled.y);
	c = mix(c, texture(layer3, UV * repeats.w).rgb, b.b * enabled.z);
	c = mix(c, texture(layer4, UV * repeat4).rgb, b.a * enabled.w);
	float dark = texture(dark_map, UV).r;
	ALBEDO = c * mix(0.35, 1.0, dark) * COLOR.rgb * brightness;
	ROUGHNESS = 1.0;
}
