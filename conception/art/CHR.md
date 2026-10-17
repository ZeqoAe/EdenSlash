# CHR : ce qu'on sait faire sur un héros (animation, texture, géométrie, effets) — rapport de limites (17/10/2026)

Département Personnages (`ORGANISATION.md`), lot CHR-1. Question du joueur : « montrez-moi les limites de ce que vous savez faire en
animation et en texture sur un héros », avec un cas réel : une classe 61 de ninja blond (« Ninja du Tourbillon » en jeu, design
*inspiré*, aucun nom ni symbole d'une œuvre). Le prototype jouable et ses mesures sont dans `R_CHR1.md` ; ici, ce qui est possible,
difficile ou hors de portée, **essayé** quand c'était faisable dans la journée.

**Preuves.** Les images du design (héros ninja, GIF des sorts, concept, essais IA) restent **hors du dépôt** (dépôt public, design
inspiré d'une œuvre protégée), dans `C:\AI\chr1\` sur le PC :
| Fichier (hors dépôt) | Ce qu'il montre |
|---|---|
| `captures\chr1_look_plate_v4.png` | le héros sous 8 angles : face, trois quarts, profil, dos, visage, garde, course |
| `captures\chr1_compare_plate_v4.png` | pas à pas : classe voisine d'Eden → pièces d'Eden → teintures et bandeau → traits du visage → mèches → rubans |
| `captures\gif\combo.gif`, `clone.gif`, `star.gif`, `orb.gif`, `ult.gif` (+ `*_planche.jpg`) | chaque geste en jeu, caméra du jeu, vrai monde |
| `captures\chr1_fight_still.png` | doubles et charge de l'ultime dans la même image, HUD |
| `captures\chr1_uv_plate.png`, `uvpaint\planche_uv.jpg` | tenue repeinte par IA sur ses UV (débruitage 0,3 / 0,5 / 0,7) |
| `concept\planche.jpg` | 3 concepts 2D (SDXL + LoRA maison 0,5) |
| `hair3d\planche.jpg`, `captures\chr1_hair3d.jpg`, `hair3d\cheveux_s9.glb` | essai de coiffure image → 3D (3 vues Blender + l'image source) |
| `anims\inv\sheet_*.png`, `anims\pose_*\strips_0.png` | inventaire des animations, poses procédurales |

Dans le dépôt (rien de propre au design) : `chr/inventaire_animations.jpg` (les 61 animations d'attaque du corps commun, figées à
l'impact), `chr/poses_procedurales.jpg` (les 4 poses du calque `ProcPose` sur l'Artiste martial), `chr/icones_ninja.png` (les 5 icônes).

Échelle : **facile** = quelques heures d'un agent, sans risque ; **moyen** = 1 à 3 jours, résultat correct à la distance de jeu ;
**dur** = une semaine ou plus, résultat incertain ou à reprendre à la main ; **non** = hors de portée aujourd'hui (outil absent,
qualité insuffisante, ou droit d'usage douteux). Coûts en jours-agent, machine actuelle (RTX 5070 12 Go partagée).

## 1. Géométrie du héros
| Besoin | Note | Coût | Ce qui a été fait / constaté |
|---|---|---|---|
| Changer de tenue (pièces d'Eden) | facile | 0 | 127 costumes d'Eden, tous sur le même squelette ; la « tenue de ninja » d'Eden (`cos_l238`) existait déjà |
| Coiffure parmi celles du jeu | facile | 0 | **6 coiffures seulement** (l102 à l108) ; « En bataille » (l103) est la plus proche des pointes |
| Coiffure en pointes ajoutée par code | facile | 2 h | 10 cônes posés sur l'os de la tête (`ClassLook` « spikes ») : la silhouette se lit à la caméra du jeu ; de près, ce sont des cônes nets sans mèches |
| Coiffure neuve « image → 3D » (Pixal3D) | dur | 2-4 j | **essayé** : SDXL **dessine toujours une tête** sous la coiffure (3 graines sur 3, malgré le négatif) ; Pixal3D en fait en 5 min un volume de pointes **convaincant** (`captures\chr1_hair3d.jpg`) mais d'un bloc avec le visage, le cou et le col (148 000 faces, 20 Mo) : il faut découper la tête, réduire à ~3 000 faces, recaler sur le crâne chibi, accrocher à `Bip01 Head` et refaire la texture. Rigide (pas de mèches qui bougent) |
| Coiffure modelée à la main (Blender) | dur | 3-5 j | l'agent sait placer des formes par script, pas sculpter avec goût ; un artiste 3D le ferait en une demi-journée |
| Bandeau frontal | facile | 2 h | anneau de tissu + plaque lisse **par code** (`ClassLook` « band »), accroché à l'os de la tête ; l'accessoire d'Eden « Ronin » était trop chargé (gros nœud, motif) |
| Accessoire rigide (masque, sacoche, kunaï à la ceinture) | facile | ½ j | chaîne PRP (`PRP.md`) : image → 3D → nettoyage → `BoneAttachment3D` ; budget 3 000 triangles |
| Rubans, écharpe courte | moyen | 1 j | **fait** : 2 rubans à ressort (chaîne de 7 points intégrée, bande face caméra) qui traînent derrière en course |
| Cape, écharpe longue qui suit le corps | dur | 3-5 j | il faut un maillage à os (Blender) puis `SpringBoneSimulator3D` (Godot 4.4+) ; collisions avec le corps chibi (grosse tête) à régler |
| Silhouette du corps (plus grand, plus mince) | non | — | un seul corps chibi pour tout le jeu ; tout changement casse les 127 tenues et les animations |

## 2. Textures
| Besoin | Note | Coût | Ce qui a été fait / constaté |
|---|---|---|---|
| Recolorer une tenue (3 couleurs) | facile | 0 | masques R/V/B d'Eden (`apply_dye`) : orange / noir en une ligne de données |
| Cheveux d'une autre couleur | facile | 1 h | variante grise teinte ; **le blond vif demande d'éclaircir la texture** avant la teinte (`hair_gain` 1,8) sinon il tire sur l'olive |
| Marques peintes sur le visage | facile | 2 h | **fait** : 3 traits au pinceau effilé peints par code sur une copie de la texture du visage (512², moitié de visage en miroir : les deux joues d'un coup) |
| Retexture précise sur des UV existants (motifs, coutures) | moyen | 1-2 j | faisable par code pour des formes simples ; un dessin libre demande de connaître l'atlas île par île |
| Repeindre une tenue par IA sur ses UV (image vers image) | dur | — | **essayé** : à débruitage 0,3 rien ne change ; à 0,5 un léger effet « peint » ; à 0,7 l'IA **ignore les îles d'UV** (coutures, panneaux qui ne se raccordent plus) : ce n'est pas une vraie nouvelle tenue |
| Texture neuve projetée depuis plusieurs vues (StableProjectorz, MV-Adapter, Paint3D…) | dur | 3-5 j | outils absents, installation lourde, 12 Go de VRAM partagés ; résultat à juger |
| Style toon (ombrage, liseré) | facile / moyen | ½-2 j | `eden_character.gdshader` ; contour encré (coque inversée) = moyen |

## 3. Squelette
Le corps commun (`body_m.glb`) a **40 os** Bip01 : bassin, colonne (3), cou, tête, bras (clavicule, bras, avant-bras, main, 2 doigts
× 2 phalanges), jambes (cuisse, mollet, pied, orteil), plus **2 chaînes de cheveux de 3 os** (coiffures l103 et l105) et 2 os de
manches. Les accessoires articulés d'Eden ajoutent leurs os au chargement (`EdenModel.dress`, renommés « pièce~os »).
| Besoin | Note | Coût | Constat |
|---|---|---|---|
| Ajouter des os au chargement | facile | 0 | déjà fait par le jeu pour les ailes et chapeaux d'Eden |
| Os « dynamiques » (cheveux, rubans) | moyen | 1-2 j | `SpringBoneSimulator3D` existe (Godot 4.4+) et irait sur les chaînes `Bone_L103_Hair` ; il faut retirer leurs pistes des animations d'Eden. Pour ce lot : rubans **sans os** (Verlet), plus simple et moins cher |
| Doigts, visage animé (bouche, sourcils) | non | — | 2 doigts par main, aucun os de visage : pas de signes de mains détaillés, pas d'expression (le visage est une texture) |

## 4. Animations
**Inventaire** : 194 noms d'animations d'Eden connus (`motion_keys.json`), **94 présentes dans le corps du jeu** (27 attaques, 34
gestes de sort, 13 gardes, 11 déplacements, 3 sauts, 3 attentes…) ; les autres n'existent que dans des .kfm d'armes non convertis. **Aucun coup
de pied, aucun signe de mains**, des courses d'Eden génériques (pas de course ninja bras en arrière).
| Besoin | Note | Coût | Constat |
|---|---|---|---|
| Réutiliser les animations d'Eden | facile | 0 | planche `chr/inventaire_animations.jpg` pour choisir à l'œil (outil `tools/anim_sheet.tscn`) |
| Convertir les ~100 animations manquantes (.kfm d'Eden) | moyen | 1-2 j | chaîne `tools/nif2gltf.py` existante, session locale avec le client |
| Recomposer une attaque (vitesse, enchaînement, tour sur soi, salto) | facile | 2 h | **fait** : taï-jutsu en 3 étapes (direct, crochet, coup de pied **retourné** = animation d'Eden + tour du modèle + pose) |
| Gestes procéduraux sur le squelette | moyen | 1 j | **fait** : calque `ProcPose` (SkeletonModifier3D) qui oriente bras, jambes et buste, mélangé à l'animation (montée 0,08 s, retombée 0,16 s) : coup de pied, signe des mains, sphère tenue, bras levé. Lisible à la caméra du jeu ; de près, gestes « figés » (pas d'anticipation ni de rebond, pieds non calés au sol) |
| Animer à la main dans Blender (clés) | dur | 1-2 j par geste | l'agent peut poser des clés par script, pas juger le rythme comme un animateur ; résultat « robotique » sans retouches humaines |
| Reprendre des animations externes (Mixamo, banques) | dur | 2-3 j | reciblage Bip01 → humanoïde faisable (`BoneMap`), mais proportions chibi (tête énorme, bras courts : mains dans la tête) ; Mixamo demande un compte et ses fichiers bruts ne doivent pas aller dans un dépôt public |
| Mouvement généré par IA (texte → mouvement : MDM, MoMask, HY-Motion…) | non (aujourd'hui) | 3-5 j d'essai | aucun modèle installé ; sorties sur squelette SMPL, à recibler ; bon pour marcher, courir, gestes génériques ; **faible pour un combat d'anime** (pas d'anticipation, de poses-clés marquées, de « smear »), pieds qui glissent. À tester seulement si le joueur veut un essai |
| Vidéo → mouvement (capture depuis une vidéo) | dur | 3-5 j | mêmes reciblage et nettoyage ; droit d'usage de la vidéo source |

## 5. Effets
| Besoin | Note | Coût | Constat |
|---|---|---|---|
| Effets d'Eden (impacts, auras, sorts) | facile | 0 | des centaines d'effets convertis (`EdenFx`) ; ex. fumée d'apparition du « clone » d'Eden pour le Double de brume |
| Sphère tourbillonnante | facile | 3 h | **fait** : shader `swirl_orb` (spirale qui tourne et s'enroule, cœur, liseré), additif |
| Projectile à forme (étoile de lancer) | facile | 1 h | **fait** : étoile à 4 branches qui tourne (`HeroBolt` style « shuriken ») |
| Grande étoile à lames de vent | facile | 2 h | **fait** : 4 lames courbes générées, qui tournent autour de la sphère |
| Explosion en dôme, ondes, lames | facile | 2 h | **fait** avec les briques `Vfx` (ondes, éclairs, arcs) + la sphère agrandie |
| Fumée | facile | 1 h | particules CPU (quads, dégradé) |
| Effets « peints » (sprites animés générés par IA, planches) | moyen | 1-2 j | SDXL + LoRA pour des planches d'images, détourage ; animer une planche reste du travail |
| Traînées de mains / pieds (sans arme) | moyen | ½ j | la traînée du jeu suit la lame de l'arme (W1 / W2) ; pour les poings il faut des points sur les os des mains |
| Doubles (clones) | facile | ½ j | **fait** : de vrais héros alliés IA (`ClassRival`) habillés comme le joueur, 6 s, fumée à l'apparition et à la disparition ; ils esquivent et attirent les coups. Limite : leur IA est celle des adversaires scriptés (esquives, annonces de coups) |
| Lisibilité (beaucoup d'effets) | moyen | — | les impacts d'Eden sont gros : de près ils cachent le geste ; réglages « Intensité des effets » existants |

## 6. Caméra, moments forts
| Besoin | Note | Coût | Constat |
|---|---|---|---|
| Caméra qui se rapproche pendant la charge | facile | 1 h | **fait** (−22 % de distance, retour en 0,45 s ; jamais en duel, ni pour une IA) |
| Secousses, arrêt sur image à l'impact | facile | 0 | existants (`_shake`, `_hit_pause`) |
| Bandeau « ultime » avec portrait qui glisse (cut-in manga) | moyen | 1 j | l'illustration est une image propre au design : hors dépôt, ou une illustration originale à faire valider |
| Ralenti, temps arrêté, caméra de cinéma | moyen / dur | 2-3 j | ralentir le jeu ralentit tout le monde : seulement en solo ; caméra scriptée = beaucoup de cas (murs, mini-carte, contrôle rendu) |

## 7. Ce qui coince vraiment (en une ligne chacun)
1. **Un seul corps chibi, 94 animations** : tout geste neuf est soit une recomposition, soit un calque procédural ; pas d'animateur.
2. **Modèles neufs organiques** (cheveux, visage, vêtement souple) : l'image → 3D donne des objets rigides propres, pas des cheveux
   ni des tissus prêts à animer.
3. **Texture neuve cohérente sur des UV** : l'IA ne respecte pas l'atlas ; les retouches par code se limitent à des formes simples.
4. **Mouvement par IA** : pas prêt pour un combat d'anime chibi sans reprise manuelle.
5. **Droits** : tout ce qui copie une œuvre (logo, symbole, nom, silhouette trop exacte) reste hors du dépôt public.

## 8. Ce que je recommande
- **Garder** pour les classes maison la recette de ce lot : pièces d'Eden + teintures + petits ajouts par code (bandeau, mèches,
  rubans, traits du visage) + poses procédurales + effets par shader ; c'est rapide (2-3 jours par classe) et ça tient à la distance
  de jeu.
- **Investir** si le joueur veut monter d'un cran : (1) convertir les ~100 animations d'Eden manquantes (1-2 j, gain sûr) ;
  (2) `SpringBoneSimulator3D` sur les chaînes de cheveux existantes (1-2 j) ; (3) un contour encré du shader toon (1 j).
- **Ne pas investir** maintenant : mouvement par IA, texture IA projetée, coiffures image → 3D ; à reprendre si un vrai artiste 3D
  ou animateur rejoint le projet (une demi-journée de son travail vaut ici plusieurs jours d'agent).
