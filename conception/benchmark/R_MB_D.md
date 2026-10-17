# R_MB_D : Les Deux Voies, lot MB-D — héros en partie et boutique

Lot MB-D du plan `conception/benchmark/MOBA.md` (§ 7.3, § 7.6, § 7.7, § 9), sur les lots MB-A (règles), MB-B (carte) et MB-C
(tours, sbires, partie de bout en bout). Recommandations par défaut de l'étude : validées. Le mode reste caché (« Bientôt ») :
l'IA par poste est le lot MB-E, le HUD et la boutique à l'écran le lot MB-H ; ici une interface minimale de test (une ligne
d'état et quatre touches) et toutes les données d'affichage exposées.

## 1. Livré

| Élément | Fichier | Rôle |
|---|---|---|
| Héros en partie | `game/scripts/core/moba_hero.gd` (`MobaHero`, nouveau) | état d'un héros (niveau, XP, or, objets, potions, K / M / A, série, sbires achevés, camps, réapparition, rappel, enchaînements débloqués, choix en attente, achats annulables, journal des morts) ; règles pures (partage, rattrapage, aides, déblocages) ; `view()` = données du HUD |
| Boutique et objets | `game/scripts/core/moba_items.gd` (`MobaItems`, nouveau) | achat / recette / refus / annuler / vendre / potions ; parcours conseillé adapté ; « prochaine étape » en un appui ; totaux et fiches (joueur, IA) ; effets déclenchés des 40 objets sur n'importe quel héros |
| Directeur | `game/scripts/core/moba_director.gd` | un `MobaHero` par héros ; XP et or (sbires, éliminations, structures, camps, passifs) ; niveaux et kit ; réapparition selon le niveau ; rappel ; boutique à la fontaine ; `hud_data()` ; interface de test ; mesures (`--moba-perf` : temps des scripts de chaque image, coût par héros ; ligne `[moba] bilan {json}`) |
| Héros IA | `game/scripts/ai/moba_rival.gd` | fiche du niveau de partie + objets ; sorts débloqués (enchaînements, ultime à 60-90 s et × 1,6, gardé pour les héros) ; vitesse d'attaque, recharges, course des objets ; zones interdites (lot MB-E) |
| Branchements | `combat/combatant.gd` (5 lignes gardées par `MobaItems.active`), `player/player.gd` (1 ligne dans `recalc_stats`), `core/moba.gd` (`--moba-auto`, arrêt des objets), `core/moba_data.gd` (infobulle de la Lame de braise) | — |
| Mesure | `tools/moba_ai_games.py` | parties IA contre IA en parallèle, temps CPU du processus par image physique (GetProcessTimes), bilan JSON par partie |
| Tests | `game/tests/test_mb_hero.tscn`, `game/tests/test_mb_shop.tscn` | § 4 |

## 2. Règles codées

- **Niveaux 1 à 12 par XP** (MobaData : 120, 160 … 520 ; 3 520 pour le niveau 12) ; fiche d'un héros de la classe au niveau
  30 + 5 × (niveau − 1), refaite à chaque niveau (une par image), PV gardés en proportion.
- **Le niveau fait grandir le kit** : 1 = cases 1-3 ; 2, 3, 4 = 1er enchaînement d'une case au choix ; 5 = ultime (case 4, à sa
  recharge de partie de 60-90 s et sa puissance × 1,6 : clés « cd » et « dmg » de `Run.skills` pour le joueur, fiche de sort
  doublée pour l'IA) ; 6, 7, 8 = 2e enchaînement d'une case au choix ; 9 = enchaînement de l'ultime ; 10-12 = la fiche monte.
  **Choix non bloquant** : il attend dans `MobaHero.pending` (le jeu continue), Ctrl + 1 / 2 / 3 le fait ; `--moba-auto` (et le
  pilote automatique) le fait seul ; l'IA le fait seule dans l'ordre de ses cases les plus fortes (`_ai_prefer`).
- **XP** : sbire partagé entre les héros adverses à 15 m (le tueur compris) ; élimination 100 + 25 × niveau de la victime,
  partagée entre le tueur et ses aides ; camp (lot MB-F) au tueur ; 1 par seconde pour tous.
- **Or** : départ 500 ; 2 / s dès 0:40 ; sbire : 100 % au dernier coup d'un héros, 60 % à chaque autre héros proche, 50 % à
  chacun si un sbire ou une tour l'achève ; rattrapage + 30 % (XP et or des sbires) sous la moyenne adverse de 2 niveaux ;
  élimination 300 (+ 100 premier sang, + 100 par élimination de la série de la victime au-delà de 2, 700 au plus) ; aide 150
  partagée (aide = a frappé la victime dans les 10 s) ; une victime achevée par une tour ou un sbire donne la prime au dernier
  héros adverse qui l'a frappée ; tour T1 250, T2 300 à chacun du camp.
- **Réapparition** : 5 + 2 × niveau du héros (× 1,25 dès 15:00, × 1,5 dès 18:00), à la fontaine, sans recréer le modèle.
- **Rappel** (X, action `extract`) : 6 s sans bouger ni être touché (`MobaJungle.recall_time` de la Bannière : lot MB-F) ;
  fontaine : 12 % des PV par seconde.
- **Boutique** : ouverte à 14 m de la fontaine et pendant la mort ; 6 places bottes comprises, une seule paire de bottes, un
  objet fini porté une fois ; recette : on ne paie que la différence (composants pris) ; annuler (or et composants rendus) tant
  qu'on ne quitte pas la base ; vendre 70 % ; potions à part (5 de chaque au plus ; le joueur garde les siennes dans le sac,
  touches C / V ; 2 potions de soin au départ). **Parcours conseillé** par famille (2 chacune) adapté à l'équipe adverse
  (2 Ombre ou plus : Bouclier du gardien tôt ; 2 Arcane ou plus : Heaume du colosse ; 2 Ferveur ou plus : Lame de braise) ;
  « Acheter » en un appui = l'objet fini suivant s'il est payable, sinon son composant manquant le plus cher payable.
- **Stats des objets** en part de la fiche de base (additionnées) : PV, attaque ou magie (Bâton : + 25 % de toute la magie),
  défense, critique, vitesse d'attaque, recharges (50 % au plus), vol de vie, puissance de soin, course ; posées après les
  plafonds du mode. Joueur : une ligne de `Player.recalc_stats`. IA : `MobaRival.resheet` (PV, attaque, défense, critique) ; la
  vitesse d'attaque raccourcit la fin de ses coups et sa pause (jamais l'annonce rouge), les recharges ses minuteurs de sorts,
  la course sa vitesse.
- **Effets déclenchés sur un Combatant** (la table `Procs` du jeu ne connaît que le `Player` : les objets passent par
  `MobaItems`, branché par des lignes gardées de `Combatant`) : Lame de braise (un critique brûle 3 s ; soins reçus − 40 %
  pendant la brûlure), Croc du chasseur (élimination : + 15 % des PV), Arc-tempête (foudre un coup sur trois, saute sur un 2e
  ennemi), Faux de la Lune (après un sort, coup suivant × 1,5), Brise-garde (25 % de la défense ignorés), Lame de l'exécuteur
  (jusqu'à + 20 % sur un héros sous la moitié de ses PV), Orbe des marées (sort sur un héros : bouclier 8 %), Grimoire des échos
  (un sort sur cinq frappe une 2e fois à 60 %), Sceptre du givre (sorts : ralenti 1,5 s), Lanterne des âmes (10 % des dégâts des
  sorts soignent), Égide (+ 10 % de défense par ennemi proche au-delà du premier), Cœur de pierre (3 % des PV / s hors combat),
  Cape d'épines (15 % des auto-attaques renvoyés), Bouclier du gardien (sous 30 % : bouclier 25 %, 60 s), Armure vivante (+ 20 %
  de soins reçus), Heaume (contrôles et ralentis 30 % plus courts), Encensoir / Médaillon / Harpe (soin d'un allié : il frappe
  plus vite / bouclier / il court plus vite), Étendard (sbires alliés à 10 m : + 20 % de dégâts), Sablier du sage (élimination ou
  aide : − 30 % des recharges en cours), Bottes du vent (+ 12 % de course hors combat). Hors combat = 5 s sans coup donné ni reçu.
  Un effet ne déclenche pas d'autre effet (profondeur 1).
- **Données d'affichage** (`MobaDirector.hud_data(h)` = `MobaHero.view` + parcours, objet conseillé avec prix réel et or,
  temps, score, tableau des 8 héros) ; interface de test : une ligne d'état (niveau, XP, or, K / M / A, objets, choix, conseil,
  boutique, rappel) et P (acheter l'étape conseillée), Ctrl + Z (annuler), Ctrl + 1 / 2 / 3 (choix de niveau), X (rappel).

## 3. Mesures

Copie de HEAD 0.1.314 + ce lot, 8 IA en Difficile (IA de voie provisoire du lot MB-C : le lot MB-E la remplace), `--fixed-fps 60`,
× 4, de 1:00 à 8:00, processus un cran au-dessus (machine à 70-80 processus Godot) : `python tools/moba_ai_games.py --perf`.

| Mesure | 8 IA (3 parties) | Vagues seules (2 parties) | MB-C (rappel) |
|---|---|---|---|
| Temps CPU du processus par image physique | **4,51 / 4,57 / 5,18 ms** (médiane 4,57) | 2,22 / 2,32 ms | 4,07 / 2,11 ms |
| Scripts de l'image physique, p95 (temps mur, borne haute) | 3,08 ms | 0,72 ms | — |
| Un héros IA (MobaRival entier : ClassRival + monstre + mouvement, temps mur) | 142 µs par image (max 206) | — | — |

Les héros coûtent ≈ 0,3 ms de plus par image qu'au lot MB-C (fiches refaites aux niveaux, objets, effets, économie) : la
logique reste sous le budget de 5 ms (R_MB0 § 6) en temps CPU. Économie observée avec l'IA provisoire (aucun combat de héros,
aucune jungle) à 10:00 : niveaux 6-10, 1 500-2 900 or gagnés par héros (le calibrage de la durée et de l'or est le lot MB-J).

## 4. Tests

- `test_mb_hero` (nouveau, 37 contrôles) : règles pures (déblocages par niveau, choix non bloquant et refusé, choix
  automatique dans l'ordre préféré, XP bornée au niveau 12, partage de l'XP et de l'or, rattrapage, primes, aides,
  réapparition) ; partie réelle : 8 états, départ (niveau 1 = fiche 30, 500 or, 2 potions, 3 sorts), **niveau 5 = ultime**
  (joueur : 4e case à 64 s et × 1,6 ; IA : dans ses sorts, enchaînements choisis seuls), Ctrl + 1, fiche plus forte, sbire achevé
  (or et XP exacts), élimination (prime, premier sang, réapparition selon le niveau), or passif, rappel (coupé par un coup, puis
  6 s jusqu'à la fontaine), boutique fermée loin de la base, données d'affichage, objets coupés après la partie.
- `test_mb_shop` (nouveau, 42 contrôles) : achat, recette (différence payée), refus (or, place, bottes, doublon, boutique
  fermée), **annuler rend l'or et les composants**, vendre 70 %, potions, parcours adapté, un appui, achat automatique, conseil ;
  partie réelle : **achat → stats** du joueur (+ 10 % d'attaque, + 10 % de PV) et de l'IA (PV, attaque, vitesse d'attaque,
  recharges), annuler rend la fiche ; 15 objets à effet vérifiés un par un sur des héros et des sbires réels.
- Suite demandée (copie de HEAD 0.1.312 + lot, `run_tests.py -j 2`) : test_mb_data, test_mb_map, test_mb_lanes, test_mb_hero,
  test_mb_shop, test_mode0, test_pvp, test_duel_modes, test_m7, test_royale, test_texts_fr : **11 verts** (test_mb_data rouge
  seulement tant que `tools/moba_kits.py` manquait dans la copie : la copie de `run_tests.py` ne contient que `game/` ; vert
  une fois le script posé à côté). Repassés sur HEAD 0.1.314 + lot : test_mb_data, test_mb_hero, test_mb_shop verts.

## 5. Pièges
1. `ClassRival` ne suit son but (`goal`) que s'il a une cible valide : sans cible, il reste planté (le lot MB-C lui donnait le
   Cœur adverse comme cible « de regard ») : `MobaHeroAi._go` fait de même.
2. Les dégâts entre héros passent par les plafonds du mode (coup ≤ 22 % des PV) même pour un effet sur la durée : un test qui
   veut une élimination pose d'abord les PV à 1.
3. Le lanceur `Godot_…_console.exe` est un autre processus : son temps CPU (GetProcessTimes) est nul ; mesurer avec l'exécutable
   sans console (comme `tools/moba_probe.py`).
4. Deux équipes ont écrit dans `moba_director.gd` en même temps (MB-F) : chaque envoi reconstruit sa version depuis HEAD
   (retrait des blocs de l'autre lot, lignes gardées par des remplacements exacts) ; aucune référence statique à `MobaJungle`
   dans ce lot (lu par `get("jungle")`).
5. `Path.write_text` de Python écrit des fins de ligne CRLF sous Windows : toujours `write_bytes` (le dépôt est en LF).

## 6. Pour la suite
- MB-E : `MobaHeroAi` (poste, tours et sbires respectés, rappel, achats) sur `MobaRival.avoid` / `dive_ok`, les données de
  `MobaHero` et l'interface de la jungle (`MobaJungle.camps`, `MobaDirector.reward_camp`).
- MB-F : `reward_camp` (XP, or, compte des camps), `reward_objective` à écrire s'il faut autre chose que l'XP à l'équipe.
- MB-H : HUD et boutique à l'écran sur `hud_data()` ; maintien 0,6 s pour vendre ; onglets `MobaData.TABS`.
- MB-J : calibrer la durée et l'or (or estimé à 17 min : ≈ 7 000 par héros) avec l'IA de poste et la jungle.
