shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
// Sphère d'énergie tourbillonnante (Ninja du Tourbillon, lot CHR-1) : cœur clair, bandes en spirale qui tournent
// autour de l'axe vertical et glissent vers les pôles, liseré au bord (Fresnel). Additif : rien de noir, jamais opaque.
// Réglages : couleur, vitesse de rotation, nombre de bras de la spirale, intensité (fondu d'apparition / disparition).

uniform vec3 core_color : source_color = vec3(0.92, 0.98, 1.0);
uniform vec3 swirl_color : source_color = vec3(0.35, 0.72, 1.0);
uniform float spin = 6.0;      // tours de la spirale (rad/s)
uniform float arms = 5.0;      // bras de la spirale
uniform float twist = 7.0;     // enroulement vers les pôles
uniform float intensity = 1.0; // 0 = invisible
uniform float rim_power = 2.2;

varying vec3 v_local;

void vertex() {
	v_local = normalize(VERTEX);
}

void fragment() {
	vec3 p = v_local;
	float ang = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	// spirale : bandes fines qui tournent (le temps) et s'enroulent avec la latitude
	float band = sin(ang * arms + lat * twist - TIME * spin);
	float band2 = sin(ang * (arms + 2.0) - lat * twist * 0.6 + TIME * spin * 1.7);
	float swirl = smoothstep(0.55, 1.0, band) + 0.55 * smoothstep(0.7, 1.0, band2);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float core = pow(facing, 3.0);
	vec3 col = core_color * core * 0.9 + swirl_color * (swirl * 1.2 + rim * 1.8);
	ALBEDO = col * intensity;
	ALPHA = clamp((core * 0.8 + swirl * 0.6 + rim) * intensity, 0.0, 1.0);
}
