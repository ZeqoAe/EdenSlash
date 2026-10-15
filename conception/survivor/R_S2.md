# R_S2 — Survivant, pièces et arme (15/10/2026)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md`, `R_S1.md`, `PLAN_NUIT.md`, `CLAUDE.md`.

## Fait
- **Pool** (`core/survivor_pool.gd`) : le catalogue n'a que **13 sets de niveau 90**, tous de 5 pièces (tête, torse, jambes,
  gants, bottes), 5 en plates, 5 en cuir, 3 en tissu ; 12-13 variantes visuelles par emplacement. Cape, collier et bague
  n'ont aucun set à 90 : ils prennent les pièces de niveau 90 hors set, mythiques et légendaires (12 / 18 / 12). Armes : les 17
  types, modèles de niveau 90 (6 à 15 par type). Type d'armure de la classe (`ClassGear.profile().armor`) proposé ×2.
- **Stats d'origine** (`SurvivorGear.from_eden`) : `Items.from_template` à la rareté d'Eden, sans affixe ni passif d'Eden ;
  puissance = niveau du héros (crochet S1 de `Items.power_level`) ; qualité 100 à 120 % par pas de 1 % (jet parfait 120 % ≈ 1
  pièce sur 21), seule part aléatoire.
- **Passifs** : `Cards.PASSIVE_EFFECTS` (38 effets des cartes communes, ordre fixe ; ni Rappel, ni Canon de verre, ni
  évolutions, ni sauts) et `Cards.effect_line`. Pièce = `sv_passives` [{id, at, power}] ; posés dans `Run.passives` /
  `Run.passive_power` (cumul entre pièces, plafond `boon_cap` : max, ou 1,5 × max). Affichés par `Items.describe`.
- **Passifs de palier** : `upgrade_offer(slot, tier, rng, step)` tire le passif de chaque palier +6 / +8 / +10 franchi
  (`roll_tier_passive(piece, tier, rng, exclude)`, jamais un passif de la pièce) et le garde dans l'offre ; `apply_upgrade`
  l'applique (offre périmée refusée). Puissance = `passive_power` × rareté de la carte. Arme : l'offre porte aussi
  l'amélioration d'auto-attaque (`auto`), le rang suit le +N (effet légendaire à +4).
- **Verrou à vie** : `SurvivorGear.equip` refuse un emplacement pris ; `Profile.equip` / `unequip` / `equip_offhand` /
  `swap_weapons` refusent (`locked`) ; page d'inventaire de la pause : bouton « Gardée toute la run » grisé, dépôt refusé.
- **Armes** : `make_weapon(wtype)` (variante d'auto-attaque au hasard), `weapon_offers(3)` (3 types différents, type de la
  classe ×2, même nature de dégâts ×1,5) pour la 1re carte de S3.
- **Stats du héros** : rien à changer, `Profile.equipped` EST l'équipement de la run (S1) ; bonus de set via `Items.set_def`.

## Table des passifs fixes (déterministe : famille du set, rang du set dans sa famille, emplacement)
Pièce j (tête, torse, jambes, gants, bottes) du r-ième set de la famille = `FAMILY_PASSIVES[famille][(5r + j) mod 12]` :
5 effets consécutifs, donc jamais de doublon dans un set (vérifié sur les 13 sets).

| Set | Armure | Famille | Tête, torse, jambes, gants, bottes |
|---|---|---|---|
| e340 Chevalier de l'Aile d'acier | plates | Assaut | Fil aiguisé, Force brute, Tueur de géants, Main lourde, Fil tranchant |
| e342 Seigneur de guerre puissant | plates | Assaut | Transe guerrière, Onde de choc, Cadavres explosifs, Exécuteur, Peau de fer |
| e344 Pillard mystique | plates | Assaut | Corps aguerri, Soif de sang, Fil aiguisé, Force brute, Tueur de géants |
| e346 Croissant buriné | cuir | Assaut | Main lourde, Fil tranchant, Transe guerrière, Onde de choc, Cadavres explosifs |
| e348 Sceau de la Destruction | cuir | Sortilège | Arcanes, Incantation vive, Lame large, Lame statique, Fil de givre |
| e350 Argent lunaire supérieur | cuir | Vivacité | Cadence, Précision, Lame du vent, Œil du chasseur, Pas du vent |
| e352 Festin du Fantôme | cuir | Sortilège | Écho, Plaies profondes, Venin tenace, Concentration, Cœur d'hiver |
| e354 Éveil spirituel | cuir | Grâce | Corps aguerri, Peau de fer, Second souffle, Concentration, Cœur d'hiver |
| e356 Profanation déchaînée | tissu | Sortilège | Élan meurtrier, Braise, Arcanes, Incantation vive, Lame large |
| e358 Asile sacré | tissu | Grâce | Aimant, Érudit, Bonne étoile, Pas du vent, Soif de sang |
| e360 Malédiction fracassée | tissu | Sortilège | Lame statique, Fil de givre, Écho, Plaies profondes, Venin tenace |
| e447 Gardien resplendissant | plates | Vivacité | Pas léger, Projectile supplémentaire, Perforation, Ricochet, Allonge |
| e448 Courroux de l'Océan | plates | Sortilège | Concentration, Cœur d'hiver, Élan meurtrier, Braise, Arcanes |

Cape / collier / bague : `SLOT_PASSIVES[emplacement][rang du modèle]` ; armes : `WEAPON_PASSIVES[rang + 3 × rang du type]`
(effets d'auto-attaque). Imprimé par `test_sv2`.

## Règle des bonus de set (Survivant seulement ; ailleurs les paliers d'Eden)
Famille = attribut dominant des 5 pièces (Force 4 sets, Intelligence 5, Agilité 2, Sagesse 2).
- **2 pièces** : Assaut +6 % d'attaque · Vivacité +8 % de vitesse d'attaque · Sortilège +8 % d'attaque magique · Grâce +8 % de PV.
- **3 pièces** : les deux stats propres au set (`SIG_VALUES` : +4 % critique, +6 % vitesse d'attaque, +5 % recharge, +3 %
  esquive, +15 % dégâts critiques…).
- **5 pièces** : Assaut +15 % de dégâts et explosion d'auto-attaque (30 %, 250 %, 5 m) ; Vivacité +12 % de vitesse d'attaque
  et foudre sur critique (50 %, 5 rebonds) ; Sortilège +20 % de zone et écho de compétence (35 %, 80 %) ; Grâce +15 % de PV,
  +20 % de soins, barrière et 10 % de PV quand touché (10 s) ; + stat du type d'armure (plates +10 % défense, cuir +6 %
  vitesse, tissu +6 % recharge). `SurvivorPool.SIGNATURE` (vide) permet d'écrire un set à la main.

## Fréquence du 5/5 (`tools/sv_set_sim.tscn`, 3 000 à 5 000 runs par cas)
Modèle tiré du SPEC (37 montées de niveau, 8 coffres d'emplacement ouverts, 3 gardiens). Sans freinage, un joueur qui cherche
un set l'avait **1 run sur 2** (il laisse les emplacements vides et voit ~9 pièces par emplacement). Réglage retenu (profil
`survivor`) : `armor_pref` 2, `set_damp` 0,3 dès `set_damp_from` 3 pièces portées, jamais deux pièces du même set dans une
offre. Résultat : **chercheur 1 run sur 23 à 29** (tissu 1/23, plates 1/27, cuir 1/29), suiveur (vise le set de sa 1re
pièce) 1/18 à 1/27, 4/5 ou plus ≈ 27-33 %, preneur (sans chercher) 0 %. 3/5 reste l'objectif courant.

## Tests
`test_sv2` (vert) : pool, stats d'origine, qualité, jet parfait, passifs fixes sans doublon, 120 pièces menées à +10 (4 passifs
distincts, celui affiché = celui appliqué), offre périmée, cumul et plafond, verrou (API, Profile, inventaire), bonus 2/3/5 actifs
au bon nombre de pièces et dans les stats, 17 armes (modèle visible, auto-attaque à +4), 5/5 entre 1/60 et 1/12, hub intact.
Non-régression : voir STATUT.

## Pièges
- Ne jamais nommer une méthode statique `set_name` (ni autre méthode de `Resource`) : `SurvivorPool.set_name(...)` appelait
  `Resource.set_name` de la classe et renvoyait null. D'où `panoply_name`.
- Deux sets n'ont pas de nom (« Panoplie 447 / 448 ») : nom = fin commune des noms de leurs pièces.
- Le pool suit le catalogue : un set de niveau 90 ajouté entre dans le pool tout seul, mais décale la table des passifs fixes
  de sa famille (rang du set). `Cards.PASSIVE_EFFECTS` : ajouter à la fin.
- Le simulateur dépend des hypothèses de cartes de S3 (poids du SPEC) : à relancer quand S3 / S7 auront de vraies mesures.
- Ouvert pour S3 : step des cartes légendaires (+4 : `upgrade_offer(..., 4)` gère deux paliers d'un coup), bannissement de
  set (`ctx.banned`), relance = nouvelle `upgrade_offer`. Pour S5 : `passive_lines`, `LOCK_TEXT`, `is_perfect`.
