# R_A1 — Plans de donjon par boss (refonte Aventure, lot A1, 16/10/2026)

Lot A1 de `REFONTE_AVENTURE.md` §5. Fichiers : `core/dungeons.gd`, `ui/fabrication_page.gd`, `core/resource_help.gd` ; retouches
ciblées : `core/compass.gd` (1 ligne, A8), `ui/guide.gd` (fiche « Plans de donjon »), `ui/dungeon_results.gd` (ligne du bilan).

## Fait
- **48 plans, un par boss** (`plan_<boss>` dans `Profile.plans`) : `Dungeons.reward` le donne **à la 1re victoire contre ce boss**
  (toute difficulté), jamais en double ; plus de tirage « une fois sur dix ». Sans boss choisi : celui d'origine de la zone (son
  record `dgb_` est alors compté aussi). API : `plan_id`, `has_plan`, `plans_known`, `plan_total`, `plan_diff`, `plan_source`.
- **Fabrication en insignes** (`FabricationPage.craft(boss, slot)`) : 2 emplacements du boss (`BossLibrary.loot`), sa panoplie,
  arme du type de la classe choisie ; niveau = donjon du boss à la meilleure difficulté finie contre lui ; mythique, légendaire après
  un Mythique. Prix = `Economy.base_price({niveau du donjon, rareté})` : Normal de Monts Calcaires 44, Héroïque de Beluga 65,
  Mythique 260. **Aucun cristal** (ils restent à la Forge). Le plan n'est pas consommé.
- **Migration sans perte** (`Dungeons.migrate_plans`, paresseuse et idempotente, appelée par `reward`, `has_plan`, `plans_known`) :
  `plan_<zone>` → plan du boss d'origine de la zone ; la meilleure difficulté finie dans la zone est gardée dans
  `records.plan_diff_<boss>` (le plan converti fabrique au niveau d'avant) ; plan inconnu gardé tel quel ; `profile.gd` intact.
- **Page** (onglet « Plans de donjon ») : compteur « x / 48 plans », plans trouvés (2 colonnes : emplacement, « Fabriquer · N
  insignes », ce qui manque en rouge), plans des donjons ouverts (3 colonnes : emplacements, « Il tombe en battant <boss>. »), les
  donjons fermés en une ligne (« 35 autres plans dans les donjons encore fermés. »). Captures 1280×720 relues : rien de coupé.
- Textes : `ResourceHelp` (plans, insignes, cristaux), Guide, bilan du donjon (« Plan de donjon · <boss> »), boussole.

## Décisions
- Prix sur le **niveau du donjon** (pas sur le modèle tiré, qui est aléatoire) : le prix affiché est celui payé.
- Les donjons fermés ne font pas 40 fiches grises : une ligne suffit (une idée par écran).
- `FabricationPage.craft` accepte encore un id de zone (→ boss d'origine) pour les vieux appels.

## Tests
`test_a1` (nouveau, 37 vérifications : plan au 1er clear, sans doublon, 48 au bout, migration `plan_limestone` / `plan_delphi`,
idempotence, prix en insignes, 0 cristal, emplacements du boss, légendaire après Mythique, page). Mis à jour : `test_e2`, `test_lot18`,
`test_lot13`, `test_p4_flow`, `test_workshop`. Verts sur une copie de HEAD + ce lot : `test_a1`, `test_m2`, `test_e2`, `test_pages`,
`test_nav_screens`, `test_p4_migration`, `test_workshop`, `test_lot18`, `test_lot13`, `test_lot13b`, `test_loot`, `test_compass`,
`test_results`, `test_p4_flow`, `test_texts_fr`.

## Reste / pièges
- `tools/progression_sim.gd` (lot A7) modélise encore le plan par zone (son drapeau `--refonte` l'approche).
- La page Donjons (A2) pourrait dire « plan : à trouver / trouvé » sur la fiche du boss.
- Noms courts sans article dans « Il tombe en battant Mains de granit. » (données `bosses.json`).
- DESIGN « Atelier » : la puce « Plans de donjon » (hunk en cours du lot A3) est corrigée dans le dossier de travail, à pousser avec A3.
