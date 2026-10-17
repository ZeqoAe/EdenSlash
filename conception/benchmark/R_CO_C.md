# R_CO_C : Le Colisée, lot CO-C — directeur du combat et sonde de performances (17/10/2026)

Étude : `ARENA.md` § 6.2, § 6.10, § 6.15, § 6.16 ; socle : `R_MODE0.md`, `R_CO_A.md` (machine de partie), `R_CO_B.md` (carte). Lot =
backlog n° 3 et 4.

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Directeur du combat | `game/scripts/core/colisee_director.gd` (`ColiseeDirector`) | monté par `TeamMatch.mount` (état « team » de `RunDirector`) ; carte (`generate_colisee`, une arène par combat), manches de la machine `Colisee`, combats simultanés réels, combats cachés, repli au tableau, mort du joueur, spectateur de base, fin de partie (bilan `ResultsPanel` minimal, `Colisee.finish` avant tout), abandon |
| Effets coupés par arène | `combat/vfx.gd` (`Vfx.hidden_arenas`, `Vfx.muted(nœud)`), `combat/eden_fx.gd`, `combat/sfx.gd`, `combat/damage_number.gd`, `combat/telegraph.gd` | dans une arène cachée : ni effet d'Eden, ni son, ni chiffre, ni effet simple ; les télégraphes frappent mais ne sont pas dessinés ; `Vfx.silent` garde son sens (tout couper) |
| HUD | `ui/hud.gd` | état « team » : horloge et ligne lues dans le directeur du mode (`clock_text`, `sub_text`) au lieu de « ⏳ 10:00 » et « Sceaux » ; pas d'objectifs à déplier |
| Lancement direct | `core/world.gd` | `world.tscn -- --colisee [--co-format=classique|eclair|grand] [--co-diff=0..4] [--co-seed=N] [--co-nofallback] [--autoplay] [--auto-quit]` (lignes « [colisee] … ») |
| Page minimale du lobby | `ui/colisee_page.gd` (`ColiseePage`), `ui/activities.gd`, `ui/lobby.gd` | activité « Le Colisée » (Affrontements, image des Arènes en attendant la sienne), **cachée** hors mode dev tant que `Colisee.READY` est faux ; page : le mode en trois lignes, format, adversaires (5 difficultés), « Entrer au Colisée » |
| Sorts du joueur | `core/colisee.gd` (`begin`) | sans préréglage de sorts : les 4 premiers sorts de la classe (la 1re partie réelle n'en avait aucun) |
| Sonde | `game/tools/colisee_probe.tscn`, mesures `game/tests/co_mesures.json` | § 3 |
| Tests et captures | `game/tests/test_co_c.tscn`, `game/tests/shot_co.tscn` (1280 × 720 et 1600 × 900), `test_nav_screens` (page du lobby) | § 5, § 6 |

## 2. Déroulé codé

- **Manche** : préparation (`PREP` 3 s ; 1 s au pilote ; l'écran de préparation de 30 s vient au lot CO-G) → compte à rebours 3 s →
  combats : **tous ceux de la manche en même temps**, pour de vrai (mêmes héros scriptés `TeamMatch.make_hero`, fiche « à l'arme »
  niveau 60, mêmes sorts d'Eden), chacun dans son arène → fin d'un combat quand un trio est entièrement à terre, ou au temps (85 s,
  égalité par part de PV restants, `Colisee.tie_winner`) → bandeau 2,5 s (« Manche gagnée · Griotte −20 », « Égalité », éliminations
  « Menthe éliminés · 5e ») → `Colisee.report`, éliminations rendues à `TeamMatch.eliminate` **dans le même ordre** (contrôlé :
  avertissement si les places divergent, jamais vu) → manche suivante. L'équipe du joueur est toujours du côté de la caméra.
- **Héros** recréés à chaque manche (un héros scripté tombé disparaît) : l'arène regardée tout de suite, les autres 3 par image ;
  modèles des 18-24 classes préchargés au lancement sur un fil (`ColiseeDirector.prepare`). Équipes au repos (exempte, éliminées) :
  personne sur la carte ; le joueur au repos n'a ni corps ni contrôle (arène `PARK`, que `ffa_foes` ne voit jamais).
- **Anneau et fleurs** de chaque arène avancés par le directeur (`ColiseeArena.tick`), PV et soins hors de l'anneau (lot CO-B).
- **Combats cachés** (patron AC-E) : seule l'arène regardée est rendue ; ailleurs héros invisibles, `anim.active` faux, arène non
  dessinée, `Vfx.hidden_arenas` coupe effets, sons, chiffres et dessin des télégraphes ; annonces du HUD seulement pour le combat
  du joueur. Aucun réglage d'IA différent entre combat regardé et combats cachés.
- **Repli « au tableau »** : images de plus de 33 ms cumulées sur 3 s réelles, pas avant 5 s de combat (une image rapide en retire
  deux fois sa durée) → les combats cachés encore en cours sont tranchés par `Colisee.resolve_board` (PV × frappe des héros debout),
  notés « tableau » dans le journal. Première version (20 ms, 1 s, comme l'Échiquier) : sur la machine chargée elle tranchait des
  combats dès 1,3 s (10 replis dans une partie) ; réglée : 2 replis sur 30 combats dans la partie mesurée (§ 4).
  `--co-nofallback` le coupe (mesures de vrais combats).
- **Mort du joueur** : ses alliés continuent, message « Tu es tombé : tes alliés se battent encore ! », la caméra suit un allié debout ;
  il revient à la manche suivante. **Spectateur de base** : combat du joueur fini (après 2 s) ou trio éliminé → la caméra passe au
  combat encore en cours le plus long (« Ailleurs : Braise contre Menthe ») ; `watch(i)` / `next_watch(±1)` pour l'interface (vignettes
  et LB / RB : lot CO-J).
- **Fin** : `Colisee.finish()` (donc `TeamMatch.end()`) avant toute récompense (lot CO-H), bilan minimal (place, manches, manches
  gagnées, « Menu principal » : profil rechargé).

## 3. Sonde de performances et décision du Grand tournoi

`godot --headless --fixed-fps 60 --path game res://tools/colisee_probe.tscn -- --teams=2|6|8 --diff=3 --seconds=30 --seed=N`
(et sans `--headless` : rendu de l'arène regardée compris, fenêtre 1600 × 900). Vraie partie, Hardcore, 1re manche : tous les combats en
même temps pendant 30 s (les 2 premières à part : apparition des héros cachés). `--fixed-fps 60` : une image = un pas de physique, sans
attente, la durée mesurée est le calcul. Trois essais par cas (graines 4242-4244). PC du joueur : Ryzen 7 9800X3D, RTX 5070, 31 Go ;
**8 à 14 processus Godot d'autres sessions actifs** pendant les mesures (notés dans `co_mesures.json`).

| Cas | Héros | Image médiane (ms) | p95 | p99 | max | Apparition des héros | Godot actifs |
|---|---|---|---|---|---|---|---|
| 1 arène (référence, 2 équipes), calcul seul | 6 | 3,35 / 2,91 / 3,07 | 5,2 / 5,0 / 4,9 | 22 / 16 / 12 | 88 / 88 / 52 | 53-73 ms | 12-14 |
| **Classique 6 × 3**, calcul seul | 18 | 3,92 / 4,00 / 4,19 | 5,3 / 5,8 / 5,9 | 13-14 | 26-59 | 130-137 ms | 12-14 |
| **Grand tournoi 8 × 3**, calcul seul | 24 | 4,39 / 4,59 / 4,57 | 6,2 / 7,0 / 6,3 | 10-13 | 24-55 | 131-159 ms | 12 |
| Classique 6 × 3, avec rendu | 18 | 7,36 / 7,54 / 6,36 | 9,9 / 11,6 / 9,4 | 16-17 | 41-108 | 97-122 ms | 10-12 |
| **Grand tournoi 8 × 3, avec rendu** | 24 | **7,56 / 7,48 / 7,13** | **11,3 / 11,9 / 10,1** | 17-17,5 | 28-42 | 116-149 ms | 8-10 |

Du lancement au premier combat (carte, navigation, monde, héros) : 1,8-2,5 s dans tous les cas (2 équipes comprises : c'est la carte, pas
les héros).

**Lecture** : chaque arène cachée de plus coûte environ 0,2-0,3 ms de calcul par image ; 24 héros au lieu de 18 : +0,4 ms de calcul, et
avec rendu les deux formats sont au même niveau (le rendu de l'arène regardée domine). Les pics (max) ne suivent pas le nombre de héros :
la référence à 6 héros a les plus hauts (88 ms) — ce sont les autres sessions qui tournent sur la machine et les apparitions.

**Décision : Grand tournoi 8 × 3 OUVERT** (critères de l'étude tenus dans les 3 essais avec rendu : médiane ≤ 8 ms, p95 ≤ 16 ms ;
apparition des 24 héros 0,12-0,16 s, bien sous 1,5 s). `Colisee.FORMATS.grand` n'a plus `locked` (sélectionnable sur la page ; la
colonne compacte des 8 équipes de l'interface reste au lot CO-L). Réserve : la médiane avec rendu (7,1-7,6 ms) est proche du seuil de
8 ms ; à remesurer au calme et après les lots qui ajoutent du coût (CO-D chef d'équipe, CO-E atouts, CO-G HUD) — la sonde se relance
telle quelle. Le p99 avec rendu (16-17,5 ms) dépasse 16 ms dans les deux formats : une image sur cent tient en deux images à 60 i/s.

## 4. Parties réelles (pilote automatique, machine chargée)

`world.tscn -- --colisee --co-diff=2 --co-seed=7 --autoplay --auto-quit` (Difficile, préparation de 1 s) :

| Partie | Manches | Combats réels : médiane (min-max) | Replis au tableau | Durée réelle | Place du joueur | Erreurs |
|---|---|---|---|---|---|---|
| 1re version (repli 20 ms / 1 s) | 10 | — | **10** (dès 1,3 s) | 9,7 min | 2e | 64 257 « instance libérée » (caméra sur un héros de la manche d'avant) |
| version livrée | 10 | **56,2 s** (29,4-62,8 ; 21 combats) | 2 (à 29,9 s, manche 4) | 11,0 min | 3e (victoire) | 0 |
| Grand tournoi 8 × 3, Mélange (`--co-format=grand --co-diff=4 --co-seed=21`) | 11 | 48,5 s (24,4-72,3 ; 32 combats, 4 en même temps) | 0 | 11,6 min | 2e (victoire) | 0 |

Avec la préparation de 30 s de l'étude (lot CO-G), la même partie ferait ≈ 16 min (cible de l'étude : 17-21 min ; mesures du lot CO-I).
Les combats tiennent dans la cible v2 de l'étude (manche médiane 50-65 s) ; les trios s'éliminent avant le feu le plus serré.

## 5. Tests (copie de HEAD 0.1.303 + CO-C, `run_tests.py --reuse -j 2`)

`test_co_c` (≈ 25 contrôles, 3 min) : directeur monté, carte de 3 arènes (navigation), ni carte de compétence ni monstre de la Survie ;
manche 1 : 3 combats, 18 héros dont le joueur, chacun dans l'arène de son combat et dans son équipe ; combat regardé = celui du joueur ;
combats cachés (héros invisibles, animations arrêtées, effets / sons / chiffres coupés, arène non dessinée) ; regarder un autre combat
puis revenir ; mort du joueur (pas de bilan de Survie, caméra sur un allié) ; repli au tableau d'un combat caché ; les 3 combats
finissent ; **≈ 255 coups relevés dans les arènes, 0 d'une arène à l'autre, 0 entre équipiers** (relevés au moment du coup) ; manche
rendue à la machine (PV d'équipe, TeamMatch manche 2) ; joueur relevé ; finale jouée pour de vrai jusqu'au bilan ; places uniques de 1 à 6 ;
plus aucun effet coupé après la partie.

Suite (une seule exécution, `-j 2`, 8 à 14 autres Godot sur la machine) : **14 verts sur 14** — `test_co_a`, `test_co_b`, `test_co_c`,
`test_mode0`, `test_pvp`, `test_duel_modes`, `test_m7`, `test_royale`, `test_nav_screens` (avec la page du Colisée), `test_texts_fr`,
`test_hud2`, `test_pages`, `test_compass`, `test_lot10` ; `python tools/check_scripts.py` (copie) : 575 scripts compilent.

## 6. Captures regardées (`tests/shot_co.tscn`, hors dépôt : `C:\AI\benchmark_refs\arena\co_c\`)

1280 × 720 et 1600 × 900 : début du combat, annonce du feu (pointillés), un autre combat regardé, joueur à terre. Corrigé après lecture :
le joueur n'avait **aucun sort** (barre vide : pas de préréglage → les 4 premiers sorts de la classe) ; le cadre du HUD disait
« ⏳ 10:00 » et « Sceaux ◇◇◇ » (Survie) → « Manche 1 · 0:22 » et « Prairie · ton trio 100 PV · contre Griotte » / « · Feu · 3 s » ;
la ligne était coupée en 1280 × 720 (l'annonce du feu remplace « contre … »). Tout tient dans 1280 × 720. Restent pour le lot CO-G :
barres de vie pomme / fraise sans nom au-dessus des héros, statuts écrits au-dessus des héros (« Épines · Barrière »), barre de boss
réemployée pour la cible, effets d'Eden très couvrants (déjà notés par l'étude), vie du joueur affichée quand il regarde ailleurs.

## 7. Pièges pour la suite

1. Un héros scripté tombé est **libéré** (~2,4 s) : ne jamais garder une référence typée (`var c: Combatant = …`) sur un héros d'une
   manche passée ; `is_instance_valid` d'abord (la caméra en a fait les frais : 64 000 erreurs).
2. Les éliminations doivent passer par `Colisee.report` puis `TeamMatch.eliminate` dans l'ordre rendu (places identiques).
3. `Vfx.hidden_arenas` est global : le directeur le vide à la fin et à la sortie de l'arbre ; tout nouvel effet visuel ou sonore du
   combat doit passer par `Vfx.muted(nœud)` (pas `Vfx.silent`) pour rester coupé dans les arènes cachées.
4. `ColiseeDirector.probe` (sonde) : pas de préparation, combats sans fin ; à remettre à faux hors sonde.
5. Le repli au tableau dépend de la charge de la machine : les tests le coupent (`ColiseeDirector.fallback = false`).
6. La page du lobby est minimale et l'activité cachée (`Colisee.READY` faux) : l'ouvrir à tous au lot CO-H, quand bilan, récompenses et
   quêtes seront là.
