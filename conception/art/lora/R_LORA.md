# R_LORA : modèle de style (LoRA), chaîne d'entraînement et premiers essais (17/10/2026)

Département LORA (`ORGANISATION.md`). **Rien n'est intégré au jeu** : ce sont des outils et des essais à juger.

## À regarder
| Fichier | Quoi |
|---|---|
| `v0b/planche_comparaison.jpg` | **le LoRA retenu** (héros, monstres, icônes) : mêmes prompts, mêmes graines, sans LoRA puis intensités 0,5 / 0,8 / 1,0 |
| `v0b/planche_etapes.jpg` | le même prompt aux pas 500 / 1000 / 1500 / 2000 (sur-apprentissage) |
| `v0b/planche_memoire.jpg` | légendes d'images d'entraînement redonnées telles quelles (le LoRA recopie-t-il ?) |
| `v0/planche_comparaison.jpg` | 1er essai, entraîné sur des décors (paysages, villages, combat) |
| `v0b/jeu_de_donnees.jpg`, `v0/jeu_de_donnees.jpg` | les images d'entraînement |
| `DATASET.md` | la procédure du jeu de données |

## Outils retenus (hors dépôt, `C:\AI`)
- **Entraîneur : kohya-ss/sd-scripts** (`C:\AI\sd-scripts`, commit 690ea7f du 24/09/2026), venv dédié `C:\AI\venv_train`
  (Python 3.12.8, PyTorch 2.11.0 + CUDA 12.8, accelerate 1.15.0, transformers 5.17.0, diffusers 0.40.0, bitsandbytes 0.50.2).
  Versions relevées à chaque entraînement dans `mesures.json`.
  `C:\Users\Nico\kohya_ss` (interface graphique v25.2.1 de juin 2025) **n'était pas installée** (ni venv ni sous-module
  sd-scripts) : laissée telle quelle ; la ligne de commande sd-scripts suffit, se pilote par script et marche du premier coup
  sur la RTX 5070 (Blackwell, capacité 12.0).
- **Modèle de base : SDXL base 1.0** (`stabilityai/stable-diffusion-xl-base-1.0`, accès libre, non restreint), licence
  **CreativeML Open RAIL++-M** : usage commercial permis, avec des restrictions d'usage (pas de contenus illégaux, trompeurs, etc.)
  à reporter sur les œuvres dérivées. Fichier `C:\AI\ComfyUI\models\checkpoints\sd_xl_base_1.0.safetensors` (6,94 Go). VAE
  `sdxl_vae_fp16_fix` (madebyollin, MIT, 0,33 Go) téléchargé en réserve, non utilisé (entraînement en bf16).
  Écartés : FLUX.1-schnell (déjà installé, distillé : s'entraîne mal), FLUX.1-dev et SD 3.5 (accès restreint / licence non
  commerciale ou communautaire), dérivés SDXL « anime » (Illustrious, Pony, Animagine : données d'entraînement douteuses ou
  licences à clauses), Juggernaut (licence commerciale restrictive).
- **Génération : ComfyUI** (déjà installé par G1) avec le workflow `tools/art/workflows/sdxl_lora.json` ; SDXL base vérifié
  (1216 × 832, 30 pas, dpmpp_2m karras, cfg 6,5 : 8 à 18 s par image selon la charge de la carte).

## Scripts (`tools/art/`)
| Script | Rôle |
|---|---|
| `lora_dataset.py` | captures du jeu (copie propre de HEAD, dossier utilisateur à part) : `--portraits` (héros, bustes, monstres : `godot/lora_studio.gd`), `--capture` (décors : `godot/lora_capture.gd`) ; puis `--list <json>` fait le dossier d'entraînement (image + légende) et la planche |
| `train_lora.py <config.toml>` | lance sd-scripts d'après la configuration (`lora_v0.toml`, `lora_v0b.toml`), libère d'abord la VRAM de ComfyUI, relève durée, VRAM au plus haut, perte (`perte.csv`, `perte.png`), versions (`mesures.json`) ; `--dry-run`, `--report-only` |
| `gen_with_lora.py` | génération en série via l'API de ComfyUI : `--lora`, `--strengths 0,0.5,0.8,1.0` (0 = nœud retiré, image exacte du modèle de base), `--prompts`, `--seeds`, `--grid` (planche) |

Réglages communs (fichier TOML) : rang 32, alpha 16, U-Net seul (encodeurs de texte figés, sorties en cache), AdamW 8 bits,
lr 1e-4 cosinus (100 pas d'échauffement), 2 000 pas, lot de 1, bf16, gradient checkpointing, SDPA, latents en cache, min-SNR 5,
bucketing sans agrandissement, sauvegarde tous les 500 pas. Mot-clé `edenstyle`.

## Mesures
| | v0 (décors) | v0b (héros, monstres, icônes) |
|---|---|---|
| Images | 52 (10 cartes + 42 captures de décor) | 60 (20 héros, 10 bustes, 22 monstres, 4 planches d'icônes, 4 cartes) |
| Durée | **52 min** (2 000 pas, 1,5-1,6 s / pas ; 0,83 s / pas seul sur la carte, au test de 40 pas) | **58 min** (2 000 pas ; 4 à 4,7 s / pas pendant 20 min où la carte et la RAM étaient prises par d'autres agents, puis 1,6 s / pas) |
| VRAM | 7,8 Go pour l'entraînement seul (test) ; 11,0 Go au plus haut pour toute la carte (autres programmes compris) | 11,8 Go au plus haut pour toute la carte (2,5 Go déjà pris avant le départ) |
| Perte moyenne (début, milieu, fin) | 0,114 / 0,087 / 0,095 | 0,106 / 0,096 / 0,094 |
| Fichier | 170 Mo (bf16) | 170 Mo |

La perte d'un modèle de diffusion bouge peu et ne dit pas grand-chose du résultat : c'est la planche qui juge.
Pendant les deux entraînements, la carte était partagée avec d'autres agents (simulations Godot, ComfyUI) : d'où 1,5 s / pas au
lieu de 0,8. Seul sur la carte, un entraînement de 2 000 pas prend **≈ 28 min**.

## Résultats, honnêtement
### v0 (décors)
- **Le style passe, et fort** : dès 0,5, lumière laiteuse, brume pastel, herbe saturée, maisons rondes du jeu, rendu « 3D toon »
  au lieu de l'illustration ou de la photo de SDXL. À 0,8-1,0 les images ressemblent à des captures du jeu.
- **Sur-apprentissage du contenu** dès 0,8 : un village **enneigé** devient un village vert (la neige n'existe pas dans le jeu de
  données), le dragon de glace est posé sur un sol volcanique, le chevalier devient une de nos héroïnes chibi aux longs cheveux.
  Le LoRA a appris « le jeu » (ses décors) plus qu'un style transposable.
- Intensité utile : **0,5 à 0,7**.

### v0b (DA colorée : héros, monstres, icônes)
- **Le style du jeu passe, très nettement** : chibi en 3D toon, grands yeux bleus, contours nets, couleurs vives, villages aux
  toits ronds, lumière douce du jeu. Sans LoRA, SDXL dessine de l'illustration anime « à plat » ; dès 0,5 on obtient des
  personnages qui pourraient sortir du jeu (chevalière, mage garçon, buste, dragon : `planche_comparaison.jpg`).
- **Intensité à retenir : 0,5** avec le fichier final (`eden_style_v0b.safetensors`), **ou l'étape 500 à 0,8**
  (`eden_style_v0b-step00000500.safetensors`, installée dans ComfyUI) : le style est là et le prompt est encore obéi
  (cheveux roses, neige, ailes du dragon).
- **Sur-apprentissage dès l'étape 1 000 / l'intensité 0,8** (`planche_etapes.jpg`) : les cheveux roses deviennent bruns (le jeu de
  données n'a que 6 couleurs de cheveux), la neige disparaît au profit des prairies vertes, le dragon perd ses ailes, tous les
  visages convergent vers **le** visage du jeu (même bouche, mêmes yeux). Pour la v1 : ≈ 1 000 pas suffisent avec 60 images.
- **Pas de recopie** (`planche_memoire.jpg`) : redonner la légende exacte d'une image d'entraînement donne une image nouvelle dans le
  même style (barde à la guitare, champignon rose), pas l'image d'origine.
- Icônes : planches d'icônes au trait du jeu (tuiles grises arrondies, objets brillants), mais la grille demandée (4 × 4) n'est
  pas respectée et les icônes sont petites : à recadrer, ou un LoRA « icônes » à part avec des icônes seules agrandies proprement.
- Paysages : le village enneigé reste enneigé jusqu'à 0,8 (peu de décors dans ce jeu de données, au contraire de la v0).

## Limites
- Le LoRA apprend **l'allure actuelle du jeu** (rendu 3D toon de nos modèles), pas encore une illustration peinte : pour des cartes
  d'activité ou un écran titre « illustrés », il faudra des images d'illustration validées dans le jeu de données (v1).
- SDXL base n'est pas un modèle « anime » : sans LoRA il tire vers l'illustration occidentale ou la photo ; le LoRA corrige,
  mais les visages et les mains restent fragiles en plan large. Un dérivé anime à licence propre pourrait aider (à vérifier
  modèle par modèle, voir Écartés).
- Aucun texte lisible, comptes approximatifs (grilles d'icônes « 4 × 4 » non respectées), petits détails (mains, armes) à reprendre.
- Captures : les héros sont tous rendus avec le corps de base du jeu (personnages féminins chibi) ; le LoRA ne sait donc pas
  dessiner un héros masculin dans notre style sans le décrire.

## Disque
Dans `C:\AI` : venv d'entraînement 4,9 Go, SDXL base 6,9 Go + VAE 0,3 Go, sd-scripts 46 Mo, copie de HEAD pour les captures
(`lora_snap`) 2,8 Go, captures et jeux de données ≈ 0,3 Go, sorties (4 fichiers de 170 Mo par LoRA, journaux) ≈ 1,6 Go, LoRA copiés dans `ComfyUI\models\loras` 0,5 Go :
**≈ 18 Go** (budget 25). À supprimer sans risque : `lora_snap` (refait en 30 s), les étapes intermédiaires des LoRA.
Dans le dépôt : ≈ 3 Mo (planches JPG, listes, scripts).

## Entraîner la v1 (quand la bible v2 et les choix du joueur seront prêts)
1. Mettre dans le jeu de données les **images validées par le joueur** (planches de la DA, illustrations retenues) en plus des
   portraits : nouvelle liste `dataset_v1.json` (source `fichier`), légendes à la main selon `DATASET.md`.
2. Équilibrer : ≈ 40 % illustrations validées, 30 % héros / monstres, 15 % icônes, 15 % décors **variés** (ajouter neige, nuit,
   intérieurs pour éviter le « tout vert » de la v0).
3. Copier `tools/art/lora_v0b.toml` en `lora_v1.toml` (chemins, nom) ; garder rang 32, mais **1 000 pas** (`pas = 1000`,
   `sauver_tous_les = 250`) : la v0b sur-apprend dès 1 000 ; comparer les étapes sur la planche plutôt que de réentraîner.
4. `C:\AI\venv_train\Scripts\python.exe tools/art/train_lora.py tools/art/lora_v1.toml` (≈ 15 min seul sur la carte pour 1 000 pas).
5. Planche : `C:\AI\venv_comfy\Scripts\python.exe tools/art/gen_with_lora.py --lora C:/AI/lora_out/eden_style_v1/eden_style_v1.safetensors --strengths 0,0.5,0.8,1.0 --prompts tools/art/lora_prompts_v0b.json --seeds 11,22 --out <dossier> --grid`
6. Variante « interface » (boutons, cadres) : LoRA séparé, jeu de données de pièces d'interface détourées sur fond uni, à ne pas
   mélanger avec l'illustration.
