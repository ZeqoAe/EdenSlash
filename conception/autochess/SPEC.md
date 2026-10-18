# L'Échiquier — spécification du mode « autochess » (AC1, 16/10/2026)

Demande du joueur (mot à mot) : « un mode comme TFT, où tu pourrais placer tes héros sur le board et ils se battent en combat
auto ; faudrait réfléchir à comment se passe le déroulé de la game, l'économie de ce mode, les bonus à mettre en place entre
chaque manche, etc. … faire un autochess avec nos IA cerveaux ; je suis sur ça. » Une équipe dédiée code ce mode.

**Décision du joueur (16/10, après la 1re version)** : « enlève les idées de cerveau si c'est coûteux, mieux vaut 0 qu'un seul
cerveau qui va oblitérer le board, mais il faut que nos IA scriptées jouent très bien ». **Aucun cerveau neuronal dans ce
mode** : toutes les unités sont pilotées par l'IA scriptée (§4.1), dont la qualité se mesure (§4.2).

Ce document est prêt à coder : chaque point ouvert est tranché (**DÉCISION**, justification courte). Les chiffres marqués
« (réglage) » sont des valeurs de départ que le lot de mesure AC-J recale. Annexes : `ANNEXE_A_UNITES.md` (les 60 unités :
coût, traits, portée, sort signature, mana), `ANNEXE_B_OBJETS.md` (9 composants, 36 objets, butin). Sonde technique de la
session sœur : `R_AC2.md` (prime sur §4.3 et §8 là où elle mesure autre chose).

Règles communes du jeu respectées : **mode scellé** (`Modes.sealed()` : ni équipement, ni talents, ni insignes, ni maîtrise),
récompenses = apparences, titres, coffres d'apparence ; une idée par écran ; textes français courts ; aucun pourcentage dans le
texte permanent (infobulle) ; aucune mention du jeu d'origine ; manette partout (UiNav) ; pas de réseau (toi + 7 IA).

---

## 1. Pitch et fantasme

**« Recrute des héros, place-les, regarde-les se battre comme de vrais joueurs. »** Huit stratèges, un seul gagnant.

| Ce que les autres modes donnent | Ce que l'Échiquier donne, lui seul |
|---|---|
| Survie, Survivant, Tour, Donjons : **toi**, une classe, tes mains | **Les 60 classes à la fois** : composer, pas exécuter. On découvre en 5 minutes des classes jamais jouées |
| Duel, Arènes, Battle royale : réflexes | **Décisions** : or, risque, timing ; un mode qui se joue détendu, manette en main, à la pause café |
| Combat d'un héros contre un autre | **Des escouades de 10 contre 10** qui esquivent, enchaînent et se soignent avec nos vrais sorts, nos vraies armes et nos vrais boss (48) |

Différence avec un autochess classique : les pièces ne sont pas des pions qui tapent sur place. Chaque unité est un héros du
jeu (corps, tenue, arme, auto-attaque, sort signature) qui **joue bien** : les soigneurs restent derrière et soignent le
plus bas, les tireurs gardent leur portée, les assassins plongent sur l'arrière-ligne, les tanks protègent, tout le monde
esquive les zones rouges. Les manches « gardien » opposent ton escouade à un boss de la bibliothèque avec ses mécaniques.

---

## 2. Déroulé d'une partie

### 2.1 Forme
- **8 stratèges** : toi + 7 IA (`core/autochess_ai.gd`, §4.4). Chacun a **100 PV de joueur**. À 0 : éliminé, place fixée.
- **Durée cible** : 25 à 30 min pour aller au bout ; 12 à 18 min si on sort tôt. Une partie s'arrête quand il ne reste qu'un.
- **Étapes** (« 3-2 » = étape 3, manche 2). L'étape 1 apprend ; à partir de l'étape 2, chaque étape a 7 manches :

| Manche | Étape 1 | Étapes 2 et suivantes |
|---|---|---|
| x-1 | **Ouverture** : choisis 1 héros de coût 1 parmi 4 (tous reçoivent le leur) | JcJ (atout en 2-1) |
| x-2 | Monstres (2 sbires) | JcJ (atout en 3-2 et 4-2) |
| x-3 | Monstres (3 sbires) | JcJ |
| x-4 | Monstres (1 élite + 2 sbires ; 2 élites avant ACX-4) | **Choix partagé** (pas de combat) |
| x-5 | — | JcJ |
| x-6 | — | JcJ |
| x-7 | — | **Gardien** : un boss de la bibliothèque |

- **DÉCISION atouts en 2-1 / 3-2 / 4-2** (le brief proposait 2-4 / 3-2 / 4-6) : un atout à 4-6 arrive quand la moitié des
  stratèges est déjà sortie dans une partie de 25 min ; plus tôt, il oriente la partie au lieu de la conclure.

### 2.2 Une manche
| Phase | Durée | Ce qui se passe |
|---|---|---|
| Préparation | 25 s (étape 1 : 15 s ; manche d'atout : +10 s) | boutique, banc, placement, objets ; bouton **Prêt** (Y) qui lance tout de suite (les IA sont prêtes d'office) |
| Combat | 20 à 40 s (cible médiane 25 s) | les unités se battent seules ; **×1 / ×2** (gardé entre les parties) |
| Bilan de manche | 3 s | « Victoire · +6 or » ou « Défaite · −7 PV » ; puis or et XP de la manche |

Le jeu est solo : la préparation peut aussi se mettre en pause (menu pause). Durée mesurée sur ≈ 35 manches : ≈ 50 s chacune
(préparation écourtée par « Prêt ») → ≈ 29 min ; ≈ 22 min en ×2.

### 2.3 PV de joueur, élimination, égalités
- Défaite en JcJ : **dégâts = base de l'étape + 1 par unité adverse debout + 1 par étoile au-delà de la première** (★2 = 2,
  ★3 = 3). Base (réglage) : étape 2 : 2 · 3 : 4 · 4 : 6 · 5 : 9 · 6 : 12 · 7 : 15 · 8 et plus : 20.
- Défaite contre monstres ou gardien : base de l'étape + 2 (le gardien compte pour 3 unités debout).
- **Égalité** (les deux équipes debout à 45 s) : les deux perdent, chacun prend les dégâts de ce qui reste en face.
- Deux stratèges éliminés à la même manche : le mieux placé est celui qui avait le plus de PV avant la manche, puis celui
  dont l'équipe valait le plus (somme des coûts × étoiles), puis le tirage.
- Éliminé : on regarde la fin (spectateur, plateau du choix) ou on ouvre le bilan ; ouvrir le bilan arrête la partie
  (la place est déjà fixée).

### 2.4 Appariement
- Chaque manche JcJ : appariement au hasard parmi les vivants **sans retrouver un des 3 derniers adversaires** (2, puis 1
  quand il reste 4 vivants ou moins).
- Nombre impair : un stratège affronte un **fantôme** (copie de l'équipe d'un autre vivant, prise au début de la manche) ; le
  propriétaire du fantôme ne gagne ni ne perd rien.
- Les 4 combats de la manche sont de **vrais combats**, joués en même temps (§4.3) ; le joueur regarde le sien et peut passer
  sur un autre.

### 2.5 Sauvegarde et reprise
**DÉCISION : une partie en cours, sauvegardée au début de chaque préparation** (`user://autochess_save.json` par
`SafeFile.write`, comme toute sauvegarde). Tout l'état est de la donnée (plateaux, bancs, or, PV, boutiques, réserve, graine) :
c'est peu de code et une partie dure 30 min. Quitter en plein combat = reprendre à la préparation de cette manche, **même
boutique, même graine** (pas de relance gratuite par rechargement). « Abandonner » (pause, confirmation `InfoCard.ask`) =
place actuelle des vivants, récompenses de cette place seulement si elle est dans les 4 premières (pas de farm par abandon).

---

## 3. Plateau et unités

### 3.1 Plateau
- **Hexagones**, 7 colonnes × 4 rangées par camp (28 cases), 7 × 8 au total ; case de 2,0 m (pointe en haut) : plateau de
  ≈ 14 × 13 m, posé dans une arène de rayon 15 m.
- **Banc** : 9 cases en ligne devant le plateau. Plateau limité au **niveau du stratège** (1 à 10) + Couronnes.
- Placement libre sur ses 4 rangées pendant la préparation ; l'équipe adverse apparaît en miroir.
- **DÉCISION : les cases ne servent qu'au placement.** En combat, les unités bougent librement (déplacement, esquive et
  saut de `ClassRival`), bornées au plateau. Justification : c'est ce qui donne « des héros qui se battent vraiment » et
  ça réutilise notre IA de combat au lieu d'un moteur de grille.

### 3.2 Unités : les 60 classes
- **Toutes les 60 classes** sont dans la réserve, débloquées ou non sur le compte (mode scellé : la réserve doit être la
  même pour les 8). Chaque unité a **un trait de famille** et **un trait d'arme** (§5.4), un coût de 1 à 5, une portée en
  cases, un sort signature (`ANNEXE_A_UNITES.md`). Répartition : coût 1 : 10, 2 : 15, 3 : 15, 4 : 10, 5 : 10 ; par famille :
  2 / 3 / 3 / 2 / 2 ; les classes vertes en coût 1-2, les ascensions en coût 2-5.
- **Fiche** : celle d'un héros de la classe au niveau 30, nu, arme de sa classe (même fabrique que `Duel.rival_sheet`) ;
  puis × coût et × étoiles. Les différences entre classes (PV du Guerrier, frappe du Magicien) restent.

| | ★1 | ★2 (3 copies) | ★3 (3 ★2) |
|---|---|---|---|
| PV et attaque | × coût (1 / 1,15 / 1,35 / 1,6 / 1,9) | × 1,8 | × 3,24 |
| Sort signature | rang 1 | rang 2 (puissance × 1,5) | rang 3 (× 2,25) **+ enchaînement** : le 2e sort propre de la classe part juste après, sans mana |

- Fusion automatique dès la 3e copie (banc ou plateau, même banc plein) ; la ★2 prend la place de l'exemplaire du plateau.

### 3.3 Combat
- **Portée** : mêlée = 1 case (2 m), lance / faux-fusil = 2, sceptre / guitare / bâton de métal = 3, arc / bâton / canon /
  grimoire = 4. Ciblage, placement, usage des sorts et esquive : §4.1.
- **Mana** : 0 au départ (+ objets) ; +10 par auto-attaque ; +1 par tranche de 1 % des PV max perdus (15 au plus par coup) ;
  mana max = recharge du sort signature × 10 (40 à 140) : **le sort revient au rythme de sa recharge du jeu**. Mana pleine →
  le sort part (annonce rouge au sol seulement pour les sorts, jamais pour les auto-attaques : lisibilité à 20 unités).
- **Durée** : échelle des dégâts du profil `autochess` de `ModeRules` réglée pour une médiane de 25 s (réglage). Un coup
  retire au plus 20 % des PV max (hors gardiens), comme les plafonds JcJ.
- **Mort subite** à 30 s : « Fureur » : dégâts infligés +50 %, puis encore +50 % toutes les 5 s ; soins reçus divisés par
  deux. À 45 s : égalité (§2.3). Vitesse ×2 : `Engine.time_scale` 2 pendant le combat seulement.
- Le joueur ne combat pas : son héros est le **stratège** (§7.1), au bord du plateau.

---

## 4. IA de combat des unités et adversaires

**Aucun cerveau neuronal** (décision du joueur, voir en tête) : ni capitaine, ni `MlDuelPilot`, ni réentraînement. Toutes les
unités des 8 stratèges ont **la même IA scriptée, au même réglage** : la différence entre stratèges vient de leurs décisions
(§4.4), jamais de mains plus habiles.

### 4.1 IA de combat des unités (`ai/autochess_unit.gd`, sous-classe de `ClassRival`)
Socle repris de `ClassRival` : lecture des coups annoncés et esquive (`read`, charges, recharge), rotation autour de la
cible, annulation, visée anticipée, réglages par difficulté (`DIFF`). Réglage commun de toutes les unités :
`AutochessData.UNIT_DIFF` = **Difficile** (réaction 0,16 s, lecture 0,7 ; réglage : le Hardcore esquive presque tout et
allonge les combats).

**Équipes** : `Combatant.ffa_id` = 2 × plateau + camp. Ennemis = l'autre identifiant **du même plateau** ; alliés = le même
identifiant (soins, boucliers, renforts et soutien `_support` ne visent que lui). Les listes d'unités viennent du directeur
(`board.units[camp]`), jamais des groupes `monsters` / `ffa` (4 plateaux tournent en même temps).

**Boucle** : déplacement et esquive à chaque image (socle) ; **décision de cible et de sort 4 fois par seconde**, décalée
d'une unité à l'autre (coût lissé).

| Rôle (`ANNEXE_A`) | Place et distance | Cible | Sort à mana pleine |
|---|---|---|---|
| **Tank** | devant, au contact | l'ennemi qui frappe un allié fragile (s'interpose entre lui et l'allié), sinon le plus proche | provocation / renfort dès le début ; zone si 2 ennemis ou plus dedans |
| **Combattant** | au contact | meilleur score à portée + 1 case ; suit le focus d'équipe | zone sur le plus grand groupe, sinon sur la cible |
| **Assassin** | plonge au début sur l'arrière-ligne (contourne par le côté le moins garni) | l'ennemi d'arrière-ligne le plus fragile, soigneurs et mages d'abord ; ensuite le plus fragile à 4 cases ou moins | sur sa cible ; déplacement pour plonger, ou pour se dégager sous 30 % de PV |
| **Tireur** / **Mage** | garde sa portée (entre portée − 1 et portée) ; **recule** quand une mêlée arrive à 1,5 case et que l'esquive est prête, vers ses alliés, jamais dans un coin | meilleur score à portée ; focus d'équipe | zone où elle touche le plus d'ennemis (2 au moins), sinon sur la cible ; ligne / projectile sur l'alignement le plus garni |
| **Soigneur** | derrière la ligne de ses alliés, à portée du plus avancé ; n'avance jamais au contact | ennemi le plus proche à portée, sans avancer | soin sur l'allié à portée au plus bas % de PV ; attend jusqu'à 2 s qu'un allié passe sous 70 % plutôt que de soigner des PV pleins |
| **Soutien** | comme le soigneur | idem | renfort au début du combat si la mana de départ suffit, sinon quand 3 alliés ou plus sont à portée et engagés |

- **Score de cible** = faiblesse (PV effectifs bas : PV × défense qui compte contre l'attaquant) + menace (dégâts infligés
  sur les 3 dernières secondes, objets portés, coût × étoiles) + achèvement (cible sous 20 % à portée : priorité) − distance
  (en temps de trajet). Poids par rôle dans `AutochessData.AI_WEIGHTS` (réglage).
- **Focus d'équipe** : chaque camp tient une cible désignée (meilleur score atteignable par 2 alliés ou plus), recalculée
  toutes les secondes ; +30 % de score pour qui l'a à portée + 1 case. Jamais plus de 3 unités de mêlée sur la même cible
  (la 4e prend la suivante : pas de bouchon).
- **Reciblage** : cible morte → nouvelle cible à la décision suivante (≤ 0,25 s) ; cible hors d'atteinte 1,5 s → reciblage ;
  sinon on ne change que si le nouveau score dépasse l'ancien de 25 % (pas de danse entre deux cibles).
- **Sorts selon leur type** (`kind`) : `ground` / `spin` / `cone` / `fan` = zone, posée où elle touche le plus d'ennemis ;
  `bolt` / `line` = sur la cible ou l'alignement le plus garni ; `heal` = allié le plus bas ; `buff` = début du combat ou
  mêlée engagée ; `dash` / `blink` = rejoindre une cible hors de portée ou fuir une menace (tireur rattrapé, assassin
  blessé). Une zone peut attendre **1,5 s au plus** une meilleure occasion (2 cibles), puis part sur la cible.
- **Esquive** : lit les zones rouges de **tous** les sorts ennemis et des gardiens (pas les auto-attaques : combats sans fin),
  sort du côté de son camp ou hors de la zone ; charges et recharge du socle.
- **Plateau** : bornes = l'hexagone du plateau moins 0,5 m ; un recul bloqué glisse le long du bord (comme `flee_radius`).
  Aucune unité ne sort, jamais (testé).
- Étourdie, gelée, renversée : rien (socle). Pendant un sort, pas de reciblage.

### 4.2 Mesurer « joue très bien » : banc d'essai
- **Outil** `tools/autochess_ai_bench.tscn` : combats en miroir exact (mêmes unités, étoiles, objets, placement retourné) ;
  camp A = IA complète, camp B = **IA naïve** (`AutochessUnit.naive` : ennemi le plus proche, aucun focus, aucun recul,
  sort dès la mana pleine sur la cible, aucune esquive de zone, soigneur qui avance comme un combattant). 40 compositions
  (8 par archétype : plongeurs, tireurs, mur, sorts, soins) × 2 côtés × 3 graines = 240 combats ; ligne `[ac_bench]` par
  combat.

| Mesure | Cible |
|---|---|
| IA complète contre naïve, en miroir | ≥ 75 % de victoires |
| Chaque comportement seul (activé un à un sur la naïve) | ≥ 55 % contre la naïve, sinon il est retiré ou corrigé |
| Soins gaspillés (sur des PV pleins) | ≤ 15 % |
| Ennemis touchés par sort de zone | ≥ 2 en moyenne |
| Tireurs et mages : temps à portée de leur cible / temps au contact d'une mêlée | ≥ 70 % / ≤ 20 % |
| Unités hors du plateau | 0 |
| Durée médiane d'un miroir / égalités | 20-35 s / < 3 % |

- **Scénarios unitaires** (`test_ac_unit_ai`) : le soigneur soigne l'allié le plus bas ; l'assassin atteint l'arrière-ligne
  en moins de 3 s ; le tireur recule devant une mêlée ; le tank s'interpose devant un plongeur ; l'unité quitte une zone
  rouge avant l'impact ; reciblage ≤ 0,25 s après une mort ; deux plateaux voisins ne se touchent pas.

### 4.3 Combats que le joueur ne regarde pas
- **DÉCISION : tous les combats sont de vrais combats.** Mesure d'AC2 (relayée par la coordination) : ≈ 0,1 ms par unité et
  par image, 160 unités tiennent. Les 4 plateaux d'une manche JcJ (≤ 80 unités ≈ 8 ms) ou les 8 d'une manche de gardien
  (≤ 88 unités) sont posés à 300 m les uns des autres dans le même monde ; seul le plateau regardé est rendu (les autres :
  invisibles, sans effets, sons ni chiffres de dégâts). Un seul moteur de combat : aucun écart entre ce qu'on voit et ce qui
  compte.
- **Simulateur de données** `core/autochess_sim.gd` (aucun nœud, pas de 0,1 s ; mêmes fiches, mana, traits, objets, atouts ;
  rôles simplifiés) : **outil d'équilibrage** (des milliers de parties, §9) et **repli** si une machine ne tient pas l'image
  (plus de 20 ms pendant 2 s : les plateaux cachés encore en cours sont finis par le simulateur). Calibré sur le vrai
  combat : même vainqueur ≥ 75 %, écart moyen des survivants ≤ 1,5 (`test_ac_sim_real`, facteur `sim_factor` par unité).
- Vitesse ×2 : `Engine.time_scale` 2 (à vérifier par AC2 : nombre de pas physiques par seconde réelle, donc coût).

### 4.4 Adversaires IA (stratèges)
Scriptés (`core/autochess_ai.gd`), pas de réseau de neurones : la stratégie se règle et se lit.

| Difficulté | Économie | Composition | Placement / objets | Atouts |
|---|---|---|---|---|
| **Recrue** | dépense tout, relance au hasard | suit ses premières unités, change souvent | rangée avant / arrière selon la portée ; objets au hasard | au hasard |
| **Vétéran** | garde 30 or, achète l'XP aux paliers | vise 2 traits dès l'étape 2 | objets sur l'unité la plus chère | meilleure note de base |
| **Champion** | intérêts pleins (50 or) jusqu'au niveau 7-8 | lit la réserve : quitte un trait contesté par 2 autres | protège son porteur, contre les Ombres (coins) | note selon sa composition |
| **Légende** | courbe d'un bon joueur (niveau 8 en 4-2, relance à 4-1 ou 5-1) | 3 plans, choisit au 1er atout ; ★3 de coût 1-3 si la réserve le permet | regarde l'adversaire de la manche suivante | note + contexte |

- Trois **tempéraments** tirés pour chaque IA : économe, relanceur (cherche des ★3 de coût 1-3), montée rapide (niveau 8).
- Mélange des 7 IA par difficulté choisie (comme `Royale.MIX`) : par ex. Champion = 2 Vétéran, 3 Champion, 2 Légende.
- Elles achètent dans **la même réserve** que le joueur (§6) et leurs plateaux se regardent.

---

## 5. Économie, atouts, objets, synergies

### 5.1 Or et expérience
| Règle | Valeur (réglage) |
|---|---|
| Or de départ | 2 (à 1-2) |
| Revenu de base | 1-2 : 2 · 1-3 : 2 · 1-4 : 3 · dès 2-1 : **5** par manche (JcJ ou gardien) |
| Intérêts | +1 par tranche de 10 or, **5 au plus** (à 50 or) ; comptés avant le revenu |
| Séries (victoires **ou** défaites JcJ) | 2-3 : +1 · 4 : +2 · 5 et plus : +3 ; les manches contre monstres et gardiens ne cassent rien |
| Victoire JcJ | +1 or |
| Prix d'une unité | son coût (1 à 5) |
| Vente | ★1 : coût · ★2 : 3 × coût (−1 si coût ≥ 2) · ★3 : 9 × coût (−1 si coût ≥ 2) ; les objets vont au banc |
| Actualiser la boutique | 2 or ; **verrou** gratuit (la boutique reste à la manche suivante) |
| Acheter de l'XP | 4 or = 4 XP ; +2 XP offerts à chaque manche dès 1-2 |
| Banc | 9 cases ; plateau = niveau (10 au plus) |

XP pour passer au niveau suivant : 2→3 : 2 · 3→4 : 6 · 4→5 : 10 · 5→6 : 20 · 6→7 : 36 · 7→8 : 48 · 8→9 : 72 · 9→10 : 84
(niveau 2 donné à 1-2).

### 5.2 Boutique : 5 unités, taux par niveau (%)
| Niveau | Coût 1 | Coût 2 | Coût 3 | Coût 4 | Coût 5 |
|---|---|---|---|---|---|
| 1-2 | 100 | 0 | 0 | 0 | 0 |
| 3 | 75 | 25 | 0 | 0 | 0 |
| 4 | 55 | 30 | 15 | 0 | 0 |
| 5 | 45 | 33 | 20 | 2 | 0 |
| 6 | 30 | 40 | 25 | 5 | 0 |
| 7 | 19 | 30 | 40 | 10 | 1 |
| 8 | 18 | 25 | 32 | 22 | 3 |
| 9 | 10 | 20 | 25 | 35 | 10 |
| 10 | 5 | 10 | 20 | 40 | 25 |

### 5.3 Atouts (entre les manches : 2-1, 3-2, 4-2)
Trois cartes, **une relance** par choix (toutes les 3), même rareté pour les 3 cartes d'un même choix ; rareté tirée par
choix : Argent 50 % / Or 35 % / Éclat 15 % (réglage ; jamais deux Éclats de suite). Un atout est permanent pour la partie.

| Rareté | Atout | Effet |
|---|---|---|
| Argent | Tirelire | +1 or au début de chaque manche |
| Argent | Relance offerte | 1 actualisation gratuite par manche |
| Argent | Apprenti | +3 XP tout de suite et +1 XP par manche |
| Argent | Composant | un composant au choix (carte à 3) |
| Argent | Renfort | 2 unités de coût 1 de ta famille la plus nombreuse |
| Argent | Peau dure | tes unités ont +120 PV |
| Argent | Premier sang | la 1re unité à toucher : +30 % d'attaque pour le combat |
| Argent | Esquive aiguisée | tes unités : +10 % d'esquive |
| Argent | Ralliement | quand un allié tombe, les autres récupèrent 8 % de PV |
| Argent | Mana vive | +15 mana au début de chaque combat |
| Or | Intérêts composés | plafond des intérêts : 5 → 10 (à 100 or) |
| Or | Pacte de sang | −15 PV de joueur, +25 or tout de suite |
| Or | Insigne | un Insigne tout de suite |
| Or | Chef de guerre | ton unité la plus chère : +30 % de PV et d'attaque |
| Or | Héritage | une classe verte et une de ses ascensions sur le plateau : +20 % de PV et d'attaque aux deux |
| Or | Écho de recrue | chaque 4e unité achetée arrive en double |
| Or | Riposte | quand une de tes unités esquive, elle rend 60 % de sa frappe |
| Or | Garde du corps | tes 2 unités les plus avancées : bouclier de 25 % des PV pendant 8 s |
| Or | Cœur de famille | +1 au compte d'une famille au choix (carte à 5) |
| Or | Forge de campagne | chaque gardien donne un objet complet de plus |
| Or | Main sûre | tes sorts signature coûtent 20 % de mana de moins |
| Éclat | Couronne | +1 unité sur le plateau |
| Éclat | Héros légendaire | une unité de coût 5 ★2 au choix parmi 3 |
| Éclat | Ordre de bataille | les 6 premières secondes : +25 % de vitesse d'attaque et de déplacement ; le 1er sort de chaque unité part à mi-mana |
| Éclat | Menace | gardiens deux fois plus forts, butin doublé ; +2 or par gardien vaincu |
| Éclat | Trésor du dragon | +30 or tout de suite, plus d'intérêts |
| Éclat | Niveau 11 | niveau maximal 11 ; +10 XP tout de suite |
| Éclat | Étoile filante | tes unités de coût 1-2 passent ★2 avec 2 copies au lieu de 3 |
| Éclat | Arsenal | 2 objets complets au choix (cartes à 3) |
| Éclat | Double trait | +1 au compte de **tous** tes traits d'arme actifs |

Texte permanent sans pourcentage : la carte dit « Tes unités ont plus de PV » et l'infobulle donne « +120 PV ».

### 5.4 Synergies : 15 traits (5 familles + 10 armes)

> **Révisé par le lot ACX-4 (17-18/10, `R_ACX4.md`, retour du joueur : « les traits de la famille du Guerrier sont tellement
> bons qu'on veut toutes les classes jaunes »)** : le 2e trait n'est plus celui de l'arme mais un **style porté par la
> lignée** (classe verte + ses 2 éveils : mêmes traits, coûts différents) ; chaque style réunit **2 lignées de 2 familles**,
> les 10 styles sont les 10 paires de familles (chaque famille partage un style avec chacune des 4 autres). Ids et effets des
> 10 anciens traits d'arme gardés ; trois renommés (Tir → **Cadence**, Chœur → **Harmonie**, Poudre → **Brasier**).
> 5 **unités ponts** (Exécuteur +Ombre, Danseuse envoûtante +Ferveur, Chantre de vie +Arcane, Maître des chimères +Traque,
> Arès mécanique +Rempart) ont un 3e trait : la famille d'à côté. Table : `AutochessData.LINEAGE_STYLE` / `BRIDGES`.
> | Style (2 / 4 / 6) | Lignées (familles) |
> |---|---|
> | Escrime | Templier (Rempart) + Danseuse de lames (Ombre) |
> | Estoc | Chevalier (Rempart) + Rôdeur (Traque) |
> | Fracas | Guerrier (Rempart) + Sage (Ferveur) |
> | Brasier (ex-Poudre) | Chevalier dragon (Rempart) + Démoniste (Arcane) |
> | Impact | Artiste martial (Ombre) + Luminaire (Arcane) |
> | Tranchant | Voleur (Ombre) + Chasseur (Traque) |
> | Harmonie (ex-Chœur) | Samouraï (Ombre) + Barde (Ferveur) |
> | Malédiction | Inquisiteur (Traque) + Clerc (Ferveur) |
> | Cadence (ex-Tir) | Ingénieur (Traque) + Illusionniste (Arcane) |
> | Élémentaire | Chaman (Ferveur) + Magicien (Arcane) |
> Le tableau des armes ci-dessous reste l'origine des effets (inchangés).
Le brief parlait de 10 familles : le code en a **5** (`class_data.family`, 12 classes chacune : Guerrier, Voleur, Chasseur,
Clerc, Magicien) et 20 lignées (une classe verte + 2 ascensions). **DÉCISION** : un trait de famille (seuils 3 / 6 / 9) +
un trait d'arme, les 17 types regroupés en **10 traits de 6 unités** (seuils 2 / 4 / 6). Chaque unité a exactement 2 traits.

| Famille (seuils 3 / 6 / 9) | Effet |
|---|---|
| **Rempart** (famille du Guerrier) | défense des Rempart +20 / 45 / 80 ; à 9, toute l'équipe +20 % de PV |
| **Ombre** (famille du Voleur) | au début, les Ombre bondissent sur la rangée arrière ennemie ; dégâts critiques +20 / 40 / 70 % |
| **Traque** (famille du Chasseur) | attaque +15 / 30 / 55 % contre une cible à plus de 3 cases ; à 6, portée +1 |
| **Ferveur** (famille du Clerc) | toutes les 4 s, soin de l'allié le plus blessé : 8 / 15 / 25 % de ses PV ; à 9, soins reçus +30 % |
| **Arcane** (famille du Magicien) | puissance des sorts des Arcane +20 / 45 / 80 % ; à 9, le 1er sort de chaque Arcane part deux fois |

| Arme (seuils 2 / 4 / 6) | Types | Effet |
|---|---|---|
| **Escrime** | épée | parade 15 / 30 / 50 % des attaques, riposte à 80 % |
| **Tir** | arc | vitesse d'attaque +15 / 35 / 60 % après 3 s ; à 6, les flèches traversent |
| **Élémentaire** | bâton | le sort laisse une zone : 10 / 25 / 50 % de ses dégâts par seconde, 3 s (à 6 : ralentit) |
| **Tranchant** | katana, dague | achèvent sous 10 / 15 / 20 % de PV |
| **Fracas** | hache, marteau | toutes les 4 / 3 / 2 attaques, étourdit 0,5 s |
| **Estoc** | rapière, lance | ignorent 20 / 40 / 70 % de la défense |
| **Poudre** | canon, faux-fusil | les attaques explosent à 1 case : 20 / 40 / 70 % des dégâts |
| **Chœur** | sceptre, guitare | toute l'équipe gagne 2 / 4 / 7 mana par seconde |
| **Malédiction** | grimoire, bâton de métal | à 3 s, les 2 / 4 / tous les ennemis les plus forts : attaque et défense −15 / 25 / 35 % |
| **Impact** | espadon, gantelets | chaque coup sur la même cible : +5 / 8 / 12 % de dégâts (10 fois au plus) |

Une unité compte une fois par trait (deux Guerriers = 1 Fracas). Un Emblème (Annexe B) ajoute un trait.

### 5.5 Objets
**DÉCISION : composants → objets complets** (8 composants de base + l'Insigne rare ; 36 objets nommés d'après nos passifs) :
c'est le cœur du « je construis mon porteur », et nos pièces d'équipement (sets, passifs à +6/+8/+10) sont trop riches pour
un plateau de 20 unités. Tables complètes et butin : `ANNEXE_B_OBJETS.md`. 3 objets par unité, combinaison automatique ;
une unité vendue rend ses objets au banc d'objets (10 cases).

### 5.6 Choix partagé (manches x-4)
9 unités (coût autour de l'étape : 2-4 → coûts 1-3, 3-4 → 2-4, 4-4 et plus → 3-5) portant chacune un composant, sur un
anneau au centre. **Ordre : les PV de joueur les plus bas d'abord** (égalité : place à la manche précédente). L'IA choisit
tout de suite ; le joueur a 10 s (choix automatique ensuite) ; les stratèges marchent vers leur choix (0,6 s chacun). Sans
course en temps réel : un menu de cartes et l'anneau 3D derrière.

---

## 6. Boutique et réserve
**DÉCISION : réserve partagée entre les 8 stratèges** (copies limitées). Coût d'implémentation faible (un compteur par unité,
`core/autochess_pool.gd`) et c'est ce qui rend la lecture des autres plateaux utile (« trois stratèges jouent Tir, je change »).

| Coût | Copies par unité | Unités | Total |
|---|---|---|---|
| 1 | 29 | 10 | 290 |
| 2 | 22 | 15 | 330 |
| 3 | 18 | 15 | 270 |
| 4 | 12 | 10 | 120 |
| 5 | 10 | 10 | 100 |

Tirage d'une case : coût tiré selon le niveau (§5.2), puis unité tirée **au poids des copies restantes** de ce coût. Une
unité vendue, éliminée avec son stratège ou non achetée en fin de boutique revient à la réserve. Invariant testé : copies en
réserve + copies possédées = total, à chaque instant.

---

## 7. Interface et récompenses

### 7.1 Écrans (1280×720 au moins, manette d'abord)
| Écran | Une idée | Contenu |
|---|---|---|
| Page du lobby (rangée **Affrontements**, après Battle royale) | « Choisis ta difficulté » | 4 boutons (Recrue, Vétéran, Champion, Légende ; fermés « 🔒 » avec leur condition), 3 lignes de récompenses (✔ si gagnées), **Reprendre la partie** s'il y en a une, Lancer (épinglé) |
| Plateau (préparation) | « Compose ton équipe » | plateau 3D vu de 3/4 (caméra fixe, deux zooms), banc ; en bas la boutique (5 cartes : portrait, nom, coût, 2 icônes de trait), or au centre, niveau + XP + [Acheter XP] à gauche, [Actualiser] et verrou à droite ; colonne gauche : traits (actifs en or, pastilles 2 / 4 / 6) ; colonne droite : 8 stratèges (portrait, PV, série) ; en haut : frise de l'étape (● JcJ, ◆ choix, ☠ gardien) et minuteur ; [Prêt] |
| Combat | « Regarde » | boutique repliée, [×2], barre de PV et mana au-dessus de chaque unité ; compteur de dégâts (option) ; la colonne des stratèges permet de regarder un autre plateau |
| Atout | « Choisis un atout » | 3 grandes cartes, [Relancer] en dessous |
| Choix partagé | « Prends ton héros » | 9 cartes en anneau, ordre des stratèges en haut |
| Fiche d'unité | « Qui est-ce ? » | survol ou curseur posé : stats, sort (texte court ; chiffres en infobulle), 2 traits, objets, étoiles |
| Bilan de manche | « Gagné / perdu » | 3 s en surimpression : résultat, PV perdus, or gagné (détail : base, intérêts, série) |
| Fin de partie | « Ta place » | `ResultsPanel.show_spec` : place en grand, tuiles (manches gagnées, meilleure unité, trait principal, or dépensé), bloc Gardé (coffres, titre), « Ton équipe finale », boutons Rejouer / Retour |

- **Stratège** = ton héros du hub (tenue, accessoires, aura, skin d'arme) qui marche au bord du plateau : c'est la vitrine des
  apparences gagnées. IA : apparences tirées au hasard.
- **Manette** : la croix / le stick déplacent un **curseur de case** sur plateau + banc ; A prend / pose ; maintenir X
  0,5 s vend ; la fiche de l'unité sous le curseur s'affiche seule (panneau latéral) ; B = retour ; Y Prêt ; LB acheter de l'XP ; RB passe à la boutique (UiNav, 5 cartes, A achète) ;
  gâchette gauche actualise ; gâchette droite verrou ; menu = pause. Clavier : 1-5 achète, D actualise, F XP, E vend,
  Espace Prêt ; souris : glisser-déposer. Le plateau a un `gui_input` relié (règle UiNav) ; `test_nav_screens` le couvre.
- **Fiches** à la 1re partie (`Tutorial.CARDS`, ≤ 125 signes) : « Achète et place », « Trois copies, une étoile »,
  « Les traits », « L'or qui dort rapporte ». Entrée au Guide F1 (chapitre Modes).

### 7.2 Récompenses (mode scellé : apparences et titres seulement)
| Palier atteint | 1re fois par difficulté | Ensuite (par jour, au plus) |
|---|---|---|
| Top 4 | coffre d'apparence commun | 1 commun |
| Top 2 | coffre rare | 1 rare (partagé avec la victoire) |
| 1re place | coffre mythique (**légendaire** en Champion et Légende) + titre de la difficulté | — |

- Titres de victoire : Stratège (Recrue), Tacticien (Vétéran), Grand tacticien (Champion), Maître de l'Échiquier (Légende).
- Titres d'exploit (une fois, toute difficulté) : **Trois étoiles** (une unité de coût 4 ou 5 ★3), **Pur sang** (un trait de
  famille à 9), **Invaincu** (1re place avec 70 PV ou plus), **Frugal** (1re place sans jamais actualiser la boutique).
- Ouverture : Recrue et Vétéran dès le départ ; Champion après un top 4 en Vétéran ; Légende après une 1re place en
  Champion (mode dev : tout). Plafonds dans `Profile.records["ac_rewards"]` (comme `sv_rewards`, rien à migrer).
- Quêtes : `Quests.end_run("autochess", top4, {place, rounds_won})` ; entrée `QuestPool.ACTS` ; pastilles `gives` :
  `["look", "title"]`.

---

## 8. Plan d'implémentation

Fichiers neufs préfixés `autochess`. Les fichiers partagés ne sont touchés que par le lot indiqué (colonne « Partagés »).
Lancement direct : `world.tscn -- --autochess [--ac-diff=0..3] [--seed=N] [--autoplay] [--auto-quit]` (ligne `[autochess]`
par manche). `Modes.current()` rend `"autochess"`, ajouté à `Modes.SEALED`.

| Lot | Contenu | Fichiers propres | Partagés | Dépend | Tests / acceptation | Taille |
|---|---|---|---|---|---|---|
| **AC-A** Données | tables §5-6 (éco, XP, boutique, réserve, dégâts), traits, objets, atouts **en données** avec clés d'effet ; unités générées | `core/autochess_data.gd`, `data/autochess_units.json`, `tools/autochess_units.py` | — | — | `test_ac_data` : 60 unités, 12 / famille, 6 / trait d'arme, coûts 10/15/15/10/10, taux = 100, 36 recettes | S (≈ 400) |
| **AC-B** Partie | machine d'étapes sans scène, boutique, réserve, achat / vente / fusion, XP, or, séries, dégâts, appariement, fantôme, places, sauvegarde ; combat **injecté** (fonction) | `core/autochess.gd`, `core/autochess_pool.gd` | — | A | `test_ac_game` : 500 parties au hasard sans erreur ; invariant de réserve ; fusion banc plein ; revenu attendu ; même graine = même partie ; reprise identique | M (≈ 900) |
| **AC-E** Combat réel | directeur : 4 (ou 8) plateaux à 300 m, apparition en miroir, équipes par `ffa_id`, fin, mort subite, égalité, ×2, rendu du seul plateau regardé ; squelette d'unité (fiche, étoiles, mana, sort signature, ciblage « le plus proche ») ; profil `autochess` | `core/autochess_director.gd`, `ai/autochess_unit.gd` (squelette) | `core/modes.gd`, `core/mode_rules.gd`, lancement dans `world.gd` / `run_director.gd` | A | `test_ac_fight` : 5 contre 5 fini en 15-45 s ; sorts à mana pleine ; égalité à 45 s ; 4 plateaux en même temps sans interférence ; budget d'image mesuré (80 unités) | L (≈ 900) |
| **AC-U** IA de combat | rôles, score de cible, focus d'équipe, recul, plongée, protection, soins, sorts par type, esquive des zones, bornes, reciblage (§4.1) ; IA naïve ; banc d'essai | `ai/autochess_unit.gd` (après le squelette d'AC-E), `tools/autochess_ai_bench.tscn` | — | E (squelette) | `test_ac_unit_ai` (scénarios du §4.2) ; banc : cibles du §4.2 tenues ; rapport `R_AC_U.md` | L (≈ 1 000) |
| **AC-F** Plateau | grille hexagonale 3D, banc, curseur de case (manette / souris / glisser), stratège qui marche, miroir adverse | `world/autochess_board.gd`, `world/autochess_bench.gd`, `ui/autochess_cursor.gd` | — | A, B | `test_ac_board` : placement limité au niveau, banc plein, curseur atteint toutes les cases | M (≈ 800) |
| **AC-C** Simulateur | combat de données (§4.3) : outil d'équilibrage et repli ; mêmes clés d'effet ; calibré sur le vrai | `core/autochess_sim.gd`, `tools/autochess_fight.tscn` | — | A, U | `test_ac_sim` : déterminisme, médiane 20-35 s ; `test_ac_sim_real` : même vainqueur ≥ 75 % | M (≈ 900) |
| **AC-D** IA stratèges | 4 difficultés, 3 tempéraments, compo, éco, placement (selon les rôles du §4.1), objets, atouts | `core/autochess_ai.gd` | — | B, C | sur 200 parties simulées : Légende top 4 ≥ 75 % contre 7 Recrues ; Recrue top 4 ≤ 25 % contre 7 Légendes | M (≈ 800) |
| **AC-H** Effets | objets et atouts : effets appliqués aux fiches et déclencheurs (frappe, sort, chute, seuil de PV), **même code** pour le combat réel et le simulateur | `core/autochess_items.gd`, `core/autochess_augments.gd` | — | A (E, C pour brancher) | `test_ac_effects` : chaque objet / atout a un effet mesurable en combat réel (5 contre 5 court) ; mêmes effets dans le simulateur | M (≈ 900) |
| **AC-G** Interface | boutique, traits, stratèges, frise, atouts, choix partagé, fiche d'unité, bilan de manche | `ui/autochess_hud.gd`, `ui/autochess_shop.gd`, `ui/autochess_traits.gd`, `ui/autochess_players.gd`, `ui/autochess_augments.gd`, `ui/autochess_carousel.gd`, `ui/autochess_unit_card.gd` | — | B, F | `test_ac_ui` ; `tests/shot_ac.tscn` sans ligne `[débord]` en 1280×720 ; `test_nav_screens` | L (≈ 1 200) |
| **AC-I** Entrée et fin | activité, page du lobby, bilan, récompenses, quêtes, fiches, Guide | `core/autochess_rewards.gd`, `ui/autochess_results.gd` | `ui/activities.gd`, `ui/lobby.gd`, `core/quest_pool.gd`, `core/tutorial.gd`, `ui/guide.gd`, `ResourceHelp` | B, G | `test_ac_rewards` (plafonds, mode scellé : hub intact), `test_p4_activities -- autochess`, `test_texts_fr` | M (≈ 600) |
| **AC-J** Mesure | parties entre IA en masse (simulateur), parties réelles au pilote, rapport, réglages | `tools/autochess_games.tscn`, `tools/autochess_report.py`, `tests/ac_mesures.json` | — | C, D, H, U | §9 tenu ; rapport `R_AC_J.md` | M |

**Vagues (équipe de 4 agents au plus, fichiers disjoints)** :
1. AC-A seul (court, fige les clés de données et d'effet dont tout dépend).
2. **AC-B, AC-E, AC-F en parallèle** ; AC-E livre d'abord le squelette de `ai/autochess_unit.gd` (fiche, mana, sort, ciblage
   simple), puis s'en tient à `autochess_director.gd`.
3. **AC-U, AC-H, AC-G, AC-C en parallèle** (AC-U seul dans `autochess_unit.gd` ; AC-H branche ses effets par les points
   d'appel prévus en AC-A : E, U et C appellent `AutochessItems.apply` / `AutochessAugments.on_event`, AC-H ne réécrit pas
   leurs fichiers).
4. **AC-D et AC-I** en parallèle, puis AC-J (qui peut commencer dès que C et D tournent).

Pièges : dossier partagé (tests sur une copie, `python tools/run_tests.py`), commit par chemins explicites ; `--import` après
chaque nouveau `class_name` ; version + CHANGELOG à chaque envoi de code ; aucun `taskkill` global.

---

## 9. Équilibre et mesure

- **Outil** : `tools/autochess_games.tscn` (Godot headless, simulateur AC-C + IA AC-D, 8 IA, graine) écrit une ligne JSON par
  partie (places, compositions finales, traits, objets, atouts, manches, durée de chaque combat) ; `python
  tools/autochess_report.py` lit les lignes. Cible : < 3 s par partie, 2 000 parties par passe (4 copies en parallèle).
- **Mesures** : place moyenne (sur 8, moyenne 4,5) par unité (finale), par niveau de trait, par objet, par atout ; taux de
  choix ; durée des combats ; manche de fin ; ★3 obtenues ; or moyen à 4-1.

| Mesure | Cible |
|---|---|
| Place moyenne d'une unité à son coût (porteuse d'objets) | entre 4,0 et 5,0 ; aucune unité jamais jouée par Légende |
| Trait à son seuil haut | entre 3,5 et 5,0 ; aucun trait choisi par plus de 30 % des Légende |
| Atout | place moyenne 4,0-5,0 ; pas un atout pris plus de 50 % des fois où il est proposé |
| Combat (réel, `--autoplay`) | médiane 22-28 s ; 90 % sous 40 s ; égalités < 3 % |
| Partie (réel, durées mesurées × manches du simulateur) | vainqueur : 25-30 min (×1) ; 1er éliminé avant 4-1 dans moins de 20 % des parties |
| Échelle des difficultés | §8 AC-D ; joueur au pilote Vétéran : top 4 ≈ 50 % en Vétéran |
| IA de combat (banc du §4.2) | IA complète ≥ 75 % contre la naïve ; autres cibles du §4.2 |
| Simulateur contre réel | même vainqueur ≥ 75 % |

- Réglages en tête de `core/autochess_data.gd` ; tout changement refait `tests/ac_mesures.json` (comme `sv7_mesures.json`).
- En partie réelle : `world.tscn -- --autochess --autoplay --auto-quit` (le pilote joue le stratège du joueur avec l'IA
  Vétéran) pour la durée vraie et les erreurs d'affichage.

---

## 10. Questions ouvertes (tranchées par défaut, le joueur peut revenir dessus)

| Question | Décision par défaut | Pourquoi |
|---|---|---|
| Nom du mode | **L'Échiquier** (sous-titre « 8 stratèges, une seule couronne ») | court, français, aucun nom d'autre jeu |
| Où et quand | Affrontements, après Battle royale ; **ouvert dès le départ** | scellé : rien du compte n'y change la force |
| Classes non débloquées | toutes dans la réserve | réserve identique pour les 8 |
| Combat sur la grille ou libre | libre (cases pour placer) | des héros qui se battent vraiment ; réutilise `ClassRival` |
| Cerveaux d'IA | **aucun** (ni capitaine, ni réentraînement) | décision du joueur : mieux vaut 0 qu'un cerveau qui écrase le plateau |
| Qualité de l'IA des unités | même IA scriptée (Difficile) pour les 8 stratèges, mesurée au banc (§4.2) | « il faut que nos IA scriptées jouent très bien » ; équitable |
| Prendre la main d'une unité | non | autochess = décisions |
| Combats cachés | vrais combats sur plateaux invisibles ; simulateur en repli et pour l'équilibrage | mesure d'AC2 : 160 unités tiennent |
| Objets | composants → 36 objets | sensation « porteur » ; nos pièces sont trop lourdes ici |
| Réserve partagée | oui | peu de code, vraie lecture des autres plateaux |
| Moment des atouts | 2-1 / 3-2 / 4-2 | partie de 25 min (§2.1) |
| Choix partagé | menu par ordre de PV, anneau 3D derrière | pas de course temps réel contre des IA |
| Sauvegarde | oui, au début de chaque préparation | 30 min de partie |
| Vitesse | ×1 / ×2 en combat, préparation écourtée par Prêt | durée cible |
| Maîtrise ou insignes | non : apparences et titres | mode scellé |
| Classement (rangs Bronze → Platine) | pas en v1 ; les difficultés et titres en tiennent lieu | taille |
| Multijoueur | non | aucun réseau dans le jeu |
