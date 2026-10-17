shader_type canvas_item;
// Panneau « autocollant » de l'interface (bible de style v2, § 5) : rectangle arrondi par SDF, contour d'encre,
// face en deux tons nets (cel) avec reflet clair en haut, léger relief (liseré clair sous le contour), trame de points
// dans le bas, ombre dure d'encre décalée vers le bas, lueur intérieure animable. Posé sur un ColorRect qui couvre le
// panneau (UiTheme.StickerPanel) ; sans shader, UiTheme.StickerBox donne le même dessin en StyleBoxFlat.

uniform vec2 size = vec2(400.0, 300.0);
uniform float radius = 18.0;
uniform float border = 3.0;
uniform float shadow = 7.0;
uniform vec4 fill : source_color = vec4(1.0, 0.973, 0.925, 1.0);
uniform vec4 light : source_color = vec4(1.0);
uniform vec4 dark : source_color = vec4(0.914, 0.875, 0.796, 1.0);
uniform vec4 ink : source_color = vec4(0.133, 0.102, 0.227, 1.0);
uniform float cel_top = 0.06;
uniform float cel_bottom = 0.22;
uniform float trame = 0.10;
uniform float trame_pitch = 7.0;
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.886, 0.478, 1.0);

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * size;
	vec2 face_size = vec2(size.x, size.y - shadow);
	vec2 c = face_size * 0.5;
	float aa = 1.0;
	float d_face = sd_round_box(px - c, c, radius);
	float d_shadow = sd_round_box(px - c - vec2(0.0, shadow), c, radius);
	// ombre dure d'encre
	vec4 col = vec4(ink.rgb, ink.a * (1.0 - smoothstep(-aa, aa, d_shadow)));
	// face : trois tons nets
	float y = px.y / face_size.y;
	vec3 face = fill.rgb;
	if (y < cel_top) {
		face = light.rgb;
	} else if (y > 1.0 - cel_bottom) {
		face = dark.rgb;
		// trame manga dans la bande d'ombre
		vec2 cell = mod(px, trame_pitch) - vec2(trame_pitch * 0.5);
		float dot_m = 1.0 - smoothstep(0.6, 1.4, length(cell));
		face = mix(face, ink.rgb, dot_m * trame);
	}
	// relief : liseré clair juste sous le contour, en haut
	float rim = (1.0 - smoothstep(0.0, 2.0, abs(d_face + border + 2.0))) * (1.0 - smoothstep(0.15, 0.45, y));
	face = mix(face, vec3(1.0), rim * 0.55);
	// lueur intérieure (survol, mise en avant)
	float g = glow * (1.0 - smoothstep(0.0, 14.0, -d_face - border));
	face = mix(face, glow_color.rgb, g * 0.6);
	float inside = 1.0 - smoothstep(-aa, aa, d_face);
	col = mix(col, vec4(face, fill.a), inside);
	// contour d'encre
	float edge = (1.0 - smoothstep(-aa, aa, d_face)) * smoothstep(-border - aa, -border + aa, d_face);
	col = mix(col, vec4(ink.rgb, 1.0), edge * ink.a);
	COLOR = col;
}
