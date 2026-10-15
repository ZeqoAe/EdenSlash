# N1 — La Survie part avec l'équipement du hub (nuit du 15/10/2026)

Session N1, travail de la nuit. Décision du joueur du 15/10 : revenir sur la décision 0.1.123 « en Survie on part sans
équipement ». Constat de départ (journal réel du joueur, partie neuve) : 9 runs, toutes perdues entre 2 min 35 et 4 min 55,
niveau 1 à 4, 18 à 133 monstres tués, aucune n'atteint le boss ; et rien de ce qu'il faisait au hub ne servait en Survie.

## 1. Ce qui a été fait (en une page)

| Sujet | Décision | Où |
|---|---|---|
| Équipement de départ | La Survie part avec le **préréglage actif du hub** : pièces, +N, gemmes, enchantements, panoplies, arme secondaire. Plus de choix d'arme au départ. | `Run.start_survival`, `RunDirector` |
| Instantané / restauration | `Profile.begin_run` copie l'équipement (la run travaille sur des copies) et prend un **instantané** du coffre, des préréglages et du loadout (`_hub_snapshot`). `Profile.end_run_survival` appelle `restore_hub_gear()` : si quoi que ce soit a bougé (hash), tout est remis. Victoire, défaite, abandon, extraction : même chemin. | `core/profile.gd` |
| Reprise après fermeture | Pas de code de reprise à écrire : `save_profile()` n'appelle pas `_sync_vault()` en run, donc le fichier contient toujours le hub d'avant la run ; `load_profile()` repart de là (`in_run = false`). Vérifié par `test_gear_run` (copie modifiée +9 en run, sauvegarde, rechargement : +0). | `core/profile.gd` |
| Trouvailles de coffre | Elles remplacent un emplacement **le temps de la run** et restent achetables à l'Armurerie (`seen_gear`), comme avant. | inchangé |
| Compte neuf | `StarterGear` : 8 pièces d'Eden par classe (arme du type de la classe, tête, torse, jambes, gants, bottes, bague, collier), les plus rares possibles jusqu'à **rare**, palier 10-30 (le plus proche de 20), +0, qualité 1,0. Remises **une seule fois par classe** (`Profile.starter_done`) si son préréglage actif n'a aucune pièce d'armure : un compte existant sans armure (la partie neuve du joueur) en reçoit aussi. 57 classes sur 60 ont les 8 pièces ; `gunscythe` (Inquisiteur, Reaver, Rifleteer) n'a aucun objet dans les données d'Eden : arme générée comme avant. | `core/starter_gear.gd`, `Profile._grant_starter` |
| Enclume | **Additive** : bonus tiré de +0 à +7 (moyenne ≈ +3,2, plus de négatif), AJOUTÉ au +N de la pièce du hub ; **total plafonné à +12** (`Run.UPGRADE_CAP`, ×2,2 sur les stats de base). Elle rattrape les pièces peu améliorées ; sur une pièce +10 elle ne vaut que +2. Un nouveau tirage sur un emplacement remplace l'ancien. | `Run.slot_upgrade`, `Run.ANVIL_ROLLS` |
| Gemmes | En Survie, leurs valeurs **plates** (force, PV, défense…) suivent le niveau du héros : pleines au niveau 15, ×0,35 au plus bas, ×2 au plus haut (`Craft.gem_run_factor`). Sans cela une gemme royale valait +320 PV dès le niveau 1. Les gemmes de critique et les enchantements (tous en %) ne changent pas. Hors Survie : valeur pleine. | `core/craft.gd` |
| Cartes d'amélioration | Inchangées et déjà plafonnées : niveau 8 par arme (`WeaponAttacks.MAX_RANK`), rang de sort plafonné. Elles s'ajoutent aux stats d'équipement sans les remplacer ; le plafond de stats d'équipement est donc +12 de +N × la rareté. | doc seulement |
| Insignes | **+25 de participation** dès 10 monstres tués (`Run.INSIGNIA_BASE`) ; kills/20 au lieu de kills/25. Une défaite en carte 1 avec 40 monstres tués rapporte 54 insignes ; la pièce de l'Armurerie la moins chère de l'époque I coûte 50 (arme niveau 20) à 73. Donc même une défaite paie une pièce en 1 ou 2 runs. | `core/run.gd` |
| Débuts de partie | Premiers niveaux plus rapides (`Epochs.xp_boost` : XP ×2 au niveau 1, ×1 au niveau 10) ; début de carte plus doux (`EARLY_EASE` 0,6 → 0,45, `EARLY_RAMP` 180 → 300 s). | `core/epochs.gd`, `player.gd`, `run_director.gd` |
| Textes joueur | Premiers pas (étape 1 : « Ton équipement du hub est déjà porté… », validée au 1er monstre tué), fiches Enclume et « Ce que tu gardes », message de début de run, page Survie du lobby, Guide/Informations, Armurerie, message de forge en run. | `tutorial.gd`, `lobby.gd`, `info_page.gd`, `gear_shop_page.gd`, `inventory_page.gd` |
| Docs | `DESIGN.md` (« Boucle de jeu et Survie »), `CLAUDE.md` (« Survie refondue »). | |

Non touchés : Duel, Tour, Donjons, Arènes, Siège, Battle royale (qui démarre toujours nue : `Royale.start` vide ses propres copies).
Le défi d'époque III « Finir sans arme secondaire » : l'arme secondaire du hub compte (`Run.offhand_used` vaut vrai au départ).

## 2. Mesures (autoplay, `tools/sim_survie.py`)

**Protocole.** `world.tscn -- --autoplay --auto-quit --class=… --hub=… --epoch=… --human=… --fight=8 --boss-after=360`, 60 images/s
fixes, un profil jetable par processus (`EDEN_PROFILE=user://sim_….json`), 7 processus en parallèle, graines 1000 / 8919 / 16838.
Les 5 classes de départ (guerrier, voleur, chasseur, clerc, magicien) × 3 graines = 15 runs par ligne (10 pour les lignes
« époque II » et « moyen »).

Le bot ne sait pas esquiver et se bat mal : il meurt à 2-5 min même avec un bon équipement. Il sert donc de **proxy relatif** :
`--human=0,5` fait éviter la moitié des coups (bon joueur), `--human=0,3` 30 % (débutant). Comparaison avec le journal réel : à
0 % d'évitement le bot meurt aussi vite que le joueur (2-5 min, niveau 2-6).

**Métrique principale : « survit au moins 7 min » (= est encore là à l'heure d'aller au boss).** « Boss atteint » est donné mais
sous-estimé : le bot rate parfois la porte du donjon (des runs finissent à 15 min en rage sans y être entrés). « Boss battu » est
très bas pour tout le monde : le bot n'esquive jamais les zones rouges.

### Époque I, carte 1 (Limestone), coups évités 0,5

| Équipement du hub | Survit ≥ 7 min | Boss atteint | Boss battu |
|---|---|---|---|
| Départ d'un compte neuf (StarterGear) | **60 %** (9/15, reproduit : 9/15 sur une 2e série) | 8/30 | 0/30 |
| Moyen : pièces mythiques de la carte 1 à +3, sans gemme (`--hub 1.1.3`, 10 runs) | 100 % | 0/10 (bot) | 0/10 |
| Optimisé : mythiques de la carte 3 à +10, 2 gemmes parfaites par pièce, enchantement (`--hub 1.3.10.3`) | **100 %** (15/15) | 8/15 | 4/15 |

Débutant (0,3) : départ 40 % (6/15) ; optimisé 67 % (10/15, mesure faite avec l'ancien réglage de début de carte).

Avant les réglages de début de partie, même équipement de départ (0,5) : 47 % ; et sans l'équipement, le bot et le joueur meurent
en moins de 5 min dans 100 % des runs (journal réel).

### Époque II, carte 1 (Wetlands), coups évités 0,5, 10 runs par ligne

| Équipement | Survit ≥ 7 min | Boss atteint |
|---|---|---|
| Départ d'un compte neuf | 70 % | 4/10 |
| Optimisé de l'époque I (`1.3.10.3`) | 90 % | 6/10 |
| Optimisé de l'époque II (`2.3.10.4`) | 90 % | 4/10 |

**Lecture honnête** : l'écart entre départ et optimisé est net à l'époque I (60 % → 100 %, boss battu 0 → 27 %) ; à l'époque II, carte 1,
le bot ne distingue pas les équipements (la carte 1 plafonne le héros au niveau 15 et le bot ne tient pas jusqu'aux cartes 2-3 ni aux
boss, où l'écart d'époque se verrait). Le levier d'époque reste `Epochs.MONSTER_MULT` (×1,35 / ×1,75 / ×2,2) ; il n'a pas été vérifié ici.

### Échelle des stats (sonde `tools/gear_probe.tscn`, guerrier, niveau 15)

| | PV d'équipement | attaque physique d'équipement | (héros : atk 171, PV 1720) |
|---|---|---|---|
| Départ (rare, +0) | 422 | 47 | |
| Mythiques carte 3 +0 | 523 | 46 | |
| Mythiques carte 3 +10 | 1294 | 91 | |
| + 2 gemmes parfaites par pièce | 2600 | 91 | |

Une pièce mythique achetée remplace une pièce de départ rare : +22 % de stats sur l'emplacement (rareté ×1,22 contre ×1,0). C'est modeste
(le héros pèse bien plus que l'équipement) ; le gros de la progression vient de l'Atelier (+N : ×2 à +10) et des gemmes. **Piège
d'équilibrage mesuré** : un départ plus faible (communes / spéciales, qualité 0,9) fait tomber la survie du compte neuf de 60 % à 40 % ; le
début de partie est très sensible à l'arme.

## 3. Pièges, restes, à décider

1. **`settings_test.cfg` partagé** : les tests (`test_lot9`, `test_controls`…) réécrivent les réglages de test (mode de déplacement « clic », aide
   « détente »…) et faussent les mesures du bot si on les lance en même temps ou juste avant (une série est tombée à 0 % pour cette raison).
   Supprimer `%APPDATA%/Godot/app_userdata/Eden Slash/settings_test.cfg` avant de mesurer, et ne pas lancer de test pendant une mesure.
2. **Fortification en hub** (déjà relevé par A1, mur n°1) : un parchemin doit avoir un niveau ≥ celui de la pièce ; les pièces mythiques de l'époque I
   (niveaux 20-43) demandent des parchemins Lv30-50 qui ne tombent qu'en carte 2 ou plus, et une défaite ne garde pas les fournitures. Le compte neuf
   peut donc surtout progresser par l'Armurerie ; l'Atelier arrive avec les premières victoires. À traiter dans le chantier économie (B5).
3. **Pièces de départ ≈ pièces rares de niveau 20** : leur plafond de puissance est leur niveau (20-30), donc elles suivent le héros jusqu'à la fin
   de la carte 1 (niveau 15) et un peu au-delà, puis décrochent aux cartes 2-3 (plafonds 25 et 35) : le joueur est poussé vers l'Armurerie.
4. **Premier pas du joueur** : l'étape 1 des Premiers pas se valide au 1er monstre vaincu (plus d'écran de choix d'arme).
5. **Équilibrage à confirmer par le joueur** : début de carte plus doux et XP ×2 aux premiers niveaux touchent aussi les vétérans (cartes 2 et 3
   comprises pour la rampe). Ils ont été pris plutôt que d'adoucir les monstres ; le rythme est à valider au jeu réel.
6. **Numérotation** : la consigne disait 0.1.164 ; d'autres sessions ont déjà poussé 0.1.165 à 0.1.169 sur la même branche, ce lot est la **0.1.170**.
7. **Bot de test** : `--fight=<m>` (le bot combat avant de marcher vers un objectif) et `--human=<part évitée>` sont des options de mesure
   (`Run.test_fight_range`, `Run.test_taken`), sans effet en jeu normal.
8. Reste : mesurer les cartes 2-3 et les boss avec un bot qui esquive ; mesurer les époques III-IV ; `Items.describe` montre le +N de la pièce, pas le total
   avec l'enclume (la pastille de l'emplacement, elle, montre le total).

## 4. Fichiers

Nouveaux : `game/scripts/core/starter_gear.gd`, `game/tests/test_gear_run.gd/.tscn`, `game/tools/gear_probe.gd/.tscn`, `tools/sim_survie.py`.
Modifiés : `core/profile.gd`, `core/run.gd`, `core/craft.gd`, `core/epochs.gd`, `core/run_director.gd`, `core/world.gd`, `core/tutorial.gd`,
`combat/combatant.gd`, `player/player.gd`, `ui/lobby.gd`, `ui/info_page.gd`, `ui/gear_shop_page.gd`, `ui/inventory_page.gd`, `ui/item_widgets.gd`,
tests `test_farm`, `test_progress`, `test_pages`, `DESIGN.md`, `CLAUDE.md`.

Mesure : `python tools/sim_survie.py --hub new --classes warrior,thief,hunter,cleric,magician --seeds 3 --human 0.5` ;
`--hub E.C.N[.G]` = pièces des coffres de l'époque E, carte C, à +N, avec 2 gemmes de palier G.
