# Équipe Équilibrage — raffinement (tour 3, jeu 0.1.130)

Lu : `00_BRIEF.md`, `SYNTHESE_v1.md`, **`REPONSES_JOUEUR_1.md` (fait foi)**, notre `concertation_2.md`.
Vérifié dans le code : `combat/pvp_caps.gd`, `combat/combatant.gd:take_damage` (l. 311),
`player/player.gd:recalc_stats` (l. 283-305), `core/duel.gd`, `ml/ml_arena.gd:429`,
`core/fortune.gd`, `core/run.gd:finish`, `core/profile.gd:expertise_need`, `ui/gear_shop_page.gd:price`.
**Deux mesures** faites (arène d'IA, cerveau Hardcore des deux côtés, Guerrier contre Magicien, 4 manches).

## 1. Les deux modes de duel (réponses 8 et 10)

### 1.1 Ce que fait le code aujourd'hui (un seul mode, « équipé »)

| Élément | Code | Valeur |
|---|---|---|
| Niveau du duel | `Duel.gear_level()` | pièce portée la plus haute, **10 au moins** (le niveau 1 est impossible) |
| Inscription | `Duel.requirements()` | preset complet, points de maîtrise posés, certificats posés, **arme + 5 pièces**, tenue |
| Échelle des dégâts | `PvpCaps.damage_mult` | 0,012 × √(PV cible × PV attaquant) / √(puissance × puissance) : en miroir, un coup de multiplicateur 1 retire **1,2 % des PV avant défense**, quel que soit le niveau |
| Défense | `PvpCaps.taken` | défenses égales → **50 %** subis (plancher 40 %) ; les DoT ignorent la défense |
| Plafond par coup | `Combatant.PVP_HIT_CAP` | **20 % des PV max**, appliqué coup par coup (pas de fenêtre) |
| Bonus en % | `player.gd:292-305` | `dmg_mult`, `crit`, `crit_dmg` **ne passent pas par la normalisation** (seule `atk`/`matk` est ramenée) : ils multiplient directement la vitesse de la manche |
| Plafonds de stats | `PvpCaps.CAPS` | dégâts +200 %, crit 50 %, dégâts critiques ×2,5, vol de vie 20 %… |
| Soins, acharnement, auto-attaque | `PvpCaps` | ×0,35 ; dégâts ×2 toutes les 20 s après 30 s ; ×0,7 sans contrôle |

### 1.2 Base de niveau 1 (données `levels.json`, `game_data.gd`, mesuré dans l'arène)

| Niveau | PV de base (`player_max_hp`) | Attaque de base (`45 × 1,1^(n-1)`) | Guerrier (PV / att. / déf.) | Magicien (PV / att. mag. / déf.) |
|---|---|---|---|---|
| 1 | 502 | 45 | 664 / 53 / 15 | 423 / 60 / 7 |
| 10 | 1 132 | 106 | 1 519 / 130 / 40 | 959 / 148 / 26 |

Grâce à la normalisation, **le niveau 1 marche** : en miroir, un coup de multiplicateur 1 retire
~0,6 % des PV (1,2 % × 50 %) à tout niveau. Seul défaut au niveau 1 : les dégâts sont arrondis à
l'entier (`maxf(1, round(...))`) ; un coup de 3 PV a ±17 % d'arrondi et un petit DoT vaut au moins
1 PV par tic. Négligeable avec l'échelle du mode A (×2,5 → ~8 PV par point de multiplicateur).

### 1.3 Mesures (arène d'IA, `--scenario=duel --brain=cerveau_hardcore --episodes=4 --hero=warrior --foe=magician`)

| Mesure | Règles | Durée moyenne | Résultat | Lecture |
|---|---|---|---|---|
| `--level=1` | `PvpCaps` actives (niveau ≠ 10), aucune pièce, aucun bonus = **mode A avec l'échelle actuelle** | **105 s** (97-111) | 1 victoire du Guerrier sur 4 ; PV soignés jusqu'à 156 % subis | trop long ; la manche ne finit que par l'acharnement (×2^3,75 ≈ ×13 à 105 s) |
| `--level=10` | conditions d'entraînement des cerveaux (`ml_arena.gd:429` : `Duel.active` faux) | **19 s** (16-23) | 0 / 4 pour le Guerrier | trop court ; plus gros coup calculé : Magicien 148 × 3,58 × 1,5 × 0,79 ≈ **41 % des PV** du Guerrier |

Modèle tiré de la 1re mesure : dégâts nets (soins déduits) ≈ 1 / 389 des PV par seconde avant
l'acharnement. Pour finir une manche en T secondes, il faut une échelle ×k :
**T = 60 s → k ≈ 4,7 ; T = 75 s → k ≈ 2,8 ; T = 90 s → k ≈ 1,7**. On vise le milieu (65-75 s) →
**k = 2,5**, soit `dmg_scale` **0,030** pour le mode A. Cohérent avec le mode B : un build opti au
plafond frappe ~×2,5 à ×3 plus fort qu'un héros nu (dégâts × critiques), et le mode B tient 53-88 s
avec 0,012 (CHANGELOG 0.1.118). **Une échelle par mode compense exactement l'écart d'équipement.**

### 1.4 Mode A « À l'arme » (Ligue, Gantelet, Panthéon, Duel libre au choix)

| Champ | Valeur | Pourquoi |
|---|---|---|
| Niveau | **choisi, 1 à 100, identique des deux côtés** (défaut 10) ; Ligue et Panthéon : 10 | réponse 10 ; la normalisation rend le niveau neutre |
| Pièces | **aucune** ; l'arme est la **forme d'attaque de la classe** (type et variante choisie parmi les 2), sans aucune stat, ni forge, ni gemme | « juste avec une arme » |
| Méta | **0** : ni talents, ni certificats, ni archive, ni aura, ni arme secondaire | « l'équipement ne compte pas du tout » |
| Sorts | preset de 12 sorts au rang 1 (chaînes comprises) ; aucune carte | seul le jeu compte |
| Inscription | preset complet + variante d'arme (rien d'autre) | `Duel.requirements` à deux lignes |
| `dmg_scale` | **0,030** (×2,5) | 1.3 |
| Plafond par coup | **15 %** | 1.6 |
| Rafale | **35 % des PV sur 2 s** | 1.6 |
| Soins | ×0,35 | inchangé |
| Acharnement | 30 s, ×2 / 20 s | inchangé ; doit rester un filet, pas le moteur |
| Auto-attaque | ×0,7 sans contrôle | inchangé |
| Contrôles, combos d'états | durée ×0,7, limite commune ; combos ×1,5 | concertation (E3) |
| **Cible** | manche **45-90 s**, médiane 65 s, à **tous** les niveaux (1, 10, 50, 90) | réponse 10 |

### 1.5 Mode B « Équipé » (Duel libre, duels de la Tour)

| Champ | Valeur | Pourquoi |
|---|---|---|
| Niveau | celui de l'équipement (`gear_level`, 10 au moins) | inchangé |
| Pièces, forge, gemmes, arme secondaire, talents, certificats | **oui** (réponse 8) | « armes, certificats, points de maîtrise » |
| Avantage d'équipement | **par le rapport √(puissance × PV)** (déjà le cas) **et** par les bonus en % ramenés : bonus effectif = 1 + **0,5** × (bonus − 1) pour `dmg_mult`, `dot_bonus`, `heal_power` | aujourd'hui les % échappent à la normalisation (1.1) |
| Plafonds | dégâts **+100 %** (au lieu de +200), dégâts critiques **×2** (au lieu de ×2,5), crit 50 %, autres = | facteur de rafale max ≈ 1,5 × 1,5 = **×2,25** au lieu de ×5,25 |
| `dmg_scale` | 0,012 (à remesurer après les plafonds : peut monter à 0,015) | 53-88 s en 0.1.118 |
| Plafond par coup / rafale | **15 % / 35 % sur 2 s** | comme A |
| **Cible** | manche **30-75 s** ; un héros mieux équipé gagne plus souvent, jamais en moins de 15 s | réponse 10 |

Duels de la Tour (`tour_duel`) : mode B, poids des % 0,75, PV du duelliste ×0,6, acharnement à 45 s
(concertation 3.3, inchangé).

### 1.6 Garde-fou « pas de one-shot » (les deux modes, et les Arènes)

Aujourd'hui `take_damage` borne **chaque coup** à 20 % (`PVP_HIT_CAP`), après critique, combo
d'états et acharnement. Mais un sort à 3 coups + 2 enchaînements = 5-6 coups en ~2 s :
théoriquement 100 % en une rotation au plafond.

Règle proposée (dans `take_damage`, branche `pvp`, après tous les multiplicateurs) :
1. **par coup** : au plus **15 %** des PV max (DoT compris : un tic aussi) ;
2. **fenêtre de 2 s** : la somme des dégâts subis (tous attaquants, DoT et Épines compris) ne
   dépasse pas **35 %** des PV max ; au-delà, le reste du coup est compté **×0,25** (on sent toujours
   ses coups, on ne vide pas une barre) ;
3. **conséquence garantie** : tuer un héros plein demande **au moins 3 fenêtres**, soit **≥ 5 s**
   même au pire moment de l'acharnement ; en début de manche (sans acharnement), le plus gros coup
   du jeu (Souffle destructeur, 3,58) au critique (×1,5 sans bonus) avec combo ×1,5 retire
   3,58 × 1,5 × 1,5 × 0,6 % × 2,5 ≈ **12 %** en mode A (mode B au plafond : ~3,58 × 2 × 1,5 × 1,5 ×
   0,6 % ≈ 10 %) : le plafond ne mord qu'avec l'acharnement ou en rafale, il ne nivelle pas.
4. **Affichage** : le chiffre affiché est le dégât réel ; un coup réduit par la fenêtre s'affiche en
   gris (lisible : « il a encaissé le max »).

Coût : S (`combatant.gd`, une file des dégâts récents par héros). Aucune observation d'IA ajoutée.

### 1.7 Durée garantie à tout niveau (contrôle)

- **Essai** (après le réglage) : `--scenario=duel --brain=cerveau_hardcore --episodes=4` aux niveaux
  **1, 10, 50, 90** en mode A, et 25 / 60 / 90 avec `--hero-build/--foe-build` opti en mode B,
  3 paires de classes (Guerrier-Magicien, Clerc-Voleur, Chasseur-Chevalier). Cible : **moyenne dans
  la fenêtre et moins de 1 manche sur 4 terminée après 100 s**.
- Il faut à l'arène un drapeau **`--rules=duel_a` / `duel_b`** (aujourd'hui `Duel.active` ne s'allume
  que si le niveau ≠ 10 ou avec un build, `ml_arena.gd:429` : le niveau 10 en mode A est impossible à
  mesurer). Coût S, sans observation nouvelle.

### 1.8 Panthéon : compatible avec le mode A ?

- **Oui, c'est le même cadre** : niveau 10, aucune pièce, aucun bonus, kit de la classe — c'est la
  fiche d'entraînement. La seule différence est la règle (`PvpCaps` contre règles brutes).
- Les règles brutes sont **exclues** : 19 s par manche et des coups à 40-50 % des PV (1.3) = le
  « one-shot pour rien » refusé (réponse 10).
- **Le cerveau sous les règles du mode A** : la 1re mesure montre qu'il finit ses manches et joue
  normalement (pas de blocage), mais son taux de victoire n'est pas garanti. Validation : cerveau
  Hardcore contre le scripté Hardcore, en mode A niveau 10 : taux d'entraînement ±10 %.
  **Si l'écart dépasse** : une étape d'entraînement de plus (`--rules=duel_a`, niveau 10, reprise du
  cerveau existant, une nuit), **sans nouvelle observation** : coût S (drapeau) + temps machine.
- Récompenses (réponse 9 : panoplie, coffres d'apparence, titre, coffres d'auras) : **aucune n'est
  utilisable au Panthéon ni en Ligue** (mode A) ; la panoplie sert en mode B, Tour, Donjons, Survie
  (achat). Pas de boucle « je bats le cerveau avec sa panoplie ».

## 2. Réponse 4 : le journal de run mesure les deux styles

Le joueur alterne « coffres » et « farm » : on ne règle E5 (époques) et l'or que sur des **runs
classées par style**. Le journal (E6a, une ligne par map dans `user://journal.jsonl`, mêmes
compteurs que les succès) enregistre :

| Groupe | Mesures (par map) |
|---|---|
| Style | coffres ouverts / coffres posés sur la carte (par qualité), objets cassés, **temps en combat** (monstre touché < 3 s) / temps hors combat, distance parcourue, % de la carte vu |
| Or | or gagné **par source** (monstres, élites, objets cassés, sites, autel), or dépensé **par usage** (coffres, enclume, marchand), or restant au boss ; clés gagnées / utilisées |
| Puissance au boss | niveau, cartes, trophées, pièces de coffre (rareté, niveau), meilleur palier d'enclume, **DPS sur les 10 premières secondes du boss** |
| Pression | dégâts subis par minute (monstres normaux, élites, boss séparés), part des PV perdue par coup max, résurrections, cause de la mort |
| Résistance des monstres | **temps pour tuer** un normal, une élite, le boss ; coups pour tuer un normal |
| Contexte | époque, map, classe, variante d'arme, version, durée de la map, victoire / mort / extraction, aide auto active (section 4) |

**Classement du style** : indice = part des coffres ouverts − part du temps en combat (normalisés) :
`coffres` > +0,2, `farm` < −0,2, sinon `mixte`. Pas de choix du joueur à faire.

**Règles de décision** (au moins 5 maps par style et par époque) :
- E5 « **frappent trop** » si les dégâts subis / min à l'époque II dépassent **×1,5** ceux de
  l'époque I **dans les deux styles** ; « **tiennent trop** » si le temps pour tuer un normal dépasse
  **×1,4**. On ne règle que l'axe qui sort.
- Économie : les deux styles doivent arriver au boss **à puissance voisine** : écart du DPS de boss
  **≤ 25 %** et du temps de boss **≤ 30 %**. Si le style `coffres` est devant : or des objets
  cassés −15 % ; si `farm` est devant : prix des coffres −10 % (pas l'inverse : on récompense le
  combat, c'est la pression voulue).
- Garde-fou : un style ne doit jamais rendre une époque **ingagnable** (mort au boss > 60 % des
  essais dans un style et < 30 % dans l'autre → on règle avant toute autre chose).

## 3. Chiffres pour les réponses 12, 7 et 6

### 3.1 Autel de la fortune (réponse 12 : insignes et apparences)

Repères : une run gagnée à l'époque I rapporte ≈ 200-260 insignes (`run.gd:143` :
25 × étape + monstres / 25 + élites × 2 + 60 × époque, estimation à confirmer par le journal) ;
une pièce de l'Armurerie coûte 30 + niveau (commune à épique) ou 80 + 2 × niveau (légendaire).
Chance de franchir l'étage f = (8 − f) / 8 (`fortune.gd`).

| Étage | Gain (remplace le précédent) | Chance d'y arriver | Espérance si on encaisse là |
|---|---|---|---|
| 1 | or × 1 (inchangé) | 7/8 | — |
| 2 | or × 1,5 + 2 clés (inchangé) | 6/8 | — |
| 3 | **15 insignes** | 5/8 | 9,4 |
| 4 | **25 insignes** | 4/8 | 12,5 |
| 5 | **40 insignes** | 3/8 | 15 |
| 6 | **60 insignes + coffre d'apparence commun** | 2/8 | 15 + 1/4 apparence |
| 7 | **90 insignes + coffre d'apparence rare** | 1/8 | 11 + 1/8 apparence rare |
| 8 (sommet) | **apparence dorée** (inchangé) + **120 insignes** | 1/8 (après l'étage 7) | — |

- Espérance presque **plate** (12-15 insignes) : encaisser tôt ou risquer est un goût, pas un
  calcul. 3 autels par run ≈ **40 insignes ≈ 15 %** de la run : un bonus, pas une source principale.
- Insignes × (1 + 0,25 × (époque − 1)), comme les prix qui montent avec le niveau.
- Apparence déjà toute collectée : insignes **×2** à la place (comme le sommet donne aujourd'hui un
  coffre en plus).
- Les coffres « forge », « joaillerie », « équipement » et « panoplie » **sortent** de l'autel
  (`Fortune.PRIZES`). Coût S.

### 3.2 Défis à maîtrise renforcée (réponse 7)

Repères : maîtrise 20 = Σ(120 + 80 n) pour n = 1 à 19 = **17 480 points** (`profile.gd:712`) ;
une run gagnée à l'époque I ≈ 1 500-2 000 points (`run.gd:136`, estimation) → **~9 runs par classe,
~540 runs pour les 60 classes**. Le but « toutes les classes au max » (réponse 11) doit rester long
mais pas absurde : viser **~300 runs**.

| Source | Gain de maîtrise | Fréquence |
|---|---|---|
| Défi du jour (classe imposée parmi 3) | **×2** pour la classe jouée ; ×2,5 si les 2 modificateurs sont gardés | 1 par jour |
| **Défi de maîtrise** (nouveau) : une classe sous la maîtrise 20, une contrainte de son identité (« finir la map sans arme secondaire », « 3 élites tuées par des sorts ») | **×3** sur la run, 1 fois par classe et par palier de 5 (5, 10, 15, 20) | 4 par classe, 240 en tout |
| Rattrapage par famille | **×1,5** tant que la classe est sous la meilleure maîtrise de sa famille − 5 | permanent |
| Duel (Ligue) | 40 + 20 × rang (concertation, inchangé) | — |

Avec Défis de maîtrise + rattrapage, une classe passe de ~9 runs à **~5** : ~300 runs pour tout.
Les modificateurs des Défis sont ceux de notre liste unique (concertation 1.2) ; un Défi de maîtrise
n'ajoute **aucune puissance**, seulement des points.

### 3.3 Alliés IA (réponse 6 : jouer hors ligne)

**Arènes 2v2 / 3v3** (profil `arene`, base = **mode A**, l'équipement ne compte pas) :

| Champ | 2v2 | 3v3 |
|---|---|---|
| `dmg_scale` (mode A = 0,030) | **0,022** | **0,018** |
| Pris pour cible (frappé par 2+ adversaires en 2 s) | ×0,8 | ×0,75 |
| Plafond par coup / rafale | 15 % / **35 % sur 2 s, tous attaquants** (le focus reste fort sans être instantané) | idem |
| Soins | **×0,5** (le soigneur a un rôle) ; soin sur un allié **×0,8** de plus | idem |
| Acharnement | 45 s | 60 s |
| Cible | manche 60-120 s | 75-150 s |

- Alliés et adversaires IA = **IA scriptée** (`ClassRival` sur la fiche d'un héros, comme le Duel) ;
  le cerveau ne voit qu'un adversaire et aucun allié (obs figées) : en arène il ne peut jouer qu'un
  « duelliste » qui vise sa cible, pas un coéquipier. **Même difficulté pour les alliés et les
  adversaires** : la variable, c'est toi.
- Mesure (journal) : part des dégâts faits par les alliés ; cible **30-45 %** de l'équipe en 2v2.
  Au-delà, l'arène se gagne sans jouer.

**JcE avec alliés** (seulement si Modes le retient ; nous conseillons **Donjons et Tour, pas la
Survie** : les cartes et coffres de la Survie sont pensés pour un seul héros) :
- PV des monstres × (1 + **0,5** × nombre d'alliés), dégâts inchangés, les monstres visent le héros le
  plus proche (aggro partagée, la pression sur toi baisse un peu : voulu pour l'aide hors ligne) ;
- **gains inchangés** (pas de part, pas de bonus) ; records et étoiles notés « avec alliés »
  (succès « en solo » à part) ;
- allié = fiche opti de sa classe au niveau du donjon (`Duel.opti_build`), pas de cartes.

## 4. Tampon d'entrées et mode auto (pilote Builds) : conséquences d'équilibrage seulement

Si le **mode auto devient une aide officielle** (« easy to play ») :
1. **Récompenses JcE** : gains **inchangés** avec l'auto (c'est une aide, pas une triche) **à condition**
   que l'auto ne batte pas le jeu manuel moyen. Le journal note `auto` ; si les runs auto tuent le boss
   **> 20 %** plus vite que les runs manuelles du joueur, l'auto est bridé (pas les gains).
2. **Succès d'adresse, Épreuves de maîtrise, records de combo** : **manuel seulement** (sinon ils ne
   mesurent rien).
3. **JcJ** : auto **interdit en Ligue et au Panthéon** (le défi est ton jeu) ; permis en Duel libre et en
   Arène pour les **alliés** (ils sont l'auto). Si l'auto rejoint la Ligue un jour : échelle à part.
4. **Tampon d'entrées** : il rend les rotations plus régulières (même dégâts, moins de trous) →
   un joueur moyen frappe plus en JcJ : la durée de manche peut baisser de 10-20 %. Le garde-fou de
   rafale (1.6) couvre le risque de one-shot ; on remesure la durée après son arrivée.
5. Le cerveau n'utilise pas le tampon : rien à réentraîner.

## 5. Profils mis à jour

| Champ | `survie` | `tour` | `donjon` | **`duel_a`** | **`duel_b`** | `tour_duel` | `pantheon` | `gantelet` | `arene` | `entrainement` |
|---|---|---|---|---|---|---|---|---|---|---|
| Utilisé par | Survie, Défis | Tour | Donjons | Ligue, Duel libre (A) | Duel libre (B) | duels de la Tour | Panthéon | Gantelet | Arènes | entraînement |
| Niveau | run | étage | donjon | **choisi 1-100** (Ligue 10) | équipement | étage | **10** | 10 | 10 | choisi |
| Équipement | run | sync | sync | **aucun (arme = forme)** | complet | sync | aucun | aucun | aucun | choisi |
| Méta (talents, certificats…) | 1 (plafond ×1,6-1,8) | 1 | 1 | **0** | 1 | 1 | 0 | 0 | 0 | 1 |
| `dmg_scale` | — | — | — | **0,030** | 0,012 | 0,012 | 0,030 | 0,030 | 0,022 / 0,018 | — |
| Poids des bonus en % | — | — | — | — | **0,5** | 0,75 | — | — | — | — |
| Plafond coup / rafale 2 s | — | — | — | **15 % / 35 %** | 15 % / 35 % | 15 % / 35 % | 15 % / 35 % | 15 % / 35 % | 15 % / 35 % | — |
| Soins | 1 | 1 | 1 | 0,35 | 0,35 | 0,35 | 0,35 | 0,35 | 0,5 | 1 |
| Acharnement | — | — | — | 30 s | 30 s | 45 s | 30 s | 40 s | 45 / 60 s | — |
| Combos d'états | ×2 | ×2 | ×2 | ×1,5 | ×1,5 | ×1,5 | ×1,5 | ×1,5 | ×1,5 | = |
| Durée visée | map ~12 min | étage 30-60 s | 8-12 min | **45-90 s** | **30-75 s** | 20-45 s | 45-90 s | 60-120 s | 60-150 s | — |

Changements par rapport à la concertation : `duel` scindé en `duel_a` / `duel_b` ; `pantheon` = `duel_a`
au niveau 10 (plus les règles brutes) ; `gantelet` et `arene` passent sur le mode A ; plafond par coup
20 % → 15 % + fenêtre de rafale partout en JcJ. Les autres colonnes (Survie, Tour, Donjon) ne changent pas.

## 6. Liste finale des propositions (coût, ordre)

| Ordre | # | Proposition | Coût | Touche |
|---|---|---|---|---|
| 1 | E6a | Journal de run par map, classement du style (section 2) | S | `run.gd`, `run_director.gd`, `Profile.records` |
| 1 | E9 | Ménage (commentaires faux de `pvp_caps.gd`, `ZONE_MAX_LEVEL`…) | S | — |
| 2 | E1+M0 (a) | Socle `mode_rules.gd`, valeurs actuelles, aucun changement visible | M | avec Modes |
| 3 | **E11** | **Garde-fou anti one-shot** : 15 % par coup + 35 % sur 2 s | S | `combatant.gd:take_damage` |
| 3 | **E12** | **Mode A « À l'arme »** : niveau choisi dès 1, aucune pièce ni méta, `dmg_scale` 0,030, inscription allégée | S-M | `duel.gd`, `player.gd:recalc_stats`, page Duel (Interface) |
| 3 | **E13** | **Mode B** : bonus en % ×0,5, plafonds dégâts +100 % et critiques ×2 | S | `pvp_caps.gd`, `player.gd` |
| 4 | **E14** | Drapeau d'arène `--rules=duel_a/duel_b` + essais 1.7 (4 niveaux × 3 paires) | S | `ml_arena.gd` (aucune observation) |
| 4 | E7 | Garde-fous de build (projectiles, Élan meurtrier, trophées 5 s…) | S | avec Builds |
| 5 | E3 | Reste du JcJ : contrôles ×0,7, combos ×1,5, `tour_duel` | S | — |
| 5 | **E15** | Panthéon = `duel_a` niveau 10 ; validation du cerveau ±10 %, sinon une nuit d'entraînement | S + machine | `ml_duel_pilot.gd` |
| 6 | **E16** | Autel : insignes et apparences (3.1) | S | `fortune.gd` |
| 6 | **E17** | Défis de maîtrise ×3, Défi du jour ×2, rattrapage ×1,5 (3.2) | S (chiffres) | avec Modes, Progression |
| 7 | E5, E8 | Époques et économie **d'après le journal** (règles de 2), cristaux, forge | S | après ≥ 5 maps par style |
| 8 | E4, E10 | Donjons (profil, plans), liste des modificateurs | S | avec Modes |
| 9 | **E18** | Profil `arene` et alliés IA (3.3), JcE avec alliés si retenu | S (chiffres) | avec Modes (M6, L) |
| — | E6b | Banc headless 5 classes × 4 époques | M | session locale |

Ordre : **mesurer → ranger → protéger le JcJ (E11-E14) → corriger → Panthéon → récompenses → régler
au journal → contenus**.

## Résumé (6 lignes)

1. Duel en deux modes : **A « À l'arme »** (niveau 1 à 100, aucune pièce ni bonus, échelle 0,030) pour Ligue, Gantelet, Panthéon ; **B « Équipé »** (tout compte, bonus en % ×0,5, plafonds +100 % / ×2) pour Duel libre et Tour.
2. Mesuré : sans équipement, les règles actuelles font **105 s** au niveau 1 (fin par l'acharnement seul) → échelle ×2,5 ; les règles d'entraînement des cerveaux font **19 s** avec des coups à ~40-50 % des PV → abandonnées.
3. **Pas de one-shot** : 15 % des PV par coup et 35 % sur 2 s, tout compris (critiques, combos, DoT, acharnement, plusieurs attaquants) : tuer prend ≥ 5 s au pire, sans niveler les coups normaux.
4. **Panthéon = mode A au niveau 10** (même cadre que l'entraînement, règles du duel) ; à valider ±10 % ; sinon une nuit d'entraînement sans nouvelle observation, grâce à un drapeau `--rules` dans l'arène.
5. Journal par map avec **style classé** (coffres / farm / mixte) ; E5 et l'économie se règlent sur des écarts chiffrés entre styles, pas au ressenti.
6. Autel : insignes 15 → 120 et apparences (espérance plate ~12-15) ; Défis de maîtrise ×3 (~300 runs pour tout) ; Arènes sur le mode A avec IA scriptée, alliés et adversaires de même force ; auto : gains gardés en JcE, interdit en Ligue et au Panthéon.
