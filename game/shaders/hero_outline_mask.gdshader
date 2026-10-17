shader_type spatial;
// Contour du héros (lot SVX-1, Survivant) — passe 1 : rien de visible ; marque la silhouette du héros dans le tampon de
// gabarit (stencil), même cachée derrière des monstres, un boss, des effets ou le décor (pas de test de profondeur).
// La passe 2 (hero_outline.gdshader, next_pass) dessine le liseré autour de cette silhouette.
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
stencil_mode write, compare_always, 77;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
