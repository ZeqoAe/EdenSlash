# R_MB_H : Les Deux Voies, lot MB-H — HUD et écrans en partie

Lot MB-H du plan `conception/benchmark/MOBA.md` (§ 7.7-7.9, § 9 ; croquis `moba_maquettes/v2_hud.svg`, `v2_boutique.svg`, `v2_bilan.svg`),
sur MB-D (héros, boutique : `R_MB_D.md`), MB-E (IA par poste : `R_MB_E.md`) et MB-F (jungle, objectifs : `R_MB_F.md`). DA v2 « autocollant
manga » (`conception/art/BIBLE.md` : encre, papier, bonbons, Mochiy Pop One / M PLUS Rounded 1c, UiTheme, UiFeel), socle du HUD v2
(`conception/hub/R_HUD2.md`). Le mode reste « Bientôt » (`Moba.READY` faux) ; l'interface de test de MB-D (ligne d'état, P / Ctrl + Z /
Ctrl + 1/2/3 dans le directeur) est retirée.

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| HUD du mode | `game/scripts/ui/moba_hud.gd` (`MobaHud`, nouveau) | posé par `Hud._build` (mode « moba »), par-dessus le HUD commun ; pièces dessinées à 10 i/s, données 4 i/s, vue de l'équipe 3 i/s |
| Boutique | `game/scripts/ui/moba_store.gd` (`MobaStore`, nouveau) | panneau sur la moitié gauche, 7 onglets, cartes, fiche, tes objets, achat / conseillé / annuler / vendre / achats automatiques |
| Bilan | `game/scripts/ui/moba_results.gd` (`MobaResults extends ResultsPanel`, nouveau) | raison de la fin (`Moba.decided_by`), tuiles, tableau des 8 héros, meilleur de la partie ; Rejouer / Menu par LoadScreen |
| Page du mode | `game/scripts/ui/moba_page.gd` (`MobaPage`, nouveau) | poste (conseillé ★ d'après la famille), difficulté, touches, « Entrer dans l'arène » (LoadScreen) ; `Lobby._show_menu("moba")` |
| Repères | `game/scripts/core/moba_pings.gd` (`MobaPings`, nouveau) | données des repères du joueur (sorte, lieu, cible, instant ; signal `bus.pinged`) pour le coach (MB-G) |
| Branchements | `ui/hud.gd` (3 lignes : `_moba`, attache, crochet de `show_message`), `core/moba_director.gd` (interface de test retirée, bilan `MobaResults`), `core/moba.gd` (`READY`, `visible()`), `ui/lobby.gd` (page), `tests/test_nav_screens.gd` (page atteignable) | — |
| Tests et captures | `game/tests/test_mb_hud.tscn`, `game/tests/shot_mbh.tscn` | § 4, § 5 |

## 2. Écrans (étude § 7.9)

- **Tableau (haut centre)** : 4 + 4 portraits (icône de classe sur la couleur de famille ; allié à coins ronds, adversaire à **coins coupés** :
  lisible sans la couleur), niveau de partie en pastille d'encre, point soleil = ultime prêt (alliés), mort = trame + secondes avant le
  retour, anneau lagon = toi ; puits central : éliminations de chaque équipe sur sa couleur et son **blason** (`TeamSigil`, couleur + motif),
  temps de partie, « tours 4 – 4 » ; Sceaux du Gardien en 3 plots mandarine sous chaque score, drapeau améthyste de la Bannière.
- **Minuteurs d'objectifs** (sous le tableau) : Gardien (mandarine), Colosse (améthyste) : compte à rebours, « en jeu », « au combat » + jauge
  de ses PV ; Marée (lagon) puis « Fin » (fraise dans la dernière minute) ; Bannière (alliée ou adverse) avec son temps.
- **Annonces, une à la fois** : la bulle de `HudAlert` (lot DNG-2 ; niveau 2 = fraise inclinée et son pour un danger, bonbon du sens sinon :
  soleil = bonne nouvelle, mandarine / améthyste = objectif, lagon = information), une ligne de détail dessous ; file à priorités (0 discret,
  1 information, 2 objectif, 3 moment fort ; une plus forte passe tout de suite, une égale après 0,8 s, une moindre attend 4 s au plus, 3 en
  attente au plus). Tous les messages du directeur et de la jungle passent par `MobaHud.announce_message` (crochet de `Hud.show_message`,
  après la barre de boss) ; « Niveau N ! » nourrit le bandeau de choix, « Tu es tombé » l'écran de mort. Moments du fil (`Moba.events`) :
  **Premier sang !**, **Série !** (3, 5, 7… éliminations), tour, objectif ; onomatopées Mochiy au-dessus du héros (`RoyaleAnnounce.word`,
  600 ms : « K.O. ! », « Tour ! », « Niveau ! », « Gardien ! »…).
- **Mini-carte (haut droite, 294 × 190 à 1600 × 900)** : toute l'aire de jeu (relief et voies de `MobaMap.minimap_info`), tours (carré à la
  couleur de l'équipe, trait blanc = PV entamés, ✕ = tombée), Cœurs, camps (plein = en vie, anneau = à venir), fosses (losange plein = boss en
  jeu), sbires, héros (alliés ronds, adversaires à coins coupés, toi = flèche soleil), repères, cadre blanc de la caméra ; **brouillard tramé**
  (encre + points papier) hors de 25 m autour des alliés et des structures alliées, et un adversaire (héros, sbire) n'apparaît que vu ainsi
  (`MobaHud.is_seen`, aussi pour les repères). Clic tenu : la caméra regarde là sans bouger le héros ; clic droit : repère ; [M] / Vue (hors
  base) : grande carte entre les minuteurs et la barre d'action. Le fil des éliminations (« Toi ⚔ Paladin » avec les points d'équipe), des
  tours, des objectifs et des repères est dessous (8 s).
- **Alliés (gauche)** : portrait, « Druide · 6 », PV, ultime prêt, ce qu'il fait : l'intention écrite du coach si l'IA en donne une
  (`MobaHero.ai.intent`, lot MB-G), sinon d'après sa place (à la base, rentre à la base, avec toi, au Gardien, Voie du Soleil, dans la jungle)
  ; mort : « tombé · revient dans 9 s ».
- **Barre d'action** (celle du HUD commun) : **plots d'enchaînements** sous chaque case, de part et d'autre de la touche (pomme = débloqué),
  ultime cerclé de soleil, verrouillé « niv. 5 » (trame + cadenas) ; **choix de niveau non bloquant** : bandeau soleil « Niveau 3 ! Un
  enchaînement : [Ctrl+2] [Ctrl+3] · [G] conseillé », cases possibles éclairées en pomme avec « + » et « Ctrl+N » (un clic sur la case
  choisit) ; [G] / → croix (`quick_equip`) prend le choix conseillé (`MobaHero.auto_choice`). La barre de niveau montre le **niveau de partie**
  (1-12) et son XP, jamais le niveau de la fiche (30-85). **Rappel** [X] : case ronde lagon à gauche des potions, anneau soleil pendant la
  canalisation (3 s avec la Bannière).
- **Or (bas droite)** : or, « Boutique [P] » (pomme et pulsé quand on est à la base et que l'étape suivante est payable), objet conseillé avec
  sa barre « 1 245 / 1 000 · à la base / prêt ! », les 6 places, potions de soin ; un clic ouvre la boutique.
- **Boutique** ([P] ; Vue à la base) : panneau papier sur la moitié gauche, la partie continue ; ouverte à la manette, la partie attend (UiNav
  ne navigue que les menus en pause : choix assumé en solo contre l'IA, la pause existe déjà). En-tête (À la fontaine / Pendant la mort /
  « Rejoins la fontaine pour acheter » : on regarde sans acheter), or, onglets Conseillé (« Ton parcours · Arcane », adapté à leur équipe),
  Attaque, Magie, Défense, Soutien, Bottes, Potions (LB / RB) ; cartes (case du type, prix réel, ✔ À toi, grise = impossible) : clic = fiche,
  double clic / clic droit / X = acheter ; fiche : type, prix (« reste 530 » / « il manque 300 »), ce que l'objet donne **en mots** (forte /
  moyenne / légère), effet en une phrase, chiffres en infobulle, recette (✔ ce que tu portes : « tu ne paies que la différence »), « Mène à » ;
  tes objets : **maintenir 0,6 s** (anneau fraise) ou clic droit pour vendre ; boutons Acheter (primaire), « Conseillé : … · [Entrée] »,
  « Annuler · [Ctrl+Z] » (tant qu'on reste à la base), « Achats automatiques » (`MobaHero.auto_pick` : le directeur achète le parcours et fait
  les choix de niveau). Aucun pourcentage dans les textes (contrôlé par le test sur les 7 onglets).
- **Tableau des scores** (tant que [Tab] / ← croix est tenu) : par équipe (couleur, blason, éliminations, structures, objectifs) les 4 héros
  (toi en tête et surligné), poste, retour, niveau, É / M / A, sbires, 6 objets.
- **Mort** : la barre d'action se range ; carte « Tombé ! » (fraise inclinée), « Retour dans 11 s », qui t'a battu (portrait, sort en cours :
  meta « move » de ClassRival, jauge des PV qui lui restent), d'où venaient les coups des 8 dernières secondes (jauges, sans pourcentage),
  touches [P] Boutique, [G] Regarder un allié (la caméra passe d'un allié à l'autre ; la réapparition la rend), [M] Carte.
- **Repères** (molette / L3) : appui = selon ce qui est visé (héros ou structure adverse vu : « Attaquez ! » avec sa cible ; fosse :
  « Objectif » ; sinon « Ici ») ; maintien 0,25 s = **roue** (Attaquez ! / J'y vais / Repli ! / À moi !, souris ou stick droit) ; épingle au sol
  avec la distance, sur la mini-carte et au fil. Les ordres aux alliés IA sont le lot MB-G : il lit `MobaPings.recent()` ou `bus.pinged`.
- **Bilan** (`MobaResults`) : VICTOIRE ! / DÉFAITE / ABANDON, « Les Deux Voies · Fin au temps (25:00) : plus de structures détruites
  (3 contre 1) » (Cœur détruit, structures, Cœur le moins entamé, objectifs, or, sbires, égalité, abandon), tuiles (structures, durée,
  éliminations, objectifs, ta partie), tableau des 8 héros (blason, classe, poste, niveau, É / M / A, sbires, or gagné, objets) défilant en
  1280 × 720, ★ meilleur de la partie (éliminations, aides, sbires, camps ; morts en moins). Récompenses scellées et quêtes : lot MB-I.
- **Mise en page** : tout est posé à l'échelle k = hauteur / 900 (0,8 à 1280 × 720, Bible) ; à moins de 1500 px de large, la pile de gauche
  (quête suivie) passe sous les minuteurs et les alliés dessous ; le cadre de cible et la barre de boss passent sous les minuteurs ; l'or
  reste au-dessus du numéro de version.

## 3. Coût (budget : 0,3 ms par image)

| Mesure | 1600 × 900 | 1280 × 720 |
|---|---|---|
| Mise à jour du HUD (`MobaHud.tick` : données, vue de l'équipe, brouillard, file d'annonces, mise en page), meilleure de 7 × 100 images, test headless | **0,022-0,029 ms** | — |
| Même mesure dans la vraie fenêtre (`shot_mbh`, 120 images, 3 passages) | 0,029-0,033 ms | 0,028-0,034 ms |
| Rendu processeur de la fenêtre avec / sans le HUD du mode (`viewport_get_measured_render_time_cpu`, 4 × 120 images, 3 passages) | **+ 0,11 / + 0,17 / + 0,20 ms** | **+ 0,11 / + 0,13 / + 0,38 ms** |

Le budget de 0,3 ms (test à la `test_bri1`) porte sur la mise à jour : 0,03 ms, tenu largement. Le rendu des pièces dessinées s'ajoute
(+ 0,1 à + 0,2 ms le plus souvent ; une mesure à + 0,38 ms en 1280 × 720 sur la machine saturée, le même passage à 1600 × 900 donnait
+ 0,17 ms) : à remesurer au calme (MB-J) ; parade si besoin : trames de points en texture au lieu de cercles.

Les pièces se redessinent 10 fois par seconde (pas à chaque image) ; le brouillard est une image de 100 × 60 refaite 3 fois par seconde
(`Image.copy_from` + `fill_rect` par ligne de cercle, aucune boucle par pixel) ; `hud_data()` 4 fois par seconde. Mesures sur une machine
chargée par d'autres agents.

## 4. Tests

`test_mb_hud` (≈ 60 contrôles, ≈ 35 s) : règles pures (sorte et rang des messages, raison de la fin, repères) ; partie réelle (toi + 7 IA,
horloge à 2:50) : HUD posé, plus de ligne de test, mini-carte ronde et objectifs de la Survie cachés, tableau (temps, tours), minuteurs,
3 alliés et leur intention, mini-carte (10 structures), brouillard (un adversaire à sa fontaine n'est pas vu, près de toi il l'est), niveau de
partie sur la barre, choix de niveau (bandeau, 3 cases éclairées, ultime verrouillé, Ctrl + 1 réel, plots), annonces (priorité, file), fil
(élimination, premier sang, tour), boutique ([P], parcours, conseillé, annuler, vente au maintien — pas avant 0,6 s —, 7 onglets sans « % »,
fiche, fermée loin de la base, [P] la referme), boutique à la manette (partie en pause, 12 / 12 contrôles atteignables, RB, reprise),
tableau des scores (Tab tenu / relâché), repère sur un adversaire vu (« Attaquez ! » et sa cible), mise en page 1280 × 720 et 1600 × 900
(pièces dans l'écran, tableau et minuteurs loin de la mini-carte, alliés et or loin de la barre, pile de gauche, tableau des scores, mort,
grande carte au-dessus de la barre), coût, mort (carte, qui t'a battu, barre cachée, réapparition), bilan (raison, tableau des 8, meilleur).
`test_nav_screens` : la page du mode est atteignable à la croix.

Suite demandée sur une copie de HEAD 0.1.323 + ce lot (`run_tests.py --snap … --reuse -j 2`) : voir § 6.

## 5. Captures regardées (`shot_mbh`, 1600 × 900 et 1280 × 720 ; `conception/benchmark/mb_h/`)

Corrigé après la 1re planche : plots d'enchaînements qui mordaient la touche sous la case (placés de part et d'autre), pictogrammes
invisibles (icônes génériques sans préfixe `ico_` ; composants sur fond gris : fond de la stat qu'ils donnent), « Retour dans 11 s » coupé,
l'or qui couvrait le numéro de version, grande carte sous le bandeau de choix et sur la barre d'action, « Premier sang ! » au-dessus du héros
qui venait de tomber, priorités (une annonce discrète coupait un moment fort après 0,8 s), onglets de la boutique vides (`tab_items` rend des
fiches, pas des ids).

## 6. Pour la suite
- MB-G : ordres aux alliés depuis `MobaPings` (bulle « D'accord ! » / « Pas maintenant » : `MobaHud.announce` ou le fil), intention écrite
  `MobaHero.ai.intent` (lue par les cadres des alliés), repères posés par les IA (`MobaPings.add`) ; buissons dans la vue de l'équipe
  (`MobaHud.viewers` / `is_seen` : 25 m, sans buissons).
- MB-I : activité (`Moba.READY`, image, `QuestPool.ACTS`, `ResourceHelp`, `Compass`), choix des postes et des héros (la page est minimale),
  récompenses et quêtes dans `MobaResults`, courbe d'écart d'or, moments.
- Plaques des héros (barre courte + niveau, nom au survol, allié arrondi / adversaire à coins coupés : P1-20) et réglage des couleurs de camp
  (bleu / orange) : pas dans ce lot. Touche [P] et Vue à la base codées en dur (pas d'action réassignable « boutique » dans `Settings`).
- MB-K : sons et moments manga des événements (tour qui tombe : secousse ; Cœur : ralenti), fiches et Guide.
