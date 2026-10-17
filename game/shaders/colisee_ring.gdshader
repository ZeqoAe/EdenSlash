// Anneau de feu du Colisée (lot CO-B, BIBLE § 10) : disque posé au sol de l'arène ; dehors (au-delà de `radius`) un voile
// mandarine à `out_alpha` au plus, bord net blanc + liseré mandarine foncé, prochain anneau en pointillés qui défilent.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float radius = 22.0;
uniform float next_radius = -1.0;  // < 0 : pas d'annonce
uniform float extent = 30.0;  // rayon du disque (m)
uniform float edge = 0.16;  // épaisseur du bord blanc (m)
uniform vec4 fire : source_color = vec4(1.0, 0.541, 0.122, 1.0);  // mandarine base
uniform vec4 fire_dark : source_color = vec4(0.784, 0.373, 0.031, 1.0);  // mandarine foncé
uniform float out_alpha = 0.32;
uniform float pulse = 0.0;  // 0..1 : resserrement en cours (le voile s'avive)

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float d = length(local_pos.xz);
	float aa = fwidth(d) * 1.2;
	vec4 col = vec4(0.0);
	// voile dehors, plus dense près du bord, borné à out_alpha (+ un peu pendant le resserrement)
	float outside = smoothstep(radius - aa, radius + aa, d);
	float near = 1.0 - clamp((d - radius) / 6.0, 0.0, 1.0);
	float a_out = outside * (out_alpha * (0.55 + 0.45 * near) + 0.08 * pulse);
	col = mix(col, vec4(fire.rgb, a_out), outside);
	// liseré foncé juste dehors, puis bord blanc net
	float dark = smoothstep(radius + edge, radius + edge + aa, d) * (1.0 - smoothstep(radius + edge * 2.6, radius + edge * 2.6 + aa, d));
	col = mix(col, vec4(fire_dark.rgb, 0.85), dark);
	float white = smoothstep(radius - edge - aa, radius - edge, d) * (1.0 - smoothstep(radius + edge, radius + edge + aa, d));
	col = mix(col, vec4(1.0, 1.0, 1.0, 0.95), white);
	// prochain anneau : pointillés blancs qui défilent
	if (next_radius > 0.0 && next_radius < radius - 0.5) {
		float ang = atan(local_pos.z, local_pos.x);
		float dash = step(0.5, fract(ang * next_radius / 1.4 + TIME * 0.6));
		float band = smoothstep(next_radius - edge * 0.8 - aa, next_radius - edge * 0.8, d) * (1.0 - smoothstep(next_radius + edge * 0.8, next_radius + edge * 0.8 + aa, d));
		col = mix(col, vec4(1.0, 1.0, 1.0, 0.85), band * dash);
	}
	// rien au-delà du disque
	col.a *= 1.0 - smoothstep(extent - 2.0, extent, d);
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
