# R_H3 — Porter selon le niveau de héros (lot H3 de `NIVEAU_HEROS.md`)

## Fait
- **Règle** : `Items.required_level(item)` = niveau affiché de la pièce (niveau d'Eden, sinon celui de sa création, plafond 90) ;
  0 pour les pièces de départ (`starter`), du Survivant et du Battle royale (`sv`), les trophées. `HeroLevel.wear_block(item)` =
  niveau requis si > niveau de héros, sinon 0 (jamais pendant une partie ni en mode scellé, `Modes.sealed()` du lot H2) ; `lock_text` (« Niveau 60 requis · tu es niveau 34 »), `lock_line` (ligne de carte,
  variante « Déjà portée : elle reste. » pour une pièce portée).
- **Où c'est vérifié** (hub, d'où part l'équipement de l'Aventure, des Donjons, de la Tour, de la Ruée, du Siège et du Duel équipé /
  Arènes / Gantelet) : `Profile.equip` / `equip_offhand` (renvoient `false` si refusé ; `force` pour l'outil de build du mode dev,
  `RivalBuilds.apply_to_hero`) ; `ClassGear.best_gear` (« Équiper le meilleur », boussole) : seulement des pièces portables + celles
  que la classe porte déjà ; `best_weapon` et `family_plan` (« Appliquer à la famille » : une pièce trop haute n'est pas copiée, la
  classe garde la sienne, message « Pièces au-dessus de ton niveau laissées de côté. ») ; arme par défaut / `select_weapon_type` /
  `end_run` (`Profile._auto_ok`).
- **Interface** : `ItemSlot.wear_check` (fond rouge sombre, icône éteinte, niveau requis en rouge ; pas de ▲) dans l'inventaire, la
  poupée, Fabriquer, les coffres du hub ; fiche de l'inventaire : « Niv. 60 · tu es niveau 34 » en rouge (orange si portée), bouton
  « Niveau 60 requis » désactivé, refus au double-clic / glisser avec le message court ; retirer une pièce portée trop haute demande
  une confirmation (« Tu ne pourras la remettre qu'au niveau 60. ») ; carte d'objet (infobulle) avec la ligne ; Fabriquer : permis,
  « À porter au niveau 53 · tu es niveau 34 » sous le bouton, filtre « Portables » (ajouté en fin de liste : index des autres inchangés) ;
  Registre : « N pièces au-dessus de ton niveau de héros (gardées) » dans l'infobulle du compteur Pièces (`ClassGear.entry().over`).
- Test `test_h3` (≈ 45 vérifications) ; captures `tests/shot_h3.tscn` (1280 × 720, regardées).

## Décisions
- **Trouvailles de la Survie non bloquées** pendant la run : avant H4a, les coffres d'emplacement donnent des pièces 20-43 dès
  l'époque I ; un compte neuf (niveau 1) n'aurait plus rien pu porter en run (« aucun état cassé entre deux lots », §4.2). H4a, qui
  crée ces pièces au niveau du héros, n'aura qu'à retirer `Profile.in_run` de `HeroLevel.wear_block`. Les coffres du **hub**
  (récompenses rapportées des parties) sont signalés en rouge.
- **Pièces portées au-dessus du niveau** (préréglages non actifs d'un compte migré, pièces posées par `install_gear`) : jamais
  retirées ; changer de préréglage les garde ; « Équiper le meilleur » peut les remplacer par mieux, jamais par contrainte.
- **Pas de blocage en mode dev** (sauf l'outil de build) : la règle est la même pour tout le monde.
- Compte pas encore migré (sauvegarde chargée avant `HeroLevel.ensure`) : l'arme par défaut n'est pas filtrée (la migration
  met le niveau au-dessus des pièces portées).

## Reste
- Boussole « Monte au niveau N pour porter … », `Compass.affordable_piece` (peut conseiller de fabriquer une pièce trop haute),
  « manque : niveau » du Registre : lot H6. Coffres de la run : H4a (voir plus haut).
- Outils de capture qui équipent des pièces générées sur un compte neuf : `shot_hero` / `shot_p16` montent le niveau à 90 (tests
  adaptés de même : `test_compass`, `test_e3`, `test_e4`, `test_p16`, `test_pages` ; `test_workshop` : statut « Portables »).
- Vu aux captures, **déjà là avant ce lot** (même image sur HEAD) : à 1280 × 720, une pièce choisie élargit la fiche de
  l'inventaire et la colonne de droite sort de l'écran (onglets « Divers », bouton « Démonter » coupés) : à reprendre (lot U).
- Suite complète verte sauf `test_br2` (plante à la sortie, aussi sur HEAD) et `test_p13` (instable, aussi sur HEAD).

## Pièges
- `Profile.equip` renvoie maintenant un booléen ; un test qui équipe des pièces de niveau > 1 sur un compte neuf doit monter le niveau
  (`Profile.records[HeroLevel.KEY] = HeroLevel.total_for(90)`).
- `Items.generate(niveau)` donne des pièces d'Eden de la tranche de la zone choisie (souvent bien plus basses que le niveau
  demandé) : pour tester un niveau précis, partir d'un modèle d'Eden (`Items.from_template`).
