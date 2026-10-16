# R_BR1 — Battle royale : durée des combats, boule de neige, force des scriptés (16/10/2026, 0.1.219)

Retours du joueur (`RETOURS_JOUEUR.md`, points 2 et 5) + consignes en cours de lot : retirer les deux Lames du tirage,
mesurer nus **et** améliorés, recaler `Royale.AI_GEAR_SCALE` après BR3 (pièces du Survivant), pas de boule de neige.

## Ce qui se passait (point 5)
- Il n'y a ni monstre ni invocation : le « Lame … niveau 24 » est **un des 7 héros scriptés** (Lame noire / Lame de lumière
  sont des classes). Il compte dans « N / 8 en vie » parce que c'est un joueur de la partie ; « donne des niveaux quand il est
  éliminé » = la **prime** (3 éliminations : ★ sur la carte, « Élimine-le : un niveau de plus »). Un scripté mort sort bien de
  `alive_count` et de la place (vérifié en partie et par `test_royale` / `test_br4` ; un revenant de BR4 compte en vie tant
  qu'il doit revenir). Plaque « nom · niv. N » et mini-carte : justes (plaque recalculée toutes les 0,4 s).
- Boule de neige mesurée (6 parties au pilote, 0.1.218) : chaque élimination valait 1 niveau + 25 % des PV quel que soit
  l'écart ; un scripté passait de 23 à 29 en tuant des héros 12 et 16 niveaux plus faibles ; scriptés jusqu'à 21-23 et pilote
  jusqu'à 25 avant le 2e resserrement (245 s), vainqueur au niveau 40. Et un scripté qui éliminait **le joueur ne gagnait
  rien** (oubli : ni expérience, ni PV, ni compteur).

## Décisions
- **Expérience d'une élimination** (`Royale.kill_xp`, joueur et scriptés) : 1 niveau entre égaux, ± 0,15 par niveau d'écart
  avec la victime, de 0,2 à 2 ; la prime ajoute toujours 1. Le scripté qui élimine le joueur gagne comme pour un autre héros.
- **Niveau maximal par anneau** (`Royale.LEVEL_CAPS` 14 / 20 / 26 / 32 / 36 / 40), annoncé à chaque nouvel anneau et dans les
  objectifs (« niveau 12 / 14 ») ; l'expérience en trop est perdue (le joueur garde moins d'un niveau, comme le scripté).
- **Durée des combats** (point 2) : profil `royale` seulement : échelle 0,04 → **0,055** et plafonds du duel équipé
  (critiques ×2 au plus, dégâts +100 %). Mesure : ce sont les critiques qui raccourcissaient les combats équipés ; avec les
  plafonds du duel, nus et légendaires +10 durent à peu près pareil. Duel, Arènes, Gantelet, Siège : profils inchangés.
- **Force des scriptés** (consigne BR3) : `AI_GEAR_SCALE` 0,62 → **1** et PV / attaque **+5 % par niveau au-delà du 3e**
  (+25 % au plus, `Royale.ai_level_factor`) : l'équivalent des cartes de montée de niveau qu'ils ne tirent pas. Le levier
  `AI_GEAR_SCALE` seul ne suffisait pas (0,62 → 1 : force +10 à +18 % ; il manquait +30 à +50 %). Vitesse et qualité de
  ramassage inchangées.
- **Tirage** : jamais la Lame noire ni la Lame de lumière (`Royale.AI_EXCLUDED`). Tournoi 1 contre 1 (60 classes × 10
  adversaires, niveau 15, pièces dorées) : les Lames n'y dominent pas (55 % et 25 %) ; les classes à distance gagnent presque
  tout en terrain nu (Chasseur, Flèche sacrée, Dompteur 100 % ; Voleur, Samouraï, Kage 0 %), mais en partie aucune classe
  n'écrase : laissé tel quel.

## Mesures (avant → après)
| | Avant | Après |
|---|---|---|
| Duel de 2 scriptés de même niveau (`tools/royale_duel_probe`, 8 paires, Hardcore), médianes niveaux 1 / 9 / 20 / 40 × nus / commun / doré / +6 / légendaire +10 | 17-41 s (nus 39-41 s) | **17-31 s** (nus 24-29 s) |
| Combats en partie entre héros d'écart ≤ 2 niveaux (lignes `[royale] élimination`) | médiane 22 s (4 à 58 s ; une fois 154 s) | **14 s** (4 à 30 s) |
| Niveau maximal avant 245 s (2e resserrement) | scriptés 21-23, pilote 25 | **20** |
| Niveau du vainqueur | 19-40 | 17-32 |
| Force √(PV × frappe) scripté / joueur au même niveau, niveaux 1-5 / 6-10 / 11-15, Hardcore | 0.1.214 : 1,10 / 1,24 / 1,06 ; 0.1.218 : 1,02 / 0,86 / 0,82 | **1,09 / 1,09 / 1,04** |
| Idem, Normal | 0.1.214 : 0,67 / 0,74 / 0,69 ; 0.1.218 : 0,61 / 0,49 / 0,47 | **0,69 / 0,78 / 0,77** |

Parties : `world.tscn -- --royale --autoplay --auto-quit` sur une copie, 3 Hardcore + 3 Normal par version (0.1.214
reconstruite, 0.1.218, après), plus 3 de contrôle. Le pilote gagne encore 5 parties sur 6 (2 / 3 en Hardcore) : il pille deux
fois plus de coffres qu'un scripté ; à nombre de coffres égal la force est revenue à celle de 0.1.214.

## Tests
`test_royale` (nouveau `_test_snowball` : écart de niveau, plafonds, force, Lames, échelle et profils des autres modes ;
scripté qui élimine le joueur ; duel 12 à 45 s), `test_e2`, `test_duel_modes`, `test_br3`, `test_br4`, `test_hud` verts sur
HEAD + BR1. `test_m1` : la vérification de la prime suit `kill_xp` ; **9 échecs déjà présents sur HEAD 0.1.218 sans BR1**
(choix de coffre « Facile », fuite / combat au contact, spectateur, bilan : à reprendre après BR3 / BR4). `test_br3` a échoué
une fois sur quatre sous forte charge (« joueur tombé : 0 pièces au sol »), vert les trois autres fois.

## Pièges
- Dossier partagé : mesures et tests sur une copie (`HEAD` + fichiers BR1) ; commit par l'index pour `mode_rules.gd`,
  `player.gd`, `DESIGN.md`, `CLAUDE.md` (travail en cours d'autres sessions dedans).
- J'ai arrêté par erreur deux parties `--royale --autoplay` d'une autre session vers 16 h 30 (filtre sur la ligne de commande).
- `Royale.level_cap_now` est remis à 14 par `Royale.start` et suivi par `RoyaleDirector.update` ; hors partie il vaut 40.
