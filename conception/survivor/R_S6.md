# R_S6 — Survivant, fin de run et récompenses (15/10/2026, version 0.1.204)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md`, `R_S1` / `R_S2` / `R_S4`, `PLAN_NUIT.md`, `R_U9`, `R_M5`, `R_P12`, `CLAUDE.md`.
Règles dans `DESIGN.md`, « Survivant », point « Fin de run et récompenses ». Test : `tests/test_sv6.tscn` (vert), captures `tests/shot_sv6.tscn`.

## Fait
- **`core/survivor_rewards.gd`** : suivi de la run (`track`, appelé par `SurvivorDirector.update` : temps de carte, gardiens vaincus), `plan(res, tier)`
  (pur : ce que la run donnerait), `settle` (donne, après la remise du hub), `board(tier)` (page du lobby), `build()` (arme, pièces, panoplie, +10,
  jets parfaits, sorts), `quest_extra()`, `journal()`, `hub_view` (tests). Le paramètre `tier` (1 à 5) est prêt pour S8.
- **Récompenses = coffres d'apparence seulement.** Tenir 10 min → commun ; 3 gardiens → rare ; boss vaincu → mythique, légendaire dès le palier II ;
  titre de victoire par palier (5). Plafonds : chaque palier d'avancée paie une fois par palier de difficulté ; ensuite au plus un commun et un rare
  par jour. Borne totale : 15 coffres « première fois » (3 × 5). Une défaite ou un abandon paient ce qui a été atteint, jamais de titre.
  État dans `Profile.records["sv_rewards"]` (aucune clé de sauvegarde nouvelle, écrit après la remise des `HUB_KEYS`, donc gardé).
- **Bilan** (`ResultsScreen.survivor_spec`, `ResultsPanel` : une colonne `build` ajoutée à `COLUMNS`) : 6 tuiles (niveau, durée, monstres, élites,
  gardiens x / 3, boss vaincu / atteint / —), titre gagné en annonce dorée (seulement s'il est nouveau), bloc Gardé (coffres, raison au survol),
  bloc Ton build, ligne « Ta quête » (`Quests.report_line`, sans le conseil « Ensuite »), phrase de bas de page quand rien n'est gagné
  (« Tiens 10 minutes… » / « Récompenses du jour déjà prises. »). Pas de Gagné, pas de Perdu, aucun insigne ni maîtrise.
- **Boutons** : Rejouer (même classe `Run.class_id`, zone, palier, sans lobby), Changer de classe (`Survivor.lobby_request = "class"` : le lobby ouvre
  la page du mode et le menu de classe), Retour au lobby (nom gardé de U9 plutôt que « Menu »).
- **Quêtes** : `Quests.end_run("survivor", …, SurvivorRewards.quest_extra())` : le temps de carte (pauses exclues) remplace le temps réel, donc « Tenir 10
  minutes » compte juste. **Journal** : `sv_time`, `sv_guardians_down`, `sv_rewards` (le plan, la ligne étant fermée avant `settle`).
- **Page du lobby** : section « Coffres d'apparence » (3 lignes : palier, rareté en couleur, ✔ une fois gagné, titre au boss), avant la liste des zones.
- **Apparence du hub pendant la run** : vérifiée (tenue, aura portée, skin d'arme du type : `Profile.weapon_code`) ; rien à changer, ce n'est pas dans `HUB_KEYS`.
- **Hub intact** après victoire, défaite, abandon, fermeture en pleine run : seuls les coffres d'apparence, titres et plafonds changent.

## Retouches hors lot (minimales)
`run.gd` (1 ligne : l'extra des quêtes), `survivor.gd` (`reset` + `lobby_request`), `survivor_director.gd` (1 ligne `track`), `results_panel.gd`
(colonne `build`), `lobby.gd` (section, demande de classe, `_badge`), tests `test_sv1` / `test_sv3` / `test_sv4` (empreinte du hub via
`SurvivorRewards.hub_view`, bilan à 3 boutons), `test_nav_screens` (bilan Survivant : 3 / 3 atteignables).

## Mesures et vérifications
`test_sv6` : 0 échec (plafonds sur 5 jours et 2 paliers, bilans des 3 issues, quêtes, journal, hub intact, parcours réel lobby → monde → mort → bilan →
Rejouer → victoire → Changer de classe). Verts : test_sv1, 2, 3, 4, test_results, test_quests, test_nav_screens, test_journal, test_p13.
Captures regardées (1600×900 et 1280×720) : bilans de victoire, de défaite précoce et de défaite à 15 min, page du lobby.

## Reste / pièges
- Le sélecteur de palier (S8) appellera `SurvivorRewards.board(palier)` ; `Survivor.start` garde déjà `palier`.
- `Survivor.READY` reste faux (S8). Titres : aucun succès lié (cosmétique seulement).
- À 720 px la colonne « Ton build » défile (6 sorts + 8 lignes) : voulu.
- Un compte en mode dev dont une quête du jour est « Survivant » reçoit son coffre en plus de ceux du mode (2 lignes Gardé).
- `Profile.records` fait partie de `HUB_KEYS` : l'état des quêtes tiré pendant la run est remplacé par celui d'avant ; `Quests.end_run` passe après la
  remise et rejoue le tirage (déterministe par date), donc rien ne se perd.
