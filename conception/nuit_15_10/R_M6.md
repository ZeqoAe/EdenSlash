# R_M6 — Ruée des boss et Siège sur la bibliothèque, lisibilité de la difficulté (passe M6)

Retour du joueur : Ruée pas encore testée ; Siège Normal fait, Mythique tenté « vraiment dur, logique : je n'avais pas la
puissance ». Règles : `DESIGN.md`, « Ruée des boss et Siège sur la bibliothèque ». Test : `tests/test_m6.tscn` (44 contrôles) ;
captures : `tests/shot_m6.tscn` (`user://shots/m6_*.png`, copies dans `captures/m6/`, non commitées) ; mesures :
`tools/m6_run.tscn` (Ruée / Siège entiers au pilote) et `tools/m6_probe.tscn` (niveaux, PE, tirages).

## Fait
- **Ruée** (`core/rush.gd`, `core/rush_director.gd`, branché dans `run_director.gd` et `Tower.start_dungeon`) : 8 boss tirés dans la
  bibliothèque, un par zone (niveau croissant ; Mythique : PV × 0,8 → 1,2), mécaniques variées (200 tirages : 42 boss sur 48
  vus, 0,26 famille partagée en moyenne entre deux boss consécutifs, jamais 2), boss du tirage précédent évités (1 repris sur 8),
  graine affichée, « Nouveau tirage », tirage gardé jusqu'à la victoire. Pas de renforts génériques ; carte et 50 % de PV entre
  deux. HUD « Boss 3/8 », sous-ligne « Ensuite : Buka Buka · Normal ». Bilan : boss vaincus, n° du tirage, modificateurs.
- **Idée 1, modificateurs de Ruée** : Sans répit (+30 % de cristaux), Boss enragés (dégâts × 1,25, mécaniques plus fréquentes,
  +40 %), À l'aveugle (boss cachés, +15 %). Gardés d'une Ruée à l'autre, total des cristaux dans la ligne des récompenses.
- **Siège** : boss du jour de la zone (bibliothèque, change chaque jour), lieutenants aux vagues 3 et 5 ; vagues en escouades
  par rôle (P15 : `SpawnDirector.compose / species_for / apply_role`), du bord de l'arène à l'angle d'or, arrivée dans le dos
  signalée, un événement annoncé par vague (tenaille, encerclement, ruée d'essaim, élite escortée, tenaille). Alliés IA en
  comportement d'équipe de M7 (`ClassRival._team_mode` vrai en Donjon / Ruée / Siège : zones rouges, repli, cible faible).
- **Idée 2, objectifs du Siège** : ★ Le boss tombe, ★ Personne ne tombe (HUD « alliés 2/2 »), ★ Avant sa fureur ; +25 % de
  cristaux par objectif secondaire, étoiles gardées par zone et difficulté (page et bilan).
- **Lisibilité** (`ui/difficulty_panel.gd`, pages Ruée et Siège) : PE requise (ou conseillée en Normal) · la tienne + jauge,
  estimation Facile / Équilibré / Difficile / Hors de portée (infobulle : le conseil), récompenses de la difficulté, avertissement
  d'une phrase si c'est trop haut ; la jauge de la difficulté suivante (P6) reste dessous. Aucun pourcentage permanent.

## Mesures (pilote « Bot », héros immortel, coups évités 0,85, totems et cristaux cassés après 8 s ; « perdus » = PV max par boss)
Le pilote n'esquive jamais : même la Ruée d'avant M6 le tue au 1er boss sans immortalité ; on compare donc durée et PV perdus.

| Ruée (tirage 4821 / 1234) | PE | Durée pilote | PV max perdus par boss | Estimation |
|---|---|---|---|---|
| Normal, avant M6 (boss de zone, renforts) | 11,8-13,4 k | 11-16 min | 1,3-7 | — |
| Normal, `2.1.5.2` (4 classes) | 10,8-13,7 k | 10-19 min | 0,3-3,6 (5-9 sur 1 boss) | Équilibré |
| Normal, `1.1.0` / `2.3.10.3` | 5 k / 24-28 k | 28-40 min / 4,7-5 min | 9-24 / < 1 | Hors de portée / Facile |
| Héroïque, `3.1.5.2` / `3.3.10.4` / `4.3.10.4` | 16-18 k / 28-35 k / 32-41 k | 29-31 / 14-15 / 9-15 min | 13 / 3-7 / 0,5-3,6 (guerrier au verrou) | Hors / Difficile / Équilibré |
| Mythique, `3.3.10.4` / `4.3.10.4` | 32 k / 37 k | inachevée / 12 min | 22-800 / 3-23 | Hors de portée |

Siège (Marais, boss du jour Ankit à Miroir ; vagues 23-35 s sauf la 3e) : Normal 5,6 k : boss en 8,5 min, 35 PV perdus ;
`2.1.5.2` (11-13 k) : 8-11 min, vague 3 en 67 s (102 s avec élite escortée + lieutenant ×2 : recalé), boss 4,7-7 min ;
24 k : 4 min, ★★★. Héroïque 35-37 k (sous le verrou 46 k) : 12-19 min ; Mythique 41 k (verrou 61 k) : bloqué à la vague 5.
Le Miroir (Ankit, Barend) gonfle les PV perdus du pilote (il frappe pendant le reflet) : un joueur s'arrête.

## Décisions
- **PE conseillée** (`Rush.ADVISED` [1,3 ; 3,7 ; 3,4], `Siege.ADVISED` [1,3 ; 4,1 ; 3,6] × la PE attendue) : « Équilibré »
  avec l'équipement de l'époque II gagnée en Normal (≈ 11 500, l'ouverture), au verrou en Héroïque, avec l'équipement complet
  optimisé en Mythique (le verrou seul y est « Difficile » : il reste permis, l'avertissement le dit). Seuils 1,35 / 0,95 / 0,7.
- **Verrous et PV inchangés** : le Normal passe à l'ouverture, l'Héroïque au verrou, le Mythique est hors de portée sans
  l'équipement complet (ce qu'a vécu le joueur en mode dev). Rythme : Ruée 10-15 min au pilote en « Équilibré » (comme avant
  M6) ; un joueur qui esquive est estimé 12-20 min ; je n'ai pas monté `RUSH_BOSS` (plus de PV = plus de dégâts subis).
- Siège : lieutenant × 1,6 (pas 2) et événements légers sur les vagues d'élites : la vague 3 durait 3 fois les autres.
- Boss du jour pour le Siège (plutôt qu'au choix) : une idée par écran, de la variété sans menu de plus.

## Reste / pièges
- Le pilote meurt toujours contre les boss (il n'esquive pas) : à confirmer au journal du joueur (mode « dungeon », Ruée / Siège).
- Capture 1280 × 720 : `M6_RES` ne change pas la taille de la fenêtre (projet en 1600 × 900) ; pages vérifiées en 1600 × 900.
- Idées proposées, non faites : vote de difficulté avec les alliés IA, Ruée « boss du jour » commune, classement des tirages.
- Retouches hors lot : `ui/lobby.gd` (pages Ruée / Siège), `ui/hud.gd` (sous-ligne `sub_text`), `ui/dungeon_results.gd`
  (notes, tuiles de la Ruée), `ai/class_rival.gd` (`_team_mode`), `core/tower.gd`, `core/run_director.gd`, `core/dungeons.gd`.
  Le dossier partagé contenait du travail en cours d'autres sessions : tests et mesures sur une copie HEAD + mes fichiers ;
  le commit ne prend que mes morceaux de `lobby.gd`, `hud.gd` et `CLAUDE.md`.
