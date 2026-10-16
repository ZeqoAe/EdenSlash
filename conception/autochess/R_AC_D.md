# R_AC_D — L'Échiquier, lot AC-D : les stratèges IA (17/10/2026)

## Fait
- `game/scripts/core/autochess_ai.gd` (`AutochessAi`) : les 7 adversaires du joueur, scriptés (aucun cerveau). Interface
  d'AC-B : `decide(partie, i)` / `choose(partie, i, choix)` ; fabrique `AutochessAi.make(difficulté, tempérament, graine)` ;
  `AutochessAi.lineup(difficulté, graine, place_du_joueur)` = les 8 stratèges d'une partie (null pour le joueur, 7 IA au
  mélange `AutochessData.DIFFICULTIES[*].mix`) ; `AutochessAi.restore(partie)` refait les IA d'une partie reprise
  (identité, plan et compteur de hasard dans `players[i].meta`, sauvegardés avec la partie).
- 4 difficultés (SPEC §4.4) × 3 tempéraments (`econome`, `relanceur`, `montee_rapide`) :
  - **Recrue** : achète au hasard (un peu selon ses premières unités, plan changé souvent), relance et monte au hasard,
    garde ses unités posées (ne remplace que par une unité bien plus forte), place selon la portée, objets et choix au hasard.
  - **Vétéran** : garde 30 or (10 à l'étape 2), XP aux paliers et sur sa courbe, vise 2 traits dès l'étape 2, objets sur
    l'unité la plus chère, atouts à la note de base, choix partagé = unité la plus chère.
  - **Champion** : 50 or jusqu'au niveau 7, lit les plateaux / bancs adverses (quitte une famille disputée par 2+), assemble
    les objets selon le rôle (tank / physique / magie / soutien), porteur dans un coin du fond s'il y a des plongeurs,
    assassins sur les flancs, soigneur collé au porteur, atouts selon sa composition, relance un choix d'atout faible.
  - **Légende** : dépense à l'étape 2 puis garde 50 or, courbe niveau 4 (2-1) / 5 (2-5) / 6 (3-2) / 7 (4-1) / 8 (4-2),
    relance à 6 en 3-x et à 7-8 en 4-x / 5-x quand le plateau est faible, panique sous 45 PV ; 3 plans gardés jusqu'au
    1er atout, changement de plan aux étapes 3-4 si la composition ne vient pas ; lit tous les adversaires (coins contre
    les plongeurs, rangée espacée contre les zones) ; atouts selon composition, étape et PV.
- Commun (Vétéran et plus) : valeur d'un plateau = puissance des unités (coût × étoiles × objets) + paliers de traits
  pondérés par le plan + ligne de front ; plateau choisi glouton, achats (★2 complétée toujours, places libres, copies,
  amélioration) sans perdre une tranche d'intérêts, vente propre du banc (les objets reviennent et repartent sur le
  plateau), Couronne avec deux Insignes, Emblème du plan, verrou de boutique sur une ★2 inabordable.
- **Aucune triche** : l'IA n'agit que par les actions publiques et ne lit que ce que voit le joueur (son état, plateaux et
  bancs adverses) ; jamais `pool`, jamais `g.rng` (générateur propre regrainé à chaque appel). Prouvé par `test_ac_ai`.
- Banc `tools/autochess_ai_games.tscn` (hors suite) et test `test_ac_ai` (≈ 10-20 s).

## Mesures (200 parties par mise en place, graine 1)
| Mise en place | Combat provisoire `power_fight` | Combat de données (couche AC-H, `--fight=effects`, 60 parties) | Simulateur AC-C (`--fight=sim`, 200 parties) |
|---|---|---|---|
| Légende contre 7 Recrues : top 4 (cible ≥ 75 %) | **78 %** (place 2,82) | 100 % (1,08) | 99,5 % (1,12) |
| Recrue contre 7 Légendes : top 4 (cible ≤ 25 %) | **22 %** (place 6,11) | 0 % (7,47) | 0,5 % (7,63) |
| Échelle (2 de chaque) : place moyenne R / V / C / L | 5,85 / 4,31 / 4,05 / 3,79 | — | 6,93 / 4,53 / 3,41 / 3,13 (50 parties) |
- Parties : 30-32 manches en moyenne (≈ 32 min estimées avec préparations pleines et combats provisoires de 20-40 s ;
  29-31 min au simulateur AC-C, 3-4 s de calcul par partie) ; **0 partie bloquée, 0 erreur de réserve, 0 plateau anormal** sur toutes les passes.
- Temps de décision (`decide`) : 1,5-3 ms en moyenne seul (test), 3,5-4,7 ms avec 5 bancs en parallèle sur la machine
  chargée (Légende / Champion ; Recrue ≈ 1 ms) ; pire cas 20-40 ms (relance de fin de partie, 40 relances au plus).
- Pilote Vétéran à la place du joueur (`--setup=pilote`, 100 parties, `power_fight`) : top 4 66 % contre le mélange Recrue,
  53 % Vétéran (cible SPEC §9 ≈ 50 %), 58 % Champion, 44 % Légende.
- **Le combat provisoire est très plat** : un plateau 1,3 fois plus fort n'y gagne que 64-67 % de ses combats (ligne
  « victoires JcJ selon le rapport de puissance ») ; traits, rôles et assemblage des objets n'y comptent pas (deux
  composants posés à part y valent plus qu'un objet complet). D'où l'écart avec les combats de données, où la Légende
  gagne 97-99 % des combats à 1,1-1,3 fois la force. Au simulateur AC-C (le plus proche du vrai combat), l'échelle est nette
  et monotone, et la Légende écrase la Recrue.

## Réglages (tête de `autochess_ai.gd`) et essais
- A / B entre Légendes (64 parties × 8 places) : réserve 50 > 30 > 10 ; relance « ★3 » à 50 or nuisible (retirée : le
  Relanceur cherche des ★2 au niveau 6) ; courbe standard ≥ montée rapide. Contre les Recrues : dépenser à l'étape 2
  (`early` 0) +3 points de top 4 ; `adapt` (réserve réglée sur la force face à la médiane adverse) neutre au combat
  provisoire, gardé éteint pour le réessayer au vrai combat.
- `tune` (champ de l'IA, banc `--a=clé:valeur,…` / `--b=…`, `--setup=ab[:difficulté]`) : econ, early, curve, panic, roll6,
  rolldown, reroll_q, reroll_floor, potential, adapt, temper.

## Relancer
```
godot --headless --path game res://tools/autochess_ai_games.tscn --quit-after 3 -- --games=200 --setup=tout [--fight=sim]
godot --headless --path game res://tests/test_ac_ai.tscn
```
`--setup=legende_vs_recrues | recrue_vs_legendes | echelle | pilote | ab`, `--trace` (état de chaque stratège à chaque
manche), `--out=f.jsonl` (une ligne par partie). Plusieurs bancs en parallèle : 4 copies à la fois tiennent sur la machine.
`--quit-after 3` évite qu'une erreur de script laisse Godot ouvert.

## Reste / pièges
- Recaler sur le vrai combat (AC-E / AC-U) et le simulateur (AC-C) : la Légende y écrase la Recrue (0,5 % de top 4) ; si le
  joueur trouve Recrue trop dure ou Légende trop facile, régler `TRAIT_SENSE`, `BUY_MIN`, `RECRUE_*` (AC-J).
- `test_ac_ai` refait chaque décision sur une copie à partir des seules actions publiques : toute nouvelle action de l'IA
  doit passer par une fonction publique d'`Autochess` (sinon le test casse, c'est voulu).
- Le joueur au pilote (`--autoplay` de l'écran) peut utiliser `AutochessAi.make(1, …)` comme pilote Vétéran (SPEC §9).
