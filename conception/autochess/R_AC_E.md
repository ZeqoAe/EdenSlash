# R_AC_E — L'Échiquier, lot AC-E : le combat réel (17/10/2026)

## Fait
- `game/scripts/core/autochess_director.gd` (`AutochessDirector`, Node3D) : joue en même temps tous les combats d'une manche
  de la machine `Autochess` (AC-B). Un plateau par combat, à `AutochessData.BOARD_SPACING` (300 m) les uns des autres, sol et
  murs physiques ; camps en miroir aux cases d'`AutochessBoard.cell_position` (monstres et gardien : cases de devant) ;
  le plateau regardé apparaît d'un coup, les autres 3 unités par image ; `prepare(partie)` précharge (fil du moteur) les
  modèles de toutes les unités des plateaux et bancs pendant la préparation. Couche d'effets `AutochessEffects` (AC-H) = vérité :
  `context` (fiche `base_sheet`), `start`, `set_pos` et `tick` (pas de 0,05 s) à chaque image ; fin quand un camp tombe ;
  « Fureur » annoncée à 30 s (signal `fury_started` ; les dégâts, eux, sont dans la couche) ; égalité à 45 s (`draw_at`,
  profil `autochess`) ; ×1 / ×2 par `Engine.time_scale` pendant le combat seulement (rendu à 1 à la fin, `set_speed`,
  `AutochessDirector.speed` gardé) ; `watch(i)` (rendu du seul plateau regardé : unités cachées, animations arrêtées, ni
  effets, ni sons, ni chiffres ailleurs ; le plateau affiché `view` et la caméra suivent) ; repli : image > 20 ms pendant
  2 s -> plateaux cachés finis par le combat de données (`finish_by_data`, `data_run`, même couche).
- `game/scripts/ai/autochess_unit.gd` (`AutochessUnit extends ClassRival`) : **squelette** de l'IA, repris du prototype
  d'AC2 (`tools/ac2_unit.gd` : soutien d'équipe, zones des équipiers ignorées, sans repli ni bond réflexe, mêlée au contact,
  sorts à portée). Camps par `ffa_id` = 2 × plateau + camp ; ennemis / alliés donnés par le directeur (`foes_of`,
  `allies_of`), jamais par les groupes globaux. Mana au lieu des recharges : sort signature à mana pleine
  (`AutochessEffects.can_cast` puis `cast`), ★3 : 2e sort enchaîné sans mana, Arcane 9 : relance (`recast`). Auto-attaque au
  rythme de `stat("as")`, à `stat("reach")`, sans zone au sol, résolue à l'impact par `AutochessEffects.attack` ; sorts de
  dégâts : zone rouge (Telegraph) -> `take_damage` -> `spell_hit` ; soins : `spell_heal` sur l'allié le plus bas. Les PV,
  la mana et les contrôles du nœud sont le miroir de la couche (`sync`, `ac_stun`, `ac_die`). Bornes : plateau moins
  0,5 m (murs + position bornée à chaque image). Barres de PV (vert / rouge selon le camp) et de mana au-dessus de chaque
  unité (une seule surface face caméra, paramètres par instance), étoiles et nom court, chiffres de dégâts et soins, ESQUIVE
  / PARADE (plateau regardé seulement). Monstres et gardien : corps d'un monstre d'Eden (rang 2 / 3 / boss), même IA.
- `core/modes.gd` : `Modes.current()` = « autochess » tant qu'`AutochessDirector.active` (posé par un directeur dans l'arbre,
  `owns_mode`), ajouté à `Modes.SEALED` et à `Modes.sealed()`. `core/mode_rules.gd` : profil `autochess` (`dmg_scale`,
  `draw_at`, et pour lecture `hit_cap`, Fureur, `unit_diff` d'`AutochessData`). Aucun autre mode ne change.
- Test `test_ac_fight` (≈ 35 vérifications, ≈ 2-3 min ; `AC_FIGHT_QUICK=1` : 10 combats au lieu de 20). Compteurs par unité
  gardés après la chute dans `arène.stats[fid]` (sorts, auto-attaques, soins, bornes corrigées). Captures
  `tests/shot_ac_fight.tscn` (1280 × 720 : début, mêlée, suite), regardées : barres, étoiles et noms lisibles.

## Chiffres (headless, `dmg_scale` 0,10)
- 20 combats 5 contre 5 (coûts 1-3, 15 % de ★2), ×2 : médiane **24-26 s** (17-45 s), 0 égalité ; 80 % des unités lancent
  leur sort au moins une fois (les tanks à 140 de mana, rarement).
- 4 plateaux 10 contre 10 en même temps (80 unités) : image physique médiane **6 ms** (p95 20-80 ms : apparitions, d'où
  le repli suspendu tant que des unités apparaissent).
- ×2 : 2,0 × le temps réel. Égalité à 45,0 s ; Fureur à 30,0 s. Manches 1-2 à 2-1 d'une partie au hasard jouées en vrai.

## Décisions
- **La couche d'effets résout tout** (PvpCaps n'est pas utilisé, `Modes.is_pvp()` reste faux) : un seul moteur de chiffres
  pour le vrai combat et le simulateur. Le nœud ne garde que déplacement, esquive, animations.
- **Fiche de base** `AutochessDirector.base_sheet(u)` (à reprendre telle quelle par AC-C) : la fiche par défaut de la couche
  (rôle × coût × étoiles) × l'écart de la classe à la moyenne des 60 (PV et attaque de base, bornés 0,8-1,25 : « le
  Guerrier a plus de PV ») ; sort = attaque × multiplicateur du vrai sort signature (borné 1,5-3,5) × rang des étoiles ;
  attaque et sort × `dmg_scale` / `DMG_REF`. `dmg_scale` garde le sens de l'échelle du duel (part des PV d'une unité de même
  coût retirée par une auto-attaque) : 0,10 ici (AC2 mesurait 0,20 avec les règles du duel, où l'attaque s'annule ; ici
  défense, Fureur et plafond de 20 % sont ceux de la couche). Pas de `Royale.sheet` : rien du compte ne peut entrer.
- Auto-attaques sans zone rouge (SPEC §3.3) : elles touchent à l'impact si la cible est encore à portée (+ 1,2 m) ;
  l'esquive des auto-attaques est la statistique `dodge` de la couche, pas un bond.
- Un sort en préparation ne s'annule pas par une esquive (la mana est dépensée) ; un contrôle de la couche l'interrompt.
- Un sort qui n'a pas sa cible à portée attend 1,5 s puis part sur elle (zone posée sur la cible) : tout sort finit par partir.
- Portée des guitares (3 cases) : celle des données (SPEC) même si l'animation est de mêlée (AC2 §2.2) ; à revoir par AC-U.

## Points d'extension pour AC-U (`ai/autochess_unit.gd`)
`choose_target(pool, current)` (score, focus d'équipe ; squelette = ClassRival en équipe), `wants_cast()` (sort selon son
type, attente d'une meilleure zone), `heal_target(any)`, `skill_reach(s)`, `_update_chase(delta)` (rôles : recul,
plongée, interposition), `naive` (IA naïve du banc), `RETARGET_EVERY`, `ZONE_WAIT`, `HEAL_WAIT`. Contrat avec le directeur à
garder : `setup_unit`, `sync`, `ac_die`, `ac_stun`, `ac_stop`, `set_shown`, `ac_stats`, `ac_fid` / `ac_side` / `ac_arena`.

## Branchement (AC-G / AC-I)
`var d := AutochessDirector.new(); d.view = plateau; d.camera = caméra; add_child(d)` au début de la partie (le mode est
alors scellé), puis en phase « combat » : `await d.play_round(partie)` (rend les résultats à `finish_combat`) ; `d.watch(i)`
depuis la colonne des stratèges ; `d.set_speed(2.0)` pour ×2 ; `d.clear()` au début de la préparation suivante (les
survivants restent sur place pendant le bilan). Combat instantané sans scène : `partie.fight = AutochessDirector.data_fight`
(remplace `power_fight`). L'écran d'AC-G joue encore `power_fight` : branchement à faire par AC-G / AC-I (fichiers à eux).

## Reste
- IA fine (rôles, focus, plongée, sorts par type) : AC-U. Mécaniques du gardien (briques de boss) : à faire (aujourd'hui un
  gros monstre à la fiche de la couche). Préchargement des modèles pendant la préparation (création 18-48 ms par unité).
- Lancement `world.tscn -- --autochess` non fait (l'écran `scenes/autochess.tscn` d'AC-G en tient lieu).
- Bornes corrigées souvent (≈ 250 images par combat) : unités qui poussent contre un bord (tireurs qui reculent) ; AC-U.

## Pièges
- `AutochessDirector.active` pilote le mode scellé : un directeur créé pour un outil (`owns_mode = false`) ne scelle rien.
- Tests en temps réel : `Engine.time_scale` 2 ou 4 dans `test_ac_fight` ; le repli est coupé (`fallback_ms = 0`) quand on
  mesure, sinon un test chargé finirait ses plateaux cachés par les données.
