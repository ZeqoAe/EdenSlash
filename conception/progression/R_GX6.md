# R_GX6 — test_ideas réparé, arbre de talents conseillé, chargements, profils « opti » à 80 points (17/10/2026)

Lot GX-6, deux points : (1) `test_ideas` rouge depuis GX-2 ; (2) le reste signalé par GX-5 : pas d'arbre conseillé ni de
« chargements » de talents, et des profils « opti » qui mettaient tout l'arbre (164 à 240 points) alors qu'un héros en a 80.

## 1. test_ideas : le test était périmé
« forge : le parchemin est consommé » attendait 4 parchemins sur 5 après un clic sur le premier bouton qui commence par
« Fortifier ». Depuis GX-2, la zone épinglée de la Forge range d'abord **« Fortifier jusqu'à +N »** (essais enchaînés jusqu'au
prochain palier : +0 → +4 avec 4 parchemins, chacun réussi à bas niveau) puis « Fortifier · prix » (un essai). Le test cliquait
sur l'enchaînement : il restait 1 parchemin. Pas de bug de la Forge (un essai = un parchemin, vérifié). Le test vise maintenant
« Fortifier · » et vérifie aussi que « Fortifier jusqu'à +N » est proposé. Vert.

## 2. Arbre conseillé (`core/talent_build.gd`, `TalentBuild`)
- Un **ordre de 80 points** par classe (2 par niveau de maîtrise) ; avec N points, le conseil = les N premiers. Chaque préfixe se
  bâtit point par point (`Profile.talent_set_valid`) : vérifié pour les 60 classes à 14 tailles (`test_gx6`).
- Valeur d'un point : talent de stat = poids de la stat au profil de la classe (`ClassGear.profile().weights`, ★ `top_stats` × 1,1)
  × ce que 1 % rapporte vraiment (`EFF` : 1 % de dégâts > 1 % de force ; d'après `Player.recalc_stats`) ; classes en plates : survie
  × 1,25. Talent de sort = part du sort (dégâts / recharge parmi les 6 meilleurs, 60 % des dégâts ; soins ; forfait de soutien) ;
  une durée ne vaut plus rien quand l'effet est déjà permanent (durée ≥ recharge). Glouton, un talent fermé par un prérequis est
  pesé avec ses points de prérequis (paquet) : les sorts renforcés du bout de l'arbre sont atteints.
- Exemples (80 points) : Guerrier (Rempart) PV max 20 %, Défense 20 %, Dégâts 20 %, Parade 5 %, Critique 14 %, « Rugissement de fer »
  renforcé ; Magicien (Arcane) Attaque 20 %, Incantation 20 %, Critique 20 %, Dégâts 12 %, Recharge 10 % ; Clerc (Esprit) Incantation,
  Soins reçus, Sagesse 20 % ; Barde : durées de chants jusqu'à l'effet permanent (13,8 s), puis Attaque et Dégâts.
- `Profile` : `advised_talents`, `apply_talents` (refus si l'arbre ne se bâtit pas ; « Annuler » rend l'arbre d'avant tant que
  l'arbre est celui posé : `_talent_undo_after`, même règle pour « Tout reprendre »), **3 chargements nommés par classe** :
  nouvelle clé de sauvegarde `talent_loads` (`talents` inchangée, sauvegarde sûre `SafeFile` comme le reste du profil),
  `save_` / `load_` / `rename_` / `clear_talent_load`, `talent_load_block` (« demande 80 points, tu en as 24 »).
- Page Talents : rangée au-dessus de l'arbre : **« Conseillé »** (aperçu avant → après par stat, « Garder mon arbre » / « Placer
  ces points », puis « Annuler » ; « Conseillé ✓ » grisé quand l'arbre le suit), la phrase « Pensé pour Rempart : PV max, Dégâts,
  Défense », et **3 chargements** (« 1 · Donjons ») ; un clic ouvre la fiche (`TalentsPage.LoadDialog` : nom, « Enregistrer ici » /
  « Remplacer par l'arbre actuel », « Charger » avec le même aperçu, « Renommer », « Effacer », « Fermer » ; B / Échap ferme).
  Aucun mot anglais (« arbre conseillé », pas « build »).
- Modes scellés intacts : `Run.passive_stats` / `skill_talent` non touchés (vérifié : talents posés, Survivant → ni stat ni sort).

## 3. Profils « opti » du duel : corrigés après mesure
`RivalBuilds.extra_stats` donne à l'adversaire « opti » ses talents de stat : avec l'arbre entier il avait jusqu'à +20 % de Force et
+20 % d'Attaque de plus que le meilleur héros possible (Guerrier), +30 % de dégâts critiques (Voleur), +40 % (Chasseur, Clerc,
Magicien). `gen_profiles` prend maintenant `TalentBuild.ranks(classe, 80)` ; `-- --talents-only` ne réécrit que les talents des
profils « opti » (pièces gardées). Le fichier poussé a été réécrit par Python depuis HEAD (seule la clé `talents` des 480 profils
« opti » change ; Godot aurait changé les entiers en flottants). Essai `gen_profiles -- warrior` (sans écrire) : 8 profils, sorties
normales.

Mesure : arène d'IA en duel équipé (`ml_arena -- --scenario=duel`, cerveau hardcore, 8 combats par paire, `--fixed-fps 60`),
avant (A, HEAD) / après (B, talents à 80 points) :

| Paire | A : durée moyenne, victoires | B : durée moyenne, victoires |
|---|---|---|
| Guerrier – Magicien, niv. 90 | 51,4 s (45,7-56,0), 0 / 8 | 47,3 s (39,5-53,9), 0 / 8 |
| Voleur – Clerc, niv. 90 | 38,6 s (28,7-50,9), 0 / 8 | 45,9 s (33,5-58,8), 0 / 8 |
| Chevalier – Chasseur, niv. 90 | 48,0 s (38,4-61,2), 1 / 8 | 51,5 s (41,8-61,5), 1 / 8 |
| Guerrier – Magicien, niv. 25 | 74,7 s (59,9-86,8), 7 / 8 | 68,5 s (54,8-83,8), 7 / 8 |

Mêmes vainqueurs ; écarts de −6 à +7 s, dans la dispersion d'une paire (±8 s) ; toutes les manches dans la cible 30 s-1 min 30.
`test_pvp` (même part des PV par coup aux niveaux 25 et 90, plafonds) et `test_duel_modes` verts avec les nouveaux profils.

## Tests et captures
Nouveau `test_gx6` (60 classes, préfixes, cohérence par rôle et ★, aperçu, appliquer / annuler, chargements et sauvegarde relue,
clé abîmée, mode scellé, page : Conseillé, aperçu, Annuler, fiche des chargements, B ; profils opti ≤ 80). Mis à jour : `test_ideas`,
`test_nav_screens` (fiche d'un chargement : 3 / 3 contrôles). Verts sur une copie de HEAD + ce lot (`-j 2`) : test_gx6, test_ideas,
test_gx5, test_h2, test_pvp, test_duel_modes, test_build, test_nav_screens, test_pages, test_texts_fr, test_p4_migration.
Captures `tests/shot_gx6.tscn` (`GX6_RES`), regardées à 1600 × 900 et 1280 × 720 : page, aperçu, arbre posé, fiches vide et remplie,
aperçu d'un chargement ; aucun `[débord]` (à 720 px, la dernière rangée de l'arbre tient juste). Retouches après captures : le
bouton de refus de l'aperçu disait « Annuler », comme le bouton qui rend l'arbre d'avant → « Garder mon arbre » ; « build » → « arbre ».

## Reste / pièges
- `RivalBuilds.apply_to_hero` (éditeur de profils, mode dev) pose les talents du profil tels quels ; avec les nouveaux profils
  c'est 80 points, mais un compte avec moins de maîtrise reçoit plus de points qu'il n'en a (comme avant).
- L'ordre conseillé ne tient pas compte des sorts encore fermés par la maîtrise (les premiers points vont aux stats, donc peu d'effet).
- Le duel scripté (`Duel.rival_sheet`, profils « opti ») n'a pas été remesuré en partie réelle (`world.tscn -- --duel`) ; seule l'arène
  d'IA l'a été.
