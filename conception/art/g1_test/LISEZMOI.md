# G1 : essai de génération d'assets (ComfyUI local, 17/10/2026)

Étape de faisabilité. **Rien n'est intégré au jeu** : le joueur valide d'abord.

## À regarder
| Fichier | Quoi |
|---|---|
| `echiquier.jpg`, `survivant.jpg`, `quetes.jpg`, `arenes_3v3.jpg`, `battle_royale.jpg` | cartes d'activité 960 × 320 (même format que `game/assets/ui/activities/`), la meilleure de 4 graines |
| `variantes/planche_20_variantes.jpg` | les 20 essais (4 graines par carte) |
| `coffre.glb` + `coffre_source.jpg`, `coffre_4_vues.jpg`, `coffre_apercu_blender.jpg` | coffre au trésor 3D texturé, image source générée par FLUX |
| `coffre2.glb` + `coffre2_source.jpg`, `coffre2_4_vues.jpg` | 2e coffre (réglage par défaut actuel) |
| `epee.glb` + `epee_source.jpg`, `epee_4_vues.jpg` | épée longue 3D texturée |
| `variantes/coffre_reduction_ratee_30k.jpg`, `coffre_geometrie_reduction_150k.jpg` | pourquoi la réduction de maillage se fait en deux temps (voir Limites) |

## Installation (hors dépôt)
- `C:\AI\ComfyUI` : ComfyUI 0.41.0 (mis à jour du 30/03 au 16/10/2026 par `git pull`, aucune modification locale perdue).
- `C:\AI\venv_comfy` : Python 3.12.8, PyTorch 2.11.0 + CUDA 12.8 (RTX 5070, capacité 12.0, calcul GPU vérifié).
- Lanceur : `C:\AI\Lancer_ComfyUI.bat` (écoute 127.0.0.1:8188 seulement).
- Nœuds désactivés (dossiers renommés `.disabled`, réversibles) : LTXVideo, WanVideoWrapper, faceswap. Les autres (Manager, GGUF,
  Impact-Pack/Subpack, IPAdapter_plus, VideoHelperSuite, Frame-Interpolation) sont à jour et se chargent sans erreur.
- Modèles (`C:\AI\ComfyUI\models`, ≈ 32 Go, tous libres d'accès sur Hugging Face, dépôts Comfy-Org) :
  - image : `checkpoints/flux1-schnell-fp8.safetensors` (FLUX.1-schnell, Apache 2.0, 17,2 Go, encodeurs T5 / CLIP et VAE inclus) ;
  - 3D (nœuds natifs de ComfyUI, Pixal3D / TRELLIS.2, licences MIT) : `diffusion_models/pixal3d_int8_convrot` (5,6 Go),
    `diffusion_models/trellis_2_int8_convrot` (5,3 Go, variante non utilisée par défaut), `vae/trellis_2_shape_vae_bf16` (1,1 Go),
    `vae/trellis_2_texture_vae_bf16` (0,95 Go), `clip_vision/dino_v3_L_naf_fp32` (1,2 Go), `geometry_estimation/moge_2_vitl_normal_fp16`
    (0,66 Go), `background_removal/birefnet` (0,44 Go).

## Images (FLUX.1-schnell fp8, 4 pas, euler / simple, cfg 1)
Généré en 1536 × 640 puis recadré au centre et réduit en 960 × 320 (JPG 90, 58-105 Ko).
**Temps : 7 à 15 s par image, 10,3 s en moyenne** (20 images) ; ~19 s pour la toute première (chargement du modèle).
**VRAM : 8-10 Go** pendant la génération (modèle de 11,3 Go chargé en partie, le reste en RAM ; pic mesuré 11,9 Go sur 12,2).

Suffixe de style ajouté à chaque prompt (`tools/art/comfy_gen.py`, `STYLE`) :
`stylized 3D fantasy MMORPG game art, anime toon shading, soft painterly lighting, rich saturated colors, midnight blue and gold palette,
highly detailed, cinematic wide shot, no text, no watermark, no logo, no UI`

| Carte | Graine retenue | Prompt (début ; complet dans `tools/art/prompts_activites.json`) |
|---|---|---|
| L'Échiquier | 1101 | A wise robed strategist seen from behind, standing before a huge golden hexagonal game board … grand circular fantasy arena at dusk |
| Survivant | 2205 | A lone hero with a glowing golden sword standing on a small rocky hill … surrounded by an endless horde of fantasy monsters |
| Quêtes | 3303 | Still life of rolled parchment quest scrolls … red and gold wax seals, an old fantasy map, a feather quill … guild hall |
| Arènes 3v3 | 4407 | Two teams of three fantasy heroes facing each other inside a grand circular colosseum arena … |
| Battle royale | 5505 | High aerial view of a lush fantasy island … a gigantic glowing blue magical storm wall closing in … |

Graines voisines : 1101-1104, 2202-2205, 3303-3306, 4404-4407, 5505-5508 (planche).

## 3D (image -> GLB texturé)
Chaîne : image FLUX (objet seul sur fond gris clair, 1024²) -> détourage BiRefNet -> MoGe (champ de vision) -> Pixal3D (structure,
forme, sur-échantillonnage 1024 par défaut, texture) -> remaillage 768 -> réduction QEM 150 000 faces -> dépliage UV -> textures 2048
(couleur, métal / rugosité, normales cuites depuis le haut détail, occlusion ambiante) -> GLB. Puis Blender 5.2 en arrière-plan
(`tools/art/glb_cleanup.py`) : réduction à 25 000 / 15 000 triangles, origine au centre de la base, hauteur 0,8 m (coffre) / 1,1 m (épée),
textures JPEG.

| Objet | Graine | Temps ComfyUI | Fichier final |
|---|---|---|---|
| Épée | 56 | **2 min 27 s** (objet fin, sur-échantillonnage 1536) | `epee.glb` 2,1 Mo, 14 992 triangles, 0,25 × 0,27 × 1,1 m |
| Coffre 2 | 7 | **12 min 25 s** (sur-échantillonnage 1024 : 3 passes d'échantillonnage ≈ 7 min, réduction QEM 3 min 35 s, cuisson 18 s) | `coffre2.glb` 3,3 Mo, 24 938 triangles, 0,8 m de haut |
| Coffre | 56 | 21 min 40 s au 1er essai (sur-échantillonnage 1536, 1er chargement, réduction ratée), 3 min 14 s en reprenant le cache | `coffre.glb` 3,3 Mo, 24 826 triangles, 0,91 × 0,8 (haut) × 0,92 m |

VRAM : jusqu'à 11,9 Go (carte pleine). **Piège** : un objet massif (coffre) avec un sur-échantillonnage 1536 peut déborder de la VRAM
(1er essai du coffre 2 : 250 s par pas au lieu de 8, arrêté au bout de 12 min) ; le workflow est donc réglé à 1024 par défaut
(qualité très proche, voir `coffre2_4_vues.jpg`) ; 1536 pour un objet fin : `--set "94.target_resolution=1536"`.
**Import Godot 4.7.2 vérifié** (projet de brouillon, `--headless --import` puis chargement) : 1 MeshInstance3D, StandardMaterial3D
avec couleur 2048², normales, métal / rugosité et occlusion ; boîte englobante posée au sol (y = 0) et centrée.

## Qualité, honnêtement
Forces
- FLUX : composition et lumière de qualité « illustration de jeu », palette bleu nuit et or respectée, très rapide (10 s).
- 3D : la forme du coffre est remarquable (ferrures, rivets, serrure, pieds) ; texture peinte cohérente avec l'image ; GLB propre.

Faiblesses
- Les illustrations sont plus sombres, plus « peinture numérique » et plus chargées que les cartes actuelles (qui sont des vues
  du jeu, claires et calmes) : ça se voit si on les mélange. Un LoRA de style ou des prompts « bright daylight » corrigeraient.
- FLUX compte mal : plateau octogonal au lieu d'hexagonal, 3 contre 3 rarement respecté (graine 4404 : 6 contre 6), faux texte
  possible sur les objets (runes de l'épée).
- Personnages génériques (pas les classes du jeu) : il faudrait un LoRA ou une image de référence (IPAdapter, déjà installé).
- 3D : objet incliné quand l'image source est en perspective (l'épée penche un peu de profil) ; dessous et dos inventés ;
  pas de squelette (objets fixes seulement : coffres, armes posées, décor) ; textures un peu sombres (métal à 1 sur tout l'objet,
  à régler dans Godot ou Blender si besoin).
- Réduire trop fort dans ComfyUI casse le maillage (30 000 faces en une fois : forme en éclats, voir `variantes/`) : garder
  150 000 dans ComfyUI puis réduire dans Blender.

## Relancer
1. `C:\AI\Lancer_ComfyUI.bat` (ou l'interface : http://127.0.0.1:8188).
2. Cartes d'activité (dossier du dépôt) :
   `C:\AI\venv_comfy\Scripts\python.exe tools/art/comfy_gen.py --batch tools/art/prompts_activites.json --out conception/art/essais --resize 960x320 --jpg 90`
   (une seule : `--prompt "..." --seed 1234 --width 1536 --height 640 --name nom`).
3. Objet 3D : image d'objet seul sur fond uni, puis
   `C:\AI\venv_comfy\Scripts\python.exe tools/art/comfy_gen.py --workflow image_to_3d_pixal3d --image objet.png --seed 56 --name objet --out <dossier>`
   et `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/art/glb_cleanup.py -- objet.glb objet_propre.glb 0.8 25000 apercu.png`.
4. Workflows enregistrés (format API de ComfyUI) : `tools/art/workflows/flux_schnell.json`, `image_to_3d_pixal3d.json` ;
   le script repère les nœuds par leur titre (PROMPT, SIZE, SAMPLER, IMAGE, FACES, SAVE). Pour essayer TRELLIS.2 au lieu de Pixal3D :
   `--set "319.unet_name=\"trellis_2_int8_convrot.safetensors\""` (et remplacer la condition Pixal3D par `Trellis2Conditioning`).

## Coût disque
venv 6,3 Go + modèles 31 Go (32,5 Go téléchargés, budget 45) + ComfyUI 0,7 Go + sorties ≈ 0,3 Go : **≈ 38 Go** dans `C:\AI`.
Dans le dépôt : ce dossier ≈ 10 Mo. Gagner 5,3 Go : supprimer `models/diffusion_models/trellis_2_int8_convrot.safetensors` (inutilisé par défaut).

## Pour aller plus loin
- **LoRA de style** (Kohya, `C:\Users\Nico\kohya_ss`) entraîné sur 30-60 captures du jeu / cartes d'activité : rapprocherait la lumière
  et les couleurs des cartes actuelles (FLUX.1-schnell se prête mal à l'entraînement : prévoir FLUX.1-dev, sous licence non commerciale
  et à accès restreint, ou un modèle SDXL d'illustration).
- **Agrandissement** : un modèle 4x (ESRGAN / UltraSharp, ~65 Mo) pour des illustrations plein écran ou des fonds de menu.
- **Textures PBR / tuiles** pour le terrain et le décor (FLUX + nœud de tuilage, ou génération de cartes de normales).
- **Effets et sprites** (auras, impacts, icônes de sorts) : FLUX sur fond noir puis détourage BiRefNet (déjà installé), planches d'animation.
- **Tenues / apparences** : IPAdapter (installé) pour garder un personnage d'une image à l'autre ; la 3D animée (squelette) reste hors de portée.
- **Objets 3D en série** : prompts d'objet seul sur fond gris -> `image_to_3d_pixal3d` -> `glb_cleanup.py` (≈ 3 à 12 min par objet).
