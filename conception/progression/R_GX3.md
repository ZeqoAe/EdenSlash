# R_GX3 — Fiche d'objet v2, sac, objectifs, « Le meilleur ▲N » (17/10/2026)

Lot GX-3 = reste du backlog P0 de `conception/benchmark/HEROS_EQUIPEMENT_PROGRESSION.md` hors GX-2 : P0-1 (infobulle v2), P0-2
(verrou, « neuf », démontage en masse), P0-6 (★ Objectif), P0-7 (« Nouveau plan »), P0-8 (« Le meilleur ▲N »), P0-9 (stats au
survol, PE vers la difficulté suivante), P0-10 (textes) ; plus deux points notés après H3 : la boussole pouvait conseiller de
fabriquer une pièce trop haute pour le niveau de héros, le Registre n'avait pas « Monte ton niveau de héros ». Recommandations
de l'étude validées par le joueur (Q4 : profil pour le mot, PE pour le chiffre ; Q5 : 1 objectif épinglé + 5 suivis ; Q7 : verrou
par objet). DA v2 par `UiTheme` (autocollants, tons bonbon, `ForgeWidgets.candy_button`).

## Fait
- **Objectifs** (`core/goals.gd`, nouveau `class_name Goals`) : `Profile.records.goals` = `{pinned, list}` (aucun champ de
  `Profile`) ; id = id d'Eden (« 1234 ») ou plan de donjon `plan_<boss>:<emplacement>`. `follow` (le dernier souhait est épinglé),
  `unfollow`, `toggle`, `pin_next`, `prune_done`, 6 au plus (refus avec message). `status(id)` : plan (✓ / à trouver et où :
  `Completion.plan_place` ou `Dungeons.plan_source`), insignes x / y (« il en manque N ≈ X cartes de Survie »), niveau de héros
  h / requis, fabriquée / portée, `ready`, une phrase `line` et `go` (où aller : Survie, Donjons, Atelier > Fabriquer ou Plans de
  donjon, Héros). `advice()` = premier conseil de la boussole (`Compass._r_goal`, en tête de `Compass.RULES`, famille « goal »).
  `found_in(ids)` : bilan.
- **Barre d'objectif** (`ui/goal_bar.gd`, `class_name GoalBar`) : rangée soleil ★, case de la pièce (carte au survol), nom, ce qui
  manque, étapes en pastilles pomme / papier (sauf compacte), « Y aller » / « Fabriquer » / « Porter », ⇄ (suivant), ✕ ;
  `open_target` ferme Héros ou l'Atelier si besoin puis `Lobby._compass_open`, et ouvre la page sur l'objectif (`show_goal` de
  Fabriquer et de Plans de donjon). Posée en tête du sac (Héros), de la colonne des paliers (Fabriquer) et de Plans de donjon.
- **★ sur les listes** : « ★ Objectif » / « ★ Objectif suivi » dans la fiche de Fabriquer (plan connu ou à trouver), bouton ★ sur
  chaque carte de Plans de donjon, ★ soleil sur les cases (`ItemSlot.goal`, `Silhouette.goal`), la poupée du palier montre le plan
  visé à la place d'un autre du même emplacement, filtre « ★ Objectifs » (ajouté en fin de `GearShopPage.STATUSES` : index gardés).
- **Fiche d'objet v2** (`Items.describe(item, detailed, worn)`, `ItemWidgets.card_text` / `ItemCard`) : dès qu'elle parle d'une
  pièce d'équipement, verdict « ▲ Meilleure / ≈ Équivalente / ▼ Moins bonne pour <classe> » + « PE +N » (`Items.verdict`,
  `verdict_line` ; l'écart au profil en % seulement derrière Maj) ; niveau trop haut : « Niveau N requis · tu es niveau H » en fraise
  à la place du verdict ; écarts ▲ / ▼ sur chaque ligne ; stat principale en grand puis 3 stats triées par le poids du profil (★ =
  poids ≥ 1,2), le reste sur une ligne grise « Aussi : … », « En moins : » ce que l'échange fait perdre ; type d'armure dans le
  sous-titre ; qualité derrière Maj ; panoplie « 1 / 6 → 2 avec celle-ci » ; provenance (« Plan ✓ · Époque I · Monts Calcaires »,
  « Plan à trouver : … », « Se fabrique : Atelier > Plans de donjon ») ; la pièce portée, réduite, posée à côté (bandeau « Portée »).
  Carte = autocollant d'encre (`UiTheme.sticker("nuit")`) avec un bandeau de la couleur de rareté.
- **Verdict corrigé** : le mot comparait la note seule (`Items.rating`, rapportée au niveau de la pièce), donc une pièce de niveau 1
  pouvait être « meilleure » qu'une de niveau 45. Il compare maintenant la valeur au profil × le niveau (`GearPower.item_power`,
  comme « Équiper le meilleur ») : `Items._gain`, `profile_gain` (▲ / ▼ des cases), `FabricationPage.verdict_text` (GX-2).
- **Sac** (`ui/inventory_page.gd`) : cadenas (clé `locked` de l'objet ; bouton « Garder » / « Gardée » lagon, touche L ; dessiné
  sur la case ; `Profile._convert` ne démonte ni ne vend jamais une pièce gardée, même en masse) ; « neuf » (clé `new` posée par
  `Profile.add_item` hors partie, les coffres du hub, la Tour, le Panthéon ; effacée quand on regarde ou porte la pièce ; pastille
  mandarine inclinée) ; pastilles Ma classe / Portables / Nouveautés · N / Gardées / Inutiles · N ; tri « Pour ma classe » ;
  **pièces inutiles** (`InventoryPage.useless_items`) : jamais gardée, portée, dans un préréglage, améliorée, sertie, enchantée,
  d'un objectif, mieux que la pièce portée, ni la meilleure de sa case (arme : de son type) pour l'un des 7 profils ou pour la PE ;
  « Démonter les N pièces inutiles » (fraise, confirmation `InfoCard.ask` avec ce que ça rend) puis « Annuler le démontage » le
  temps de la séance (`Profile.undo_disassemble`). Badge « P » = pièce d'un préréglage (le ★ est aux objectifs).
- **Héros > Équipement** : « Le meilleur ▲N » sort de « Gérer » (à côté de la PE) : aperçu actuel → recommandé et écart de PE
  (`PresetBar.best_plan`, `_open_best`), puis Appliquer (annulable dans Gérer comme avant) ; ▲ pomme sur les cases de la poupée quand
  le coffre a mieux ; survol d'une pièce du sac : l'intitulé des 5 stats devient l'écart (« ▲ +2 937 ») ; à côté de la PE :
  « Héroïque à 25 272 · −23 071 » (`InventoryPage.next_gate`, la plus facile des difficultés pas encore atteintes des donjons
  ouverts) ; fiche : écarts ▲ / ▼ sans parenthèses, verdict sans pourcentage.
- **1280 × 720** : le débord de la colonne du sac (onglets, tri, fiche, « Démonter » coupés, noté à H3) est corrigé : colonne de
  la poupée 470 px, tri sans « fit_to_longest_item », fiche sans la colonne « Pièce portée » (le verdict passe sous le niveau),
  boutons sans icône, 6 stats au plus dans la fiche à 720 px. Panneaux et boutons de l'écran en DA v2 (puits d'encre, onglet actif
  mandarine, Équiper soleil, Démonter fraise) ; `frame_box` / `card_box` (autres écrans) inchangés, `frame_v2` / `card_v2` nouveaux.
- **« Nouveau plan »** (`RunDirector.plan_badge`) sur les cartes des coffres d'emplacement de la Survie : « ✦ Nouveau plan »,
  « Plan connu », « ★ Ton objectif ! » ; la comparaison de la carte n'a plus de pourcentage (« ▲ Meilleure que ta pièce »).
  Bilan : « ★ Objectif : plan trouvé » en tête de Gardé, « Plans : A, B, C + N » (`ResultsScreen.kept_rows`).
- **Boussole** : `affordable_piece` ne propose plus une pièce au-dessus du niveau de héros (`HeroLevel.wear_level`) ; conseil
  « monte ton niveau de héros → Survie » (`level_up_hero`) quand l'équipement est déjà au niveau du héros. **Registre** :
  « Il manque : du niveau de héros (tu es niveau H) → Monte ton niveau de héros en Survie » (`ClassGear.hero_capped`).
- **Textes** : « Armurerie » → Atelier / Fabriquer dans la boussole (règles et `Compass.after` : « 3 plans découverts : Atelier >
  Fabriquer »), le Registre (« Survie, puis Atelier »), `ResourceHelp`, `Unlocks` (« Atelier : Fabriquer »), `DifficultyPanel`,
  le Panthéon ; « Pièces découvertes » → « Plans : … » au bilan.

## Tests et captures
Nouveau `test_gx3` (≈ 70 vérifications : objectifs et sauvegarde, verrou / neuf / masse / annulation, fiche v2, inutiles, textes,
boussole et Registre au niveau de héros, écran Équipement, Atelier, cartes de coffre, bilan). Mis à jour : `test_nav_screens`
(Fabriquer avec objectif, Héros avec objectif, « Inutiles », aperçu « Le meilleur »), `test_pages` (carte v2 ; en partie : ni
objectif, ni pastilles, ni cadenas), `test_texts_fr` (textes des objectifs, pastilles, verdicts), `test_gx2` (verdict entre deux
niveaux), `test_h3` (carte : niveau requis à la place du verdict ; « Le meilleur » jamais trop haut ; pas d'écart au survol),
`test_compass`, `test_workshop`, `test_e3` (mots). Captures `tests/shot_gx3.tscn` (`GX3_RES=1280x720`, lignes `[débord]`)
regardées à 1600 × 900 et 1280 × 720 : Héros sans débord ; seul `[débord]` restant : la page Carnet > Registre déborde de 8 px
(panneau de la page, même valeur aux deux tailles : géométrie du `PageScreen`, pas une ligne du lot).

## Reste / pièges
- Pastille « ★ ton objectif tombe ici » sur la carte d'activité du menu Jouer (étude P0-6) : pas faite (menu Jouer = lot HUB) ;
  `Goals.status(...).go` donne déjà l'activité.
- « Maintien 0,6 s » du bouton destructif : remplacé par la confirmation `InfoCard.ask` (même garde, souris et manette).
- La carte d'objet reste un puits d'encre (texte clair) : une version papier demanderait de refaire les couleurs BBCode de
  `Items.describe` (utilisées aussi dans les puits de l'Atelier et de la Forge).
- « Inutiles » est volontairement prudent : une pièce faible qui reste la meilleure de sa case pour un profil n'y est pas.
- `Items.describe(item, detailed)` sans troisième argument = comme avant (pas de verdict) : boutique, archive, Survivant.
