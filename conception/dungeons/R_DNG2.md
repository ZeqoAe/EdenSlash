# Lot DNG-2 : la partie visuelle des modes de boss (Donjons, Tour, Ruée, Siège) (17/10/2026)

Mandat : reste du backlog P0 de l'étude BM-DNG (`conception/benchmark/DONJONS_TOUR_RUEE_SIEGE.md`, recommandations validées), la
partie visuelle, sur le socle UIK-0 (UiTheme v2 « autocollant manga », StickerBox, UiFeel, polices) et les données livrées par DNG-1
(`R_DNG1.md`) : P0-1 barre de boss v2, P0-2 frise « À venir », P0-3 annonces à 3 niveaux, P0-4 télégraphes v2, P0-8 page Donjons v2,
P0-9 onglet « Rencontres » du Carnet, P0-7 habillage du bilan v2. **Équilibre intact** : PV fixes, briques, rythmes, dégâts et règles
de touche n'ont pas bougé (les ajouts au cerveau du boss sont en lecture seule ; test « PV fixes inchangés », « minuteur intact »).

## 1. Ce qui est fait

### Barre de boss v2 (P0-1) : `ui/boss_bar.gd` (`BossBar`, nouveau)
- Remplace le cadre de cible du HUD dès que la cible est un boss (`Hud._update_target` -> `BossBar.show_for`), partout où il y a un
  boss : Donjons, Tour, Ruée, Siège, Survie, Survivant. Papier contouré d'encre, ombre dure (maquette `v2_barre_boss.svg`).
- **Médaillon** : rendu du modèle d'Eden du boss (`ui/boss_portrait.gd`, `BossPortrait`, nouveau) sur des rayons de soleil, dans la couleur
  de la famille de sa 1re mécanique ; rendu une fois par modèle dans une SubViewport hors écran (file d'attente : un rendu à la fois, une
  liste de 48 boss ne fige rien), gardé en mémoire ; sans écran (tests), l'initiale du boss en Mochiy.
- Nom complet, **pastille de difficulté** (Normal lagon, Héroïque améthyste, Mythique mandarine ; Tour : Facile … Hardcore ;
  « Lieutenant »), **minuteur de fureur** fraise : Impatience des boss de la bibliothèque (« Fureur 1:48 », puis « Fureur ×2 »,
  `BossBrain.fury`), rage du boss de la Survie (« Rage 0:42 », « Rage ×3 », `RunDirector.boss_rage_*`).
- **Jauge** 30 px (creux d'encre, remplissage fraise en deux tons, trace claire des dégâts, bord droit d'encre ; lagon tant que le boss est
  sous bouclier ou barrière) avec les **seuils réels** (`BossBrain.thresholds` : la fureur à mi-vie et chaque seuil `at` des briques), une
  encoche d'encre et une pastille de la couleur de la famille sous chacune (grise une fois passé), la part des PV au centre (« 62 % »,
  comme la maquette validée).
- Dessous : les **pastilles des mécaniques** du boss (icônes d'état du jeu sur la couleur de leur famille ; l'active grossit et se cercle
  de blanc) et la **ligne d'incantation** mandarine qui se vide (« Pluie de météores · bouge ! », `BossBar.CAST_HINT`, 20 signes au plus).
- **Ne cache jamais le boss** : s'il passe sous la barre, elle s'efface à moitié ; hors de la vue, une **flèche soleil** au bord de
  l'écran le montre (toujours sous la barre et ses pastilles, jamais posée dessus).
- Largeur : l'espace entre la pile de gauche et la mini-carte (480 à 720 px) ; vérifié en 1280×720 (500 px) et 1600×900 (720 px).

### Frise « À venir » (P0-2) : `ui/boss_timeline.gd` (`BossTimeline`, nouveau)
- Puits d'encre à droite, sous le compteur de dégâts : la mécanique en cours (« maintenant », fraise), les périodiques dans l'ordre de
  **leur vrai minuteur** (« dans 6 s »), puis celles qui tombent à un seuil de PV (« à 35 % »). Tout vient de `BossBrain.upcoming(n)`
  (minuteurs `_brick_t`, miroir, onde de fureur en 2e phase, seuils pas encore passés) : rien n'est inventé ni estimé.
- 2 à 4 lignes selon la hauteur libre (jamais sur la barre de sorts : 2 en 1280×720, jusqu'à 4 en 1600×900).
- Affichée par défaut, **réglage** Paramètres > Caméra & interface > « Frise « À venir » des boss » (`interface/boss_timeline`).

### Annonces à 3 niveaux (P0-3) : `ui/hud_alert.gd` (`HudAlert`, nouveau)
- Les annonces des mécaniques du boss suivi (et celles qui suivent : barrière brisée, fureur à mi-vie, impatience, miroir) quittent le
  bandeau pour une alerte au centre, au-dessus du héros : **mineure** (renforts, invocations, résultats : texte seul contouré),
  **moyenne** (bulle lagon + son court), **critique** (cercle sûr, regard, tourbillon, arène qui se resserre, rage, fureur : bulle fraise
  inclinée de −3°, plus grande, son d'impact). Jamais de vibration (bible § 7).
- **28 signes au plus** (`BossBar.alert_text` : l'annonce si elle tient, sinon son texte court `SHORT`, sinon ce qui précède les
  deux-points : « Barrière brisée ! ») ; contrôlé sur **toutes** les annonces de `boss_bricks.gd` (lues dans la source par le test) ;
  largeur bornée à l'écran (passe à la ligne au besoin). Noms toujours ceux du jeu en français (`short_name`, NamesFr).
- Les autres messages (intro du boss, salles) gardent le bandeau, **décalé sous la barre** quand elle est affichée.
- Sons de la bibliothèque SND-1 : `alert_crit` (impact bref), `alert_mid` (notification), `tele_arm` (tic) dans `Sfx.UI`.

### Télégraphes v2 (P0-4) : `combat/telegraph.gd`, `shaders/telegraph.gdshader` (nouveau)
- Zones des attaques ennemies : **bord net** (bande d'encre et liseré papier au milieu), intérieur **hachuré** fraise en diagonale
  (lisible sans la couleur) et cœur qui monte jusqu'au bord pendant l'armement, 35 % d'opacité au plus ; **compte à rebours** (« 1,9 s »)
  sur les zones d'au moins 5,5 m.
- **Zone sûre** (sans dégâts, verte) : pomme, bord en **pointillés**, mot « SÛR » face caméra.
- **Danger immense** (anneau de 30 m et plus autour d'un cercle sûr — Cercle sûr, Bourrasque — ou cercle de 16 m et plus) : seul le bord
  intérieur est peint et le voile s'efface en 5 m : on peint la frontière du sûr, plus jamais un écran rouge plein.
- **Son court à l'armement** des zones de boss et d'élites à mécaniques (`tele_arm`, au plus un toutes les 40 ms).
- Les annonces discrètes (`small` : monstres ordinaires, arrivées, zones du héros), les traits de projectiles et les pièges du Duel
  gardent le dessin d'avant. Couleur du danger = fraise de la bible (`Telegraph.COLOR`).
- **Seul l'aspect change** : formes, délais, dégâts, `contains`, `_resolve` sont ceux d'avant.

### Page Donjons v2 (P0-8) : `ui/dungeon_page.gd` (réécrite)
- Fiche du boss : médaillon sur la couleur de sa famille, nom en Mochiy, titre et niveau, sa phrase, victoires, meilleur temps et plan.
- Mécaniques en **pastilles** (icône, nom, conseil d'entrée ; le conseil après chute `HitLog.TIPS` en infobulle), l'Impatience « en
  Mythique » quand le boss ne l'a pas.
- Difficulté en **onglets nets** : l'actif mandarine plus haut, les autres papier, le verrouillé gris tramé avec 🔒 et sa condition en
  infobulle, ✔ sur une difficulté déjà battue (corrige l'état ambigu relevé par l'étude) ; jauge de PE et estimation (`DifficultyPanel`) ;
  « Tes records en Normal : boss 1:58 · donjon 4:12 ».
- **Butin en cases** : une case autocollante par emplacement de la panoplie (icône du jeu, cochée pomme si la pièce est déjà à toi),
  le plan avec la pastille « Garanti 1re fois », « Gants déjà à toi : on te proposera la tête ».
- Liste **par zone** (« Mine d'Andrew V · niv. 14 », « 1 / 6 vaincus ») : tuiles avec médaillon, emplacements · panoplie, points des
  familles de mécaniques et **médailles N / H / M** ; la tuile choisie en lagon, une zone fermée grise tramée avec sa condition ;
  pied « 48 boss · N / 48 vaincus · N plans à trouver ». Filtres, alliés et bouton épinglé « Entrer : … » inchangés.

### Journal des rencontres (P0-9) : `ui/encounter_journal.gd` (`EncounterJournal`, nouveau)
- Onglet « Rencontres » ajouté **à la fin** de `CarnetPages.tabs()` (la Collection garde l'indice 4), sur les données de DNG-1
  (`Encounters.card / all / counts`, `BestTimes`).
- À gauche, puits d'encre : les 48 boss par zone, 6 par ligne (vaincu : coche pomme ; rencontré : en couleurs ; jamais rencontré : éteint ;
  zone fermée : « ? » tramé, nom caché) ; compteurs « 2 / 48 vaincus · 3 rencontrés » et « Mécaniques vues : 5 / 29 ».
- À droite, la fiche : médaillon, nom et titre, zone, « Rencontré dans : Donjons, Tour », panoplie et emplacements (cochés si déjà à toi),
  mécaniques (vues : « vue 9 fois » ; pas encore vues : grisées mais **le conseil reste lisible**), records par difficulté (victoires,
  meilleur temps du boss et du donjon complet), « Ton meilleur sans le battre : il lui restait 37 % », et **« Aller à son donjon »**
  (ferme le Carnet, ouvre la page Donjons sur ce boss ; grisé avec la condition si les Donjons ou sa zone sont fermés).
- `PageScreen` : avec sept onglets, ils perdent leur largeur minimale et prennent un cran de moins (M PLUS Rounded 800 sous 1500 px) : le
  Carnet tient en 1280×720 et 1600×900.

### Bilan v2 (P0-7, habillage) : `ui/results_panel.gd` (blocs du lot DNG-1 seulement)
- « Record ! » en **pastille mandarine** sur la tuile du temps ; objectifs en **autocollants** (soleil tenus, gris tramés sinon, « nouvelle »
  en mandarine) ; **butin en cases** de la couleur de la rareté (icône de l'objet, ou du coffre, ou du plan) avec nom et détail ; la pièce
  qui manque dans une **bande pomme** ; « Ce qui t'a battu » en puits d'encre bordé de fraise, titre Mochiy fraise, **une pastille de
  mécanique par ligne**, conseil en soleil. « Réessayer le boss » (DNG-1) reste le bouton principal après une chute devant le boss.

## 2. Lecture seule du cerveau (`ai/boss_brain.gd`)
Ajouts sans effet sur le combat : signal `brick_started`, `age` (horloge du HUD, comptée dans `_physics_process` avant tout retour),
`last_cast` / `last_cast_at` (posés par `note_cast`), `active_cast()`, `thresholds()`, `upcoming(n)`, `fury()`. Les minuteurs, seuils,
rythmes et dégâts ne sont lus nulle part ailleurs que par le HUD. `boss_bricks.gd`, `boss_library.gd`, `dungeons.gd` : non touchés.

## 3. Mesures et vérifications
Sur une **copie propre de HEAD (0.1.272) + ce lot** (`run_tests.py --snap … --reuse`), le travail en cours des autres sessions n'y entre pas.
- `test_dng2` (nouveau, 73 contrôles) : tables (icône, consigne, nom pour les 29 briques et 5 attaques), 27 annonces des briques en 28
  signes, API du cerveau (seuils 70/50/35/30 %, ordre de la frise, mécanique en cours, Impatience, minuteur intact, attribution intacte),
  télégraphes (danger, compte à rebours, sûr, immense, dessins simples, 35 %, fraise) ; **partie réelle** (salle du boss d'un donjon) en
  1280×720 et 1600×900 : barre et pastilles dans l'écran, ni sur la pile de gauche ni sur la mini-carte, une encoche par seuil réel, frise
  dans l'écran et au-dessus de la barre de sorts, annonce critique / moyenne / longue raccourcie, intro sous la barre, flèche hors vue,
  réglage de la frise, PV fixes inchangés, barre retirée à la mort ; page Donjons v2 (48 tuiles, onglets, cases, records) ; Carnet >
  Rencontres (dernier onglet, 48 fiches, nom caché mais conseils lisibles, dans l'écran en 1280×720 et 1600×900, « Aller à son donjon ») ;
  bilan v2 (pastille Record, cases, dans 1280×720, pastilles de « Ce qui t'a battu »).
- Mis à jour et verts : `test_dng1` (barre v2 dans l'écran), `test_pages` (7 onglets du Carnet), `test_nav_screens` (Rencontres, tuile
  des Donjons), `test_texts_fr` (noms, consignes, annonces, lignes de butin), `test_p11` (rage de la Survie sur la barre, encoche à mi-vie),
  `test_m2` (toute zone immense des 48 boss peinte par son bord), `test_m3` (barre et difficulté de la Tour), `test_m6` (barre de la Ruée).
- Verts aussi : test_hud, test_results, test_uik0, test_a1, test_a2, test_m7, test_m8, test_siege, test_tower, test_p12, test_p13, test_p15,
  test_p16, test_p18_modes, test_p2, test_p4_flow, test_bri1, test_bri2, test_royale, test_hub1, test_duel_modes, test_pvp, test_snd1,
  test_lot13, test_lot13b, test_sv1, test_p1.
- Captures **regardées** (hors dépôt) : `tests/shot_dng2.tscn` -> `user://shots/dng2_<cas>_<largeur>.png` (page Donjons haut / bas / liste,
  Rencontres Latif / Argus, bilans victoire et défaite, combat : météores, cercle sûr, bourrasque, boss hors vue) en 1600×900 et 1280×720 ;
  `shot_m2`, `shot_m3`, `shot_m6` refaites.

## 4. Ce qui reste
- P1 de l'étude : étoiles de donjon au chrono (P1-1 ; le bilan sait déjà les montrer), défi de la semaine, relève (« Relève 1 » collé aux
  PV), « S'entraîner » (P1-4), première rencontre d'une mécanique, coups signatures, faveurs de la Tour, Ombres mises en scène, Siège lisible
  (deux barres lieutenant + boss), Ruée chronométrée, palette des télégraphes réglable (les formes, elles, sont fixes).
- « Autre boss » au bilan (maquette) : il faut une demande d'ouverture du lobby sur la page Donjons (comme `Survivor.lobby_request`).
- Le mur de l'arène qui se resserre (`BossBricks.ArenaWall`) garde son anneau à lui (fraise désormais, via `Telegraph.COLOR`) : l'anneau
  mandarine de la spec demanderait de toucher `boss_bricks.gd`, laissé intact par consigne.
- Sons provisoires choisis dans la bibliothèque SND-1 ; une signature propre « gong » pour le critique serait mieux (département SND).

Aucun texte ni image tiers dans ce lot (icônes et sons : ceux du jeu et de la bibliothèque SND-1 ; maquettes maison).
