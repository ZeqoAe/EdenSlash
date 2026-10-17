# R_CHR1 : le Ninja du Tourbillon, classe maison n° 61 (prototype jouable) — 17/10/2026

Département Personnages (`ORGANISATION.md`), lot CHR-1. Demande du joueur : tester l'autonomie de l'équipe sur une classe neuve,
« le ninja blond », et voir **les limites** de ce qu'on sait faire en animation et en texture sur un héros. Le rapport de limites
est `CHR.md` (tableau facile / moyen / dur / non, coûts, preuves) ; ici, ce qui est dans le jeu et comment c'est mesuré. Version VERSION_CHR1.

**Nom et droits** : en jeu « Ninja du Tourbillon », design *inspiré* (cheveux blonds en pointes, bandeau à plaque **lisse**, tenue
orange et noire, trois traits sur chaque joue), aucun nom de personnage, aucun symbole. **Aucune image ni aucun modèle propre à ce
design dans le dépôt** : tout le look est fait par code sur des pièces d'Eden déjà dans le jeu. Les captures, GIF, concepts et essais
IA sont dans `C:\AI\chr1\` sur le PC (liste dans `CHR.md`) ; le joueur décide s'ils peuvent entrer.

## À regarder (sur le PC, hors dépôt)
`C:\AI\chr1\captures\chr1_look_plate_v4.png` (le héros), `chr1_compare_plate_v4.png` (pas à pas), `gif\combo.gif`, `clone.gif`,
`star.gif`, `orb.gif`, `ult.gif`, `chr1_fight_still.png`. Dans le dépôt : `chr/icones_ninja.png`, `chr/poses_procedurales.jpg`,
`chr/inventaire_animations.jpg`.

## La classe
| | |
|---|---|
| Données | `game/data/classes_custom.json` (même format que `classes.json`, + `look`, `auto`, `open`, `proto`, `weapon_hidden`, `gear_profile`) |
| Place | famille Voleur, en bas de sa colonne du sélecteur de classe (« Création maison (prototype) ») ; **ouverte dès le départ** |
| Arme | gantelets (type « cestus », pour les objets et les apparences) **cachés** : il se bat à mains nues |
| Stats | PV ×1,04, attaque ×1,05, défense 2,5 ; agilité forte (base 15, +3 par niveau) ; profil de stats « vivacité » (comme le Kage) |
| Certificats | Endurance du tourbillon (+12 % de vitesse d'attaque, +5 % de PV), Volonté inflexible (+6 % de dégâts) |
| Auto-attaque | **Taï-jutsu** : direct, crochet, puis **coup de pied retourné** (×1,9, arc 200°, repousse) ; l'enchaînement repart du 1er coup après 1,1 s sans frapper ; effet légendaire « Rafale du tourbillon » |

| Sort | Forme | Recharge | Effet |
|---|---|---|---|
| Double de brume | `clone` | 16 s | signe des mains, fumée, 2 doubles alliés (vrais héros IA habillés comme toi, 25 % de tes PV, ta puissance × 1,6 par coup) qui frappent et attirent les coups 6 s puis disparaissent en fumée |
| Étoiles filantes | `bolt` | 5 s | 5 étoiles de lancer en éventail (46°, 13 m), 80 % chacune, traversent un ennemi, Saignement 3 s |
| Sphère tourbillon | `orb` | 8 s | élan de 6 m la sphère en main ; elle broie devant toi (6 coups de 40 % qui retiennent) puis éclate (220 %, 3,4 m, renverse 0,8 s) |
| Étoile du Tourbillon | `ult` | 32 s | charge 0,8 s bras levé (caméra qui se rapproche) ; l'étoile-sphère géante file (15 m/s), tranche ce qu'elle frôle (45 %), éclate sur le premier ennemi touché ou au point visé (550 %, 6 m, renverse 1 s), puis tourbillon (6 × 35 %, attire) |

Icônes : 5 pictogrammes de la DA (autocollant d'encre et de bonbon), faits par code comme ceux d'ICO-1 (`tools/art/ico_defs_d.py`,
`ico_sk_whirl_*`, `ico_cls_whirl_ninja`).

## Comment c'est fait (code)
| Fichier | Rôle |
|---|---|
| `core/game_data.gd` | `custom_classes` (lu à part : `GameData.classes` reste les **60** classes d'Eden), `class_data` cherche dans les deux, `is_custom_class` |
| `core/progression.gd`, `ui/class_picker.gd`, `core/class_gear.gd` | ouverte dès le départ (`open`), place dans le sélecteur, profil de stats lu dans ses données |
| `combat/ninja_arts.gd` (`NinjaArts`) | les 3 formes de sort nouvelles (`clone`, `orb`, `ult`) : charge, poses, doubles (`ClassRival` alliés, hors du groupe « allies », zones bleues), sphère, étoile géante, explosion, tourbillon, fumée, maillages (étoile de lancer, lames de vent) |
| `player/proc_pose.gd` (`ProcPose`) | calque de poses procédurales (`SkeletonModifier3D`) : coup de pied, signe des mains, sphère tenue, bras levé ; directions relatives au bassin, mélange 0,08 / 0,16 s |
| `core/class_look.gd` (`ClassLook`) | apparence d'une classe maison : teintures, blond vif (`hair_gain`), bandeau par code, traits peints sur le visage, mèches en pointes, 2 rubans à ressort (Verlet) |
| `shaders/swirl_orb.gdshader` | sphère tourbillonnante (spirale animée, cœur, liseré), additive |
| `player/player.gd` | auto-attaque de classe (`auto`, étapes `steps` : mult, zone, tour, pose, poussée), formes de sort branchées sur `NinjaArts`, arme cachée, `ClassLook` à l'habillage, portée de visée de l'ultime ; **rien ne change pour une classe sans ces clés** |
| `combat/hero_bolt.gd`, `core/eden_model.gd`, `ai/class_rival.gd` | style « shuriken » ; `ClassLook` dans les aperçus et sur les doubles ; zone bleue des doubles |
| `tools/anim_sheet.tscn` | planches d'animations du corps commun (impacts, bandes, `--pose=`) : l'outil qui a servi à choisir les gestes |
| `tests/test_chr1.tscn`, `tests/shot_chr1.tscn` | test (42 contrôles) ; captures (`CHR1_MODE=look|compare|fight|uv`, sortie hors dépôt) |

**Pourquoi à part des 60 classes** : `GameData.classes` est parcouru par 60 endroits (tirages des Arènes, du Siège, de la Battle royale,
de l'Échiquier, du Panthéon, listes et tests « 60 classes »). La classe maison n'y entre pas : aucun mode à IA ne la tire, aucune
mesure existante ne bouge. Elle n'est **pas** ajoutée à `ML_CLASSES` (`ml_arena.gd`) : l'observation des cerveaux dépend du nombre de
classes, l'ajouter rendrait tous les cerveaux entraînés (dont les 6 du Panthéon) inutilisables. Pas d'arbre de talents (la page
Classe s'ouvre, vide de talents), pas d'unité d'Échiquier.

## Équilibre (mesuré)
**Aventure** (`tools/boss_ttk.py --scenarios bande --epochs 1,2,3 --stages 1 --human 0.5 --repeat 2 --same-seeds --by-class`, copie
propre, 11 classes, 66 combats ; DPS et dégâts subis rapportés à la médiane des classes du même cas) :

| Classe | Boss battus | Morts | DPS | Subis | Indice |
|---|---|---|---|---|---|
| Magicien | 6/6 | 0 | 1,54 | 0,89 | 1,41 |
| Guerrier | 5/6 | 1 | 1,07 | 0,65 | 1,62 |
| **Ninja du Tourbillon** | **4/6** | **2** | **1,15** | **0,67** | **1,47** |
| Samouraï | 5/6 | 1 | 1,07 | 0,81 | 1,06 |
| Voleur | 5/6 | 1 | 1,07 | 0,86 | 0,93 |
| Assassin | 2/6 | 4 | 0,97 | 0,73 | 0,96 |
| Clerc | 6/6 | 0 | 0,97 | 0,90 | 0,83 |
| Kage | 4/6 | 2 | 0,81 | 0,89 | 0,86 |
| Hunter / Artiste martial / Asura | 3 à 5/6 | 1 à 5 | 0,64-0,87 | 0,86-1,09 | 0,60-0,66 |

Dans le haut du peloton, **sous** le Guerrier et à côté du Magicien : ni inutile, ni hors norme. Ses dégâts subis bas viennent des
doubles, qui prennent des coups. **La Tour seul** (`tools/m8_matrix.py run`, `--god --pure --pilot=bot`, une mesure par cas, temps pour
tuer le boss en s) : étage 30 : 59,8 (Voleur 42,0, Kage 92,4, Artiste martial 110,4) ; étage 50 : **45,9** (73,3 / 65,5 / 70,3) ;
étage 100 : **161,5** (84,5 / 62,2 / 93,1). Fort tôt, faible à l'étage 100 (les doubles y tombent vite) : à suivre si la classe
reste, avec `TowerBalance` (`data/tower_solo.json` ne la connaît pas : multiplicateur 1).

## Tests
- `test_chr1` (nouveau, **vert**, 42 contrôles) : données à part (60 classes intactes), sélecteur, ouverte, noms français, icônes,
  apparence (bandeau, mèches, rubans, teintures, traits du visage ; un Guerrier n'a rien de tout cela), dans un vrai monde : arme
  cachée, taï-jutsu à 3 étapes (3e coup ×1,9 en coup de pied retourné, reprise au 1er coup), les 4 sorts touchent, 2 doubles
  apparaissent puis disparaissent, ultime retardé par la charge, Artiste martial inchangé ; lobby et Héros (5 sections) ouverts avec la classe.
- `test_texts_fr` étendu aux classes maison (sorts, cartes de classe) : **vert**.
- Sur une copie de HEAD (`run_tests.py -j 2`) : **8 verts sur 8** (`test_build`, `test_chr1`, `test_ico1`, `test_names_fr`,
  `test_nav_screens`, `test_pages`, `test_skills`, `test_texts_fr`) ; `check_scripts.py --head` **vert** (584 scripts).
- Piège rencontré (pour la coordination) : avec l'index partagé périmé, `run_tests.py` prend les fichiers commités par index
  temporaire pour des fichiers « non suivis » et **les retire de sa copie** (65 fichiers de HEAD manquants, dont ceux du lot et ceux de
  NET-0 / MB-B) : il faut remettre les fichiers de `git ls-tree HEAD` absents de la copie, puis `--reuse`.

## Limites honnêtes du prototype
- **De près**, les mèches sont des cônes nets et le bandeau un anneau lisse : à la caméra du jeu, la silhouette se lit.
- **Poses procédurales** figées (pas d'anticipation ni de rebond) ; de dessus, le coup de pied se devine surtout au tour sur soi.
- Les **impacts d'Eden** (blanc-bleu, orange) sont gros : de près ils couvrent les gestes (réglage « Intensité des effets »).
- Les **doubles** ont l'IA des adversaires scriptés : ils esquivent (« ESQUIVE ! ») et lisent les zones.
- En **duel** et dans les modes d'équipes la classe se joue, mais n'a ni profil « opti » (`build_profiles.json`) ni cerveau ; elle
  n'est jamais tirée comme adversaire ou allié.

## Suite possible (si le joueur garde la classe)
Valider le design et les noms ; une illustration et un portrait originaux ; convertir des animations d'Eden manquantes (course,
coups de pied) ; arbre de talents (`build_talents.py` ne connaît que les classes d'Eden) ; profil « opti » ; facteur de la Tour ;
décider si elle entre dans les tirages des modes à IA (alors : `GameData.classes`, tests « 60 classes », `ML_CLASSES` à la fin + nouvel entraînement).
