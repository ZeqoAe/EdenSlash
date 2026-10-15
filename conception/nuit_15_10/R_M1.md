# R_M1 — Battle royale : héros scriptés, détails, idées, équilibre (version 0.1.201)

Retour du joueur (note du 15/10 17:22, seule note de `feedback/` sur le Royale) : « même en hardcore les bots sont trop faibles
en farm : je suis niveau 10 quand eux sont 4, ils ne se déplacent pas avec le dash ». Ajoutée à `feedback/_SUIVI.md` (traitée).

## Fait
**1. Héros scriptés** (`ai/class_rival.gd`, `core/royale_director.gd`, `core/royale.gd`)
- Trajet : course d'un héros (`Player.BASE_SPEED` × vitesse de la classe) + esquives de trajet de 6 m en 0,32 s (celles du
  joueur, sans user les charges de combat), une sur quatre en saut + esquive en l'air. `ClassRival.TRAVEL_GAP` par difficulté.
  Mesuré sur sol plat (test_m1) : Facile 7,7 m/s, Hardcore 10,9 m/s (avant ≈ 5-7 ; joueur qui court 6,5, qui esquive ≈ 11).
- Ils cassent jarres et caisses en passant (même expérience que le joueur, `Royale.BREAK_XP`) et vont en casser quand aucun
  coffre n'est à portée (mode B).
- Cerveau `RoyaleDirector.BRAIN` (Facile → Hardcore) : vue, rapport de forces `Royale.power_ratio` (PV × frappe) pour attaquer,
  fuite s'il est dépassé et a une potion (pas deux fuites de suite), traque des affaiblis / occupés / mis à prix à partir du
  3e anneau, coffres choisis par valeur / trajet et à moitié prix si un adversaire y arrive avant (Difficile, Hardcore),
  potion bue plus tôt en Hardcore. Pièce gardée = meilleure note pondérée de la classe (`Items.rating`, profil E3).
- Garde-fous mesurés : poursuites abandonnées au bout de 5 s hors de portée, combat égal rompu après 20 s pendant les deux
  premiers anneaux, exigence d'attaque qui baisse à chaque anneau (`ENGAGE_RAMP`) : pillage d'abord, combats à la fin.

**2. Passe de détails** (captures `shot_m1` regardées une à une, compte neuf et avancé)
- Lobby : la difficulté choisie reste cochée d'une partie à l'autre ; 3 lignes (largages, anneau, mis à prix).
- Spectateur après la mort : la caméra et la mini-carte suivent le tueur puis le mieux placé, barre du bas cachée, « Tu
  regardes X » ; Échap / Options ouvre le bilan ; la place est fixée à la mort (avant : bilan forcé 3 s après). « Abandonner »
  en spectateur garde sa place (avant : 8e). Durée du bilan = temps de survie du joueur.
- Fil des éliminations sous la mini-carte (4 lignes, 8 s ; les tiennes en or) au lieu du message central.
- Bilan : maîtrise dans « Gagné » avec sa valeur (avant : ligne brute « Maîtrise : +20 » dans Gardé), accords (1 coffre).
- Pause : ni or / clés / cristaux, ni trophées ; chiffres de la partie (en vie, éliminations, coffres, soins).
- Cadre de cible : « Chantre de vie · niv. 1 — Nv 1 » en double corrigé (nom seul, le niveau sur la plaque).
- Plantage trouvé en mesure : les héros morts sont libérés, la ligne de fin lisait leurs données (`ai_stats` gardé à part).
- `--auto-quit` pour le Royale (mesures), pilote automatique qui esquive en trajet (joueur moyen).

**3. Idées (5 proposées, 2 faites)** : **largages annoncés** (à chaque resserrement sauf le dernier, coffre de 4e qualité dans
le prochain anneau 15 s plus tard, pilier doré, étoile visible de partout) et **mis à prix** (3 éliminations ou plus : visible
de tous, prime d'un niveau). Proposées : contrats de partie (3 mini-objectifs), zone de puissance dans l'anneau (expérience
en y restant), série d'éliminations (annonce + vitesse). Ajout nécessaire : **réapprovisionnement** (coffres dans l'anneau à
50 s puis à chaque resserrement / nouvel anneau) : les 64 coffres de départ partaient en 45 s.

**4. Équilibre** : anneau 3 min 30 → 9 min 50 (5 resserrements), échelle des dégâts du mode 0,05 → 0,04 (`ModeRules.ROYALE`).

## Mesures (`world.tscn -- --royale --autoplay --auto-quit --royale-diff=N`, 6 parties, réglage final)
| | avant (0.1.193, Hardcore) | après |
|---|---|---|
| niveau à 3 min : joueur / bots (moy.) | 5 / 3-6 à 2 min 15 (partie finie à 2 min 25) | 14-18 / 10,7-13,4 |
| niveau à 6 min : joueur / bots | — | 22-30 / 15-26 |
| durée, joueur vainqueur (5 parties) | 2 min 25 | 6 min 38 à 8 min 17 (moy. 7 min 06) |
| durée, joueur éliminé tôt (bots seuls) | — | 9 min 47 |
| part du temps des bots (1er / 2e anneau) | combat ≈ 45 % | pillage 49+27 / combat 29 ; 112+87 / 82 |

Vidage : les 64 coffres de départ en ≈ 45 s ; 20-50 coffres restent sur la carte à la fin grâce aux vagues.
Le pilote automatique (qui pille sans se battre) reste en tête après 5 min : il gagne 5 parties sur 6 et fait 4-6 éliminations.

## Reste / pièges
- Durée sous 8 min quand le joueur domine (le pilote ne fuit jamais et fait boule de neige) : à revoir avec des parties réelles.
- Duo / trio, cerveaux du Panthéon en adversaires : non faits. Les 3 idées non retenues ci-dessus.
- Des blocs blancs à cristaux (objets cassables « gem » de certains biomes) paraissent sans texture sur les captures : hors lot.
- Dossier partagé cassé par moments (classes d'autres lots en cours) : tests et mesures sur une copie `HEAD + mes hunks`
  (patch filtré par motifs) ; le commit ne contient que mes hunks.
- Une commande `taskkill /IM` a arrêté trois Godot en mesure (les miens, d'après les PID et les tâches).
Tests verts (copie HEAD 0.1.199 + M1) : test_m1 (23), test_royale, test_results, test_nav_screens, test_p4_activities,
test_hud, test_build.
