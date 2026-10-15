# R_S4 — Survivant, déroulé de la run (15/10/2026)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md`, `R_S1.md`, `PLAN_NUIT.md`, `R_P11.md`, `R_P12.md`, `CLAUDE.md`.
Code : `core/survivor_director.gd` (tout le lot) ; crochets d'une ligne dans `run_director.gd`, `hud.gd`, `run_page.gd`,
`survivor.gd` (`level_cap`). Règles dans DESIGN.md, « Survivant », points « Déroulé », « Monstres », « Ce qui reste ».

## Fait
- **Chronologie** (`SurvivorDirector.timeline()`, temps de carte, en pause pendant les choix) : annonce 10 s avant puis
  gardien à 5:00, 10:00, 15:00 ; portail du boss ouvert à 15:00 (message à 15:05 pour ne pas couvrir celui du 3e gardien) ;
  19:00 « Le boss arrive dans 1:00 » + horde finale (30 en anneau, densité maximale) ; 20:00 fondu forcé vers l'arène (il
  attend un héros debout). Pas de rage de carte. Pas d'extraction (directeur + bouton du menu pause).
- **Gardiens** : géant de P12 (`GiantMonster`, coups plafonnés à 30 % des PV du héros) surgi à 18 m, PV FIXES
  40 000 / 150 000 / 450 000 × palier × Menace ; vaincu : or (60 + 15 × niveau) et « Coffre du gardien » ; **ne monte pas** la
  Menace (seuls les géants des autels la montent).
- **Boss** : PV fixes 1 500 000 × palier, puis × Menace (P12, en différé) ; jamais d'après le héros ; rage du boss à 4:00
  (`boss_rage_at`, paliers de P11). Victoire = boss tué ; défaite = 2e chute ; abandon : bilan, hub intact.
- **Monstres** : `spawn_plan(t)` = interface étroite (vivants, meutes, vagues, élites, niveau, PV, dégâts, horde finale) ;
  `update_spawns` l'applique (meutes en anneau 20-28 m, encerclement / horde en alternance, élites dès 8:00, camps d'élite).
  P15 n'était pas poussé : si `RunDirector.spawner` existe, ses escouades par rôle et ses événements remplacent mes meutes et
  vagues (appels dynamiques, `--spawn=legacy` les coupe). **À vérifier quand P15 poussera** (son travail en cours, mesuré au
  pilote en `--fixed-fps`, ne faisait presque rien apparaître, en Survie aussi : 3 monstres en 2:30).
- **Coffres** : 30 coffres du Survivant (`BOXES`, `LAYOUT` : 2 par emplacement d'armure et de bijou, 2 d'arme, 6 de sort,
  6 dorés), noms et prix branchés ; contenu = `SurvivorCards.chest_cards(id)` (ids `sv_<emplacement>`, `sv_weapon`,
  `sv_spell`, `sv_gold`, `sv_guardian`, `sv_anvil`) ; tant que S3 n'est pas poussé : cartes de la Survie.
- **Journal** : `sv_minutes` (une ligne par minute : niveau, PV, vivants, tués, niveau et multiplicateurs des monstres,
  Menace, or, sorts, pièces), `sv_guardians` (instant, niveau, PV, temps pour vaincre), `sv_arena_at`, `sv_arena_forced`,
  `sv_early_s` (Audace de S6 : `early_seconds()`), `sv_boss_hp` ; ligne console `[sv]` chaque minute.

## Décisions
- **Ce qui reste / disparaît** (SPEC §6.1 appliqué) : or, clés, XP, potions (3 % / 30 %), fontaine, aimant, sanctuaires
  (carte ou 2 clés), camps d'élite (clé + carte), pacte et autels du géant (P12 inchangé) restent ; enclume = +2 sur une pièce
  portée (`chest_cards("sv_anvil")`, rien à forger : l'enclume reste) ; stèle du défi = coffre doré + or. Disparaissent :
  butin d'équipement, coffres de récompense, fournitures et gemmes (objets cassés compris), arme secondaire, sceaux.
- **Pas de plancher « niveau du héros − 1 »** pour les monstres (SPEC §8.2) : sans le plafond de niveau par carte il emballait
  la run (pilote 0,9 : niveau 66 à 20:00, monstres collés derrière) ; sans lui : 54. Monstres = 1 + 1,8 par minute.
- Plafond de niveau du héros : 90 (`Survivor.level_cap`), plus celui de la carte de la Survie.
- `RunJournal.context` reçoit une **méthode liée**, pas une fonction anonyme : une variable statique qui garde une fonction
  anonyme faisait planter Godot à la sortie (code 139).

## Mesures (pilote `--autoplay --fixed-fps 60 --hub=new`, sans S3 : ni arme ni pièce aux cartes, 4 sorts)
| Pilote | 5:00 | 10:00 | 15:00 | 20:00 | Gardiens (temps pour vaincre) | Fin |
|---|---|---|---|---|---|---|
| guerrier 0,9 Rainbowfall | niv. 12 | niv. 22 | niv. 35 | niv. 54, 4 194 tués, 57 vivants | 90 s / 133 s / 105 s | arène forcée à 20:00, boss (1,5 M) : mort en 69 s |
| mage 0,5 Beluga | niv. 11 | — | — | — | — | mort à 6:36 (niv. 12) |
| guerrier 0,5 Limestone | niv. 5 à 3:00 | — | — | — | — | mort à 3:45 |
Run complète de 20 minutes sans blocage ni erreur de script ; vivants 80-110 de 13:00 à 19:00. Cibles de §8.1 (niveau 20 à
9:00 tenu : 20 ; 38 à 20:00 : 54, trop haut) et TTK des gardiens (30-60 s) : **à recaler en S7 avec les cartes de S3** (le pilote
n'a ni arme ni pièce, les morts précoces viennent de là). Or : 60 000 à 20:00 (personne ne le dépense sans S3).

## Tests
`test_sv4` (58 vérifications : chronologie, courbe, PV fixes, palier, 30 coffres, potions seules au sol en 60 s de pilote,
gardiens 1-3 et Menace, portail, arène forcée, boss × Menace, rage à 4:00, victoire, défaite après résurrection, entrée en
avance + abandon, journal, hub intact). Verts sur une copie propre (HEAD + ce lot seul) : test_sv1, test_sv2, test_farm,
test_p11, test_p12, test_pursuit, test_progress, test_royale, test_hud, test_results.

## Pièges
- Le dossier partagé contenait le travail en cours de P15 (`spawner`), S3 (`survivor_cards.gd` qui ne compilait pas par
  moments) et d'autres : tests et pilote lancés sur une copie (`tools/run_tests.py`, `preparer_copie`) + ce lot seul.
- J'ai arrêté par erreur (`taskkill /IM`) trois processus Godot d'autres sessions vers 18:10 : relancer leurs tests si besoin.
- S5 : `objective_lines()`, `status_text()` (gardiens ◆◇◇) sont branchés au HUD ; S6 : `early_seconds()`, `guardians`,
  `arena_forced` ; S3 : les ids de coffres ci-dessus.
