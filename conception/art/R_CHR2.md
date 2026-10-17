# R_CHR2 : jusqu'où monter la qualité d'un héros (« classe premium ») — 17/10/2026

Département Personnages (`ORGANISATION.md`), lot CHR-2, exploration d'une journée d'agent. Question du joueur après CHR-1 :
nos limites viennent-elles du modèle et du squelette (Bip01, 40 os, petit corps chibi, textures 512) ? Réponse courte :
**en partie seulement**. On a pu, **sans toucher au squelette ni aux 94 animations d'Eden**, poser sur le Ninja du Tourbillon une
tête neuve (visage 2048, mèches 3D séparées, bandeau, rubans), **10 os de plus animés par ressorts**, une tenue 2048 et
**7 animations faites dans Blender** ; le coût d'image est négligeable. Ce qui reste limité : le corps chibi lui-même (bras
courts, grosse tête qui cache les gestes vus de dessus) et la qualité d'animation d'un agent qui pose des clés sans œil
d'animateur. Version 0.1.317.

**Droits** : tout ce qui est propre au design (tête, textures, captures, GIF) est **hors du dépôt**, dans `C:\AI\chr2\` ; le jeu
les lit dans `game/assets/player/premium/` (dossier ignoré par git, rempli sur le PC). Dans le dépôt : le code, les outils, la
bibliothèque d'animations (gestes génériques) et une planche neutre (`chr/chr2_animations.jpg`, sur le corps d'Eden par défaut).

## À regarder (sur le PC, hors dépôt)
| Fichier | Ce qu'il montre |
|---|---|
| `C:\AI\chr2\captures\chr2_look_avant.png` / `chr2_look_apres.png` | même cadrage, CHR-1 puis « Héros détaillé » : trois quarts, dos, visage, profil, garde, course, coup de pied, signe |
| `captures\chr2_anim_ninja_*.png` | chaque animation neuve (8 instants) sous celle d'Eden qu'elle remplace |
| `captures\gif\combo.gif`, `clone.gif`, `ult.gif`, `orb.gif`, `star.gif` (+ `_planche.jpg`) | en jeu, caméra du jeu (7 m), doubles compris |
| `captures\glb_views.png` | la pièce « tête » seule (dos, profil, face) dans Blender |
| `tex\face_compare2.png` | œil agrandi ×4 : Lanczos / traits redessinés / IA |
| `blend\chr2_anims.blend`, `blend\chr2_head.blend` | fichiers Blender éditables (actions clé par clé, tête) |
Dans le dépôt : `conception/art/chr/chr2_animations.jpg` (les 7 animations sur le corps d'Eden par défaut, rendu Blender).

## Ce qui est fait, gain visible, coût
Coûts : heures d'un agent sur la machine partagée, GPU = RTX 5070 partagée (SDXL ≈ 7 Go).

| Amélioration | Gain visible | Coût | Risques |
|---|---|---|---|
| **Tête neuve** (visage d'Eden subdivisé, poids transférés de `#LFACE`, mêmes UV) | silhouette du visage plus ronde, plus de facettes au menton ; **de près seulement** | 0,5 h | aucun : mêmes UV, mêmes os |
| **Visage 2048** (agrandi ×4 par SDXL + LoRA maison, tuiles 1024, débruitage 0,3 ; traits des joues peints à 2048) | escaliers des yeux et des traits disparus ; visible dans Héros, lobby, création ; **invisible à la caméra du jeu** (visage ≈ 40 px) | 0,5 h, 2 min GPU | l'IA lisse un peu la peinture d'origine |
| **Mèches 3D séparées** (26 mèches effilées et courbes + calotte, 1 750 triangles, texture 1024 dégradé + reflet en code) | **le plus visible en jeu** : vraies pointes de toutes les directions, au lieu de 10 cônes et d'une coiffure d'Eden teinte | 1,5 h | formes « cristal » de près (section en losange à 6 côtés) ; un artiste ferait mieux en 2 h |
| **Bandeau** (anneau à épaisseur, plaque biseautée lisse, nœud) | net de près, se lit en jeu | inclus | — |
| **10 os neufs + ressorts** (`SpringBoneSimulator3D` : 2 mèches de côté × 2 os, 2 rubans × 3 os ; collisions tête et dos) | rubans et mèches qui traînent, rebondissent ; contrôle : 33 cm de traîne mesurés au test | 1 h | réglages par chaîne (raideur, traînée, gravité) à affiner à l'œil |
| **Tenue 2048** (même méthode IA, teintures gardées) | **aucun gain visible en jeu**, léger au lobby (texture d'Eden peinte floue à l'origine) | 2 min GPU | — |
| **7 animations Blender** (garde, course penchée, coup de pied circulaire, signe des mains, lancer d'étoiles, ultime : charge bras levés + lancer) | coup de pied, garde et course **nettement plus lisibles** que les poses figées de CHR-1 ; signe et lancer corrects ; ultime : bras levés **cachés par la tête** vue de dessus | 2,5 h (2 passes) | « robotique » sans œil d'animateur (pas de smear, peu de rebond) ; corrigeable à la main dans le .blend |

### Comment c'est fait
| Fichier | Rôle |
|---|---|
| `tools/art/chr2_anims.py` (Blender) | poses-clés en repère du personnage (devant, gauche, haut), courbes d'élan (anticipation, frappe, rebond), **IK analytique à deux os** (pieds calés, mains jointes), clés posées dans des Actions Blender (fichier .blend gardé), cuisson en deltas monde par os |
| `game/tools/chr2/chr2_anim_build.gd` | JSON -> `AnimationLibrary` (`assets/player/anims/chr2_ninja.res`, 350 Ko) aux chemins de pistes du corps commun ; passage Blender -> Godot **calculé** (alignement des repos, écart 5 mm), contrôle d'aller-retour sur `attack20` et `stand01` d'Eden : **0,1° d'écart moyen** (max 1,6°) |
| `tools/art/chr2_head.py` (Blender) | visage, mèches, bandeau, rubans et leurs os ; **GLB écrit à la main** au format des pièces d'Eden (repos exacts du corps commun, matrices de liaison calculées) : l'export glTF de Blender réoriente les os et casserait la peau |
| `tools/art/chr2_tex.py` | agrandissement ×4 (Lanczos / traits redessinés / SDXL par tuiles), peinture par masque d'îles d'UV, textures de cheveux et de bandeau, traits du visage |
| `core/class_premium.gd` (`ClassPremium`) | réglage, pièce de tête, ressorts, texture de tenue, bibliothèque + table « animation d'Eden -> neuve », ultime en deux temps |
| `combat/combatant.gd` (`play`), `player/proc_pose.gd` (`skip`), `core/class_look.gd`, `combat/ninja_arts.gd` | une ligne chacun, gardée par une méta du modèle : **rien ne change pour les 60 classes ni sans le réglage** |
| `tests/test_chr2.tscn`, `tests/shot_chr2.tscn`, `tools/chr2/chr2_perf.tscn` | test (30 contrôles), captures, mesures |

**Le jeu ne change pas avec le réglage** : le calage des coups lit toujours l'animation d'Eden (longueur, impact à 40 %) ; les
neuves ont **la même longueur** et l'impact au même instant, et sont seulement *jouées à la place* (`Combatant.play`). Contrôlé
(`test_chr2`) : durées et impacts des 3 coups du taï-jutsu identiques réglage mis / coupé.

Réglage : Paramètres > Affichage > Image > **Héros détaillé** (oui par défaut). Sans les fichiers de tête sur le PC, seules les
animations s'appliquent ; réglage coupé = apparence et poses de CHR-1.

## Mesures (20 héros à l'écran, caméra du jeu, 1280×720, 3 tours de 400 images, machine partagée)
| Configuration | GPU | Image (CPU) | Triangles | Appels de dessin | Textures |
|---|---|---|---|---|---|
| 20 classes d'Eden (référence) | 0,30 ms | 2,05 ms | 73 600 | 80 | 262 Mo |
| 20 Ninja, look CHR-1 (réglage coupé) | 0,27 ms | 4,08 ms | 89 300 | **381** | 263 Mo |
| 20 Ninja, **Héros détaillé** | **0,28 ms** | 2,49 ms | 113 300 | 121 | 279 Mo |
| idem + ailes d'Eden | 0,57 ms | 3,92 ms | 214 800 | 421 | 279 Mo |
- **GPU : +0,01 ms** pour 20 héros détaillés par rapport à CHR-1 (budget : +0,5 ms) ; le héros fait **6 856 triangles** (budget
  15 000). Plus rapide que CHR-1 côté processeur : les 10 cônes et 2 rubans de CHR-1 font 15 appels de dessin par héros.
- **Chargement** d'un héros (`instantiate_hero`) : 1er 313 ms au lieu de 247, suivants **253 ms au lieu de 174** (+79 ms) : la pièce
  porte 3 textures en PNG dans le GLB (3 Mo). **Risque** : les 2 doubles du « Double de brume » sont bâtis au lancer (+160 ms
  d'à-coup). À corriger avant d'en faire une règle : textures à part (importées et compressées), modèle des doubles préparé.
- Mémoire vidéo : +16 Mo (visage 2048, tenue 2048, cheveux et bandeau 1024).

## Reciblage depuis des banques de mouvements (évalué sans téléchargement)
Télécharger une banque demande l'accord du joueur (fichier, source, taille) : non fait. L'essai (`tools/art/chr2_retarget.py`)
fabrique la source : un squelette Bip01 **aux proportions adultes** (jambes ×1,9, bras ×1,75, buste ×1,5) qui joue des gestes, puis
les recible sur le chibi de deux façons : **A** copie des rotations (ce que font le BoneMap de Godot ou un reciblage Blender
simple), **B** A + mains et pieds recalés par IK (longueurs du chibi, mains repoussées hors du crâne).
| Geste | A : mains dans la tête | A : pieds sous le sol | B : mains dans la tête |
|---|---|---|---|
| nos 5 gestes joués à l'échelle adulte | 0 | 1,8 à 2,8 cm | 0 (erreur des mains ≤ 0,5 cm) |
| bras levés (adulte) | **8,6 cm** | 0 | **5,3 cm** (le bras chibi n'atteint pas le dessus de la tête) |
| main au front (adulte) | **6,4 cm** | 0 | 0 |
| mains jointes devant le visage | 0 | 0 | 0 |
Conclusion : le reciblage **marche pour courir, frapper, lancer** si l'on recale pieds et mains par IK (B, une demi-journée
d'outil de plus) ; **tout geste près de la tête casse** (le crâne chibi fait 2,5 fois la taille relative d'un crâne adulte) et
demande des poses refaites à la main. Banques : **Quaternius « Universal Animation Library » (CC0)** recommandée ; CMU (libre
d'usage, données brutes) ; Mixamo : compte Adobe obligatoire (un agent n'en crée pas), animations utilisables dans un jeu mais
fichiers bruts à garder hors du dépôt public ; banques « non commerciales » (Bandai Namco, AMASS) exclues.

## Mouvement généré par IA
**Non essayé** : l'installation télécharge le code et les poids (plusieurs Go), ce qui demande l'accord du joueur. Évaluation sur
dossier : modèles texte -> mouvement (MoMask, MDM, famille HY-Motion) entraînés surtout sur HumanML3D / AMASS (**licences de
données non commerciales**, à vérifier modèle par modèle), sortie sur squelette SMPL adulte (donc mêmes pièges de reciblage
qu'au-dessus), bons pour marcher, courir, gestes quotidiens, **faibles pour un combat d'anime** (pas de poses-clés marquées). Sur
12 Go partagés : MoMask et MDM devraient tenir (modèles de quelques centaines de millions de paramètres, à mesurer), installation
estimée à 1 h si le joueur l'autorise. Intérêt réel :
des bases de course et d'attente à retoucher, pas des coups.

## Recommandation « classe premium »
**Oui, faisable, avec cette procédure** ; le palier vaut surtout par **les mèches 3D + ressorts** et **les animations de combat**.
Les textures 2048 n'ont d'intérêt que pour les écrans de près (Héros, lobby) : les garder en 1024 suffit.

Procédure pour une classe (tout est reprenable, rien ne touche aux 60 classes) :
1. `look.json` du design (hors dépôt si le design est inspiré) : crâne, mèches, bandeau / accessoires, rubans, couleurs, traits.
2. `chr2_tex.py up` (visage, tenue) puis `face`, `hair`, `band` -> textures ; `chr2_head.py` -> GLB ; vérifier `glb_views.png`.
3. Animations : écrire les poses-clés dans `chr2_anims.py` (une fonction par geste, longueurs = animations d'Eden remplacées),
   planche `shot_chr2.tscn CHR2_MODE=anims`, 2 passes à l'œil ; `chr2_anim_build.gd` -> bibliothèque.
4. `look.premium` dans `classes_custom.json` (remap, poses sautées, ressorts) ; `test_chr2` adapté ; `chr2_perf.tscn`.
**Temps par classe** (agent seul) : tête et textures ½ jour, 6 à 8 animations 1 jour, intégration et mesures ½ jour : **≈ 2 jours**,
GPU ≈ 5 min. Avec un artiste : mèches modelées à la main (2 h) et retouche des clés dans le .blend (½ jour) : le saut de qualité
le plus rentable. **À ne pas faire** : changer le corps chibi ou le squelette (casserait 127 tenues et 94 animations).

À régler avant d'étendre : textures de la pièce hors du GLB (chargement), doubles préparés à l'avance, ruban plus large et
moins raide, mèches à section plus ronde (8 côtés), garde gauche du coup de pied, caméra de l'ultime (bras levés cachés de dessus).

## Tests
- `test_chr2` (nouveau, 30 contrôles) **vert** sur ce PC avec la tête détaillée (visage remplacé, 10 os, 4 ressorts, 6 856
  triangles, calage du jeu identique, ultime en deux temps) et **vert** sur une copie du commit sans elle (repli sur CHR-1).
- Sur la copie du commit (`run_tests.py --reuse -j 2`, machine chargée) : **7 verts sur 7** : `test_build`, `test_chr1` (passe le
  réglage à « non » : il contrôle l'apparence de CHR-1), `test_chr2`, `test_names_fr`, `test_nav_screens`, `test_pages`, `test_texts_fr`.
- Piège rencontré : l'interrupteur glissé entre deux listes de la section Image rendait le bouton de pied de page injoignable à la
  manette (`test_nav_screens`, 18 / 19) ; placé en fin de section, tout est atteignable (19 / 19).
- Arrêt d'une heure en cours de lot (machine du joueur libérée) ; reprise sur la même copie.
