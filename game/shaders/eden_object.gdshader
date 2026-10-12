shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;
// Décor d'Eden : texture + transparence par seuil, ombrage toon, et « trou »
// tramé autour du héros quand l'objet se trouve entre lui et la caméra.

global uniform vec2 hero_screen;      // position du héros à l'écran (0..1)
global uniform float hero_depth;      // distance caméra -> héros
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_cutoff = 0.0;     // 0 = opaque
uniform float use_vertex_color = 0.0;
uniform float hole_radius = 0.15;
uniform float near_fade = 7.0;        // décor collé à la caméra : masqué

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	if (use_vertex_color > 0.5) {
		tex.rgb *= COLOR.rgb;
	}
	if (alpha_cutoff > 0.0 && tex.a < alpha_cutoff) {
		discard;
	}
	// trou autour du héros pour ce qui est devant lui
	vec2 uv = FRAGCOORD.xy / VIEWPORT_SIZE;
	vec2 d = (uv - hero_screen) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float depth = -VERTEX.z;
	if (depth < near_fade && near_fade / max(depth, 0.01) - 1.0 > bayer4(FRAGCOORD.xy)) {
		discard;
	}
	if (depth < hero_depth - 1.5) {
		float fade = 1.0 - smoothstep(hole_radius * 0.6, hole_radius, length(d));
		if (fade > bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	ALBEDO = tex.rgb;
	ROUGHNESS = 1.0;
}
