# R_BRI1 : HUD v2 du Battle royale (backlog P0 n° 1 à 5 de `conception/benchmark/BATTLE_ROYALE.md`, 17/10/2026)

DA « autocollant manga » (Bible v2) : boîtes et boutons d'UiTheme v2 (`UiTheme.sticker`, `panel_style`, `style_button`),
polices Mochiy Pop One / M PLUS Rounded 1c, dessin à la main (flèches, épingles, jauges) dans `ui/royale_hud_style.gd`.
Aucune règle de jeu ne change ; mode scellé inchangé.

## Fait
1. **HUD d'état v2** (`ui/royale_hud.gd`, posé par `Hud._build` si `Royale.active`) : en haut à gauche l'objectif court
   (« Anneau 2 / 5 » + une ligne : mis à prix, « Rejoins la zone sûre ! », largage…) à la place du panneau d'objectifs ;
   sous la mini-carte 3 tuiles d'encre (en vie, élim., niveau / plafond ; fraise si tu es mis à prix, soleil au plafond),
   barre de l'anneau (« Se referme 1:10 », fraise pendant le resserrement ; au largage « Au sol 3 / 8 »), fil des
   éliminations en pastilles (les tiennes en soleil, une ligne par élimination, 3 au plus sous 800 px de haut).
   Plus de pourcentage ni de mot technique : orbe de niveau sans « 0 % », plus de « ASSISTÉ », message « Hors de
   l'anneau ! Suis la flèche violette » (avant : « 3 % des PV par seconde »). Cases de sort vides tramées
   (`HudWidgets.SkillSlot`, tous les modes : la Bible interdit « — »).
2. **Direction de l'anneau** : flèche améthyste au bord de la zone de jeu (`ui/royale_edge.gd`) avec « Zone sûre · 140 m »
   quand on est dehors (ou dehors du prochain anneau qui va se resserrer) ; ligne pointillée vers la zone sûre sur la
   mini-carte (crochet `RoyaleMap.minimap_overlay` dans `Minimap._draw`) et sur la grande carte.
3. **Arc de coup reçu** (`ui/hit_arc.gd`, nouveau signal `Combatant.damaged(montant, auteur)`) : arc fraise contouré
   400 ms + fondu, du côté de l'auteur, ravivé s'il frappe du même côté, vibration (0 ; 0,35 ; 0,09) ; pas d'arc sans
   auteur (anneau). Aussi en Duel et Arènes (`HitArc.attach`). **Héros proches hors de la vue** (< 40 m) : flèche fraise
   avec la couleur de sa famille.
4. **Repère personnel** (`ui/royale_ping.gd`, action `ping` réassignable : clic molette, L3) : au sol sous la souris,
   devant le héros (30 m) à la manette, sur la grande carte (clic, X à bord). Épingle lagon avec la distance, flèche au
   bord quand il est hors de la vue, sur la mini-carte et la grande carte ; reposé au même endroit il s'enlève, atteint
   il s'efface. Nom du lieu nommé du lot BR-I2 s'il est posé dedans (« Halle aux saules · 86 m »).
5. **Grande carte v2** (`ui/royale_map.gd`, remplace l'ancienne en Battle royale) : carte carrée à gauche (terrain,
   dehors teinté améthyste, anneau, prochain anneau en pointillés, lieux nommés ★, coffres aux couleurs de rareté,
   largage, mis à prix, repère, toi), panneau à droite (légende hors de la carte), zoom ×1 / ×2 / ×3,5 (molette, R3)
   qui garde le point visé sous le curseur. **Ouverte seule pendant le vol** : « Où atterrir ? », saut automatique,
   « Repère posé · Atteignable en chute », « N héros visent : lieu », trajet de l'aigle et bande atteignable,
   **« Sauter » sur A** (portes fermées : grisé), B ferme ; elle se ferme au saut. Le reste du HUD s'efface sous la carte.

## Décisions
- Repère sur **L3** (libre en Battle royale ; R3 est « Changer d'arme », sans objet ici mais gardé libre pour test_n2)
  et **clic molette** (un clic sans glisser, 0.1.264 : en mode « clic droit », le clic molette maintenu tourne la caméra) ;
  à bord, X pose le repère (lagon = couleur du repère), A saute (consigne), Y garde son saut.
- La carte **ne met pas le jeu en pause** (comme avant) ; au sol, à la manette, le stick droit mène le curseur et la
  caméra attend (`CameraRig.allow_input`), rendue à la fermeture.
- Flèches posées dans un cadre qui évite les panneaux (objectif, colonne de droite, barre d'action ; aide du largage
  comprise) ; direction calculée par la caméra (comme la flèche d'objectif de la Survie), pas par projection.
- Nom de classe en collision avec BR-I2 (`RoyaleStyle`, créé en même temps) : mes briques sont `RoyaleHudStyle`.

## Mesures
- Coût du HUD du Battle royale : mise à jour **0,04-0,06 ms** par image (`test_bri1`, meilleure de 7 séries de 100,
  `shot_bri1` fenêtré) ; rendu processeur **+0,01 à +0,04 ms** (fenêtre, HUD affiché contre caché). Budget 0,3 ms.
- Mise en page vérifiée à 1600×900 et 1280×720 (tests + captures `tests/shot_bri1.tscn`, `BRI1_RES=1280x720`) :
  carte 820 / 656 px, panneau collé en haut, colonne de droite au-dessus de la barre d'action (bas 510 px, barre 516).

## Tests
`test_bri1` (nouveau, ~60 contrôles : action, objectif, carte du vol, repère carte <-> monde, zoom, « atteignable »,
A = Sauter, tuiles, barre de l'anneau, fil, flèche orientée et au bord, héros hors de la vue à 34 / 65 m / dans la vue,
arc à droite puis à gauche, ravivé, sans auteur, repère manette / souris / atteint, carte au sol, 2 résolutions, coût) :
vert 6 / 6. Verts sur copie propre 0.1.260 + BR-I1 : test_hud, test_royale, test_br2, test_br3, test_br4, test_bri2,
test_m1, test_nav_screens, test_n2, test_controls, test_texts_fr, test_duel_modes, test_uik0.
**Instable avant moi** : `test_royale` « points d'atterrissage distincts et éloignés » échoue 1 fois sur 4 sur HEAD seul
(deux cibles de saut à 8-15 m, `RoyaleDrop.plan` : le repli « aucun coffre libre » ne vérifie pas l'écart) ; non touché.

## Reste / pièges
- Cadre de cible (haut centre) et bandeau d'annonce encore en DA v1 : lot P1 n° 18 (annonces centrales).
- Les captures `shot_br4` posent la taille de fenêtre avant `Settings.reset_all()` (qui la remet à 1600×900) :
  `BR4_RES` ne marche pas ; `shot_bri1` le fait dans le bon ordre.
- Fichiers partagés touchés (crochets minces) : `ui/hud.gd`, `ui/hud_widgets.gd`, `ui/minimap.gd`, `combat/combatant.gd`
  (signal), `core/settings.gd` (action), `core/royale_director.gd` (une ligne de message).
