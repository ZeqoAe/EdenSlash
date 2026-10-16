# R_AC_B — L'Échiquier, lot AC-B : la partie (16/10/2026)

## Fait
- `game/scripts/core/autochess.gd` (`Autochess`, RefCounted, aucune scène) : machine d'étapes, 8 stratèges, boutique,
  banc, plateau (cases logiques), fusion, XP, or, intérêts, séries, dégâts de joueur, appariement + fantôme, choix partagé,
  atouts, butin, places, élimination, fin, abandon, sauvegarde / reprise ; combat **injecté** ; `RandomStrategist` (tests).
- `game/scripts/core/autochess_pool.gd` (`AutochessPool`) : réserve partagée (copies restantes, tirage au poids des copies).
- Test `test_ac_game` (48 vérifications, ≈ 70 s) : 500 parties au hasard sans erreur (invariants à chaque phase), fusion
  banc plein (★2 et ★3 en chaîne, objets combinés), Étoile filante, objets (Couronne, Marteau, Emblème), revenu de chaque
  manche = prévision sur une partie entière, égalité, fantôme, places et départages, abandon, même graine = même partie,
  reprise identique (IA et joueur humain : même boutique après relance). `AC_GAMES=50` pour un essai court.

## API publique (lots D, E, F, G, I)
| Quoi | Appel |
|---|---|
| Lancer / reprendre | `g := Autochess.new(); g.start(graine, stratèges, combat)` ; `Autochess.load_game(chemin, stratèges, combat)` (null si rien), `has_save()`, `clear_save()` ; `g.save_path = ""` : aucune sauvegarde (simulateur) |
| Phases | `g.phase` : prep → `end_prep()` → combat → `run_fights()` ou `finish_combat(résultats)` → recap → `next_round()` ; `step()`, `play_to_end()`, `is_over()` ; signaux `phase_changed(phase)`, `changed(pi)` |
| Manche | `stage`, `round_i`, `round_key()` (« 3-2 »), `round_kind()` (ouverture, monstres, jcj, choix, gardien), `prep_time()` |
| Stratège | `g.players[pi]` : hp, gold, level, xp, max_level, streak, board ([{uid, id, stars, copies, items, cell:[col, rangée]}]), bench (9, null = vide), items (banc d'objets), shop (5 ids, "" = vide), locked, augments, crowns, trait_bonus, pending, place, alive, last (bilan : result, damage, gold, opponent, ghost), income (détail du revenu), final_board, stats, **meta** (libre pour AC-D, sauvegardé) |
| Actions (prep) | `buy(pi, case)`, `sell(pi, uid)`, `reroll(pi)`, `buy_xp(pi)`, `toggle_lock(pi)`, `place(pi, uid, Vector2i)` (échange si prise), `to_bench(pi, uid, case=-1)`, `equip(pi, indice_objet, uid)`, `set_ready(pi)` / `all_ready()`, `abandon(pi)` -> place ; toutes renvoient faux si refusées |
| Choix | `pending(pi)` : {kind : ouverture, atout (rerolls), choix_partage, objet, composant, famille, heros, embleme ; options} ; `choose(pi, i)`, `reroll_choice(pi)` ; non faits à `end_prep()` : 1re option |
| Lecture | `board_cap`, `units_of`, `bench_units`, `find_unit`, `unit_at`, `free_cell(pi, place)`, `can_receive`, `trait_counts` / `active_traits` (Cœur de famille, Double trait, emblèmes compris), `team_value`, `income_for(pi, étape, manche)`, `unit_traits(u)`, `parse_item(s)`, `board_snapshot`, `pool.remaining(id)` |
| Stratège IA | objet avec `decide(g, pi)` (appelé au début de chaque préparation, après revenu et boutique) et `choose(g, pi, choix) -> int` (-1 = relancer l'atout). Seul hasard permis : `g.rng` |
| Combat | `fight.call(plateau_a, plateau_b, ctx)` -> {winner 0 / 1 / -1, stars [[a], [b]], duration, gold [a, b] facultatif} ; ctx : stage, round, kind, seed, a, b, ghost_of, augments [a, b], traits [a, b], guardian_mult. Monstres : `{"monster": "elite" / "sbire"}` ; gardien : `{"guardian": true, stage, mult}`. `g.fights` liste les combats préparés (le directeur réel peut les jouer lui-même). `power_fight` = combat provisoire |

## Décisions (points que la SPEC laissait ouverts)
- Revenu crédité **au début de la préparation** (« Or de départ 2 à 1-2 » = le revenu de 1-2) ; intérêts sur l'or d'avant ;
  intérêts et série seulement avec un revenu de base (rien au choix partagé) ; +1 or de victoire JcJ tout de suite.
- Niveau 2 donné à 1-2 **sans** XP cette manche-là, +2 XP par manche dès 1-3 (sinon on passe niveau 3 dès 1-2).
- Fin de préparation : plateau complété depuis le banc (case selon `place` de l'unité), au-delà des places les dernières
  posées reviennent au banc (vendues s'il est plein). Rangée 0 = la plus proche de l'ennemi.
- Copies : la boutique et le choix partagé tiennent leurs copies ; l'ouverture n'en tient pas (prise au choix). Une unité
  porte `copies` (★2 d'Étoile filante = 2, Héros légendaire selon la réserve) : vente et élimination rendent ce nombre.
- Rareté d'atout tirée **une fois par manche** pour les 8 (jamais deux Éclats de suite) ; jamais un atout déjà pris.
- Fantôme : un vivant qui n'en a pas eu à la manche d'avant ; propriétaire hors de ses derniers adversaires si possible.
  Appariement avec retour arrière ; contrainte relâchée seulement s'il n'existe aucun appariement (0 sur 31 860 à 8 vivants).
- Choix partagé banc plein : l'unité est vendue d'office, le composant reste. Atouts « de partie » appliqués ici (or, XP,
  unités, objets, places, choix, Étoile filante, Écho de recrue, Menace, Forge de campagne) ; ceux de combat sont dans
  `ctx.augments` pour AC-H.
- Abandon : place = rang parmi les vivants (PV, puis valeur d'équipe) ; la partie s'arrête (phase « over »).

## Chiffres (combat provisoire, IA au hasard)
500 parties : 33,4 manches en moyenne (29 à 39), fin à l'étape 5 à 7 ; ≈ 0,14 s par partie (machine + combat de données).

## Reste / pièges
- Le combat `power_fight` est un remplaçant : AC-C (simulateur) et AC-E (vrai combat) se branchent par `fight` ou `fights`.
- Une règle de fusion qui change en cours de partie (Étoile filante prise avec deux copies au banc) faisait perdre l'unité
  achetée banc plein : `_take_augment` refait les fusions et `_add_unit` repose l'unité dans la case libérée. Le test de
  500 parties vérifie l'invariant de la réserve après chaque phase ; à refaire après tout changement des fusions.
- Clés neuves d'un dictionnaire d'unité : `u["cell"] = …` (`u.cell = …` crée une clé StringName) ; l'emplacement d'une
  unité se lit par `_board_index`, pas par `has("cell")`.
- La sauvegarde est faite **après** les décisions des IA : la reprise ne rappelle pas `decide()`.
