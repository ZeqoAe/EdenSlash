shader_type spatial;
// Contour du héros (lot SVX-1, Survivant) — passe 2 : le modèle gonflé de [width] pixels à l'écran, dessiné seulement hors
// de la silhouette marquée par la passe 1 (gabarit ≠ 77) et par-dessus tout (pas de test de profondeur) : un liseré net
// d'épaisseur constante, toujours visible.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 77;

uniform vec4 color : source_color = vec4(0.53, 0.87, 1.0, 1.0);
uniform float width = 2.5;  // pixels à l'écran

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float l = length(dir);
	if (l > 0.0001) {
		clip.xy += dir / l * width * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
