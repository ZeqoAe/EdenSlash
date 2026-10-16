shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Personnages et monstres d'Eden : texture d'origine, couleurs un peu ravivées,
// transparence par seuil (cheveux, accessoires), éclairage stylisé (eden_light).
// EdenModel.stylize remplace « cull_back » pour les matériaux double face.

#include "res://shaders/eden_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_cut = 0.0;      // 0 = opaque
uniform float use_vertex_color = 0.0;
uniform float saturation = 1.2;
// recoloration (costumes d'Eden) : masque de teinture R/V/B × 3 couleurs choisies, détails
// par-dessus — même calcul que l'export (tools/nif2gltf.py, bake_dyed), en sRGB
uniform float use_dye = 0.0;
uniform sampler2D dye_mask : filter_linear_mipmap;
uniform sampler2D dye_decal : filter_linear_mipmap;
uniform float use_decal = 0.0;
uniform vec3 dye0 = vec3(1.0);
uniform vec3 dye1 = vec3(1.0);
uniform vec3 dye2 = vec3(1.0);
// parties sans masque d'une pièce recolorée (lueurs, plumes d'énergie) : teinte sur la luminosité
uniform float use_tint = 0.0;
uniform vec3 tint = vec3(1.0);
// couleur des yeux du héros (création de personnage, HeroLook) : masque des iris, teinte gardant leur dégradé
uniform float use_eye = 0.0;
uniform sampler2D eye_mask : filter_linear_mipmap;
uniform vec3 eye_color = vec3(1.0);

void fragment() {
	vec4 t = texture(albedo_tex, UV) * albedo_color;
	if (use_dye > 0.5) {
		vec4 m = texture(dye_mask, UV);
		vec3 c = clamp(m.r * dye0 + m.g * dye1 + m.b * dye2, 0.0, 1.0);
		if (use_decal > 0.5) {
			vec4 d = texture(dye_decal, UV);
			c = mix(c, d.rgb, d.a);
		}
		t = vec4(pow(c, vec3(2.2)), m.a) * albedo_color;
	}
	if (use_tint > 0.5) {
		float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		t.rgb = clamp(pow(tint, vec3(2.2)) * l * 2.2, 0.0, 1.0);
	}
	if (use_eye > 0.5) {
		float k = texture(eye_mask, UV).r;
		float v = max(t.r, max(t.g, t.b));
		t.rgb = mix(t.rgb, clamp(pow(eye_color, vec3(2.2)) * v * 1.9, 0.0, 1.0), k);
	}
	if (use_vertex_color > 0.5) {
		t.rgb *= COLOR.rgb;
	}
	if (alpha_cut > 0.0 && t.a < alpha_cut) {
		discard;
	}
	ALBEDO = mix(vec3(dot(t.rgb, vec3(0.299, 0.587, 0.114))), t.rgb, saturation);
	ROUGHNESS = 0.6;
}
