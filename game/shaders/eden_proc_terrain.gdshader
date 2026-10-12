shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Terrain généré dans la DA d'Eden : herbe de base, herbe 2 (R), terre (G),
// chemin (B), roche selon la pente ; ombre des arbres précalculée (A).
// Rendu modernisé : textures sans répétition visible (deux échelles mélangées par un
// bruit), variations de teinte à grande échelle, transitions selon le relief des
// textures, relief éclairé tiré de la texture (bump), occlusion au pied des arbres.

uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_size = vec2(512.0);
uniform float tile = 6.0;          // mètres par répétition de texture
uniform vec3 tint = vec3(1.0);
uniform float bump = 0.18;         // profondeur du relief tiré des textures (m)
uniform float macro = 0.22;        // variations de teinte à grande échelle
uniform float saturation = 1.0;
uniform float brightness = 0.86;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 17.0) * 0.3 + vnoise(p * 4.1 + 41.0) * 0.15;
}

// Texture sans motif répété : deux échelles tournées, mélangées par un bruit.
vec3 untiled(sampler2D t, vec2 uv, float n) {
	vec3 a = texture(t, uv).rgb;
	vec2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.43 + vec2(0.37, 0.71);
	vec3 b = texture(t, r).rgb;
	return mix(a, b, smoothstep(0.35, 0.65, n));
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Mélange selon le « relief » des textures : la couche la plus haute l'emporte.
vec3 hblend(vec3 a, float ha, vec3 b, float hb, float w) {
	float depth = 0.18;
	float ma = max(ha + 1.0 - w, hb + w) - depth;
	float b1 = max(ha + 1.0 - w - ma, 0.0);
	float b2 = max(hb + w - ma, 0.0);
	return (a * b1 + b * b2) / max(b1 + b2, 1e-4);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	float n = vnoise(world_pos.xz * 0.09);
	vec4 s = texture(splat_map, world_pos.xz / map_size);
	vec3 g1 = untiled(tex_grass, uv, n);
	vec3 g2 = untiled(tex_grass2, uv * 0.7, 1.0 - n);
	vec3 dirt = untiled(tex_dirt, uv, n);
	vec3 road = untiled(tex_road, uv * 0.8, n);
	vec3 c = hblend(g1, luma(g1), g2, luma(g2), s.r);
	c = hblend(c, luma(c), dirt, luma(dirt) + 0.1, s.g);
	c = hblend(c, luma(c) * 0.8, road, luma(road) + 0.15, s.b);
	float slope = 1.0 - world_normal.y;
	float rock = smoothstep(0.22, 0.38, slope + (n - 0.5) * 0.08);
	vec3 rk = texture(tex_rock, world_pos.xy / (tile * 1.5)).rgb;
	c = mix(c, rk, rock);
	// variations à grande échelle : zones plus sombres / plus dorées
	float m = fbm(world_pos.xz * 0.012);
	float m2 = fbm(world_pos.xz * 0.035 + 9.0);
	c *= mix(1.0 - macro, 1.0 + macro * 0.6, m);
	c = mix(c, c * vec3(1.08, 1.02, 0.82), smoothstep(0.55, 0.85, m2) * macro * 2.0 * (1.0 - s.b));
	// ombre des arbres, plus douce et colorée
	c *= mix(vec3(1.0), vec3(0.58, 0.64, 0.72), s.a);
	c = mix(vec3(luma(c)), c, saturation) * brightness * tint;
	ALBEDO = c;
	// relief tiré de la texture (dérivées écran), atténué au loin pour éviter le scintillement
	float h = luma(c);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	float fade = 1.0 - smoothstep(18.0, 45.0, -VERTEX.z);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump * fade * grad);
	ROUGHNESS = mix(0.92, 0.75, s.b);
	SPECULAR = 0.25;
	AO = mix(1.0, 0.55, s.a);
	AO_LIGHT_AFFECT = 0.3;
}
