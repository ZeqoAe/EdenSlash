# R_SVX3 — Survivant : évolutions, records, coffres, Codex, élites et événements (17/10/2026)

Lot SVX-3 de l'étude `conception/benchmark/SURVIVANT.md` (recommandations validées) : le reste du backlog **côté règles et
contenu**, P1 puis P2 : SV-P1 (recettes d'évolution), SV-M1 (Codex), SV-M2 (records), SV-M3 (défis), SV-E1 (élites lisibles,
événements nommés, gardiens variés), SV-F1 (coffres et ressenti), SV-Q5 (statistiques du mode). Mode scellé : rien du compte
n'est lu ni écrit ; tout l'état du mode vit dans `Profile.records["sv_rewards"]` (déjà écarté de la progression du compte).
Correctif : le fondu d'arrivée qui couvrait le premier choix de carte.

## 1. Ce qui est en place
| Sujet | Fichiers | Contenu |
|---|---|---|
| Recettes d'évolution (SV-P1) | `core/survivor_evo.gd` (`SurvivorEvo`), `core/boons.gd` (une ligne : `get_def` retombe sur `SurvivorEvo.def`), `core/survivor_cards.gd` | **20 recettes** (4 de Boons + **16 neuves**) : **7 d'arme** (chaque type d'arme a la sienne : arme à **+6** + un passif porté ; Séisme, Mille entailles, Volée perçante, Tempête arcanique, Lance du dragon, Poings d'orage, Accord résonnant), **5 de sort** (un sort **niveau 10** + un passif : Résonance, Flux éternel, Fléau, Surcharge, Givre éternel ; le sort lui-même est renforcé : dégâts / recharge / durée inscrits dans son entrée de `Run`), **4 paires de passifs** neuves (Bourreau, Immortel, Œil de faucon, Danse des rafales). Une fois par partie, bannissables. Jamais proposées en Survie (hors de `Boons.all()`). Le **coffre du gardien** offre l'évolution prête en tête. |
| Lisibilité des recettes | `ui/survivor_cards_view.gd` (`evo_hint`, `evo_paths` délèguent), `ui/survivor_build_page.gd`, `ui/survivor_bilan.gd` | pastille de la carte : « ◆ Évolution prête : Séisme » (ou « Évolutions prêtes : A, B »), « ◆ Évolution : + Onde de choc → Séisme », aussi sur une amélioration d'arme (+4 → +6) ou de sort (9 → 10) ; recette d'une autre arme jamais suggérée (l'arme est gardée à vie) ; carte d'évolution « Grâce à : Hache à +6, Onde de choc », sous-titre « Évolution de <sort> » ; pause : les 4 évolutions les plus proches (« il manque… »). |
| Records (SV-M2) | `core/survivor_records.gd` (`SurvivorRecords`) | par classe et palier : victoire la plus rapide, survie la plus longue, plus haut niveau, plus de dégâts, plus de monstres ; « Nouveau record ! » au bilan quand une valeur tenue est battue (la 1re partie pose les scores sans fanfare), « Première victoire avec cette classe · x / 60 » ; classes gagnées. |
| Défis (SV-M3) | `SurvivorRecords.DEFIS` (22) | gagne, 10 minutes, gardiens, évolutions, panoplie 5 / 5, 12 sorts, +10, jets parfaits, niveau 50, 3 000 monstres, gardiens en moins d'une minute, Téméraire (arène avant 17:00), boss en 90 s, arme hors classe, paliers III et V, 5 classes, Codex (10 types d'arme, 10 évolutions, 5 panoplies, 100 monstres) ; 9 donnent un **titre** (cosmétique, `SurvivorRewards.mode_titles()`, écartés du « hub intact »). |
| Codex (SV-M1, SV-Q5) | `core/survivor_codex.gd` (`SurvivorCodex`), `ui/survivor_codex_page.gd` (`SurvivorCodexPage extends PageScreen`), `ui/lobby.gd` (une ligne) | collection propre au mode : évolutions (prises / recette connue / « ? »), armes (17 types × variantes d'auto-attaque), panoplies (complètes / portées), **bestiaire** (monstres des 8 zones vus à l'écran, boss vaincus), records par palier, classes gagnées, défis, **statistiques** (parties, victoires, temps, monstres, arme la plus portée, évolution préférée, classe la plus jouée, victoires par palier). Page du mode : carte « Records et Codex » (records au palier choisi, classes gagnées, défis) et bouton « Codex du Survivant · n % ». |
| Coffres de fin (SV-F1) | `ui/survivor_bilan.gd` (`ChestChip`) | « Tes coffres » au bilan : les coffres gagnés apparaissent l'un après l'autre (fermés, rareté), **« Ouvrir mes coffres »** les ouvre un à un (rayons 520 ms, BIBLE § 7, puis l'apparence gagnée : `Rewards.open`, comme le menu Coffres) ; non ouverts, ils attendent au menu Coffres ; « Réduire les animations » : tout d'un coup. La liste « Gardé » disparaît quand elle ne dit rien de plus. |
| Élites lisibles, gardiens variés (SV-E1) | `core/survivor_events.gd` (`SurvivorEvents`), `core/survivor_director.gd` (3 lignes : `events.tick()`) | chaque élite / géant reçoit un modificateur : **Rapide** (×1,45 vitesse), **Blindé** (PV ×1,5), **Explosif** (zone de 3,5 m annoncée 1,1 s à sa mort, 20 % des PV du héros), **Invocateur** (3 monstres toutes les 7 s, 4 fois) ; étiquette autocollante au-dessus de la tête, nom préfixé dans la barre de cible. Les 3 gardiens : un modificateur chacun, sans doublon (jamais « Blindé » : PV fixes mesurés), annoncé (« Gardien explosif ! »). |
| Événements de partie (SV-E1) | `SurvivorEvents`, `ui/survivor_hud.gd` (frise) | **7:30 « Nuée »** : 25 s de meutes rapides et fragiles ; en vaincre 60 % ouvre un coffre doré. **12:30 « Chasseur »** : élite nommée (rapide, blindée) qui traque le héros ; vaincue en 60 s, un coffre doré, sinon elle s'enfuit. Annoncés 5 s avant, losanges mandarine sur la frise (palpitent pendant l'annonce et l'événement), moments marquants. |
| Ressenti | `ui/survivor_hud.gd` | montée de niveau : onde blanche qui repousse d'environ 2 m les monstres à moins de 4 m (BM-SURV § 7.3). |
| Fondu d'arrivée | `ui/screen_fade.gd` | cause : le fondu `ScreenFade.reveal` était au calque 90, au-dessus du choix de carte ouvert dès l'arrivée ; la toute première image du monde est longue (chargement, mesurée 2,5 s par le vrai chemin lobby → Survivant), le voile noir plein restait donc à l'écran pendant cette image puis 0,8 s de fondu, cartes comprises. Le fondu passe **sous le choix de carte** (calque 19 : au-dessus du HUD et de la pause) : les cartes se lisent dès la première image, le monde sort du noir derrière le flou. |
| Bilan à 1280 × 720 | `ui/survivor_bilan.gd` (`_fit_bilan`) | le bilan du Survivant (déjà à 728 px sur HEAD, signalé par UIK-2) se resserre s'il dépasse : courbe, moments, ligne du Codex, lignes de record en trop. `test_svx2` vert à 1280 × 720 et 1600 × 900. |

## 2. Mesures
Copies propres (`run_tests.preparer_copie`) : HEAD (A) contre HEAD + ce lot (B), même graines, `tools/sim_survivor.py` (pilote moyen 0,5,
palier I, 5 classes × 2 graines) ; machine partagée (temps réels gonflés, comparaison deux à deux).

**Cartes seules** (`tools/sv_cards_sim.tscn -- runs=300 seed=7`, 3 profils de choix) : évolutions par partie **1,37 → 2,87** (pilote),
1,24 → 2,73 (Bot), 1,20 → 2,52 (chercheur de panoplie). Les évolutions d'arme dominent (l'arme atteint +6 dans toutes les parties ; le passif
voulu est souvent sur une pièce) ; les évolutions de sort restent rares (un sort au niveau 10 dans 6 à 33 % des parties) : ce sont les
« découvertes » de fin de partie. Aucune carte de repli de plus.

**Premières mesures (avant la horde SVX-1, réglages d'origine des évolutions)**, 7 parties de chaque côté : victoires 28 % / 28 %,
boss 61 s / 68 s, mais 3e gardien **94 s → 20 s** (médiane) et dégâts subis 225 → 137 % des PV par minute : les évolutions d'arme les plus
fréquentes et « Bourreau » (+60 % contre élites et boss) écrasaient le gardien de 15:00. Réglage : Séisme 35 % / 200 % → 25 % / 150 %,
Mille entailles (critique +5 %, dégâts critiques +25 %, double coup 25 % / 70 %), Tempête arcanique (25 % / 100 %), Lance du dragon (auto +20 %),
Poings d'orage (60 %), Bourreau (+35 %), Œil de faucon (+8 % / +25 %).

**Mesure finale (HEAD 0.1.286 avec la horde SVX-1, réglages ci-dessus, onde de niveau comprise)**, 10 parties de chaque côté :
| | A : HEAD | B : HEAD + SVX-3 |
|---|---|---|
| victoire (pilote moyen) | 30 % | 40 % (bruit de 10 parties : ± 15) |
| tient 10 min · 3 gardiens · boss atteint | 80 · 60 · 60 % | 80 · 60 · 70 % |
| niveau à 5 / 10 / 15 / 20 min | 12 / 20 / 30 / 42 | 12 / 21 / 30 / 41 |
| cartes à 20:00 | 84 | 93 (Nuée et Chasseur : deux coffres dorés de plus quand ils réussissent) |
| dégâts subis (% des PV par minute) | 121 | 116 |
| gardiens 5 / 10 / 15 min (médianes, s) | 169 / 76 / 28 | 152 / 225 / 90 |
| boss (s) | 81 | 84 |
| évolutions par partie | 1,8 | 3,5 |
Lecture : aucun écart hors du bruit sur la victoire, le niveau, le boss ; les évolutions sont des pics de puissance visibles (3 à 6 par partie
réussie) sans écraser le boss (PV fixes). Les gardiens sont plus longs et plus dispersés **des deux côtés** depuis la horde SVX-1 (1er
gardien 169 s sur HEAD, cible 30-90) ; avec ce lot, le gardien « invocateur » ou « rapide » s'y ajoute : à surveiller au journal réel et aux
prochaines mesures du lot horde (levier : `SurvivorEvents.GUARDIAN_AFFIXES`, ou les retirer aux gardiens). `tests/sv7_mesures.json` n'est
pas réécrit : aucun réglage du profil « survivor » ne change (test_sv7 relit les constantes) ; ces nouvelles mesures sont ici.

## 3. Tests et captures
- `test_svx3` (nouveau) : 20 recettes, une par type d'arme, lecture par Boons, jamais en Survie ; Séisme (indice +4 → +6, « il manque », coffre du gardien, procs), Surcharge (indice 9 → 10, sort ×+0,9, un seul par sort), Œil de faucon (indice d'une pièce, bannie), records et défis sur 4 parties, titres écartés du hub, statistiques, références des coffres, bilan (rien sans le bouton, puis ouverts un à un), modificateurs (blindé, gardien jamais blindé), événements, calque du fondu.
- Mis à jour : `test_nav_screens` (Codex), `test_pages` (Codex dans 1280 × 720), `test_sv1` et `test_sv6` (titres du mode : `SurvivorRewards.mode_titles()` ; coche `Ico`), `test_sv8` (cadenas `Ico`).
- Verts sur copie propre de HEAD + lot : test_svx3, test_sv1 à test_sv6, test_sv8, test_sv9, test_svx1, test_svx2 (bilan à 1280 × 720 compris), test_texts_fr, test_pages, test_nav_screens ; `check_scripts` vert.
- Captures regardées (1280 × 720 et 1600 × 900) : `tests/shot_svx3.tscn -- bilan|codex|lobby|cartes|hud` (`SVX3_RES`).

## 4. Restes
- Hors du lot (backlog BM-SURV) : faveurs de départ (SV-R1), pièces maudites (SV-R2), boutique du gardien (SV-R3), accessibilité dédiée
  (SV-A1 : daltonisme, taille des nombres, vitesse du jeu), graine du jour (SV-Q1), prolongations (SV-Q2), choix regroupés (SV-Q3), reprise
  (SV-Q4), fiches d'arme et de sort au Codex (SV-Q6).
- Gardiens : voir § 2 (longs depuis la horde ; les modificateurs de gardien s'y ajoutent).
- `test_sv6` et `test_sv8` lisaient « ✔ » et « 🔒 V » à la page du mode : ICO-1 les a remplacés par des pictogrammes (`Ico.mark`,
  `Ico.lock`) ; les tests lisent désormais le pictogramme (rouges sur HEAD avant ce lot).
