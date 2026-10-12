class_name Gfx
extends RefCounted
## Rendu « moderne » partagé par la run et les menus : tonemapping, occlusion ambiante,
## lueur, brume en hauteur, ombres douces, selon la qualité graphique choisie dans les
## paramètres (basse, moyenne, haute, ultra). Le moteur de compatibilité (OpenGL) ignore
## ce qu'il ne sait pas faire (SSAO, SSIL).

const QUALITIES := ["low", "medium", "high", "ultra"]
## Densité de l'herbe 3D selon la qualité (0 : pas d'herbe).
const GRASS := {"low": 0.0, "medium": 0.5, "high": 1.0, "ultra": 1.5}


static func quality() -> String:
	var q := String(Settings.get_v("display", "quality"))
	return q if q in QUALITIES else "high"


static func level() -> int:
	return QUALITIES.find(quality())


static func grass_density() -> float:
	return float(GRASS.get(quality(), 1.0))


## Réglages d'image communs (à appeler après avoir choisi ciel et brume du biome).
static func style_environment(env: Environment) -> void:
	var q := level()
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.25
	# occlusion ambiante : contact au sol, creux des modèles, pieds des arbres
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = q >= 3
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	# lueur : seuls les effets et les reflets très lumineux brillent
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	# brume : le lointain prend la couleur du ciel (perspective aérienne)
	env.fog_height_density = 0.0
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.35


static func style_sun(sun: DirectionalLight3D) -> void:
	var q := level()
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.0 if q < 2 else 0.8  # ombres douces (PCSS)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])


## Ciel : soleil visible, dégradé plus riche.
static func style_sky(sky_mat: ProceduralSkyMaterial) -> void:
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	sky_mat.sky_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.1
	sky_mat.ground_curve = 0.04
