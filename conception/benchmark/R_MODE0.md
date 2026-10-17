# R_MODE0 : socle commun des modes d'équipes (lot MODE-0, 17/10/2026)

Préparation des trois modes d'équipes validés par le joueur : **Le Colisée** (6 équipes de 3, `ARENA.md`), **Les Deux Voies**
(4 contre 4 à objectif, `MOBA.md`) et **L'Assaut** (4 contre 4 tactique, `TACTIQUE.md`), tous scellés et joués seul contre des IA.
But : un socle unique, **sans rien changer aux modes existants** (Duel, Arènes, Gantelet, Battle royale, Échiquier, Survivant, Siège…).

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Contexte de partie d'équipes | `game/scripts/core/team_match.gd` (`TeamMatch`) | registre des modes, équipes, couleurs, camps, arènes, vivants / éliminés, manches, spectateur, résultats, directeur du mode, fabrique de héros IA sans état de Duel |
| API unique de mode | `game/scripts/core/modes.gd` | `Modes.current()` (id du mode d'équipes), `Modes.kind()`, `Modes.sealed()`, `Modes.is_pvp()`, `Modes.team_match()`, `Modes.hero_match()` |
| Profils de règles enregistrés | `game/scripts/core/mode_rules.gd` | `ModeRules.register(nom, profil)`, `has_profile` ; `profile_name()` rend le profil de la fiche du mode d'équipes |
| Filtre d'arène | `game/scripts/combat/combatant.gd` | `arena_id` (-1 = partout), `Combatant.same_arena` ; `ffa_foes`, `hostile_heroes`, `hostile_targets` filtrent l'arène |
| IA en équipe | `game/scripts/ai/class_rival.gd` | `_team_mode` vrai en mode d'équipes ; `_teammates` = l'équipe dans son arène ; `_read_zones` ignore les zones de son équipe et des autres arènes |
| Branchements du jeu | `core/world.gd`, `core/run_director.gd`, `core/profile.gd`, `core/potions.gd`, `core/run_journal.gd`, `core/quests.gd`, `player/player.gd` | directeur du mode monté par `RunDirector.start` (état « team ») ; mort du joueur et abandon rendus au directeur ; ni carte de départ, ni cartes de niveau, ni bonus de zone, ni musique de rage, ni potions, ni journal, ni sauvegarde en cours de partie (options de la fiche) ; activité des quêtes |
| Palette d'équipes | `game/data/ui_tokens.json` (`couleur.equipe`), `conception/art/BIBLE.md` § 3 | 8 couleurs + 8 motifs ; contrôle `python tools/team_palette_check.py` |
| Blason d'équipe | `game/scripts/ui/team_sigil.gd` (`TeamSigil`) | pastille autocollant couleur + motif blanc contouré |
| Test | `game/tests/test_mode0.tscn` (+ `tests/mode0_demo_director.gd`) | voir § 5 |

## 2. Inventaire chiffré (HEAD 0.1.286, `game/scripts`, hors tests et outils)

| Test | Lectures | Fichiers | Où surtout |
|---|---|---|---|
| `Duel.active` | 40 | 15 | hud 6, world 6, player 5, run_page 4, run_director 4, run_journal 3, pause_menu 2, ml_arena 2, modes 2… |
| `Royale.active` | 65 | 23 | hud 10, run_page 9, minimap 7, run_journal 5, player 4, run_director 4, run 3, world 3, items 2, class_rival 2… |
| `Modes.sealed()` | 9 | 5 | run 4, player 2, hero_level, equipment_page, inventory_page |
| `AutochessDirector.active` | 4 | 2 | modes 3, autochess_director 1 (il le pose) |
| `ModeRules.` | 29 | 10 | pvp_caps 10, combatant 6, survivor 3… |
| `Modes.current()` | 8 | 4 | hero_level, mode_rules, run_journal, tutorial |
| `Siege.ffa` | 6 | 5 | — |
| `ffa_id` (camp chacun pour soi) | 18 | 9 | combatant 7… |
| `Duel.team_mode()` | 5 | 2 | duel_director 4, class_rival 1 |

Dans `tests/` et `tools/` : `Duel.active` 33, `Royale.active` 43, `ModeRules.` 55, `Modes.sealed()` 10. Le dossier de travail partagé
en compte un peu plus (travail en cours d'autres agents : 69 `Royale.active`), d'où les « 109 » de l'étude ARENA.

**Variables statiques de `Duel` (28)** : `active`, `rival_class`, `bare`, `mode`, `last_report`, `team_allies`, `extra_foes`,
`arena_level`, `forfeit`, `hazards`, `_free_prefs`, `bare_level`, `bare_variant`, `_stashed_build`, `_stashed_mults`, `_weakened`,
`difficulty`, `level`, `wins`, `losses`, `round_n`, `gear_mode`, `rival_spells`, `hp_mult`, `pilot`, `rival_build`, `atk_mult`,
`_opti`. Elles portent : l'interrupteur, l'adversaire et ses réglages (classe, difficulté, sorts, PV / dégâts, cerveau, profil de
l'éditeur, équipement généré / copié / opti), le format (libre, Ligue, Panthéon, Arènes, Gantelet, équipes, arène piégée), le niveau,
le score de manches et le bilan. **Toutes supposent un seul combat** ; `Duel.make_ally` / `make_extra` / `make_rival` les lisent
(`gear_mode` = copie de TON équipement par défaut). `PvpCaps` a aussi un état global : `elapsed`, `round_times`, `best_dealt`,
`best_taken`, `board`. `Royale` : `active`, `difficulty`, `rank`, `kills`, `last_report`, `zone_id`, `level_cap_now`, `mod`, `custom`,
`custom_seed`, `fights`, `fight_log`…

## 3. L'API que les trois modes utilisent

```gdscript
# déclaration (fiche) : TeamMatch.MODES (colisee, moba, assault) ou TeamMatch.register(id, fiche) ; profil de règles :
ModeRules.register("colisee", {...})                   # dmg_scale, hit_cap, burst_cap, caps… (comme PVP_A3)
# lancement (page du lobby) :
Run.start(classe) ; Run.zone_id = … ; TeamMatch.begin("colisee", -1, {"director": "res://scripts/core/colisee_director.gd"})
get_tree().change_scene_to_file("res://scenes/world.tscn")   # RunDirector.start -> TeamMatch.mount -> directeur.setup(rd)
# dans le directeur : carte, équipes, héros
var r := TeamMatch.make_hero("cleric", niveau, difficulté, équipe, arène)   # ClassRival à la fiche d'un héros, sans Duel
TeamMatch.add(d.player, TeamMatch.player_team, arène)
TeamMatch.start_round() ; TeamMatch.set_phase("countdown"|"fight"|"recap"|"done")
TeamMatch.note_ko(victime, tueur) ; TeamMatch.wiped(t, arène) ; TeamMatch.end_round(gagnant) ; TeamMatch.round_winner()
TeamMatch.eliminate(t) -> place ; TeamMatch.finish(ordre) ; TeamMatch.standing() ; TeamMatch.result()
TeamMatch.next_watch(±1) ; TeamMatch.watched                 # spectateur (caméra : d.world.rig.target)
func update(delta), func player_down(tueur), func abandon()   # appelés par RunDirector et world.gd
# fin : récompenses scellées (patron AutochessRewards.finish), Quests.end_run(TeamMatch.act(), …), puis TeamMatch.end()
```

- **Le mode actif** : `Modes.current()` = `"colisee"` / `"moba"` / `"assault"` ; `Modes.kind()` = `teams` / `objective` (et pour les
  modes d'avant : `menu`, `pve`, `duel`, `teams` pour Arènes et Gantelet, `ffa`, `board`) ; `Modes.sealed()` vrai (rien du compte :
  talents, certificats, plateau, archive, auras, sorts fermés) ; `Modes.is_pvp()` vrai (règles `PvpCaps` du profil) ;
  `Modes.team_match()` ; `Modes.hero_match()` = partie entre héros sans économie de run (Duel, Battle royale, modes d'équipes).
- **Camps** : équipe t = `ffa_id` `TeamMatch.FFA_BASE + t` (100+, loin des 0-7 du Battle royale et du 90 de son gardien).
- **Arènes** (Colisée) : `TeamMatch.add(c, t, arène)` ; deux arènes au même endroit ne se touchent pas (prouvé en jeu, § 5).
- **Couleurs** : `TeamMatch.color(t, "clair"|"base"|"fonce")`, `team_name(t)`, `motif(t)`, `TeamSigil.make(t, px)` ; barres de vie :
  `TeamMatch.bar_color(c)` = pomme (équipe du joueur) / fraise (adversaires), jamais la couleur d'équipe (piège 11 d'ARENA).
- **Options de fiche** (toutes fausses par défaut) : `potions`, `level_cards`, `journal`, `save` ; `win_places` (Colisée : 3),
  `rounds_to_win` (Assaut : 7), `arenas`, `director`.
- **Événements** : `TeamMatch.bus` (`phase_changed`, `round_started`, `round_over`, `member_down`, `team_out`, `watched_changed`).

## 4. Palette d'équipes (jetons `couleur.equipe`)

Ordre fixe (2 équipes = les 2 premières, 6 = les 6 premières) ; les bonbons de la DA sont **inchangés** (azur = lagon, améthyste =
améthyste ; pomme et fraise exclues : elles disent gain / danger).

| # | Clé | Nom | Base | Motif |
|---|---|---|---|---|
| 0 | azur | Azur | `#22B8F0` | rond |
| 1 | braise | Braise | `#FF8A1F` | carré |
| 2 | citron | Citron | `#F7E030` | triangle |
| 3 | amethyste | Améthyste | `#B43BEB` | losange |
| 4 | menthe | Menthe | `#12A18C` | étoile |
| 5 | griotte | Griotte | `#AE184E` | croix |
| 6 | marine | Marine | `#1C4EA2` | hexagone |
| 7 | perle | Perle | `#E7E4F3` | anneau |

Mesures (`tools/team_palette_check.py`, simulation Machado 2009 des trois daltonismes complets, écart CIEDE2000) : vision normale
**26,9** au plus près (azur / menthe) ; protanopie **12,3** (améthyste / marine) ; deutéranopie **11,7** (braise / citron) ;
tritanopie **11,2** (azur / menthe) ; à 2 équipes (azur / braise) plus de 51 partout. Seuils du script : 20 (normal), 8 (daltonismes).
Les paires sous 12 se lisent encore, mais **le motif fait le travail** : règle d'usage = la couleur d'équipe ne va jamais sans son motif.

## 5. Preuves de non-régression

1. **`test_mode0`** (≈ 70 contrôles) :
   - table de vérité : les **5 120** états des drapeaux (`AutochessDirector`, `Royale`, `Duel`, `Tower`, `Training`, `Run.active`,
     `Survivor`, `Run.survival`, `Siege.ffa` × 5 formats de Duel × à l'arme / équipé) donnent exactement les anciennes valeurs de
     `Modes.current()`, `is_pvp()`, `PvpCaps.active()`, `sealed()`, `ModeRules.profile_name()`, `hero_match()` (= l'ancien
     « Duel.active or Royale.active »), `Potions.allowed()` (formules d'avant recopiées dans le test) ;
   - chacun pour soi d'avant (Battle royale, gardien 90, Siège) : `ffa_foes` et `hostile_targets` identiques à l'ancienne formule ;
   - registre, profils, options, équipes, arènes, manches, élimination, classement, bilan, couleurs (jetons, bonbons gardés), blasons ;
   - **partie réelle** dans `world.tscn` avec un directeur de démonstration : 4 équipes de 2 dans 2 arènes **posées au même endroit**,
     12 s de combat : 24 coups dans les arènes, **0 entre arènes, 0 entre équipiers**, cibles des IA toujours dans leur arène ; ni carte
     de départ, ni monstre de la Survie ; mort du joueur et abandon rendus au directeur du mode.
2. **Suite de non-régression** (copie de HEAD, puis HEAD + MODE-0, `run_tests.py -j 2`) : voir § 7 (résultats).
3. **Parties réelles mesurées** avant / après (`world.tscn -- --duel --duel-mode=arena3|gauntlet3|arena2 --autoplay --auto-quit`,
   Battle royale `--royale --autoplay --royale-diff=1 --royale-seed=4242 --auto-quit`) : voir § 7.

## 6. Pièges restants (à lire avant CO-A, MB-0 / MB-C, TAC-0)

1. **Ne jamais poser `Duel.active` ni `Royale.active`** pour un mode d'équipes, ni appeler `Duel.make_ally` / `make_extra` /
   `make_rival` / `rival_sheet` (elles lisent ~10 statiques de Duel ; `gear_mode` copie l'équipement du joueur) : `TeamMatch.make_hero`.
2. **Lectures non migrées** (sûres aujourd'hui, à reprendre par le lot d'interface de chaque mode) : `ui/hud.gd` (or affiché,
   pile de gauche, objectifs, titre — fichier très modifié par d'autres lots, laissé tel quel), `ui/pause_menu.gd` (bourse affichée,
   texte d'abandon), `ui/run_page.gd` (trophées, cartes, sac), `ui/menace_badge.gd`, `ui/minimap.gd` (Battle royale seulement),
   `player.gd` 237 (à l'arme du Duel), 859 (enchaînement auto), 1248 (aide au coup parfait), `core/items.gd` / `ui/item_widgets.gd`
   (arme d'une autre classe permise au Survivant et au Battle royale). Le patron : `Duel.active or Royale.active` → `Modes.hero_match()`.
3. **`PvpCaps.elapsed` et `PvpCaps.board` sont globaux** : un seul chrono d'acharnement / mort subite pour toutes les arènes. Juste
   tant que tous les combats d'une manche partent ensemble (Colisée) ; le directeur l'avance lui-même (`PvpCaps.elapsed += delta`).
   `PvpCaps.board` (tableau de manche) : un dictionnaire par instance, partagé ; vider à chaque manche.
4. **`hit_stop`** est coupé en mode d'équipes (il gèlerait toutes les arènes) ; **`swap_cooldown`** est celui du JcJ.
5. **Arène = filtre logique**, pas physique : les héros de deux arènes au même endroit se traversent-ils ? Ennemis = calque monstre
   (pas de collision monstre / monstre), alliés = calque joueur ; mais un **allié** du joueur et un **adversaire d'une autre arène**
   se bousculent. Le Colisée pose ses arènes à 300 m ; ne pas superposer d'arènes hors test.
6. **Télégraphes et projectiles** passent par `hostile_targets` (filtrés) ; les **effets** (`EdenFx`), **chiffres** (`DamageNumber`),
   **sons**, **secousses** et **alertes** du HUD ne sont pas filtrés : combats cachés à couper par le directeur (patron AC-E).
7. **`ClassRival._threat`** ne lit que le `Player` ; entre IA seules les zones rouges sont lues (filtrées par arène et par équipe).
8. **Monstres neutres** (jungle des Deux Voies, Spectres du Colisée) : un `Monster` sans `ffa_id` vise les héros par
   `hostile_heroes` (camp `team`) ; pour qu'un camp neutre frappe tout le monde il faut lui donner un `ffa_id` à part (ex. 99) et un
   `arena_id` ; `Monster._update_chase` choisit parmi `ffa_foes`.
9. **Navigation** : une carte `ProcMap` cuit sa navigation sur un fil ; un test qui la génère attend
   `map._region.navigation_mesh != null` avant `quit()` (piège T1, fait dans `test_mode0`).
10. **Directeur du mode** : il tient lui-même le héros sur la carte (`RunDirector` n'appelle pas `_keep_on_map` en état « team ») et
    sa fin de partie (bilan, `TeamMatch.end()`, `Profile.reload_keep_records()` comme `Duel.finish`, retour au lobby).
11. **Sauvegarde** : `Profile.save_profile()` ne fait rien pendant la partie (`save` faux) ; appeler `TeamMatch.end()` AVANT d'écrire
    les récompenses (sinon la sauvegarde de fin est ignorée).
12. **`Modes.forced`** prime toujours sur `TeamMatch.active` (essais d'équilibrage) ; `ModeRules.forced` aussi.
13. **Signaux de `TeamMatch.bus`** : instance unique pour tout le jeu ; se déconnecter en fin de partie (le directeur meurt avec la scène,
    ses `Callable` aussi, mais un écran qui survit doit se déconnecter).
14. Les deux modes 4 contre 4 n'ont pas d'arènes (`arena_id` = -1) ; un camp neutre éventuel du MOBA reste à concevoir (MB-F).

## 7. Résultats des mesures (machine chargée par d'autres agents : `-j 2`, tests de durée relancés)

**Suite de non-régression**, même liste avant (copie de HEAD 0.1.286) et après (HEAD 0.1.286 + MODE-0) :

| Test | Avant | Après |
|---|---|---|
| test_pvp, test_duel_modes, test_modes, test_h2, test_m7, test_m2, test_siege, test_royale, test_br2, test_br3, test_br4, test_bri1, test_bri2, test_ac_unit_ai | vert | vert |
| test_m6, test_mode0 | — | vert |
| test_bri3 | **rouge** (« chiffres sobres : 3 coups -> 1 nombre ») | rouge, même échec : déjà rouge sur HEAD, sans lien |
| test_ac_fight | rouge (budget d'image, médiane 55 à 130 ms selon la charge) | rouge ; **lancés en même temps** : 129,8 ms avant, 129,1 ms après → charge de la machine, pas le lot |

Puis sur HEAD 0.1.289 + MODE-0 (lots BR-R1 et HUD-2 arrivés entre-temps) : voir la dernière ligne de ce rapport.

**Parties réelles** au pilote (`world.tscn -- --duel --duel-mode=… --autoplay --auto-quit`, Difficile, classes d'équipe tirées au hasard
à chaque partie : comparaison d'ordre de grandeur seulement) :

| Partie | Avant (durées des manches) | Après |
|---|---|---|
| Arène 3 contre 3 | 69,4 / 73,1 s (défaite 0-2) | 91,8 / 95,0 s (défaite 0-2, autres classes) |
| Gantelet 1 contre 3 (niveau 29) | 51,7 / 44,4 s | 46,6 / 48,3 s |
| Arène 2 contre 2 | 81,1 / 73,8 s (défaite 0-2) | 63,9 / 83,7 / 55,4 s (victoire 2-1) |
| Battle royale (Normal) | partie complète, 1er, 206 s | partie complète, 7e, partie de 510 s |

Aucune erreur de script dans ces parties ; les durées restent dans les plages mesurées par les passes M7 et BR1 (manches d'Arène
55-95 s, Gantelet 45-50 s). La preuve forte reste la table de vérité de `test_mode0` : hors mode d'équipes, aucune fonction de mode ne
rend une valeur différente, et les seuls autres changements de comportement possibles sont gardés par `TeamMatch.active` ou par
`arena_id >= 0` (jamais vrais dans les modes d'avant).

**Sur HEAD 0.1.289 + MODE-0** (copie refaite après l'arrivée des lots BR-R1 et HUD-2) : test_mode0, test_royale, test_brr1, test_br4,
test_m7, test_pvp, test_duel_modes, test_modes, test_h2, test_hud2, test_siege : **11 verts sur 11**.
