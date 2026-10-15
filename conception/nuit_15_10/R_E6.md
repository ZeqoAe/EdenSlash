# R_E6 — Équilibrage global par mesure (passe E6, version 0.1.182)

Règles dans DESIGN.md, « Équilibrage global (passe E6) ». Test : `tests/test_e6.tscn` (règles + bornes de la simulation).

## Méthode

- **Journal réel** : 2 cartes de Survie seulement (`tools/journal_report.py` : « pas assez de cartes ») ; il ne peut encore rien trancher.
- **Simulation d'un compte neuf** (nouvel outil `res://tools/progression_sim.tscn`) avec les **vraies formules** : stats du héros
  (`Player.recalc_stats`, indice I = √(PV effectifs × DPS) aux niveaux 15 / 25 / 35), pièces des coffres (`SlotChests`), barème
  d'insignes (`Economy`), prix de l'Armurerie, coûts et chances de la Forge (pierres dès +6), contenu réel des coffres
  (`Rewards.open`), butins des activités (`ActivityLoot`), PE. **Modèle de joueur** (écrit dans l'outil) : chance de finir une
  carte = σ(0 / 0,2 / 0,4 + 2,6 ln R + talent − apprentissage), R = I / I(pièces +0 de l'époque I) / monstres ; trouvailles de
  run sur 70 % des emplacements ; achats de la meilleure base ; Atelier (+N, gemmes, enchantements) ; 40 % du temps en
  activités (Tour, puis Donjons tenables : PE **et** niveau des pièces). La pente 2,6 vient du pilote automatique (survie à 7 min
  de 60 % à 100 % quand R triple). Le talent et l'apprentissage sont des hypothèses : les chiffres absolus sont ±30 %.
- **Pilote automatique** (`tools/sim_survie.py`, coups évités 0,5, après réglage) : E I départ 3/5 survivent 7 min ; E II avec
  pièces de l'époque I +5 et gemmes : 5/5 ; E IV avec un équipement d'époque IV +10 gemmes (×6) : 3/5 (comme l'époque I au
  départ). La 1re campagne (10 cases) a été arrêtée : machine chargée, et elle mélangeait l'ancienne et la nouvelle règle.

## Mesures (joueur « moyen », médianes ; 24 comptes, 90 h)

| | Avant | Après | Cible |
|---|---|---|---|
| 1re victoire d'époque I | 13 runs, 3,3 h (16 comptes, bruit ±4) | **9-10 runs, 2,0-2,5 h** (60 comptes : 9) | 5-8 runs |
| Époque II / III gagnée | 6,9 h / 8,7 h | **8,5 h / 15 h** | — |
| Époque IV gagnée | **10,2 h** | **26,7 h** | hors de portée avant 40-60 h |
| Équipement complet (9 pièces +10, gemmes ≥ rang 4, enchantement ≥ 5) | 27,5 h | 30,3 h | 15-25 h |
| « bon » / « débutant » : 1re victoire E I | — | 6 runs / 24 runs | |
| « bon » / « débutant » : époque IV | — | 16 h / 43 h | |

Puissance en Survie (R à la carte 1, × monstres) : pièces +0 de l'époque I = 1 ; +10 = ×1,9 ; 2 gemmes royales par pièce : ×2,4
avant / ×1,5 après ; équipement complet d'époque IV ≈ ×6,8 (simulation). Avant, les monstres n'allaient que jusqu'à ×2,2.

Boucles (époque I, insignes / h · maîtrise / h) : abandon à 1 min **2 000 → 200** · 2 000 ; défaite express à 3 min **1 011 → 411** ;
victoire réelle (2 500 monstres) 549 ; rage 60 min sur la 1re carte **625 → 203** · **5 579 → 1 364**.
Cristaux / h (100 % de réussite) : Donjon N / H / M 180 / 540 / 1 020, Ruée 213 / 480 / 907, Siège 129 / 386 / 857, Tour **45 → 120**.

## Constats et réglages

1. **Écart d'époque trop faible** (N1 §2 jamais vérifié) : l'équipement multiplie la puissance par ≈ 6-7, les monstres par 2,2 ;
   un compte simulé gagnait l'époque IV en 10 h. → `Epochs.MONSTER_MULT` **1 / 1,7 / 3,4 / 7** (sweep : 6 → E IV 19 h, 7 → 27 h,
   7,5 → 28 h). Chaque époque demande l'équipement de la précédente bien monté ; IV = équipement complet.
2. **Gemmes** : deux royales par pièce triplaient la puissance en carte 1 (plus que toutes les époques). → `Craft.GEM_RUN_SHARE`
   0,09 × 1,08^(niv − 1) (comme les pièces). Rangs par époque d'E4 gardés (royales dès la fin de l'époque I : sans effet abusif
   maintenant). Hors Survie inchangé (duels non touchés).
3. **Formules Lv8-9 en époque IV** (E4) : ≈ 10 par carte, plus qu'un Siège Mythique. → `Craft.SURVIVAL_SCROLL_MAX` 2 / 4 / 6 / 7 ;
   Lv8-9 = Siège et coffres du joaillier ≥ 70.
4. **Exploits fermés** : abandon / défaite express (participation au prorata des 10 min avant la rage, `Economy.ENTRY_MINUTES`,
   temps lu dans le journal) ; ferme en rage (monstres comptés ≤ 1 500 par carte, `Run.KILL_CAP_PER_MAP` ; coffres ≤ 6 et
   fournitures ≤ 60 des monstres ordinaires par carte, `RunDirector.FARM_CAP`) ; **insignes → cristaux sans limite** (pièce d'un
   palier entamé à 8 insignes puis démontée pour 3 cristaux, en boucle) → une pièce rachetable ne rend que ses améliorations.
5. **Creux E I → E II** (A1, C3) : la Tour, seule source de cristaux avant les Donjons, payait ≈ 45 / h → 3 / 4 / 5 / 6 par étage.
6. **Vérifiés, inchangés** : enclume (+12 : une pièce +10 n'y gagne que +2), capes (≈ 1/9), cartes d'amélioration (plafonnées),
   barème d'E5 (Survie 1re source d'insignes à l'heure ; avec les vrais monstres, ≈ 2 500 par victoire au lieu de 600,
   la Survie paie ≈ 30 % de plus que la table d'E5), aucune activité dominante pour les cristaux (Mythiques 850-1 020 / h).
7. **60 classes** : à 90 h le compte simulé a dépensé 5 800 insignes sur 26 300 et 8 500 cristaux sur 23 400 : le reste sert les
   autres classes (kit ≈ 2 200 insignes + 9 000 cristaux ≈ 13 h par profil × 7 profils + armes) ; maîtrise 20 des 60 ≈ 128 h
   (E5). Total : quelques centaines d'heures, sans mur, sans boucle triviale trouvée.

## Écarts aux cibles (décisions)

- **Époque IV ≈ 27 h, pas 40-60 h** : dans un jeu où l'équipement ouvre l'époque, IV tombe quand l'équipement est complet ; 40-60 h
  demanderait que l'équipement d'une classe prenne aussi 40-60 h, contre la cible 15-25 h. Gardé : IV ≈ équipement complet
  (≈ 30 h). Monter `MONSTER_MULT[3]` au-delà n'y change presque rien (7,5 : 28 h) mais en fait un mur ; pour la repousser,
  ralentir l'équipement (cristaux de la Forge). À valider au jeu réel.
- **1re victoire E I à 9-10 runs** (bon : 6) : non retouchée (début réglé par N1 au pilote ; « 1re run punitive » voulue).

## Reste / pièges

- **Bilan de Survie (U9, `ui/results_screen.gd`, `insignia_tip`)** : affiche encore « Participation +25 » et 25 × carte en dur. Il
  doit lire `Run.insignia_parts` (participation, maps, fights, victory), écrit par `Run.finish`. Non touché (fichier ui).
- **Donjons Mythiques ouverts trop tôt par la PE** : la PE pèse peu le niveau (20 + 2 × niveau) ; un équipement de l'époque I à +10
  fait 16 300 ≥ 14 400 requis pour un donjon de niveau 90, où ses pièces valent 30 fois moins que des pièces de niveau 90.
  Proposition : exiger aussi un niveau moyen des pièces ≥ niveau du donjon − 12 (textes du lobby à revoir : chaîne U).
- `core/run.gd` de HEAD (0.1.179-0.1.181) ne compilait pas (`discover_weapons()` mal placé par le commit partiel d'E4) : la
  correction présente dans la copie de travail est emportée par ce commit.
- Tests verts : test_e6 (simulation du test : E I 11 runs, II 8,7 h, IV 27,5 h, équipement complet 30,8 h), e2, e3, e4, e5,
  gear_run, progress, farm, loot, lot13, lot16, lot18, siege, journal, build. test_pages (« mode dev en run ») échoue à cause
  d'une erreur de compilation d'un autre lot en cours (`ArchivePages` → `dev.gd`), sans lien avec E6.
- Retouches d'autres lots : `tests/test_gear_run`, `test_loot`, `test_lot16` (temps de carte, cristaux de la Tour, gemmes),
  `core/activity_loot.gd`, `core/items.gd` (démontage), `core/craft.gd` (mes seuls blocs commités).
