shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;
// Eau stylisée : légères vagues, reflets du ciel, transparence.

uniform vec4 deep_color : source_color = vec4(0.12, 0.38, 0.55, 0.78);
uniform vec4 shallow_color : source_color = vec4(0.35, 0.72, 0.8, 0.6);
uniform float wave_speed = 0.6;

float wave(vec2 p, float t) {
	return sin(p.x * 0.7 + t) * 0.5 + sin(p.y * 0.9 - t * 1.3) * 0.5;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float w = wave(world.xz, t) * 0.5 + wave(world.xz * 2.3 + 7.0, t * 1.7) * 0.25;
	NORMAL = normalize(NORMAL + vec3(w * 0.08, 0.0, -w * 0.08));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 col = mix(deep_color, shallow_color, w * 0.25 + 0.5);
	ALBEDO = col.rgb + fres * 0.25;
	ALPHA = col.a;
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
}
