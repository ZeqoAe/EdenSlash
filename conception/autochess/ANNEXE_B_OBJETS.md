# Annexe B — composants et objets de L'Échiquier (valeurs de départ, recalées par AC-J)

Une unité porte **3 objets** au plus. Deux composants posés sur la même unité se combinent tout de suite en objet complet
(aucun choix à faire). Un objet ne se retire pas (seul l'objet « Marteau de réforge », gagné aux gardiens, rend les composants
d'une unité au banc). Les noms viennent de nos passifs et procs (`Cards.PASSIVE_EFFECTS`, `Boons`) : le joueur les connaît
déjà de la Survie et du Survivant ; leurs icônes sont réutilisées.

## Les 9 composants

| Composant | Effet seul | Où |
|---|---|---|
| Lame d'acier | +10 % d'attaque | monstres, gardiens, choix partagé |
| Arc court | +10 % de vitesse d'attaque | idem |
| Bâton runique | +10 % de puissance des sorts | idem |
| Larme de mana | +15 mana au début du combat | idem |
| Plastron | +20 défense | idem |
| Voile | +20 défense magique | idem |
| Ceinture du géant | +150 PV | idem |
| Gant de chance | +15 % de critique | idem |
| **Insigne** (rare) | aucun seul | gardiens 4-7 et 6-7, atout « Insigne » |

## Les 36 objets complets (deux composants de base)

| | Lame | Arc | Bâton | Larme | Plastron | Voile | Ceinture | Gant |
|---|---|---|---|---|---|---|---|---|
| **Lame** | Exécuteur | Transe de combat | Lame statique | Écho | Soif de sang | Briseur de sorts | Tueur de géants | Précision |
| **Arc** | | Lame vive | Tir multiple | Élan | Pas du vent | Ricochet | Second souffle | Œil du chasseur |
| **Bâton** | | | Arcanes | Incantation | Onde de choc | Nova de givre | Braise | Sort critique |
| **Larme** | | | | Source | Barrière | Persistance | Vigueur | Flux de combo |
| **Plastron** | | | | | Robustesse | Mur du titan | Brute | Coup final lourd |
| **Voile** | | | | | | Lame de givre | Ange gardien | Volatile |
| **Ceinture** | | | | | | | Colosse | Plaies profondes |
| **Gant** | | | | | | | | Fortune |

Effets (s'ajoutent aux stats des deux composants) :

| Objet | Effet |
|---|---|
| Exécuteur | dégâts +40 % contre une cible sous 30 % de PV |
| Transe de combat | chaque attaque : +4 % de vitesse d'attaque (10 fois au plus) |
| Lame statique | toutes les 3 attaques, éclair à 2 ennemis : 120 % de l'attaque |
| Écho | après un sort, l'attaque suivante inflige 200 % |
| Soif de sang | vol de vie 20 % ; bouclier de 15 % des PV la 1re fois sous 40 % |
| Briseur de sorts | chaque attaque retire 10 mana à la cible |
| Tueur de géants | +25 % de dégâts contre une cible qui a plus de PV max |
| Précision | critique +25 %, dégâts critiques +40 % |
| Lame vive | +30 % de vitesse d'attaque, encore +30 % après 6 s de combat |
| Tir multiple | chaque attaque touche un 2e ennemi à 70 % |
| Élan | +5 mana de plus par attaque |
| Pas du vent | touché : +25 % d'esquive 4 s (recharge 6 s) |
| Ricochet | les attaques rebondissent une fois à 60 % |
| Second souffle | sous 50 % de PV, une fois : soin de 20 % et +30 % de vitesse d'attaque |
| Œil du chasseur | portée +1 case, critique +20 % |
| Arcanes | puissance des sorts +50 % |
| Incantation | mana max −20 % |
| Onde de choc | le sort renverse les ennemis à 2 cases (1 s) |
| Nova de givre | au début puis toutes les 8 s : gel 1,5 s des ennemis à 2 cases |
| Braise | les sorts brûlent 15 % des PV max sur 5 s ; soins reçus −40 % |
| Sort critique | les sorts peuvent critiquer ; critique +20 % |
| Source | +10 mana toutes les 3 s |
| Barrière | chaque sort : bouclier de 20 % des PV pendant 4 s |
| Persistance | zones des sorts : +2 s, rayon +20 % |
| Vigueur | chaque sort soigne 12 % des PV max |
| Flux de combo | chaque critique rend 8 mana |
| Robustesse | défense +60, renvoie 15 % des dégâts physiques |
| Mur du titan | PV +20 %, dégâts reçus −15 % |
| Brute | +500 PV ; insensible aux contrôles les 10 premières secondes |
| Coup final lourd | toutes les 3 attaques, étourdit 0,75 s |
| Lame de givre | les attaques réduisent la vitesse d'attaque de la cible de 25 % (3 s) |
| Ange gardien | sous 40 % de PV, une fois : invulnérable 1,5 s |
| Volatile | à sa chute, explose : 25 % de ses PV max aux ennemis à 2 cases |
| Colosse | +900 PV, taille ×1,15 |
| Plaies profondes | saignement de 3 % des PV max par seconde (4 s), soins reçus −50 % |
| Fortune | critique +35 % ; chaque élimination : +1 or (2 par manche au plus) |

## Insigne
| Combinaison | Objet |
|---|---|
| Insigne + n'importe quel composant | **Emblème** : on choisit (carte à 3 choix) une famille ou un trait d'arme que l'unité ne porte pas ; elle compte pour ce trait. Les stats du composant restent. |
| Insigne + Insigne | **Couronne** : +1 unité sur le plateau (ne s'équipe pas : elle va droit au compteur d'équipe) |

## Butin par manche (attendu sur une partie : 9 à 11 composants, 0 à 2 Insignes)
| Manche | Butin |
|---|---|
| 1-2 / 1-3 / 1-4 (monstres) | 1 composant chacune ; 1-3 : +2 or ; 1-4 : +3 or et un héros de coût 2 |
| x-4 (choix partagé) | chaque héros proposé porte un composant |
| 2-7 gardien | 2 composants (perdu : 1) |
| 3-7 gardien | 1 objet complet au choix parmi 3 (perdu : 1 composant) |
| 4-7 gardien | 2 composants + Insigne une fois sur deux (perdu : 1 composant) |
| 5-7 gardien | 1 objet complet au choix + Marteau de réforge |
| 6-7 gardien | Insigne + 1 composant |
| 7-7 gardien | 2 objets complets au choix |
