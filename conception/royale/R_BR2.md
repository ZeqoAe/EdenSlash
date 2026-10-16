# R_BR2 : coffres du Battle royale et décor cassable (retours du joueur, points 3 et 4)

## Fait
- **Coffres** : le « tonneau » était le modèle `m604` (« Coffre secret » d'Eden). Remplacé, dans le Battle royale seulement, par de vrais coffres
  (`uc020` bois et argent, `uc008` acier, `uc007` or ; largage `uc009`), plus grands (×1,7 à ×2,8). Réglages dans `ProcMap.ROYALE_LOOKS`
  (nom, modèle, taille, couleur, hauteur du faisceau, rayon du halo, étincelles), fabrique `ProcMap.make_royale_chest(tier)` utilisée par la carte
  (`_build_chests`), les vagues (`RoyaleDirector._spawn_chest`) et le largage (`_announce_drop`).
- **Aura par qualité** (`Interactable.add_chest_aura`, `make_aura`, `style_label`) : halo au sol qui pulse + anneau net, faisceau qui s'éteint vers le
  haut et scintille, quelques étincelles (CPUParticles3D, 3 à 12 par coffre, visibles à moins de 55 m), nom coloré à moins de 30 m.
  Shaders `shaders/chest_beam.gdshader` et `chest_halo.gdshader` : additifs, sans lumière dynamique (les anciens `OmniLight3D` des coffres
  ouvragés et dorés ne sont plus posés ici). Couleurs : commun blanc bleuté, rare rouge, doré or, largage or clair ; faisceau 14 / 19 / 28 / 60 m.
- **Largage** : un repère (halo + faisceau) au point d'atterrissage dès l'annonce, le coffre tombe sans aura et l'allume en se posant.
- **Mini-carte** : « chest » passe au blanc bleuté (couleur du commun) ; la légende de la grande carte dit « Coffre commun / rare / doré » dans le
  Battle royale (la Survie garde ses noms).
- **Décor** : plus aucune jarre, caisse ni tas d'or au Battle royale (`_put_breakable` les refuse), ni caisses, tonneaux et sacs du décor des lieux
  (`ROYALE_NO_DECOR`). Il reste 19 cristaux (3 coups, parfois une potion ; `GEM_XP` 0,1 niveau, soit ~2 niveaux en tout sur la carte entière,
  contre ~1 000 objets × `BREAK_XP` avant) : constantes `BREAK_XP` / `GEM_XP` laissées telles quelles, `BREAK_XP` ne sert plus. Survie et
  Survivant inchangés (test).
- Test `test_br2` (4 qualités, aura éteinte à l'ouverture, aura seule, carte : 64 coffres des 3 qualités, 0 jarre / caisse / or, Survie intacte).
  Outil de capture `tests/shot_br2.tscn -- lineup <modèles> | tiers | map [graine]` (user://shots/br2_*.png).

## Vérifié sur capture
Les quatre qualités à 10, 28 et 55 m (`tiers`), puis sur la vraie carte du Battle royale à 30 et 55 m (`map`) : chaque coffre se repère de loin
grâce au faisceau et au halo coloré, sans jarre ni caisse autour.

## Reste / pièges
- Retouches hors de mon périmètre : `ui/minimap.gd` (couleur « chest » + noms de légende), `core/royale_director.gd` (`_spawn_chest`,
  `_announce_drop`, variable `_chest_npc` retirée).
- `test_royale` / `test_nav_screens` : à relancer une fois que les autres lots de la nuit (BR3, BR4 : `royale_loot.gd`, `royale_drop.gd`) compilent.
- Les rotations aléatoires des coffres sont gardées ; le halo est symétrique donc rien ne change.
