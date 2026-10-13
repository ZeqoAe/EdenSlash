# Audit d'Eden Slash (version 0.1.33)

> **Tes réponses (13/10) sur les parties 1 à 5 sont appliquées** : voir « ✅ Décidé » dans
> chaque partie. Il reste les questions des parties 6 à 10.

But : repasser sur **tout ce qui existe** avant d'ajouter quoi que ce soit, pour que tu
choisisses quoi approfondir. Pour chaque partie : **comment ça marche aujourd'hui**, **ce que
j'ai mesuré ou repéré**, **ce que je propose**, et **les questions pour toi** (❓). Réponds
directement dans ce fichier ou dans le chat, partie par partie ; les sessions suivantes
s'en servent comme feuille de route.

Légende : 🔴 problème net (à corriger) · 🟠 à repenser (ton avis compte) · 🟢 sain.

---

## 0. Déjà corrigé dans cette session

- 🟢 **Aperçu du héros** (Apparence, Équipement, partout) : **molette = zoom**, **clic droit
  glissé = monter / descendre** (voir un chapeau ou des ailes de près), double-clic = cadrage
  d'origine. Le clic gauche glissé tourne toujours le héros.
- 🟢 **Équipement : clic sur une case de la poupée** (vide ou non) → l'inventaire ne montre
  plus que les pièces de cet emplacement, les meilleures d'abord. Une pastille « Tête ✕ »
  au-dessus de la grille revient à tout l'inventaire ; « Aucune pièce en stock » si vide.
- 🟢 Bilan chiffré en fin de run de test (`--quit-at` : niveau, butin par rareté, or, cartes…),
  utilisé pour les mesures ci-dessous.

---

## 1. Chronologie et progression entre les runs

**Aujourd'hui**
- On commence **Guerrier**. 5 classes de départ se débloquent par missions (250 monstres,
  soigner 4 000 PV, un coup de 800, 40 esquives, 15 élites) ; les 54 classes d'Eden se
  débloquent par la **maîtrise** de leur classe d'origine (vertes : maîtrise 2 à 8 de la
  classe de base ; orange : maîtrise 8 de la classe parente).
- **Maîtrise** : niveau 1 → 40, il faut 120 + 80 × niveau points ; une run rapporte
  niveau max × 15 + monstres / 2 + élites × 10 (+200 victoire, +60 extraction). Une run
  moyenne ≈ 400 à 600 points → la maîtrise 8 (classes orange) demande ~6 runs réussies.
- **Sorts** : 4 au départ, puis un nouveau sort aux maîtrises 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16.
- **Zones** : 8 zones à débloquer dans l'ordre (victoire sur le boss = zone suivante).

**Repéré**
- 🟠 Les classes d'Eden ont **14 à 20 sorts** : les derniers arrivent aux maîtrises 18 à 26,
  très loin. Une classe orange (débloquée à la maîtrise 8 de sa parente) repart de zéro.
- 🟠 Les missions des 5 classes de départ ne parlent pas d'Eden (« 800 dégâts en un coup »),
  alors que toutes les autres se débloquent par la maîtrise : deux logiques mélangées.
- 🟠 60 classes, mais rien n'oriente le joueur : quelle classe viser ensuite, laquelle est
  proche d'être débloquée.

**Proposition** : resserrer les paliers de sorts (tous débloqués vers la maîtrise 15) ; un
**arbre des classes** (familles, parent →
enfants) dans la page Classe avec la progression de chaque déblocage.

✅ **Décidé et fait (0.1.33)** : les 5 classes de base (Guerrier, Voleur, Chasseur, Clerc,
Magicien) sont jouables d'emblée ; Chevalier = Guerrier 3 ; Samouraï = Guerrier 3 **et**
Voleur 3 ; Inquisiteur = Chasseur 3 ; Barde = Clerc 3 ; Luminaire = Magicien 3 **et** Voleur 3 ;
Chevalier dragon = Chevalier **ou** Guerrier 5 ; Artiste martial = Samouraï ou Voleur 5 ;
Ingénieur = Inquisiteur ou Chasseur 5 ; Sage = Clerc ou Barde 5 ; Illusionniste = Luminaire ou
Magicien 5 ; Templier, Danseuse de lames, Rôdeur, Chaman, Démoniste = une des 3 classes
précédentes de la famille au niveau 7 ; classes éveillées (Berserker, Protecteur…) = maîtrise 8
de leur classe. Les missions (monstres, esquives…) ne débloquent plus de classe.
❓ J'ai compris « les 5 classes de base débloquées » comme **jouables dès le départ** : si tu
voulais qu'elles demandent aussi quelque chose, dis-le.

---

## 2. Déroulé d'une run

**Aujourd'hui** : 10 min d'exploration (montée de difficulté sur les 3 premières minutes),
puis la **rage** (monstres +3 niveaux, flux continu). Le donjon est scellé : **3 sceaux**
portés par les gardiens d'élite des camps. Boss à mécaniques. Fin : victoire, extraction
(10 s de canalisation, on garde tout) ou mort (on garde un objet).
Sur la carte : 10 coffres payants, 10 sanctuaires, 3 marchands ambulants.

**Mesuré** (pilote automatique, Wetlands, 92 s) : 91 monstres, **1 411 or**, 1 clé.
Limestone (run complète) : voir l'annexe A.

- 🔴 **L'or coule à flots** : 2 + niveau du monstre par monstre (+ ×3 pour une élite). À
  Wetlands, 1 400 or en 1 min 30, alors que les **10 coffres de la carte coûtent ~1 150 or
  au total**. Les coffres payants n'ont plus d'intérêt de choix.
- 🟠 Le plafond de niveau de chaque zone (Limestone 15, Wetlands 24…) fait que la fin de
  run ne fait plus monter le héros ; l'XP de la rage ne sert alors à rien.
- 🟠 10 min avant la rage, c'est long si on a déjà trouvé les sceaux ; il n'y a pas de
  raison d'aller au donjon tôt (ni bonus pour un boss vite tué).

**Proposition** : or par monstre divisé par ~4 et prix des coffres qui montent plus vite
(×1,5 par coffre) ; bonus de temps (« boss battu avant la rage : +1 coffre de récompense »).

✅ **Décidé** : l'or reste tel quel (marchands, améliorations) ; **le prix des coffres double à
chaque ouverture** (fait : 27 or, 54, 108… au niveau 1) ; 10 min puis la rage continue, pour
farmer l'expérience avant le boss si on veut.

---

## 3. Cartes : déblocage et offre

**Aujourd'hui** (0.1.30) : à chaque niveau, 3 cartes au choix (nouvelle compétence tant
qu'on n'en a pas 4 — une est forcée —, amélioration de sort, passifs de classe et cartes
communes). Rareté tirée à chaque carte (commune 60 %, rare 27 %, épique 10 %, légendaire 3 %),
passifs jusqu'au niveau 10, totaux avant → après. Aussi via coffres, sanctuaires, élites des
camps, marchands. 1 relance par run (+1 par Bonne étoile).

**Repéré**
- 🟠 Toutes les cartes sont proposées **dès la première run** : aucune carte ne se débloque
  avec la progression (la maîtrise débloque des sorts, pas des cartes). Pas de sentiment de
  découverte.
- 🟠 Les cartes de classe (« Corps aguerri »…) et les cartes communes sont mélangées sans
  distinction visuelle claire (seulement le sous-titre).
- 🟠 Sur 15 niveaux (plafond de Limestone), on voit ~45 cartes : avec 30+ cartes dans le
  pool et 10 niveaux chacune, un build ne se « construit » pas vraiment — on prend au hasard.
- 🟢 Le pilote automatique des tests ne prenait que des sorts : corrigé (il prend aussi des
  passifs, pour que les mesures voient des builds).

**Propositions** : débloquer les cartes par la maîtrise et la collection (comme Megabonk :
« vaincre 3 boss avec X » débloque une carte) ; **bannir** une carte pour la run ; une carte
« garantie » de sa classe tous les 5 niveaux ; icône de classe sur les cartes de classe.

✅ **Décidé et fait (0.1.33)** :
- **Méta-progression** : 12 cartes de base disponibles, les 18 autres se débloquent pour
  toujours par un exploit cumulé (500 / 1 000 / 2 500 monstres, 10 / 25 élites, 1 à 5 boss,
  5 coffres, 5 sanctuaires, niveau 12 atteint, un coup de 1 500 / 4 000, 50 / 150 esquives,
  5 000 PV soignés). Page **Héros > Cartes** : toutes les cartes, leur condition et leur
  avancement ; le bilan de fin de run annonce les cartes débloquées. Mode dev : « Débloquer
  toutes les cartes ».
- **Bannir** (la carte quitte la run, une autre la remplace) et **Garder** (la carte revient
  au choix suivant avec la même rareté) : 3 fois chacun par run, boutons sur chaque carte.
❓ Les exploits et seuils te conviennent ? (liste dans `scripts/core/cards.gd`, `UNLOCK`)

---

## 4. Équipement : génération en run et optimisation

**Aujourd'hui**
- Monstre normal : 5 % de chances de lâcher un objet (8 % en rage) ; élite : 1 objet
  (chance +0,3) ; boss : 3 objets + 1 mythique ou légendaire garanti.
- Rareté : commun 55 %, spécial 30 %, rare 15 % sur un monstre normal ; l'épique n'existe
  que sur élites et boss. Mythique / légendaire : boss et fabrication seulement.
- Chaque objet est un vrai objet d'Eden de la tranche de la zone (niveau d'Eden affiché),
  avec une **puissance** = niveau de run où il est tombé.
- Fin de run : mort = **un seul objet gardé** ; extraction = tout ; victoire = selon l'écran.

**Repéré**
- 🔴 **La puissance d'un objet garde le niveau de la run précédente.** On repart niveau 1,
  mais avec un équipement de puissance 15 à 36 : le début de chaque run devient trivial,
  et la progression de la run (niveaux, cartes) compte moins que l'équipement.
- 🟠 Les **affixes** (stats bonus aléatoires) ne s'appliquent plus aux objets d'Eden (ils ont
  leurs stats connues) : les communs à épiques se ressemblent tous, seule la qualité varie.
- 🟠 Aucun outil pour **comparer** vite : la carte au survol compare à la pièce portée, mais
  pas de flèches vertes / rouges sur les cases de l'inventaire.
- 🟠 Inventaire de run sans limite : aucune décision de tri pendant la run.
- 🟢 Chronologie des zones respectée (niveaux d'Eden), sets et passifs d'Eden.

**Propositions**
- Puissance des objets **ramenée au niveau du héros** en run (plafonnée : l'objet garde sa
  rareté, sa qualité, ses améliorations — son niveau suit le héros jusqu'à son niveau
  d'origine). L'équipement compte toujours, sans écraser la run.
- Petites flèches ▲▼ sur les cases (mieux / moins bien que la pièce portée).
- Bouton « équiper le meilleur » et « démonter les objets inférieurs ».

✅ **Décidé et fait (0.1.34)** :
- **Puissance d'un objet = niveau du héros de la run, plafonnée au niveau de l'objet** : un
  objet 23 n'évolue plus après le niveau 23, un objet 90 suit toute la run (objets de
  Limestone, niveaux d'Eden 1-13 : jusqu'au niveau max de la zone). Hors run : puissance
  maximale. La fiche indique « suit ton niveau en run jusqu'au niveau X ».
- **Améliorations (+N), gemmes et enchantements gardés** d'une run à l'autre.
- **Stats fixes** : plus de variation aléatoire des stats de base, seul le jet de qualité (%)
  change. **Pas d'affixes à la création** : une stat bonus aléatoire seulement aux paliers
  **+4, +6, +8, +10** (les autres niveaux : +10 % des stats). Rater un palier (redescendre)
  fait perdre sa stat bonus. **Réforger** relance la valeur d'une stat bonus (plus les stats
  de base).
- **Comparateur** : ▲ / ▼ sur les objets de l'inventaire et du coffre ; la fiche donne
  « ▲ Meilleur +12 % » avec le détail ; en run, un objet ramassé meilleur que la pièce portée
  s'annonce 8 s en bas de l'écran : **G** pour l'équiper (touche modifiable).
- 🔜 À faire ensuite : une monnaie ou un objet pour **redescendre d'un niveau d'amélioration**
  et retenter la stat bonus d'un palier.

---

## 5. Économie (or, clés, cristaux, coffres de récompense)

Tableau complet dans `DESIGN.md` (« Monnaies, coffres et zones »).

- 🔴 Or trop abondant (voir 2).
- 🟠 Cristaux : seulement en démontant ; réforger / polir en demande beaucoup — à mesurer
  sur une vraie partie (dis-moi si tu en manques ou en as trop).
- 🟠 Coffres de récompense : 0,6 % par monstre + boss + élites (15 %). Le menu Coffres est
  séparé du reste : on oublie de les ouvrir.

✅ **Décidé et fait (0.1.34)** : coffres de récompense sur **100 % des boss du donjon, 20 %
des élites, 0,5 % des monstres** ; ramassés, ils vont **tout de suite au menu Coffres** et ne
sont **jamais perdus**, même si la run échoue. **Seule source des mythiques et légendaires**
(coffre d'équipement : mythique, légendaire 20 % — 35 % sur un coffre de boss ; coffre de set :
3 pièces mythiques ou légendaires au choix). Les monstres lâchent l'équipement commun à épique
et les fournitures (ciseaux, gemmes, parchemins, pierres). Le boss ne lâche plus de mythique
au sol, les marchands ne fabriquent plus de mythiques, les sanctuaires donnent des trophées
jusqu'à épique.

---

## 6. Forge et joaillerie

Améliorer +1 → +10 (or, risque après +3), réforger et polir (cristaux), percer, sertir,
enchanter, fusionner des gemmes. Accessible par la fiche d'un objet (bouton Forge).

- 🟠 Beaucoup de systèmes empilés (5 actions, 3 monnaies, pierres de chance / protection) pour
  un jeu de runs courtes : on n'en utilise qu'une partie.
- 🟠 L'amélioration à risque peut frustrer sur un objet qu'on va remplacer dans 2 runs.

❓ Simplifier la forge (ex. amélioration sans échec, gemmes en bonus fixes) ou la garder
complète comme dans Eden ?

---

## 7. Collection, archive, apparences

- 🟢 10 554 entrées d'archive, catégories d'Eden, bonus permanents, trésors de collection.
- 🟢 Apparences : un modèle = une entrée, couleurs au choix (0.1.32), ailes « Blessed ».
- 🟠 Bonus d'archive : +1 / +2 attribut par entrée × 3 666 équipements = des **milliers de
  points** à terme : le bonus finira par écraser tout le reste.
- 🟠 Montures et familiers présents dans l'archive mais **pas jouables**.
- 🟠 Une trentaine de pièces sans nom ni icône (« Ailes et dos d'Eden X… »).

❓ Bonus d'archive : plafonné, ou seulement les paliers (10, 25, 50…) donnent des bonus ?
❓ Montures : utiles en run (vitesse hors combat) ou purement cosmétiques au lobby ?

---

## 8. Trophées

Trophée de départ + trophées à looter, buffs sous condition (familles agi, crit, double
frappe, carapace…), force selon la rareté.

- 🟠 19 familles mais beaucoup se ressemblent (+X % d'un attribut pendant 8 s).
- 🟠 Le trophée n'a pas d'effet visuel quand il se déclenche (juste un texte).

❓ Veux-tu des trophées plus « build » (ex. « chaque esquive lance une onde ») plutôt que
des buffs de stats ?

---

## 9. Interface (UI / UX)

Écran par écran (captures relues dans cette session) :

- **Lobby** : 🟢 clair (Jouer, Héros, Coffres, Collection, Paramètres, Quitter). 🟠 La
  « Prochaine récompense » est une barre vide sans chiffre ; le héros en fond est coupé
  par la carte « Héros : Guerrier ».
- **Héros > Équipement** : 🟢 maquette respectée. 🟠 Cases de l'inventaire sans comparaison
  ▲▼ ; « Puissance d'équipement » sans explication de ce qu'elle compte ; la fiche d'objet
  vide prend beaucoup de place tant que rien n'est choisi.
- **Héros > Apparence** : 🟢 zoom ajouté. 🟠 190 chapeaux en grille sans filtre ni
  recherche ; les verrouillés noient les débloqués (proposer « Débloqués uniquement »).
- **Collection** : 🟠 très dense ; pas de mise en avant de « ce qui est proche » (ex. set à
  1 pièce de compléter).
- **En run (HUD)** : 🟠 les **chiffres de dégâts se chevauchent** en foule (illisibles) ;
  l'objectif « Sceaux ◇◇◇ » est petit ; la barre d'XP du niveau est un pourcentage
  dans le cercle (peu visible). 🟢 FPS stables (0.1.29).
- **Choix de cartes** : 🟢 totaux avant → après. 🟠 Pas d'aperçu de ce qu'on a déjà
  (build actuel) pendant le choix.
- **Menu pause** : 🟠 la page Run liste les cartes en texte ; une vue « build » en icônes
  serait plus lisible.

**Propositions** prioritaires : chiffres de dégâts regroupés (cumul par cible, plus petits
pour les monstres normaux) ; filtre « Débloqués » + recherche dans Apparence ; flèches de
comparaison ; build actuel visible dans le choix de cartes.

❓ Quel écran te gêne le plus aujourd'hui ? (je commencerai par celui-là)

---

## 10. Technique et performances

- 🟢 Rage : ~65 FPS encerclé (0.1.29), plafond de monstres.
- 🟠 Dépôt GitHub : **1,3 Go** (assets d'Eden). Le rendre privé reste conseillé ; un nettoyage
  de l'historique réduirait la taille (opération délicate, à faire ensemble).
- 🟢 L'erreur « index hors limites » des tests venait d'un test de réforge (objet sans stat
  réforgeable) : corrigée avec les nouvelles règles.
- 🟠 Le pilote automatique des tests ne joue pas comme un humain (cartes, coffres) : les
  mesures d'équilibrage sont approximatives.

---

## Annexe A — mesures (pilote automatique)

- Limestone, Guerrier, départ : 114 s → niveau 3, 72 monstres, 279 or, 1 clé, 3 objets
  (2 communs, 1 spécial).
- Wetlands, départ niveau 12 : 92 s → niveau 13, 91 monstres, 1 411 or, 3 objets ; objet de
  niveau d'Eden 28 pour une puissance 14.
