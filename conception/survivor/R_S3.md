# R_S3 — Survivant, cartes (15/10/2026)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md`, `R_S1.md`, `R_S2.md`, `PLAN_NUIT.md`, `R_P13.md`, `R_U3.md`, `CLAUDE.md`.
Code : `core/survivor_cards.gd` (tout le lot, `handles()` = vrai : les crochets de S1 passent aux cartes du Survivant).
Retouches ciblées hors lot : `run.gd` (2 retours anticipés `Survivor.active`), `player.gd` (`knock_immune`), `card_picker.gd`
(Passer, Bannir / Garder des cartes du Survivant), `survivor_gear.gd` (`upgrade_offer(..., exclude)` : passifs bannis),
`mode_rules.gd` (`set_damp` 0,3 → 0,14), `test_sv1` (le départ n'est plus « première compétence »), `test_sv2` (fréquence du 5/5
mesurée avec le vrai tirage). Nouveaux : `tests/test_sv3`, `tests/shot_sv3`, `tools/sv_cards_sim`.

## Fait
- **Offre de 3 cartes** (`roll`) : cartes gardées d'abord ; une carte d'**équipement** (arme tant qu'aucune n'est portée ; sinon
  nouvelle pièce d'un emplacement libre, amélioration de pièce ou d'arme) ; une carte de **sort** (filet : nouveau sort tant que
  le héros en a < 2, et < 3 dès le niveau 6) ; cartes libres au poids ; une évolution en attente (absente de 4 choix) passe
  devant ; au plus 2 nouvelles pièces ; cibles toutes différentes (`sv_key`) ; mélangées ; repli (or, soin sous 70 % des PV,
  relance) seulement s'il manque des cartes. Aucune carte commune, aucun certificat, aucun trophée.
- **Familles** : `sv_weapon`, `sv_piece` (pool de S2), `sv_piece_up` / `sv_weapon_up` (+2, +4 en légendaire, jusqu'à +10 ; le
  passif de chaque palier franchi est tiré à la proposition par `SurvivorGear.upgrade_offer` et ÉCRIT sur la carte ; rare et
  mieux relèvent aussi le jet de 3 / 5 / 5 points, chemin vers le jet parfait), `skill` / `chain` (types de Run, 6 sorts au plus),
  `upgrade` (niveau 1 à 10, `Cards.skill_upgrade`), `sv_evolution` (légendaire de Boons quand ses passifs sont portés).
- **Premier choix obligatoire** (`first_offer`, `start_offers`) : 3 cartes, 1 ou 2 armes (types tous différents, type de la
  classe ×2, même nature de dégâts ×1,5) et des compétences du kit, au moins une de chaque ; ni « Passer » ni repli (`sv_first`).
- **Relances** : `base_rerolls` (2) + statistique « relances » des passifs + cartes de repli ; une amélioration relancée tire
  un autre passif. **Bannir** (3) : sort, type d'arme, set (« Bannir le set » ; modèle hors set), passif d'une amélioration
  (« Bannir ce passif » : plus jamais tiré, la carte est remplacée par la même pièce avec un autre passif), évolution ; pas
  l'amélioration de sort ni le repli. Les bannissements vivent dans `Run.banned` (préfixes `set:`, `model:`, `wtype:`,
  `passive:`, `evo:`), remis à zéro par `Run.start`. **Garder** (3) : la carte revient TELLE QUELLE (même pièce, même passif) si
  elle est encore valable (`still_valid`). **Passer** : 15 + 3 × niveau d'or, partout sauf au premier choix.
- **Coffres** (`chest_cards`, appelés par S4) : emplacement libre = 3 pièces de cet emplacement (jamais deux du même set) ; pris =
  son amélioration d'abord puis celles d'autres pièces ; arme = 3 armes, puis 3 améliorations de raretés différentes ; sort ;
  doré (chance +0,6) ; gardien = pièces d'emplacements libres différents (sinon améliorations légendaires) ; enclume = +2 sur
  les 3 pièces les plus proches d'un passif (vide : S4 le dit au joueur).
- **Neutralisation du compte** (DECISIONS §5) : `Run.passive_stats` sans talents, certificats ni plateau ; `Run.skill_talent`
  sans talents ; `Player.knock_immune` sans certificats ; tout le kit de la classe ouvert (`Progression.skill_unlocked` ignoré) ;
  passifs tirés dans `Cards.passive_effects()` (jamais `Cards.card_unlocked`) ; archive et auras déjà coupées par S1 ; trophées :
  aucun (ni carte, ni sanctuaire). `SpellPresets` ne fait que ranger les sorts pris (aucun sort ni bonus) : gardé.
  Hors Survivant, rien ne change (vérifié : talents et certificats comptent en Survie, `test_sv3`).
- **Interface** (retouches ciblées, S5 refera le rendu) : cartes lisibles en 1280 × 720 (captures `shot_sv3` regardées :
  premier choix, montée de niveau, coffre ; stats sur une ligne, set « 1 / 5 », passif, « Jet 114 / 120 · 🔒 gardée toute la
  run »), bouton « Passer (+N or) » à côté de « Relancer (n) » (même style, navigable à la manette : UiNav) ; pause et cadre sur
  la 1re carte de P13 inchangés.
- **Bot** (`auto_pick`, aide « Bot » et pilote) : arme ; nouveau sort tant que < 4 ; évolution ; amélioration qui éveille un passif ;
  amélioration d'arme ; pièce (du set porté d'abord) ; amélioration de sort ; repli en dernier ; `random` ajoute du hasard.

## Règles de pondération (profil `survivor`, modifiables en mode dev)
| Candidat | Poids |
|---|---|
| Arme (aucune portée) | 2 × `w_weapon_up` = 5 ; c'est alors la carte d'équipement garantie |
| Nouvelle pièce, par emplacement libre | `w_piece_new` 1,0 ; ×1,5 sur un emplacement de set si un set a déjà 2 pièces portées |
| Amélioration de pièce / d'arme | `w_piece_up` 0,8 / `w_weapon_up` 2,5 ; ×1,6 si la carte (+2) éveille un passif |
| Nouveau sort (famille, partagé entre les sorts ouverts) | `w_spell_new` 3 si < 2 sorts, ×2/3 si < 4, ×1/3 sinon |
| Amélioration de sort, par sort < 10 | `w_spell_up` 1,1 |
| Évolution | `w_evolution` 4 |
Pitié : ×2 après `pity_after` (6) choix sans apparaître (`Survivor.since`). Rareté des améliorations : poids de `Cards.TIERS`
(60 / 27 / 10 / 3), chance + `luck_per_min` × minutes (+0,3 coffres d'emplacement, d'arme et de sort, +0,6 coffre doré).

## Amélioration de sort : effet de la carte, par niveau (Cards.skill_upgrade, cumulé dans l'entrée du sort)
| Carte | Dégâts (soins +15 %, buff : durée +12 %) | Recharge | Facettes (Puissance +8 %, Cadence -4 %, Persistance +12 %, × rareté) | Bonus d'attribut au lancement |
|---|---|---|---|---|
| Commune ×1 | +12 % | -5 % | 0 | non |
| Rare ×1,5 | +18 % | -7,5 % | 1 | 1 fois sur 2 : +12 % pendant 6 s |
| Épique ×2,2 | +26 % | -11 % | 2 | 1 fois sur 2 : +18 % |
| Légendaire ×3 | +36 % | -15 % | 3 | toujours : +24 % |
Niveau 5 : carte au moins épique ; niveau 10 : légendaire. Recharge plafonnée à -60 % (`Run.skill_cooldown_mult`).
Moyennes mesurées (simulateur, Bot, 200 runs) — dégâts cumulés / recharge : niv. 2 +27 % / -10 % · 3 +54 / -21 · 4 +83 / -31 ·
5 +129 / -48 · 6 +159 / -54 · 7 +184 / -58 · 8 +211 / -60 · 9 +240 / -60 · 10 +313 / -60.

## Simulateur (`tools/sv_cards_sim.tscn -- runs=200`, choix sans combat, vrai tirage)
Modèle : départ + 37 niveaux en 20 min + 14 coffres (tirés dans le `LAYOUT` de S4) + 3 gardiens + 3 enclumes + 7 cartes libres
(géants, sanctuaires) = 65 choix. Trois joueurs (200 runs chacun) :
- **Pilote** (hasard) : 9/9 pièces, +N cumulés 64 / 90, 5,7 pièces à +10, 6 sorts (86 %), niveau moyen 4,4, 1,5 évolution ;
  3/5 d'un set 13 %, 5/5 0 %. **Bot** : +N 49, 4,5 pièces à +10, niveau de sort 5,9, 0,44 sort au niveau 10 ; 3/5 18 %, 5/5 0 %.
- **Chercheur** (vise un set de son armure, passe plutôt que prendre une autre pièce de set) : 3/5 98 %, **5/5 ≈ 1 run sur 25**
  (600 runs × 3 graines : 1/19, 1/32, 1/27 ; 200 runs : 1/17), 2,9 « Passer » par run. Avec `set_damp` 0,3 (valeur de S2,
  estimée sans le vrai tirage) c'était 1 sur 9 : réglé à 0,14 (0,12 → 1 sur 37, 0,15 → 1 sur 21).
- **Cartes mortes** : 0 carte de repli vue sur 39 000 choix ; `test_sv3` : 0 offre « tout en repli » sur 10 000 états aléatoires.
- **Builds** : 200 signatures distinctes sur 200 runs (arme | famille du set | 3 passifs les plus forts) pour chaque joueur ; les
  17 armes portées (3 à 19 runs chacune) ; les 38 passifs vus (le plus fréquent dans 66 % des runs, le plus rare 34 %) ; aucun
  build dominant trivial.

## Tests
`test_sv3` (77 vérifications, vert ; `SV3_ROLLS=N`, 10 000 tirages par défaut) : premier choix (200), garanties, au plus 2
pièces, cibles distinctes, jamais de carte commune, 6 sorts, niveaux 5 / 10, sans arme → arme, filet de sort, jamais tout en
repli, chaque type proposé et appliqué, passif affiché = appliqué (+6 / +8 / +10, 4 passifs à +10), légendaire +4, relance
(autre passif), bannissements (passif, set, sort, 4e refusé), garder (même carte), passer, coffres, Bot (300), interface
(premier choix sans Passer, relance, Passer), neutralisation du compte, hub intact. Verts aussi : test_sv1, test_sv2, test_sv4,
test_cards, test_p13, test_nav_screens, test_farm, test_progress, test_build, test_hud, test_controls, test_e6, test_p12,
test_lot17, test_siege. `test_royale` échoue (« joueur tombé : 8e place ») : fichiers du Battle royale en cours de modification
par une autre session (M1 : `royale_director`, `class_rival`, `player` non poussés), sans lien avec les cartes.

## Pièges et restes
- `roll()` sans arme ni sort renvoie le premier choix (un appel de `Run.roll_cards` avant le départ ne casse rien).
- `Run.kept` contient en Survivant des cartes complètes (pièce, offre de passif) ; le sélecteur compare type + id comme avant.
- Pas de « Passer » au premier choix seulement ; les coffres l'ont (sinon un coffre d'emplacement forcerait une pièce à vie).
- `SurvivorCards.minutes()` lit `world.director.time` ; tests et simulateur : `minutes_override`.
- S5 : `Cards._num` écrit « 2.5 » (point) dans les cartes de toute la partie ; `SpellInfo.skill_bbcode` montre encore « R1-R5,
  +20 % / -8 % par rang » ; badge de niveau sur la barre de sorts ; page Build.
- S7 : la recharge des sorts atteint le plafond (-60 %) vers le niveau 8 ; les pilotes remplissent les 9 emplacements tôt et
  montent peu les sorts au niveau 10 (0,06 à 0,44 par run) : à recaler sur de vraies runs (poids `w_*`, `auto_pick`).
