# R_TAC_8 : chute, spectateur, ordres, bilan, activité et récompenses de L'Assaut (lot TAC-8, 18/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.8 (mort, fin), § 7.11 (activité, récompenses, mode scellé), § 5 (récapitulatif,
spectateur, ordres) ; croquis `tactique_maquettes/v2_mort_ordres.svg` et `v2_bilan.svg`. Socle : `R_TAC_7.md` (HUD du mode).
Recommandations par défaut validées. L'activité reste **cachée** du menu Jouer tant que le mode n'est pas jouable de bout en bout
(`Assault.READY` faux ; le mode dev la montre, comme le Colisée).

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Chute et spectateur | `game/scripts/ui/assault_recap.gd` (`AssaultRecap`) | à la chute du joueur : carte « Éliminé ! » (6 s, ou [Interagir] / A) — le tueur (icône de classe, nom, rôle), le coup (« Lame d'ombre, dans le dos »), ses PV restants, ou « Emporté par l'explosion de la Charge » ; tes dégâts donnés, éliminations / aides. Puis le spectateur : la caméra suit un allié debout, [◀] / [▶] (LB / RB) en change ; voile, sons et mini-carte suivent le héros regardé ; la barre d'action se cache |
| Ordres aux alliés | `AssaultRecap` (carte « Ordres à l'équipe », [Tab] / D-pad gauche) et `AssaultDirector.give_order` / `orders` / `order_goal` / `_apply_orders` | « Va en A », « Va en B », « Va au repère » (grisé sans repère), « Tiens ta place », « Regroupez-vous », « Recule », à toute l'équipe ou à l'allié regardé ; réponses dans la colonne de droite (« Druide : « J'y vais : B ! » », « Pas pour l'instant : je me bats ! ») ; l'ordre tient jusqu'à la fin de la manche : après son agent, l'allié reçoit le point comme ancre (`AssaultRival.anchor`, « move » puis « hold », laisse de 10 m) ; jamais celui qui pose ou désamorce, ni celui que son stratège envoie poser ou désamorcer |
| Fin de manche | `AssaultHud.show_round_card`, `AssaultDirector.round_cards` | carte non bloquante de 5 s sous le bandeau : « Manche gagnée ! » (soleil) / « Manche perdue… » (papier), comment et qui (« Charge désamorcée · Druide, à 0,4 s de l'explosion », « posée par Toi »), score, or gagné dans la manche et total, « seul contre trois ! », « mi-temps : on change de côté » |
| Bilan | `game/scripts/ui/assault_results.gd` (`AssaultResults`, sur `ResultsPanel`) | « Victoire ! », « 7 contre 4 · Le Bourg aux lanternes · Classique · Normal » ; 5 tuiles (tes K.O., dégâts, poses, désamorçages, or gagné) ; **frise des manches** (couleur de l'équipe gagnante, symbole dessiné : croix, éclat, pinces, sablier ; point soleil = manche de ton équipe ; trait de la mi-temps) ; **tableau des 8** (ton équipe / adversaires : K.O., morts, aides, dégâts, « Charges » = poses / désamorçages ; toi en soleil ; étoile du **Meilleur héros**, nommé sous la frise) ; « Gagné » ; « Ta quête » ; Rejouer (même carte, format et difficultés) et Menu principal |
| Récompenses scellées | `game/scripts/core/assault_rewards.gd` (`AssaultRewards`) | victoire : coffre d'apparence selon la difficulté adverse (Facile commun, Normal rare, Difficile mythique, Expert légendaire ; Éclair un cran plus bas) ; la 1re victoire à chaque difficulté le donne toujours, ensuite 2 coffres de victoire par jour ; titres de victoire (Sapeur, Artificier, Maître de l'Assaut) et d'exploit (« Démineur » 10 désamorçages, « Dernier rempart » une manche gagnée seul contre trois, « Sans une perte » 7 à 0) ; abandon et partie regardée : rien ; `Quests.end_run("assault")` ; écrit après `Assault.finish` (sauvegarde rechargée, piège 11 de R_MODE0) |
| Activité et page | `ui/activities.gd`, `ui/assault_page.gd` (`AssaultPage`), `ui/lobby.gd` (une ligne), `core/assault.gd` (`READY`, `visible()`) | plus « Bientôt » : cachée hors mode dev ; page : le mode en trois lignes, format Classique / Éclair, adversaires et alliés (Facile, Normal, Difficile, Expert), carte (le Bourg ; le Pont et le Temple grisés « Bientôt »), ta classe et son rôle, ce que donne la victoire du jour et les titres, « Lancer l'Assaut » épinglé |
| Quêtes | `core/quest_pool.gd`, `core/quests.gd` | 3 quêtes (manches gagnées, poses et désamorçages, une partie gagnée), porte « assault » (tirées seulement si l'activité est montrée) ; récompense : apparences seulement (comme le Survivant et l'Échiquier) |
| Aide aux ressources | `core/resource_help.gd` (`get_text`), `core/compass.gd` | « Apparences » et « Titres » citent L'Assaut quand il est montré ; ligne « Ta quête » du bilan comme l'Échiquier |
| Tests | `game/tests/test_tac8.tscn` ; `test_p4_activities` (« assault+r ») ; `test_nav_screens` (page du lobby) | voir § 4 |

## 2. Décisions (recommandations par défaut de l'étude)

- Coffres de victoire seulement (ni place, ni défaite), plafonnés par jour : rien ne se farme ; titres d'exploit une fois.
- Les ordres du joueur passent avant le plan du stratège pour l'allié visé, mais pas avant la pose ni le désamorçage.
- « Prendre le relais » d'un allié (Facile / Normal) et la carte tactique plein écran : lot TAC-11 (P1), pas ici.
- La page n'ouvre que le Bourg (les deux autres cartes : lot TAC-10).

## 3. Captures regardées

`conception/benchmark/tac7/3_mort_*`, `4_ordres_*`, `4b_ordres_reponses_*`, `5_fin_manche_*`, `6_bilan_*`, `7_page_*`,
`7b_page_bas_*` (1280 × 720 et 1600 × 900). Corrigé en regardant : noms coupés dans le tableau des 8 (le rôle tombe s'il ne tient
pas, colonnes resserrées, colonne « Charges ») ; pastille « Meilleur héros » qui mangeait un nom (étoile devant le nom, le nom sous la frise) ; bilan à
1280 × 720 au bord de l'écran (la ligne « Meilleur héros » rejoint la légende de la frise) ; carte de fin de manche sous le
récapitulatif de chute (pile commune).

## 4. Preuves

`test_tac8` (vert, 44 contrôles) : récompenses (coffre par difficulté, première victoire, coffre du jour, plafond, Expert au-delà
du plafond, exploits, 7 à 0, abandon, partie regardée), quêtes (poses + désamorçages), Meilleur héros, lignes du récapitulatif,
activité cachée hors mode dev et montrée en mode dev, quêtes jamais tirées tant qu'elle est cachée, aide aux ressources, quête =
apparences seulement ; partie réelle : chute -> récapitulatif (tueur), barre d'action cachée, spectateur d'un allié, changement
d'allié (caméra et vue), bandeau du spectateur, 6 ordres, « Va en B » -> 3 réponses et l'allié a B pour ancre, « Va au repère »
grisé sans repère, carte de fin de manche, bilan (frise, tableau des 8, Meilleur héros, Rejouer / Menu principal, coffre de la
victoire) **tenu dans 1280 × 720**, TeamMatch fermé, records écrits ; page du lobby (formats, difficultés, carte, Lancer, Éclair
dans les options, cartes à venir grisées).

## 5. Pièges

1. Le bilan est un `ResultsPanel` : il met le jeu en pause et cache le HUD ; « Rejouer » relance `Assault.launch` avec la carte,
   le format et les difficultés de la partie (`AssaultDirector._replay_same`).
2. `AssaultRewards.finish` après `Assault.finish` (jamais avant) ; une partie `--assault-watch` ne donne rien.
3. Les ordres vivent dans `AssaultDirector.orders` et sont reposés chaque image après les agents (`_apply_orders`) : le stratège
   d'équipe (TAC-6) peut les lire là pour les intégrer à son plan (TAC-11).
4. Changements de scène par `LoadScreen.go` / `LoadScreen.to_lobby` (lot PERF-1) : page du mode, Rejouer, Menu principal.
5. Un fichier partagé (lobby.gd) committé en entier par une autre session a déjà emporté une ligne de ce lot (0.1.316, retirée en
   0.1.318) : commits par chemins explicites et index construit depuis HEAD.

## 6. Non-régression

Copie propre de HEAD 0.1.318 + TAC-7 + TAC-8 (`run_tests.py --reuse -j 2`, machine chargée : 55 Godot d'autres agents) :
**verts** test_tac0 à test_tac5, test_tac7, test_tac8, test_mode0, test_nav_screens (page du lobby comprise), test_pages,
test_texts_fr, test_hud, test_hud2, test_quests, test_compass, test_p4_activities (19 activités + « assault+r » : page, partie,
abandon, bilan, Rejouer, retour au lobby ; 672 s). Corrigés pendant la passe : test_tac0 lisait encore « Bientôt » (l'activité
est maintenant cachée par `Assault.visible()`) ; test_hud était rouge sur HEAD (effets « imm_cc », « blind », « bitter » des lots
TAC-4 / TAC-5 sans icône : pictogrammes maison dans `StatusDb.ASSAULT_ICO`). test_tac5 a échoué une fois sur trois (« la bombe
touche après son annonce », héros adverse qui s'écarte sur une machine saturée ; vert les deux fois suivantes) : instable, sans lien
avec ce lot (aucune règle ni objet touché).
Puis sur HEAD 0.1.321 (TAC-7 poussé, PERF-1 et MB-F arrivés) + TAC-8 : test_tac0, test_tac7, test_tac8, test_nav_screens,
test_pages, test_texts_fr, test_quests, test_p4_activities **verts** ; test_perf1 : contrôle de structure vert (aucun changement de
scène hors `LoadScreen` dans L'Assaut), mais une image de 467 ms au fondu de carte de la Survie (machine saturée, sans lien).
`check_scripts.py` vert sur l'arbre de chaque commit (TAC-7 seul, puis TAC-7 + TAC-8).
