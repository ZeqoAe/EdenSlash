# PRP : chaîne de production des objets 3D (armes, ailes de dos)

Département PRP (`ORGANISATION.md`). Procédure reproductible « idée -> image -> objet 3D -> nettoyage Blender -> GLB + fiche »,
éprouvée par le lot PRP-1 (`R_PRP1.md`, planche `prp/planche.jpg`) et reprise par le lot PRP-2 (`R_PRP2.md`, planche `prp/planche2.jpg`) qui
a mis 24 créations dans le jeu (étape `game`).

## Vue d'ensemble
| Étape | Outil | Commande (`C:\AI\venv_comfy\Scripts\python.exe tools/art/prp_pipeline.py …`) | Sortie | Temps mesuré |
|---|---|---|---|---|
| 0. Fiche | à la main | `tools/art/prp_assets.json` : id, nom français, emplacement, type, rareté, prompt, négatif, graines | — | — |
| 1. Image | SDXL base 1.0 + LoRA `eden_style_v0b` à 0,5 (ComfyUI) | `images [--only id,id]` | `C:\AI\prp1_raw\img\<id>_s<graine>.png`, détourage `_iso.png` (RGBA), planche `var_<id>.jpg` | 11 à 14 s par image |
| 2. Choix | l'œil | graine retenue dans la fiche (`"graine": 108`) | — | 1 min par objet |
| 3. Objet 3D | Pixal3D (ComfyUI, workflow `image_to_3d_pixal3d`) | `mesh` | `C:\AI\prp1_raw\mesh\<id>_hi.glb` (≈ 150 000 faces, textures 2048) | 2 min 30 à 4 min (2 min 52 en moyenne) |
| 4. Nettoyage | Blender 5.2 en arrière-plan (`tools/art/prp_blender.py`) | `clean` | `conception/art/prp/candidats/<id>.glb` + `<id>.json`, aperçu `render\<id>_vue.png` | 15 s de calcul (20 s à 2 min avec démarrage et aperçu, processeur partagé) |
| 5. Contrôle | Godot 4.7.2, projet de brouillon `C:\AI\prp1_godot` | `godot` | `render\<id>_godot.png` (sur le héros), `<id>_distance.png` (caméra du jeu), `godot_controle.txt` | 30 s pour 12 |
| 6. Icônes | Pillow (rendu Blender de l'étape 4) | `icon` | `render\<id>_icone128.png` / `_icone64.png` (tuile autocollante) | 1 s |
| 7. Planche | Pillow | `sheet` | `conception/art/prp/planche2.jpg` (≤ 500 Ko, objets seuls), `prp/mesures.json` | 2 s |
| 8. Jeu | copie + table | `game` | `game/assets/weapons/prp/<id>.glb`, `game/assets/player/outfits/back_prp_*.glb` (+ `.import` : textures en Basis Universal), `game/assets/ui/items/<id>.png` (128) et `<id>_64.png`, `game/data/prp_looks.json` | 1 s |
| — | lecture des GLB du jeu | `measure` | longueur, prise, W1 / W2 médianes par type d'arme (remplit `types`) | 2 s |

`all` enchaîne tout ; chaque étape est reprenable (un résultat présent n'est pas refait ; `--force` pour le refaire).
Journal brut de toutes les mesures (temps, VRAM de la carte avant / au plus haut) : `C:\AI\prp1_raw\mesures.jsonl`.

## Format attendu par le jeu (mesuré sur les armes et accessoires existants)
- **Arme** (`EdenModel.attach_weapon`) : la pièce est accrochée à l'os `Bip01 Prop1`, sinon `Bip01 R Hand` (arc : `Bip01 L Hand`) par un
  `BoneAttachment3D` ; le nœud racine **`EdenRoot`** du GLB est remis à l'identité : la géométrie est donc lue **dans le repère de l'os**.
  Dans ce repère : **lame / hampe vers +Z**, origine = **la main** (milieu de la poignée), largeur sur X, épaisseur sur Y.
  Nœuds vides **`W1`** (base de la lame) et **`W2`** (pointe) : la traînée d'arme (`Player._blade_base / _blade_tip`).
  Une arme de plus de 2,7 unités est réduite par le jeu (`MAX_WEAPON_SIZE`).
- Longueur et prise par type (médiane des 4 modèles du jeu, unités de l'os, `prp_assets.json` → `types`) :
  épée 1,16 (prise à la garde), espadon 2,01, katana 1,93, hache 1,54 (13 %), marteau 1,70 (16 %), bâton 1,75 (41 %), sceptre 1,23 (26 %),
  lance 2,59 (20 %). Le héros est ensuite agrandi ×1,3 (`GameData.HERO_SCALE`).
- **Dos** (`EdenModel.dress`) : un fichier dont le nom commence par `back_` (mais pas `back_l`) et **sans squelette** est un accessoire
  rigide accroché à l'os **`Bip01 Spine1`** (haut du dos), `EdenRoot` remis à l'identité. Repère de l'os : **X = haut** (le long du
  dos), **Y = devant** (le héros regarde +Y de l'os), Z = côté. Le dos du corps est à y ≈ -0,09 ; nos ailes touchent y = -0,08, centre
  0,10 au-dessus de l'os, envergure 1,9 à 2,3 (les ailes du jeu : 2,6 à 3,2).
- **Matériau** : le jeu remplace tout matériau opaque par `eden_character.gdshader` (`EdenModel.stylize`), qui ne lit **que la texture de
  couleur** (et la couleur de base) ; métal, rugosité, normales et occlusion du GLB sont ignorés. On ne livre donc qu'une texture de
  couleur, avec l'occlusion **multipliée dedans** (creux lisibles) et une saturation ×1,15 ; métal 0.
- Export : GLB sans conversion d'axes (`export_yup=False`) ; `EdenRoot` porte une rotation de -90° sur X pour qu'un visualiseur glTF
  montre l'objet debout (le jeu l'annule). Texture JPEG 1024 (qualité 88), ramenée à 512 si le GLB dépasse 1,5 Mo.

## Budgets (PRP-2, décision de la coordination : 20 héros en Battle royale)
| | Triangles | Poids | Texture |
|---|---|---|---|
| Arme | ≤ 3 000 (visé 2 880) | ≤ 600 Ko | 512² couleur seule, aplats |
| Ailes, dos | ≤ 5 000 la paire (visé 4 800) | ≤ 600 Ko | 512² couleur seule, aplats |
PRP-1 visait 8 000 / 12 000 et 1024². Les armes du jeu font 300 à 1 000 triangles, 12 à 30 Ko, texture 512². Une fiche peut demander
moins (`"triangles": 2000`). Mesure de coût en jeu : `res://tools/prp_perf.tscn` (20 héros, aucun / ailes d'Eden / maison).

**Aplats** (`flatten`, PRP-2) : la texture SDXL a des reflets « jouet verni ». Après la cuisson : valeur lissée (médiane 7×7) et tirée
vers 5 paliers, reflets écrasés au-dessus de 0,78, saturation des reflets rendue d'après les voisins ; métal 0, rugosité 1.
**Ailes battantes** (`"battement": true` sur le type `wings`) : la paire est coupée en deux moitiés `AileG` (-Z de l'os) et `AileD` (+Z),
origine à la charnière (milieu du dos) ; `EdenModel.dress` leur pose `PrpWingFlap` (repli de 14° vers l'arrière, 1,9 s ; immobiles avec
« Réduire les animations »).
**Dos non ailés** : types `halo` (centre 0,5 au-dessus de l'os, derrière les épaules, 0,25 derrière le dos) et `pack` (sac collé au dos) : `haut`, `recul`.

## Réglages et pourquoi
**Image** (`prp_pipeline.py`, en tête) : 832×1216 (armes) ou 1216×832 (ailes), 30 pas, `dpmpp_2m karras`, cfg 6,5, LoRA à 0,5.
Préfixe `edenstyle, (single object:1.3), vertical, pointing straight up` ; suffixe : vue de face orthographique, fond gris clair uni,
couleurs bonbon vives, ombrage toon, contours. Négatif commun : personnage, main, plusieurs objets, perspective, ombre, sol, texte… plus un
négatif par objet (`negatif`) : `fruit, strawberry` pour la lance fraise, `dragon, creature, head` pour des ailes de dragon, etc.
4 à 6 graines par objet ; le score automatique (`_variantes.json`) aide mais **le choix se fait à l'œil** (planche `var_<id>.jpg`).

**Détourage** (`isolate`) : fond estimé ligne par ligne (SDXL fait des dégradés), pixel d'objet = différent du fond ET (saturé OU nettement
plus clair / sombre) ; on garde la composante principale (arme) ou les grandes composantes (ailes : deux moitiés), les éclats et
pétales qui flottent autour sont retirés, les **trous** (anneau, garde ajourée) restent ouverts ; recentré sur un carré 1024, **RGBA** :
l'alpha est le masque donné à Pixal3D (le workflow est modifié à la volée : `InvertMask` du masque de `LoadImage` au lieu de BiRefNet).

**3D** : workflow de G1 inchangé (structure 12 pas, forme 20, sur-échantillonnage, texture 12, remaillage 768, réduction QEM 150 000,
UV, cuisson 2048). Sur-échantillonnage **1536** pour les armes (objets fins), **1024** pour les ailes (VRAM). Graine 3D 56.

**Blender** (`prp_blender.py`, détail en tête du script) :
1. soudure des sommets (le GLB brut est coupé aux coutures UV), miettes < 0,4 % de la surface retirées ;
2. axe principal -> +Z (inclinaison corrigée), largeur -> X ; sens : garde dans la moitié basse (lames) ou bout le plus large en haut ;
   échelle à la longueur du type ; origine à la main ; W1 / W2 ;
3. **remaillage voxel** (plus grande dimension / 400 pour une arme, / 900 pour des ailes) **puis réduction** « collapse » au budget ;
4. dépliage UV neuf (Smart UV 60°), **couleur re-cuite** depuis le haut détail (Cycles, passe d'émission, processeur, 1 s) ;
5. contrôles : triangles, poids, arêtes à plus de 2 faces (> 2 % = rejet), bords ouverts (> 5 % = rejet), nombre de grandes
   composantes (> 6 pour une arme, > 14 pour des ailes = rejet) ; verdict dans la fiche ;
6. aperçu Eevee en 3 tons (rampe constante, sans contour, comme le shader du jeu) sur le bleu du ciel du jeu.

## Pièges (rencontrés au lot PRP-1)
- **SDXL dessine plusieurs objets** (planches de 3 épées, 9 icônes) dès que l'image est en portrait : le détourage garde le principal,
  mais mieux vaut `(single object:1.3)` et un négatif « multiple objects, collection ».
- **Mots piégés** : « strawberry » donne des fraises, « cherry blossom » des branches fleuries à côté de l'arme, « dragon wings » un dragon
  entier, « butterfly wings » un papillon (corps et antennes), « katana » un personnage qui le tient. Décrire la forme (« leaf-shaped
  spearhead », « wings only, no body ») et mettre le mot piégé au négatif.
- **Fond en dégradé** (violet, gris foncé au centre) : un fond estimé sur les seuls bords prend le dégradé pour l'objet (bandeau gris
  au-dessus de l'arme) : estimation par ligne + critère de saturation.
- **Trous bouchés** : BiRefNet garde le gris vu à travers un anneau ; Pixal3D en fait un disque gris sombre (1er espadon). D'où le masque
  alpha maison.
- **Réduire directement le maillage Pixal3D casse la topologie** : c'est une coque double (remaillage « udf ») ; la réduction plie les
  parties fines (300 à 400 arêtes à 3 faces sur une épée). Le remaillage voxel avant la réduction donne 0 arête cassée, 0 trou.
  Il fond la coque double : l'aire tombe vers 50 % (normal) ; garde-fou : aire < 35 % ou boîte changée de plus de 8 % = retour à la
  réduction directe (remarque « voxel abandonné »).
- **Ne pas retirer les « petits morceaux » avant la soudure** : le GLB brut a ~900 « îles » qui ne sont que des îles UV ; les retirer
  troue la pièce (45 % d'arêtes de bord au premier essai).
- **Sens de l'arme** : Pixal3D garde le haut de l'image ; une image « lame en bas » (1re épée de G1) donne une arme à l'envers : le script
  la retourne (garde dans la moitié basse).
- La carte est partagée : ComfyUI garde SDXL (≈ 7 Go) chargé entre deux images ; Pixal3D monte à 9,9-10,7 Go au plus haut. Ne pas
  lancer un entraînement ou un autre gros modèle en même temps. Blender cuit sur le processeur (aucune VRAM).
- Godot : le projet de contrôle copie le corps du héros et les shaders hors du dépôt (`C:\AI\prp1_godot`) ; il faut une fenêtre (pas
  `--headless` : rendu factice) ; une fenêtre 512×512 s'ouvre une trentaine de secondes.

## Ajouter un objet
1. Une entrée dans `prp_assets.json` (`id` : `prp_<nom>` pour une arme, **`back_prp_<nom>`** pour le dos, sans accent ; `nom` en
   français, court ; `type` parmi `types` ; `rarete` 0-5 = Commun, Spécial, Rare, Épique, Mythique, Légendaire ; couleurs dans la
   palette de la bible : soleil, mandarine, pomme, lagon, améthyste, fraise ; armes pastel lumineuses).
2. `images --only <id>`, regarder `C:\AI\prp1_raw\img\var_<id>.jpg`, noter `"graine"` (ou changer le prompt et `"graines"`).
3. `mesh --only <id>`, `clean --only <id>`, `godot --only <id>`, puis `sheet`.
4. Rejeter si le verdict n'est pas « ok », si la silhouette ne se lit pas sur `<id>_distance.png`, ou si l'aperçu montre des taches grises
   (fond pris pour l'objet), un objet coupé ou une forme fondue.

## Types de pièce
Gérés : épée, espadon, katana, hache, marteau, bâton, sceptre, lance (PRP-1) ; dague, rapière, bâton de métal, guitare (caisse en bas :
`"sens": "large_bas"`), canon, grimoire (`"sens": "image"` : le haut de l'image est gardé) (PRP-2). Pas encore : arc (os de la main
gauche, corde fine : la 3D la perd ; corde à refaire à la main dans Blender), gantelets (deux pièces), faux-fusil.

## Entrer dans le jeu (étape `game`)
`prp_assets.json` -> `game/data/prp_looks.json` (numéro de collection fixe = 990001 + rang de la fiche : **ajouter à la fin**, ne jamais
réordonner ; `"garder": false` pour retirer une pièce). `PrpLooks.install` (au chargement de `GameData`) en fait des trésors de collection
(arme : catégorie 4 avec `skin` ; dos : catégorie 2 + cosmétique `back`) : Héros > Apparence, coffres d'apparence, Collection et la
Vitrine du menu Coffres (prix en insignes par rareté, `PrpLooks.PRICES`) les prennent seuls. Après une nouvelle pièce : `--import`
(textures en Basis Universal), puis `res://tests/test_prp_looks.tscn`.
