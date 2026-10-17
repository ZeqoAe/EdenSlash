# R_PRP2 : 24 créations maison dans le jeu (14 apparences d'armes, 10 dos) — 17/10/2026

Département PRP (`ORGANISATION.md`), suite de `R_PRP1.md`. Procédure à jour : `PRP.md`. Version 0.1.294.

## À regarder
- **`prp/planche2.jpg`** (442 Ko) : les 24 objets seuls (aperçu toon sur le ciel du jeu), leur icône, rareté, type, mesures. Aucun rendu du héros.
- `prp/captures/` : Héros > Apparence (Dos, Arme) en 1280×720 et 1600×900, menu Coffres > Vitrine, la vitrine 3D vue par la caméra
  du jeu (15 m, 52°) et `gros_plans_sur_le_heros.jpg` (chaque création portée). Les captures montrent le héros du jeu, comme celles déjà
  dans le dépôt.

## Décisions (coordination, appliquées)
| Sujet | Décision | Fait |
|---|---|---|
| Budget | armes ≤ 3 000 triangles, dos ≤ 5 000, texture 512² | 2 880 / 4 800 visés ; 137 à 359 Ko par GLB (≤ 600) |
| Rendu | mat, « aplats » (pas de vernis) | `flatten` dans `prp_blender.py` : valeur lissée et tirée vers 5 paliers, reflets écrasés, saturation rendue ; métal 0, rugosité 1 |
| Ailes | rigides mais animées par code léger, coupé par « Réduire les animations » | paire coupée en `AileG` / `AileD` (charnière au dos), `PrpWingFlap` : repli de 14° vers l'arrière en 1,9 s, phase au hasard |
| Lance royale fraise | une vraie lance, pointe en haut | refaite (nouveau prompt, graine 124) ; Pixal3D la doublait (deux hampes) : on garde la plus grande pièce (`"une_piece"`) |
| Lame des cerisiers | garder l'épée, adapter le nom | **Lame de pétale** |

## Les 24 créations
| | Nom | Type | Rareté | Vitrine (insignes) |
|---|---|---|---|---|
| PRP-1 refaites | Lame de menthe | Épée | Rare | 220 |
| | Espadon de l'aurore | Espadon | Légendaire | 1 000 |
| | Lame de pétale | Épée | Épique | 400 |
| | Hache mandarine | Hache | Spécial | 160 |
| | Marteau des prés | Marteau | Rare | 220 |
| | Bâton d'écume | Bâton | Épique | 400 |
| | Sceptre d'améthyste | Sceptre | Mythique | 700 |
| | Lance royale fraise (nouvelle) | Lance | Rare | 220 |
| | Ailes de l'aube | Ailes | Légendaire | 1 000 |
| | Ailes de dragonnet | Ailes | Épique | 400 |
| | Ailes de papillon lagon | Ailes | Rare | 220 |
| | Ailes de cristal | Ailes | Mythique | 700 |
| PRP-2 neuves | Dague du lagon | Dague | Rare | 220 |
| | Rapière solaire | Rapière | Épique | 400 |
| | Crosse de jade | Bâton de métal | Mythique | 700 |
| | Guitare fraise | Guitare | Épique | 400 |
| | Canon lagon | Canon | Spécial | 160 |
| | Grimoire étoilé | Grimoire | Légendaire | 1 000 |
| | Ailes de phénix | Ailes | Mythique | 700 |
| | Ailes de feuillage | Ailes | Rare | 220 |
| | Ailes de cœur | Ailes | Épique | 400 |
| | Ailes d'horloger | Ailes | Spécial | 160 |
| | Halo solaire | Dos (halo, derrière les épaules) | Mythique | 700 |
| | Sac lapin | Dos (sac) | Commun | 120 |

13 types d'armes sur 17 (6 nouveaux : dague, rapière, bâton de métal, guitare, canon, grimoire ; dimensions mesurées sur les armes du jeu
par la nouvelle étape `measure`). Pas d'arc (corde perdue par la 3D), ni gantelets (deux pièces), ni faux-fusil, ni katana (SDXL n'en
dessine pas). « Auras » : le jeu les dessine en effets de particules (`.nif` convertis), pas en modèle : les 2 pièces de dos non ailées sont
un halo et un sac, accrochés comme les ailes.

## Dans le jeu
- **Données** : `game/data/prp_looks.json` (écrit par `prp_pipeline.py game`), lu par `PrpLooks.install` au chargement de `GameData`
  (après les noms français). Arme = trésor de collection catégorie 4 avec `skin` (`GameData.skin_by_code`) ; dos = cosmétique « back »
  (`GameData.cosmetics`, en tête de liste) + trésor de collection catégorie 2 qui le débloque. Numéros de collection 990001-990024 (libres
  dans le catalogue, vérifié par le test). **Aucune stat** : l'archive ne compte que l'équipement (`Archive.count`).
- **Héros > Apparence** : Arme (nos créations en tête des « Apparences »), Dos (en tête, « Non teintable »). Correctif au passage : la grille
  Tenue / Tête / Dos / Aura passe à 4 colonnes et la rangée d'armes à un nom sur deux lignes sous 1500 px (la page sortait de 1280×720
  dès 5 cases ; `[débord]` à zéro dans `shot_prp2`).
- **Où les gagner** : les coffres d'apparence existants les tirent d'eux-mêmes (`Rewards.roll_look` : jamais un doublon, rareté du coffre),
  donc aussi les puits d'insignes de la Boutique ; et la **Vitrine** (menu Coffres, 3e onglet) : achat direct, prix par rareté
  (`PrpLooks.PRICES` 120 / 160 / 220 / 400 / 700 / 1 000), plus cher qu'un coffre de même rareté puisqu'on choisit. Infobulle : « Création
  maison, sans effet sur les stats ».
- **Ailes battantes** : `scripts/world/prp_wing_flap.gd`, posé par `EdenModel.dress` quand le GLB a `AileG` et `AileD`.
- **Modes scellés** : rien de changé (une apparence n'a aucun effet de jeu ; elle reste visible).
- Fichiers : `game/assets/weapons/prp/<id>.glb`, `game/assets/player/outfits/back_prp_*.glb` (textures intégrées en Basis Universal :
  pas d'image à côté), icônes `game/assets/ui/items/<id>.png` (128) et `<id>_64.png` (tuile autocollante, couleur de rareté, rayons, contour
  d'encre ; étoile pour mythique et légendaire). 6,7 Mo en tout.

## Mesures
**Coût d'image, 20 héros façon Battle royale** (`res://tools/prp_perf.tscn`, fenêtre 1280×720, caméra du jeu, ombres, course en boucle,
3 tours alternés, RTX 5070 partagée) :

| 20 héros | Image | CPU de rendu | GPU | Triangles dessinés | Appels de dessin |
|---|---|---|---|---|---|
| arme de la classe, sans dos | 1,40-1,75 ms | 0,35-0,45 ms | 0,31 ms | 83 206 | 93 |
| + ailes d'Eden articulées (`back_a6118a`) | 2,26-2,50 ms | 0,86-0,95 ms | 0,61 ms | 184 326 | 393 |
| + **ailes maison battantes et armes maison** | 1,46-1,61 ms | 0,40-0,45 ms | 0,40 ms | 221 502 | 111 |

Nos pièces coûtent **+0,09 ms de GPU** pour 20 héros, moins que les ailes d'Eden (+0,30 ms ; 15 appels de dessin par héros contre 1).
Plus de triangles, mais un seul maillage et une texture par pièce, et des niveaux de détail générés à l'import.

**Production** (carte partagée avec d'autres agents) : image SDXL 14 à 25 s ; objet 3D Pixal3D **2 min 15 à 7 min 43** (3 min 30 à 4 min
en moyenne ; jusqu'à 11,4 Go de VRAM, d'autres travaux tournaient) ; nettoyage Blender 13 s à 1 min 52. 91 images, 15 objets 3D (dont 2
nouveaux essais : lance, canon). Tout le détail : `prp/mesures.json`, journal brut `C:\AI\prp1_raw\mesures.jsonl`.

## Tests
- `test_prp_looks` (nouveau, **vert**, 35 contrôles) : table (24, aucun doublon d'id ni de numéro, numéros libres), chaque GLB se charge,
  ≤ 3 000 / 5 000 triangles, ≤ 600 Ko, `EdenRoot` / `W1` / `W2` / `AileG` / `AileD`, accroche à l'os sur un vrai héros (main, `Bip01 Spine1`),
  battement (bouge, et immobile avec « Réduire les animations »), Héros > Apparence (Arme, Dos), `Archive.skins` / `chosen_skin`, dos
  débloqué par la collection, coffres d'apparence (`Rewards.roll_look`), Collection, vitrine (refus, achat, prix, pas de second achat,
  onglet construit).
- `test_texts_fr`, `test_nav_screens`, `test_pages`, `check_scripts` : voir la ligne du lot dans `CHANGELOG.md` (résultat au moment de l'envoi).
- Captures `tests/shot_prp2.tscn` (`PRP2_RES=1280x720`) regardées : la page Apparence, la vitrine, la vue du jeu et les 24 gros plans.

## Limites, honnêtement
- **Rendu** : les aplats retirent le vernis mais la texture reste plus « peinte » (marbrures, liserés gris aux bords des feuilles) que les
  armes d'Eden ; à distance de jeu ça ne se voit pas, en gros plan oui.
- **Ailes de phénix** : un petit oiseau au centre (SDXL ne dessine pas d'ailes de phénix sans l'oiseau) ; **Ailes d'horloger** : rouages un
  peu chargés ; **Sac lapin** : le plus brut (ombre de l'image devenue socle, coupée ; quelques éclats) ; **Canon lagon** : gros, il passe
  devant le visage dans certaines poses ; **Lance** : fer modeste, hampe rayée.
- Les apparences d'armes du catalogue (et donc les nôtres) se portent sur n'importe quel type d'arme (comportement existant de
  Héros > Apparence) : une guitare sur un Guerrier est possible.
- Les « avis » de la planche pour les pièces PRP-1 viennent de PRP-1.

## Suite possible
Coffres et décor par la même chaîne ; arc (corde refaite à la main) ; une 2e passe sur phénix / sac / horloger (nouvelles graines) ;
Légendaires réservés à un défi (Panthéon, Platine) si le joueur le souhaite (aujourd'hui : vitrine à 1 000 insignes ou coffre légendaire).
