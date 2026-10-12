shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;
// Effets d'Eden (EdenFx) : couleurs saturées qui brillent (lueur HDR) au lieu de
// virer au blanc laiteux, léger assombrissement du fond sous les effets lumineux
// (lisibles sur un sol clair), fondu au contact du sol et des modèles (particules
// douces : plus de coupure nette dans le terrain).

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float additive = 1.0;       // 1 : effet lumineux (fond noir), 0 : mélange normal
uniform float use_vertex_color = 1.0;
uniform float intensity = 1.7;      // > 1 : lueur
uniform float saturation = 1.35;
uniform float darken = 0.15;        // assombrissement du fond sous un effet lumineux
uniform float soft = 0.5;           // distance de fondu au contact (m)

void vertex() {
	UV = UV * uv_scale + uv_offset;
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb * color.rgb;
	float a = t.a * color.a;
	if (use_vertex_color > 0.5) {
		c *= COLOR.rgb;
		a *= COLOR.a;
	}
	// particules douces
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float fade = 1.0;
#else
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 sp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -sp.z / sp.w;
	float fade = clamp((scene_z + VERTEX.z) / soft, 0.0, 1.0);
#endif
	float lum = max(c.r, max(c.g, c.b));
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, saturation);
	if (additive > 0.5) {
		// lumineux : ajouté au fond (prémultiplié), un peu assombri dessous
		ALBEDO = max(c, 0.0) * a * intensity * fade;
		ALPHA = clamp(lum * a * darken, 0.0, 1.0) * fade;
	} else {
		ALBEDO = max(c, 0.0) * a * fade;
		ALPHA = clamp(a, 0.0, 1.0) * fade;
	}
}
