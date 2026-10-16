# R_N2 — Survie sans enclume, armes au sac, deux armes et « Changer d'arme » (passe N2, 0.1.229)

Demande du joueur (16/10), élargie par lui : « plus d'enclume en Survie (on part et on rentre avec son équipement) ; une arme
trouvée va dans l'inventaire ; fin des dégâts automatiques de l'arme secondaire ; changer d'arme en plein combat » ; puis « la
refonte de l'arme secondaire concerne tous les modes ; l'arme principale reste celle de la classe » ; puis « les stats de dégâts de
la secondaire n'influencent que les auto-attaques, les compétences prennent toujours l'arme de classe ».

## Fait (lot 1 : socle commun + Survie + hub)

| Sujet | Règle | Où |
|---|---|---|
| Enclume | Plus aucune enclume sur les cartes de la Survie (`ProcMap` n'en pose que si `Survivor.active` : le Survivant garde la sienne, `SurvivorCards` « sv_anvil »). Supprimés : `Run.slot_bonus`, `slot_upgrade`, `anvil_roll`, `ANVIL_ROLLS`, `UPGRADE_CAP`, `ANVIL_SLOTS`, `anvil_stage(s)`, `anvil_result`, cartes `anvil_slot` / `anvil`, `RunDirector.anvil_*`, `Items.anvil_applied`, pastille « +N total » des cases, ligne « Enclume de la run », fiche de découverte, Guide, page Informations, modificateur « Enclume plafonnée » (jamais tiré), `shot_anvil`. Le +N est celui du hub. | `run.gd`, `run_director.gd`, `proc_map.gd`, `items.gd`, `item_widgets.gd`, `profile.gd`, `monster_scaling.gd`, `tutorial.gd`, `guide.gd`, `info_page.gd`, `modifiers.gd` |
| Défis d'époque | III « Finir sans arme secondaire » → « Finir sans changer d'arme » (`Run.offhand_used` passe à vrai au 1er échange) ; IV « Utiliser l'enclume sur les 3 cartes » → « Ouvrir 45 coffres » (`Epochs.CHEST_CHALLENGE`, `Run.chests_total`). Étoiles déjà gagnées : gardées (masque de bits inchangé). | `epochs.gd` |
| Armes trouvées | Coffre d'arme et arme secondaire trouvée (élites, boss) : **dans le sac de la run**, jamais équipées d'office (`Run.bag_weapon`, signal `weapon_bagged`). Le HUD l'annonce 8 s avec [G] « Équiper la trouvaille » (principale si du type de la classe, sinon secondaire) ; sinon pause > Héros (comparaison ▲ / ▼ : une arme d'un autre type se compare à l'arme secondaire, `Items.compare_to_equipped`, `ItemWidgets.card_text`). Sac plein : arme perdue, message. Fin de run : rien n'est gardé (`Profile.end_run_survival`), la pièce reste achetable à l'Armurerie (`seen_items`, `seen_family`). L'armure reste portée tout de suite. | `run.gd`, `run_director.gd`, `hud.gd`, `items.gd` |
| Arme secondaire | Ne frappe **jamais seule** (`Player._update_offhand` supprimé, `OFFHAND_DMG` / `OFFHAND_STATS` retirés) et ne donne **aucune stat** (`Profile.equipment_stats`, `Player._foe_equipment_stats`). Ses cartes d'amélioration de run restent (elle sert quand elle est en main). | `player.gd`, `profile.gd`, `weapon_attacks.gd` |
| Changer d'arme | Action `swap_weapon` : clavier touche physique Z (W en AZERTY), manette R3 (libre), réassignables (`Settings.ACTIONS`, `DEFAULT_BINDS`, `PAD_BINDS`, `PAD_ACTIONS`, Paramètres > Touches > Combat), ligne du Guide F1 (Combat). `Player.swap_weapon` : instantané, recharge `WeaponAttacks.SWAP_CD` 1 s (`SWAP_CD_PVP` 4 s en Duel / Royale), pas d'auto-attaque pendant `SWAP_LOCK` 0,35 s, l'auto-attaque en cours s'arrête, impossible pendant un sort ou étourdi ; éclair bleu discret + son « objet pris » ; pas de bandeau (discret). En main : type, variante, améliorations « offhand », modèle (`Profile.weapon_code(slot)`), gestes de repli si le corps n'a pas les animations de ce type (`Survivor.fallback_anim`). | `player.gd`, `settings.gd`, `settings_menu.gd`, `guide.gd` |
| Compétences | **Une seule source** : `Player.atk` / `matk` sont toujours calculées avec l'arme principale (la secondaire n'entre jamais dans `equipment_stats`) ; les auto-attaques lisent `basic_atk` / `basic_matk` = atk / matk + l'écart d'attaque physique / magique d'objet entre la secondaire et la principale (× bonus d'attaque en %), seulement quand la secondaire est en main (`Player._hand_weapon_delta`, `_hit_monster`). Les autres stats de la secondaire (critique, PV, gemmes, passif d'objet) ne servent à rien ; les panoplies comptent l'arme principale. | `player.gd` |
| HUD | Petite case ronde au-dessus de l'esquive : l'arme rangée, la touche, la recharge ; cachée sans arme secondaire. | `hud.gd` |
| Textes | Fiche « Deux armes » (version 0.1.229 : revue par les joueurs qui avaient vu l'ancienne), infobulles de l'Équipement, grimoire, page de run, page Informations. | `tutorial.gd`, `inventory_page.gd`, `grimoire.gd`, `run_page.gd`, `info_page.gd` |

## Modes (lot 1)

- **Survie** : tout ce qui précède.
- **Donjons, Tour, Ruée, Siège, Entraînement** : équipement du hub, donc l'arme secondaire du préréglage actif ; l'échange marche tel quel
  (recharge 1 s). Rien d'autre à adapter.
- **Duel équipé, Arènes, Gantelet, Ligue, Panthéon** : l'arme secondaire du joueur s'échange avec la recharge longue (4 s) ; les
  adversaires (profils « opti », cerveaux) n'en ont pas (`build_profiles.json` n'a aucune arme secondaire) : les durées de manche
  mesurées ne bougent pas. Avant N2 l'arme secondaire du joueur frappait seule à 60 % : c'était déjà un avantage, désormais retiré.
- **Duel à l'arme (`Duel.bare`)**, **Survivant**, **Battle royale** : pas d'arme secondaire aujourd'hui → l'action ne fait rien et la case
  est cachée. Lot 2 : y donner une arme secondaire (voir « Reste »).
- Pilote automatique, aide « Bot », héros ennemis et alliés IA : ne changent jamais d'arme (`_autoplay_wants` → faux) ; l'observation de
  l'arène d'IA garde le même nombre d'entrées (`swap_left` à la place de la recharge de l'ancienne arme secondaire).
- Sauvegardes : rien à migrer (l'arme secondaire était déjà un emplacement du préréglage) ; `Run` n'a pas de sauvegarde ; une fiche « anvil »
  vue reste dans `Profile.tutorial.seen` sans effet.

## Mesures (`tools/sim_survie.py`, compte neuf, époque I, 5 classes × 3 graines, coups évités 0,5, boss après 6 min)

Copies propres de HEAD (avant) et de HEAD + N2 (après), dossier utilisateur à part ; le pilote ne change jamais d'arme. « Après (pilote
qui s'équipe) » : le pilote porte une arme principale rangée au sac si elle vaut mieux (`RunDirector._pilot_weapon`, `--autoplay`
seulement), comme un joueur ; sans cela il gardait l'arme de départ toute la run (première série « après » : boss atteint 0 / 15).

| Série 1 (graines 1000 / 8919 / 16838) | Survit ≥ 7 min | Boss atteint | Boss battu | Attaque max (moy. / méd.) | Dégâts subis / min |
|---|---|---|---|---|---|
| Avant (enclume, secondaire qui frappe seule) | 13 / 15 (87 %) | 4 (27 %) | 3 (20 %) | 621 / 418 | 3 627 |
| Après, pilote qui garde son arme | 13 / 15 (87 %) | 0 | 0 | 334 / 340 | 6 087 |
| Après, pilote qui s'équipe | 12 / 15 (80 %) | 1 (7 %) | 0 | 323 / 354 | 4 840 |

| Série 2 (graines 5000…), pilote qui s'équipe | Survit ≥ 7 min | Boss atteint | Boss battu | Attaque max (moy. / méd.) | Dégâts subis / min |
|---|---|---|---|---|---|
| Avant | 14 / 15 (93 %) | 4 (27 %) | 2 (13 %) | 626 / 444 | 4 906 |
| Après | 13 / 15 (87 %) | 2 (13 %) | 1 (7 %) | 327 / 320 | 5 716 |

**Sur 30 runs : survie ≥ 7 min 90 % → 83 %, boss de la carte 1 atteint 27 % → 10 %, battu 17 % → 3 %, attaque médiane ≈ −20 %.**
La survie bouge peu (dans le bruit de ± 9 points), mais la fin de carte et le boss sont nettement plus durs : c'est l'effet de la demande
(l'enclume donnait ≈ +3 sur trois emplacements, l'arme secondaire frappait seule à 60 % et donnait la moitié de ses stats). **Écart
important, mais aucun rééquilibrage pris** : c'est la puissance que le joueur a jugée « trop cheat » qui disparaît ; le pilote rate déjà
souvent la porte du donjon (N1) ; la refonte « Aventure » (lots A1-A7, poussés en parallèle) retouche l'économie de la Survie. À trancher
par le joueur au jeu et au journal réel (`tools/journal_report.py`, champ `swapped` à la place de `anvil`). Leviers prêts si la carte 1
devient trop dure : `Epochs.BOSS_HP_MAP[0]` (−20 % compenserait l'attaque perdue) ou `RunDirector.EARLY_EASE` / `EARLY_RAMP`.

## Reste / à valider par le joueur

- Lot 2 : arme secondaire dans le Survivant (trouvable en coffre, hors compte ; `tests/sv7_mesures.json` à remesurer), le Battle royale
  (ramassable ; gardée ou non à la mort) et le Duel à l'arme (secondaire d'un autre type sans pièce), mesure des manches avec échange.
- Touche par défaut (Z / W en AZERTY) et R3 à la manette : à confirmer au jeu.
- La PE compte encore l'arme secondaire à 30 % (`GearPower.OFFHAND_SHARE`) : gardé (elle sert à l'échange), à revoir si le joueur trouve la PE trompeuse.
- `CardPicker.auto_pick` garde son cas « anvil_slot » (sans effet) ; `Craft.upgrade_free` reste (tests de trophées).

## Tests

`test_n2` (nouveau, une trentaine de vérifications : touche et bouton libres, plus d'enclume ni de bonus de run, arme trouvée au sac et annoncée, [G],
comparaison avec l'arme secondaire, aucune stat de la secondaire, ne frappe pas seule, échange, type et modèle suivis, compétence aux mêmes
dégâts avec l'une ou l'autre arme en main, auto-attaque aux stats de l'arme en main, verrou, recharge, retour, sans secondaire, pilote).
Adaptés : `test_gear_run`, `test_farm`, `test_build`, `test_tooltips`, `test_e4`, `test_p13`, `test_p4_flow`, `shot_tips`, `shot_u2` ; retiré :
`shot_anvil`. Captures : `tests/shot_n2.tscn` (case de l'arme rangée au-dessus de l'esquive, annonce « Dans ton sac — G : équiper »).
Suite complète sur une copie propre (HEAD + N2) : 85 / 87 verts ; `test_br2` (plantage à la sortie, identique sur HEAD) et `test_m1`
(réparé en 0.1.220 par BR5) ne viennent pas de N2. Pièges : dossier de brouillon partagé entre sessions (noms `n2_*`), plusieurs sessions
modifient les mêmes fichiers (`player.gd`, `profile.gd`, `DESIGN.md`…) : commit par morceaux, jamais le fichier entier.
