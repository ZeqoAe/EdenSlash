shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// Halo au sol d'un coffre du Battle royale : disque doux qui pulse et anneau net (la zone où [F] ouvre le coffre).

uniform vec4 col : source_color = vec4(1.0, 0.85, 0.3, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float pulse = 0.65 + 0.35 * sin(TIME * 2.4);
	float disc = smoothstep(1.0, 0.0, r);
	float ring = smoothstep(0.07, 0.0, abs(r - 0.78 - 0.04 * sin(TIME * 2.4)));
	float a = (disc * disc * 0.55 * pulse + ring * 0.9) * step(r, 1.0);
	ALBEDO = col.rgb * 1.3;
	ALPHA = clamp(a, 0.0, 1.0);
}
