# Équipe Interface & menus — concertation (tour 2, jeu 0.1.130)

Lu : `00_BRIEF.md`, notre `rapport_1.md` et les rapports Progression (P1-P9), Builds (B1-B13),
Équilibrage (E1-E9) et Modes (M0-M7). Une seule vérification dans le code, pour la place du menu
Jouer (§3.3). Rien n'est codé ; nos numéros I1 à I9 renvoient au rapport 1.

---

## 1. Réponses aux questions qui nous sont posées

### Progression
1. **Où mettre le Carnet ? Où s'affiche le titre ?** Le Carnet **est l'écran Collection** (pas une
   entrée de plus dans le lobby) : onglets Vue d'ensemble (objectifs proches et complétion), Déblocages
   (le fil d'éveil P2), Succès et titres, Classes, Cartes et certificats, Archive, Apparences,
   Statistiques. Le titre porté s'affiche sous le nom dans le badge du lobby, sur la plaque du héros en
   Duel, en Tour et dans le Panthéon, sur l'écran de fin et sur la carte de sauvegarde de l'écran
   titre. **Pas dans le HUD de Survie** (il est déjà chargé).
2. **Activités verrouillées visibles, fenêtre « Nouveau » = fiche de tutoriel** : oui pour les deux.
   Un seul système d'affichage (`ui/tip_panel.gd`) qui lit deux tables : `core/unlocks.gd` (P2) et
   `core/tutorial.gd` (I1). Chaque ligne de `unlocks.gd` donne l'identifiant de sa fiche.
3. **Vocabulaire unique et insignes au lobby** : oui. « Maîtrise » (points, niveau), « points de
   talent », « coffre commun », « insignes », « cristaux », « fournitures ». Les insignes, les cristaux
   et les fournitures vont dans la **barre de ressources** du lobby (I3).
4. **Coffres d'apparence de la Tour annoncés** : oui, une icône de coffre sur les étages 50, 100, 150
   et 200 de la page des étages, avec « déjà obtenu » quand c'est le cas (voir §3.4).

### Modes
1. **Menu Jouer à 3 rangées + Entraînement : y a-t-il la place ?** Oui, mais **pas avec la grille
   actuelle**. Aujourd'hui (`lobby.gd:_menu_play`) : grille de 2 colonnes, cartes de 345 × 112, dans un
   panneau sans défilement qui commence à y = 196 (`lobby.gd:579`). Trois rangées de 2 colonnes
   feraient ~6 lignes de cartes (~900 px) et sortiraient de l'écran. On passe à **3 colonnes de cartes
   plus basses** (~230 × 100), une rangée par groupe, et l'Entraînement en bouton plat sous la grille
   (§3.3).
2. **Étiquette avec gain propre, durée, cadenas et condition** : oui. Sur la carte : le nom, la durée
   (« ~10 min ») en petit en haut à droite, le gain propre en une ligne en bas (« Joaillerie,
   cristaux »). Verrouillée : image grisée, cadenas, condition en une ligne, barre si chiffrable. Les
   champs viennent de la fiche d'activité de M0 (`gains`, `duration`, `unlock`).
3. **Médailles des Épreuves, classement personnel des Défis, rangs de la Ligue** : oui, voir §3.3 :
   médailles bronze / argent / or sur chaque ligne d'épreuve, record personnel et « nouveau record »
   sur la page du Défi et de la Ruée, échelle verticale de 5 rangs plus le Panthéon pour la Ligue.
4. **Retirer le Champ de bataille du menu** : oui. Un menu honnête vaut mieux que des cases grises.
   Les Arènes gardent **une seule** carte « Bientôt » (2v2 et 3v3 réunies), tant que le joueur n'a pas
   répondu sur M6.

### Builds
1. **Icône d'axe sur les cartes et trophées** : oui, 12 axes au plus, 24 px en haut à droite de la
   carte, la même icône dans la page Run du menu pause. Il faut 12 icônes lisibles en petit : nous
   proposons de les prendre dans les icônes de statut d'Eden déjà extraites, une couleur par axe.
2. **Résumé du build pendant le choix de cartes** : une colonne repliable **à gauche** du choix de
   cartes. Les fiches de tutoriel s'ouvrent **à droite** (et non plus à gauche comme dans le rapport
   1) : les deux peuvent être visibles en même temps.
3. **« Sans effet sur ton build » / « plafond atteint »** : bandeau gris en bas de la carte (B1).
4. **Zone dorée de l'enchaînement (B7)** : segment doré sur l'anneau de recharge de la case de sort
   (`hud_widgets.gd:SkillSlot`), à la **même place pour un sort donné** (position propre à chaque sort,
   donc fixe d'un appui à l'autre : le joueur l'apprend). Réussite : « PARFAIT » doré près du héros,
   comme « ESQUIVE ! ». Le texte du Guide le dit.
5. **Esquive parfaite défensive (B7)** : ralenti court, anneau blanc autour du héros, **sans
   assombrir l'écran** ni flou : la horde reste lisible.
6. **Fiche de classe (B11)** : 3 étiquettes de style et la signature (B4) dans le sélecteur de classe
   (`class_picker.gd`) et sur la fiche du choix de classe de l'accueil (I1, couche 0).
7. **Grimoire des cartes (bannissement permanent, Builds §7)** : un interrupteur « retirer de l'offre »
   sur chaque carte débloquée dans Héros > Cartes, avec le compteur « 3 / N retirées ».

### Équilibrage
1. **Où afficher les règles d'un mode ?** Sur la page de l'activité, un bloc repliable « Règles du
   mode » **généré à partir du profil E1** (« Soins reçus ×0,35 · acharnement après 30 s · équipement
   compté à moitié »), pour qu'il ne mente jamais. Le même texte forme le chapitre de l'activité dans
   le Guide. Pour la Survie : « Monstres : PV ×1,75, dégâts ×1,5 » sur chaque époque (E5).
2. **Niveau synchronisé d'une pièce (Tour, Donjon)** : dans l'infobulle de la pièce
   (« Synchronisée : 23 / 45 », en orange si elle décroche), et sur la page du Donjon un contrôle comme
   celui du Duel : « Ton équipement : puissance 38 / 45 ✘ · Régler ».
3. **Page « Modes » du mode dev** : oui, même présentation que la page Tour (nom, valeur, pas,
   « valeurs d'origine »).
4. **Prix du prochain coffre (E8)** : dans l'infobulle du coffre sur la carte et sur la grande carte
   (M) : « Coffre d'arme · 214 or (le suivant : 252) ».

---

## 2. Accords (sans réserve)

- **Corrections d'abord** : P1, B1, B10, E9 et notre I7 se font **ensemble**, car ils touchent les
  mêmes textes (`info_page.gd`, `chests_page.gd`, `lobby.gd`, `results_screen.gd`, `pause_menu.gd`,
  `activities.gd`, `duel.gd`). Un seul bloc de code « Textes justes et vestiges ».
- **Bilan de Survie** (P1e, I5) : époque débloquée, fournitures gardées ou perdues, pièces découvertes
  sans les trophées, branche « héritage » supprimée.
- **Réserve qui reste au hub** (P1a) : le bilan devient simple à lire (« fournitures de la run :
  gardées / perdues »), le menu pause aussi.
- **Fil d'éveil P2** : « jamais caché, toujours grisé », sauvegardes existantes sans reverrouillage,
  mode dev qui ignore les verrous.
- **Profils de mode (E1) et socle d'activité (M0)** : c'est ce qui rend l'interface honnête (règles
  et gains affichés depuis la donnée). Voir la fusion §4.4.
- **Champ de bataille retiré** (M6) ; **une seule règle de 1 contre 1** (E3.4) : l'aide n'aura qu'une
  explication du duel.
- **ZONE_DAMAGE limité à l'époque I** (E5) : il répond à notre question 1 à Équilibrage ; la 1re map
  de l'époque I reste la map d'apprentissage.
- **Journal de run (E6)** : aucun écran, rien à faire chez nous.
- **Plans de fabrication (M2, P5)** : d'accord sur le principe ; place dans l'interface en §4.3.

---

## 3. Conflits : position argumentée et compromis

### 3.1 Où se joue le tutoriel : dans la 1re Survie (I1) ou dans des Épreuves avant (M1b) ?
- **Modes** : les 6 premières Épreuves (déplacement, esquive, saut, auto-attaque, sort, enchaînement)
  se jouent **avant** la 1re Survie, dans la Zone d'entraînement.
- **Progression** (P2.4) : un tutoriel de run court, passable.
- **Équilibrage** : un profil « tutoriel » (dégâts ×0,4, pas de rage) pour la 1re map du 1er lancement.
- **Notre position** : apprendre **dans la vraie Survie**. Le joueur juge au ressenti et aime la
  Survie ; un débutant qui doit passer 6 épreuves avant de « jouer » décroche, et une épreuve
  chronométrée en arène vide n'apprend pas la pression d'une horde. Les Épreuves sont parfaites pour
  **aller plus loin** (le « hard to master »), pas pour la première minute.
- **Compromis retenu** :
  1. la 1re Survie **est** le tutoriel (Premiers pas, I1 couche 1), jouée sous le **profil
     « tutoriel » d'Équilibrage** (seulement la toute 1re run de la sauvegarde, tutoriels activés) ;
  2. les Épreuves de maîtrise (M1b) **remplacent notre « Académie »** (I1 couche 4, abandonnée sous
     ce nom) : ouvertes d'emblée, et proposées à l'accueil en 3e choix pour qui préfère s'échauffer ;
  3. les 6 premières Épreuves reprennent **les mêmes gestes** que les Premiers pas : une étape des
     Premiers pas déjà réussie en Épreuve est cochée d'office (et l'inverse ne donne pas de médaille).

### 3.2 Carnet : entrée du lobby (P3) ou Collection (I6) ?
Progression laisse le choix. Nous maintenons **Collection = Carnet** : moins d'entrées dans le menu,
et « tout collectionner » et « où j'en suis » sont la même question pour le joueur. L'Armurerie quitte
Collection pour l'**Atelier** (I3). Compromis pour Progression : l'onglet **Vue d'ensemble** s'ouvre en
premier et porte le nom « Carnet » dans son en-tête ; le cadre du bas du lobby (objectif suivant) y
mène d'un clic.

### 3.3 Présentation des nouvelles activités dans la page Jouer
Modes propose Aventure / Défis / Affrontements + Entraînement, avec Duel libre et Duel classé,
Gantelet, Ruée, Défi du jour. Si chaque idée devient une carte, la page passe à 11 cartes. Notre
règle : **une carte par activité que le joueur choisit ; les variantes vont dans la page de
l'activité**.

```
JOUER                                                   (3 colonnes, cartes ~230 × 100)
 Aventure      [ Survie ~40 min ]  [ Donjons ~10 min 🔒 ]   [ La Tour · par 10 étages 🔒 ]
 Défis         [ Défi du jour ~10 ] [ Épreuves de maîtrise ] [ Ruée des boss ~12 min 🔒 ]
 Affrontements [ Duel 🔒 ]          [ Arènes · Bientôt ]
 ─ Zone d'entraînement (bouton plat, bac à sable) ─
```

- **Duel** : une carte ; sa page a 3 onglets : **Ligue** (5 rangs, échelle verticale, adversaire
  suivant, « S'inscrire »), **Panthéon** (6 cerveaux en colonnes de portraits, grisés jusqu'au rang
  Platine), **Libre** (le Duel actuel, réglages et éditeur, sans récompense). Le Gantelet est une ligne
  de la Ligue à partir du rang Or. Les conditions ✔/✘ « Régler » restent en tête des 3 onglets.
- **Donjons** : une carte ; sa page liste les 8 donjons (image de zone, boss, panoplie, difficultés
  Normal / Héroïque / Mythique, ★ par difficulté battue). Un donjon verrouillé affiche « Bats
  <boss> en Survie ». La carte « Donjons » s'ouvre au 1er donjon débloqué (accord avec Modes : chaque
  donjon s'ouvre par son boss de Survie, ce qui est plus parlant qu'« époque II terminée »).
- **Épreuves de maîtrise** : liste par chapitre (Bases, Sorts, Esquive, Expert), médaille par ligne,
  « Rejouer », « Passer » sur les 6 premières.
- **Défi du jour** : classe et modificateurs du jour en tête, compte à rebours avant le prochain,
  record, 7 pastilles de la semaine (cosmétique de rotation).
- **Ruée des boss** : choix « époque I à IV » ou « les 8 », chrono record par classe.
- **Entraînement** : bouton plat sous la grille (c'est un outil, pas une activité à récompense).
- Les images : écrans de chargement d'Eden comme aujourd'hui ; il en faut 4 de plus (Donjons, Défi du
  jour, Épreuves, Ruée) à recadrer par la session locale.

### 3.4 La Tour : « Rejouer » et reprise
Notre question 3 à Modes restait ouverte. Avec les **paliers de reprise** de M3 (étages 1, 11, 21…),
« Rejouer » propose **le dernier palier atteint** (« Reprendre à l'étage 41 »), et la liste des étages
devient une liste de **paliers de 10** avec, par étage, une icône de type (vagues, élite, duelliste,
épreuve, boss, cerveau aux étages 50 / 100 / 150 / 200, coffre d'apparence). Pas de « Rejouer depuis
le record » s'il n'est pas un palier.

### 3.5 Classe de départ
Nous proposions le choix parmi les 5 classes de base ; Progression P2 garde les 5 ouvertes d'emblée
au lobby. Pas de vrai conflit : à l'accueil, le choix de classe se fait sur une fiche à 5 portraits
avec les étiquettes B11, et le Guerrier est présélectionné. Reste une question au joueur.

### 3.6 Fiche d'ouverture quand les tutoriels sont coupés
Progression ne dit rien des fiches « Nouveau » en mode « Aucun ». Nous gardons notre règle : elles
restent affichées (une fenêtre courte, « Y aller ») car elles annoncent du contenu, avec une case
« Aussi masquer les nouveautés ».

---

## 4. Imbrications et fusions

### 4.1 Tutoriel (I1) + Épreuves de maîtrise (M1b) + fil d'éveil (P2) + profil tutoriel (E1)
Quatre propositions, **un seul système** pour le joueur : voir la version consolidée en §6.
- Premiers pas (I1) = la 1re Survie, sous le profil « tutoriel » (E1).
- Épreuves de maîtrise (M1b) = la suite (le geste d'expert) et la reprise des bases.
- Fiches de découverte (I1) = les fiches d'ouverture du fil d'éveil (P2) **et** les fiches de 1re
  ouverture de chaque activité (texte tiré des champs M0 : intérêt, durée, gain).
- Guide (I1, couche 3) = toutes ces fiches relisibles, plus les règles de mode générées (E1).

### 4.2 Collection (I6) + Carnet (P3) + succès et titres (P4) + sources (Modes §4, ajout n°5)
- Collection devient le Carnet (§3.2). L'onglet **Succès et titres** lit `core/achievements.gd` (P4).
- Chaque catégorie de la Vue d'ensemble dit **d'où vient** ce qui manque, avec un bouton vers
  l'activité (table « À collectionner → vient de » de Modes) : « Apparences : boss de Survie,
  paliers de la Tour, Défi du jour, Ruée des boss, Donjons · [Jouer] ».
- Succès des Épreuves (médailles), de la Ligue (rangs), de la Ruée (chronos), des étoiles d'époque
  (P6) : une catégorie par activité, comme le propose Modes.
- Codex des trophées et des passifs (Builds §7) : deux pages de la catégorie « Cartes et certificats »
  (« trophées découverts 0 / 548 »).
- Complétion globale (P4.3) en tête, scores sans fin (apparences, archive) montrés à part.
- **Bandeau de succès** en run : en haut au centre, 3 s, **pas pendant un combat de boss ni en Duel**
  (il attend la fin de la manche) ; même file d'attente que les fiches de tutoriel.

### 4.3 Atelier (I3) + Forge du hub (P2 n°6) + plans de fabrication (M2, P5) + boutique d'apparences (P9)
L'Atelier rassemble **tout ce qui dépense** les ressources gardées :
- **Forge** (fortifier, gemmes, enchantements, réforge, polissage) : liste du coffre commun à gauche,
  page de forge à droite ; verrou P2 (époque I terminée) affiché sur l'onglet ;
- **Armurerie** (insignes) : sous-onglets Équipement et **Apparences** (la boutique tournante de P9) ;
  filtres et achat multiple (I9) ; les trophées n'y sont plus (P1b) ;
- **Fabrication** (plans des Donjons) : le carnet de plans, coût en éclats, cristaux, insignes ;
  onglet absent tant qu'aucun plan n'est obtenu (puis pastille « Nouveau ») ;
- **Réserve** : les fournitures gardées.
Les plans comptent aussi dans la Collection (Vue d'ensemble), mais on les **utilise** dans l'Atelier.

### 4.4 Page d'activité générée depuis M0 et E1
Chaque page d'activité suit le même gabarit, rempli par la fiche M0 et le profil E1 :
en-tête illustré (existant, `Activities.banner`) · « Rapporte : … » · durée · record · bloc
« Règles du mode » repliable · réglages propres · conditions ✔/✘ (modèle du Duel) · **Lancer**.
Une activité nouvelle n'a plus à écrire ces textes à la main.

### 4.5 Écrans de fin (I5) + gains par mode (P5) + Rejouer pour chaque activité
Un **composant de bilan commun** à toutes les activités (Survie, Tour, Duel, Donjon, Défis) : 3 blocs
(Ta partie · Gardé · Records), boutons « Rejouer » (règle propre à chaque activité : même époque ;
dernier palier de Tour ; même donjon et difficulté ; Défi du jour : seulement pour le score) et
« Lobby ». Le bloc « Gardé » lit les gains de l'activité (P5) : fournitures de fortification en
Survie, joaillerie et cristaux en Tour, pièces et plans en Donjon.

### 4.6 Lisibilité des builds (I8) + B1, B2, B3, B7 + E7
- B3 (effet légendaire acquis au niveau 4 de l'arme) : une **jauge d'arme** à 8 crans dans la page Run
  et sur la carte d'amélioration (« niveau 3 → 4 : effet légendaire ! »), plus la fiche de tutoriel
  « L'arme grandit » au 1er cran.
- E7 (Projectile supplémentaire normalisé) : la carte affiche le gain réel pour **ton** arme
  (« +50 % de dégâts d'auto-attaque pour Iaï »), calculé par `proj_gain`.

---

## 5. Ce que nous ajustons ou abandonnons

| Rapport 1 | Devient | Pourquoi |
|---|---|---|
| I1 couche 4 « Académie » (onglet Leçons de l'entraînement) | **abandonnée** au profit des Épreuves de maîtrise (M1b), activité de la rangée Défis | même idée, Modes la porte avec son moteur |
| I1 couche 0 : 2 choix à l'accueil | **3 choix** : « Je découvre » / « Je m'échauffe d'abord (Épreuves) » / « Je connais déjà » | intègre M1b sans l'imposer |
| I1 couche 1 : Premiers pas sur la map 1 « déjà adoucie » | sous le **profil tutoriel** (E1), seulement la 1re run | E5 réserve l'adoucissement à l'époque I ; le profil tutoriel isole le reste |
| I1 couche 2 : fiche à gauche du choix de cartes | **à droite** | la gauche va au résumé du build (B2) |
| I3 : Atelier = Forge, Armurerie, Réserve | + **Fabrication** (plans) et **Apparences** (P9) | §4.3 |
| I6 : Collection en 6 pages | 8 onglets (+ Déblocages, + Apparences), Vue d'ensemble nommée « Carnet » | P2, P3 |
| I2 : verrou de la Tour par difficulté non traité | Difficile / Hardcore de la Tour affichées avec cadenas et condition (P2 n°8) | P2 |
| I9 : menu Duel en 3 blocs | remplacé par la page Duel à 3 onglets (Ligue, Panthéon, Libre) | M4 |
| I9 : icône de coffre d'apparence sur les étages | élargie : icône de **type** pour chaque étage, liste par paliers de 10 | M3 |

Nous **gardons** sans changement : I4 (Coffres), I5 (bilan, étendu en §4.5), I7 (textes), I8.

---

## 6. Ajout n°1 — Tutoriel passable : version consolidée (pilote Interface)

**Avis intégrés** : Progression (P2.4 : court, passable, passer n'ouvre rien, tout relisible), Modes
(M1b : les Épreuves enseignent ; une fiche par activité ouverte), Équilibrage (profil tutoriel),
Builds (textes des armes, enchaînements, zone dorée).

### 6.1 Principes (inchangés)
On apprend en jouant la vraie Survie ; **jamais de fenêtre bloquante en combat** ; une chose à la fois,
au moment où elle sert ; passer à tout moment ; **passer ne débloque rien et ne bloque rien** ; tout se
relit dans le Guide (F1).

### 6.2 Les 5 morceaux

| # | Morceau | Pour qui | Contenu | Coût |
|---|---|---|---|---|
| 0 | **Accueil** (nouvelle partie) | tous | 3 choix : *Je découvre* (Premiers pas + fiches) · *Je m'échauffe d'abord* (ouvre les Épreuves, Bases) · *Je connais déjà* (tutoriels coupés) ; puis la classe de départ (5 portraits, étiquettes B11, Guerrier présélectionné) | S |
| 1 | **Premiers pas** | « Je découvre » | 10 étapes cochées en jouant pendant la 1re Survie (tableau du rapport 1, I1 couche 1, inchangé), panneau sous les objectifs du HUD, « Passer » dans l'en-tête ; 1re run sous le **profil tutoriel** (dégâts des monstres ×0,4, pas de rage : valeurs E1) | M |
| 2 | **Fiches de découverte** | « Je découvre », et les nouveautés pour tous | ~40 fiches de 3 lignes à la 1re rencontre (liste du rapport 1), **dont les fiches d'ouverture du fil d'éveil P2** et la fiche de 1re ouverture de chaque activité (intérêt, durée, gain, depuis M0) | M (surtout de l'écriture) |
| 3 | **Guide** (F1, remplace la page Aide) | tous | chapitres Commandes · Combat · Cartes · Survie · Hub · Activités (règles générées des profils E1) · Formules ; chaque fiche y est relisible ; contenus verrouillés en « ??? — se débloque : … » | S-M |
| 4 | **Épreuves de maîtrise** (M1b, porté par Modes) | tous, à tout moment | Bases (6 épreuves = gestes des Premiers pas), puis Sorts, Esquive, Expert (annulation parfaite, zone dorée B7, esquive parfaite) ; médailles ; « Passer » sur les Bases | M (Modes) |

### 6.3 Ce qui s'ouvre quand (lien avec le fil d'éveil P2)
Le joueur qui découvre voit, dans l'ordre : Accueil → Premiers pas pendant la 1re Survie → bilan
(fiche « Ce que tu gardes ») → lobby : fiches d'ouverture des talents, des cartes, du menu Coffres, de
l'Armurerie (P2 n°1-4) → au fil des runs : plateau des certificats, puis à la fin de l'époque I la
Forge (onglet de l'Atelier) et la Tour, puis le Duel, les Donjons… Chaque ouverture = **une fiche**
au retour au lobby, jamais en run ; plusieurs ouvertures d'un coup = une seule fenêtre avec la liste.

### 6.4 Comment on passe
- Accueil : « Je connais déjà ».
- En-tête des Premiers pas et menu pause pendant la 1re run : « Passer les Premiers pas ».
- Chaque fiche : « Compris », « Plus de détails » (Guide), « Ne plus afficher de conseils ».
- Paramètres > Interface : **Tutoriels : Complets / Conseils seulement / Aucun**, case « Aussi masquer
  les nouveautés », bouton « Revoir tous les tutoriels ».
- Passer ne change ni le fil d'éveil, ni les médailles. Le profil tutoriel suit les Premiers pas :
  les passer rend la Survie normale **à la map suivante**, jamais en plein combat.

### 6.5 Affichage en run
Jeu déjà en pause (cartes, coffre, fortune, bilan) : la fiche s'ouvre à droite de la fenêtre. Jeu en
action : pastille « Nouveau conseil : Enclume [F1] » 4 s dans le fil du HUD, fiche au prochain moment
calme (pas de monstre à ~15 m pendant 3 s) ou à la prochaine pause ; **jamais en combat de boss, en
Duel, en Défi chronométré ni en Épreuve**. Une seule fiche à la fois (file commune avec les succès).

### 6.6 Sauvegardes existantes (le joueur) et nouveautés
Au 1er chargement d'une sauvegarde avec des runs : tutoriels sur « Aucun », fiches marquées vues sauf
celles des **contenus nouveaux** (Guide, Atelier, Carnet, succès, Épreuves, Défis, Donjons…), fil
d'éveil ouvert selon P2.3 (rien de reverrouillé), et une seule fenêtre « Nouveau dans cette version »
qui liste ces contenus avec « Y aller ». C'est aussi l'outil du joueur pour tester chaque version.

### 6.7 Données et points d'appel (pour le découpage)
- `core/tutorial.gd` : fiches (id, chapitre, titre, texte avec touches `{jump}`, image, déclencheur,
  page à ouvrir, priorité, version d'apparition) ; `Tutorial.event("enclume")`.
- `core/unlocks.gd` (Progression) : chaque ouverture renvoie l'id de sa fiche.
- `Profile.tips_seen`, `Profile.first_steps` (étapes cochées), `Settings.interface.tutorials`.
- Signaux du héros à ajouter (`player.gd` : saut, esquive, sort lancé, enchaînement, annulation
  parfaite), **sans toucher aux observations de l'arène d'IA**.
- Profil `tutoriel` dans `core/mode_rules.gd` (Équilibrage, E1).
- Un seul composant d'affichage `ui/tip_panel.gd` (lobby et run) ; le Guide dans `info_page.gd`.
- Tests et mode dev (`--autoplay`, captures, bancs d'essai E6) : tutoriels coupés d'office.

### 6.8 Ordre de réalisation
I7 (textes justes) → Guide → `tip_panel` + `tutorial.gd` avec les fiches d'ouverture (en même temps
que `unlocks.gd`) → Accueil → Premiers pas + profil tutoriel (après E1) → Épreuves (Modes, après M0).

---

## 7. Liste des propositions mise à jour (ordre conseillé)

| Ordre | Proposition | Coût | Dépend de | Bloc commun avec |
|---|---|---|---|---|
| 1 | **I7** Textes justes, F5-F8 réservés au mode dev, vocabulaire unique | S | — | P1, B1 (mentions), E9 |
| 2 | **I5** Bilan commun (gardé / perdu, époque débloquée, Rejouer), code « héritage » supprimé, texte d'abandon par mode | S-M | P1a, P1e, P1f | P1 |
| 3 | **I4** Coffres lisibles : aperçu et niveau, « Ouvrir tout » + récapitulatif, plus de pièce possédée proposée | S | P1b | — |
| 4 | **I1 couches 2-3** Guide F1 + fiches de découverte et d'ouverture (`tip_panel`, `tutorial.gd`) | M | I7, P2 (`unlocks.gd`) | P2 |
| 5 | **I2** Verrous visibles, pastilles « Nouveau », fenêtre d'ouverture | S | P2 | P2 |
| 6 | **I3** Lobby rangé : barre de ressources, objectif suivant, **Atelier** (Forge, Armurerie, Fabrication, Réserve), Guide, « Relancer » | M | P2 (verrou de la Forge), P3 | P9 (apparences) |
| 7 | **I1 couches 0-1** Accueil à 3 choix + Premiers pas sous profil tutoriel | M | E1, signaux du héros | E1 |
| 8 | **Page Jouer refaite** (3 colonnes, cartes à durée, gain, cadenas ; page d'activité générée M0/E1) | S-M | M0, E1 | M0 |
| 9 | **I8** Lisibilité des builds : icônes d'axe, résumé, « sans effet », jauge d'arme, gain réel du projectile, zone dorée, esquive parfaite, prix du prochain coffre | S chacune | B1, B2, B3, B7, E7, E8 | Builds |
| 10 | **I6** Collection = Carnet (Vue d'ensemble, Déblocages, Succès et titres, Classes, Cartes, Archive, Apparences, Statistiques), titres, bandeau de succès | M | P3, P4 | P4 |
| 11 | **I9** Confort : Armurerie filtrée et achat multiple, forge grisée en Survie, Tour par paliers avec icônes de type, grimoire des cartes | S | M3, Builds §7 | — |
| 12 | Pages des nouvelles activités : Duel (Ligue, Panthéon, Libre), Donjons, Épreuves, Défi du jour, Ruée | S-M chacune, avec leur mode | M1, M2, M4, P8 | Modes |

---

## 8. Questions au joueur (mises à jour, l'indispensable)

1. **Tutoriel** : d'accord pour apprendre dans ta 1re vraie Survie (10 étapes cochées en jouant,
   monstres plus doux pendant cette seule run), avec des Épreuves de maîtrise à côté pour s'échauffer
   ou aller plus loin ? Tout se passe d'un clic.
2. **Nouvelle partie** : choisir sa classe parmi les 5 de base dès le départ, ou toujours le Guerrier ?
3. **Lobby** : d'accord pour une entrée **Atelier** (Forge, Armurerie, plans, réserve) et pour que
   **Collection** devienne ton Carnet (complétion, succès, titres, objectifs) ?
4. **Nouveautés** : une fenêtre « Nouveau dans cette version » au 1er lancement d'une version qui
   ajoute un système, ça t'aide à tester ?

---

## Résumé (5 lignes)

1. **Tutoriel consolidé** (pilote) : accueil à 3 choix, la 1re Survie sert de tutoriel (10 Premiers pas, profil « tutoriel » d'Équilibrage), fiches à la 1re rencontre qui sont aussi les fiches d'ouverture du fil d'éveil (P2), Guide F1 ; les Épreuves de maîtrise de Modes remplacent notre Académie ; passer ne débloque rien.
2. **Conflit principal tranché** : pas d'épreuves obligatoires avant la 1re Survie (le joueur aime la Survie et juge au ressenti) ; les Épreuves restent ouvertes d'emblée et cochent les Premiers pas déjà réussis.
3. **Fusions** : Collection = Carnet (succès, titres, complétion, sources de chaque objet) ; Atelier = tout ce qui dépense (Forge, Armurerie avec apparences, Fabrication des plans, Réserve) ; bilan commun à toutes les activités avec « Rejouer ».
4. **Page Jouer** : vérifiée dans le code, la grille actuelle (2 colonnes, sans défilement) ne tient pas 3 rangées ; passage à 3 colonnes (Aventure, Défis, Affrontements), une carte par activité (Duel = onglets Ligue / Panthéon / Libre), durée, gain et cadenas lus dans M0, règles du mode générées depuis E1, Champ de bataille retiré.
5. **Ordre** : I7 → I5 → I4 → Guide et fiches → verrous → Atelier et lobby → accueil et Premiers pas → page Jouer → I8, I6, I9, pages des nouvelles activités.
