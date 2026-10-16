# R_AC_A — L'Échiquier, lot AC-A : données (16/10/2026)

## Fait
- `game/scripts/core/autochess_data.gd` (`AutochessData`) : toutes les tables du mode, réglages en tête (or, intérêts, séries,
  XP, taux de boutique niveaux 1 à 11, réserve, vente, dégâts de joueur, étoiles, coûts, mana, durées, déroulé des étapes,
  butin, raretés d'atout, difficultés et tempéraments des IA), 15 traits, 9 composants, 36 objets, 3 objets spéciaux
  (Emblème, Couronne, Marteau de réforge), 30 atouts. **Aucun code d'effet** : chaque trait / objet / atout a `effect`
  (clé) + `params` (ou `tiers` pour les traits) + `trigger` (liste fermée `TRIGGERS`), à appliquer par AC-H.
- `game/data/autochess_units.json` (60 unités), généré par `tools/autochess_units.py` (`--check` : fichier à jour ?) depuis
  `classes.json` + coût, sort signature et rôle de l'annexe A. Toutes les valeurs ont `provisional: true` et `sim_factor: 1.0`.
- Test `test_ac_data` (34 vérifications) ; `test_texts_fr` reste vert (tables parcourues : 171 scripts).

## Décisions
- **Aucun cerveau** (décision du joueur, SPEC révisée 5a0603ac) : aucune clé « cerveau » ni « capitaine ». Les unités ont ce
  que lit l'IA scriptée (SPEC §4.1) : `role` de l'annexe A (tank 9, combattant 15, assassin 3, tireur 12, mage 9, soigneur 7,
  soutien 5), `attack_range_m` (mêlée 3,2 m comme `ClassRival`, sinon cases × 2 + 0,5), `preferred_distance_m`
  (`ROLES[*].distance`), `spell_type` (zone, cible, soin, renfort, déplacement : 49 / 4 / 7 / 0 / 0 pour les signatures
  actuelles). Réglages d'IA nommés par la SPEC : `UNIT_DIFF` (2 = Difficile), `AI_WEIGHTS` par rôle, `AI_*` (focus,
  reciblage, zones, soins, recul, plongée), `BOARD_MARGIN`, `BOARD_SPACING`.
- Atouts du capitaine remplacés comme dans la SPEC révisée : **Chef de guerre** (Or) et **Ordre de bataille** (Éclat).
- Mana = recharge arrondie à la seconde (demi vers le haut) × 10 : 3 unités diffèrent de l'annexe (Danseuse d'épées 90,
  Maître-sabre 110, Kage 90 au lieu de 80 / 100 / 80, l'annexe arrondissait au pair).
- Points non chiffrés par la SPEC (réglages) : XP 10 → 11 = 100, taux du niveau 11 = 2/8/15/40/35, base de dégâts de
  l'étape 1 = 0, monstres de l'étape 1 payent même perdus, évitement à l'appariement 3 / 2 / 1 adversaires (7+ / 5-6 / 4-
  vivants), mélange des IA par difficulté (`DIFFICULTIES[*].mix`).
- Textes : `short` (permanent, sans pourcentage, ≤ 90 signes) et `tip` (infobulle chiffrée) ; icônes de passifs existants
  (`icon` = id de `Boons`, vide si aucun).

## À lire par les autres lots
Voir la liste des fonctions et clés dans l'en-tête de `autochess_data.gd` et dans le message de rendu. Les noms affichés
des unités passent par `AutochessData.unit_name(id)` (nom français de la classe).

## Reste
- Coûts, mana et `sim_factor` à recaler par AC-J ; `tests/ac_mesures.json` n'existe pas encore.
