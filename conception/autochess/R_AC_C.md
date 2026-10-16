# R_AC_C — L'Échiquier, lot AC-C : le simulateur de combats de données (17/10/2026)

## Fait
- `game/scripts/core/autochess_sim.gd` (`AutochessSim`) : combat **déterministe sans scène** (aucun nœud, aucune physique).
  Unités sur le plan du plateau en coordonnées continues (mètres, celles de la couche : `AutochessEffects.cell_pos`, bornes
  du plateau moins 0,5 m), pas de 0,1 s : déplacement (course × stat « move »), allonge (`stat("reach")`), ciblage simple
  par rôle (score de `ClassRival` en équipe : distance + part de PV × 16, inertie ; assassin : l'arrière-ligne d'abord ;
  soigneur et soutien : le plus proche), auto-attaque à l'impact (élan, fin coupée ou non comme `cfg.cancel`, 1 / vitesse
  d'attaque), sort à mana pleine selon sa forme (comme `AutochessUnit._begin_action` : cercle visé, trait, cercle autour de
  soi, cône ; zone qui attend 1,5 s sa cible ; soin du plus bas après 2 s au plus ; élan des `dash`), ★3 enchaîné à 60 %,
  sauts des Ombre (`leap`), relances d'Arcane (`recast`), esquive des zones (chance calée), Fureur à 30 s et égalité à 45 s.
  **Même couche d'effets** (`AutochessEffects` : PV, mana, défense, traits, objets, atouts, plafond de 20 %) et **même
  fiche de base** (`AutochessDirector.base_sheet`) que le vrai combat ; la couche avance tous les 3 pas (0,3 s).
- Entrées : `AutochessSim.fight(plateau_a, plateau_b, ctx)` = combat injecté d'AC-B (`partie.fight = AutochessSim.fight`,
  rend `winner`, `stars`, `duration`, `gold`, `mode` « sim ») ; `AutochessSim.run(ctx_effets, t, fin, opts)` = même
  signature que `AutochessDirector.data_run` (repli des plateaux cachés : finir un combat commencé, positions du moment) ;
  `make_context` (fiche + `sim_factor`) ; réglages `AutochessSim.TUNE`.
- Outil `tools/autochess_fight.tscn` (Godot headless, `--fixed-fps 60` : le vrai combat va aussi vite que la machine au pas
  de 1/60 s du jeu) : un combat en ligne de commande (`--a=warrior:2,knight --b=hunter:3,mage`, vrai contre simulé),
  calage (`--calib`), relecture et grille de réglages (`--compare`, `--tune`, `--sweep`, `--grid`), écart par unité
  (`--units`), cadence (`--bench`). Mode d'emploi en tête du fichier.
- Test `test_ac_sim` (≈ 80 s ; `AC_SIM_QUICK=1` : sans les vrais combats, ≈ 25 s).

## Chiffres (headless, squelette d'IA d'AC-E, `dmg_scale` 0,10)
| Mesure | Résultat |
|---|---|
| Accord sur 100 compositions au hasard (3-8 unités, coûts, étoiles, objets), 2 jeux de 100 | même vainqueur **88-96 %** (cible 85 %) ; durée médiane vrai 22,2 / simulé 22,8 s (écart **1-3 %**, cible 20 %) ; survivants ±0,4-0,55 (cible 1,5) |
| Bruit du vrai combat (mêmes 100 combats rejoués en vrai) | même vainqueur 93 %, survivants ±0,36 : le simulateur est au plafond de ce qu'on peut prévoir |
| Rythmes (vrai / simulé, par unité et par seconde debout) | auto-attaques 0,54 / 0,54 ; sorts 0,056 / 0,056 ; touches par sort 0,60 / 0,63 |
| Par unité (dégâts par seconde debout, vrai / simulé) | 55 unités sur 56 à moins de 25 % (la dernière : 8 combats seulement) : aucun `sim_factor` nécessaire, tous à 1 |
| Cadence (5 contre 5, coûts 1-4) | **2 200-3 500 combats par minute** selon la charge de la machine (17-27 ms par combat ; dont ≈ 60 % dans la couche d'effets) |
| 50 combats d'équipes types (plongeurs, tireurs, mur, sorts, soins) | médiane **29,7 s**, 2 égalités |
| Partie d'AC-B entière (8 stratèges au hasard) au simulateur | ≈ 133 combats en 4-6 s |
| Traits (miroir, avec / sans le trait au palier haut, 8 graines) | 13 nettement en faveur ; **Arcane ≈ 0** et Ombre +0,08 (voir « Pour AC-U / AC-J ») |

## Recaler (quand l'IA d'AC-U ou un réglage change le vrai combat)
1. `Godot --headless --path game res://tools/autochess_fight.tscn --fixed-fps 60 -- --calib --n=100 --seed=1 --save=user://calib1.json`
   (≈ 2 min ; refaire avec `--seed=2` pour un jeu de contrôle). La ligne `[ac_calib]` donne l'accord et les rythmes.
2. Si l'accord tombe sous 85 % ou la durée s'écarte de plus de 20 % : `-- --compare=user://calib1.json --sweep
   "--grid=auto_lock:1.5/1.8/2.1;zone_dodge:0.5/0.7;move_fudge:0.7/0.85"` (rejoue au simulateur les combats vrais
   enregistrés, sans les rejouer en vrai) ; garder la meilleure ligne `[ac_sweep]`, la vérifier sur le jeu de contrôle,
   la reporter dans `AutochessSim.TUNE`. Lire les rythmes : auto-attaques → `auto_lock` / `auto_hit` ; touches par sort →
   `zone_dodge` ; durée → `move_fudge`, puis les deux premiers.
3. Écart d'une unité seule : `--compare=… --units` (lignes `[ac_units]`, facteur conseillé) ; le mettre dans
   le champ `sim_factor` de `data/autochess_units.json` (× attaque et sort de l'unité dans le simulateur seulement ;
   `tools/autochess_units.py` l'écrit à 1,0 pour toutes : y ajouter une table par unité, puis régénérer).
4. Si AC-U change le ciblage ou les sorts en profondeur (focus d'équipe, zone sur le plus grand groupe, recul des tireurs),
   reproduire la règle dans `_pick_target` / `_wants_cast` / `_aim` (les constantes `AutochessData.AI_*` sont déjà lues
   pour les attentes) avant de régler TUNE. `test_ac_sim` garde un garde-fou court (20 combats, ≥ 75 %, durée ≤ 25 %).

## Décisions
- Coordonnées continues plutôt qu'une grille de cases : les positions de la couche (`set_pos`) servent aux zones, rebonds et
  explosions, et un repli peut reprendre les positions du vrai combat telles quelles.
- Pas de collisions entre unités ni d'esquive par bond : une chance d'esquiver chaque zone (0,7 : l'IA lit 70 % des
  annonces et a 2 charges) suffit à l'accord. Les auto-attaques ne s'esquivent que par la stat « dodge » de la couche.
- Hasard propre au moteur (`seed` du combat × 7919 + 104729), distinct de `ctx.rng` (celui de la couche) : même graine et
  mêmes plateaux = même combat, à l'unité près (testé : vainqueur, durée, PV et positions).
- La couche avance tous les 3 pas (0,3 s) : même accord, cadence × 1,4 (impulsions de 0,5 s toutes jouées).

## Pour AC-U / AC-J (mesuré en passant)
- **Les sorts pèsent peu** dans le vrai combat actuel : un sort toutes les ≈ 18 s par unité, 0,6 ennemi touché par sort (les
  zones sont esquivées), et le plafond de 20 % des PV par coup coupe les gros sorts. D'où **Arcane** (puissance des sorts)
  presque neutre ; les objets de puissance des sorts le sont sans doute aussi (à mesurer par AC-J).
- Vitesse d'attaque : dans le vrai combat, l'animation du coup (≈ 1,8 s quand elle n'est pas coupée) borne le rythme ; les
  bonus de vitesse d'attaque ne comptent qu'à moitié (coups coupés). AC-U : accélérer l'animation avec `stat("as")`, puis
  recaler `auto_lock`.
- Branchement du repli : `AutochessDirector.finish_by_data` / `data_fight` peuvent appeler `AutochessSim.run` /
  `AutochessSim.fight` (même signature que `data_run` / `data_fight`) : une ligne chacun dans le fichier d'AC-E.
