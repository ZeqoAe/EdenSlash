shader_type spatial;
render_mode unshaded, fog_disabled, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled;
// Effets d'Eden (EdenFx) : couleurs saturées qui brillent (lueur HDR) au lieu de
// virer au blanc laiteux, léger assombrissement du fond sous les effets lumineux
// (lisibles sur un sol clair), fondu au contact du sol et des modèles (particules
// douces : plus de coupure nette dans le terrain).

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);  // décalage (u, v) de la texture, après l'échelle autour du centre
uniform float uv_rot = 0.0;         // rotation de la texture autour de son centre (radians, auras)
// Enroulement de la texture (Gamebryo) : 3 répétée, 0 bloquée au bord, 1 U bloqué, 2 V bloqué.
// Une texture d'effet bloquée et zoomée en arrière montre un seul motif, pas une planche de 3 × 3.
uniform int wrap_mode = 3;
// Masque (« dark map » de Gamebryo, multiplie la texture : bords des panneaux effacés) et texture de
// détail (× 2), chacun avec sa propre transformation et son enroulement (auras, tools/fx_aura_fix.py).
uniform sampler2D dark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_dark = 0.0;
uniform vec2 dark_scale = vec2(1.0);
uniform vec2 dark_offset = vec2(0.0);
uniform float dark_rot = 0.0;
uniform int dark_wrap = 3;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_detail = 0.0;
uniform vec2 detail_scale = vec2(1.0);
uniform vec2 detail_offset = vec2(0.0);
uniform float detail_rot = 0.0;
uniform int detail_wrap = 3;
varying vec2 dark_uv;
varying vec2 detail_uv;
uniform float additive = 1.0;       // 1 : effet lumineux (fond noir), 0 : mélange normal
uniform float use_vertex_color = 1.0;
uniform float intensity = 1.7;      // > 1 : lueur
uniform float saturation = 1.35;
uniform float darken = 0.15;        // assombrissement du fond sous un effet lumineux
uniform float soft = 0.5;           // distance de fondu au contact (m)
uniform float darken_curve = 1.0;   // > 1 : seules les parties vives assombrissent le fond (auras)
uniform float lum_mix = 0.0;        // 1 : la luminosité sert d'opacité, couleur pleine (auras sur décor clair)
// Sorts (spell = 1) : la texture garde son relief (contraste), le fond est assombri sous le
// corps de l'effet (burn) pour que la couleur tienne sur un sol clair, et le cœur brûlant
// passe en lumière HDR (core) : la lueur ne vient que du centre, pas de voile laiteux.
uniform float spell = 0.0;
uniform float tex_contrast = 1.0;
uniform float burn = 0.6;
uniform float core = 2.0;
// Teinture (auras) : rgb = couleur voulue, a = force (0 : couleurs d'origine). La couleur
// remplace la teinte en gardant les nuances (clair / sombre) de l'effet.
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);
// Opacité d'ensemble (0 à 1) : 1 partout, sauf les sorts du héros en Survivant (EdenFx.opacity).
uniform float opacity = 1.0;

// Transformation « 3ds Max » de Gamebryo (NiTextureTransform::MAX_TRANSFORM) : autour du centre de la
// texture, rotation puis échelle, puis décalage [param off] (non tourné : une texture tournée d'un quart
// de tour défile toujours en U).
vec2 uv_xf(vec2 uv, vec2 sc, vec2 off, float rot) {
	vec2 p = uv - 0.5;
	if (rot != 0.0) {
		float cr = cos(rot);
		float sr = sin(rot);
		p = vec2(cr * p.x - sr * p.y, sr * p.x + cr * p.y);
	}
	return p * sc + 0.5 + off;
}

// Enroulement : coordonnées bloquées au bord (à un demi-texel près) selon le mode.
vec2 uv_wrap(vec2 uv, int mode, ivec2 size) {
	if (mode != 3) {
		vec2 h = 0.5 / vec2(size);
		if (mode != 2) { uv.x = clamp(uv.x, h.x, 1.0 - h.x); }
		if (mode != 1) { uv.y = clamp(uv.y, h.y, 1.0 - h.y); }
	}
	return uv;
}

void vertex() {
	dark_uv = uv_xf(UV, dark_scale, dark_offset, dark_rot);
	detail_uv = uv_xf(UV, detail_scale, detail_offset, detail_rot);
	UV = uv_xf(UV, uv_scale, uv_offset, uv_rot);
}

void fragment() {
	vec4 t = texture(tex, uv_wrap(UV, wrap_mode, textureSize(tex, 0)));
	if (use_dark > 0.5) {
		t *= texture(dark_tex, uv_wrap(dark_uv, dark_wrap, textureSize(dark_tex, 0)));
	}
	if (use_detail > 0.5) {
		vec4 d = texture(detail_tex, uv_wrap(detail_uv, detail_wrap, textureSize(detail_tex, 0)));
		t.rgb *= d.rgb * 2.0;
		t.a *= d.a;
	}
	t.rgb = pow(max(t.rgb, vec3(0.0)), vec3(tex_contrast));
	vec3 c = t.rgb * color.rgb;
	float a = t.a * color.a;
	if (use_vertex_color > 0.5) {
		c *= COLOR.rgb;
		a *= COLOR.a;
	}
	if (tint.a > 0.0) {
		float tl = max(c.r, max(c.g, c.b));
		c = mix(c, tint.rgb * tl * 1.15, tint.a);
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
	if (additive > 0.5 && spell > 0.5) {
		float cov = clamp(lum * a, 0.0, 1.0);
		float body = smoothstep(0.03, 0.55, cov) * fade;
		vec3 hue = max(c, 0.0) / max(lum, 0.001);
		// cœur : dans la teinte du sort (pas blanc), seules les parties les plus vives
		vec3 deep = pow(hue, vec3(2.2));
		vec3 glow = mix(deep, hue, cov) * pow(cov, 2.0) * intensity * core * fade;
		ALBEDO = deep * body * 0.8 + glow;
		ALPHA = body * burn;
	} else if (additive > 0.5) {
		// lumineux : ajouté au fond (prémultiplié), un peu assombri dessous…
		vec3 add_c = max(c, 0.0) * a * intensity * fade;
		float add_a = clamp(pow(clamp(lum * a, 0.0, 1.0), darken_curve) * darken, 0.0, 1.0) * fade;
		// … ou couleur pleine posée selon la luminosité (lisible sur un décor clair)
		float o = clamp(pow(clamp(lum * a, 0.0, 1.0), 1.6) * 1.5, 0.0, 1.0) * fade;
		vec3 full = max(c, 0.0) / max(lum, 0.001);
		vec3 mix_c = full * o * 0.85 + max(c, 0.0) * a * intensity * 0.35 * fade;
		ALBEDO = mix(add_c, mix_c, lum_mix);
		ALPHA = mix(add_a, o * 0.85, lum_mix);
	} else {
		ALBEDO = max(c, 0.0) * a * fade;
		ALPHA = clamp(a, 0.0, 1.0) * fade;
	}
	// opacité plafonnée (Survivant, lot SVX-1 : sorts du héros à 40 % au plus) ; alpha prémultiplié : tout est mis à l'échelle
	ALBEDO *= opacity;
	ALPHA *= opacity;
}
