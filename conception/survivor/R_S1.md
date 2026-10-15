# R_S1 — Survivant, socle et crochets (15/10/2026, version 0.1.194)

Lu : `SPEC.md` (entier), `DECISIONS_JOUEUR.md` (prime), `PLAN_NUIT.md`, `CLAUDE.md`.

## Fait
- **`core/survivor.gd`** (`Survivor`) : constantes du SPEC §11.1, état (`active`, `zone_id`, `palier`, `bans_used`, `picks`,
  `since`), `start(cid, zone, palier)`, `finish`, `reset`, `owns` / `apply_card`, `weapon_type`, `fallback_anim`, `xp_mult`,
  `level_cap`, `station_count`, `shrine_reward`, `rule` (profil `survivor`), `visible`, `zones` (les 8 décors de la Survie).
- **Squelettes** : `survivor_pool.gd` (S2), `survivor_gear.gd` (S2, `equip` / `free_slots` / `worn` déjà réels),
  `survivor_cards.gd` (S3, `handles()` = faux), `survivor_director.gd` (S4), `survivor_rewards.gd` (S6). Pas de squelette
  d'interface (S5 crée ses fichiers).
- **Socle des modes** : `Modes.current() == "survivor"` (pendant la run) ; profil `SURVIVOR` de `ModeRules` (cartes, qualité
  100-120 %, expérience, monstres, gardiens, boss 1 500 000, rage du boss à 240 s, paliers ; aucune clé de gains de progression) ;
  `Modifiers` documenté (s'applique aux clés du profil sans code).
- **Activité** « Survivant » (rangée Aventure, 2e), sans verrou, gains « apparences, titres », cachée hors mode dev tant que
  `Survivor.READY` est faux (`Activities.hidden`) ; page du lobby `_menu_survivor` (une phrase, 8 zones avec leur boss,
  « Lancer le Survivant » épinglé) et `_start_survivor`. `world.tscn -- --survivor [--palier=N] [--sv-zone=id]`.
- **Lancement** : héros niveau 1 (pas de bonus de niveau de zone), ni arme ni pièce, sac = potions de départ seulement, réserve
  laissée au hub, époque I carte 1 pour les règles communes ; choix de départ = première compétence (S3 : compétence ou arme).
- **Hub jamais modifié** (DECISIONS §5) : équipement copié / remis comme la Survie (`begin_run` / `end_run_survival`), et en plus
  les 30 propriétés de progression (`Survivor.HUB_KEYS` : records, coffres, insignes, cristaux, réserve, maîtrise, runs, succès…)
  photographiées au lancement, **écrites telles quelles par toute sauvegarde faite en pleine run** (`Survivor.hub_save` dans
  `Profile.save_profile` : une fermeture du jeu ne garde rien) et remises par `Run.finish` (branche `survivor` : ni maîtrise,
  ni insignes, ni records, ni `runs_done`), le sac vidé, puis `SurvivorRewards.settle` (S6).
- **Bilan** : `ResultsScreen.survivor_spec` (minimum : niveau, durée, monstres, élites ; Rejouer = même zone, même palier).
- **Journal de run** : `mode = "survivor"` (aussi pour la dernière carte, close après `Run.active`), + `SurvivorRewards.journal()`.
- **Tutoriel** : aucune fiche ; Premiers pas et fiches de la Survie coupés en Survivant (`Hud._survival_mode`, `Tutorial` lit
  `Modes.current() == "survival"`).

## Crochets posés (tous ceux du SPEC §11.2 ; S2-S4 ne touchent que leurs fichiers)
- `run.gd` : `Survivor.reset()` dans `start` ; `roll_cards`, `ban_card`, `rerolls_left` → `SurvivorCards` si `handles()` ;
  `apply_card` → `Survivor.apply_card` pour les cartes `sv_…` ; `weapon_type` ; `finish`.
- `run_director.gd` (`var sv: SurvivorDirector`) : création, message d'ouverture, `update`, pas de rage de carte,
  `update_spawns`, `objective_text`, `time_left` (20:00), `monster_level`, `max_level`, `scale_monster` (remplace zone /
  époque / montée du début), `on_monster_died` (après l'or), `try_enter_boss`, `open_chest`, `use_station`, `capture`,
  `setup_boss`, `boss_rage_at` (`_boss_rage_start`), `on_boss_killed` (**déjà actif** : une seule carte, victoire 6 s après),
  `next_zone_id` = "" , titre de zone sans « étape ».
  **Convention** : une méthode qui remplace un comportement de la Survie renvoie `true` si elle l'a pris en charge, `0` / `""` /
  `-1` pour « comme en Survie ».
- `player.gd` : `_weapon_type_id`, `recalc_stats` (ni archive ni aura), `gain_xp` (`xp_mult`, `level_cap`), `_start_attack`
  (repli d'animation). `items.gd` : `power_level` (`sv` = niveau du héros, 90 au plus). `proc_map.gd` : `layout_map` (coffres),
  `station_count` (ni scribe ni fortune), `shrine_reward` (trophée → carte). `merchant_ui.gd` : pas de fournitures.
  `card_picker.gd` : `auto_pick` → `SurvivorCards` si `handles()`. `world.gd` : `--survivor`, `start_offers`.

## Décision prise : `Run.survival` reste VRAI en Survivant
Contrairement à l'hypothèse du SPEC §9 (« ajouter `or Survivor.active` partout »), le Survivant garde `Run.survival` comme le
Battle royale : tout le socle de la Survie (carte d'époque, coffres d'emplacement, plafonds, pas de butin d'équipement des
monstres, marchand sans équipement, forge fermée en run) marche sans retouche, et chaque écart passe par un crochet.
Audit des `Run.survival` (grep) : `proc_map` 281 (crochet), `player` 403/407 (crochets), `craft` 232/353, `items` 858,
`profile` 1330, `item_widgets` 356, `inventory_page` 794/1013 (forge fermée, enclume de la Survie : sans effet tant que S4
n'utilise pas `slot_bonus`), `hud` 317 (exclut le Survivant) / 413 / 461 (rage du boss : voulue), `merchant_ui` 177 (+ filtre),
`results_screen` (branche propre), `run.gd` `finish` (branche propre, avant les blocs Survie) / `discover_weapons` / `apply_card`
« gear » (remplacé par S4 via `open_chest`), `run_director` 179 / 472-510 / 651-654 / 775 / 809 / 838 / 900 / 924-943 /
1031-1077 / 1538 (tous couverts par un crochet `sv`), `run_journal` 152 (époque 1), `tutorial` (exclu par le mode).

## Tests
`test_sv1` (62 vérifications, 0 échec) : activité (rangée, sans verrou, cachée hors mode dev), lancement nu, règles, arme,
puissance des pièces, lieux, sauvegarde en pleine run puis rechargement, victoire / défaite / abandon (hub identique : coffre,
préréglages, loadout et les 30 propriétés, comparés comme sur le disque), journal, Survie et Royale ensuite ; parcours réel
lobby → page → monde → choix de départ → défaite → Rejouer → boss vaincu → bilan → lobby → Survie. Capture de la page du
lobby regardée (rien de coupé). Non-régression, tous verts (test_farm, test_gear_run, test_progress, test_p12, test_e6, test_lot17, test_results, test_journal, test_compass,
test_lot10, test_e5, test_cards, test_build, test_hud, test_controls, test_nav_screens (page ajoutée), test_p13, test_royale,
test_lot13, test_lot18, test_p4_activities, test_tooltips, test_pages). Hors de ce lot : `test_lot9` échoue sur « news mène
à la dernière nouveauté (équipement du hub) » (la dernière fiche n'est plus `hub_gear` depuis P12 ; rien à voir avec le
Survivant) ; `test_nav_screens` a échoué 2 fois sur 4 sur « Registre : une classe ouvre Héros > Équipement » (instable, vert
ensuite sans changement).

## Pièges pour S2-S8
- `Survivor.active` retombe dans `Run.finish` ; après la run (bilan, Rejouer, journal) lire **`Run.survivor`**.
- Tout ce qui est écrit dans `HUB_KEYS` pendant la run est **effacé** à la fin : S6 donne ses récompenses dans
  `SurvivorRewards.settle` (appelé après la remise) ; un nouveau `Profile.survivor` (Codex…) n'est pas dans `HUB_KEYS`.
- Les records (`Profile.records`) bougent en mémoire pendant la run puis sont remis : `Cards.card_unlocked` les lit en direct.
- Ouvert pour S2/S3 (DECISIONS §5 « aucun lien avec la progression ») : les **talents de classe, certificats posés** et
  `Progression.skill_unlocked` (sorts ouverts par la maîtrise) s'appliquent encore ; le SPEC §7.2 les gardait, les décisions
  du joueur penchent pour les retirer (tous les sorts de la classe, ni talents ni certificats). À trancher en S3.
- Plafond de niveau : S1 garde celui de la Survie (`Survivor.level_cap`) tant que les monstres n'ont pas leur courbe ; S4 le lève
  avec `SurvivorDirector.max_level` / `monster_level`.
- La relance / « Garder » / « Bannir » restent ceux de la Survie tant que `SurvivorCards.handles()` est faux.
- HUD (S5) : l'horloge compte 20:00 (`time_left`) mais le panneau d'objectifs garde les lignes de la Survie (sceaux,
  « Rage dans … ») ; la ligne d'objectif n'a plus « avant la rage » en Survivant.
- `test_p4_activities` n'a pas d'entrée Survivant (fichier partagé) : `test_sv1` fait le même parcours.
