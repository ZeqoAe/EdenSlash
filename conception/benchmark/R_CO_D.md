# R_CO_D : Le Colisée, lot CO-D — IA d'équipe (17-18/10/2026)

Étude : `ARENA.md` § 6.9 (IA à 4 difficultés, chef d'équipe), § 6.15 (pièges 4 et 5), backlog n° 5 et 15 ; socle : `R_CO_A.md`,
`R_CO_B.md`, `R_CO_C.md`. Mode scellé, IA scriptée seule (aucun cerveau). Travail fait sur une machine saturée (20 à 80 Godot
d'autres sessions, deux pauses imposées) : toutes les mesures notent la charge ; chaque partie a un délai maximal.

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Chef d'équipe | `game/scripts/ai/colisee_coach.gd` (`ColiseeCoach`) | un par camp et par combat (créé par `ColiseeDirector._start_fights`), décide 4 fois par seconde (2 fois dans un combat caché), donne à chaque héros scripté un ordre ; réglages par niveau `LEVELS` |
| Héros scripté | `game/scripts/ai/class_rival.gd` | lit l'ordre (`coach_order`) : cible (`pick_target`), point à rejoindre (`_coach_goal`), rentrer dans l'anneau (`_coach_escape`), longer le bord (`_coach_steer`), esquive renvoyée dedans (`_coach_inside`), seuil de soin (`_support_tick`), attention partagée (`_attention`, `_team_read`) ; rien ne change hors du Colisée (ordre vide, `arena_id` < 0) |
| Directeur | `game/scripts/core/colisee_director.gd` | chefs créés et avancés, mesures par combat (premier coup, dégâts par camp, secondes dans le feu, fleurs, décisions des chefs), ligne JSON de la partie, banc IA contre IA (`--co-watch` : le joueur au repos, son trio joué par 3 héros scriptés ; `--co-even`, `--co-coach=`, `--co-diffs=`, `--co-rule=`, `--co-tune=`) ; changements de scène par `LoadScreen` (lot PERF-1) |
| Difficultés | `game/scripts/core/colisee.gd` (`DIFFS`), `ui/colisee_page.gd` | **Recrue, Vétéran, Champion, Légende**, Mélange ; échelle des dégâts du mode 0,030 → **0,045** (§ 4.3) |
| Banc | `tools/colisee_games.py` | parties complètes IA contre IA en parallèle (`-j`), une ligne JSON par partie (`--jsonl`), rapport (`--report`) |
| Test | `game/tests/test_co_d.tscn` | § 6 |

## 2. L'IA

**Héros** (`ClassRival`, inchangé dans son jeu : esquive des zones rouges de tous les héros adverses de son arène, combos, sorts,
retraite sous 30 % des PV, soutien de son trio) + **chef** qui lui dit quoi viser et où aller. Le joueur n'est jamais piloté : il compte
dans son trio (force, centre du groupe) et ses alliés ont la difficulté choisie.

| Niveau (= difficulté du trio) | Cible | Anneau de feu | Fleurs | Protection | Approche | Autres |
|---|---|---|---|---|---|---|
| **Recrue** | aucune (la plus proche, comme avant) | rentre après 0,9 s dans le feu | — | — | — | — |
| **Vétéran** | commune : la plus basse en PV, proche (bruit 35 %) | rentre après 0,35 s, longe le bord, prend l'anneau suivant 1 s avant | sous 35 % des PV | — | — | — |
| **Champion** | commune : danger ÷ (temps pour l'abattre + temps pour l'atteindre) ; bruit 15 % ; garde sa cible 1,5 s au moins | aussitôt, 2,5 s d'avance, 1,2 m de marge ; la mêlée ne suit pas sa cible dans le feu ; une cible dans le feu vaut plus | sous 50 %, si la voie est libre | tank et mêlée frappent le plongeur d'un tireur / soigneur (gardé 1,5 s), le tireur plongé s'écarte entre deux coups | personne ne part seul devant | soigneur : sous 60 % |
| **Légende** | idem sans bruit, cible contrôlée d'abord (combo) | 4 s d'avance (dès l'annonce), 1,5 m de marge | sous 55 % | idem | idem ; attend un trio plus fort (PV × frappe < 0,8) au plus 10 s | soigneur : sous 65 % |

- **Danger** d'un adversaire : rôle (soin 1,35 > tireur 1,2 > mêlée 1 > tank 0,7, ordre de l'étude) × sa frappe relative amortie de
  moitié ; **temps pour l'abattre** : PV ÷ dégâts subis (barrière, invulnérabilité) ÷ frappe du trio.
- **Attention partagée** (règle de perception du mode, tous les héros scriptés du Colisée) : visé par plusieurs adversaires dans la
  dernière seconde, la chance de lire un coup est plafonnée à 0,75 puis × 0,5 par adversaire de plus (deux : 0,375 ; trois : 0,19) ;
  idem pour l'esquive réflexe après un coup reçu. Seul contre un : la lecture de sa difficulté (Légende 0,95). Sans elle, le tir groupé
  ne servait à rien contre des Champion / Légende (§ 4.2).
- **Relève** : la règle n'existe pas encore (lot CO-J). Point d'extension `ColiseeCoach.revive_fn` (allié à terre → point de relève) :
  le chef y envoie le plus proche sans adversaire à 6 m (n'importe qui si son trio est plus fort), un seul à la fois.
- **Choix** (point d'extension des lots CO-E / CO-F, branché par l'équipe CO-3 dans `ColiseeAnvil._coach_pick`) :
  `ColiseeCoach.choose_augment(offres, classe, difficulté, trio, rng)` et `choose_anvil(…)` rendent l'indice choisi : Recrue au
  hasard, Vétéran note bruitée (± 60 %), Champion note + synergie (± 25 %), Légende note + synergie sans bruit. Une offre déjà notée
  par rôle (`ColiseeAugments.offer_dicts` : « score ») ne l'est pas deux fois ; une offre de soin pour un non-soigneur vaut × 0,15.

## 3. Le banc

`python tools/colisee_games.py --setup <réglage> --games N -j 2 [--format --diffs --coach --even] [-- --co-rule=clé:val --co-tune=clé:val]`
lance `world.tscn -- --colisee --co-watch --autoplay --auto-quit --co-nofallback` (préparation de 1 s, pas de repli au tableau : de vrais
combats seulement), lit `[colisee] partie {…}` et rapporte : manches gagnées entre réglages, durée des combats (miroirs par réglage),
passivité (premier coup, dégâts par seconde du camp le plus faible), feu, fleurs, décisions des chefs, familles et classes (combats
miroirs), durée des parties. Réglages : `lr` / `lr_even` (Légende contre Recrue, fiches du jeu / fiche égale), `chef1-3` (avec chef
contre sans chef, fiche égale), `jeu`, `jeu1`, `jeu3` (toutes de même difficulté), `echelle(_even)`, `grand`.
**Fiche égale** (`--co-even`) : sans le facteur de PV et de dégâts par difficulté (`ClassRival.DUEL_DIFF` 0,6 / 0,8 / 1 / 1,2) : seul le
jeu compte. Délai : 900 s par partie (une erreur de script fige le jeu sans le quitter).

## 4. Mesures (copies propres de HEAD + ce lot, -j 2, atouts et enclumes des lots CO-E / CO-F compris à partir de § 4.2)

### 4.1 Premier état (échelle 0,030, sans attention partagée ; HEAD 0.1.305)
| Réglage | Combats | Résultat |
|---|---|---|
| Légende contre Recrue, fiche égale | 21 | **100 %** des manches |
| Champion avec chef contre sans chef, fiche égale | 46 | **97,8 %** |
| Miroirs Légende (avec chef) | 16 | **16 au temps (85 s)** : plus personne ne meurt dans le feu ni ne laisse passer un coup |
| Miroirs Champion avec chef / sans chef | 32 / 13 | médiane 85 s (27 au temps) / 44 s |

Le chef rendait les trios trop sûrs : sans lui, les héros finissaient dans le feu (26 s-héros dehors par combat) ; avec lui, aucun
miroir ne finissait. D'où les trois réglages suivants, chacun mesuré au banc avant d'être gardé.

### 4.2 Réglages essayés (miroirs Champion, Éclair, 2 parties chacun, 21-24 combats, 40-80 Godot actifs)
| Essai | Médiane | Au temps |
|---|---|---|
| base (attention 0,6) | ~85 s | la moitié |
| échelle 0,040 | 68,2 s | 4 / 22 |
| attention 0,4 | 80,4 s | 7 / 21 |
| sans fleurs, soins à 50 % | 85 s | 14 / 22 |
| échelle 0,045 + attention 0,5 | 56,0 s | 4 / 24 |
| échelle 0,055 + attention 0,5 | 61,4 s | 1 / 22 |

Deux défauts du chef trouvés dans les journaux et corrigés : le tireur plongé ne faisait que fuir (≈ 70 écarts par combat, il ne tirait
plus) → il tire dès que son coup est prêt et ne s'écarte qu'entre deux coups ; le tank allait et venait entre plongeur et cible commune
à chaque décision → il garde le plongeur 1,5 s. Puis, les miroirs Légende restant longs (71,5 s, 15 au temps sur 45), le plafond de
lecture à 0,75 quand on est visé par plusieurs.

### 4.3 État livré (échelle 0,045, attention 0,5, plafond 0,75)
Miroirs par difficulté (Éclair, 4 parties chacun sauf Légende, 44-47 combats ; HEAD 0.1.315) :

| Miroir | Combats | Médiane (p10-p90) | Au temps | Premier coup (méd.) | Feu (s-héros / combat) |
|---|---|---|---|---|---|
| Recrue | 44 | **54,5 s** (36,6-68,3) | 0 | 1,4 s | 15,8 |
| Vétéran | 46 | **48,2 s** (29,0-69,7) | 0 | 1,0 s | 0,3 |
| Champion | 44 | **57,3 s** (33,6-77,4) | 1 | 1,0 s | — |
| Légende (avant le plafond) | 45 | 71,5 s (60,7-85) | 15 | 1,4 s | 9,4 |
| **Légende (livré)** | 22 | **61,5 s** (40,7-82,6) | 2 | 1,1 s | 5,9 |

Parties Classique (6 trios, fiches du jeu sauf mention) :

| Réglage | Parties | Résultat |
|---|---|---|
| Légende contre Recrue (`lr`) | 2 (24 combats) | **100 %** ; miroirs Légende 50,1 s, Recrue 44,3 s |
| Légende contre Recrue, fiche égale (`lr_even`) | 3 (36 combats) | **100 %** ; miroirs Légende 56,0 s, Recrue 62,4 s |
| Échelle, fiche égale (`echelle_even` : 0, 1, 2, 3, 1, 2) | 2 | Légende bat Champion 10 fois sur 11, Champion bat Vétéran 13 / 13, Vétéran bat Recrue 4 / 4 |
| Champion avec chef contre sans chef, fiche égale (`chef2`) | 3 (44 combats) | 65,9 % (le trio sans chef lisait encore tout : voir ci-dessous) |
| Partie du jeu, toutes Vétéran (`jeu1`) | 2 (47 combats) | combats 43,4 s de médiane (22,8-75,4), 0 au temps ; 11 manches ; ≈ 16 min avec 30 s de préparation |

`chef2` après le plafond de lecture : la règle d'attention ne valait que pour les héros qui ont un chef, donc le trio « sans chef »
esquivait mieux qu'un trio du jeu ; elle vaut maintenant pour tout héros scripté du Colisée (règle du mode) : mesure refaite § 4.4.

**Passivité** : premier coup entre trios à 1,0-1,6 s de médiane, 6,7 s au plus sur toutes les parties ; aucun combat sans coup ; le camp
le plus faible inflige 300 à 800 dégâts par seconde de médiane (le 0 du minimum : un trio Recrue effacé avant d'avoir frappé).
L'attente de la Légende (trio plus faible) dure 0,1 à 0,4 s par combat en moyenne : elle ne bloque jamais un combat.

**Familles** (combats miroirs, part des combats gagnés quand la famille est dans le trio, tous réglages livrés confondus, ≈ 40-80
combats par famille et par réglage) : Guerriers 43-75 %, **Combattants 31-46 %** (la mêlée agile est la plus faible : elle ne suit
plus sa cible dans le feu et se fait écarter par les tireurs), Tireurs 44-61 %, Soutiens 50-57 %, Mages 39-61 %. Aucune famille
au-dessus de 2 fois sa part ; les Combattants restent sous la moitié à toutes les difficultés : à reprendre au lot CO-I (calibrage)
avec les atouts.

**Durée d'une partie** : 10-11 manches, 9,4-11,2 min de jeu avec 1 s de préparation, soit 14,7-16,1 min avec les 30 s de l'étude
(cible 17-21 min : les combats sont plus courts que les 60 s du modèle ; au lot CO-I).

### 4.4 Confirmation (attention partagée pour tous)
Voir la fin du rapport (§ 8).

## 5. Performances (sonde `tools/colisee_probe.tscn`, Légende, 30 s, graine 4242)

| Cas | Image médiane | p95 | Godot actifs |
|---|---|---|---|
| 24 héros, calcul seul, **sans chefs** (`--co-coach=-1,…`) | 6,13 / 5,81 ms | 58 / 40 | 41 |
| 24 héros, calcul seul, **avec chefs** | 6,69 / 6,55 ms | 40 / 66 | 45-49 |
| 18 héros, calcul seul | 5,63 ms | 71 | 56 |
| **18 héros avec rendu** (fenêtre) | **7,88 ms** | 11,2 | 41 |
| **24 héros avec rendu** (fenêtre) | **9,11 ms** | 13,3 | 37 |

Le chef coûte ≈ 0,6 ms d'image médiane à 24 héros (calcul seul, mêmes conditions ; surtout du jeu en plus : chemins vers les fleurs
et les points d'écart, plus de coups) ; depuis, les combats cachés ne décident plus que 2 fois par seconde (`TICK_HIDDEN`). Avec rendu
et 37-41 Godot actifs (4 fois la charge du lot CO-C), 18 héros tiennent le budget de 8 ms ; 24 héros le dépassent de 1,1 ms. Le lot
CO-C mesurait 7,1-7,6 ms avec 8-10 Godot : **à remesurer au calme** avant de décider du Grand tournoi (critère de l'étude : 8 ms).

## 6. Tests

`test_co_d` (≈ 45 contrôles) : noms et rôles ; choix d'atouts et d'enclumes (soin au soigneur, jamais au guerrier, arc au tireur,
hasard de la Recrue, synergie, meilleure pièce, offre vide) ; décisions du chef sur des trios posés à la main (cible commune = le
soigneur à PV égaux, un adversaire presque à terre la prend, cible posée tout de suite, protection du tireur plongé et écart, Recrue
sans chef, fleur au blessé, fleur gardée par un adversaire évitée, seuils par niveau, cercle sûr avec l'avance du resserrement,
cohésion, attente bornée) ; guidage du héros (rentrer, longer le bord, esquive renvoyée dedans) ; une manche réelle IA contre IA
(Éclair, Légende contre Recrue, fiche égale : un chef par camp, un ordre pour chaque héros, cible commune tenue 71 relevés sur 80,
combats finis, coup avant 15 s, les deux camps frappent, ligne JSON).

Suite (copie de HEAD 0.1.320 + ce lot, `run_tests.py --reuse -j 1`) : voir § 8.

## 7. Pièges pour la suite

1. Un changement d'IA se mesure au banc (`tools/colisee_games.py`) **avant** d'être gardé ; les mesures varient beaucoup selon les trios
   tirés (± 10 s de médiane d'une graine à l'autre) : 40 combats au moins par réglage.
2. Ne jamais lancer le banc sur une copie dont la base diffère de la base de l'overlay (un script qui ne compile pas fige Godot sans le
   quitter) : d'où le délai par partie.
3. `ColiseeDirector.watch_only`, `even_sheets`, `coach_levels` et `ColiseeCoach.tune` sont statiques : un test qui les pose les remet.
4. L'échelle 0,045 change l'équilibre mesuré des atouts (lot CO-E, mesuré à 0,030) : leur contrôle est à refaire au lot CO-I.
5. Grand tournoi : à remesurer au calme (§ 5).

## 8. Confirmation finale

Attention partagée étendue à tout héros scripté du Colisée (avec ou sans chef), échelle 0,045, décisions des combats cachés à 0,5 s ;
copie de HEAD 0.1.320 + ce lot, 30 à 50 Godot actifs :

| Réglage | Combats | Résultat |
|---|---|---|
| **Champion avec chef contre sans chef**, fiche égale (`chef2`, 3 parties) | 40 | **72,5 %** (critère de l'étude : 70 %) ; miroirs 52,6 s avec chef, 48,2 s sans |
| **Légende contre Recrue**, fiche égale (`lr_even`, 2 parties) | 22 | **100 %** (critère : 85 %) ; miroirs Légende 63,9 s, Recrue 61,3 s |
| Miroirs Légende, Éclair (2 parties, autres graines) | 25 | 74,5 s de médiane, 6 au temps |

Bilan des critères :
- Légende bat nettement la Recrue : **100 % des manches** sur 3 séries (81 combats), fiches du jeu ou fiche égale. ✔
- Chef contre sans chef (Champion, fiche égale) : 72,5 % (97,8 % avant que la règle d'attention ne vaille pour tous). ✔
- Durée des combats entre trios de même difficulté : Recrue 54,5 s, Vétéran 43-48 s, Champion 52-57 s : **dans 50-60 s ou juste
  sous** ; **Légende 50-75 s selon les trios** (au temps 1 fois sur 10 à 1 sur 4) : **pas tenu**, à reprendre (lot CO-K, IA Légende :
  leviers mesurables `--co-tune=read_cap:…`, `--co-tune=attention:…`, ou au lot CO-I un dernier resserrement de l'anneau).
- Aucune équipe passive : premier coup à 1-1,6 s de médiane (6,7 s au plus), aucun combat sans coup. ✔
- Familles : aucune au-delà du double de sa part ; Combattants faibles (31-52 %). ~
- Budget d'image : 18 héros avec rendu 7,9 ms ✔ ; 24 héros 9,1 ms sous une charge 4 fois plus forte qu'au lot CO-C : à remesurer au calme. ~

Tests (copie de HEAD 0.1.320 + ce lot, `-j 1`) : **test_co_a, test_co_b, test_co_c, test_co_d, test_co_e, test_co_f, test_mode0,
test_pvp, test_duel_modes, test_m7, test_royale, test_texts_fr, test_nav_screens verts** ; `test_perf1` rouge sur une image de
433 ms au fondu de carte de la Survie (« carte suivante », machine chargée, sans lien avec le Colisée ; aucun changement de scène du
Colisée n'est plus « à brancher » : `LoadScreen.go` / `LoadScreen.to_lobby`). Une partie du banc sur 60 s'est arrêtée sur un plantage
du moteur (code 0xC0000005) à la 1re manche ; relancée seule avec la même graine, elle va au bout.
