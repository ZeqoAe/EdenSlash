// Éclairage stylisé moderne (personnages, monstres, décor) : passage ombre / lumière
// doux, ombres teintées (bleu-violet) au lieu de noires, contour lumineux (rim) côté
// soleil et petit reflet. Inclus par eden_character et eden_object.

uniform vec3 shadow_tint : source_color = vec3(0.8, 0.78, 0.9);
uniform float ramp_soft = 0.22;
uniform float rim_strength = 0.4;
uniform float spec_strength = 0.12;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-ramp_soft, ramp_soft, ndl) * ATTENUATION;
	vec3 l = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += l * mix(shadow_tint * 0.9, vec3(1.0), lit);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * smoothstep(-0.2, 0.5, ndl);
	vec3 h = normalize(LIGHT + VIEW);
	float sp = smoothstep(0.82, 0.9, pow(max(dot(NORMAL, h), 0.0), 24.0));
	SPECULAR_LIGHT += l * (rim * rim_strength + sp * spec_strength) * ATTENUATION;
}
