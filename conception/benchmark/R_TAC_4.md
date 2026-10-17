# R_TAC_4 : kits tactiques et rééquilibrage de L'Assaut (lot TAC-4, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.5 (kit de 4 sorts par règles), § 7.6 (rééquilibrage pour une vie, 5 rôles) ;
cibles : **un 1 contre 1 dure 7 à 10 s, personne ne tombe en moins de ~3,5 s depuis la pleine vie**. Socle : `R_TAC_0.md` à
`R_TAC_3.md`. Recommandations par défaut validées par le joueur ; Q10 : « garder la règle générique, mesurer par rôle, corriger
par l'exception de kit plutôt que par la règle ».

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Kits | `tools/assault_kits.py` -> `game/data/assault_kits.json` | 60 classes : rôle tactique (d'après `data/autochess_units.json`) et 4 cases sans enchaînement, par règles (§ 2) ; table `EXCEPTIONS` vide ; `--check` |
| Règles de combat | `game/scripts/core/assault_combat.gd` (`AssaultCombat`) | kits, rôles et passifs, contrôles, insensibilité commune, invisibilité, boucliers, soins plafonnés, chute de portée, prise à revers, révélation du Tireur ; tout gardé par `AssaultCombat.on()` (une partie de L'Assaut) |
| Points d'appel | `combat/combatant.gd`, `player/player.gd`, `ai/class_rival.gd`, `combat/telegraph.gd`, `ai/monster.gd` | une ligne gardée chacun : `_cc_gate`, `add_status`, `take_damage`, `damage_taken_mult`, `heal` ; `Player.stun`, `recalc_stats`, `_heal_action`, `skill_radius` ; soins et effets des sorts des scriptés (`Telegraph.applies`, `_apply_effects`) ; ralenti |
| Vision | `world/assault_vision.gd` | `reveal(équipe, héros, s, par)` : révélé sans ligne de vue (cible du Tireur ; objets du lot TAC-5) |
| Profil `assault` | `game/scripts/core/assault.gd` (`RULES`) | valeurs mesurées (§ 3) et clés du rééquilibrage ; `kit_for` lit le kit ; `--assault-rule=clé:valeur` accepte un dictionnaire JSON |
| Directeur | `core/assault_director.gd` | scriptés armés de leur kit et de leur rôle (`arm_rival`), rôle du joueur, plafond de soins remis à chaque manche, porteur / poseur / désamorceur sans invisibilité (`_mark_busy`), mesure de fin `[assault] mesure` (rôles, temps de survie) |
| Sonde | `game/tools/assault_duel_probe.tscn` | duels 1 contre 1 et focus 3 contre 1 en terrain plat, règles du mode (§ 3) |
| Banc | `tools/assault_games.py` | lit `[assault] mesure` : éliminations et morts par rôle, temps de survie des héros tombés en partie |
| Test | `game/tests/test_tac4.tscn` | voir § 5 |

## 2. Règles du kit (aucun kit écrit à la main)

| Case | Règle | Résultat sur 60 classes |
|---|---|---|
| 1 (gratuite) | sort de dégâts (hors déplacement) de plus courte recharge ; à égalité le plus fort | 60 signatures offensives |
| 2 (achetée) | la mobilité (dash, blink, sort qui fait avancer) de plus courte recharge, sinon le sort de pur dégât le plus court | mobilité 25, dégâts 35 |
| 3 (achetée) | l'utilité selon le rôle : Rempart bouclier > contrôle > renfort > soin > invisibilité ; Ouvreur contrôle > invisibilité > … ; Tireur contrôle > renfort > … ; Contrôleur contrôle > bouclier > … ; Soutien soin > bouclier > renfort > … | contrôle 35, soin 12, bouclier 7, renfort 6 |
| 4 (ultime) | le sort offensif de plus forte valeur (multiplicateur × coups × zone) parmi ceux de plus de 12 s de recharge ; zone × 1,3 ; 7 points | 60 |
| Prix | mobilité 200, dégâts 250, renfort 250, contrôle 300, soin 300, bouclier 300, invisibilité 350 | — |
| Rôles | tank -> Rempart (9), combattant et assassin -> Ouvreur (18), tireur (12), mage -> Contrôleur (9), soigneur et soutien -> Soutien (12) | conforme à l'étude |

Les scriptés jouent leurs cases offensives possédées (lot TAC-4 : achat complet, cases 1 à 3 ; l'ultime vient avec ses points au
lot TAC-5) ; leurs soins et renforts passent par leur soutien d'équipe ; **leurs contrôles touchent enfin** (avant, un sort de
scripté ne faisait que des dégâts) : `Telegraph.applies` les pose sur la cible, sous les règles du mode.

## 3. Mesures et réglages (sonde `assault_duel_probe`, Difficile sauf mention ; machine saturée : 50 à 60 Godot)

Duel = du premier coup à la chute, 1 contre 1 à 10 m ; focus = 3 héros sur une cible passive (ni esquive ni coup).

| Réglage | Duel médian (10e-90e) | Dans 7-10 s | Focus le plus court | Lecture |
|---|---|---|---|---|
| Étude : échelle 0,13, coup 25 %, rafale 55 % + 20 %, auto ×0,8, sans acharnement | **37,8 s** (20,8-59) | 0 / 27 | 4,33 s | trop long |
| échelle 0,7 | 9,9 s (5,2-20,9) | 13 / 40 | **2,50 s** | le reste au-delà de la rafale (20 %) tue trop vite à trois |
| échelle 0,6, rafale 45 % + 5 % | 10,3 s (5,5-22,2) | 7 / 40 | 4,08 s | focus tenu |
| même, même rôle | 13,8 s | 10 / 50 | 4,08 s | les duels d'esquiveurs traînent |
| échelle 1,0 / 1,4, même rôle | 10,6 / 10,5 s | 10 / 50 | 4,13 / 3,53 s | **plus d'échelle ne raccourcit plus** : les coups qui touchent sont au plafond, la durée tient au nombre de coups portés |
| échelle 0,6, coup 30 %, auto ×1, Normal, même rôle | **8,4 s** (5,4-14,4) | 16 / 50 | 4,32 s | retenu |
| même, Difficile, même rôle (+ acharnement 12 s / 6 s) | 12,1 s (7,5-22,0) | 14 / 50 | 4,22 s | les scriptés Difficile esquivent 70 % des coups lus |
| même, Hardcore, rôles mêlés | 19,8 s | 3 / 56 | **3,70 s** | Hardcore : 95 % de lecture, PV × 1,2 |
| **retenu**, Normal, même rôle (graine 7) | 10,4 s (7,2-21,5) | 26 / 60 | 4,15 s | |
| **retenu**, Difficile, rôles mêlés (graine 8) | 11,4 s (6,0-22,0) | 14 / 60 | 4,03 s | |

**Retenu** (profil `assault`) : échelle **0,6**, coup ≤ **30 %**, rafale ≤ **45 % sur 2 s** et **5 %** du reste, auto-attaque
**×1**, acharnement **dès 12 s** (×2 toutes les 6 s), soins ×0,30 et plafond 60 % par manche, contrôles ×0,5 et plafonds de
l'étude, insensibilité commune 2,5 s. Le duel médian est dans la cible en Normal (8,4 à 10,4 s selon la graine) et un peu
au-dessus en Difficile (11-12 s) ; **personne n'est tombé en moins de 3,5 s** dans aucune mesure retenue (3,70 s au plus court,
à trois Hardcore sur une cible passive). L'étude ne prévoyait pas d'acharnement : il est léger et ne touche que la traîne des
duels d'esquiveurs (une manche a sa propre pression : le minuteur et la Charge).

**Parties 4 contre 4** (`tools/assault_games.py --games 8 --win 4`, Bourg, Difficile contre Difficile, achat de 2 s, ×3) :

| Mesure | TAC-3 (avant) | TAC-4 |
|---|---|---|
| Attaque gagne | 94 % | 93 % |
| Façons | Charge 91 %, élimination 9 % | Charge 93 %, **désamorçage 7 %** |
| Manche jouée | 67,7 s | **62,4 s** (10e 53,6, 90e 69,8) |
| Temps de survie d'un héros tombé (premier coup à pleine vie -> chute) | — | médiane **7,4 s**, 10e 5,0 s, **plus court 4,00 s**, 0 sous 3,5 s sur 177 |

Rôles en partie (éliminations / morts par héros et par partie) : Contrôleur 5,6 / 5,5 ; Soutien 4,0 / 5,0 ; Tireur 2,9 / 4,2 ;
Ouvreur 1,2 / 5,1 ; Rempart 1,1 / 5,5. Dans la sonde, rôles mêlés : Tireur 15-17 victoires sur 18-20 et Contrôleur 13-15 sur
14-16 contre les autres rôles, Rempart 4-7 sur 17-21, Ouvreur 1-4 sur 17-23.

## 4. Ce qui reste (et où)

1. **Les rôles de mêlée perdent** (Rempart, Ouvreur) : en terrain plat les scriptés à distance tiennent leurs distances et le
   kit à distance touche plus souvent. La cible de l'étude (aucun rôle hors de 45-55 % en 4 contre 4) est celle du lot TAC-9
   (banc IA contre IA) ; un essai de règle générale (Rempart PV × 1,4, chute de portée dès 12 m et 16 m pour le Tireur) est
   consigné au § 6 ; aucune exception de kit n'est posée avant que l'IA d'équipe (TAC-6) n'aille au contact par les couverts.
2. L'Attaque gagne encore 93 % : la Défense ne reprend pas un site (agent provisoire) — lot TAC-6.
3. Le joueur n'a pas d'esquive « de plus » d'Ouvreur (son esquive n'a pas de charges : 0,45 s de recharge) ; la marche lente
   (Maj) reste à faire avec les réglages du mode (TAC-13).

## 5. Preuves

`test_tac4` : kits des 60 classes (4 cases distinctes de la classe, signature offensive gratuite, 2 cases à prix, ultime à 7 points
et zone × 1,3), 5 rôles aux effectifs de l'étude, `Assault.kit_for` ; hors Assaut rien ne change (renversement de 3 s, invisibilité
de 8 s) ; en Assaut : 3 s -> 1 s, gel refusé pendant le renversement, insensibilité commune 3,5 s, terreur refusée puis 1,2 s,
ralenti 2 s et 30 %, ténacité du Rempart (0,6 s), Talisman multiplié, invisibilité 2,5 s / brisée par un coup / refusée au porteur,
barrière × 0,8 et plancher × 0,6, plafond de soins (600 sur 1 000 PV), soins d'un Soutien comptés moitié, chute de portée (16 m,
Tireur 20 m), scripté armé de son kit (sans l'ultime) avec PV de Rempart et esquive d'Ouvreur, effets d'un sort de scripté posés
sous les règles ; partie réelle : passif du joueur (Guerrier Rempart, PV × 1,2), kit du joueur, zone de l'ultime × 1,3, rôle de
chaque scripté, cible révélée 1,5 s puis plus.

## 6. Essai non retenu et non-régression

Essai de règle générale pour la mêlée (`--rule 'role_hp:{"rempart":1.4}' --rule falloff_at:12 --rule tireur_falloff_at:16`,
8 parties dont 6 finies, 37 manches) : Rempart 1,1 / 4,9 (0,22 au lieu de 0,20), Ouvreur 1,3 / 4,9 (0,27 au lieu de 0,24),
Attaque 92 %, manche 63,0 s, et un héros tombé en 3,40 s : **rien ne bouge** pour la mêlée — ce n'est pas une affaire de PV ni de
portée mais de comportement (les scriptés de mêlée courent à découvert vers des tireurs qui reculent). Non retenu ; à revoir
avec l'IA d'équipe (TAC-6) puis au banc (TAC-9).

Non-régression (copie propre de HEAD 0.1.309 + TAC-4, `run_tests.py --reuse -j 2`, machine saturée) : **12 verts sur 12** —
test_tac0 à test_tac4, test_mode0, test_pvp, test_duel_modes, test_m7, test_royale, test_nav_screens, test_texts_fr.
`check_scripts.py` vert sur l'arbre du commit ; `tools/assault_kits.py --check` à jour.
