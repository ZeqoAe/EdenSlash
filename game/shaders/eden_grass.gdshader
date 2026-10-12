shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Brins d'herbe instanciés (GrassField) : couleur prise sur la texture d'herbe du
// terrain sous la touffe (mêmes variations que le sol), vent, brins couchés autour du
// héros, base sombre (occlusion) et pointe éclairée par transparence.

global uniform vec3 hero_world;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 6.0;
uniform vec3 tint = vec3(1.0);
uniform float brightness = 0.86;
uniform float wind_strength = 0.16;
uniform vec2 wind_dir = vec2(0.8, 0.45);
uniform float fade_start = 26.0;     // distance à la caméra où les brins rapetissent
uniform float fade_end = 38.0;

varying vec3 root;

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

void vertex() {
	root = MODEL_MATRIX[3].xyz;
	float t = UV.y;  // 0 au pied, 1 à la pointe
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// rapetisse au loin (pas de bord net de la zone d'herbe)
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float shrink = 1.0 - smoothstep(fade_start, fade_end, distance(cam.xz, root.xz));
	// vent : rafales lentes + frémissement
	float gust = sin(TIME * 1.3 + root.x * 0.21 + root.z * 0.17) * 0.6 + sin(TIME * 3.7 + root.x * 1.3 + root.z * 0.9) * 0.25;
	vec3 disp = vec3(wind_dir.x, 0.0, wind_dir.y) * gust * wind_strength * t * t;
	// couché par le héros
	vec2 away = root.xz - hero_world.xz;
	float push = 1.0 - smoothstep(0.4, 1.4, length(away));
	disp.xz += normalize(away + vec2(0.001)) * push * 0.45 * t;
	disp.y -= push * 0.25 * t;
	world += disp;
	world.y = mix(root.y, world.y, shrink);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec3 g = texture(tex_grass, root.xz / tile).rgb;
	float m = fbm(root.xz * 0.012);
	g *= mix(0.78, 1.13, m);
	g *= tint * brightness;
	// petite variation par touffe (plus jaune / plus verte)
	float v = hash(floor(root.xz * 3.0));
	g *= mix(vec3(0.94, 1.0, 0.9), vec3(1.08, 1.04, 0.86), v);
	ALBEDO = g * mix(0.84, 1.06, UV.y);
	// les deux faces sont éclairées comme le sol (pas de brins noirs vus de dos)
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	BACKLIGHT = g * 0.2 * UV.y;
	ROUGHNESS = 0.85;
}
