# R_AC_J — L'Échiquier, lot AC-J : mesure et calibrage (17/10/2026)

Versions : **0.1.252** (simulateur recalé + outils), **0.1.253** (mesure de référence + `test_ac_sim_real`), **0.1.255**
(rééquilibrage par les données). Toutes les mesures de parties sont faites au simulateur AC-C recalé (le vrai combat sert
au calage) ; les parties sont jouées par les IA d'AC-D, sans joueur humain.

## 1. Simulateur recalé sur le vrai combat (AC-U, `dmg_scale` 0,12 puis 0,11)
Procédure de R_AC_C : `autochess_fight.tscn --calib` (2 × 100 combats au hasard, graines 1 et 2), puis `--compare --sweep`.

| Réglage `AutochessSim.TUNE` | Avant (AC-C) | Après | Pourquoi |
|---|---|---|---|
| `auto_lock` | 1,8 s | **1,5 s** | rythme des auto-attaques du vrai : 0,58 / unité-s (simulé 0,54 avant, 0,58 après) |
| `zone_dodge` | 0,7 | **0,6** | touches par sort du vrai : 0,79-0,83 (simulé 0,61 avant, 0,76-0,83 après) |
| `move_fudge` | 0,85 | **1,0** | l'IA d'AC-U ne tourne plus autour de sa cible : course pleine |

| Accord (100 combats par jeu) | Avant recalage | Après (0,12) | Après rééquilibrage (0,11, mana par rôle) | Cible |
|---|---|---|---|---|
| même vainqueur | 89 / 89 % | **93 / 92 %** | **88 / 89 %** | ≥ 85 % |
| écart de durée médiane | 7 / 8 % | **4 / 3 %** | **4 / 1 %** | ≤ 20 % |
| survivants (écart moyen) | 0,62 / 0,66 | 0,58 / 0,67 | 0,76 / 0,70 | ≤ 1,5 |

- La grille autour des réglages retenus (auto_lock 1,4-1,5, zone_dodge 0,55-0,65, spell_lock 1,0-1,2) ne gagne rien de
  stable sur les deux jeux (±2 points, le bruit du vrai combat est de ≈ 7 points, R_AC_C) : TUNE gardé après le rééquilibrage.
- Par unité (`--units`) : 3 à 5 unités sur 51-56 à plus de 25 % d'écart, différentes d'un jeu à l'autre (8-33 combats
  chacune) ; seule Rakshasa sort deux fois (0,69 / 0,74). Aucun `sim_factor` posé (tous à 1) : à revoir avec 300 combats.
- `test_ac_sim` (20 combats vrais) : 90 %, écart 4 %.

## 2. Outils de mesure de masse
- `game/tools/autochess_games.tscn` : parties entre IA au simulateur, une ligne JSON par partie (places, plateaux finaux
  avec étoiles et objets, traits actifs `[palier, compte]`, atouts pris et **proposés**, économie par manche, manche et minute
  d'élimination de chacun, durées de tous les combats JcJ, temps de préparation / bilan / combat). Mises en place :
  `echelle` (2 IA de chaque difficulté, places mélangées : mesure principale), `l7r`, `r7l`, `pilote` (1 Vétéran contre le
  mélange Vétéran), `legendes`. 2,6-3,2 s par partie sur la machine chargée.
- `tools/autochess_report.py` : rapport Markdown (durées, échelle, unités, traits par palier, objets, atouts, méta,
  économie, écarts aux cibles). **Top 4 relatif** = 50 % + écart moyen au top 4 attendu de la difficulté de l'IA qui joue
  l'unité (sinon une unité jouée surtout par les Légendes paraît forte). Hors 40-60 % : signalé.
- `tests/ac_mesures.json` + `tests/test_ac_sim_real` (~75 s ; `AC_REAL_QUICK=1` : sans les vrais combats) : réglages
  identiques à la mesure, 16 combats vrai contre simulé (≥ 70 %, écart ≤ 30 %), 8 parties entre IA dans de larges bornes
  (combat médian ± 25 %, manches ± 4, durée ± 15 %, ordre des difficultés).

## 3. Mesure de référence (0.1.253) et mesure finale (0.1.255) — 2 800 parties chacune
| Mesure (SPEC §9) | Avant (0.1.253) | Après (0.1.255) | Cible |
|---|---|---|---|
| combat JcJ : médiane / p90 / sous 40 s | 21,3 s / 32,6 s / 98 % | **22,8 s** / 34,5 s / 97 % | 22-28 s / — / ≥ 90 % |
| égalités | 0,4 % | 0,7 % | < 3 % |
| partie entière ×1 (préparations pleines) | 28,8 min (p10 25,4, p90 32,3) | **29,6 min** (26,5-32,5) | 25-30 min |
| dont préparation / bilans / combats | 14,2 / 1,7 / 12,9 min | 14,1 / 1,7 / 13,7 min | — |
| partie entière, combats ×2 | 22,3 min | 22,7 min | ≈ 22 min |
| manches jouées | 33,4 | 33,3 | ≈ 35 |
| 1re élimination avant 4-1 | 12 % | **7 %** | < 20 % |
| Légende contre 7 Recrues : top 4 | 98 % | 100 % | ≥ 75 % |
| Recrue contre 7 Légendes : top 4 | 0 % | 0 % | ≤ 25 % |
| Vétéran contre le mélange Vétéran : top 4 | 62 % | **46 %** | ≈ 50 % |
| échelle R / V / C / L (place) | 7,08 / 4,31 / 3,43 / 3,19 | 7,13 / 4,60 / 3,22 / 3,05 | décroissante |
| méta : part de la 1re composition gagnante | **66 %** (Rempart + Estoc) | **33 %** | (≤ 15 % souhaité) |
| compositions gagnantes distinctes (nombre effectif) | 18 (3,5) | 26 (**7,9**) | — |
| familles des gagnants R / Tq / O / A / F | 79 / 12 / 8 / 0 / 0 % | 40 / 26 / 15 / 13 / 6 % | toutes jouables |
| top 4 relatif par rôle : mage / soigneur / soutien / tank | 27 / 37 / 43 / 67 % | **48 / 48 / 48 / 57 %** | 40-60 % |
| unités hors 40-60 % de top 4 relatif | 27 sur 60 | **4** | 0 |
| traits au palier 2 (min-max du top 4 relatif) | 3 % (Élém.) - 78 % (Rempart) | 43 % (Fracas) - 64 % (Élém.) | 40-60 % |
| objets complets (min-max) | 45-62 % | 49-60 % | 40-60 % |
| atouts (min-max) | 40-57 % | 34-62 % | 40-60 % |
| unité jamais jouée par une Légende | aucune | aucune | aucune |

Économie (stratège moyen, après) : Recrue 7,6 or en banque, 0,03 d'intérêts par manche, 24 relances ; Vétéran 34 or, 2,2 ;
Champion 32 / 2,1 (55,7 or à 4-1, niveau 7,0) ; Légende 27 / 1,7 (49 or à 4-1, niveau 6,7, 22 achats d'XP). ★3 sur les
plateaux finaux : 4,3 par partie. Éliminations : 0,3 à 0,7 stratège par manche de 4-1 à 5-6, puis moins.

## 4. Rééquilibrage (données seulement), mesuré avant / après
Passes d'essai de 300-400 parties « echelle » (copie à part, `acj_` hors dépôt), top 4 relatif par rôle mage / soigneur / tank,
part de la 1re composition gagnante, unités hors 40-60 % :

| Passe | Changement | Rôles M / S / T | Méta | Hors 40-60 |
|---|---|---|---|---|
| référence | — | 27 / 37 / 67 | 66 % | 27 |
| traits A | traits de lanceurs renforcés, Rempart / Estoc / Escrime / Fracas affaiblis | 29 / 42 / 64 | 56 % | 27 |
| plafond 30 % | `HIT_CAP` 0,20 → 0,30 (72 parties, arrêté) | 28 / 39 / 67 | 69 % | 25 |
| mana 1 | traits A + mana des mages × 0,55, soigneurs et soutiens × 0,7 | 37 / 47 / 65 | 50 % | 21 |
| mana 2 | mages × 0,45, soins × 0,6-0,65, **tanks × 1,4** ; Rempart / Estoc plus bas | 38 / 48 / 60 | 44 % | 19 |
| mana 3 | mages × 0,35, soigneurs × 0,55, soutiens × 0,6 ; Arcane +70 / 130 / 200 % ; dmg 0,11 | 51 / 51 / 55 | 29 % | 8 |
| mana 3 + plafond 25 % | idem, `HIT_CAP` 0,25 | 53 / 51 / 56 | 29 % | 13 |
| mana 4 | + Élémentaire, Escrime, Ferveur, Estoc retouchés ; mélange Vétéran ; notes d'atouts | 49 / 52 / 54 | 30 % | 6 |
| **retenu** (2 000 parties) | mana 4, Ferveur rendue (8 / 15 / 25), Élémentaire 25 / 50 / 85, Chœur 3 / 6 / 10, Fracas rendu | **48 / 48 / 57** | **33 %** | **4** |

Hors périmètre, pour mémoire : `ROLE_BASE` d'`autochess_effects.gd` (mage attaque 0,8 → 1,1 et vitesse 0,7 → 0,8, tank
défense 30 → 22) seul : 42 / 46 / 64, méta 57 % ; c'est le levier le plus juste pour le rôle, mais le fichier est à AC-H.

Changements retenus (0.1.255) :
- **Mana par rôle** `AutochessData.ROLE_MANA` (mage 35 %, soigneur 55 %, soutien 60 %, tank 140 % de recharge × 10, arrondi
  à la dizaine, 40-140) : `mana_for(recharge, rôle)`, recopié dans `tools/autochess_units.py`, `autochess_units.json`
  régénéré (54 lignes de mana), `test_ac_data` passe le rôle. Cause mesurée : en équipe, un mage (attaque 0,8 × vitesse
  0,7, 0,8 PV) ne valait pas un tank (même dégâts d'auto-attaque, 1,7 × les PV, 3 × la défense) et son sort ne revenait
  qu'une fois toutes les ≈ 11 s pour 0,8 ennemi touché (les zones s'esquivent).
- **Traits** (texte « tip » mis à jour) : Rempart déf. +20 / 45 / 80 → **+5 / 20 / 40**, PV d'équipe à 9 : 20 → **10 %** ;
  Estoc 20 / 40 / 70 → **5 / 15 / 30 %** ; Escrime parade 15 / 30 / 50 → **5 / 10 / 18 %** ; Arcane 20 / 45 / 80 →
  **70 / 130 / 200 %** ; Malédiction −15 / 25 / 35 → **−30 / 40 / 55 %** ; Élémentaire 10 / 25 / 50 → **25 / 50 / 85 %** ;
  Chœur 2 / 4 / 7 → **3 / 6 / 10 mana/s** ; Impact 5 / 8 / 12 → **7 / 11 / 16 %**. Ferveur, Fracas, Ombre, Tir, Traque,
  Tranchant, Poudre : inchangés. (`test_ac_effects` lit maintenant les PV d'équipe de Rempart dans les données.)
- **Durée** : `dmg_scale` du profil `autochess` 0,12 → **0,11** (combat de partie 21,3 → 22,8 s ; égalités 0,7 %).
- **Mélange Vétéran** `DIFFICULTIES[1].mix` [2, 3, 2, 0] → **[1, 4, 2, 0]** : les deux Recrues finissaient toujours
  7e-8e, le pilote Vétéran avait alors 4 places pour 6 (62 %) ; 46 % après.
- **Notes d'atouts des IA** (`AutochessAi.AUGMENT_BASE`) : Composant 6 → 5 (pris 77 % pour un top 4 relatif de 49 %),
  Pacte de sang 6 → 5,5 (59 %), Arsenal 8 → 7 (51 % pour 46 %).

## 5. Les écarts qui restent (à surveiller)
1. **Méta encore resserrée** : Rempart + Estoc gagne 33 % des parties (Rempart principal pour 33 % des Légendes, cible
   ≤ 30 %) ; les tanks restent les plus forts (57 %) et les 4 unités hors fourchette sont des coût 5 : Dompteur de
   dragons 67 %, Paladin 63 %, Héritier du sabre 61 %, Flèche absolue 60 %. Levier suivant : `ROLE_BASE` (tank) côté AC-H,
   ou le coût 5 seul (`COST_MULT` 1,9 → 1,8).
2. **Recrue très loin derrière** (place 7,1, 2 % de top 4 même contre des Vétérans) : Recrue contre 7 Légendes est à 0 %
   (cible ≤ 25 % tenue mais sans marge vers le haut) ; un joueur débutant qui choisit Recrue affronte 5 Recrues : partie
   facile. À revoir si le joueur trouve « Recrue » sans vie (`RECRUE_*`, `BUY_MIN`).
3. **Paliers hauts au-dessus de 60 %** (Arcane 3, Chœur 3, Malédiction 3, Rempart 3, Traque 3, Tir 3 : 71-78 %) :
   en partie structurel (6 armes ou 9 familles = niveau 8 et un plateau fort) ; à comparer entre traits du même palier,
   où l'écart est faible (64-78 %). Élémentaire 2 (64 %, 67 plateaux) à surveiller.
4. **Atouts** : la place moyenne des preneurs (cible 4,0-5,0) mélange force de l'atout et choix des IA (les Recrues
   prennent au hasard Menace, Forge de campagne, Premier sang : place 6,7-7,3 mais top 4 relatif 47-49 %). Au top 4 relatif,
   écarts : **Double trait 34 %**, Trésor du dragon 38 % (faibles), Héros légendaire 62 % ; Couronne prise 78 % et Héros
   légendaire 58 % des fois où ils sont proposés (cible ≤ 50 % ; ce sont les meilleurs Éclats).
5. **Simulateur** : 88-89 % de même vainqueur après le rééquilibrage (les sorts plus fréquents s'accordent un peu moins,
   0,09 sort par unité-s au lieu de 0,06) ; `sim_factor` par unité non posés. La place moyenne « à son coût » du §9 (4,0-5,0)
   n'est pas une bonne cible en parties mêlées : 19 unités sur 60 y sont, mais les coût 5 (2,5-3,4) sont joués par les
   plateaux de fin de partie ; le top 4 relatif la remplace.
Objets : Plaies profondes 60 % (le plus fort), Emblème 61 % (un trait de plus). Durées et échelle : dans les cibles.
Mesure au vrai combat d'une partie entière (`--autoplay` de l'écran) : pas faite ici (l'écran et le directeur sont au lot
AC-V) ; les durées viennent du simulateur calé (écart de durée 1-4 %).

## 6. Relancer
```
# calage (≈ 3-5 min chacun, puis grille sur les combats enregistrés)
Godot --headless --path game res://tools/autochess_fight.tscn --fixed-fps 60 -- --calib --n=100 --seed=1 --save=user://calib1.json
Godot --headless --path game res://tools/autochess_fight.tscn -- --compare=user://calib1.json --sweep "--grid=auto_lock:1.4/1.5;zone_dodge:0.55/0.6/0.65"
# mesure de masse (4 morceaux en parallèle + l7r, r7l, pilote, legendes : ≈ 45-60 min sur la machine chargée)
python tools/autochess_report.py --run=<dossier> --games=2000 --jobs=4
# ou à la main, puis le rapport :
Godot --headless --path game res://tools/autochess_games.tscn --quit-after 3 -- --games=500 --seed=1 --setup=echelle --out=<dossier>/e0.jsonl
python tools/autochess_report.py <dossier> [--all] [--min=30] [--json=resume.json]
Godot --headless --path game res://tests/test_ac_sim_real.tscn
```
Tout changement de `TUNE`, `dmg_scale`, des traits, objets, atouts, unités ou des IA : refaire la mesure puis
`tests/ac_mesures.json` (réglages, calage, chiffres de la passe), comme `sv7_mesures.json`.
