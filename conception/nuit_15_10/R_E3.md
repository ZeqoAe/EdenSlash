# R_E3 — Profils de classe, meilleur équipement, Registre (lots B1 + B2 de A1, version 0.1.178)

## Fait
- **Profils de stats (B1)** : `tools/gen_class_profiles.py` → `game/data/class_profiles.json` (relu, reproductible). Règle : type de dégâts réel
  (comme `GameData._balance_damage_types`), défense de base 6 = garde, sinon l'attribut de croissance le plus fort parmi ceux qui font les
  dégâts (physique : force / agilité / chance ; magique : intelligence / sagesse). **7 profils** : Puissance 4, Vivacité 9, Précision 9,
  Rempart 10, Croisé 4, Arcane 15, Esprit 9. Poids 0,3 à 1,5 par stat, armure préférée (tissu / cuir / plates) = +0,5 de note.
- `Items.rating(pièce, profil)` et `GearPower.item_power(pièce, profil)` : **sans profil, rien ne change** (PE affichée, seuils des donjons, comparaisons).
  `GearPower.gear_power`, `slot_share`, `set_factor`, `target_level` extraits (hero_power identique).
- **Nouveau `core/class_gear.gd`** : `best_gear` (meilleure pièce par emplacement pour le profil, arme principale du type de la classe, arme
  secondaire libre, puis panoplies essayées par paliers 2 / 4 / 6 et échanges pièce par pièce), `equip_best` (option **garder mes choix** :
  pièces ni de départ ni posées par le dernier « Équiper le meilleur », mémorisé dans `presets[classe].sets[i].auto`), `apply_family`,
  `undo` (une action, par sauvegarde), `menu_actions` (entrées du menu « Gérer »), `entry` / `entries` / `equipped_count` (Registre).
- **Héros > Équipement > Gérer** : « Équiper le meilleur », « …, garder mes choix » (s'il y a des choix), « Appliquer à la famille X · N classes »
  (infobulle : la liste), « Annuler : … ». Point d'entrée U4 : `PresetBar._open_menu` ajoute `ClassGear.menu_actions(_cid)`.
- **Registre (B2)** : `ui/registry_page.gd`, dernier onglet du Carnet (« Équipement » de la Vue d'ensemble y mène). Par classe : PE / attendue
  (meilleur niveau atteint), arme (type, de départ ou manquante), pièces hors départ x / 9, panoplie de donjon x / 6, Esprits x / 6, +10, gemmes x / 18,
  enchantements ; état À commencer / À compléter / À renforcer / Équipée (9 vraies pièces, PE ≥ 70 %) / Optimale ; « Il manque : … → activité »
  (classe verrouillée → sa mission ; jamais choisie → Héros ; arme, pièces, niveau → Survie puis Armurerie ; panoplie → Donjons ou Panthéon ; +10 → Forge ;
  gemmes → la Tour ; enchantements → le Siège ; « (verrouillé) » + condition en infobulle). Filtres Débloquées (défaut) / Toutes / À équiper et
  par profil ; moins équipées d'abord ; un clic ouvre Héros > Équipement sur la classe.
- **Lobby** : « N / 60 classes équipées » dans le pied (visible quand le Carnet est ouvert, un clic ouvre le Registre).

## Décisions
- La note pondérée ne sert qu'aux choix ; la PE reste commune, pour ne pas changer l'équilibrage (seuils des donjons, Siège, butin légendaire).
- « Garder mes choix » sans cadenas à poser : un choix = pièce posée à la main (rien à apprendre, rien à sauvegarder en plus qu'`auto`).
- « Appliquer à la famille » écrit dans le préréglage **actif** des autres classes (annulable), classes verrouillées comprises (prêtes au déblocage) ;
  une classe sans arme de son type au coffre est sautée et comptée dans le message.
- Fichiers d'autres lots évités : `profile.gd` et `completion.gd` non touchés (appels de `_class_presets`, `_sync_vault`, `_lobby_view` depuis ClassGear).

## Mesuré
`test_e3` (nouveau, 50 contrôles : profils, note, 60 classes = 8 pièces valables ou plus et arme de leur type en ≈ 0,2 s, garder mes choix,
famille, annulation, panoplie 6 / 6, états, page) ; `test_nav_screens` (Registre 23 / 23 + lien vers Héros), `test_pages`, `test_lot11`,
`test_gear_run`, `test_e5`, `test_hud`, `test_tooltips`, `test_workshop`, `test_e2`, `test_lot8` verts. Bandeau du lobby : 6 ms pour 60 classes.
Captures regardées : `captures/e3/` (lobby neuf / avancé, Gérer avant / après, messages, Registre neuf / avancé / Toutes / Rempart, Vue d'ensemble).

## Reste / pièges
- Le choix automatique est une heuristique (gloutonne + panoplies par paliers) : pas l'optimum exact quand deux panoplies se croisent.
- Esprits et archétype comptés sur les 9 emplacements ; « Optimale » demande 6 / 6 de l'un des deux, tout à +10, 18 gemmes, 9 enchantements.
- Classes jamais choisies : l'équipement de départ n'est remis qu'au premier choix (`Profile._grant_starter`) ; le Registre le dit.
- Outil de captures : `tests/shot_registry.tscn` (APPDATA détourné).
