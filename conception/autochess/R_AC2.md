# R_AC2 — Sonde technique de l'Échiquier (autochess) : l'IA scriptée en combat d'équipe

Session AC2, 16-17/10/2026. Outils : `game/tools/ac2_probe.gd/.tscn` (sonde, rien n'est écrit), `game/tools/ac2_unit.gd`
(prototype « IA v2 » = `ClassRival` + corrections). Aucun fichier existant modifié.

**Décision du joueur (en cours de lot)** : plus aucun cerveau neuronal dans l'autochess (« mieux vaut 0 qu'un seul cerveau qui
oblitère le plateau ; il faut que nos IA scriptées jouent très bien »). Les mesures de cerveaux restent en §5 pour mémoire.
→ À reporter dans `SPEC.md` §4.2 (capitaine) : le capitaine devient une unité scriptée.

## 0. En bref
- **Faisable** : 0,10 ms par unité scriptée et par image (headless) ; 24 unités = 2,4 ms. Aucun tir allié (0,00 % de
  dégâts égarés sur ~1 500 combats), aucune unité hors plateau, unités bloquées ≈ 1-2 % du temps.
- **Pas encore fun** : l'IA actuelle (`ClassRival` Difficile) est lente et passive en équipe : combats de 80-86 s (cible 20-40),
  27 % du temps sans infliger de dégâts, 17 % du temps à s'éloigner de l'ennemi, 0,72 esquive/s pour 1,03 coup/s ; soins et
  renforts gardés pour soi ; assassins et danseuses inutiles (dégâts × 0,2-0,5 de la moyenne, morts 94-100 %).
- **Prototype IA v2** (`tools/ac2_unit.gd`, 7 corrections ciblées) : **98-100 % de victoires** contre l'IA actuelle à
  composition égale (miroir, 40 combats par taille, 3v3 / 5v5 / 8v8). La correction qui pèse le plus : le soutien d'équipe.
- **Durée** : l'échelle des dégâts n'est qu'un levier faible (× 5 → durée ÷ 2) ; avec la v2, **dmg_scale 0,20** donne
  28,6 / 30,4 / 32,8 s (3v3 / 5v5 / 8v8, 60-80 % des combats entre 20 et 40 s).

## 1. Montage de la sonde
Plateau 8 × 8 cases de 2 m (16 × 16 m) muré, sol plat sans carte (déplacement en ligne droite), deux camps de N unités placés
en formation (mêlée devant, distance derrière). Unités = `ClassRival` (difficulté Difficile) à la fiche d'un héros nu de niveau
10 (`Royale.sheet` puis `use_sheet`, comme le Battle royale), niveau 30 vérifié aussi. Règles : `Duel.active` + mode d'équipe
(`Duel.extra_foes` non vide → `ClassRival._team_mode()`), profil `ModeRules` « arena3 » (échelle 0,024, acharnement dès 20 s,
mort subite dès 90 s), modifiable en mémoire (`--scale`, `--heal`, `--pressure`, `--sudden`). Camps : **`ffa_id` = numéro du
camp** (coups, cibles et zones réglés par `Combatant.ffa_foes`), ou camps natifs (`ally` contre adversaires, `--camps=native`).
Plusieurs plateaux simulés ensemble à 400 m les uns des autres (`--batch`), `--fixed-fps 60` headless.

Mesures par unité, échantillonnées toutes les 0,25 s : inactif (aucun dégât infligé depuis 3 s, ennemis debout), loin
(> 6 m de l'ennemi le plus proche), s'éloigne (vitesse < -2 m/s vers l'ennemi le plus proche), bloqué (< 0,3 m en 2 s à plus de
4,5 m de tout ennemi), coups / sorts / esquives par seconde, distance moyenne, concentration (cibles distinctes / unités),
dégâts égarés (|dégâts reçus par un camp − infligés par l'autre| / total), hors plateau.

## 2. L'IA actuelle (ClassRival) en combat d'équipe : défauts mesurés

### 2.1 Durée (cible 20-40 s)
| Série (IA v1 Difficile, niveau 10, 30 combats) | 3v3 | 5v5 | 8v8 |
|---|---|---|---|
| arena3 (0,024) : médiane | 82,3 s | 86,4 s | 80,9 s |
| combats entre 20 et 40 s | 0 % | 0 % | 0 % |
| fin en mort subite (> 90 s) | 27 % | 37 % | 17 % |
| niveau 30 (20 combats) | 86,4 s | 77,6 s | — |
| échelle 0,05 / 0,08 (20 combats) | 63,5 / 55,7 s | 68,6 / 59,9 s | 62,7 / 51,9 s |
| Facile (moins d'esquives), 0,05 / 0,08 | 59,1 / 47,7 s | 62,7 / 45,7 s | 58,5 / 49,9 s |
1 contre 1 miroir : 92,5 s, 46 % du temps inactif, 50 % de morts subites.

### 2.2 Comportement (moyennes 3v3 → 8v8)
| Défaut | Mesure | Cause dans le code |
|---|---|---|
| **Inactivité** | 27 % (3v3) → 19 % (8v8), 46 % en 1v1 | les deux camps esquivent les zones de l'autre (`_read_zones`, lecture 0,7 en Difficile, 2 charges) ; bond réflexe sous les coups (`take_damage` : 60 % de chances en Difficile) ; annulation après impact (`cancel` 0,5) |
| **Éloignement** | 17 % du temps à s'éloigner ; 24-36 % à plus de 6 m | repli 2,5 s sous 30 % de PV (`_update_retreat`), bonds de recul, mêlée qui « tourne hors de portée du héros » à ~4,5 m en attendant son coup (`_update_chase`, pensé contre le joueur) |
| **Esquive des zones alliées** | en `ffa_id`, une unité esquive aussi les zones de ses équipiers | `_read_zones` ne saute que les zones de son `team` quand `src.ffa_id < 0` |
| **Soutien d'équipe perdu** | soins et renforts : soi seul | `_teammates()` rend `[self]` dès que `ffa_id >= 0` |
| **Ciblage** | concentration 0,4-0,6 (plutôt bon) ; en équipe il vise « le plus faible pas trop loin » (`FOCUS`), d'où des traversées | `ClassRival.pick_target` |
| **Cible figée (camps natifs)** | 6-7 « cibles perdues » par 3v3, jusqu'à 22 s d'unités bloquées | `Monster._physics_process` ne recible que si `pool.size() > 1` : une unité adverse dont la cible meurt reste plantée face au dernier ennemi (la sonde la recible et compte le cas) |
| **Sorts hors de portée** | un cône de 3 m peut partir à 8 m | `_start_attack` prend le premier sort prêt, sans regarder la distance |
| **Portée** | 27 classes ont `attack_range` (9-13 m) et le script la respecte ; **mais 3 classes à guitare** (Barde, Chantre de guerre, Chantre de vie) se tiennent à 10 m avec une auto-attaque de mêlée : coups dans le vide | `_attack_range()` lit `cls.attack_range`, `auto_step` vient de l'arme |
| Tir allié, hors plateau | 0,00 % ; 0 unité | `hostile_targets` / `ffa_foes` partout (télégraphes, projectiles, flèches du héros) |

Correction d'une idée reçue : **les 24 classes à arme à distance ne sont pas jouées au contact** (première lecture des données,
fausse : `attack_range` est bien présent pour elles, les 24 + 3 guitares = 27). Le seul défaut de portée est celui des 3 guitares.

### 2.3 Par classe (180 combats 3v3, chaque classe ~16-25 fois ; part des dégâts de son camp × 3, 1,00 = moyenne)
- **En tête** (zones au sol, à distance) : Druide × 1,74, Maître de la gravité × 1,73, Chaman × 1,58, Magicien × 1,54,
  Annihilateur × 1,50, Arès mécanique × 1,50, Chaman des totems × 1,49 ; inactifs 9-19 %.
- **En queue** (mêlée à esquive / bond) : Voleur × 0,28 (inactif 57 %, morts 94 %), Samouraï × 0,31 (60 %), Danseuse
  envoûtante × 0,38, Assassin × 0,39 (50 %, morts 100 %), Kage × 0,39 (50 %, 100 %), Danseuse de lames × 0,40, Maître du temps
  × 0,44, Danseuse d'épées × 0,47, Maître des chimères × 0,51. Les « assassins » meurent en première ligne sans rien tuer :
  il leur manque un rôle (plonger sur l'arrière), pas des chiffres. La v2 ne les corrige pas (Voleur × 0,20, Assassin × 0,49).

### 2.4 Kits des 60 classes (`--mode=kits`)
- Sorts lancés par le script : les 4 premiers sorts d'attaque de la classe (`ClassRival.setup`), soins et renforts à part
  (`_support`, en équipe seulement). 31 classes ont une zone visée (`ground`) dans leurs 4 : idéal pour un autochess.
- **17 classes ont un sort de déplacement** (dash / blink) dans leurs 4 (elles quittent la formation) : Flèche absolue,
  Assassin, Asura, Berserker, Danseuse d'épées, Maître-sabre, Danseuse envoûtante, Flèche sacrée, Illusionniste, Kage,
  Luminaire, Héritier du sabre, Rakshasa, Samouraï, Protecteur, Voleur, Démoniste.
- **22 soigneurs** : leurs soins ne servent qu'à eux en `ffa_id` (défaut ci-dessus).
- **17 classes gaspillent leurs renforts** (≥ 6 renforts / soins sur les 12 sorts d'un kit de cerveau ; côté script, renforts
  posés sur soi seul) : Juge sacré, Chaman des totems, Barde, Chantre de guerre, Clerc, Envoûteur, Chevalier de sang, Maître
  des chimères, Druide, Danseuse envoûtante, Prêtre de l'ombre, Chantre de vie (10 / 12), Orateur sacré, Paladin, Psalmiste,
  Sage, Chaman. Le capitaine scripté (SPEC §4.2) doit recevoir un kit de **sorts d'attaque** + 1 soutien d'équipe au plus.
- Chantre de vie : 3 sorts d'attaque seulement. Aucune invocation dans les données (aucun sort de type invocation).

### 2.5 Étoiles (16 combats par case, mêmes classes des deux côtés)
| Cas | Victoires du camp étoilé | Durée médiane |
|---|---|---|
| 1v1 miroir × 1,8 / × 3,24 | 100 % / 94 % | 76,5 / 64,8 s |
| 3v3 miroir × 1,8 / × 3,24 | 100 % / 100 % | 69,7 / 47,8 s |
| 1 × 1,8 contre 2 × 1 / 3 × 1 | 13 % / 0 % | 89 / 71 s |
| 1 × 3,24 contre 3 × 1 | 69 % | 89,5 s |
Le palier × 1,8 / × 3,24 (PV et attaque) de la SPEC fonctionne avec la formule JcJ (`PvpCaps.damage_mult` garde le rapport
des forces ; les plafonds 15 % par coup et 35 % sur 2 s ne mordent pas). Une ★2 vaut un peu moins de 2 ★1, une ★3 un peu plus
de 3 ★1 : cohérent avec un autochess (3 copies = 1 étoile). Rien à ajouter au socle, sinon le multiplicateur.

## 3. Prototype « IA v2 » et banc d'essai

### 3.1 Corrections (`game/tools/ac2_unit.gd`, `extends ClassRival`, ~150 lignes, chacune coupable par `opts`)
| Clé | Correction |
|---|---|
| `team`, `zones` | camp = `ffa_id` : `_teammates()` rend les équipiers vivants (soins au plus bas sous 50 %, renforts à tous) ; `_read_zones` ignore les zones des équipiers |
| `retreat` 0 | pas de repli sous 30 % de PV |
| `reflex` 0 | pas de bond réflexe quand on est touché (les esquives sur lecture de zone restent) |
| `skill_range` | un sort n'est choisi que si la cible est à sa portée (zone / trait : portée ; cône, cercle : rayon ; élan : portée + rayon), sinon l'auto-attaque |
| `contact` | une unité de mêlée qui attend son coup colle sa cible au lieu de tourner à 4,5 m |
| `range` 2 | portée de la classe gardée, sauf auto-attaque de mêlée (guitares) : 3,2 m |
| `stick` (coupé) | « le plus proche, gardé tant qu'il est à portée » : **mesuré pire** (43-50 %) que le ciblage actuel ; laissé coupé |
| `read`, `cancel` | esquive de la difficulté gardée : la baisser (lecture 0,3, annulation 0,1) **fait perdre** (18 % en 3v3) |

### 3.2 Banc « qualité de jeu » (`--mode=bench`)
Chaque composition tirée au sort est jouée **en miroir** (mêmes classes des deux côtés) : IA v2 d'un côté, IA v1 de l'autre,
côtés alternés à chaque combat (le camp A gagne 40-60 % par lui-même selon la taille). Critère : sur 40 combats, ≥ 66 %
de victoires = gain sûr (intervalle à 95 % d'un pile-ou-face : 34-66 %) ; 100 combats pour la mesure finale (≥ 60 %).

### 3.3 Résultats (40 combats par case ; victoires de la v2 contre la v1)
| Variante | 3v3 | 5v5 | 8v8 |
|---|---|---|---|
| soutien d'équipe seul (`team`, `zones`) | 88 % | 93 % | — |
| sans repli seul | 63 % | 63 % | — |
| sorts à portée seuls | 65 % | 48 % | — |
| mêlée au contact seule | 53 % | 53 % | — |
| ciblage « plus proche gardé » seul | 43 % | 50 % | — |
| portée de l'arme partout (`range` 1) seule | 40 % | 43 % | — |
| tout, esquives baissées (lecture 0,3) | 18 % | 55 % | — |
| soutien + sans repli | 93 % | 98 % | 100 % |
| tout sauf `stick`, `range` 0 | 93 % | 100 % | 100 % |
| **v2 retenue** (tout sauf `stick`, `range` 2, sans réflexe) | **98 %** | **98 %** | **100 %** |
Comportement v2 contre v1 (8v8) : inactif 17 % (v1 22 %), s'éloigne 13 % (16 %), esquives 0,60/s (0,73/s), distance aux
équipiers 5,9 m (6,9 m). **Reste à faire** : l'inactivité (~20 %) vient des esquives croisées ; les assassins (§2.3).

## 4. Durée et échelle de dégâts du profil `autochess`
IA v2 contre v2 (20 combats par case, équipes tirées au sort) :
| dmg_scale | 3v3 | 5v5 | 8v8 | entre 20 et 40 s |
|---|---|---|---|---|
| 0,024 (arena3) | 76,7 s | 78,0 s | 74,5 s | 0 % |
| 0,05 | 56,0 s | 55,3 s | 60,6 s | 0 % |
| 0,08 | 49,5 s | 46,5 s | 43,4 s | 20-40 % |
| 0,12 | 38,2 s | 40,4 s | 38,9 s | 50-60 % |
| **0,20** | **28,6 s** | **30,4 s** | **32,8 s** | **60-80 %**, min 13,5 s |
→ profil `autochess` : **dmg_scale ≈ 0,20**, `heal_mult` 0,175 (celui d'arena3), la « Fureur » de la SPEC à 30 s pour couper la
traîne (p75 34-42 s). La durée ne suit pas l'échelle (× 8 → ÷ 2,6) : une part fixe vient de l'approche et des esquives. Les
corrections de rythme (mana, sorts annoncés seulement, §6) raccourciront encore : refaire la mesure avant de figer.

## 5. Coûts CPU (pour mémoire ; headless, sans rendu, d'autres Godot tournaient sur la machine)
| Unités | IA scriptée : image (médiane / p95) | par unité | Cerveaux (décisions étalées) : image | par décision |
|---|---|---|---|---|
| 6 | 0,67 / 0,98 ms | 0,11 ms | 12,0 ms | 5,36 ms (réseau 5,23) |
| 10 | 1,04 / 1,50 ms | 0,10 ms | 19,1 ms | 5,34 ms |
| 16 | 1,62 / 2,20 ms | 0,10 ms | 32,4 ms | 5,41 ms |
| 24 | 2,44 / 3,32 ms | 0,10 ms | 48,6 ms | 5,33 ms |
Création : 18-48 ms par unité (chargement des modèles, à précharger pendant la préparation). Trois combats invisibles de 20
unités scriptées ≈ 6 ms par image : jouables en vrai (SPEC §4.3), sans rendu ni effets. Cerveaux : réseau 565 → 256 → 256 en
GDScript, 97 % du coût, 20 décisions/s → ~107 ms de calcul par seconde et par cerveau ; tous synchronisés : pics de 35-140 ms.
En combat, les cerveaux battaient le script Difficile **100 % du temps** (3v3 et 5v5, niveaux 10 et 30 ; 0 % d'inactivité, 2,2
actions/s contre 0,9) : c'est la « force qui oblitère le plateau » que le joueur ne veut pas.

## 6. Recommandations pour les lots
- **AC-E** (`ai/autochess_unit.gd`) : partir de `tools/ac2_unit.gd` tel quel (sous-classe, aucun fichier partagé touché) ;
  camps par `ffa_id` (pas les camps natifs : bug de cible figée de `Monster`) ; `Duel.active` n'est pas nécessaire si le profil
  `autochess` et `Modes.is_pvp()` (à étendre) donnent les règles JcJ et que `_team_mode()` est surchargé à vrai.
  Puis, mesuré à chaque fois avec le banc : **rôles** lus dans `data/autochess_units.json` — *tank* (rangée avant, reste au
  contact du plus proche), *mêlée*, *distance* (garde `attack_range` × 0,75), *soutien* (soigne le plus bas à portée, reste
  derrière un équipier), *assassin* (vise l'unité arrière la plus basse, saut au début du combat ; les 17 classes à
  dash / blink en sont les candidates) ; **mana** (SPEC §3.3) : remplacer la recharge `_skill_ready` par la jauge dans
  `_start_attack` (même filtre que `skill_range`) ; **télégraphes pour les sorts seulement** (moins d'esquives croisées, plus
  lisible) ; reciblage quand la cible meurt ou reste hors de portée 1,5 s ; kit du capitaine scripté sans renforts gaspillés.
- **AC-C** (simulateur) : se calibrer sur l'IA v2, pas sur `ClassRival` (98 % d'écart de victoires entre les deux).
- **AC-F** : bornes du plateau = murs `PHYS_WORLD` (aucune sortie mesurée, élans et téléportations compris).
- **AC-H** : multiplicateurs d'étoile appliqués après `use_sheet` (× PV, × attaque) suffisent (§2.5).
- **AC-J** : garder le banc comme test de non-régression de l'IA (v-nouvelle contre v-précédente ≥ 60 % sur 100 combats).
- **SPEC à revoir** : §4.2 (capitaine cerveau → capitaine scripté), §3.3 durée (0,20), mention « 24 classes à distance au
  contact » à ne pas reprendre (faux, voir §2.2).

## 7. Relancer
`APPDATA` détourné conseillé (aucun profil touché) ; depuis `game/` :
```
Godot --headless --fixed-fps 60 --path . res://tools/ac2_probe.tscn -- --mode=kits
Godot ... -- --mode=cpu --units=6,10,16,24 [--pilot=brain]
Godot ... -- --mode=fights --sizes=3,5,8 --reps=30 [--ai=v2] [--scale=0.2] [--level=30] [--camps=native]
Godot ... -- --mode=bench --sizes=3,5,8 --reps=40 [--v2=team:1,retreat:0,…]   # IA v2 contre IA v1, miroir
Godot ... -- --mode=classes --reps=3 [--ai=v2]
Godot ... -- --mode=stars --reps=2
```
Options : `--diff=0..3`, `--batch=16` (plateaux simultanés), `--limit=180`, `--team=warrior,hunter` (mêmes classes des deux
côtés), `--seed=1` (mêmes tirages). Lignes `[ac2] combat …` (une par combat), `[ac2] === …` (synthèse), `IA v2 gagne …`.
Durée réelle : ~5 s par combat 3v3 sur un cœur, 8v8 ~4 fois plus.
