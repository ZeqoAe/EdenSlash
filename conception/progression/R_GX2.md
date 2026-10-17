# R_GX2 — Atelier : Forge sans punition, Plans de donjon, Fabriquer v2 (17/10/2026)

Lot GX-2 = backlog P0 n° 3, 4, 5 de `conception/benchmark/HEROS_EQUIPEMENT_PROGRESSION.md` (recommandations validées par le
joueur : Q1 plus de rétrogradation, Q3 réajuster au choix, Q4 « profil pour le mot, PE pour le chiffre »). DA v2 : les boutons
passent par le thème v2 poussé entre-temps (`UiTheme.style_button`, tons soleil / lagon / mandarine / pomme / nuit, via
`ForgeWidgets.candy_button`) ; les couleurs de dessin (piste, jauges) sont les jetons v2 recopiés dans `ui/forge_widgets.gd`.
Les trois sous-lots partagent `merchant_pages.gd` et `forge_widgets.gd` : poussés en un seul envoi.

## Fait
- **Forge sans punition** (`core/craft.gd`) : `DOWNGRADE_FROM` supprimé, un échec ne coûte que l'essai. Persévérance par pièce :
  `item.pity` (+ (1 − chance) × 0,5 par échec, au moins 0,25 : sans ce plancher un cran à 60 % pouvait demander 12 essais au pire) et `item.pity_n` (+10 % de la chance de base par échec, plafond × 1,5) ; jauge pleine =
  réussite assurée ; tout est effacé à la réussite (`_upgrade_success`, l'enclume comprise). Au pire 5 essais pour un cran à 40 %,
  4 pour +10. `Craft.base_chance`, `pity`, `pity_fails`, `pity_gain`, `tries_max`, `plan_upgrade(item, cible)` (attendu / au pire,
  essais, parchemins ; or en partie, cristaux hors partie). Pierres = **pierres de chance** (« Pierre de chance », « Pierre de grande
  chance », mêmes icônes) ; parchemin béni = essai gratuit. Vieilles pièces : sans clé, jauge vide.
- **Forge, écran** (`ui/merchant_pages.gd` `_upgrade`, `ui/forge_bench.gd`) : piste des 10 crans (paliers ★ +4/+6/+8/+10, prochain cran
  lagon, cible améthyste) ; jauge de chance ; jauge de **persévérance** (améthyste, trace claire = ce que le prochain échec ajoute,
  « assurée dans N essais au plus ») ; « Échec : la pièce reste à +5, la persévérance monte. Rien d'autre n'est perdu. » ; **Viser +N**
  (‹ › , défaut : prochain palier au moins 2 crans plus haut) avec « attendu ≈ · au pire · tu en as » et **« Fortifier jusqu'à +N »**
  (essais enchaînés sans pierre, arrêt à chaque palier pour montrer la stat bonus, arrêt si parchemin ou prix manque). Dans l'Atelier,
  chance, persévérance, conséquence et « Viser » sont **épinglés** au-dessus de « Fortifier » (toujours visibles à 1280×720 ; à 720 px,
  2 stats dans le tableau au lieu de 4). Verdict : pomme « RÉUSSI », **lagon « RATÉ »** quand l'échec remplit la jauge, fraise pour un
  refus. Le marchand de partie a les mêmes règles et la même rangée (dans sa colonne).
- **Réajuster au choix** (`core/forge.gd`) : `reforge` pose le nouveau jet à côté de l'ancien (`item.reroll`), `reforge_choose(item,
  nouveau?)` ; tant qu'on n'a pas choisi, la pièce garde l'ancien et un second tirage est refusé (rien payé) ; jet périmé oublié.
  Écran : tableau ancien → nouveau, « Garder l'ancien · X » / « Prendre le nouveau · Y » (le meilleur en pomme). Corrigé au passage :
  l'établi montrait la stat de base de la pièce au lieu de la valeur de la stat bonus.
- **Plans de donjon** (`ui/fabrication_page.gd`) : emplacements en onglets ; **aperçu** de la pièce (case, rareté · emplacement ·
  niveau, verdict « ▲ Meilleure pour Guerrier · PE +621 » (mot au profil de la classe, chiffre en PE, sans %), 3 stats ; Maj sur la
  case : carte complète). `FabricationPage.preview` garde le tirage : **la pièce montrée est celle fabriquée** (même modèle, même
  qualité ; nouveau tirage après fabrication). **« Fabriquer et porter »** (`craft_and_wear`, `ForgeWidgets.wear_new`), grisé avec la
  raison si le niveau de héros est trop bas ; « Il te manque N insignes ≈ X cartes de Survie ». Ligne « Pièce mythique, niveau 14 »
  (niveau du donjon, différent du niveau requis affiché) remplacée par « Plan mythique · légendaire après une victoire en Mythique ».
- **Fabriquer v2** (`ui/gear_shop_page.gd`) : vue **par paliers** par défaut : colonne des 12 cartes (« II-2 Volcan d'Avila », jauge
  x / 9, « ta bande » en lagon, époques fermées voilées) ; au centre la **poupée du kit** de la classe (9 cases 104 px, 92 à 720 px :
  pleine = fabriquée ✓, voilée = plan connu + prix, « ? » = plan à trouver + carte ; pour chaque emplacement la meilleure pièce du
  palier au profil de la classe, `GearShopPage.kit`) ; **« Fabriquer les N plans connus · total »** avec carte de confirmation du coût
  (`InfoCard.ask`, « il t'en restera … ») et « il en manque N ≈ X cartes de Survie » quand ça ne suffit pas ; fiche à droite avec
  « Fabriquer et porter » (ou « Porter » une pièce fabriquée non portée), verdict sans %, fiche sans « prochaine amélioration ». Palier
  ouvert d'office : « ta bande » s'il y a à fabriquer, sinon le plus haut palier qui a un plan connu. L'ancien catalogue filtrable
  reste derrière « Catalogue complet » (la colonne des paliers se cache alors : même mise en page qu'avant).
- `Economy.insignia_per_map(ep)` (tiers d'une victoire type de l'époque ouverte), `maps_for`, `missing_text`.

## Économie : mesures avant / après
Coût d'une pièce **niveau 85, +0 → +10** (arme, `Craft.plan_upgrade`, sans pierre) :

| | si tout réussit | attendu | au pire |
|---|---|---|---|
| avant (125 or / cristal, pierres de protection dès +6) | 755 | ≈ 1 615 | — (rétrogradation) |
| après, 125 or / cristal | 755 | ≈ 1 390 (−14 %) | ≈ 3 310 |
| **après, 108 or / cristal (retenu)** | 872 | **≈ 1 610** | ≈ 3 830 |

Décision : `Forge.GOLD_PER_CRYSTAL` 125 → **108** pour que le coût **attendu** d'un +10 reste celui d'avant (l'étude proposait de
relever le coût plutôt que de remettre du risque). Tests de `test_loot` toujours dans leurs bornes (+10 niveau 85 « si tout réussit »
600-900 : 872 ; 4,1 clears Mythiques ; un donjon Normal paie un +3 niveau 30).

`progression_sim --heros --refonte --plans=boss --hubvalue`, 12 comptes « moyen », guerrier, 50 h, copie propre de HEAD 0.1.256 (+ les
jalons `kit80_p8` / `kit80_p10` ajoutés aux deux côtés ; le joueur du modèle n'attend plus de pierre de protection après) :

| Jalon (médiane, h) | avant, graine 1 | avant, graine 2 | après 125, graine 1 | **après 108, graine 1** | **après 108, graine 2** |
|---|---|---|---|---|---|
| époque IV | 43,9 | 43,8 | 45,9 | 44,0 | 44,5 |
| **équipement 80-90 correct** (`kit80_ok`, +5) | 45,9 (83 %) | 45,5 (83 %) | 41,1 (75 %) | **45,6 (92 %)** | **46,2 (67 %)** |
| kit 80 à +8 / +10 (`kit80_p8` / `p10`) | 45,9 / 45,9 | 45,8 / 45,8 | 41,1 / 41,1 | 46,4 / 45,5 | 46,2 / 46,3 |
| kit90_ok, kit90_opti | non atteints | non atteints | non atteints | non atteints | non atteints |

Lecture : dans le modèle, la Forge n'est jamais le goulot (le kit 80 passe à +10 dès qu'il est réuni : cristaux et parchemins en
réserve) ; le jalon suit l'obtention des pièces légendaires ≥ 78. Avant / après 108 : **écart dans le bruit des graines (± 1 h)** ;
l'économie de la refonte n'est pas déplacée par ce lot. NB : sur HEAD 0.1.256, `kit80_ok` est à ≈ 46 h et non aux ≈ 30 h visés : c'est
l'état du calage de l'Aventure (lot H4b en cours, `HERO_GAME_MULT`), pas un effet de la Forge.

## Tests
Nouveau `test_gx2` (règles de persévérance, 300 pièces +9 → +10 sans perte et en 4 essais au plus, plafond de chance, pierres,
`plan_upgrade` attendu / au pire / persévérance / or en partie, réajuster au choix et jet périmé, écran de la Forge : piste, textes,
viser ›, enchaîner jusqu'au palier +6, deux boutons de choix ; sauvegarde relue avec jauge et jet en attente ; Plans de donjon : aperçu
= pièce fabriquée, onglets, « Fabriquer et porter », niveau trop bas ; Fabriquer v2 : 12 paliers, poupée de 9, palier entier,
« il en manque ≈ cartes », conversion, « Fabriquer et porter », catalogue). Mis à jour : `test_progress` (plus de rétrogradation),
`test_workshop` (catalogue explicite, bouton « Fortifier · »), `test_loot` (taux lu dans `Forge`). Captures : `tests/shot_gx2.tscn`
(`GX2_RES=1280x720`, lignes `[débord]`), regardées à 1600×900 et 1280×720 avec le thème v2 : aucun débord (à 720 px : cases de la
poupée à 84 px, lignes de palier à 44 px, chance / persévérance / « Viser » épinglés). Corrigé après captures : un cran à 60 % pouvait
annoncer « au pire 12 essais » → plancher de remplissage 0,25 (`Craft.PITY_MIN`) ; les ▲ / ▼ génériques des cases contredisaient le
verdict au profil de la classe → retirés de l'aperçu et de la poupée. Verts sur copie propre de HEAD 0.1.260 + ce lot : `test_gx2`,
`test_workshop`, `test_a1`, `test_loot`, `test_progress`, `test_build`, `test_farm`, `test_e2`, `test_e3`, `test_e5`, `test_e6`,
`test_h3`, `test_pages`, `test_nav_screens`, `test_texts_fr`, `test_p4_flow`, `test_compass`, `test_tooltips`, `test_uik0`
(`test_e1` / `test_a3` n'existent pas : E1 est couvert par `test_loot`, A3 par `test_workshop`).

## Reste / pièges
- Pastilles « Ma classe / Abordables / Portables / Objectifs » de la maquette `v2_atelier` et « ★ Objectif » : lot P0-6 (non fait ici).
- « Maintenir A pour enchaîner » remplacé par le bouton « Fortifier jusqu'à +N » (même effet à la souris et à la manette).
- La poupée choisit la meilleure pièce **au profil de la classe** parmi celles du palier ; les autres variantes du palier restent au
  catalogue (une « flèche par case » pour les parcourir serait un P1).
- Le mot « Survie » est gardé (« cartes de Survie ») : le renommage en « Aventure » est le lot A9.
- `tools/progression_sim.gd` est aussi modifié par H4b (non poussé) : le commit est construit depuis HEAD par remplacements de texte.
