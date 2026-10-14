# Équipe Progression & déblocages — concertation (tour 2, jeu 0.1.130)

Lu : `00_BRIEF.md`, notre `rapport_1.md` et les rapports Builds (B1-B13), Équilibrage (E1-E9),
Interface (I1-I9), Modes (M0-M7). Aucune vérification dans le code n'a été nécessaire : aucun
désaccord ne porte sur un fait du code, seulement sur des choix.

Notre ligne pour ce tour : **on renonce à ce qui fait doublon** (le Carnet devient la Collection
d'Interface, le Panthéon devient le haut de la Ligue de Modes) et **à ce qui ajoute de la puissance
permanente** (rangs de certificat). On garde le **contenu** : les conditions, les compteurs, les
succès, les gains par mode.

---

## 1. Réponses aux questions qui nous sont adressées

### Interface
1. **Fiche d'ouverture (P2) et fiche de tutoriel (I1) = un seul système : oui.** `core/unlocks.gd`
   (nous) dit *quoi* s'ouvre et *quand* ; `core/tutorial.gd` (Interface) dit *comment on le montre*.
   Chaque entrée de déblocage pointe vers l'identifiant de sa fiche. Une seule file d'affichage.
2. **Collection devient le Carnet : oui, et nous abandonnons notre entrée « Carnet » (P3).** Les
   onglets d'I6 (vue d'ensemble, succès et titres, classes, cartes et certificats, archive,
   statistiques) reprennent exactement les nôtres. **Armurerie dans l'Atelier** avec la Forge et la
   Réserve : oui, c'est même indispensable, puisque l'Armurerie s'ouvre dès le 1er bilan (voir 6.1).
3. **Médailles de l'Académie dans les succès : oui.** Elles forment la catégorie « Gestes » (voir 7).
   Médaille d'or = succès ; bronze et argent ne comptent que pour l'avancement.
4. **Forge : d'abord une entrée (Atelier), ensuite le verrou : oui.** Tant que l'Atelier n'existe pas,
   on ne verrouille pas la Forge (griser des boutons dans une fiche d'objet se verrait mal).

### Modes
1. **Chaque donjon s'ouvre quand son boss est battu en Survie : oui, mais à l'intérieur d'une activité
   qui s'ouvre plus tard.** Sinon les Donjons s'ouvrent dès la 1re run (le boss de la map 1 tombe
   souvent à la run 1), ce qui contredit la demande du joueur. Compromis en 2.1.
2. **Plans de fabrication : d'accord pour le partage.** Modes : où et à quel taux ils tombent.
   Progression : carnet de plans, fabrication, coût, place dans la collection (P10, section 5).
   Équilibrage : chiffres des coûts.
3. **Duel classé et Panthéon : oui, la Ligue remplace notre condition.** Le Panthéon s'ouvre au rang
   Platine. Nous retirons « étage 100 de la Tour » (deux chemins = deux conditions à expliquer).
4. **Records de la Tour, du Duel et des Défis comptent pour les cartes à débloquer et les succès :
   oui**, règle commune de M0 (corrige notre P1g).

### Builds
1. **Certificats : couche méta (plateau) et carte de run, on garde les deux**, avec des rôles nets :
   le plateau = ce que tu as débloqué et choisi ; la carte de run = **essayer** un certificat (y compris
   pas encore débloqué) pendant une run. Règles : une carte de certificat ne propose jamais un passif
   déjà posé (P1d) et la fiche le dit (« essai : se débloque à la maîtrise 3 de X »).
2. **Déblocages de build par la maîtrise, sans puissance : oui, et cela remplace nos rangs de
   certificat** (abandonnés, voir 4). Maîtrise 10 / 20 / 30 / 40 : choix et cosmétiques (section 6.3).
3. **Évolutions d'axe (B2) débloquées par des succès avec titre : oui.** Elles entrent dans la
   catégorie « Cartes » de la complétion ; le succès qui les ouvre est visible (pas caché).
4. **Couleurs des certificats** : votre règle B10 et notre P1c sont la même. Un seul bloc de code (le
   nôtre, P1c), avec votre table de stats.

### Équilibrage
1. **Plafond de méta en Survie (×1,6 à la maîtrise 20, ×1,8 au maximum) : accepté comme règle.** Il
   ne sert plus aux rangs de certificat (abandonnés), mais il borne talents + plateau + archive + aura.
   À vérifier par le journal (E6) ; si l'archive à 1 500 objets fait dépasser, on baisse ses paliers.
2. **Compteurs du journal (E6) et des succès (P4) écrits une seule fois : oui.** Liste commune en 7.3.
3. **Multiplicateurs des rangs héroïques (+12 % PV, +8 % dégâts par rang, insignes +15 %) : acceptés.**

---

## 2. Accords

| Sujet | Avec | Accord |
|---|---|---|
| Rien n'est caché, tout est grisé avec sa condition et son avancement | Interface I2, Modes | règle commune du fil d'éveil |
| Passer le tutoriel ne débloque rien | Interface I1 | déjà notre P2.4 |
| Sauvegardes existantes : rien n'est reverrouillé, ouverture sans fenêtre | Interface I1 | voir 6.1 (on le précise) |
| Zone d'entraînement (et l'Académie) ouverte d'emblée | Interface, Modes | oui |
| Un gain propre par activité (Survie : fortification ; Tour : joaillerie et cristaux ; Donjons : pièces ciblées et plans ; Duel : titres) | Modes M7, Équilibrage E8 | c'est notre P5, devenu la règle de tous les modes |
| Cristaux : ~2 + étage ÷ 20 par étage de Tour ; coût de la forge ÷ 3 jusqu'à +6 | Équilibrage E8 | oui ; condition pour que « tout amélioré à fond » ait un sens |
| Records gardés dans tous les modes | Modes M0 | oui |
| Débloquer = plus de choix, jamais plus de puissance brute | Builds §7 | oui ; nous l'appliquons à toute la méta nouvelle |
| Panthéon : conditions d'entraînement des cerveaux (niveau 10, sans équipement, poids de l'équipement 0) | Équilibrage E3.5, Modes M4 | oui, remplace notre « copie de ton équipement » |
| Cerveaux du Panthéon figés dans git | Modes | déjà notre P8 |
| Champ de bataille 10v10 retiré du menu | Modes M6 | oui ; il sort aussi de la table des déblocages |
| Bilan : époque débloquée, gardé / perdu, pièces découvertes, « Rejouer » | Interface I5 | c'est notre P1e, porté par Interface |
| Textes faux et vocabulaire unique | Interface I7 | notre P1f et P3 « vocabulaire » ; à faire ensemble |
| Codex des trophées découverts | Builds §7 | résout notre P1b (les trophées sortent de l'Armurerie) |

---

## 3. Conflits : position et compromis

### C1 — Quand s'ouvrent les Donjons (Modes : au boss de la zone ; nous : époque II)
- **Modes** : chaque donjon s'ouvre quand son boss est battu en Survie (3 donjons dès l'époque I).
- **Notre position** : le boss de la map 1 tombe souvent dès la 1re run ; les Donjons se jouent avec
  l'équipement du hub (option A de M2, E4), donc ils n'ont de sens qu'après la Forge et quelques achats
  à l'Armurerie. Les ouvrir avec la Forge et la Tour ferait trois ouvertures d'un coup.
- **Compromis** : l'**activité** Donjons s'ouvre à la fin de l'**époque II** ; **à l'intérieur**, chaque
  donjon est jouable si son boss a été battu en Survie (règle de Modes). À l'ouverture, le joueur a
  donc 4 à 6 donjons, et les suivants arrivent avec les époques III et IV. Variante si le joueur veut
  plus tôt : époque I terminée **et** étage 10 de la Tour.

### C2 — Le tutoriel : dans la Survie (Interface) ou par les Épreuves avant la 1re Survie (Modes)
- Pas notre domaine, mais le fil d'éveil en dépend (que voit-on à la 1re minute ?).
- **Position** : nous suivons Interface (les « Premiers pas » dans la 1re vraie Survie). Imposer
  6 épreuves avant de jouer retarde le cœur du jeu.
- **Compromis** : Académie (I1 couche 4) et Épreuves de maîtrise (M1b) = **la même activité**, ouverte
  d'emblée dans la Zone d'entraînement, **conseillée** (pastille) mais jamais imposée ; les Premiers
  pas cochés en Survie valident la médaille de bronze des épreuves correspondantes.

### C3 — Les cerveaux dans le Duel libre (Modes : en libre accès ; nous : réservés au Panthéon)
- **Modes** : le Duel libre garde le choix du cerveau (banc d'essai).
- **Notre position** : si le cerveau Hardcore est en libre accès dès la 1re heure, le « défi ultime »
  est déjà vu avant d'être gagné.
- **Compromis** : en Duel libre, **un cerveau est disponible une fois battu au Panthéon** (il devient
  partenaire d'entraînement) ; le Débutant l'est d'emblée. Le mode dev ignore la règle (banc d'essai
  des IA intact). « Le plus récent » reste un outil du mode dev.

### C4 — Récompense du Panthéon : vrai équipement (nous) ou titres et cosmétiques
- Le Panthéon se joue **sans équipement** (E3.5) : la panoplie ne sert pas là où on la gagne.
- **Position** : garder une **panoplie réelle**, utilisable en Tour et en Donjons (modes à équipement
  synchronisé), car c'est la demande du joueur (« débloquera leur équipement »).
- **Compromis** : bonus de panoplie **à effets** (archétype façon Builds B9) plutôt que de grosses
  stats, bornés par la synchronisation de niveau ; plus aura et titres. Question au joueur (9.3).

### C5 — Ouverture du Défi du jour (Modes : après la 1re run)
- **Position** : la 1re run ouvre déjà Classe, Cartes, Coffres, Collection et Armurerie ; un mode de
  plus le même soir dilue l'effet « nouveau ».
- **Compromis** : Défi du jour après **3 runs de Survie terminées** (quelle que soit l'issue). Comme il
  impose une classe débloquée, le joueur en a alors 1 ou 2 de plus.

### C6 — Duel après 3 duellistes de la Tour (nous) ou 1 (Modes)
- Nous prenons la version de Modes : **Duel libre au 1er duelliste battu, Ligue au 3e**. Plus lisible :
  « tu as gagné un duel dans la Tour, le Duel s'ouvre ».

---

## 4. Ce que nous ajustons ou abandonnons

| Proposition du tour 1 | Décision | Pourquoi |
|---|---|---|
| P3 Carnet de progression (entrée du lobby) | **abandonné comme écran** ; restent les **données** (objectifs les plus proches, statistiques) et le **vocabulaire** | Collection devient le Carnet (I6) |
| P7 rangs de certificat II et III (×1,5, ×2) | **abandonné** | puissance permanente en Survie ; principe Builds ; plafond E7 |
| P7 maîtrise 9 à 40 | **refait** : choix et cosmétiques (6.3) | Builds §7 |
| P7 rattrapage par famille | **gardé** (S) | rend la maîtrise 20 des 60 classes atteignable |
| P8 Panthéon (écran à part, accès Hardcore ou étage 100) | **fusionné** dans la Ligue (M4) ; on garde les récompenses, « un cerveau après l'autre » et les cerveaux figés | une seule échelle JcJ |
| P8 « fiche égale = copie de ton équipement » | **remplacé** par le profil `duel_pantheon` (E3.5) | le cerveau joue le jeu qu'il a appris |
| P2 Tour Difficile / Hardcore à 50 étages | **gardé**, avec les paliers de reprise de Modes (M3) | — |
| P2 Arènes « 10 duels gagnés » | **remplacé** par « rang Or de la Ligue » | une seule échelle |
| P1b trophées dans l'Armurerie | **réglé** : les trophées vont au codex des trophées (Builds §7) | — |
| P1g records de Tour et Duel | **déplacé** dans M0, mais à faire tout de suite en correctif S si M0 tarde | — |
| P9 autel de la fortune | **inchangé** : question au joueur | personne n'a tranché |
| P4 ~100 succès en 7 catégories | **élargi** à ~120 succès en 9 catégories | nouvelles activités (M1, M4, Académie) |

---

## 5. Imbrications et fusions

| Leur proposition | Se branche sur | Forme fusionnée |
|---|---|---|
| Interface I1 (fiches) + I2 (verrous, pastilles) | P2 fil d'éveil | `unlocks.gd` (conditions) → `tutorial.gd` (fiche) → `tip_panel.gd` (affichage) : un bloc « Déblocages et fiches » |
| Interface I3 (Atelier, barre de ressources, objectif suivant) | P2, P3, P9 | objectif suivant du lobby = fonction « 3 déblocages les plus proches » de P3 ; insignes et cristaux dans la barre |
| Interface I6 (Collection = Carnet) | P3, P4 | écran unique ; nous fournissons les données (catégories, complétion, succès, titres) |
| Interface I5 (bilan) | P1e, P4 | lignes « Débloqué : … » et « Succès : … » au bilan |
| Modes M0 (champ `unlock` de `Activities.LIST`) | P2 | le champ contient **l'identifiant** d'une entrée de `unlocks.gd`, pas la condition (une seule source) |
| Modes M1a/b/c, M2, M4 | P2, P4, P5 | chaque activité = une ligne du fil d'éveil, une famille de succès, un gain propre |
| Modes M2 plans de fabrication | P5, P9 | P10 ci-dessous : voie ciblée vers l'équipement **et** les apparences |
| Modes M3 gains de la Tour | P5 | identiques ; quantités E8 |
| Modes M4 Ligue → Panthéon | P8 | Bronze → Platine, puis 6 cerveaux ; récompenses de P8 |
| Équilibrage E1 (profils de mode) | P6 rangs héroïques | un rang = une surcharge du profil `survie` |
| Équilibrage E6 (journal) | P4, P11 | mêmes compteurs (7.3) |
| Équilibrage E8 (cristaux) | P5, « amélioré à fond » | sans le ÷ 3 jusqu'à +6, les panoplies à +10 restent irréalistes |
| Builds B2, B8, §7 (évolutions d'axe, trophées avancés, codex, grimoire des cartes, 3e variante) | P7, P4 | catégories « Cartes et trophées » et « Armes » de la complétion |
| Builds B10 | P1c | un seul bloc |

### P10 — Plans de fabrication (nouveau, notre part ; coût M, avec M2)
- **Carnet de plans** : onglet de la Collection. Un plan appris le reste ; il se **refabrique** au même
  prix (utile pour une 2e classe).
- **Fabrication** : Atelier, onglet Forge. Coût : éclats du donjon + cristaux + insignes (chiffres :
  Équilibrage). Pièce au niveau de la difficulté où le plan est tombé, +0.
- **Deux sortes** : plan de **pièce** (panoplie du donjon) et plan d'**apparence** (tenue ou arme d'Eden
  de la zone). Un plan déjà appris ne retombe pas : il devient des éclats.
- Compte dans la complétion (catégorie Équipement : « Plans 12 / N »).

---

## 6. Ajout n°2 consolidé — contenu débloqué au fur et à mesure (« fil d'éveil »)

**Principes communs** (Progression, Interface, Modes, Équilibrage)
1. Le cœur du jeu est ouvert d'emblée ; le reste s'ouvre **dans les 5 à 10 premières runs**, sauf la
   fin de jeu.
2. **Rien n'est caché** : verrou grisé, condition en 1 ligne, barre d'avancement (I2).
3. Chaque ouverture = une **fiche d'ouverture** au retour au lobby (jamais en run) + pastille
   « Nouveau » jusqu'à la 1re visite + ligne « Débloqué : … » au bilan.
4. Les conditions s'appuient sur des choses que le joueur **fait de toute façon** (finir une run, une
   époque, un duel de la Tour), jamais sur un travail à part.
5. On ne reverrouille jamais ; le mode dev ignore les verrous ; « passer le tutoriel » n'ouvre rien.

### 6.1 Table d'ouverture (version consolidée)

| Jalon | S'ouvre | Condition exacte | Fiche |
|---|---|---|---|
| **0. Nouvelle partie** | Survie (époque I), Zone d'entraînement + Académie / Épreuves, Héros (équipement, apparence, Grimoire), Guide (F1), Paramètres ; les 5 classes de base (choix de départ, I1 couche 0) | — | accueil (I1) |
| **1. Fin de la 1re run** (toute issue) | Héros > Classe (talents, parcours de maîtrise) ; Héros > Cartes ; **Collection** (vue d'ensemble, succès, statistiques) | 1 run de Survie terminée | « Ce que tu gardes » |
| | **Coffres** | 1er coffre de récompense ramassé | « Menu Coffres » |
| | **Atelier > Armurerie** | 1 pièce découverte | « Armurerie » |
| **2. Maîtrise 3 d'une classe** | Plateau des certificats | 1er certificat débloqué | « Plateau » |
| **3. Trois runs terminées** | **Défi du jour** (M1a) | 3 runs de Survie terminées | activité |
| **4. Époque I terminée** | **Atelier > Forge et Réserve** ; **La Tour** (Facile, Normal) | boss de la map 3 de l'époque I | 2 fiches, une fenêtre |
| **5. Dans la Tour** | **Duel libre** | 1er duelliste de la Tour battu (étage 1) | « Duel » |
| | **Duel classé (Ligue)** | 3 duellistes battus | « Ligue » |
| | Tour Difficile, puis Hardcore | 50 étages en Normal, puis 50 en Difficile | — |
| **6. Époque II terminée** | **Donjons** (chacun si son boss est battu en Survie) ; **Ruée des boss** (M1c) | boss de la map 3 de l'époque II | 2 fiches |
| **7. Ligue** | Gantelet (rang Or) ; Arènes 2v2 / 3v3 si elles se font (rang Or) ; **Panthéon** (rang Platine) | rangs de la Ligue | une par activité |
| **8. Époque IV terminée** | **Rangs héroïques** (P6) | boss de la map 3 de l'époque IV | « Rangs héroïques » |

Les **étoiles d'époque** (P6) sont visibles dès qu'une époque est ouverte : ce sont des objectifs, pas
un contenu. Classes vertes et orange : règles de maîtrise actuelles, inchangées.

### 6.2 Sauvegardes existantes (le joueur, époque II)
- À la 1re ouverture avec le fil d'éveil : tout jalon dont la condition est remplie s'ouvre **sans
  fenêtre**. En plus, **tout ce que le joueur a déjà utilisé reste ouvert** même si le compteur
  n'existait pas : Duel (si `duel_wins` > 0 ou un duel déjà lancé), Tour (si `tower_best` > 0), Forge
  (si une pièce du coffre commun a été améliorée). On ne demande pas de refaire un duel de la Tour.
- Une seule fenêtre récapitulative pour le contenu **réellement nouveau** (Collection refaite, succès,
  Atelier).

### 6.3 Le milieu de courbe : maîtrise 9 à 40 et runs 5 à 50
Sans puissance brute (principe Builds) :

| Maîtrise de la classe | Récompense |
|---|---|
| 10 | titre « Vétéran » de la classe ; cadre de badge |
| 15 | **emplacement de preset** en plus (Grimoire) |
| 20 (« Maître », compte pour la complétion) | **variante de signature** de lignée (Builds B4) si elle existe, sinon teinte d'aura de classe ; titre « Maître » |
| 30 | apparence d'arme de la classe (Eden) |
| 40 | variante dorée de la tenue de classe si les assets le permettent, sinon aura ; titre « Grand maître » |

- Toujours 2 points de talent par niveau (l'arbre ne se remplit jamais).
- **Rattrapage par famille** : maîtrise ×2 pour une classe tant qu'elle est sous une autre classe de sa
  famille, jusqu'à 20.
- **Déblocages de choix** (Builds §7) : évolutions d'axe par succès ; ~27 effets de trophée avancés
  ouverts par époques gagnées et succès ; 3e variante d'arme « de maître » plus tard (L).

**Coût global n°2** : M (table + verrous + migration) ; présentation S côté Interface (I2) ; dépend
d'Atelier (I3) pour la Forge et l'Armurerie.

---

## 7. Ajout n°5 consolidé — tout collectionner, succès et titres

### 7.1 Les catégories de la complétion (affichées par la Collection, I6)

| Catégorie | Unité comptée | Total (aujourd'hui → avec les ajouts) | D'où ça vient (Modes) |
|---|---|---|---|
| Classes | classe débloquée | 60 | maîtrise (tous modes) |
| Maîtrise | classe à la **maîtrise 20** | 60 (21 à 40 = titres de prestige, hors %) | tous les modes donnent de la maîtrise (M4 : le Duel classé aussi) |
| Cartes | carte débloquée | 49 → ~65 (évolutions d'axe B2, cartes B7/B8) | records de tous les modes, Épreuves |
| Certificats | certificat débloqué | 120 (codex par famille) | maîtrise 3 et 8 |
| Trophées | **effet** découvert (choisi une fois en run) | 67 (+ effets avancés) ; les 548 modèles = score à part | Survie, Tour (M3) |
| Armes | variante jouée jusqu'à son effet légendaire | 34 (→ 51 avec les variantes de maître) | Survie |
| Équipement | **panoplie** complète au coffre commun ou à l'archive ; « à fond » = succès « panoplie à +10 » | 154 + panoplies des Donjons + Panthéon ; plans | Armurerie, Donjons, Tour, Panthéon |
| Époques et Tour | étoiles (12) ; étage 200 par difficulté (4) | 16 | Survie, Tour |
| Activités | rangs de la Ligue, cerveaux (6), médailles d'or des Épreuves, donjons en Mythique (8) | ~30 | Duel, Académie, Donjons |
| Succès | succès obtenus | ~120 | partout |

**Scores sans fin, montrés à part** (pas dans le %) : apparences (paliers 50 / 200 / 500 / 1 000 /
2 000), archive (paliers actuels), modèles de trophées, rangs héroïques, maîtrise 21 à 40.

**Complétion globale** = moyenne des 10 catégories (chacune en %), affichée en tête de la Collection,
au pied du lobby et sur la carte de sauvegarde de l'écran titre (I6).

### 7.2 Succès et titres
- **~120 succès, 9 catégories** : Aventure (époques, étoiles, rangs héroïques) · Combat (records) ·
  Classes · Collection · Tour · **Défis** (défis du jour, chronos de la Ruée) · **Gestes** (médailles
  de l'Académie, annulations et enchaînements parfaits) · Duel, Ligue et Panthéon · Exploits (cachés).
- **Ce qu'un succès donne** : titre, apparence, cadre de badge, insignes, ou l'**entrée d'un choix** dans
  le jeu (évolution d'axe, trophée avancé). **Jamais de stat.**
- **Rétroactif** : à l'arrivée des succès, tout ce que les records existants justifient est accordé
  d'un coup, avec un seul bandeau « 23 succès obtenus ».
- **Titres** : un seul porté, choisi dans la Collection ; affiché sous le nom (badge du lobby, plaques
  de la Tour et du Duel, bilan, carte de sauvegarde ; pas dans le HUD : I6). Sources : succès, paliers
  de maîtrise (6.3), rangs de la Ligue, cerveaux, catégories complètes (« Archiviste », « Collectionneur
  de trophées »).
- **Seuils** : premières valeurs dans notre rapport (4.1), recalées sur le journal E6.
- **Technique** : `core/achievements.gd` (table de données + vérification sur `Profile.record_add` et
  en fin d'activité), `Profile.achievements`, `Profile.title`.

### 7.3 Compteurs communs (succès + journal E6 + cartes à débloquer)
Existants : kills, elite_kills, boss_kills, chests, shrines, dodges, healed, best_hit, best_combo,
breakables, duel_*, tower_best*, epochs_cleared. **À ajouter une seule fois** : victoires par époque,
par classe et par famille ; victoires sans résurrection ; étoiles ; sommets de la fortune ; enclumes
+9/+10 ; runs à 12 trophées ; annulations parfaites ; enchaînements parfaits (si B7) ; éliminations en
l'air ; dégâts sur la durée ; duellistes de la Tour battus ; rang de Ligue ; cerveaux battus ;
médailles d'Épreuve ; donjons par difficulté ; défis du jour réussis ; effets de trophée et variantes
découverts. Règle M0 : gardés dans **tous** les modes.

### 7.4 Ce qui rend « tout » atteignable
- Maîtrise 20 au lieu de 40 + rattrapage par famille : ~440 runs → environ 200 (à mesurer).
- Panoplie comme unité, plans de fabrication (cible), coût de forge ÷ 3 jusqu'à +6 (E8).
- Apparences : voies ciblées (boutique tournante d'insignes P9, plans d'apparence, souvenirs de la Ruée,
  rotation du Défi du jour, aura du Panthéon) ; le total reste un score.
- Grimoire des cartes avec retrait permanent (Builds §7) pour que débloquer ne dilue pas les offres.

**Coût global n°5** : M (données, compteurs, migration rétroactive) + M côté Interface (I6).

---

## 8. Liste des propositions mise à jour (ordre conseillé)

| # | Proposition | Coût | Avec | Ordre |
|---|---|---|---|---|
| P1 | Corrections de cohérence (réserve qui reste au hub, Armurerie sans trophées et `owned()` avec l'archive, couleurs des 120 certificats = B10, un passif posé une fois, bilan, vestiges) | S | I7, I5, B10 | **1** |
| P11 | Compteurs communs + records gardés partout (P1g) | S | E6, M0 | **1** |
| P2 | Fil d'éveil : `unlocks.gd`, verrous, migration des sauvegardes | M | I1, I2, I3 (Atelier d'abord), M0 | **2** |
| P3 | Données « objectifs les plus proches » + vocabulaire unique (l'écran = Collection I6) | S | I3, I6, I7 | 2 |
| P4 | Succès, titres, complétion (7) | M | I6, E6, Builds §7 | **3** |
| P5 | Gains par mode : coffre de forge garanti au boss de Survie (S) ; joaillerie et cristaux en Tour (S, avec M3 et E8) ; Donjons (avec M2) | S + S + — | M3, M2, E8 | 4 |
| P7′ | Milieu de courbe sans puissance (6.3), rattrapage par famille | S-M | B4, B2, B8 | 5 |
| P9 | Boutique d'apparences tournante (insignes) ; autel de la fortune selon le joueur | S | I3, E8 | 5 |
| P8′ | Panthéon au bout de la Ligue : récompenses, un cerveau à la fois, cerveaux figés dans git, cerveaux battus disponibles en Duel libre | M (notre part) | M4, E3.5 | 6 |
| P6 | Étoiles d'époque (S) puis rangs héroïques (M) | S + M | E1, E8, Modes | 7 (après le ressenti à l'époque II-IV) |
| P10 | Plans de fabrication : carnet, fabrication, coût | M | M2, E8 | 8 (avec les Donjons) |

Retirés : P3 comme écran, rangs de certificat (P7), accès au Panthéon par la Tour (P8).

---

## 9. Questions au joueur (mises à jour, l'indispensable)

1. **Ordre d'ouverture** (6.1) : Forge et Tour à la fin de l'époque I, Duel au 1er duelliste battu dans
   la Tour, Donjons à la fin de l'époque II : d'accord ? Ta sauvegarde garde tout ce que tu utilises déjà.
2. **« Toutes les classes au maximum »** = maîtrise 20 dans la complétion (21 à 40 : titres et
   cosmétiques de prestige), avec un rattrapage par famille : d'accord ?
3. **Cerveaux** : leur récompense est-elle un **vrai équipement** (utilisable en Tour et en Donjons) ou
   seulement **titres, aura et apparences** ?
4. **Autel de la fortune** : garder ses coffres d'équipement (seule pièce mythique qui sort de la
   Survie) ou les remplacer par des insignes et des apparences ?

---

## Résumé (5 lignes)

1. **Fusions** : notre Carnet devient la Collection d'Interface (vue d'ensemble, succès, titres, stats), nos fiches d'ouverture = ses fiches de tutoriel (`unlocks.gd` → `tutorial.gd`), notre Panthéon = le haut de la Ligue de Modes, joué dans les conditions d'entraînement des cerveaux (E3.5).
2. **Abandons** : rangs de certificat (puissance permanente) et écran Carnet ; la maîtrise 10-40 donne des choix et des cosmétiques (preset, signature, apparences, titres), jamais des stats.
3. **Ajout n°2 consolidé** : 9 jalons (1re run → Classe, Cartes, Collection, Coffres, Armurerie ; 3 runs → Défi du jour ; époque I → Forge, Tour ; 1er / 3e duelliste de la Tour → Duel libre / Ligue ; époque II → Donjons (chacun au boss battu) et Ruée ; Ligue Platine → Panthéon ; époque IV → rangs héroïques), tout visible et grisé, rien reverrouillé.
4. **Ajout n°5 consolidé** : complétion en 10 catégories (maîtrise 20, panoplies, effets de trophée, plans…) et scores sans fin à part, ~120 succès en 9 catégories, rétroactifs, sans stat ; compteurs écrits une fois avec le journal E6.
5. **Ordre** : P1 + P11 (S) → Atelier puis fil d'éveil P2 (M) → succès P4 (M) → gains par mode P5 → milieu de courbe, boutique → Panthéon → étoiles et rangs héroïques → plans de fabrication avec les Donjons.
