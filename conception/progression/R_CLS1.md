# R_CLS1 — équilibre des classes face aux boss de l'Aventure (lot CLS-1)

Version : **0.1.310**. Suite de `R_H4b.md` (« Chasseur (et rôdeur) : plus faibles face aux boss, à traiter dans un lot de classes »).
Tables d'époque de H4b (`BOSS_HP_ADJ`, `BOSS_ATK`, `MAP_ATK`, `MAP_MULT`) **non touchées** ; duel / JcJ (`pvp_caps`, `ModeRules`), modes
scellés et Tour (`TowerBalance`, `data/tower_solo.json`) **non touchés**.

Mesures sur des copies propres de HEAD (0.1.276 puis 0.1.290 / 0.1.295, APPDATA détourné), 2 processus au plus (machine partagée :
jusqu'à 47 processus Godot d'autres sessions). Aide « Bot » du jeu, coups évités 0,5 (sauf mention). **Bruit** : une sonde rejouée
avec la même graine ne redonne pas exactement le même combat (cartes et trophées tirés), et une partie entière encore moins : ± 15
points sur 10 combats ; seules les différences de plus de 2 combats sur 6 et répétées sur deux séries sont retenues.

## Outils (ce qui a changé)

| Outil | Nouveau |
|---|---|
| `tools/boss_ttk.py` | `--classes all` (les 60), `--by-class` (tableau par classe : battus, morts, DPS et PV rapportés à la médiane du cas, dégâts subis, **indice** = DPS relatif / dégâts subis relatifs), `--same-seeds` (graine selon la carte et la répétition : mêmes combats pour toutes les classes, avant / après), `--json`, `--game` (copie propre), `--userdir` (APPDATA à part) |
| `tools/sim_survie.py` | `--by-class` (boss battus, combat médian par classe), `--game`, `--userdir` |

La sonde ne refait pas la run d'un compte neuf (PV et attaque bien plus bas qu'en partie) : le compte neuf se mesure en **partie
entière** (`sim_survie.py --bot --hub new`).

## Diagnostic

**60 classes**, sonde `bande` (héros au haut de la bande, pièces de la carte +5), cartes I-2, II-1, III-2, IV-1 (1 combat chacune),
puis 23 classes (les plus faibles, les classes de départ, tous les tireurs les plus en retard) × I-1, II-1, III-2 × 2 combats (`--same-seeds`) :
378 combats. Boss battus par famille : guerriers **72 %**, voleurs et mêlée 52 %, tireurs 53 %, soutiens 87 %, mages 59 % ; **médiane
des familles 59 %** (seuil du lot : 20 % en dessous, soit 47 %).

| Classe (famille) | Boss battus | Lecture |
|---|---|---|
| Asura (voleurs) | **0 / 10** | mêlée au contact ; DPS face aux boss 0,6-0,8 de la médiane (dans la Tour, sans mécaniques, elle est rapide : le kit ne tient pas face aux mécaniques) |
| Rakshasa (voleurs) | **1 / 10** | même base et même kit de départ que l'Asura, 4 ruées |
| Conjurateur (mages) | 3 / 10 | DPS 0,8 ; combats longs croisés par la rage du boss (III-2 : mort vers 310-320 s) |
| Chasseur de démons (tireurs) | 3 / 10 | tombe en 30-35 s aux époques I-II (PV 1, arc à attaque magique) |
| Luminaire (mages) | 3 / 10 | DPS correct, meurt avant la fin |
| Lame maîtresse, Chevalier dragon, Ingénieur, Méca-Arès, Fusilier | 4 / 10 | à 1 combat du seuil : dans le bruit, **non réglés** (à surveiller) |
| Chasseur, Rôdeur (tireurs) | 6 / 10, 6 / 10 | au niveau de la bande : **dans la moyenne** (Voleur 6 / 10 ; Guerrier, Clerc, Magicien 8 / 10) |

**Le Chasseur n'est faible qu'au compte neuf.** Partie entière, carte I-1, compte neuf (niveau 1, équipement de départ), 4 parties à
coups évités 0,5 + 6 à 0,3 (débutant) :

| Classe de départ | 0.1.276 | 0.1.295 (même code que le réglage) |
|---|---|---|
| Guerrier | 7 / 10 | 4 / 4 (0,5) |
| Voleur | 5 / 10 | 9 / 10 |
| **Chasseur** | 5 / 10 | **2 / 10** |
| Clerc | 8 / 10 | — |
| Magicien | 7 / 10 | — |

Cause : le Chasseur est la seule classe de départ dont la base est **sous celle de toute sa famille sans rien en échange** : PV ×0,85,
attaque ×0,95, aucune défense de base, quand les 11 autres tireurs ont PV 1 à 1,1, attaque 1 et défense 3 (le Voleur, PV 0,9 sans
défense, a +10 % de critique, +15 % de vitesse d'attaque et +8 % de déplacement ; le Magicien, PV 0,8, attaque magique ×1,15). Le
boss d'I-1 est tué en ≈ 50 s comme au Guerrier, mais avec 25-40 % de PV en moins (≈ 1 050 contre 1 350-1 850). Sur la carte, il perd
2 fois plus de PV par minute qu'un Guerrier (tir unique, les monstres l'atteignent) ; l'arène du boss le soigne à l'entrée : c'est le
combat du boss qui le tue. Au niveau 23 et au-delà, l'équipement compte bien plus que la base (+18 % de PV de base = +9 % de PV au
niveau 23).

## Réglage : `ClassBalance` (`core/class_balance.gd`, `data/class_balance.json`)

Stats de l'Aventure par classe, appliquées par `Player.recalc_stats` **seulement en Aventure** (`Epochs.adventure()`), **pour le héros du
joueur** (jamais un héros ennemi ni un profil type) : ni duel, ni Arènes, ni Tour, ni Donjons, ni modes scellés, ni l'IA (`ClassRival`,
arène d'apprentissage : les cerveaux restent entraînés sur `data/classes.json`, qui ne change pas). Deux leviers :
- **clés de la base** (`hp`, `def`, `atk`, `matk`, `crit`, `atk_speed`, `move_speed`) qui remplacent celles de `data/classes.json` :
  jamais une baisse, jamais au-dessus de la meilleure classe de la même famille (le « plancher de la famille ») ; elles comptent
  surtout aux premiers niveaux ;
- **multiplicateurs** `hp_mult`, `dmg_mult` (1 à 1,5, comme `TowerBalance` dans la Tour) pour un kit en retard à tout niveau.

| Classe | Réglage | Avant → après (mesuré) |
|---|---|---|
| **Chasseur** | PV 0,85 → **1,1**, attaque 0,95 → **1**, défense 0 → **3** | compte neuf I-1 : **2 / 10 → 6 / 10** (0,5 : 1 / 4 → 4 / 4 ; 0,3 : 1 / 6 → 2 / 6) ; essai PV 1 : 4 / 10. Sonde bande : 3 / 6 → 3 / 6 (inchangé, voulu) |
| **Asura** | dégâts ×**1,3** | sonde I-1 / II-1 / III-2 : 0 / 6 → 3 / 6 ; I-2 / IV-1 (hors réglage) : 2 / 4 → 2 / 4, temps pour tuer IV-1 56 / 214 → 36 / 123 s |
| **Rakshasa** | dégâts ×**1,3** | 0 / 6 → 3 / 6 ; I-2 / IV-1 : 2 / 4 → 2 / 4 (IV-1 62 / 199 → 36 / 118 s) |
| **Conjurateur** | dégâts ×**1,2** | 2 / 6 → 5 / 6 ; I-2 / IV-1 : 2 / 4 → 3 / 4 |
| **Chasseur de démons** | dégâts ×**1,2**, PV ×**1,2** | 2 / 6 → 3 / 6 (dégâts ×1,2 seuls : 2 / 6) ; I-2 / IV-1 : 0 / 4 → 1 / 4 |
| **Luminaire** | dégâts ×**1,2**, PV ×**1,15** | 2 / 6 → 3 / 6 (PV ×1,15 seuls : 2 / 6) ; I-2 / IV-1 : 2 / 4 → 2 / 4 |

Cinq classes réglées à haut niveau, ensemble : **14 / 50 (28 %) → 27 / 50 (54 %)** boss battus (médiane des familles 59 %). I-2 et IV-1
n'ont pas servi au réglage (contrôle). Essayé puis retiré : Voleur PV 1 et défense 3 (compte neuf 9 / 10 → 7 / 10 : aucun retard à
corriger).

Compte neuf après réglage : Chasseur 6 / 10, Voleur 9 / 10, Guerrier 11 / 14, Clerc 8 / 10, Magicien 7 / 10 : **60 à 90 % quel que soit
l'archétype** (avant : 20 à 90 %).

## Duel, Tour, modes scellés : rien ne bouge

Par construction (`Epochs.adventure()` et héros du joueur seulement) ; vérifié par `test_cls1` (héros ennemi en Aventure et héros du
joueur hors Aventure : mêmes stats avec ou sans la table). Verts sur une copie de HEAD 0.1.309 + ce lot : `test_cls1`, `test_m8`, `test_pvp`,
`test_duel_modes`, `test_h2` (modes scellés), `test_h3`, `test_h4a`, `test_p11`. `data/tower_solo.json` **non régénéré** (la Tour ne change pas).

## Reproduire
- 60 classes : `python tools/boss_ttk.py --scenarios bande --epochs 1,2 --stages 1 --human 0.5 --repeat 2 --same-seeds --by-class
  --classes all --jobs 2 --game <copie>/game --userdir <dossier> --json mesures.json` (cartes 2 : `--epochs 1,3 --stages 2`).
- Avant / après : même commande et mêmes graines, `data/class_balance.json` vidé (`{"adventure": {}}`) puis remis.
- Compte neuf : `python tools/sim_survie.py --bot --hub new --epoch 1 --boss-after 360 --human 0.5 --classes warrior,thief,hunter,cleric,magician
  --seeds 4 --by-class` (débutant : `--human 0.3 --seeds 6 --seed-base 3000`).

## Reste / pièges
- Classes à 4 / 10 (Lame maîtresse, Chevalier dragon, Ingénieur, Méca-Arès, Fusilier) : dans le bruit, à remesurer avec plus de combats.
- Le boss d'I-1 au niveau 23 (équipement correct) tue vite presque toutes les classes sauf les guerriers (morts en 30-45 s) : c'est une
  carte de H4b, pas une classe.
- La sonde rejouée avec `--same-seeds` n'est pas strictement identique (tirages des cartes) ; une partie entière diffère d'une version à
  l'autre : comparer avant / après sur **le même code**.
- Le multiplicateur suit le kit tiré en partie ; un réglage de classe dans `data/class_balance.json` se mesure avant d'être gardé
  (`test_cls1` vérifie les bornes, pas l'équilibre).
- Donjons, Ruée, Siège (boss de la bibliothèque) : non mesurés dans ce lot ; s'ils montrent les mêmes écarts, étendre `ClassBalance`
  plutôt que `data/classes.json` (lu aussi par l'IA, l'Échiquier et le duel).
