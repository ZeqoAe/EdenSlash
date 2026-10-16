# R_M8 — La Tour : équilibre entre classes, captures 1280 × 720, esquive du pilote (passe M8)

Règles : `DESIGN.md`, « La Tour : types d'étage », point « Équilibre entre classes ». Test : `tests/test_m8.tscn` ; captures :
`tests/shot_m8.tscn` (`M8_RES=1280x720` ou `1600x900`, `user://shots/m8_<taille>_*.png`, copies dans `captures/m8/`, non commitées) ;
mesures : `tools/m8_tower.tscn` (une ligne `[m8-étage]` par étage : type, issue, durée, PV perdus, temps pour tuer le boss, part du
combat où le boss ne perd aucun PV, cause des dégâts zone / flaque / autre ; `--plan` : plan des étages) et `tools/m8_matrix.py`
(lance une liste de mesures en parallèle sur une copie propre, `solo` régénère `data/tower_solo.json`).

## Diagnostic : classe ou pilote ?
Protocole commun : 8 classes de 4 familles (Samouraï, Voleur = mêlée ; Chasseur, Magicien = distance ; Clerc, Barde = soutien ;
Guerrier, Templier = tank), équipement attendu de l'étage (`1.3.5.1` jusqu'au 50, `2.3.10.3` au 60, `3.3.10.4` au 100, `4.3.10.4` au-delà),
aide « Bot » du jeu (`--pilot=bot`), Normal.
- **Pilote** : le pilote de mesure (`autoplay`) et l'aide « Bot » donnent le plus souvent les mêmes temps pour tuer (à 10 % près). Sans
  esquive, le pilote meurt partout entre les étages 11 et 50 (14 tranches de 10 étages finies sur 48) : 50 à 90 % des PV perdus viennent des **zones rouges annoncées**,
  qu'il ne lit pas. Avec une esquive : 33 / 48. Les écarts de survie de M3 venaient surtout du pilote.
- **Classe** : sans mécaniques (`--pure`), l'écart de temps pour tuer entre les 60 classes est de 2,6 (étage 30), 2,2 (50), 3,5 (100) :
  c'est le kit (Barde, Templier, Aube…, soutiens et tanks), pas les briques de boss (mécaniques comprises : 1,9 à 2,8, le même ordre).
- **Bug** : un boss poussé hors de la salle tombait sans fin, intouchable (Homme de paille de l'étage 40 à 18 % de ses PV, des km plus bas
  au bout de 3 min ; d'où les « 600 s » et les distances absurdes de certaines mesures).
- Briques : aucune cible inatteignable en mêlée ; les mêlées mouraient d'abord sous les zones du boss (Bond + Arène qui se resserre au 10).

## Corrections (jeu)
1. **Dégâts × facteur par classe dans la Tour** (`TowerBalance.solo_mult`, `data/tower_solo.json`) : temps pour tuer brut des 60 classes aux
   boss 30, 50, 100 (sans mécaniques), à son pire boss, ramené à 1,1 × la médiane ; jamais de baisse ; au plus × 1,8. 33 classes aidées
   (Barde 1,54, Aube 1,51, Arbitre 1,43, Équilibriste 1,42, Templier 1,28…). Tour seulement (pas Donjons, Ruée, Siège), héros du joueur.
2. **Coups de boss de la Tour plafonnés à 25 %** des PV max (`Tower.BOSS_HIT_CAP`, option `hit_cap` de `BossLibrary.spawn`, 40 % ailleurs).
3. **Boss ramené au centre** s'il sort de la salle (`TowerDirector._rescue_boss`, Tour, Donjons, Ruée, Siège).
4. **Courbe** : `BOSS_FLOOR_ADJ` 100 × 0,7 (médiane 2 min 47, deux fois ses voisins), 150 × 2,5 (13 s à 2 min 20, médiane 43 s). Ailleurs
   la progression est douce : boss 10-50 en 1 min 10-2 min 20, 60 en 50 s-1 min 30 (équipement de l'époque II).
5. Interface : barre du boss « 39 045 / 39 044 » (PV arrondis différemment) ; page des étages en 1280 × 720 : l'étage choisi caché
   sous le bouton épinglé, maintenant visible (`ensure_control_visible`).

## Mesures avant / après
Temps pour tuer (s) du boss, mécaniques comprises, héros invincible, aide « Bot » :

| Boss | Samouraï | Voleur | Chasseur | Magicien | Clerc | Barde | Guerrier | Templier | max / min |
|---|---|---|---|---|---|---|---|---|---|
| 10 Poing de pierre | 98 → 90 | 87 → 82 | 95 → 95 | 68 → 68 | 87 → 82 | 135 → 88 | 90 → 90 | 118 → 91 | 2,0 → 1,4 |
| 20 Mori | 97 → 85 | 84 → 77 | 98 → 98 | 74 → 74 | 90 → 79 | 140 → 94 | 83 → 83 | 108 → 85 | 1,9 → 1,3 |
| 30 Buster | 105 → 85 | 96 → 80 | 90 → 90 | 69 → 69 | 94 → 79 | 158 → 99 | 83 → 83 | 117 → 93 | 2,3 → 1,4 |
| 40 Homme de paille | 104 → 100 | 99 → 92 | 99 → 99 | 76 → 76 | 103 → 89 | 213 → 109 | 91 → 91 | 157 → 111 | 2,8 → 1,5 |
| 50 Angela | 143 → 138 | 125 → 114 | 156 → 156 | 112 → 112 | 129 → 116 | 214 → 148 | 114 → 114 | 183 → 135 | 1,9 → 1,4 |
| 60 Starnoc | 77 → 69 | 52 → 50 | 85 → 85 | 66 → 66 | 82 → 74 | 77 → 51 | 65 → 65 | 106 → 88 | 2,0 → 1,8 |
| 100 Double-porte | 129 → 90 | 94 → 62 | 133 → 96 | 90 → 64 | 250 → 161 | 185 → 92 | 165 → 120 | 249 → 141 | 2,8 → 2,6 |

60 classes, sans mécaniques (bornes de `test_m8`) : 2,57 → 1,86 (30), 2,17 → 1,79 (50), 3,47 → 2,30 (100).

Survie aux boss 10, 20, 30, 40, 50, 60, 100 (2 graines, pilote qui esquive, `--human=0.5`), boss battus sur 14 :
« avant » = pilote du début de passe (sans esquive des enchaînements ni recul), « pilote M8 » = pilote final sur le jeu d'avant :

| Classe | Avant | Pilote M8, jeu d'avant | Après |
|---|---|---|---|
| Samouraï / Voleur | 4 / 3 | 9 / 8 | 11 / 8 |
| Chasseur / Magicien | 3 / 13 | 7 / 12 | 12 / 14 |
| Clerc / Barde | 10 / 10 | 11 / 11 | 14 / 13 |
| Guerrier / Templier | 9 / 7 | 13 / 11 | 14 / 11 |
| Total | 59 / 112 | 82 / 112 | **97 / 112** |

Temps pour tuer des survivants (boss 10-60, médiane) : 111 s (Magicien) à 254 s (Barde), 2,3 → 93 à 178 s, 1,9.
Ascension 1-10, 21-30, 41-50 (8 classes, pilote M8) : 240 étages sur 240 franchis ; étage de monstres 38 à 127 s, tranche de 10 étages
6 à 21 min au pilote. Avant : 6 tranches sur 24 perdues (boss 10, 30, 50).

## Pilote qui esquive (`--dodge`, `PilotDodge`, mesures seulement)
Option de `tools/m8_tower`, `tools/tower_run`, `tools/boss_ttk` (`PilotDodge.enabled`, faux en jeu ; crochets dans `Player` sans effet
sinon). Le pilote lit 85 % des zones rouges d'un adversaire après 0,3 s, marche vers le bord le plus proche, esquive à 0,35 s de
l'impact (même au milieu d'un enchaînement), ne lance pas de sort dans une zone, reste en deçà du mur d'une arène qui se resserre ;
un tireur recule 0,8 s quand on l'approche, puis tire au moins 2 s. Gain : PV perdus par étage de monstres 0,58 → 0,13 ;
tranches de 10 étages finies 14 → 33 / 48 (pilote du début), boss battus 59 → 82 / 112 (pilote final, jeu inchangé).

## Captures 1600 × 900 et 1280 × 720 (`shot_m8`, 22 écrans chacune, regardées)
Page Tour, étages, 4 fiches, Ruée, Siège, Donjons (haut et bas), HUD Tour (élites, boss), Ruée, Siège, bilans Tour, Ruée, donjon,
Siège : aucun texte coupé ni chevauchement ; corrigés : barre du boss, étage choisi caché. `shot_m6` ne changeait pas la taille
(la résolution des paramètres l'écrasait) : `shot_m8` la pose après `Settings.reset_all()`, par `M8_RES` (un argument `--` lancerait une run).

## Reste / pièges
- Boss 150 et 200 : écarts 2,9 et 4,3 (Abby, Wushu) ; l'aide « Bot » vise le monstre le plus proche (illusions, familier) : à revoir
  avec le ciblage, pas avec des PV. Double-porte (100) à 2,6 mécaniques comprises (2,3 sans) : bruit d'une mesure par classe.
- Voleur : 8 / 14 boss battus au pilote (le plus fragile au contact) ; à confirmer au journal du joueur.
- Le multiplicateur suit le kit du préréglage par défaut ; un joueur qui change de sorts peut être plus ou moins rapide.
- Mesures longues : 15 à 35 processus Godot en parallèle (d'autres sessions) ; certaines lignes « temps » viennent de délais.
- Hors lot : `ui/hud.gd`, `ui/lobby.gd` (une ligne chacun), `player/player.gd` (multiplicateur, crochets du pilote), `core/tower.gd`,
  `core/tower_director.gd`, `core/siege_director.gd` (une ligne), `core/boss_library.gd`, `tools/tower_run.gd`, `tools/boss_ttk.gd`.
  Le commit 0.1.210 (S8) a emporté une première version du point « Équilibre entre classes » de `DESIGN.md` ; corrigé ici.
