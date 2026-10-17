# R_AC_U — L'Échiquier, lot AC-U : l'IA de combat des unités (17/10/2026)

Décision du joueur reprise telle quelle : **aucun cerveau neuronal**, « il faut que nos IA scriptées jouent très bien ».
Même IA, même réglage (Difficile) pour toutes les unités des 8 stratèges.

## Fait
- `game/scripts/ai/autochess_unit.gd` (`AutochessUnit extends ClassRival`) : IA complète sur le squelette d'AC-E, contrat avec
  le directeur inchangé. Cinq comportements coupables un à un (`ai`, `on(k)`, détails `sub(k)` : `full,-hop`) :
  - **roles** : place par rôle (`autochess_units.json`) ; mêlée au contact (fini les tours à 4,5 m) ; tireurs, mages,
    soigneurs, soutiens à distance gardent leur portée et **reculent d'un bond** quand une mêlée qui les vise arrive à 1,5 case
    (vers leurs alliés et le centre, jamais dans un coin, le long du bord s'ils sont coincés) ; soigneurs et soutiens
    **derrière la ligne** de leurs mêlées ; **assassins** : attendent l'engagement des mêlées ennemies (0,9 s au plus) en
    glissant vers le flanc le moins garni, puis plongent sur l'arrière-ligne la moins protégée (soigneurs et mages d'abord),
    contournent par ce flanc si une mêlée barre la route, un bond s'ils sont loin ; ensuite le plus fragile proche.
    **Bords** : toute vitesse, écartement, bond, saut et élan perd sa part qui sortirait du plateau (`_edge_safe`).
  - **target** : score de cible = faiblesse (PV × défense) + menace (dégâts des 3 dernières secondes, coût × étoiles, objets)
    + achèvement (sous 20 % à portée + 1 case) − trajet, poids `AutochessData.AI_WEIGHTS` ; focus du camp (recalculé chaque
    seconde, atteint par 2 alliés, +30 %) ; 3 mêlées au plus sur une cible ; marge de 25 % avant de quitter une cible vivante,
    sauf cible hors d'atteinte 1,5 s ; tank : l'ennemi qui frappe un allié fragile (`TANK_GUARD_BONUS`) ; assassin :
    arrière-ligne non protégée.
  - **spells** : selon `spell_type` : zone posée où elle touche le plus d'ennemis (chaque ennemi et le milieu de chaque paire,
    places du moment : la visée anticipée `lead` est coupée, perdante), tout de suite sur 2 ou plus, sur 1 après 1,5 s, sur la cible après 3 s si rien
    n'est à portée ; un tireur pose son tourbillon / cône comme une zone ; cible unique sur l'alignement le plus garni ;
    soin sur l'allié à portée le plus bas, soins en route comptés, seulement s'il manque assez de PV (pas de soin perdu),
    sous 45 % tout de suite, sous 70 % après 2 s ; renfort au début ; déplacement pour rejoindre.
  - **dodge** : esquive des zones rouges **ennemies** seulement (lignes et cônes de côté, cercles vers son camp) ; ni bond
    réflexe, ni bond après l'impact (`_cancel_after_hit` = fin d'animation seulement), ni esquive pendant un sort.
  - **retreat** : repli sous 30 % des rôles fragiles visés par une mêlée — **coupé par défaut** (`OFF_BY_DEFAULT`) : perdant.
- IA naïve (`naive`, tous coupés) : la plus proche, sort dès la mana pleine sur la cible, soigneur qui avance, ni recul ni esquive.
- Banc d'essai `game/tools/autochess_ai_bench.tscn` (SPEC §4.2) : miroirs exacts (mêmes unités, étoiles, objets, cases),
  40 compositions (8 × plongeurs, tireurs, mur, sorts, soins) × 3 graines × 2 côtés = 240 combats, comportements par
  `fight.ai = [camp 0, camp 1]` (lu par `setup_unit`) ; ligne `[ac_bench]` par combat, synthèse `[ac_bench] ===` ; compteurs par
  unité dans `ac_stats` (zones / touchés, soins demandés / perdus, relevés d'inactivité et de portée, bonds, esquives, plongées).
- Test `game/tests/test_ac_unit_ai.tscn` (15 vérifications, ~5 s).
- `core/mode_rules.gd` (édit ciblé, profil `autochess`) : **dmg_scale 0,10 → 0,12** (mesure ci-dessous : égalités en miroir).

## Mesures (240 combats 5 contre 5 chacune, headless, `--fixed-fps 60`)
| Mesure | Cible | Avant (squelette AC-E / AC2) | Après |
|---|---|---|---|
| IA complète contre naïve | ≥ 75 % | — | **99,6 %** (98,8-99,6 sur les séries successives) |
| esquive seule / ciblage seul | ≥ 55 % | — | **94,2 %** / **59,6 %** |
| rôles seuls | ≥ 55 % | 49,6 % (bond sur toute mêlée proche) | **56,3 %** (bond devant la mêlée qui le vise, mêlée à 0,9 de l'allonge) |
| sorts seuls | ≥ 55 % | 52,9 % avec visée anticipée | **56,3 %** (sans visée anticipée) |
| repli seul | ≥ 55 % | — | 46,7-53,8 % ; en contexte l'IA sans repli bat l'IA avec 58 % → **retiré** |
| soins perdus | ≤ 15 % | naïve 0-2 % | **0,0-0,4 %** |
| ennemis touchés par zone (contre la naïve) | ≥ 2 | naïve 0,74 | **2,00-2,01** ; sorts seuls 2,09-2,16 (en miroir complet 0,74 : l'adversaire esquive) |
| tireurs / mages à portée / au contact | ≥ 70 % / ≤ 20 % | — | **90-92 % / 9-13 %** (contre la naïve), 90 % / 21 % en miroir complet |
| bornes corrigées par combat | 0 sortie | ≈ 250 par combat (R_AC_E) | **0,9-1,4** ; 0 image hors du plateau |
| inactivité (aucune action 3 s) | < 10 % | 27 % (AC2, ClassRival) | **0,1 %** |
| miroir complet : durée médiane / égalités | 20-35 s / < 3 % | — | dmg 0,10 : 32,2-32,9 s / 2,9-6,3 % ; **dmg 0,12 : 28,1-28,6 s / 0,4-0,8 %** |
| coût (10 contre 10, 8 plateaux, machine chargée) | — | naïve 0,31 ms / unité | complète 0,29 ms / unité (aucun surcoût) |

Le banc est déterministe (mêmes graines : même résultat) ; l'écart d'une série à l'autre vient du code. Détails (rôles seuls) :
bond de recul +8 points (et l'IA complète bat la même sans bond 60 %) ; plongée : plongeurs 63-67 % ; ligne des soigneurs :
sans elle 50 % ; tireurs et mages derrière la ligne aussi (`line_all`) : 53,8 %, 47,9 % en contexte, non retenu ; mêlée à
0,85 de l'allonge : 54,6 %, à 0,9 : 56,3 %. Visée anticipée des zones : l'IA sans elle bat celle avec 54,6 %.

## Relancer
```
Godot --headless --fixed-fps 60 --path game res://tools/autochess_ai_bench.tscn -- --ai=full            # contre la naïve
Godot ... -- --ai=roles | target | spells | dodge | retreat                                             # un comportement seul
Godot ... -- --ai=full --vs=full,-hop      # A / B en contexte ; --comps=40 --seeds=3 --size=5 --batch=12 --items=0.3
Godot ... -- --shard=0/4 --out=a.json  puis  -- --merge=a.json,b.json,…                                # en parallèle
Godot --headless --fixed-fps 60 --path game res://tests/test_ac_unit_ai.tscn
```
~2 combats par seconde sur un cœur libre (240 combats : 4-9 min selon la charge).

## Reste / pièges
- Rôles seuls et sorts seuls à 56 % : juste au-dessus du seuil (intervalle d'une série de 240 : ± 6 points) ; zones à 2,0.
- `test_ac_fight` : « budget d'image 80 unités sous 20 ms » échoue quand la machine est chargée par d'autres sessions
  (22-44 ms à 93-100 % de CPU, 11 ms au calme) ; même coût par unité avec l'IA naïve : pas une régression de l'IA.
- Le simulateur d'AC-C est calé sur le vrai combat d'avant AC-U (et `dmg_scale` 0,10) : à recaler (`tools/autochess_fight.tscn --calib`).
- Repli : gardé dans le code pour le banc (`--ai=full,retreat`), à retenter avec un soigneur qui suit le replié.
