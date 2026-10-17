# R_CO_A : Le Colisée, lot CO-A — socle du mode (17/10/2026)

Étude et spécification : `ARENA.md` (§ 5, § 6.2, § 6.3, § 6.15) ; socle commun : `R_MODE0.md`. Lot = backlog n° 1.

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Machine de partie | `game/scripts/core/colisee.gd` (`Colisee`) | formats (Classique 6 × 3, Éclair 4 × 3, Grand tournoi 8 × 3 verrouillé), PV d'équipe 100, barème, appariement tournant, exempt, égalités, éliminations simultanées, places, trios, difficultés, simulation « au tableau », résolution d'un combat caché au tableau (`resolve_board`), profil de règles, lancement (`begin`) et fin (`finish`) |
| Textes de pause | `game/scripts/ui/pause_menu.gd` | « Quitter le Colisée ? » (tout mode d'équipes : son titre) ; bourse cachée (`Modes.hero_match()`) |
| HUD | `game/scripts/ui/hud.gd` | ligne d'or et compteur de dégâts cachés en mode d'équipes (`Modes.hero_match()`) |
| Page Run (pause) | `game/scripts/ui/run_page.gd` | pas de bouton « S'extraire » en mode d'équipes (il ne faisait rien) |
| Test | `game/tests/test_co_a.tscn` | § 4 |

La machine est **sans scène** (patron de la machine `Autochess`) : une instance par partie (`Colisee.new(format, graine)`, ou
`Colisee.begin(...)` pour la partie du jeu, gardée dans `Colisee.game`). Elle ne pose aucun drapeau : le mode actif est `TeamMatch`
(« colisee »), lu par `Modes`. Le directeur du combat (lot CO-C) lui rend chaque manche par `report(résultats)` et répercute les
éliminations sur `TeamMatch.eliminate` **dans l'ordre rendu** (les places concordent : celles de `TeamMatch` = équipes encore en lice).

### Règles codées (valeurs de départ de l'étude, § 6.3 ; à mesurer au lot CO-I)
- **Barème** Classique 20 (manches 1-3), 25 (4-6), 35 (7-9), 50 (10-11), 100 (12 et suivantes) ; Éclair 25 / 35 / 50 / 100 (7+).
- **Appariement** : pas deux fois la même équipe avant d'avoir vu toutes les autres **encore en lice** ; recherche exhaustive des
  appariements (15 à 6 équipes, 105 à 8) avec **2 manches d'avance** (sans elle, 6 équipes après 3 manches peuvent former deux
  triangles sans appariement possible) ; à égalité, pas la revanche de la manche d'avant.
- **Exempt** (nombre impair) : l'une des équipes les moins exemptées, jamais deux fois de suite si possible (P0 : exempt simple, sans
  perte ; les Spectres sont au lot CO-J).
- **Égalité au temps** (85 s) : la plus grande part de PV restants gagne ; égalité exacte : les deux perdent la moitié du barème.
- **Éliminations simultanées** : la plus basse en PV d'abord, puis la moins de manches gagnées, puis la moins de K.O. ; places
  uniques ; la dernière debout est 1re (deux finalistes à terre ensemble : la mieux placée en PV).
- **Trios** : 3 familles différentes, aucune classe deux fois dans la partie (18 classes en Classique, 24 en Grand tournoi), tirés par
  la graine ; l'équipe 0 commence par la classe du joueur. **Difficultés** : Facile, Normal, Difficile, Hardcore, Mélange (une par
  équipe adverse, alliés en Normal).
- **Profil `ModeRules` « colisee »** (enregistré au lancement par `Colisee.register_rules`, jamais au démarrage : `test_mode0` vérifie
  qu'un profil non enregistré lit les chiffres du duel) : échelle 0,030 (celle du duel à l'arme, à mesurer), soins × 0,5, coup
  plafonné à 15 %, 35 % sur 2 s, **pas d'acharnement ni de mort subite** (l'anneau de feu les remplace), bonus en % aux trois quarts.
- **Lancement** (`Colisee.begin`) : `Run.start` (copie du profil, aucune écriture), sorts du préréglage, **équipement, sac, or et clés
  mis de côté** (comme le Battle royale ; le profil est rechargé à la fin, `Profile.reload_keep_records`), `TeamMatch.begin("colisee",
  n, {format, difficulty, director})`. Ni `Duel.active` ni `Royale.active` (vérifié).

## 2. Mesures de la simulation « au tableau » (modèle de l'étude § 5.1, combats « cible v2 »)

Force d'équipe ~ N(0 ; 0,8), victoire logistique, combat ~ N(60 s ; 12 s) borné [30 ; 85], préparation 30 s (Éclair 25), compte à
rebours 3 s, bandeau 2,5 s, transitions 8 s ; une manche dure autant que son plus long combat. `test_co_a`, graines 1000 et suivantes.

| Format | Parties | Manches méd. / p90 / max | Partie méd. (p10-p90) | Revoir une équipe trop tôt | Durée du calcul |
|---|---|---|---|---|---|
| Classique 6 × 3 | 1 000 | 10 / 11 / **12** | **18,9 min** (17,2-20,8) | 113 combats (0,11 par partie), **tous inévitables** | 3,2-4,7 s |
| Éclair 4 × 3 | 1 000 | 7 / 7 / 8 | 11,8 min (10,3-12,8) | 0 | 0,8 s |
| Grand tournoi 8 × 3 | 300 | 11 / 12 / 13 | 20,7 min (19,0-22,6) | 47 (0,16 par partie), tous inévitables | 4,9-8,6 s |

- Concorde avec l'étude (18,6 min médiane en Classique, 20,2 en 8 × 3) ; la fin est **garantie à la manche 12** en Classique (mort
  subite) : aucune des 1 000 parties ne la dépasse. Éclair : un peu sous la cible 12-16 min (combats v2 de 60 s ; à remesurer au lot
  CO-I avec les vrais combats).
- **Revoir trop tôt** : après des éliminations, la règle peut devenir impossible (ex. 4 équipes dont 3 n'ont pas encore vu la même) ; le
  test refait une recherche exhaustive **indépendante** à chaque manche (même règle d'exempt) : la machine fait toujours le minimum
  possible (écart au minimum : 0 sur 2 300 parties). Sans éliminations (tours complets à 6 et 8 équipes) : 0, chaque équipe voit les
  autres une fois par tour.

## 3. Audit des drapeaux `Duel.active` / `Royale.active` (HEAD 0.1.290 : 103 lectures dans `game/scripts`)

Situation en Colisée : `TeamMatch.active` vrai, `Duel.active` et `Royale.active` faux, `Run.active` vrai, `Run.survival` faux.
Légende : **sûr** = la valeur lue est la bonne pour le Colisée ; **corrigé** = changé par ce lot ; **MODE-0** = déjà migré ; **lot X** =
sans effet sur le jeu aujourd'hui, à reprendre par l'interface du mode.

| Fichier : lignes | Lecture | Colisée |
|---|---|---|
| `core/modes.gd`, `mode_rules.gd`, `team_match.gd` | définitions, commentaires | MODE-0 |
| `core/run_director.gd` 135, 141-147, 787, 1217 | montage par mode, état « team », pas de musique ni de Survie | MODE-0 |
| `core/run_director.gd` 1086 (`start_extraction`) | `Modes.hero_match()` | MODE-0 (sûr) |
| `core/run_director.gd` 1522, 1616 | `Run.survival` faux | sûr |
| `core/world.gd` 220-226, 252, 279, 492, 541-546, 817, 829 | abandon, niveau de zone, carte de départ, cartes de niveau, mort, ambiance | MODE-0 |
| `core/profile.gd` 349, `core/potions.gd` 49, `core/run_journal.gd` 85-143, `core/quests.gd` 374 | sauvegarde, potions, journal, activité | MODE-0 |
| `player/player.gd` 1655 (`hit_stop`) | coupé en mode d'équipes | MODE-0 |
| `player/player.gd` 237 (`_bare`, duel à l'arme) | faux : mais l'équipement est vidé au lancement, donc même fiche (arme de la classe, sans pièce, sans arme secondaire) | sûr |
| `player/player.gd` 462 (`gain_xp`), 469 (plafond du BR), 2578 (pilote du BR) | `Run.survival` faux, BR seulement | sûr |
| `player/player.gd` 859 (`_auto_combo`), 1248 (aide au coup parfait) | aides permises comme au Battle royale (jeu solo contre des IA) | sûr (choix) |
| `ai/class_rival.gd` 753 | « coup qui t'a battu » du BR | lot CO-G (bilan) |
| `combat/pvp_caps.gd` 78 | durée des combats du BR | sûr |
| `core/epochs.gd` 131 (`adventure`) | `Run.survival` faux | sûr |
| `core/items.gd` 596, 890, `ui/item_widgets.gd` 159 | arme d'une autre classe permise au Survivant et au BR | lot CO-F (enclumes) |
| `core/run.gd` 775, 803, 928, `core/royale_loot.gd` 223, `ui/survivor_cards_view.gd` 26 | cartes et butin du BR | sûr (aucune carte en Colisée) |
| `ui/hud.gd` 464 (ligne d'or), 1128 (compteur de dégâts) | montrés à tort | **corrigé** (`Modes.hero_match()`) |
| `ui/hud.gd` 145-160 (titre de zone), 235 (fil), 298-302 (HUD du BR, arc de coup du Duel), 352, 851, 1039, 1171, 1215, 1332, 1349 | titre = nom du mode ; HUD propre au lot CO-G | lot CO-G |
| `ui/pause_menu.gd` 95 (bourse), 115-122 (textes d'abandon) | bourse montrée, texte de Survie | **corrigé** |
| `ui/run_page.gd` 70 (« S'extraire ») | bouton inutile | **corrigé** |
| `ui/run_page.gd` 28-195 (titres, trophées, cartes, sac) | page Run de la pause | lot CO-G |
| `ui/menace_badge.gd` 61 | état « team » : jamais sur la carte | sûr |
| `ui/minimap.gd`, `ui/royale_*.gd` | Battle royale seulement | sûr |
| `ml/ml_arena.gd` | arène d'IA | sûr |

Équivalence des corrections pour les modes d'avant : `Modes.hero_match()` = `Duel.active or Royale.active or TeamMatch.active`, et
`TeamMatch.active` est toujours faux hors mode d'équipes (table de vérité de `test_mode0`, 5 120 états) : mêmes valeurs qu'avant.

## 4. Tests

`test_co_a` (≈ 45 contrôles, 30 s) : barèmes, formats, profil ; tours complets à 6 et 8 équipes ; exempts (5 équipes, 10 manches :
2 chacune, jamais deux fois de suite) ; 1 000 / 1 000 / 300 parties (places uniques, vainqueur, minimum de revanches anticipées relu
indépendamment, fin au plus tard manche 12 / 8 / 13) ; égalités au temps et exactes ; éliminations simultanées ; finale nulle ;
trios ; difficultés ; lancement (mode, type, scellé, JcJ, profil lu par `PvpCaps`, équipement mis de côté, options, directeur, quêtes,
pause) et fin (menu, profil seulement à l'exécution).

Résultats (copie de HEAD 0.1.292 + CO-A, `run_tests.py --reuse -j 2`, 32 Godot actifs sur la machine) : `test_co_a`, `test_mode0`,
`test_texts_fr`, `test_hud2` verts ; `python tools/check_scripts.py` (copie) : 535 scripts compilent.

## 5. Pièges pour la suite
1. `Colisee.begin` ne change pas de scène : l'appelant fait `change_scene_to_file("res://scenes/world.tscn")`.
2. Les places de `Colisee` et de `TeamMatch` ne concordent que si le directeur rend les éliminations **dans l'ordre de `report`**.
3. `PROFILE` n'est **pas** dans `ModeRules.PROFILES` (sinon `test_mode0` casse) : `Colisee.register_rules()` au lancement.
4. Le Grand tournoi reste `locked` tant que la sonde du lot CO-C ne l'a pas validé.
