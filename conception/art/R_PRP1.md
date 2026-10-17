# R_PRP1 : chaîne de production des objets 3D, 8 apparences d'armes et 4 ailes de dos (17/10/2026)

Département PRP (`ORGANISATION.md`). **Rien n'est intégré au jeu** (aucun fichier de `game/` touché) : le joueur choisit sur la planche,
un lot suivant intègre. Procédure complète, réglages et pièges : `PRP.md`.

## À regarder
- **`prp/planche.jpg`** (430 Ko) : les 12 objets ; pour chacun, l'aperçu toon, **le héros du jeu qui le porte** (Godot 4.7.2, vrai
  shader, vraie accroche), **sa taille réelle à l'écran** (caméra du jeu : 15 m, 52°, 1280×720), l'image source, les mesures, le verdict.
- `prp/candidats/<id>.glb` + `<id>.json` (fiche : id, nom français, emplacement, type, rareté, os d'accroche, mesures, source, licence).
- `prp/mesures.json` : temps et VRAM de chaque image, de chaque objet 3D, du nettoyage.

| Objet | Type | Rareté | Triangles | Poids | Avis |
|---|---|---|---|---|---|
| Lame de menthe | Épée | Rare | 7 680 | 432 Ko | silhouette nette ; liseré clair au tranchant |
| Espadon de l'aurore | Espadon | Légendaire | 7 680 | 563 Ko | garde ajourée bien rendue ; le plus lisible de loin |
| Lame des cerisiers | Épée | Épique | 7 680 | 370 Ko | lame nette ; demandé « katana », SDXL n'en dessine pas (voir Limites) |
| Hache mandarine | Hache | Spécial | 7 680 | 588 Ko | hache double très lisible, tête épaisse |
| Marteau des prés | Marteau | Rare | 7 680 | 452 Ko | bonne silhouette ; petit disque plat sous le manche (ombre de l'image) |
| Bâton d'écume | Bâton | Épique | 7 680 | 586 Ko | anneau et orbe nets, plumes un peu fondues |
| Sceptre d'améthyste | Sceptre | Mythique | 7 680 | 748 Ko | le plus détaillé ; gemme facettée lisible |
| Lance royale fraise | Lance | Rare | 7 680 | 556 Ko | le plus faible : un sceptre-lance (pointe en bas) ; 1re version (hampe d'un fil) écartée |
| Ailes de l'aube | Dos | Légendaire | 11 520 | 896 Ko | plumes nettes, deux ailes séparées |
| Ailes de dragonnet | Dos | Épique | 11 520 | 791 Ko | membranes lisibles, petite tête de dragon au centre du dos |
| Ailes de papillon lagon | Dos | Rare | 11 520 | 726 Ko | très fidèle à l'image, contours dorés |
| Ailes de cristal | Dos | Mythique | 11 520 | 806 Ko | le plus massif (0,83 d'épaisseur), très lisible de loin |

7 types d'armes (épée ×2, espadon, hache, marteau, bâton, sceptre, lance). Les 12 passent les contrôles : budget de triangles, ≤ 1,5 Mo,
**0 arête cassée, 0 trou**, une seule grande pièce (bâton, lance : 2), import Godot sans erreur, os trouvé, `EdenRoot`, `W1` / `W2`.

## Méthode (résumé ; détail dans `PRP.md`)
1. **Image** : SDXL base 1.0 + LoRA `eden_style_v0b` à 0,5 (ComfyUI), vue de face orthographique sur fond gris, 4 à 10 graines par objet,
   choix à l'œil ; détourage maison (fond en dégradé, éclats retirés, trous laissés ouverts) en **PNG RGBA** dont l'alpha sert de masque.
2. **3D** : Pixal3D (workflow G1), masque alpha au lieu de BiRefNet, sur-échantillonnage 1536 (armes) / 1024 (ailes).
3. **Blender 5.2** (`tools/art/prp_blender.py`, en arrière-plan) : soudure, miettes retirées, axe corrigé, mise à l'échelle par type,
   **repère de l'os** (arme : lame vers +Z, origine à la main, W1 / W2 ; ailes : os `Bip01 Spine1`, collées au dos), **remaillage voxel puis
   réduction** au budget, UV neuf, couleur **re-cuite** (occlusion multipliée, saturation ×1,15, métal 0 : le shader du jeu ne lit que la
   couleur), GLB avec `EdenRoot`.
4. **Contrôle Godot** (projet de brouillon hors dépôt) : même accroche qu'`EdenModel`, même shader, héros à l'échelle, pose de combat.
5. **Planche et mesures**. Une commande par étape : `C:\AI\venv_comfy\Scripts\python.exe tools/art/prp_pipeline.py images|mesh|clean|godot|sheet|all`.

Format vérifié sur le jeu : les armes d'Eden sont lues dans le repère de l'os de la main (`EdenRoot` remis à l'identité, lame +Z,
W1 / W2 pour la traînée) ; les accessoires de dos rigides (`back_*.glb` sans squelette) dans celui de `Bip01 Spine1` (X haut, Y devant) ;
longueurs par type = médiane des 4 armes du jeu de ce type.

## Mesures (RTX 5070 12 Go partagée avec d'autres agents ; Godot en parallèle)
| Étape | Temps | VRAM (carte entière) |
|---|---|---|
| Image SDXL + LoRA 832×1216, 30 pas | **12,7 s** en moyenne (10 à 18 s), 80 images | 7,7 à 10,7 Go (SDXL reste chargé) |
| Objet 3D Pixal3D | **2 min 52** en moyenne (2 min 27 à 3 min 57) | **9,2 à 11,1 Go** au plus haut |
| Nettoyage Blender (avec démarrage et aperçu) | 19 s à 1 min 52 (58 s en moyenne ; 15 s de calcul seul, le reste attend le processeur partagé) | 0 (processeur) |
| Contrôle Godot (import + 2 rendus) | ≈ 3 s par objet | négligeable |

**Par objet : ≈ 6 à 7 min de machine** (4 à 6 images, une 3D, nettoyage), **+ 1 min de choix humain**. Le lot : 80 images (17 min),
13 objets 3D (37 min, dont un 2e essai pour la lance ; plus 2 essais de réglage), soit ≈ 1 h de carte. Polygones : 7 680 par arme (budget 8 000), 11 520 par
paire d'ailes (budget 12 000). Poids : 370 à 896 Ko (budget 1 536), texture couleur 1024² JPEG.

## Ce qui a été rejeté en route
- 1er passage : le maillage réduit directement avait 350 arêtes à 3 faces (topologie cassée) puis, en retirant les « îles » avant la
  soudure, 45 % d'arêtes de bord (troué) : corrigé (soudure d'abord, remaillage voxel avant réduction).
- 1er espadon : disques gris dans la garde ajourée (BiRefNet bouchait les trous) : refait avec le masque alpha.
- Images : planches de plusieurs armes, fraises au lieu d'une lance, dragons entiers au lieu d'ailes, papillons avec corps et antennes,
  personnages tenant un katana : 2e tour de prompts (négatifs par objet) ; graines écartées dans `C:\AI\prp1_raw\img\var_<id>.jpg`.
- Lance, 1re version : hampe d'un fil, illisible en jeu (conservée hors dépôt : `C:\AI\prp1_raw\lance107`).

## Limites, honnêtement
- **Plus fins que les armes du jeu** : 7 680 triangles et 1024² contre 300-1 000 triangles et 512² pour les armes d'Eden ; texture
  peinte avec des reflets « plastique brillant » (SDXL) là où le jeu a des aplats. Côte à côte sur le héros, ça se voit un peu : plus
  riche, plus « jouet verni ». Réglable (voir choix 2 et 3).
- **SDXL obéit mal aux formes précises** : pas de katana courbe en 10 essais, pas de lance à hampe solide ; il ajoute volontiers
  socle, ombre, gemme. On choisit parmi des variantes plutôt qu'on ne commande.
- **Dos et dessous inventés** par Pixal3D : vus de dos, les ailes sont propres ; une arme vue par la tranche est plus épaisse que sur
  l'image (marteau 0,49, cristal 0,83). Les rendus de dos sont à juger sur la planche (colonne « sur le héros »).
- Ailes **rigides** (pas d'os) : elles ne battent pas, contrairement à beaucoup d'ailes du jeu. Un battement simple (2 os, rotation
  en boucle) est faisable dans Blender, pas fait ici.
- **Pas d'icônes** encore (l'Apparence et la boutique en demandent) : à rendre depuis Blender dans le style des icônes du jeu au
  lot d'intégration.
- La planche montre le **héros du jeu** (rendu) comme les captures déjà dans le dépôt ; les GLB, eux, ne contiennent que nos modèles et
  textures générés (SDXL OpenRAIL++-M, Pixal3D / TRELLIS.2 MIT, LoRA maison).

## Plan d'intégration proposé (lot suivant, après le choix du joueur)
1. **Fichiers** : armes retenues -> `game/assets/weapons/prp/<id>.glb` ; ailes -> `game/assets/player/outfits/back_prp_<nom>.glb` (le
   préfixe `back_` sans `l` suffit à `EdenModel.dress` pour les accrocher au haut du dos) ; icônes 128² rendues par un nouveau
   `prp_pipeline.py icon` (case arrondie, rayons, couleur de rareté : bible § 9) -> `game/assets/ui/items/prp_<id>.png`.
2. **Données** : une table à nous, `game/data/prp_looks.json` (générée depuis les fiches `<id>.json`), lue par `GameData` au chargement :
   - armes : entrées comme les trésors de collection à apparence (`{"id", "code": "PRP_<id>", "name", "icon", "rarity", "cat": 4,
     "skin": {"model", "texture": "", "wtype"}}`) ajoutées à `GameData.collection` et `skin_by_code` : elles apparaissent alors seules
     dans Héros > Apparence > Arme (`Archive.skins`, `Profile.set_skin`) et sur le héros (`EdenModel.weapon_entry` / `attach_weapon` :
     texture vide = celle du GLB) ;
   - ailes : entrées de `GameData.cosmetics` (`{"id": "back_prp_…", "cat": "back", "name", "icon", "rarity", "outfit", "variants": []}`) :
     Héros > Apparence > Dos, `Profile.unlock_outfit` / `set_worn` ; pas de teinture (aucun `.dye.json`).
3. **Où les obtenir** (au choix du joueur) : coffres d'apparence existants (`SurvivorRewards`, coffres de la Tour et du Siège qui
   donnent déjà des « apparences ») avec un tirage pondéré par rareté ; et/ou une vitrine « Atelier > Apparences » payée en insignes ; les
   Légendaires (Espadon de l'aurore, Ailes de l'aube) en récompense de défi (Panthéon, rang Platine).
4. **Contrôles** : `test_texts_fr` (noms déjà en français), un test `test_prp_looks` (chaque entrée charge, os trouvé, W1 / W2,
   triangles ≤ budget), capture de Héros > Apparence en 1280×720, et mesure de performances en Battle royale (20 héros à 11 520
   triangles d'ailes = 230 000 triangles : à vérifier ; sinon une version à 4 000 triangles pour les autres héros).

## Choix à faire par le joueur
1. **Lesquels garder** sur la planche (et si la Lance royale fraise et la Lame des cerisiers valent un nouvel essai).
2. **Niveau de détail** : garder 7 680 / 11 520 triangles (riche, lobby et gros plans) ou descendre vers 2 000 / 4 000 pour coller aux
   armes du jeu (une ligne dans la fiche, `"triangles"`, puis `clean --force`).
3. **Rendu des couleurs** : tel quel (brillant), ou plus « aplat » comme les armes d'Eden (postérisation de la texture en 3-4 tons au
   nettoyage) ; à décider sur 2-3 objets avant de refaire la série.
4. **Ailes animées** (battement lent) ou rigides.
5. **Où les gagner** (coffres, vitrine en insignes, défis) et à quel rythme.
6. La suite de la chaîne : coffres et décor (le coffre de G1 passerait tel quel : type « décor » à ajouter, os aucun, pose au sol).
