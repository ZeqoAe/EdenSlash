shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Terrain généré dans la DA d'Eden : herbe de base, herbe 2 (R), terre (G),
// chemin (B), roche selon la pente ; ombre des arbres précalculée (A).

uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_size = vec2(512.0);
uniform float tile = 6.0;          // mètres par répétition de texture
uniform vec3 tint = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = world_pos.xz / tile;
	vec4 s = texture(splat_map, world_pos.xz / map_size);
	vec3 c = texture(tex_grass, uv).rgb;
	c = mix(c, texture(tex_grass2, uv * 0.7).rgb, s.r);
	c = mix(c, texture(tex_dirt, uv).rgb, s.g);
	c = mix(c, texture(tex_road, uv * 0.8).rgb, s.b);
	float slope = 1.0 - world_normal.y;
	float rock = smoothstep(0.22, 0.38, slope);
	c = mix(c, texture(tex_rock, world_pos.xy / (tile * 1.5)).rgb, rock);
	ALBEDO = c * mix(1.0, 0.62, s.a) * tint;
	ROUGHNESS = 1.0;
}
