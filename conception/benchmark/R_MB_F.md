# R_MB_F : Les Deux Voies, lot MB-F — jungle neutre, Gardien, Colosse, Sceaux, Bannière, Marée, fin au temps

Lot MB-F du plan `conception/benchmark/MOBA.md` (§ 7.2-7.5, § 9), sur MB-C (`R_MB_C.md`) et en parallèle de MB-D (`R_MB_D.md`,
héros en partie et boutique, autre équipe). Budgets : `R_MB0.md` § 6. Neutralité : `R_MODE0.md` piège 8 (un camp neutre = son
propre `ffa_id`). Mode scellé, solo contre IA scriptée ; l'activité reste cachée (« Bientôt »).

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| Jungle et objectifs | `game/scripts/core/moba_jungle.gd` (`MobaJungle`, monté par `MobaDirector._build_jungle`) | 8 camps, Gardien, Colosse, bonus, Sceaux, Bannière, annonces de la Marée et de la fin, interface pour l'IA, mesures |
| Monstre neutre | `game/scripts/ai/moba_camp.gd` (`MobaCamp extends Monster`) | neutralité, laisse, remise à zéro (cerveau du boss compris), recyclage, sommeil |
| Règles | `game/scripts/core/moba_data.gd` | `CAMPS` (monstres, PV, coups, bonus), `OBJECTIVES` (palier de la bibliothèque, briques, PV, coups), `NEUTRAL_FFA` 99, `CAMP_WAKE`, `OBJ_LEASH`, `BOSS_BANNED`, `BANNER`, Marée (`TIDE_GIANTS`, `TIDE_WAVE_EVERY`), `camp_stats`, `objective_stats`, `wave` / `wave_time` |
| Décision aux points | `game/scripts/core/moba.gd` | `objectives_taken`, `neutral_kills`, `team_gold`, `decided_by`, `decide` (structures, Cœur, **objectifs**, or, sbires), `score`, options `--moba-jungle=0`, `--moba-probe=`, `--moba-clock=` |
| Crochets | `combat/combatant.gd` (2 lignes gardées par `MobaJungle.active` + 3 états), `core/boss_library.gd` (`ctx.bricks`), `ai/moba_minion.gd` (`banner_mult`), `world/moba_structure.gd` (sièges de la Bannière), `core/moba_director.gd` (jungle, `_skip_clock`, réserve de sbires) | — |
| Sonde | `game/tools/moba_obj_probe.gd` (`world.tscn -- --moba --moba-heroes=none --moba-clock=S --moba-probe=cible:héros:niveau[:essais]`) | temps pour vider un camp / un objectif, chutes, coût |
| Test | `game/tests/test_mb_objectives.tscn` | § 5 |

## 2. Règles codées

- **Neutralité** : chaque monstre neutre porte `MobaData.NEUTRAL_FFA` (99, commun à tous les neutres : ils ne se frappent pas) ; hors
  de TeamMatch, du « heroes » et de la grille du directeur (les sbires et les tours ne le voient pas). Les héros des deux équipes le
  frappent (`ffa_foes`) ; il ne vise que les **agresseurs de son camp** (liste du camp : frapper un monstre d'un petit camp réveille
  les deux), le plus proche ; ses zones touchent ce qui s'y trouve. Vérifié : un héros posé à 2 m d'un camp sans le frapper n'est
  jamais visé.
- **Laisse** : 12 m autour du point du camp (18 m autour du centre d'une fosse de 8 m) ; un agresseur qui en sort est oublié ; plus
  aucun agresseur (ou monstre entraîné à plus de laisse + 6 m) : **remise à zéro** (retour à × 1,8 sa vitesse sans prendre de coups,
  « RETOUR » au joueur qui frappe, PV pleins ; boss : seuils, 2e phase, minuteurs des briques, rythme, rage et fureur retirés).
- **Camps** (Forêt de l'arc-en-ciel) : Source = Tortue des îles (lagon), Braise = Crabe fleur de rose (fraise), petits camps = Lutin
  des feuilles + Diablotin de la forêt. Apparition à 1:30 (2 camps par image au plus), réapparition 90 s (petits) / 150 s (bonus).
  Force relative au héros attendu à l'apparition (comme les sbires) : PV en auto-attaques (`hits` 11 / 24), coup en part des PV
  d'un héros (`atk` 2 / 3,5-4 %).
- **Bonus** (90 s, au héros qui achève ; sinon au dernier héros qui a frappé) : **Source** = recharges − 20 % (joueur :
  `Player.timed_stats` « cdr » ; héros scripté : ses minuteurs de sorts avancent × 1,25) ; **Braise** = chaque coup brûle 2 s et
  ralentit 1 s (une fois par seconde et par cible, jamais une structure ni un effet sur la durée ; texte « Tes coups brûlent et
  ralentissent. », l'étude disait « auto-attaques » : `ClassRival` ne distingue pas ses coups, la règle est la même pour tous). Un héros
  éliminé par un héros adverse lui passe ses bonus (le temps qui leur restait).
- **Gardien** (3:00, annoncé 45 s avant, revient 3 min après sa chute) et **Colosse** (9:00, 60 s, 4 min) : **boss de la
  bibliothèque** (`BossLibrary.spawn` ; `MobaJungle` tient lieu de directeur : `_spawn_monster`, `message`, `_boss`), **tirés à la
  graine** parmi ceux qui ont assez de briques jouables dans une fosse : pas d'invocation (aucune création de modèle en partie), pas
  de bouclier à invoquer (totems, cristaux), pas d'arène qui se resserre ni de bourrasque (elles débordent sur les voies, à 21 m ; la
  bourrasque repoussait aussi les héros hors de la laisse : le boss se remettait à zéro en boucle) ; réglages de fosse (`PIT_TUNE` :
  regard 16 m, balayage 20 m, rayons 18 m, météores 7 m). Gardien : 2 briques au palier Normal (37 boss possibles) ; Colosse :
  3 briques au palier Héroïque (rythme × 0,85, 15 boss possibles) + **fureur** 90 s après le début du combat (+12 % de dégâts et
  rythme × 0,95 toutes les 30 s, 6 crans, retirée à la remise à zéro). PV en auto-attaques du héros niveau 5 (Gardien, 140) ou 10
  (Colosse, 255), ou du héros attendu s'il est plus fort ; un coup ≤ 22 / 25 % des PV max. Nom : « Clovis, Gardien ».
- **Sceau** (Gardien) : + 4 % de dégâts (`Combatant.damage_dealt_mult`) et + 4 % de PV max pour toute l'équipe, 3 au plus ; les PV
  sont suivis à chaque image : une fiche refaite ailleurs (niveau, objets du lot MB-D) reçoit de nouveau le bonus.
- **Bannière du Colosse** (150 s, héros vivants de l'équipe qui le prend) : sbires alliés à 12 m d'un porteur × 1,5 (coups sur les
  héros et les sbires, **sièges compris**) et 20 % plus gros ; rappel en 3 s (`MobaJungle.recall_time`, à brancher dans le rappel
  du lot MB-D). Perdue à la mort.
- **Marée finale** (18:00) : annoncée 30 s avant ; un géant de plus par vague sur chaque voie (`MobaData.wave`), Cœurs vulnérables
  même si leurs T2 tiennent (`MobaStructure.invulnerable`, déjà en MB-C), réapparition × 1,5 (MB-A). Vagues resserrées : mesurées à
  20 s, non retenues (§ 4), réglage `TIDE_WAVE_EVERY` (30 s) et `--moba-tune=tide_every:20`.
- **Fin au temps** (25:00) : annonce une minute avant ; décision **aux points** : structures détruites, puis Cœur le moins entamé,
  puis **objectifs pris**, puis or des équipes (`Moba.team_gold`, à tenir par l'économie du lot MB-D), puis sbires tués ; raison dans
  `Moba.decided_by` et la ligne `[moba] fin` ; `Moba.score(camp)` pour le tableau du HUD.
- **Récompenses** (économie du lot MB-D) : camp -> `MobaDirector.reward_camp(genre, lieu, tueur)` (XP 60 / 100, or 60 / 100) ;
  objectif -> XP à chaque héros de l'équipe (150 / 250 ; `reward_objective` si le directeur l'a, sinon `_xp`) ; `on_neutral_down`
  si elle existe ; signal `neutral_down(entrée, tueur, équipe)`.

## 3. Calibrage (sonde, héros scriptés Difficile, une classe par poste tirée à la graine, × 2, `--fixed-fps 60`)

| Cible (étude § 7.5) | Héros | Réglage | Temps (médiane, plage, essais) | Lecture |
|---|---|---|---|---|
| Petit camp ≈ 12 s | 1 Ombre niv. 2 | hits 6 | 6,6 s (4,8-11,4 ; 6) | trop court |
| | | **hits 11** | **13,0 s** (11,3-32,1 ; 6) | retenu |
| Source / Braise ≈ 20 s | 1 Ombre niv. 2 | hits 20 (Source) | 16,8 s (12,3-19,8 ; 6) | un peu court |
| | | **hits 24** (Braise) | **20,6 s** (17,7-76,7 ; 6) | retenu pour les deux |
| Gardien ≈ 25 s | 4 héros niv. 5 | hits 70 | 9,9 s (6,2-12,1 ; 6) | trop court |
| | | hits 175 | 31,4 s (26,9-62,5 ; 6) | un peu long |
| | | **hits 140** | **23,8 s** (12,5-26,7 ; 6), aucun héros tombé | retenu |
| Colosse ≈ 45 s | 4 héros niv. 10 | hits 140 | 24,5 s (17,7-31,2 ; 6) | trop court |
| | | hits 255 (bourrasque permise) | 55,5 s sur 2 ; 4 échecs (bourrasque : héros repoussés hors de la laisse, remises à zéro, équipe balayée) | bourrasque retirée |
| | | **hits 255** | **46,5 s** (42,2-111,4 ; 6) ; 2 équipes balayées par un tirage (couronne d'orbes + flaques + tourbillon) | retenu |

Le Colosse est un vrai combat d'équipe : un tirage sur quatre (tourbillon + flaques) bat 4 héros scriptés niveau 10 qui ne savent pas
encore s'écarter des flaques ; à revoir avec l'IA de poste (MB-E) et la mesure des parties (MB-J).

## 4. Voies : non-régression (`test_mb_lanes`, vagues seules, × 4)

| Réglage | 20 min de vagues égales (3 graines) | Camp bleu × 1,2 : 1re tour (6 graines) |
|---|---|---|
| Marée avec vagues toutes les 20 s | **T1 bleue tombée à 19:46 et 19:55** (2 sur 3), rien sur la 3e | — |
| Marée sans resserrement (retenu) | rien ne tombe (3 sur 3) | T1 rouge à 10:15 / 9:46 / 9:45 / 6:48 / 8:21 / 9:18 (médiane 9:30) |
| sans jungle (`--moba-jungle=0`), vagues à 20 s | rien ne tombe (graine 4) | 7:42 (graine 2) |

La jungle ne touche pas aux voies, mais ses 14 monstres préparés au chargement tirent dans le hasard global : la suite de hasard des
sbires change (graine 2 : 6:45 avec une réserve plus petite, 9:46 avec la réserve actuelle). La plage reste celle de MB-C (7:14-11:17).
Réserve de sbires agrandie (22 mêlées, 15 tireurs, 5 béliers, 8 géants par camp) : avec la Marée, l'ancienne réserve créait jusqu'à
6 sbires en partie après 18:00.

## 5. Coût (budgets R_MB0 § 6 ; machine saturée par d'autres agents)

| Mesure | Valeur | Budget |
|---|---|---|
| Nœud `MobaJungle` par image physique (temps mur) | 25-120 µs en moyenne (sondes et test) | — |
| Monstres neutres éveillés en combat (leur `_physics_process`, cerveau du boss à part) | 80-360 µs par image en tout (1 à 5 neutres au combat) | — |
| Partie à 8 IA (2:00-6:00) : neutres éveillés en moyenne / au plus | 3,4 / 10 (après passage du réveil de 30 à 22 m et une image sur 2 sans combat ; avant : 6,2 / 12, 300 µs) ; nœud 84-88 µs, neutres 119-124 µs par image | — |
| Images où le nœud ou un neutre dépasse 1 ms | 0 à 13 sur 400-3 800 en sonde ; 30 / 50 sur 14 400 en partie à 8 IA (mesure en temps mur sur une machine saturée : préemption ; aucune n'est liée à un genre de travail) | — |
| Apparition des 8 camps à 1:30 | 1,6-2,6 ms l'image avant étalement, 2 camps par image ensuite | aucune image > 5 ms |
| Monstres neutres créés pendant la partie | **0** (14 au chargement : 12 de camp + 2 boss) | aucun modèle |
| Temps CPU du processus par image physique, partie à 8 IA (Difficile, graine 21, HEAD 0.1.318 avec MB-D), 2:00-6:00, `GetProcessTimes` | **4,51 ms** avec la jungle, 4,28 ms sans (`--moba-jungle=0`) : **+ 0,23 ms** (Gardien en jeu dès 3:00 compris) | logique ≤ 5 ms |

Les camps dorment sans héros à 30 m (ni physique ni animation) : dans les parties à 8 IA (qui ne vont pas encore en jungle, MB-E),
seuls les objectifs proches des voies s'éveillent.

## 6. Tests

`test_mb_objectives` (≈ 50 contrôles, ≈ 60 s) : règles pures (tables, Marée, réapparition, décision aux points et sa raison, forces,
briques des 48 boss) ; partie réelle (horloge à 1:20, × 2) : 8 camps / 12 monstres et 2 boss préparés au chargement, apparition à
1:30, neutres hors de TeamMatch, sommeil, neutralité, laisse et remise à zéro, Source (bonus, minuteurs × 1,25, récompense), Braise
(brûlure, ralenti, jamais une structure), bonus passés au tueur, Gardien (fosse, 2 briques, annonce, cible, Sceau : dégâts, PV,
refonte de fiche), Colosse (annonce, 3 briques, fureur et remise à zéro, Bannière : porteurs, rappel, sbires × 1,5 et plus gros),
Cœurs vulnérables à la Marée, interface de l'IA, aucune création, coût ; puis un processus à part (horloge à 24:40, × 4) : fin au
temps à 25:00 avec la décision.

Suite demandée, sur une copie de HEAD 0.1.318 + ce lot (`run_tests.py --snap … --reuse -j 2`, machine chargée) : **test_mb_objectives,
test_mb_data, test_mb_map, test_mb_lanes, test_mb_hero, test_mb_shop, test_mode0, test_pvp, test_duel_modes, test_m7, test_royale,
test_texts_fr : 12 verts sur 12**. (Copie : `tools/` de HEAD ajouté à côté de `game/`, que `test_mb_data` lit.)

## 7. Interface pour l'IA (MB-E, MB-G) et pour le HUD (MB-H)

`MobaJungle.current` (ou `MobaDirector.jungle`) : `camps_alive(moitié)` / `camp_list()` -> `{key, camp, kind, half, pos, state, hp,
respawn_in, engaged, danger (part des PV d'un héros perdue par seconde à le tenir), ttk (temps visé seul)}` ; `objectives_state()` ->
`{guardian, colossus : {name, boss, bricks, state, spawn_in, hp, engaged, fury, taken}, seals, banner_until}` ; `buffs_of(héros)` ;
`recall_time(héros)` ; signaux `neutral_down`, `objective_event(clé, announced | spawned | engaged | reset | taken)` ; `said` (annonces).
Aucune vue honnête ici : le coach (MB-G) filtre ce qu'une équipe a pu voir.

## 8. Pièges
1. Un `Monster` libère son nœud à la mort (`queue_free`) : `MobaCamp._on_death` ne l'appelle pas (recyclage, `park` / `revive`).
2. La brique « frenzy » se lance une fois à l'apparition (boucle sur minuteur) : au chargement elle aurait couru avant 9:00 ; la fureur
   du Colosse est tenue par `MobaJungle._fury` (remise à zéro propre).
3. `BossLibrary.spawn` crée le boss par `director._spawn_monster` : la jungle fournit cette méthode (et `message`, `_boss`) ; les briques
   ne passent plus par `bricks_of` quand `ctx.bricks` est donné.
4. Le hasard global est partagé (graines des mesures) : tout ce qui est créé au chargement change la suite des sbires (§ 4).
5. Les héros hors du directeur (sonde, test) ne reçoivent Sceaux, Source et Bannière que s'ils sont dans `MobaJungle.guests`.

## 9. Pour la suite
- MB-D : `recall_time` dans le rappel ; `Moba.team_gold` (or total des équipes) pour la décision au temps ; `reward_objective` si l'XP
  des objectifs doit suivre une autre règle.
- MB-E : jungler (parcours des camps selon `camp_list`), objectifs (`objectives_state`), danger des camps ; mesurer le Colosse.
- MB-H : minuteurs des objectifs (`spawn_in`), Sceaux près du score, Bannière, bonus de camp (`buffs_of`, états `moba_source` /
  `moba_braise` / `moba_banner` déjà nommés).
- MB-J : `TIDE_WAVE_EVERY` (resserrement) à remesurer sur des parties complètes avec héros.
