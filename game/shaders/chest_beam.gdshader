shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// Faisceau de lumière d'un coffre du Battle royale (Interactable.add_chest_aura) : fort au pied, il s'éteint vers le
// haut et scintille doucement. Additif, sans lumière dynamique.

uniform vec4 col : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float height = 12.0;
uniform float strength = 0.9;

varying float t;

void vertex() {
	t = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float edge = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.2);
	float fade = pow(1.0 - t, 0.9) * smoothstep(1.0, 2.6, t * height);  // rien dans le coffre lui-même
	float flick = 0.8 + 0.2 * sin(TIME * 2.6 + t * 9.0) * sin(TIME * 1.3 + 1.7);
	ALBEDO = col.rgb * 1.4;
	ALPHA = clamp(strength * fade * edge * flick, 0.0, 1.0);
}
