# Équipe Builds & identité de combat — concertation (tour 2, version 0.1.130)

Lus : `00_BRIEF.md`, notre `rapport_1.md`, et les rapports 1 de Progression (P1-P9), Équilibrage
(E1-E9), Interface (I1-I9) et Modes (M0-M7). Aucun désaccord n'a demandé de vérification dans le code :
les chiffres cités par les autres équipes recoupent les nôtres (Projectile supplémentaire ×2 à ×4,
Élan meurtrier sans recharge interne, trophées « à l'impact », 108 certificats bleus).

---

## 1. Réponses aux questions qui nous sont adressées

### 1.1 Équilibrage

| # | Question | Réponse Builds |
|---|---|---|
| 1 | `proj_gain` par variante (E7), rareté qui ajoute des dégâts plutôt que des projectiles, plafond +4 | **D'accord sur les trois.** Cela remplace notre B3 « normalisation » et notre B13 ; nous gardons seulement que la carte légendaire de Projectile supplémentaire reste désirable (+30 % de dégâts d'auto-attaque, c'est suffisant). Le plafond +4 compte cartes **et** Tempête d'acier ; l'évolution doit donc donner autre chose qu'un projectile au-delà du plafond (perforation +1 par exemple). |
| 2 | Recharge interne 5 s des trophées « à l'impact » (Double frappe 1 s), chance ×1,5 | **D'accord.** Aucune identité ne repose sur un buff permanent en horde ; l'identité « zone » garde Lame large, explosions et procs. Demande : afficher la recharge sur la carte du trophée (« toutes les 5 s au plus »), sinon le joueur croit à un bogue. |
| 3 | Correction physique / magique (B5) sans compensation, puis journal E6 | **D'accord.** Les 20 classes concernées sont aujourd'hui sous-dosées (sorts sur une base 2,2 fois plus faible) : la correction les ramène au niveau de leur classe sœur, elle ne crée pas de classe trop forte. Profils « opti » à régénérer, puis `IA_Duel.bat`. |
| 4 | Effets sur la durée non cumulables (un par type et par cible) | **D'accord, on garde.** L'axe Durée se renforce par la **durée et la puissance** (Plaies profondes, Venin tenace) et par les finisseurs qui **consomment** l'effet (signatures B4), pas par le cumul. À écrire dans le Guide (I1) pour que le joueur le sache. |
| 5 | Budget d'un certificat ≈ 3 cartes communes de la même stat ; à effet ≈ une carte rare au niveau 3 | **D'accord**, avec une nuance : les certificats d'une même lignée (parent, 2 enfants) doivent être **différents** (B10) ; le budget s'applique à chacun. Les 11 « insensible aux renversements » : coder l'effet (rare en Survie, utile en Donjon) plutôt que retirer le texte. |
| E3 | Combos d'états ×1,5 en JcJ au lieu de ×2 | **D'accord** (c'était notre proposition) : champ `combo_mult` du profil de mode (E1). |

### 1.2 Progression

| # | Question | Réponse Builds |
|---|---|---|
| 1 | Règle de couleur des certificats (P1c) et un passif posé une seule fois (P1d) | **D'accord, c'est notre B10.** Nous fusionnons : la règle de couleur est celle de P1c, plus « zone » et « portée » en bleu. P1d est juste : aujourd'hui 20 passifs se posent 3 fois. Un seul bloc de code (P1c + P1d + B10). |
| 2 | Cartes et trophées à passer « à débloquer » (P7) | **Trophées** : ~40 effets simples d'emblée, ~27 avancés à débloquer (esquive et parfait, aérien, enchaînements, sorts, foudre en chaîne avancée). **Cartes** : jamais la base d'un axe ; seulement les **évolutions d'axe** (B2) et les cartes de geste (B7 : Flux, Maître du ciel). Liste en 4.2. |
| 3 | Rangs II et III des certificats (×1,5 puis ×2) | **Conflit**, voir 2.1 : d'accord si c'est budgété et neutre en JcJ. |
| 4 | Effets de la panoplie du Panthéon | Proposition en 3.5. |
| 5 | Recouvrement talents / cartes de sort de classe / améliorations de sort | Oui, il y a doublon **en run** : améliorations de sort (~20 %) et cartes de classe (~30 %) visent le même sort et diluent l'offre. Proposition B14 (3.4) : les cartes de classe deviennent les **facettes** de l'amélioration de sort. Les talents (méta) restent tels quels. |
| B-Q | Certificats en méta (plateau) **et** en run (coffre de certificat) | Progression n'a pas tranché. Notre position : garder les deux, mais en run ne proposer **que** des certificats non posés et d'une autre lignée que la classe jouée (découverte), avec un poids faible (3 % aujourd'hui, c'est bien). |

### 1.3 Modes

| # | Question | Réponse Builds |
|---|---|---|
| 1 | Trophées en Tour (un choix tous les 10 étages) ; cartes de run en Donjon | **Tour : oui** (20 choix pour une ascension, collection plafonnée à 12 : le choix « garder la place » devient enfin réel). **Donjon : oui, mais peu** (option A de M2, voir 2.3) : une carte par salle, pas de trophée. |
| 2 | Quelles épreuves de maîtrise débloquent quelles cartes | Table en 3.2. Règle : chaque carte de geste a **deux chemins** (médaille de bronze **ou** record cumulé en run), pour ne jamais forcer l'Académie. |
| 3 | Combos d'états (B4) et esquive parfaite (B7) en Duel | **Combos : oui**, ×1,5 (profil JcJ). **Annulation parfaite : oui** (déjà le cas). **Esquive parfaite défensive : seulement contre une attaque annoncée** (`telegraph.gd`) ; les sorts des héros n'en ont pas, donc en Duel elle ne joue que si on ajoute plus tard un marquage aux sorts adverses. **Jamais de ralenti en JcJ** (le temps est commun aux deux joueurs) : un éclair et le déclencheur « perfect » suffisent. |
| 4 | Soins sur alliés dès maintenant (B6) | **Non.** B6 vise le solo (onde sacrée, surplus en Barrière). On prévoit seulement que la cible d'un soin passe par une fonction unique, pour brancher les alliés le jour où M6 arrive. |

### 1.4 Interface

| # | Question | Réponse Builds |
|---|---|---|
| 1 | Combien d'axes, quelles icônes (24 px, 12 au plus) | **12 axes, figés** : Projectiles, Zone, Critique, Durée, Givre, Foudre, Éliminations, Esquive et parfait, Aérien, Sorts, Auto-attaque, Rempart (les soins vont dans Rempart). Icônes : statuts d'Eden déjà extraits quand ils existent (gel, foudre, saignement, Barrière), sinon pictogrammes simples. Pas de 13e axe : les invocations sont reportées (B12b abandonnée, 4). |
| 2 | Relire les fiches « Armes et variantes », « Enchaînements », « Annulation parfaite » | **Oui**, au tour 3, après le choix du joueur sur B3 et B7. Points déjà sûrs : l'arme principale est l'arme de la classe, 2 variantes, l'arme secondaire frappe seule à 60 %, l'enchaînement donne +20 % sur toute la barre (zone dorée en plus si B7). |
| 3 | Zone dorée : position fixe ou variable | **Fixe par sort** (déduite de l'identifiant du sort, toujours au même endroit) et **visible en permanence** dans la barre : on l'apprend comme un rythme, c'est le « hard to master ». Variable = loterie visuelle au milieu d'une horde. |

---

## 2. Conflits (position, arguments, compromis)

### 2.1 Rangs de certificat II / III (Progression P7) — puissance brute permanente

- **Notre position** : « débloquer = plus de choix, jamais plus de puissance brute » (rapport 1, §7).
  Un certificat ×2 au rang III, multiplié par 7 emplacements, creuse l'écart débutant / vétéran en
  Survie et, surtout, fausse le JcJ (le Duel copie aujourd'hui la méta de l'adversaire, mais la Ligue
  et le Panthéon ne le feront pas forcément).
- **Arguments de Progression** : les maîtrises 9 à 40 sont vides ; il faut une récompense qui se sent.
- **Compromis proposé** :
  1. les rangs **changent la forme** plutôt que le chiffre quand c'est possible : rang II = le
     certificat gagne un **second effet de la même famille** (« +15 % d'attaque » → « …et +5 % de
     dégâts contre les élites ») ; rang III = sa couleur compte double pour les liens du plateau ;
  2. ce qui reste chiffré entre dans le **plafond de méta d'Équilibrage** (×1,6 à la maîtrise 20,
     ×1,8 au maximum, E7) ;
  3. en JcJ classé et au Panthéon, le profil de mode met `meta` à la valeur de la fiche égale (E1 :
     champ `meta`), donc les rangs n'y comptent pas.

### 2.2 Ce que débloquent les Épreuves de maîtrise (Modes M1b)

- **Risque** : si une carte ne s'obtient **que** par une épreuve, le joueur qui n'aime pas l'Académie
  perd un morceau de build ; c'est contraire à « rien d'indispensable verrouillé ».
- **Compromis** : double chemin (médaille de bronze **ou** record cumulé), voir 3.2. Les médailles
  d'argent et d'or ne donnent **que** des titres et cosmétiques.

### 2.3 Donjon : mini-Survie (notre avis du tour 1) ou équipement du hub (Modes, option A)

- **Nous nous rallions à l'option A**, qui donne au Donjon son équilibrage propre (ajout n°3) et un
  usage à l'Armurerie et à la forge ; la mini-Survie ferait doublon avec le Défi du jour et la Ruée.
- **Ce que nous demandons en échange** (le Donjon doit rester un mode de build) :
  - sorts = preset du Grimoire (comme le Duel), variante d'arme choisie à l'entrée ;
  - **une carte par salle** tirée dans un pool réduit : cartes communes, améliorations d'arme (B3 :
    l'effet légendaire au niveau 4 est atteignable en 4 salles s'il y a une amélioration garantie
    par salle), **pas** d'améliorations de sort (le preset est déjà complet) ni de trophée ;
  - PV des monstres d'Équilibrage E4 dans sa version « avec cartes » allégée (×1,8 plutôt que ×2,4,
    puisqu'il n'y a que 3 à 4 cartes).
- **Imbrication** : les **panoplies de donjon** (M2) sont le bon support de nos panoplies de build
  (B9) : voir 3.3.

### 2.4 Profils de mode : un seul endroit (E1) ou un socle d'activité (M0)

Pas un vrai conflit, mais un risque de doublon. **Notre avis** : M0 range le **comportement** (vie,
cartes de départ, fin, gains), E1 range les **chiffres** ; la fiche d'activité de M0 nomme son profil
E1. Un seul fichier de chiffres par mode, lisible et réglable en mode dev. Les champs « build » du
profil sont listés en 5.1.

### 2.5 Préréglage de 4 cartes à la reprise de la Tour (Modes M3) et presets (B11)

Modes propose N ÷ 5 cartes à la reprise de l'étage N. **Ajustement** : la reprise donne d'abord les
**sorts du preset** (`Run.fill_from_preset`, déjà utilisé par le Duel), puis N ÷ 10 cartes tirées
**avec l'affinité de B2** (un axe principal choisi à l'entrée). Sinon 30 cartes au hasard d'un coup
donnent un build incohérent, exactement le « build subi » de notre problème n°1.

---

## 3. Accords, imbrications et fusions

### 3.1 Accords sans réserve

- **E7 garde-fous** (Projectile supplémentaire normalisé, Élan meurtrier 0,15 s et 1,5 s rendues par
  seconde au plus, trophées « à l'impact » à 5 s, Lame large plafonnée à +100 %, cartes retirées au
  plafond) : **fusion avec nos B3 (partie projectiles), B8 (partie recharge) et B13**. Un seul bloc
  « garde-fous » ; B13 disparaît en tant que proposition séparée.
- **E3 JcJ** : stats en % ramenées par `gear_weight`, contrôles à endurance partagée, duels de la Tour
  sous les règles du Duel. Pour les builds, c'est une bonne nouvelle : en JcJ, les **effets**
  (certificats à effet, panoplies, signatures) prennent le pas sur les « +X % », ce que nous demandions.
- **E5 époques** (dégâts séparés des PV) et **I1 tutoriel** (`ZONE_DAMAGE` réservé à l'époque I) :
  hors de notre domaine, d'accord.
- **P1b** : retirer les trophées de l'Armurerie. Ils deviennent un **codex des trophées** dans
  Collection (découverte, pas d'achat), voir 6.
- **I8** : icône d'axe, résumé du build pendant le choix de cartes, bandeau « sans effet sur ton
  build », zone dorée, anneau blanc sans assombrir l'écran : exactement ce qu'il nous faut.
- **E6 journal de run** : nous y ajoutons 4 compteurs de build (cartes prises par axe, niveau d'arme
  atteint et tour où l'effet légendaire arrive, trophées pris, part des dégâts auto-attaque / sorts /
  procs). C'est ce qui permettra de vérifier B2 et B3 sur les vraies parties.

### 3.2 Épreuves de maîtrise (M1b) ↔ cartes de geste (B7) ↔ succès (P4)

Chaque carte de geste a deux chemins d'ouverture ; les médailles supérieures donnent des titres.

| Épreuve (Modes M1b) | Bronze ouvre… | …ou en run (record cumulé) | Argent / or |
|---|---|---|---|
| 10 annulations parfaites en 60 s | carte **Flux** (+1 palier de Fluidité, +1 s) | 200 annulations parfaites | titre « Fluide » / cadre |
| Esquiver 30 attaques annoncées sans être touché | évolution **Danse des lames** (axe Esquive) | 100 esquives parfaites | titre « Insaisissable » |
| Sauter 5 ondes de choc du boss | carte **Maître du ciel** (+15 % en l'air) | 300 éliminations en l'air | titre « Aérien » |
| 3 enchaînements parfaits d'affilée (si B7) | carte **Cadence parfaite** (zone dorée +5 % de barre) | 150 enchaînements parfaits | titre « Virtuose » |
| Mannequin en 20 s avec la classe imposée | rien (épreuve de DPS) | — | titre de classe |
| Duelliste Normal sans sort | rien | — | titre « Lame nue » |

Ces records sont aussi ceux d'E6 et de P4 : **on les écrit une fois** (`Profile.records`).

### 3.3 Panoplies de build (B9) ↔ panoplies de donjon (M2, P5) ↔ JcJ (E3)

- Au lieu de rattacher nos archétypes aux sets d'Eden des paliers de Survie (B9 tour 1), on les
  rattache **aux panoplies des 8 donjons** : chaque donjon = une panoplie = un archétype de build
  (Givre éternel, Tempête, Lame sanglante, Œil du faucon, Phénix, Vent céleste, + Projectiles,
  Rempart). Les 6 bonus existent déjà dans `items.gd` (morts aujourd'hui en Survie).
- Effets : le Donjon donne une raison de **choisir quel donjon refaire** (« je veux la panoplie
  Givre pour mon Chevalier glaciaire ») ; l'Armurerie et la Tour gagnent des pièces qui changent le
  jeu ; le JcJ gagne de la variété de builds (E3 rend les « +X % » moins décisifs).
- B9 passe donc **après** M2 et devient une partie de son butin (coût inchangé, M).

### 3.4 B14 (nouvelle, issue de la question 5 de Progression) — facettes d'amélioration de sort (S-M)

- Aujourd'hui, pour un sort pris : une carte « amélioration de sort » (rang +1) **et** 2 à 3 cartes
  de classe (Puissance / Ferveur, Cadence, Persistance) dans l'offre : ~50 % des cartes proposées
  concernent les sorts, en 2 familles qui se recouvrent.
- **Règle** : une seule carte « amélioration de sort » ; sa rareté fixe le nombre de **facettes**
  (commune : rang +1 ; rare : + une facette au choix entre Puissance, Cadence, Persistance ; épique :
  deux ; légendaire : les trois + bonus d'attribut). Les cartes de classe séparées disparaissent.
- **Gain** : l'offre se dégage (~15 % de place libérée) pour les axes (B2) et l'arme (B3) sans
  changer la puissance totale. Sorts fétiches (B11) : la pondération ×3 porte sur cette seule carte.
- **À valider par Équilibrage** avec le journal E6 (part des cartes de sort avant / après).

### 3.5 Panoplie du Panthéon (P8) — des effets de maîtrise, pas des stats

6 pièces légendaires (arme de la classe, tête, torse, jambes, gants, bottes), bonus d'effet :

| Pièces | Bonus (même effet dans tous les modes, chiffres du profil) |
|---|---|
| 2 | Annulation parfaite : la Fluidité dure +1 s |
| 4 | Esquive parfaite défensive (B7) : rend 15 % de la recharge du dernier sort lancé |
| 6 | La signature de lignée (B4) consomme la marque sans la retirer une fois toutes les 10 s |

Version **éveillée** (30 victoires, P8) : mêmes effets, rang supérieur, apparence dorée. Ces bonus
récompensent le jeu d'expert (cohérent avec « battre les cerveaux ») et n'ajoutent pas de « +X % ».

### 3.6 Affinités de build (B2) ↔ autres équipes

- **Défi du jour (M1a)** : un des 2 modificateurs est un **axe mis en avant** (« Projectiles : cartes
  de l'axe ×3 et +1 projectile de départ »), ce qui fait essayer d'autres builds ; les étiquettes de
  B2 suffisent à le coder.
- **Succès (P4)** : « gagner une époque avec ≥ 4 cartes de l'axe X » = 12 succès, qui ouvrent
  l'évolution de l'axe (rapport 1, §7).
- **Trophées en Tour (M3)** : l'offre de trophée suit l'affinité (1 de l'axe principal, 1 d'un axe
  secondaire, 1 au hasard), comme en Survie.
- **Statistiques (I6)** : « axe le plus joué » par classe, utile au joueur pour savoir ce qu'il n'a
  pas essayé.

---

## 4. Ce que nous ajustons ou abandonnons

| Proposition (tour 1) | Décision | Raison |
|---|---|---|
| B3 normalisation des projectiles | **ajustée** : chiffres d'Équilibrage (E7, `proj_gain`, rareté = dégâts, plafond +4) ; on garde l'effet légendaire au niveau 4, l'amélioration garantie au boss et la variante gardée au coffre | E7 plus précis |
| B8 recharge des trophées | **ajustée** : 5 s (Double frappe 1 s), chance ×1,5 ; le reste de B8 (nouveaux effets pour les axes vides, force affichée, noms en double) est gardé | E7 |
| B13 garde-fous | **fusionnée** dans E7 | doublon |
| B9 panoplies sur les sets de Survie | **déplacée** vers les panoplies de donjon (3.3) | M2 lui donne une source ciblée |
| B11 preset ×2 dans les offres | **gardée**, et étendue à la reprise de la Tour (2.5) et au Donjon (preset = sorts) | M2, M3 |
| B12a projectiles des sorts | **gardée** (S), avec le plafond E7 : +1 projectile de sort toutes les 2 cartes, +2 au plus | E7 |
| B12b familiers (Ingénieur, Dompteur, Dresseur) | **abandonnée pour l'instant** | Modes : pas d'allié IA avant M6 ; coût L ; pas de 13e axe d'icône |
| B6 « 2e buff identique renforce » | **gardée**, mais en Survie et Donjon seulement ; en JcJ le profil peut la couper | durée des manches (E2) |
| B7 esquive parfaite avec ralenti | **ajustée** : ralenti 0,4 s en JcE seulement ; en JcJ éclair + déclencheur, sans ralenti | temps commun en duel |
| B4 signatures | **gardée**, ×2 en JcE, ×1,5 en JcJ (profil) ; question au joueur maintenue (lignée ou classe) | E3 |
| Évolutions débloquées par succès (§7) | **gardée**, alignée sur P4 et M1b (3.2, 3.6) | — |
| Rien d'indispensable verrouillé | **maintenu** comme règle commune, proposée à la synthèse | conflits 2.1, 2.2 |

---

## 5. Avis consolidé sur l'ajout n°3 — équilibrage distinct par mode

**Principe commun aux 4 équipes** : l'**identité** d'un build est la même partout, seuls les
**chiffres** changent, et à **un seul endroit par mode** (profil E1, nommé par la fiche d'activité M0).
Nous soutenons E1 + M0 tels quels.

### 5.1 Ce qui ne change jamais d'un mode à l'autre (le joueur l'apprend une fois)

Forme des sorts et des enchaînements ; les 2 variantes de chaque arme et leur effet légendaire ;
signatures de lignée et combos d'états ; annulation parfaite, Fluidité, saut, esquive ; déclencheurs
des procs ; effets des panoplies. Un changement d'une de ces règles est une refonte, pas un profil.

### 5.2 Champs « build » à ajouter au profil E1

| Champ | Survie | Tour | Donjon | Défi du jour / Ruée | Duel classé | Panthéon | Arènes (plus tard) |
|---|---|---|---|---|---|---|---|
| Source des sorts | cartes | preset + cartes | preset | cartes (accélérées) | preset | preset | preset |
| Cartes de run | oui | 1 par étage | 1 par salle (pool réduit) | oui | non | non | non |
| Améliorations d'arme | oui | oui | oui (1 garantie par salle) | oui | non | non | non |
| Trophées | 4 coffres par map | 1 choix / 10 étages | non | oui (Ruée : 1 par boss) | non | non | non |
| `combo_mult` | 2 | 2 | 2 | 2 | 1,5 | 1,5 | 1,5 |
| `cc_mult` / endurance (E3) | 1 / non | 1 / non (monstres), JcJ pour les duellistes | 1 / non | 1 / non | 0,7 / oui | 0,7 / oui | 0,7 / oui |
| Ralenti de l'esquive parfaite | oui | oui | oui | oui | non | non | non |
| `meta` (talents, certificats, archive) | plein, plafond E7 | plein | plein | plein | `gear_weight` | fiche égale | `gear_weight` |
| Buff identique qui renforce (B6) | oui | oui | oui | oui | non | non | non |

### 5.3 Ce que chaque mode fait briller (à montrer, pas à égaliser)

- **Survie, Défi, Ruée** : Éliminations, Zone, Projectiles, Durée (hordes) ; trophées.
- **Tour, Donjon** : Critique, Durée, Givre/contrôle sur élites et boss ; panoplies de donjon.
- **JcJ** : Esquive et parfait, contrôle (raccourci), mono-cible, signatures ; certificats à effet.

Étiquette « horde / boss / duel » sur chaque axe (icône I8 + infobulle) : le joueur sait qu'un build
d'éliminations est roi en Survie et faible en Duel, et c'est voulu. **Point de vigilance** : les
cerveaux d'IA ont appris sans `PvpCaps` ; le Panthéon en « fiche égale » (E3.5) est la bonne réponse,
et aucun champ de 5.2 n'ajoute d'observation à `ml_arena.gd`.

---

## 6. Avis consolidé sur l'ajout n°5 — cartes et passifs à débloquer

**Règle** : débloquer = **plus de choix**, jamais plus de puissance brute ; la **base de chaque axe**
reste libre dès la 1re run (les 31 cartes libres actuelles, à ne pas réduire). Chaque déblocage
dilue l'offre, donc B1, B2 et le **grimoire des cartes** (bannissement permanent réversible de N cartes
débloquées, S) viennent **avant** d'en ajouter.

| Collection | Compte pour la complétion (P4.3) | S'ouvre par | Où on la suit (I6) |
|---|---|---|---|
| Cartes de base (31) | oui | d'emblée | Collection > Cartes |
| Cartes à débloquer (18 actuelles) | oui | records cumulés (en place) | idem, avec barre |
| Évolutions d'axe (4 → 12) | oui | succès « époque gagnée avec ≥ 4 cartes de l'axe » | idem, et Succès |
| Cartes de geste (Flux, Maître du ciel, Cadence parfaite) + Danse des lames | oui | Épreuve bronze **ou** record cumulé (3.2) | idem, et Académie |
| Certificats (120 passifs) | oui (maîtrise 8 de chaque classe) | maîtrise 3 et 8 (en place) | Collection > Certificats, par lignée |
| Rangs de certificat (P7) | **non** (prestige, pas collection) | maîtrise 15 / 25 | parcours de maîtrise |
| Effets de trophée (67 → ~75 avec B8) | oui (effets découverts) | ~40 d'emblée, ~27 avancés par succès / époques | **codex des trophées** |
| Modèles de trophée d'Eden (548) | **score à paliers**, pas pourcentage | choisis en run | codex (vignettes d'Eden) |
| Variantes d'arme « de maître » (17) | plus tard, si le joueur le veut (M-L) | époque gagnée avec cette arme | Collection > Armes |

Titres liés : un par axe complété (cartes + évolution), « Codex des trophées » par palier, un par
lignée dont tous les certificats sont débloqués. Les cartes ne donnent pas de titre une à une
(trop nombreux) : seulement les ensembles.

---

## 7. Liste des propositions mise à jour (coût, dépendances, ordre conseillé)

| Ordre | Prop. | Contenu (tour 2) | Coût | Avec |
|---|---|---|---|---|
| 1 | **B1** | cartes sans effet retirées (×0,15), cartes dominées relevées, plafonds affichés | S | E7, I8 |
| 1 | **E7 (ex-B13)** | garde-fous : `proj_gain`, Élan meurtrier, trophées 5 s, Lame large +100 % | S | Équilibrage pilote |
| 1 | **B5** | cohérence physique / magique des 20 classes, sans compensation, mesure E6 | S | Équilibrage (profils opti, IA_Duel) |
| 1 | **B10 = P1c + P1d** | couleurs des 120 certificats, un passif posé une fois, insensibilité codée, frères différents | S | Progression |
| 2 | **B3** | arme qui grandit : améliorations ×2 plus fréquentes, garantie au boss, effet légendaire au niveau 4, variante gardée | S | E7 |
| 2 | **B14** (nouvelle) | facettes d'amélioration de sort à la place des cartes de classe | S-M | Équilibrage (E6) |
| 3 | **B2** | 12 axes étiquetés, carte d'affinité, offre de trophée orientée, évolutions par axe | M | I8, P4, M1a, M3 |
| 4 | **B7** | zone dorée fixe, esquive parfaite (sans ralenti en JcJ), Flux, aérien | M | M1b, I8, P4 |
| 4 | **B4** | signatures de lignée (20), ×1,5 en JcJ | M (L pour 60) | session locale, joueur |
| 5 | **B8** | trophées : effets pour les axes vides, force affichée, noms uniques, ~27 avancés à débloquer | S-M | P7, I6 |
| 5 | **B11** | identité affichée, preset ×2, sort fétiche ×3, reprise de Tour par preset + affinité | S | I1, M3 |
| 5 | **B6** | buffs qui se renforcent (JcE), soins offensifs en solo | M | profil E1 |
| 5 | **B12a** | Perforation / Ricochet / projectiles pour les sorts (+2 au plus) | S | E7 |
| 6 | **B9** | archétypes de build sur les panoplies des donjons | M | M2, P5 |
| 6 | **Panthéon** | effets de la panoplie (3.5) | S (données) | P8, M4 |
| 6 | **Grimoire des cartes + codex des trophées** | bannissement permanent réversible ; trophées découverts | S | I6, P4 |
| — | B12b familiers ; 3e variante d'arme « de maître » | reportés | L / M-L | M6, joueur |

**Logique de l'ordre** : d'abord rendre l'offre honnête et les chiffres sains (lots 1-2, tous S),
ensuite seulement orienter l'offre (B2), puis récompenser le geste (B7, avec l'Académie de M1b et le
tutoriel I1), puis l'identité de lignée (B4, session locale). Ce qui dépend d'un mode à venir (B9,
Panthéon) suit ce mode.

### Questions au joueur, mises à jour (l'indispensable)

1. Signature par **lignée** (20, M) ou par **classe** (60, L) ?
2. **Zone dorée** dans la barre d'enchaînement (+40 %) et **esquive parfaite** avec ralenti (sauf en
   Duel) : d'accord ?
3. Les **cartes de classe** (Puissance, Cadence, Persistance) fondues dans l'amélioration de sort
   (B14) : d'accord, sachant qu'on verra plus souvent les cartes d'arme et d'axe ?

---

## 8. Résumé (5 lignes)

1. **Réponses** : d'accord avec Équilibrage sur `proj_gain` (rareté = dégâts, plafond +4), trophées à 5 s, B5 sans compensation, effets sur la durée non cumulables, combos ×1,5 en JcJ ; 12 axes figés pour l'Interface, zone dorée fixe par sort ; trophées en Tour oui, en Donjon non.
2. **Conflits** : rangs de certificat (P7) acceptés s'ils changent la forme, entrent dans le plafond de méta E7 et sont neutres en JcJ classé ; cartes des Épreuves (M1b) toujours à double chemin (médaille **ou** record) ; Donjon : ralliement à l'option A (équipement du hub, preset, une carte par salle).
3. **Fusions** : B13 et une partie de B3 / B8 absorbées par E7 ; B10 = P1c + P1d ; panoplies de build (B9) portées par les panoplies des 8 donjons ; épreuves, succès et journal E6 partagent les mêmes records ; nouvelle B14 (facettes d'amélioration de sort) contre la dilution de l'offre.
4. **Ajout n°3** : identité identique partout, chiffres dans le profil de mode (E1 + M0), avec 9 champs « build » par mode (source des sorts, cartes, arme, trophées, combos, contrôles, ralenti, méta, buffs) ; chaque mode fait briller ses axes, et on l'affiche au lieu de l'égaliser.
5. **Ajout n°5** : débloquer = plus de choix, jamais plus de puissance ; base de chaque axe libre ; évolutions, cartes de geste et ~27 trophées avancés à débloquer ; grimoire des cartes et codex des trophées ; ordre : B1 / E7 / B5 / B10 → B3 / B14 → B2 → B7 / B4 → le reste.
