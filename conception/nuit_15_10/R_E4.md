# R_E4 — capes, types d'arme, fournitures de la Survie (lot E4, version 0.1.179)

Lots A6 + B3 + A1(b) de `A1_progression.md` §5.4 (problèmes I1, I2, I7, « pas de pièce dos »). Test : `tests/test_e4.tscn` (23 vérifications).

## Fait

- **Capes (A6)** : coffre `back` (« Coffre de cape ») dans `SlotChests.BOXES` ; 2 coffres par carte, pris aux gants (3 → 2) et aux
  bottes (3 → 2) : toujours 30 coffres, 4 de trophée. Une cape existe sur les 12 cartes (mythique 33-58, légendaire 60-75 ; pas de cape
  « éveillée » dans les données : la carte éveillée donne une légendaire). L'enclume vise aussi la cape (`Run.ANVIL_SLOTS`). L'Armurerie les
  vend comme le reste (`seen_gear`, compteur `Completion.armory_total` calculé). Compte neuf : toujours 8 pièces, sans cape (choix de N1 gardé :
  la cape est une trouvaille).
- **Enclume à 9 emplacements** : le choix montrait 8 cartes de 320 px dans une fenêtre de 1 600 px (cartes 5 à 8 hors de l'écran, bug
  déjà présent, vu sur capture). Elle montre maintenant **3 emplacements**, les plus utiles d'abord (pièce portée, +N total le plus bas,
  arme en tête), la relance passe aux 3 suivants en boucle (`RunDirector.ANVIL_PAGE`) ; titre raccourci à « Enclume : choisis un emplacement ».
- **Types d'arme (B3, décision)** : recommandation (ii) retenue. **Une arme choisie en Survie** (coffre d'arme ou arme secondaire) fait
  découvrir les armes **de tous les types** au palier et à la rareté de la carte (`SlotChests.weapon_family`, `Run.seen_family`, versé dans
  `Profile.seen_gear` en fin de run, même perdue). Pourquoi : la Survie garde son rôle de découverte, aucun coffre ni monnaie nouveaux, et une
  classe d'épée peut s'équiper d'une épée découverte en jouant un Guerrier (vérifié : `_main_weapon_ok`), toute classe d'une arme
  secondaire de n'importe quel type. Les 17 types ont des pièces (la faux-fusil aussi, aux raretés mythique et légendaire) ; chaque type a une
  arme mythique et une légendaire à découvrir. 35 armes découvertes par arme choisie à l'époque I (15 types), 17 types ensuite.
- **Tirage des coffres corrigé** : une pièce prise « en dessous du palier » l'est à 20 niveaux au plus (`SlotChests.POOL_WINDOW`), sinon la
  plus basse au-dessus : plus de **légendaire de niveau 1** (Ragnarok, Penthos…) proposée au palier 60. La famille d'armes ne découvre pas une
  pièce à plus de 20 niveaux du palier (elle viendra à son époque). L'arme secondaire est tirée comme un coffre d'arme de son type.
- **Fournitures (A1 b)** : `RunDirector.supply_level` = niveau des pièces de la carte d'époque (max armure / arme) pour les parchemins de
  fortification (objets cassés, coffres, élites, marchand), les formules (autel du scribe, objets) et les coffres de forge ; plus de plafond
  à 35. Parchemins par carte : 30 / 40 / 50, 50 / 60 / 60, 70 / 70 / 80, 80 / 90 / 90 (test : chaque pièce de l'Armurerie au palier de son
  époque ou en dessous a son parchemin dans la même époque). **Gemmes** : niveau du moment + 8 par époque (`GEM_EPOCH_LEVELS`, un rang de
  plus par époque), coffres du joaillier aussi : les royales restent rares avant l'époque IV. Hors Survie : inchangé.
- Retouches minimales d'autres lots : `ui/merchant_ui.gd` (2 lignes, `supply_level` / `gem_level`, déjà emportées par le commit de U5),
  `core/world.gd` (une ligne `[fournitures]` sous `--auto-quit`), `core/craft.gd` (paramètre `gem_level` de `loot_for` / `random_loot`),
  `core/starter_gear.gd` (`--hub E.C.N.G` avec cape, `.0` final : sans). `tools/sim_survie.py` : résumé des fournitures, `--seed-base`, `--extra`.

## Mesures (`tools/sim_survie.py`, 5 classes de départ, coups évités 0,5, boss après 6 min)

| Époque I, compte neuf | Survit ≥ 7 min | Boss atteint |
|---|---|---|
| Avec capes (2 séries, 30 runs) | **70 % (21 / 30 : 80 % puis 60 %)** | 6 / 30 |
| Sans capes (`--extra=--no-cape`, 2 séries, 30 runs) | **60 % (18 / 30 : 60 % et 60 %)** | 7 / 30 |
| N1 (référence, 15 runs) | 60 % | 27 % |

Lecture : les capes ajoutent peut-être quelques points (la 9e pièce comble un emplacement vide du compte neuf), dans le bruit
de la mesure (± 9 points sur 30 runs) ; le début reste punitif comme N1 l'a réglé, aucun réglage pris. PE : une cape = +11 à +14 % de la PE d'un équipement optimisé de l'époque II (1/9 des emplacements).

Fournitures trouvées par carte 1 (sac de la run, gardé sur victoire ou extraction ; coffres de forge et du joaillier toujours gardés) :

| | Parchemins | Formules | Gemmes | Coffres gardés |
|---|---|---|---|---|
| Époque I (12 runs) | Lv30 ×7,7 | Lv1 ×0,8 | rangs 1-3 ×4,8 | forge Lv23 ×1,2, joaillier ×0,8 |
| Époque II (4 runs) | Lv50 ×4,5 | Lv3-4 ×4 | rangs 2-4 ×4,5 | forge Lv48 ×1,5, joaillier ×1,4 |
| Époque IV (1 run de 12 min) | Lv80 ×19 | Lv8-9 ×11 | royales ×14 | forge Lv80 ×5, joaillier ×8 |

Une pièce à +10 consomme une douzaine de parchemins (R_E1) : une victoire d'époque (3 cartes) en donne 30 à 45 au bon niveau, de quoi monter
2 à 3 pièces de l'Armurerie de cette époque (les cristaux restent la limite, lot E1). La difficulté de la run n'en dépend pas : la forge est fermée
pendant la Survie (`inventory_page._on_upgrade`), les fournitures ne servent qu'au hub. Les époques III-IV avec un équipement optimisé de
leur époque : boss battu 5 / 5 (III), 2 / 5 (IV) ; non comparé à l'avant (pas d'effet du lot en run hors capes).

## Reste / pièges

- **Formules en époque IV** : ≈ 10 formules Lv8-9 par carte longue (rage) : généreux face au Siège (« formules hautes », lot E1). À regarder
  dans la passe E6 (part de la famille « scroll » de `Craft.LOOT_SOURCES` en Survie, ou formules au niveau de l'armure − 1).
- Une arme de type sans pièce à son palier est prise au-dessus (ex. 5 types à l'époque II : mythique 65) : achetable à l'époque II, ses
  parchemins (Lv70) viennent de l'époque III.
- La relance de l'enclume dit « Relancer (4) » : pour l'enclume, « Autres emplacements » serait plus juste (bouton du `CardPicker`, lot U3).
- L'Armurerie va grossir vite (35 armes par arme choisie) : les filtres du catalogue (U5 : emplacement, époque, classe) sont indispensables.
- `--no-cape` (option de mesure, `SlotChests.layout`) remet 3 gants et 3 bottes.
- Capture : `godot --path game res://tests/shot_anvil.tscn` (`user://shots/anvil_*.png`).
