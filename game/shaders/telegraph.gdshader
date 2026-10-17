// Télégraphes v2 (lot DNG-2, bible § 10) : intérieur d'une zone d'attaque au sol, hachures en diagonale (lisibles sans la
// couleur) sur un voile léger ; pour une zone immense (anneau autour d'un cercle sûr), le voile s'efface en s'éloignant du
// bord intérieur : on peint la frontière du sûr, pas tout l'écran.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform vec4 tint : source_color = vec4(1.0, 0.302, 0.427, 1.0);
uniform float base_alpha = 0.06;
uniform float hatch_alpha = 0.24;
uniform float hatch_width = 0.36;
uniform float period = 1.3;
uniform vec3 center = vec3(0.0);
uniform float inner_r = 0.0;
uniform float fade_len = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = fract((wpos.x + wpos.z) / period);
	float h = step(s, hatch_width);
	float a = base_alpha + hatch_alpha * h;
	if (fade_len > 0.0) {
		float d = distance(wpos.xz, center.xz) - inner_r;
		a *= clamp(1.0 - d / fade_len, 0.0, 1.0);
	}
	ALBEDO = tint.rgb;
	ALPHA = a * tint.a;
}
