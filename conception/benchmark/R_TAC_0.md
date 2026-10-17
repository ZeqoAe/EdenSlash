# R_TAC_0 : socle de L'Assaut (lot TAC-0, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` (§ 7.1 à 7.3, § 9). Socle commun : `R_MODE0.md` (TeamMatch). Recommandations par
défaut de l'étude **validées** par le joueur. Mode **scellé** (rien du compte), joué seul avec 3 alliés IA contre 4 IA.

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Règles et machine de manche | `game/scripts/core/assault.gd` (`Assault`) | profil `assault` de ModeRules (combat + manche + or), machine pure sans scène : achat → manche → pose / désamorçage → fin → mi-temps / prolongation → fin de partie ; or de manche ; formats Assaut et Éclair ; lancement (`launch`) et fin (`finish`) scellés ; options d'un lancement direct (`args_options`) |
| Directeur de scène | `game/scripts/core/assault_director.gd` (`AssaultDirector`) | monté par `TeamMatch.mount` (fiche « assault », état « team » de RunDirector) : carte, 8 héros (ou 8 IA en spectateur), manches, pose et désamorçage (joueur : [Interagir] maintenu, immobile), mort du joueur, abandon, bilan provisoire, agent IA provisoire |
| Lancement direct | `game/scripts/core/world.gd` | `world.tscn -- --assault [--assault-watch --assault-map=arena --assault-diff=0..3 --assault-format=eclair --assault-side=attack --assault-seed=N --assault-speed=N --autoplay --auto-quit --trace]` |
| Activité | `game/scripts/ui/activities.gd` | « L'Assaut » (rangée Affrontements) marquée **Bientôt** : cachée tant que le mode n'est pas jouable de bout en bout |
| Test | `game/tests/test_tac0.tscn` | machine pure (manche, primes, mi-temps, prolongation, Éclair, 200 parties tirées au hasard) + partie réelle IA contre IA accélérée sur l'arène simple |

## 2. Règles codées (profil `assault`, `Assault.RULES` ; tout passe par ModeRules : mode dev et modificateurs compris)

| Règle | Valeur | Remarque |
|---|---|---|
| Équipes | 4 contre 4 (équipe 0 = la tienne), classes différentes dans une équipe, familles différentes d'abord | `Assault.pick_classes` (exclues comme au Battle royale : Lame noire, Lame de lumière) |
| Partie | premier à **7**, 12 manches au plus, **mi-temps après 6** (côtés changés, 800 d'or chacun, séries remises) | |
| Prolongation | à 6-6 : blocs de 2 manches (une par côté), **4 000 d'or fixes** à chaque manche, **2 manches d'écart** ; après 3 blocs : **manche décisive** (côté tiré au sort) | |
| Éclair | premier à 4, 7 manches, mi-temps après 3, la 7e décide, 1 200 d'or au départ | format `eclair` (lot TAC-12 pour son entrée au lobby) |
| Achat | 20 s (25 s à la 1re manche de chaque moitié) ; le joueur reste dans son départ (barrière : lot TAC-7) | l'écran d'achat : lot TAC-5 |
| Manche | 1:40 ; la Défense gagne au temps si rien n'est posé | |
| Pose | 4 s immobile dans un site (porteur : le 1er attaquant debout, lot TAC-3 pour la Charge portée) ; un pas, un coup, un sort, une esquive ou un étourdissement l'annulent | |
| Après la pose | mèche de 40 s ; Défense à terre = l'Attaque gagne aussitôt ; Attaque à terre = la manche continue | |
| Désamorçage | 7 s, **point de sauvegarde à la moitié** (`Assault.defuse_resume`) | Pinces (4 s) : lot TAC-5 |
| Or | victoire 2 400 ; défaite 1 500 → 1 900 → 2 300 → 2 700, **une victoire fait redescendre la série d'un cran** ; élimination 200, aide 50 (≥ 30 % des PV de la cible) ; pose +300 à chaque attaquant ; désamorçage +200 ; attaquant vivant au temps sans pose : pas de prime ; plafond 7 000 | |
| Combat (PvpCaps) | échelle 0,13, auto-attaque ×0,8, soins ×0,30, coup ≤ 25 % des PV, rafale ≤ 55 % sur 2 s (reste ×0,2), pas d'acharnement | valeurs de départ de l'étude, **à mesurer par la sonde de TAC-4** |
| Fiche | niveau 50, aucune pièce, ni talent, ni certificat (scellé) ; kit provisoire = les 4 premiers sorts de dégâts ou de contrôle de la classe (`Assault.kit_for`, remplacé par `data/assault_kits.json` au lot TAC-4) | |
| Fiche TeamMatch | ni potions, ni cartes de niveau, ni journal, ni sauvegarde en cours de partie ; `Modes.current()` = assault, `Modes.kind()` = objective | jamais `Duel.active` ni `Royale.active` (piège 1) |

## 3. Directeur et IA provisoire

- Chaque manche, les héros scriptés sont **recréés** (une vie, PV pleins) ; le joueur est relevé dans son départ. Les héros tombés
  sont libérés par leur animation de mort : le directeur ne garde jamais de référence typée vers eux (`hero(clé)` vérifie).
- K.O. : prime d'élimination au tueur, aide à qui a fait ≥ 30 % des PV de la victime ; `TeamMatch.note_ko`, `TeamMatch.end_round`
  (frise de TeamMatch), `PvpCaps.board` vidé à chaque manche (piège 3).
- **Agent provisoire** (remplacé par le stratège et l'agent du lot TAC-6) : l'Attaque va ensemble au site tiré pour la manche, le
  porteur pose quand aucun adversaire n'est à moins de 9 m ; la Défense tient 2-2, puis reprend le site de la Charge (le plus proche
  désamorce) ; un adversaire à moins de 16 m est combattu par `ClassRival` tel quel.
- Fin : `TeamMatch.finish`, `Assault.finish()` (TeamMatch.end() **avant** toute écriture, piège 11 ; sauvegarde rechargée ;
  vitesse du jeu rendue), bilan provisoire `ResultsPanel` (score, manches, façons de gagner ; Rejouer, Menu principal). Les
  récompenses scellées, les quêtes (`Quests.end_run("assault")`), la frise et le tableau des 8 : lot TAC-8.
- Mesures : `--trace` imprime toutes les 2 s chaque héros (position, but, état, PV) ; `--auto-quit` une ligne `[assault] fin`.

## 4. Preuves

`test_tac0` (vert) : 41 contrôles de la machine pure + 16 de la partie réelle. Partie réelle (arène simple, 8 IA Difficile, ×3,
règles d'essai : premier à 3, mi-temps après 2, manche de 30 s, mèche de 22 s) :

```
manche 1 gagnée par l'équipe 0 (défense, temps) en 30.0 s : 1 - 0
manche 2 gagnée par l'équipe 0 (défense, désamorçage) en 16.4 s : 2 - 0      (Défense mise à l'écart, pose, puis reprise)
manche 3 gagnée par l'équipe 1 (défense, temps) en 30.0 s : 2 - 1            (mi-temps : l'équipe 0 attaque ; tous immobiles)
manche 4 gagnée par l'équipe 1 (défense, temps) en 30.0 s : 2 - 2
```

Aucun coup entre équipiers ; navigation cuite avant la fin ; après la partie : TeamMatch fermé, menu, rien de scellé, vitesse
rendue ; bilan affiché. 200 parties pures au hasard : un vainqueur valable à chaque fois (7 à 19 manches, médiane 11).
Partie complète au pilote (`--assault --assault-watch --assault-speed=2 --assault-win=2 --trace`, règles normales) : la manche
1 dure 55,6 s, gagnée par la Charge après une pose à 15 s ; les combats durent encore longtemps (règles de combat non mesurées :
lot TAC-4).

Suite de non-régression (copie de HEAD + TAC-0, `run_tests.py -j 2`) : voir § 6.

## 5. Pièges et suites

1. Les héros scriptés tombés sont **libérés** : jamais `var h: Combatant = dico[clé]` (erreur « previously freed ») ; passer par
   `AssaultDirector.hero(clé)`.
2. `TeamMatch.members` garde des références libérées d'une manche à l'autre : le directeur les purge à chaque manche.
3. Les 30 s de manche du test font souvent finir au temps (les combats ne sont pas encore réglés) : un test d'Assaut attend des
   événements (pose, désamorçage, fin), jamais une durée.
4. `Engine.time_scale` (option `speed`) n'est rendu que par `Assault.finish()` : tout outil qui coupe une partie doit l'appeler.
5. Le porteur est « le 1er attaquant debout » : la Charge portée, lâchée et ramassée vient au lot TAC-3 (avec les bips).
6. Rien n'arrête encore la vue ni les coups (lot TAC-2), la carte est l'arène simple (lot TAC-1 : le Bourg).

## 6. Suite de non-régression

Copie propre de HEAD 0.1.295 + TAC-0 (`run_tests.py --reuse -j 2`, machine chargée par d'autres agents) : **11 verts sur 11** —
test_tac0 (72 s), test_mode0, test_pvp, test_duel_modes, test_m7, test_royale (118 s), test_nav_screens, test_texts_fr,
test_compass, test_lot10, test_pages (ces trois parcourent `Activities.LIST` : l'entrée « Bientôt » ne change rien à l'écran).
`check_scripts.py` vert sur le dossier de travail (HEAD 0.1.297 + travaux en cours). Partie directe au pilote
`world.tscn -- --assault --autoplay --auto-quit --assault-win=2 --assault-speed=2` : 2 manches (Charge à 59 s, élimination à
55 s), ligne `[assault] fin`, sortie propre.
