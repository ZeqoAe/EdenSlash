# Équipe Nouveaux modes — concertation (tour 2, jeu 0.1.130)

Lus : `00_BRIEF.md`, notre `rapport_1.md` et les rapports Progression (P), Équilibrage (E),
Interface (I) et Builds (B). Aucun désaccord n'a demandé de vérifier le code : les points de code
cités par les autres équipes (`Tower.RULES`, `hero_vs_hero_factor`, `ZONE_DAMAGE` par `Run.stage`,
records de la Tour perdus) concordent avec nos lectures du tour 1.

---

## 1. Réponses aux questions qui nous sont adressées

### Progression
1. **Tour = joaillerie et cristaux, Donjons = pièces ciblées et plans** : d'accord, c'est notre règle
   « un gain propre par activité ». **Fabrication** : vous la portez (carnet de plans dans la
   Collection, recette, coût en éclats, cristaux, insignes) ; nous portons **où et comment les plans
   tombent** (quel donjon, quelle difficulté, quelle chance).
2. **Ordre d'ouverture** : d'accord avec P2, avec un seul ajustement pour les Donjons (voir 3.4).
   Arènes : rang Or de la Ligue (si elles se font).
3. **Panthéon** : une **page à part dans le Duel** (onglet « Panthéon » à côté de « Libre » et
   « Classé »). Format : celui d'Équilibrage E3.5 (conditions d'entraînement), voir 3.5.
4. **JcJ où l'équipement compte** : oui, sans second système : le **Duel libre** prend
   `gear_weight` 0,75 (E3.1). L'équipement du hub sert donc à la Tour, aux Donjons (synchronisé) et au
   Duel libre ; le Duel classé reste à 0,5 et le Panthéon à 0.

### Équilibrage
1. **Liste des modes et contrats (E2)** : d'accord, avec ces retouches : Donjon **10 à 12 min**,
   boss **2 à 3 min** (4 min fait long pour un mode qui se rejoue) ; Défi du jour = contrat Survie
   sur une map (~12 min) ; Ruée des boss ~1 min 30 par boss ; Académie : pas de contrat (épreuves
   chronométrées) ; **Champ 10v10 : profil inutile, l'activité sort du menu** (voir 3.7).
2. **Donjons** : **avec peu de cartes** (une par salle, ~4) ; niveau **imposé par la difficulté**
   (pas choisi librement) ; **pas de groupe** dans la 1re version. Valeurs : votre colonne « sans
   cartes » d'E4 (PV ×1,6) convient, 4 cartes ne justifient pas ×2,4.
3. **Tour** : garde ses cartes de run ; **duels de la Tour sous le profil `tour_duel`** (E3.4) :
   d'accord, nous abandonnons notre « une seule échelle PvpCaps avec un multiplicateur de PV ».
4. **Panthéon en conditions d'entraînement** (niveau 10, sans équipement, g = 0) : **d'accord**,
   c'est la seule égalité garantie avec un cerveau.
5. **Arènes** : manches (pas de réapparition), 2 manches gagnantes, pas d'objectif ; soins sur
   alliés seulement quand les arènes se font (M6). Vos valeurs E3.6 sont à garder en réserve.

### Interface
1. **Fiche de 3 lignes et « Rapporte : … » de chaque activité** : fournies en section 6 (tableau).
2. **Académie dans la Zone d'entraînement (onglet « Leçons »)** : d'accord, et nous y rangeons nos
   Épreuves de maîtrise (voir 3.3). L'étiquette du menu Jouer devient « Entraînement et Académie ».
3. **« Rejouer » en fin de Tour** : repartir du **palier de départ** (étage en x1 d'où l'on est parti),
   avec un 2e bouton « Continuer du palier N » quand le record a passé un nouveau palier.
4. Menu Jouer à 3 rangées (Aventure, Défis, Affrontements) + Entraînement : nous maintenons la
   demande ; verrous grisés avec condition (I2) : d'accord.

### Builds
1. **Tour** : aujourd'hui pas de trophée, pas d'enclume, cartes oui (les améliorations d'arme y
   sortent donc). Nous proposons **un choix de trophée tous les 10 étages** (après le boss) : B2, B3
   et B8 s'y appliquent tels quels. Bascule dans le profil (`trophies` d'E1).
2. **Combos d'états (B4) et esquive parfaite (B7) en Duel** : oui, même comportement partout,
   chiffres du profil JcJ (combo ×1,5, E7).
3. **Soins sur alliés** : pas maintenant ; seulement au lancement de M6.
4. **Familiers (B12) en Donjon** : pas dans la 1re version des Donjons ; le Donjon les accueillera
   bien plus tard (boss = cible unique, pas de horde qui noie le familier).

---

## 2. Accords (sans réserve)

- **Un profil de règles par mode, à un seul endroit** (E1 = notre M0, fusion en 3.1).
- **Fil d'éveil P2** avec verrous visibles (I2) ; le mode dev ignore les verrous ; on ne reverrouille
  jamais une sauvegarde existante.
- **Records gardés dans tous les modes** (P1g) : règle commune du socle.
- **Cerveaux** : seulement en 1 contre 1, figés dans git pour le Panthéon (P8), aucune observation
  ajoutée (contrainte du brief).
- **Gains par mode** (P5) : Survie = fortification et insignes ; Tour = joaillerie et cristaux ;
  Donjons = pièces ciblées et plans ; Duel = titres puis Panthéon.
- **Journal de run E6** : il doit couvrir aussi Tour, Donjons, Défis (le champ `mode` du journal).
- **Tutoriel dans la vraie Survie** (I1, couches 0 à 3), passer ne débloque rien.
- **Identité de build constante entre modes** (B, section 8).

---

## 3. Conflits, imbrications et fusions

### 3.1 M0 (socle activité) + E1 (`mode_rules.gd`) : une seule version

Les deux propositions décrivent la même chose sous deux angles ; nous en faisons **un socle en deux
étages**, livré en un bloc (coût **M**, pas M + M) :

| Étage | Fichier | Contenu | Qui en décide |
|---|---|---|---|
| **Fiche** | `ui/activities.gd:LIST` | id, rangée, nom, image, fiche 3 lignes, `gains` (« Rapporte : … »), `duration`, `unlock` (clé de `core/unlocks.gd`, P2), `profile` (clé de profil) | Modes, Interface, Progression |
| **Comportement** | `core/modes.gd` : `Modes.current` + un script par mode (`survival`, `tower`, `dungeon`, `duel`, `training`, `challenge`…) | points d'entrée communs : `start`, directeur, `on_hero_down`, `on_level_up`, `cards_at_start`, `finish` (gains + records), `replay` (pour « Rejouer », I5) | Modes |
| **Chiffres** | `core/mode_rules.gd:PROFILES` (E1) | monstres, héros (`gear`, `cards`, `trophies`, `anvil`, `meta`, `res`, `spells` : cartes / preset), héros contre héros, gains ; surcharge du mode dev | Équilibrage |

Règles de la fusion :
- **Une seule source du mode en cours** : `Modes.current` remplace les tests `Tower.active`,
  `Duel.active`, `Training.active` dispersés ; `ModeRules.get("clé")` lit le profil de
  `Modes.current` (E1 n'a plus à deviner le mode).
- **La différence entre les deux étages** : le profil dit *combien* (PV des monstres, nombre de
  résurrections, poids de l'équipement), le script dit *comment* (que se passe-t-il quand le héros
  tombe, quand la partie finit). Notre champ « source des sorts / de l'équipement » passe dans le
  profil d'E1 (famille Héros).
- **Profils** : ceux d'E1 + `donjon`, `defi` (Survie d'une map + modificateurs), `ruee` (boss),
  `academie`, `tutoriel` (E, « Avis » : dégâts ×0,4 sur la 1re map de la 1re partie). **Retirés** :
  `champ`.
- **Livraison** : 1er envoi = rangement **sans changement visible** (valeurs actuelles), avec
  `test_farm`, `test_pvp` et un **test de la Tour** à créer (il n'y en a pas).

### 3.2 Une table de modificateurs commune (nouvelle imbrication)

Trois propositions tirent des « contraintes » dans une liste : les **rangs héroïques** (P6, façon
pacte), le **Défi du jour** (M1a) et les **étages-épreuves de la Tour** (M3). Nous proposons **une
seule table** `core/modifiers.gd` (id, texte, effet sur le profil, coût de difficulté), lue par les
trois. Exemples : élites ×2, soins reçus ÷2, coffres +30 %, enclume plafonnée à +6, une vie,
projectiles des monstres doublés, pas de relance. Coût S en plus de M0. Équilibrage fixe les
valeurs, Progression les récompenses par rang.

### 3.3 Épreuves M1b face au tutoriel I1 : nous cédons le tutoriel

- Au tour 1 nous disions « les Épreuves sont le tutoriel ». Interface propose mieux : apprendre
  **dans la 1re vraie Survie** (Premiers pas). **Nous l'adoptons.**
- Nos Épreuves de maîtrise **deviennent l'Académie** (I1, couche 4) : Interface pilote l'affichage
  (onglet Leçons, médailles), nous pilotons le **contenu et les règles** des épreuves.
- Contenu consolidé : 1) les 10 Premiers pas rejouables (sans médaille) ; 2) leçons d'expert,
  chacune avec bronze / argent / or : annulations parfaites en série, esquive aérienne, sauter
  5 ondes de choc, esquiver 30 attaques annoncées sans être touché, enchaînement parfait (si B7),
  esquive parfaite défensive (si B7), mannequin en temps limité avec classe imposée, duelliste
  Normal sans sort.
- Gains : médailles → succès (P4) et titres ; l'or d'une leçon débloque **la carte liée au geste**
  (Builds section 7 : « succès liés à l'axe »), jamais de puissance brute.

### 3.4 Ordre de déblocage des modes (Progression P2) : version commune

| Ouvre | Condition | Changement par rapport à P2 |
|---|---|---|
| Survie I, Entraînement et Académie | nouvelle partie | Académie ajoutée |
| **Défi du jour** | 1re run de Survie terminée | ajouté |
| **La Tour** (Facile, Normal) | Époque I terminée | — |
| **Duel libre et Duel classé** | 3 duellistes battus dans la Tour | — (nous renonçons au « Duel libre après 1 duelliste ») |
| **Donjons** | Époque II terminée ; **dans la page, chaque donjon est ouvert si son boss a été battu en Survie** | P2 + notre condition par donjon : à l'ouverture, ~6 donjons sur 8 disponibles, les autres affichent « bats le boss de X en Survie » |
| **Ruée des boss** | Époque II terminée | ajouté (même moment que les Donjons : une seule fenêtre « Nouveau » à 2 entrées) |
| Tour Difficile, Hardcore | 50 étages en Normal, puis en Difficile | — |
| **Panthéon** | rang **Platine** de la Ligue (= victoire contre le Hardcore scripté) **ou** étage 100 de la Tour | P8 reformulé : le Platine **est** la victoire contre le Hardcore |
| Gantelet | rang Or de la Ligue | ajouté |
| Arènes (si faites) | rang Or de la Ligue | — |

Pourquoi le double verrou des Donjons : la condition « époque II » de P2 évite de tout ouvrir en même
temps que la Forge et la Tour ; la condition par boss donne au joueur une raison de voir chaque zone.

### 3.5 Donjons : M2 face à E4 (et Builds §8) — version unique

| Point | M2 (tour 1) | E4 | Builds | **Version commune** |
|---|---|---|---|---|
| Équipement | hub (préréglage), ramené au niveau | synchronisé min(niveau, plafond) | — | **synchronisé** (E4), affiché « synchronisée 23 / 45 » (I) |
| Sorts | preset | — | — | **les 12 sorts du preset** (`Run.fill_from_preset`, comme le Duel) |
| Cartes | une par salle | avec ou sans | mini-Survie avec cartes | **un choix de carte par salle (~4)**, pas de trophée ni d'enclume |
| Niveau | Normal / Héroïque / Mythique | paliers 20 / 45 / 65 / 85 | — | **Normal** = palier de l'époque du donjon (20, 45, 65 ou 85) ; **Héroïque** = +15 ; **Mythique** = 90 pour tous |
| Durée | 8 à 12 min | 10 à 15 min, boss 2 à 4 min | — | **10 à 12 min**, boss **2 à 3 min**, rage du boss à 3 min (E4 : dégâts ×2 toutes les 30 s) |
| Monstres | — | PV ×1,6, élites ×2,5, boss ×25 | profil « boss » | valeurs d'E4 (colonne sans cartes), profil `donjon` |
| Butin | pièce de panoplie au choix parmi 2, éclats, plan ~10 % | — | — | inchangé ; rareté : Normal mythique, Héroïque légendaire, Mythique **éveillée** (note du joueur) |

Salles : 3 salles (vagues, élites, pièges `hazard.gd`) + salle de repos (marchand) + boss à pleine
force. La question au joueur « équipement du hub ou à zéro » **devient une confirmation** : trois
équipes sur quatre vont vers l'équipement synchronisé ; la variante « à zéro » ferait doublon avec la
Survie et la Ruée des boss.

### 3.6 Duel et Panthéon : M4 face à P8 et E3

- **Trois onglets du Duel** : **Libre** (banc d'essai actuel, g = 0,75, sans récompense),
  **Classé** (Ligue Bronze → Platine contre l'IA scriptée en build opti, profil `duel`, g = 0,5,
  un peu de maîtrise par victoire, titres de rang), **Panthéon** (cerveaux dans l'ordre, profil
  `duel_pantheon` = conditions d'entraînement).
- **Conflit P8 / E3.5** (copie de ton équipement ou niveau 10 sans équipement) : nous tranchons
  pour **E3.5**. La récompense (panoplie du Panthéon) reste un **vrai équipement** pour la Tour, les
  Donjons et le Duel libre, puisqu'elle ne sert pas au Panthéon lui-même (question au joueur de P8).
- **Ajusté** : nous **abandonnons les cerveaux aux étages 50 / 100 / 150 / 200 de la Tour** (M3) :
  ils y joueraient au niveau 25 à 100 sous `tour_duel`, des règles qu'ils n'ont pas apprises, et
  cela affadit le Panthéon. À la place : duelliste scripté **Hardcore** avec un modificateur (3.2).

### 3.7 Champ de bataille et Arènes

- Équilibrage a écrit un profil `champ` (E3.6) ; nous maintenons : **le 10v10 sort du menu** (19 IA,
  grande carte, objectifs inconnus du cerveau). Question au joueur maintenue (retirer ou « Siège »).
- Arènes 2v2 / 3v3 : **L, en dernier**, et seulement si le joueur le demande (question maintenue).

### 3.8 Tour : imbrications

- Reprise sans piège (M3) + paliers en x1 : d'accord avec E3.4 et P2 n°8. Cartes de départ : nous
  gardons **N ÷ 5 cartes, dont les sorts du preset** ; Équilibrage valide le N ÷ 5.
- Gains P5 : coffre du joaillier aux étages de boss (1re fois par difficulté), cristaux 2 + étage ÷ 20
  par étage (E8 : ~450 pour 1 → 100). Coffres d'apparence de palier **annoncés** (I9).
- Étages-épreuves : ils réutilisent les **épreuves** de la section 4 (même code que les événements de
  Survie).

---

## 4. Ajout n°4 (pilote) — mini-jeux et activités : version consolidée

### 4.1 Principe

Chaque activité ou mini-jeu a **un intérêt** (ce qu'il fait travailler), **une durée**, **un gain
propre** qu'aucun autre ne donne (P5) et **une condition d'ouverture** (P2) ; il réutilise un
système existant et passe par le socle (3.1). On écarte les mini-jeux hors combat (pêche, cuisine,
maison) sauf avis contraire du joueur : le jeu se juge au ressenti du combat.

### 4.2 Trois familles

**A. Activités du menu Jouer** (une page, un profil, un bilan)

| Activité | Rangée | Durée | Intérêt | Gain propre | Coût |
|---|---|---|---|---|---|
| Survie | Aventure | 35-45 min | le build qui grandit | insignes, fournitures de fortification | — |
| Donjons | Aventure | 10-12 min | mécaniques de boss, équipement synchronisé | pièces de panoplie ciblées, plans, éclats | M (+S plans) |
| La Tour | Aventure | par blocs de 10 étages | puissance du hub, endurance | joaillerie, cristaux, apparences de palier | S-M |
| Défi du jour | Défis | ~12 min | sortir de son build (classe imposée parmi 3, 2 modificateurs) | insignes ×1,5, cosmétique de rotation (7 défis) | S-M |
| Ruée des boss | Défis | ~12 min | les 8 boss pour eux-mêmes, au chrono | souvenir de boss (apparence ou titre), cristaux | S-M |
| Académie | Entraînement | 1-3 min par leçon | le geste (« hard to master ») | médailles, titres, cartes liées au geste | S-M |
| Duel libre / classé | Affrontements | 2-4 min | le 1 contre 1 | rangs, titres, un peu de maîtrise | M |
| Panthéon | Affrontements | 2-4 min | battre les cerveaux | panoplie du Panthéon, aura, titres | (P8, L) |
| Gantelet | Affrontements | ~3 min | 1 contre 2 puis 3 (IA scriptée) | titres | S-M |

**B. Épreuves** (mini-jeux de 30 à 90 s, une bibliothèque réutilisée à 3 endroits : événements de
Survie, étages-épreuves de la Tour, leçons de l'Académie)

| Épreuve | Règle | Ce qu'elle fait travailler | Coût |
|---|---|---|---|
| Prime | tuer l'élite marquée en moins de 60 s | dégâts sur cible unique | S |
| Course aux reliques | ramasser 5 reliques en 90 s | mobilité (saut, esquive aérienne) | S |
| Horde | survivre 45 s à une vague dense | zone, survie | S |
| Sol piégé | traverser / tenir sur les zones de `hazard.gd` | lecture des annonces au sol | S |
| Cristal à défendre | tenir 45 s près d'un cristal attaqué | placement (les monstres visent un objet) | M |
| Faille | petite salle d'un boss d'une autre époque | mécaniques de boss | S (réutilise la Ruée) |

Gain selon l'endroit : Survie → coffre de joaillier, cristaux ou coffre d'emplacement de rareté
supérieure ; Tour → pierres de polissage et de réforge ; Académie → médailles.

**C. Lieux de la Survie** (déjà 7 : enclume, scribe, fontaine, aimant, cupidité, stèle du défi,
autel de la fortune) + **Marchand masqué** (échange risqué : un trophée contre deux au hasard, S).

### 4.3 Ce qui change d'un jour à l'autre

Le **Défi du jour** (graine = date, `Run.seed`) est le seul renouvellement quotidien de la 1re vague ;
la table de modificateurs (3.2) permet plus tard un **Défi de la semaine** (3 maps, S) sans moteur
neuf. Pas de rotation de boutique de notre côté (P9 la porte).

---

## 5. Ce que nous ajustons ou abandonnons

| Tour 1 | Tour 2 |
|---|---|
| M0 socle à part de E1 | **fusionné** avec E1 (3.1), un seul coût M |
| Épreuves = tutoriel | **abandonné** : tutoriel dans la Survie (I1) ; les épreuves deviennent l'Académie |
| Une seule échelle PvpCaps pour la Tour | **remplacé** par le profil `tour_duel` d'E3.4 |
| Cerveaux aux paliers 50/100/150/200 de la Tour | **abandonné** (3.6) |
| Duel libre après 1 duelliste de la Tour | **abandonné**, P2 (3 duellistes) |
| Donjons ouverts seulement par le boss de leur zone | **ajusté** : époque II + condition par donjon |
| Donjons Normal / Héroïque / Mythique « niveaux plus hauts » | **chiffré** : palier d'époque, +15, 90 |
| Panthéon « niveau du cerveau ou plafonds JcJ » | **tranché** : conditions d'entraînement (E3.5) |
| 5 événements de Survie | **3 en premier** (Prime, Reliques, Faille) ; Cristal à défendre plus tard (M) |
| Durée de donjon 8-12 min | 10-12 min, boss 2-3 min |

---

## 6. Fiches des activités pour Interface (3 lignes + « Rapporte »)

| Activité | Fiche (3 lignes) | Rapporte |
|---|---|---|
| Survie | Pars sans rien, bâtis ton build carte après carte. 3 maps, 3 boss, une époque. Bats l'époque pour ouvrir la suivante. | Maîtrise, insignes, pièces pour l'Armurerie, fournitures |
| La Tour | Gravis 200 étages avec ton équipement et tes sorts. Une seule vie ; reprends depuis un palier de 10. Boss tous les 10 étages, duellistes tous les 3. | Joaillerie, cristaux, apparences aux étages 50 à 200 |
| Donjons | Un donjon d'Eden, 3 salles et son boss au complet. Ton équipement est ramené au niveau du donjon. Trois difficultés : Normal, Héroïque, Mythique. | Pièces de la panoplie du donjon, plans de fabrication |
| Défi du jour | Une map, une classe imposée, deux règles spéciales. Une tentative récompensée par jour. Change à minuit. | Insignes bonus, cosmétique de rotation |
| Ruée des boss | Les boss d'une époque à la suite, au chrono. Build accéléré : 6 cartes au départ, 3 entre deux boss. Une résurrection. | Souvenirs de boss, cristaux |
| Académie | Des leçons d'une à trois minutes sur les gestes d'expert. Bronze, argent, or. Les Premiers pas se rejouent ici. | Médailles, titres, cartes liées au geste |
| Duel | Libre : teste ton build. Classé : monte de Bronze à Platine. Règles du duel : soins réduits, acharnement après 30 s. | Rangs, titres, maîtrise |
| Panthéon | Affronte les cerveaux d'IA dans l'ordre, à armes égales (niveau 10, sans équipement). Seul ton jeu compte. | Panoplie du Panthéon, aura, titres |

---

## 7. Liste des propositions mise à jour (coût et ordre conseillé)

| Ordre | Proposition | Coût | Dépend de |
|---|---|---|---|
| 1 | **Socle M0 + E1** (fiche, `Modes.current`, profils aux valeurs actuelles, records gardés, test de la Tour) | M | E1, P2 (`unlocks.gd`), I2 |
| 2 | **Tour : reprise sans piège** (paliers x1, N ÷ 5 cartes dont le preset, carte de départ = sort) + `tour_duel` | S | E3.4 |
| 3 | **Académie** (contenu des leçons, médailles) | S-M | I1 couche 4, B7, P4 |
| 4 | **Table des modificateurs** commune | S | E, P6 |
| 5 | **Défi du jour** | S-M | 1, 4 |
| 6 | **Épreuves** : Prime, Reliques, Faille (Survie puis Tour) | S chacune | E (gains) |
| 7 | **Donjons** (version 3.5) | M (+S plans) | E4, P5, session locale (panoplies) |
| 8 | **Ruée des boss** | S-M | 1, Faille |
| 9 | **Tour : gains P5, trophées tous les 10 étages, étages-épreuves, boss renforcés** | S-M | P5, B, 6 |
| 10 | **Duel en 3 onglets** (Libre, Classé, puis Panthéon avec P8) | M (+L P8) | E3, P8 |
| 11 | Gantelet, Cristal à défendre, Marchand masqué, Défi de la semaine | S-M chacun | — |
| 12 | Arènes 2v2 / 3v3 | L | réponse du joueur |
| — | Champ de bataille 10v10 | retiré | réponse du joueur |

## 8. Questions au joueur (mises à jour)

1. **Donjons avec ton équipement, ramené au niveau du donjon** (avis commun Modes, Équilibrage,
   Progression) : d'accord ?
2. **Champ de bataille 10v10** : retirer, ou remplacer par un « Siège » JcE ?
3. **Arènes avec alliés IA** : importantes pour toi ? (plus gros chantier des modes)
4. **Défi du jour à classe imposée** (au choix parmi 3) : ça te plaît ?
5. **Mini-jeux hors combat** (pêche…) : en veux-tu ?

---

## Résumé (5 lignes)

1. **Socle unique** : notre M0 et le `mode_rules.gd` d'Équilibrage fusionnent en un bloc M à trois étages (fiche d'activité, `Modes.current` + script de mode, profil de chiffres), plus une table de modificateurs commune aux rangs héroïques, au Défi du jour et à la Tour.
2. **Tutoriel** : nous cédons à Interface (Premiers pas dans la vraie Survie) ; nos Épreuves de maîtrise deviennent l'**Académie** de la Zone d'entraînement (contenu Modes, affichage Interface).
3. **Donjons** : équipement synchronisé (E4), 12 sorts du preset, une carte par salle, Normal / Héroïque / Mythique = palier d'époque / +15 / 90, 10-12 min, ouverts à l'époque II puis donjon par donjon selon les boss battus en Survie.
4. **Duel** en 3 onglets (Libre g = 0,75, Classé g = 0,5, Panthéon en conditions d'entraînement) ; cerveaux retirés de la Tour, duels de la Tour sous `tour_duel` ; Champ 10v10 sorti du menu.
5. **Ajout n°4 consolidé** : 9 activités en 4 rangées, une bibliothèque de 6 épreuves courtes réutilisée en Survie, en Tour et à l'Académie, chacune avec son intérêt, sa durée et son gain propre ; ordre : socle → Tour sans piège → Académie → modificateurs et Défi du jour → épreuves → Donjons.
