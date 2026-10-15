# R_S7 — Survivant, équilibrage par mesures (15/10/2026, version 0.1.209)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md` (§8), `R_S1` à `R_S6`, `PLAN_NUIT.md`, `R_P15`, `R_P11`, `R_P12`, `CLAUDE.md`.
Réglages : en tête de `core/survivor.gd` (constantes documentées), lus par le profil `survivor` de `ModeRules` (mode dev).
Mesures : copie propre de HEAD + ce lot (`tools/run_tests.preparer_copie`), `--fixed-fps 60`, un dossier utilisateur par processus.

## Fait
- **Spawn de P15 branché** (`SurvivorDirector.update_spawns`) par son interface publique : `tick` (soigneurs, secteurs, mesures),
  `pack(budget, niveau)` (deux escouades de deux côtés dès un budget de 7), `wave(dur, minutes)` (encerclement annoncé, escorte,
  ruée, tenaille ; `pace` suit la courbe), horde finale de 19:00 = encerclement annoncé + ruée ; la courbe par minute
  (`spawn_plan`) reste la seule source du rythme.
- **MonsterScaling en Survivant** : l'indice d'équipement de la RUN (pièces portées / PE attendue au niveau du héros) est comparé à
  une bande par minute mesurée au pilote (`POWER_BAND`, p25-p75) ; monstres ordinaires PV ×0,9-1,3, dégâts ×0,9-1,15 (plus étroit
  que la Survie : les pièces de la run sont la progression attendue), lissé, plafonné avec Menace et pacte ; gardiens et boss jamais.
- **Ouverture** : dégâts ×0,3 et PV ×0,6 à 0:00 (×1 à 3:00), 1re vague à 1:15, pas de vague « dure » (élite) avant 4:00, camps
  d'élite endormis avant 3:00, meutes de 3.
- **Expérience** en trois bornes : ×2 (niv. 1) → ×1,15 (niv. 10) → ×0,35 (niv. 35 et plus).
- **Boss** : PV fixes 6 000 000 (× palier × Menace), dégâts × `BOSS_ATK` (1) au lieu de la courbe des monstres (×1,93 à 20:00).
  **Gardiens** : 50 000 / 220 000 / 700 000.
- **Garde-fous** (`Survivor.cap_hero`, crochet d'une ligne dans `Player.recalc_stats`) : critique ≤ 75 % (surplus × 0,25 en dégâts
  critiques), dégâts critiques ≤ +250 %, vitesses d'attaque et d'incantation ≤ ×2,5 ; plafond des passifs = `passive_cap_mult`.
- **Pitié de l'offre** (`SurvivorCards`) : après 3 choix d'affilée sans carte forte (`is_strong` : arme, pièce, sort, évolution,
  amélioration rare+ ou qui apporte un passif), l'offre suivante a ses améliorations au moins épiques. Mesurée : 0 sur 2 000 tirages
  et 0 par run simulée (filet de sécurité, le tirage normal en propose toujours).
- **Menace optionnelle** : autels du géant (2) et pacte présents en Survivant, boss et gardiens × Menace (vérifié, `test_sv7`).
- **5/5 de set** (`tools/sv_cards_sim`, vrai tirage, chercheur, 39 montées et 12 coffres mesurés) : `set_damp` 0,14 → 1 run sur 31
  (3 × 600 runs : 1/43, 1/30, 1/25) ; **0,17 → 1 run sur 23** (1/19, 1/27, 1/23) : retenu.
- Outils : `tools/sim_survivor.py` (runs au pilote, `--probe` : sonde de builds), `tools/sv_build_probe.tscn` (run de choix par
  stratégie puis combat contre le boss, aide « Bot », héros invincible), lignes `[sv]` enrichies (cartes, dégâts subis, PV max,
  indice, puissance, pitié, PV du boss) et `[sv-build]` (arme, set, +N, sorts, passifs, statistiques).

## Mesures (pilote `--survivor --autoplay`, 5 classes ; débutant 0,3 / moyen 0,5 / bon 0,7 = part des coups évités)
| | Avant (0.1.206, 15 runs) | Après (30 runs) | Cible |
|---|---|---|---|
| niveau à 5 / 10 / 15 / 20 min | 11 / 21 / 34 / **53** | 11 / 20 / 30 / **40** | 10 à 4:00 … 38 ± 4 |
| morts avant 3:00 (tous profils) | **4 / 15** (élites de camp, escorte) | **0 / 30** | 0 |
| tient 10 min (déb. / moy. / bon) | 60 / 80 / 80 % | 80 / 90 / 100 % | 70 / 85 / 95 |
| victoire (déb. / moy. / bon) | 60 / 80 / 60 % (bimodal : mort à 1 min ou victoire facile) | 40 / **40** / 60 % | 10 / 35-50 / 65 |
| boss final (TTK du pilote) | **7 s** (2-13) | **130 s** (69-223) | 90-180 s |
| gardiens 1 / 2 / 3 (médiane) | 36 / 25 / 31 s | 60 / 39 / 28 s | 30-90 s |
| durée d'une victoire | 20:12 | 22:16 | 22-25 min |
| cartes prises à 20:00 | — | 70 | ≈ 70 (SPEC §6.3) |
| dégâts subis (part des PV max / min) | — | 194-294 % (soins de niveau, vol de vie) | — |
Étapes : B1 (XP ×0,45 tardive) niveau 43 mais 5 morts sur 10 avant 2:10 ; B2 (ouverture, XP ×0,35) niveau 40, 9 morts dans l'arène
en 30 s (boss aux dégâts de la courbe) ; B3 (dégâts du boss, PV, bande) = colonne « après ». Débutant au-dessus de la cible : le
proxy « coups évités » ne rend pas les erreurs de placement d'un débutant (à lire au journal réel).

## Dominance (sonde, 312 builds : 7 stratégies × 5 classes × 9 graines, niveau 40, 18 coffres, 10 cartes libres)
TTK du boss (6 M PV) : 10 % 58 s · 25 % 89 · **médiane 129** · 75 % 185 · 90 % 230 (≈ rage) ; 90 % des builds battent le boss avant la
rage avec l'aide « Bot » et sans encaisser. Par stratégie, victoires avant la rage : pièces 100 %, bot 95, pilote 93, set / passifs 91,
arme 89, sorts 76 % → **meilleur / médian ×1,10** (DPS ×1,30) ; par famille de set ×1,13, par classe ×1,03, par arme ×1,02 (DPS ×2,5
entre la rapière, 4 builds, et le ceste). Avant les plafonds de statistiques : « tout en pièces +10 » faisait ×2,7 le DPS médian
(critique 300 %, dégâts critiques +300 %, vitesse d'attaque ×4) ; après : ×1,3. Évolutions ≤ 3, sorts au niveau 10 ≤ 5, aucun passif
au-delà de son plafond (`test_sv7`, 60 builds tirés aux niveaux 38 / 60 / 90).

## Décisions
- Courbe des monstres (PV ×0,5 × 1,12^min, dégâts ×0,5 × 1,07^min) **inchangée** : le héros trop fort venait de son niveau (53), pas
  des monstres ; l'ouverture et l'XP suffisent. Les monstres restent 3 niveaux sous le héros (37 contre 40).
- Boss dimensionné sur la sonde (référence de P11 : aide « Bot ») : médiane 2:09, une bonne run 1:00-1:30, une run faible à la rage.
- Survie, Tour, Siège : rien ne change (`test_e6`, `test_p12`, `test_p15`, `test_farm`, `test_progress` verts).

## test_e6 (échec signalé par P15)
Pas de régression : sur HEAD 0.1.206 / 0.1.207, `test_e6` est vert 4 fois sur 4, déterministe (Héroïque 13,9 h / époque III 20,0 h =
69,5 % ≥ 65 %). `progression_sim` ne lit ni le spawn ni le Survivant ; l'échec de P15 venait du dossier partagé (travail non poussé
d'autres sessions à ce moment-là). Ni le test ni la constante ne changent.

## Tests
`test_sv7` (37 vérifications, vert) ; mis à jour pour lire les constantes : `test_sv1` (boss, expérience), `test_sv4` (courbe, PV
fixes). Verts : test_sv1 à sv7, test_p15, test_p12, test_farm, test_progress, test_e6, test_nav_screens, test_cards, test_hud (copie propre de HEAD + ce lot).

## Reste / pièges
- `tests/sv7_mesures.json` porte les réglages mesurés : changer une constante d'équilibrage fait échouer `test_sv7` tant que les
  mesures ne sont pas refaites (`python tools/sim_survivor.py --project <copie>/game --seeds 2` puis `--probe --fight --seeds 9`).
- Le pilote ne dépense presque pas son or (50 000 à 20:00) : économie des coffres à revoir au journal réel ; il entre toujours à
  20:00 (pas d'Audace mesurée). Les paliers II à V (S8) ne sont pas mesurés.
- Runs au pilote ≈ 7 min chacune (1 seule machine) ; la sonde ≈ 2 min par build à 6 M PV.
