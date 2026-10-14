# Équipe Progression & déblocages — raffinement (tour 3, jeu 0.1.130)

Lu : `00_BRIEF.md`, `SYNTHESE_v1.md`, **`REPONSES_JOUEUR_1.md` (fait foi)**, notre `concertation_2.md`.
Vérifié dans le code : `core/fortune.gd:PRIZES`, `core/rewards.gd` (coffres d'apparence, raretés 0 à 5),
`core/run.gd:136-144` (expertise et insignes de fin de run), `data/eden_catalog.json` (6 888 objets de
collection, dont **242 auras** : 165 rares, 77 légendaires), `data/cerveaux/` (6 cerveaux).
Les chiffres marqués « (E) » sont des premières valeurs à recaler par Équilibrage avec le journal de run.

---

## 1. Table d'ouverture finale

### 1.1 Nouvelle partie (réponse 2)
- Accueil (Interface) puis **choix de la classe de départ parmi les 5 classes de base**, portraits
  côte à côte, aucune présélection imposée (Guerrier en surbrillance seulement).
- Les **5 classes de base sont toutes ouvertes** dès le départ : le choix ne verrouille rien, il dit avec
  quelle classe se joue la 1re Survie (et les Premiers pas). Les classes vertes et orange gardent les
  règles de maîtrise actuelles (`Progression.requirement`).

### 1.2 Les deux modes de duel (réponses 8 et 10)

| | **Duel « Arme seule »** | **Duel « Héros complet »** |
|---|---|---|
| Ce qui compte | ta classe, ses sorts (preset), **l'arme de la classe** (une des 2 variantes au choix), ton jeu | tout ton héros : équipement, arme secondaire, certificats, talents (points de maîtrise), aura, archive |
| Ce qui est neutre | équipement, talents, certificats, archive, aura (statistiques à 0, l'apparence reste) | rien ; les plafonds JcJ (`PvpCaps`) empêchent le « one-shot pour rien » |
| Niveau | **au choix de 1 à 90** en Libre ; **fixe à 10** en Ligue et au Panthéon | niveau du héros |
| Activités | Duel libre, **Ligue** (Bronze → Platine), **Panthéon** des cerveaux | Duel libre, **duels de la Tour**, Gantelet, Arènes (alliés IA) |
| Profil de règles (E) | `duel_arme` (= conditions d'entraînement des cerveaux au niveau 10) | `duel_heros` (= `duel` actuel ; les duels de la Tour s'y rangent) |
| Gain propre | rangs, titres, maîtrise (40 + 20 × rang, E), Panthéon | **seul endroit JcJ où ton équipement sert** : titres du Gantelet, maîtrise |

Pourquoi la Ligue et le Panthéon sont en « Arme seule » : réponse 10 (l'équipement ne compte **pas du
tout** en Ligue) et les cerveaux ont appris à jouer au niveau 10 sans équipement. Cela donne **une
seule échelle** Ligue → Panthéon dans un seul cadre. Le Héros complet donne enfin un usage JcJ à
l'Armurerie, à la Forge et à la panoplie du Panthéon.

Cible de durée (réponse 10, pour Équilibrage) : **ni interminable, ni mort en un coup**, au niveau 1
comme au niveau 90 : manche de 30 à 90 s, aucun coup (sort ou critique) ne retire plus de 35 % des PV
max d'un héros plein (à mesurer).

### 1.3 Table d'ouverture (réponse 1 : oui)

| Jalon | S'ouvre | Condition exacte |
|---|---|---|
| **0. Nouvelle partie** | Survie (époque I), Zone d'entraînement + Épreuves de maîtrise, Héros, Guide (F1), Paramètres ; 5 classes de base (choix de départ) | — |
| **1. Fin de la 1re run** | Héros > Classe et Cartes ; **Collection = Carnet** | 1 run de Survie terminée (toute issue) |
| | Coffres | 1er coffre de récompense ramassé |
| | Atelier > Armurerie | 1 pièce découverte |
| **2. Maîtrise 3 d'une classe** | Plateau des certificats | 1er certificat débloqué |
| **3. Trois runs** | Défi du jour (à maîtrise renforcée, 3.2) | 3 runs de Survie terminées |
| **4. Époque I gagnée** | Atelier > Forge et Réserve ; **la Tour** (Facile, Normal) | boss de la map 3, époque I |
| **5. Dans la Tour** | **Duel libre, les deux modes** | 1er duelliste de la Tour battu |
| | **Ligue (Arme seule)** | 3 duellistes de la Tour battus |
| | Tour Difficile, puis Hardcore | 50 étages en Normal, puis en Difficile |
| **6. Époque II gagnée** | Donjons (chacun si son boss est battu en Survie) ; Ruée des boss | boss de la map 3, époque II |
| **7. Ligue rang Or** | **Gantelet (Héros complet)** ; Arènes 2v2 / 3v3 avec alliés IA quand elles existeront | rang Or |
| **8. Ligue rang Platine** | **Panthéon (Arme seule)** | rang Platine (= victoire contre le Hardcore scripté) |
| **9. Époque IV gagnée** | Rangs héroïques | boss de la map 3, époque IV |

- Le Champ de bataille 10v10 **sort de la table** (réponse 6).
- En Duel libre, les cerveaux : le Débutant d'emblée, les autres **une fois battus au Panthéon** ; ils n'y
  sont proposés qu'en Arme seule (seul cadre où ils jouent bien). Le mode dev garde tout.
- **Ta sauvegarde** : rien n'est reverrouillé ; Duel (les deux modes), Tour et Forge restent ouverts ;
  la Ligue s'ouvre si tu as 3 victoires en Duel ou 3 duellistes battus ; une seule fenêtre « Nouveau
  dans cette version » (réponse 3).

---

## 2. Récompenses des cerveaux (réponse 9)

### 2.1 L'échelle
Débutant → Facile → Normal → Difficile → Hardcore → **Champion** (le cerveau « actuel », figé dans git
au moment de la sortie du Panthéon : `data/cerveaux/pantheon_*.json`). On n'affronte un cerveau
qu'après avoir battu le précédent. Combat en **Arme seule, niveau 10**, au meilleur de 3 manches.

### 2.2 La panoplie du Panthéon (« Panoplie des Esprits », nom à valider)
- **6 pièces** : arme, tête, torse, jambes, gants, bottes. **Une pièce par cerveau, à sa 1re victoire**
  (Débutant : bottes ; Facile : gants ; Normal : jambes ; Difficile : tête ; Hardcore : torse ;
  Champion : **arme**, du type de la classe jouée).
- Rareté **légendaire**, niveau = ton niveau le plus haut (ramenée au niveau du donjon ou de la Tour
  comme le reste). Bonus de panoplie à **2, 4 et 6 pièces**, **à effets** plutôt qu'en stats (Builds,
  façon archétype ; ex. 6 pièces : « une esquive parfaite renvoie ta prochaine auto-attaque en double »).
- **Où elle sert** : Tour, Donjons, Duel **Héros complet**, Gantelet, Arènes. Pas en Survie (départ sans
  équipement) ni en Arme seule. Elle compte comme une panoplie de la Collection (catégorie Équipement).
- **Pour les autres classes** : chaque pièce gagnée entre dans `Profile.seen_gear` → achetable à
  l'Armurerie pour toutes les classes (prix légendaire actuel), et l'arme pour tout type d'arme dès que
  le Champion est battu. Pas besoin de refaire le Panthéon 60 fois.
- **Version éveillée** : une pièce **s'éveille** quand son cerveau est battu avec une classe de chacun
  des **5 groupes de base** (une lignée Guerrier, une Mage, etc. : 5 victoires par cerveau, **30 en
  tout**). Pièce éveillée = rareté éveillée (comme l'Armurerie), bonus de panoplie à 6 pièces renforcé,
  apparence teintée. Objectif long qui fait jouer plusieurs classes, sans farm d'une seule.

### 2.3 Coffres d'apparence, titres, coffres d'auras

| Cerveau | 1re victoire | Coffre d'apparence | Coffre d'aura | Titre |
|---|---|---|---|---|
| Débutant | bottes | rare | — | « Éveillé » |
| Facile | gants | rare | — | « Apprenti des Esprits » |
| Normal | jambes | mythique | aura **rare** | « Duelliste des Esprits » |
| Difficile | tête | mythique | aura rare | « Briseur d'Esprits » |
| Hardcore | torse | légendaire | aura **légendaire** | « Fléau des Esprits » |
| Champion | arme | légendaire ×2 | aura légendaire + **aura exclusive du Champion** (teinte unique, hors collection d'Eden) | « Champion du Panthéon » |
| Chaque **éveil** de pièce (6) | pièce éveillée | — | aura d'une qualité de plus que la 1re (rare → légendaire) | — |
| Les 6 éveillées | — | — | — | « Maître des Esprits » (titre doré) |

- **Victoires suivantes** : la 1re victoire **avec une nouvelle classe** contre un cerveau déjà battu
  donne un coffre d'apparence d'une qualité de moins que la 1re (360 victoires possibles au total) ; les
  victoires répétées avec la même classe ne donnent que de la maîtrise. Pas de farm possible.
- **Coffre d'aura** (nouveau type dans `Rewards.TYPES`, comme `look_*`) : une aura de la collection
  **pas encore obtenue**, de la rareté annoncée (165 rares, 77 légendaires). Si tout est obtenu :
  insignes (E). Les auras ne s'additionnent pas (une seule portée), donc collectionner n'ajoute pas de
  puissance en Survie.
- **Total** : 6 pièces + 6 éveils, 7 coffres d'apparence de 1re victoire, 5 auras + 1 exclusive + 6
  auras d'éveil, 7 titres. Tout compte dans la Collection (catégorie Activités : 6 cerveaux + 6 éveils).

---

## 3. Autel de la fortune et défis à maîtrise renforcée

### 3.1 Autel de la fortune : insignes et apparences (réponse 12)
Même pyramide (`fortune.gd`, 8 étages, 1 chance sur 8 d'atteindre le sommet). **Plus de coffres
d'équipement ni de set.** Nouveaux gains (chaque gain remplace le précédent) :

| Étage | Chances d'y arriver | Gain actuel | **Nouveau gain** (E) |
|---|---|---|---|
| 1 | 7 / 8 | or ×1 | or ×1 (inchangé) |
| 2 | 6 / 8 | or ×1,5 + 2 clés | or ×1,5 + 2 clés (inchangé) |
| 3 | 5 / 8 | coffre de forge | **15 insignes** |
| 4 | 4 / 8 | forge + joaillerie | **30 insignes** + coffre d'apparence **commun** |
| 5 | 3 / 8 | équipement | **50 insignes** + coffre d'apparence **rare** |
| 6 | 2 / 8 | équipement + set | **80 insignes** + coffre d'apparence rare |
| 7 | 1 / 8 | set + équipement | **120 insignes** + coffre d'apparence **mythique** |
| 8 (sommet) | 1 / 8 | set + équipement + apparence dorée | **180 insignes** + coffre **légendaire** + apparence dorée (`summit_look`, inchangé) |

- Insignes × (1 + 0,25 × (époque − 1)) pour suivre le prix de l'Armurerie (30 + niveau à 250). Repère :
  une run gagnée à l'époque I rapporte déjà ~150 insignes (`run.gd:143`) ; un sommet vaut ~1 run.
- Les insignes de l'autel s'ajoutent à `Run.insignia_gain` (montrés au bilan sur leur ligne), gagnés
  même en cas de défaite ensuite (le gain est encaissé à l'autel).
- Conséquence : l'équipement mythique ne sort plus de la Survie que par l'**Armurerie** (fidèle au
  principe roguelite). Le texte de l'autel et la fiche du Guide changent.

### 3.2 Défis à maîtrise renforcée (réponse 7)
La maîtrise d'une classe = son **expertise** (`Profile.add_expertise`), gagnée en fin d'activité
(`run.gd:136` : niveau max × 15 + kills ÷ 2 + élites × 10 + bonus d'issue + 120 par map). Un défi ne
change pas ce calcul : il **multiplie le gain final** de la classe jouée.

| Défi | Règle | Multiplicateur d'expertise |
|---|---|---|
| **Défi du jour** | une map, **classe imposée au choix parmi 3**, 2 modificateurs | **×2** si réussi, ×1,25 si échoué |
| **Défi de la semaine** | 3 runs avec des classes d'**une famille imposée**, en n'importe quel ordre | ×1,5 sur chacune des 3 runs, puis un coffre d'apparence rare |
| **Contrat de classe** (permanent) | chaque classe sous la maîtrise 20 a un objectif affiché (« gagner une map sans résurrection avec le Paladin ») | ×1,5 sur la run qui le réussit, un contrat à la fois par classe |

Règles de compte :
- Multiplicateurs **cumulés avec le rattrapage par famille** (×2), mais le total est **plafonné à ×3**.
- Le bonus s'applique à l'expertise **de la classe jouée seulement**, jamais à une autre.
- Il est affiché au bilan sur sa ligne : « Expertise Paladin : +840 (défi du jour ×2) ».
- Les 3 classes du Défi du jour sont tirées **parmi tes classes débloquées sous la maîtrise 20**
  (sinon parmi toutes) : le défi sert à rattraper, pas à grossir la classe favorite.
- Le Duel donne aussi de la maîtrise (40 + 20 × rang de Ligue, E) dans les deux modes.

---

## 4. Plus tard (réponse 7) — hors des premiers lots

### 4.1 Creuset des apparences (fusion de cosmétiques)
**Idée** : les apparences en double ne deviennent plus seulement des cristaux ; on peut les **fondre**
pour tenter une apparence plus rare, **jamais déjà possédée**.

- **Où** : Atelier > Creuset (à côté de la Forge).
- **Ce qu'on fusionne** : des **doublons** seulement (un doublon reçu devient un « jeton d'apparence »
  de sa rareté et de sa catégorie au lieu de 30 cristaux ; l'ancien choix « cristaux » reste possible).
  On ne sacrifie **jamais** une apparence de sa collection : la collection ne fait que grandir.
- **Recette** : **3 jetons de même rareté** + un coût en insignes (E : 20 / 40 / 80 / 150 selon la
  rareté) → **une apparence pas encore possédée**. On peut cibler une **catégorie** (tenue, tête, dos,
  arme, aura) si les 3 jetons sont de cette catégorie.
- **Raretés** (celles d'Eden, `rarity` 0 à 5) : commun (1 219) → spécial (1 790) → rare (1 251) →
  épique (331) → mythique (641) → légendaire (1 656).

| Fusion de 3 jetons | Résultat de même rareté | Une rareté au-dessus |
|---|---|---|
| commun / spécial / rare / épique | 70 % | **30 %** |
| mythique | 80 % | **20 %** (légendaire) |
| légendaire | 90 % (légendaire) | **10 %** : apparence **dorée** |

- **Garde-fous contre la frustration** :
  - on gagne **toujours** quelque chose de nouveau (le « raté » est une apparence de même rareté que tu
    n'avais pas) ;
  - **compteur de chance** visible par rareté : +10 % à chaque fusion sans montée ; la **4e fusion
    sans montée monte d'office** (au plus 4 essais, comme la pitié des jeux de collection) ;
  - les chances sont **affichées avant de fondre** ; pas d'achat avec autre chose que des monnaies de
    jeu ; aucun jeton perdu si la catégorie visée est complète (on prévient et on rend les jetons).
- **Coût** M : jetons dans `Profile`, page du Creuset, tirage dans `rewards.gd:roll_look` (existe déjà
  avec rareté et « pas encore obtenu »). Compte dans le score d'apparences (hors %).

### 4.2 Les autres « trucs RNG » et le housing (esquisse)
- **Loterie de la semaine** : un ticket par run gagnée, tirage au lobby le lundi ; lots = apparences,
  jetons, insignes ; un lot garanti d'apparence rare au 5e ticket sans gros lot. Coût S.
- **Roue du Marchand masqué** (Modes) : une roue d'apparences contre de l'or de run. Coût S.
- **Housing « Salle des trophées »** : une pièce du hub où l'on expose ses panoplies (mannequins), ses
  armes archivées, ses titres et les 6 têtes des cerveaux vaincus ; vitrine de la collection, pas de
  stat. Coût L (décor, placement) ; à faire après le Carnet.
- Règle commune : **la RNG ne donne que des cosmétiques et des monnaies**, jamais de stat ni de pièce
  d'équipement (sinon elle concurrence l'Armurerie et les Donjons).

---

## 5. Complétion et succès mis à jour

### 5.1 Ce qui change depuis la concertation
- **Maîtrise 20** = « classe au maximum » (réponse 11) : catégorie Maîtrise = 60 classes à 20 ; 21 à 40
  = titres et apparences de prestige, hors pourcentage.
- **Signature par famille (20)** (réponse 13) : à la maîtrise 20 de **la 1re classe d'une famille**, la
  signature de la famille s'ouvre pour ses 3 classes. Nouvelle ligne dans la catégorie Armes :
  « Signatures 20 » (quand Builds B4 existera).
- **Pas de zone dorée ni de ralenti** (réponse 14) : on **retire** le compteur « enchaînements
  parfaits », les succès « Gestes » qui en dépendaient, la médaille et la carte de geste « zone
  dorée », et le multiplicateur de maîtrise par enchaînement. On garde : annulation parfaite, esquive
  au bon moment (sans ralenti), saut des ondes, éliminations en l'air.
- **Prise en main / mode auto** (sujet ouvert) : en attendant la décision, **aucun succès de la
  complétion n'exige le jeu manuel** ; les succès de gestes passent dans la catégorie **Exploits**
  (comptés dans les succès, mais un joueur en auto atteint 100 % des autres catégories). Le mode auto
  donne toute la progression, sauf en JcJ où il n'existe pas.
- **Cartes de classe fondues** (réponse 15) : 3 cartes de moins à débloquer, catégorie Cartes ~62.
- 10v10 retiré ; Arènes avec alliés IA gardées, comptées seulement quand elles existent.

### 5.2 Catégories de la complétion (version finale)

| Catégorie | Compté | Total |
|---|---|---|
| Classes | classes débloquées | 60 |
| Maîtrise | classes à la maîtrise 20 | 60 |
| Cartes | cartes débloquées (sans les cartes de classe) | ~62 |
| Certificats | certificats débloqués | 120 |
| Trophées | effets découverts | 67 |
| Armes | variantes jouées jusqu'à l'effet légendaire ; signatures de famille | 34 + 20 |
| Équipement | panoplies complètes (Eden, Donjons, **Panthéon**) ; plans | 154 + Donjons + 1 |
| Époques et Tour | étoiles d'époque, étage 200 par difficulté | 16 |
| Activités | rangs de Ligue (4), cerveaux (6) et éveils (6), médailles d'or des Épreuves, donjons en Mythique (8), Gantelet | ~32 |
| Succès | succès obtenus | ~115 |

Scores à part : apparences, auras (242), archive, modèles de trophées, rangs héroïques, maîtrise 21-40.

### 5.3 Succès : ajouts et retraits
- **Ajoutés** : Duel Arme seule au niveau 1 gagné ; Ligue Platine ; chaque cerveau ; chaque éveil ;
  « Maître des Esprits » ; Gantelet en Héros complet ; Défi du jour 7 jours de suite ; 10 contrats de
  classe ; sommet de l'autel (déjà prévu, sa récompense devient une apparence).
- **Retirés** : enchaînements parfaits (×3), zone dorée en Épreuve, ralenti / esquive parfaite en
  série. **~115 succès** au lieu de ~120.
- Compteurs communs à écrire une seule fois (concertation 7.3) : **sans** « enchaînements parfaits » ;
  **avec** victoires par mode de duel, cerveaux battus par classe (pour l'éveil), contrats réussis,
  jours de Défi du jour d'affilée, insignes gagnés à l'autel.

---

## 6. Liste finale de nos propositions (coût et ordre)

| Ordre | # | Proposition | Coût | Avec |
|---|---|---|---|---|
| 1 | P1 | Corrections de cohérence (certificats B10, passif posé une fois, réserve, bilan) | S | I7, I5, B10 |
| 1 | P11 | Compteurs communs + records gardés partout (sans enchaînements parfaits) | S | E6, M0 |
| 2 | P9a | **Autel de la fortune en insignes et apparences** (3.1) : changer `Fortune.PRIZES` | **S** | E, I (textes) |
| 3 | P2 | Fil d'éveil (1.3), choix parmi les 5 classes, migration de ta sauvegarde | M | I1-I3, M0 |
| 4 | P12 | **Deux modes de duel** : réglage Arme seule / Héros complet dans le Duel libre, niveau 1-90 | S-M (notre part S) | E (profils), M, I |
| 5 | P4 | Succès, titres, complétion (5) | M | I6, E6 |
| 6 | P13 | **Défis à maîtrise renforcée** : multiplicateur d'expertise plafonné ×3, Défi du jour, contrats de classe ; Défi de la semaine après | S (+ S) | M1a, I |
| 7 | P7′ | Paliers de maîtrise 10-40 sans puissance, rattrapage par famille, signatures par famille (avec B4) | S-M | B4 |
| 8 | P9b | Boutique d'apparences tournante (insignes) | S | I3, E8 |
| 9 | P8′ | **Panthéon** : 6 cerveaux figés, panoplie (6 pièces + éveil), coffres d'apparence, **coffres d'auras** (nouveau type), 7 titres | M (+ M Builds pour les effets de panoplie) | M4, E, B |
| 10 | P6 | Étoiles d'époque, puis rangs héroïques | S + M | E1, E8 |
| 11 | P10 | Plans de fabrication (avec les Donjons) | M | M2, E8 |
| plus tard | P14 | Creuset des apparences (fusion), loterie, roue, Salle des trophées | M / S / S / L | I, E |

Abandonnés ce tour : tout ce qui dépendait de la zone dorée ; coffres d'équipement de l'autel ;
cerveaux en Héros complet.

---

## Résumé (6 lignes)

1. **Ouverture finale** : 5 classes de base au choix ; époque I → Forge et Tour ; 1er duelliste → Duel libre (deux modes) ; 3e → Ligue ; époque II → Donjons ; Or → Gantelet et Arènes ; Platine → Panthéon ; époque IV → rangs héroïques ; 10v10 retiré.
2. **Deux duels** : « Arme seule » (arme de la classe, niveau 1 à 90 en libre, 10 en Ligue et au Panthéon, équipement à zéro) et « Héros complet » (tout le héros sous `PvpCaps` : duels de la Tour, Gantelet, Arènes), sans one-shot.
3. **Cerveaux** : une pièce de panoplie légendaire par cerveau (6), éveil en battant chaque cerveau avec les 5 groupes de base (30 victoires), coffres d'apparence rare → légendaire, auras (nouveau coffre d'aura, 242 auras), 7 titres ; victoires par nouvelle classe sans farm.
4. **Autel** : 15 à 180 insignes et coffres d'apparence commun → légendaire au lieu des coffres d'équipement (`Fortune.PRIZES`, coût S) ; **défis** : expertise ×2 (Défi du jour), ×1,5 (semaine, contrats), plafond ×3 avec le rattrapage.
5. **Plus tard** : Creuset qui fond 3 doublons en une apparence nouvelle (30 % de monter d'une rareté, pitié garantie au 4e essai, jamais de perte), loterie, roue, Salle des trophées ; la RNG ne donne jamais de stat.
6. **Complétion** : maîtrise 20, signatures par famille, sans zone dorée (compteurs et succès retirés), aucun succès de complétion n'exige le jeu manuel ; ordre : corrections → autel → fil d'éveil → deux duels → succès → défis → Panthéon.
