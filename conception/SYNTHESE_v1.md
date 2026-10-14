# Synthèse de l'atelier — version 1 (jeu 0.1.130, 14/10/2026)

Écrite par la session principale après le tour 1 (`<équipe>/rapport_1.md`) et la concertation
(`<équipe>/concertation_2.md`) des 5 équipes : Progression (P), Builds (B), Équilibrage (E),
Interface (I), Modes (M). Les numéros renvoient à leurs fichiers. **Rien n'est codé.**

Prochaine étape : **tes réponses aux questions de la section 6**, puis un tour de raffinement, puis
le concept final et le découpage en blocs de code (une ébauche est en section 5).

---

## 1. Ce que les équipes ont trouvé (le plus important)

- **Seule la Survie a une vraie boucle.** Le Duel ne rapporte qu'un compteur de victoires, la Tour
  peu de chose, et reprendre la Tour haut est un piège (build presque vide à l'étage 150).
- **Une vingtaine de textes faux à l'écran** depuis la refonte de la Survie (Aide, menu Coffres,
  menu pause « tu choisiras 1 objet à garder », lobby, écran titre, Armurerie, page de la Tour).
  `DESIGN.md` est aussi en retard (combos d'auto-attaque, pas de Tour ni de Duel).
- **Touches de triche F5 à F8** (+1 niveau, rage…) actives en partie normale.
- **Deux règles différentes pour les combats entre héros** : le Duel (`PvpCaps`) et les duels de la
  Tour / l'entraînement (`hero_vs_hero_factor`, sans plafonds ni soins réduits).
- **Les cerveaux d'IA sont entraînés sans les règles du duel** (`ml_arena.gd:429`) mais les subissent
  en Duel.
- **Adoucissement de la 1re map rejoué à chaque époque, boss compris** (`run_director.gd:522`) : à
  l'époque IV la map 1 est à ×1,21 et la map 3 à ×2,2. Non voulu.
- **« Projectile supplémentaire » casse l'échelle des armes** (×2 pour une arme à un coup, ×1,25 pour
  la Mitraille, une légendaire = ×4). Élan meurtrier et 7 trophées « à l'impact » sans recharge.
- **20 classes ont des sorts calculés sur la mauvaise base** (physique / magique), 20 passifs se
  posent 3 fois, les couleurs des 120 certificats sont incohérentes.
- **Menu Coffres** : coffre 3D et animation déjà faits ; manquent l'aperçu du contenu, « Ouvrir
  tout », et un coffre peut proposer une pièce déjà possédée.
- **Les Donjons sont aux trois quarts prêts** (8 donjons d'Eden dans `zones.json`, boss et ~15
  mécaniques dans `boss_brain.gd`). **La pyramide de la fortune est déjà faite** (`core/fortune.gd`).
- **Ajouter un mode coûte cher** : chaque mode est câblé par des tests `Tower.active` / `Duel.active`
  dispersés (12 dans `world.gd`, 8 dans `run_director.gd`), et il n'existe aucun test de la Tour.
- **Le Champ de bataille 10v10 n'est pas réaliste** : l'IA ne vise que le joueur, le cerveau ne voit
  ni alliés ni plus d'un adversaire, 19 IA dépasseraient le budget d'une image.

---

## 2. Les principes communs (accord des 5 équipes)

1. **Un build a la même identité dans tous les modes** ; seuls les chiffres changent, à **un seul
   endroit par mode**, affichés sur la page du mode (« Règles : … ») et réglables en mode dev.
2. **Débloquer donne plus de choix, jamais plus de puissance brute.** La base de chaque axe de build
   reste libre dès la 1re run. Les rangs de certificat (puissance permanente) sont abandonnés.
3. **Rien n'est caché** : une activité fermée est grisée avec sa condition et son avancement.
   **On ne reverrouille jamais** ta sauvegarde ; le mode dev ignore les verrous.
4. **Passer le tutoriel ne débloque rien et ne bloque rien.** On apprend dans la vraie Survie.
5. **Chaque activité a un gain propre** qu'aucune autre ne donne : Survie = insignes et fournitures ;
   Tour = joaillerie et cristaux ; Donjons = pièces de panoplie ciblées et plans ; Duel = rangs et
   titres ; Panthéon = panoplie des cerveaux.
6. **Les records et compteurs sont écrits une seule fois** et servent à la fois aux succès, aux cartes
   à débloquer et au journal de run (mesures).
7. **D'abord mesurer et corriger, ensuite ajouter.**

---

## 3. Le concept, ajout par ajout

### 3.1 Ajout n°1 — Tutoriel passable (pilote Interface)
- **Accueil** d'une nouvelle partie : « Je découvre » / « Je m'échauffe d'abord » (Épreuves) /
  « Je connais déjà », puis la classe de départ (5 portraits, Guerrier présélectionné).
- **Premiers pas** : 10 étapes cochées en jouant ta 1re Survie, monstres adoucis pendant cette seule
  run ; « Passer » à tout moment.
- **~40 fiches courtes** à la 1re rencontre (jamais en combat de boss, en Duel ni en épreuve), qui
  sont aussi les fiches « Nouveau : … » des déblocages.
- **Guide (F1)** qui remplace l'Aide périmée ; règles de chaque mode générées depuis ses chiffres.
- **Paramètres** : Tutoriels Complets / Conseils seulement / Aucun.
- **Ta sauvegarde** passe d'office en « Aucun », avec une seule fenêtre « Nouveau dans cette version ».

### 3.2 Ajout n°2 — Contenu débloqué au fur et à mesure (pilote Progression)

| Quand | S'ouvre |
|---|---|
| Nouvelle partie | Survie (époque I), Zone d'entraînement, Épreuves de maîtrise, Héros, Guide, 5 classes de base |
| Fin de la 1re run | Classe (talents, maîtrise), Cartes, Collection ; Coffres (1er coffre) ; Armurerie (1re pièce découverte) |
| Maîtrise 3 d'une classe | Plateau des certificats |
| 3 runs terminées | Défi du jour |
| Époque I gagnée | Atelier > Forge et Réserve ; la Tour (Facile, Normal) |
| 1er duelliste de la Tour battu | Duel libre |
| 3e duelliste battu | Duel classé (Ligue) |
| Époque II gagnée | Donjons (chacun dès que son boss est battu en Survie) ; Ruée des boss |
| Ligue rang Or, puis Platine | Gantelet ; puis Panthéon des cerveaux |
| Époque IV gagnée | Rangs héroïques (difficultés au-delà de l'époque IV) |

Ta sauvegarde garde ouvert **tout ce que tu utilises déjà** (Duel, Tour, Forge), même sans compteur.

### 3.3 Ajout n°3 — Équilibrage distinct par mode (pilote Équilibrage)
- Un seul fichier de chiffres (`core/mode_rules.gd`) avec **8 profils** : Survie, Tour, Donjon, Duel,
  duels de la Tour, Panthéon, Gantelet, entraînement. Le 1er envoi ne fait que ranger le code
  (**aucun changement en jeu**), puis chaque réglage arrive dans son propre envoi.
- Les **Défis** et les **rangs héroïques** ne sont pas des profils : c'est la Survie avec des
  **modificateurs** tirés d'une liste unique (projectiles doublés, soins réduits, une vie…).
- **Durées visées** : Survie ~12 min par map, boss 1 à 2 min ; étage de Tour 30-60 s ; Donjon
  10-12 min, boss 1 min 30-2 min 30 ; manche de Duel 30-90 s à tout niveau (déjà tenu).
- **JcJ** : contrôles plus courts avec une limite commune, combos d'états ×1,5 au lieu de ×2, bonus en
  % ramenés comme l'attaque, **duels de la Tour sous les mêmes règles que le Duel**.
- **Panthéon** : les deux héros jouent dans les conditions d'entraînement des cerveaux (niveau 10,
  sans équipement) : seul cadre où un cerveau joue vraiment bien.
- **Époques** (après ton avis, question 6.4) : PV et dégâts des monstres séparés ; adoucissement de la
  1re map gardé à l'époque I, réduit ensuite.

### 3.4 Ajout n°4 — Mini-jeux et activités (pilote Modes)

Page Jouer refaite en **3 colonnes** (la grille actuelle ne peut pas les contenir), une carte par
activité, avec durée, gain et cadenas :

```
Aventure       [ Survie ~40 min ]   [ Donjons ~10 min ]    [ La Tour · par 10 étages ]
Défis          [ Défi du jour ]     [ Épreuves de maîtrise ] [ Ruée des boss ]
Affrontements  [ Duel : Ligue · Panthéon · Libre ]  [ Arènes · Bientôt ]
─ Zone d'entraînement ─
```

- **Donjons** : 3 salles + boss au complet, ton équipement ramené au niveau du donjon, tes 12 sorts,
  une carte par salle ; Normal / Héroïque (+15 niveaux) / Mythique (niveau 90) ; butin = pièces de la
  panoplie du donjon (mythique → légendaire → éveillée) et **plans de fabrication** (ta note).
  Chaque panoplie = un archétype de build (Givre, Tempête, Lame sanglante…).
- **Défi du jour** : une map, une classe imposée parmi 3, 2 modificateurs, change à minuit.
- **Épreuves de maîtrise** : leçons de 1 à 3 min sur les gestes d'expert (annulation parfaite,
  esquive, saut des ondes…), médailles bronze / argent / or ; le bronze ouvre une carte de geste, qui
  s'ouvre aussi par un record en run (jamais obligatoire).
- **Ruée des boss** : les boss d'une époque à la suite, au chrono.
- **Tour** : reprise sans piège (tes 12 sorts + des cartes selon l'étage), un trophée tous les 10
  étages, étages-épreuves, coffres d'apparence annoncés.
- **Duel** en 3 onglets : Ligue (Bronze → Platine), Panthéon (les 6 cerveaux dans l'ordre), Libre
  (banc d'essai actuel). Gantelet (1 contre 2 puis 3) au rang Or.
- **6 petites épreuves** de 30 à 90 s réutilisées en Survie, en Tour et aux Épreuves : Prime,
  Reliques, Horde, Sol piégé, Cristal à défendre, Faille. Plus un **Marchand masqué** en Survie.
- **Champ de bataille 10v10 retiré du menu** ; Arènes 2v2 / 3v3 en dernier (gros chantier).

### 3.5 Ajout n°5 — Tout collectionner (pilote Progression)
- **Collection devient le Carnet** : vue d'ensemble, déblocages, succès et titres, classes, cartes et
  certificats, archive, apparences, statistiques. Chaque manque dit **d'où il vient**, avec un bouton.
- **Complétion en 10 catégories** : classes, maîtrise 20 des 60 classes, cartes, certificats, effets
  de trophée, armes, panoplies (dont « à +10 »), étoiles d'époque et Tour, activités, succès. Les
  scores sans fin (apparences, archive, 548 modèles de trophée) sont montrés à part.
- **~120 succès** en 9 catégories, **accordés aussi pour le passé**, jamais de stat ; ils donnent
  titres, apparences, insignes ou l'accès à un choix (évolution d'axe, trophée avancé).
- **Un titre porté**, affiché sous ton nom (lobby, Tour, Duel, bilan).
- **Maîtrise 10 à 40** : titres, emplacement de preset en plus, apparences, signature de lignée.
- **Atelier** : tout ce qui dépense (Forge, Armurerie avec boutique d'apparences tournante,
  Fabrication des plans, Réserve). Coût de la forge ÷ 3 jusqu'à +6, cristaux gagnés dans la Tour.

---

## 4. Désaccords restants et arbitrage de la session principale

| # | Sujet | Positions | Arbitrage proposé |
|---|---|---|---|
| A1 | Monstres adoucis pendant la 1re run du tutoriel | Interface et Modes : un profil « tutoriel » ; Équilibrage : abandonné, l'époque I suffit | **Un modificateur « tutoriel »** dans la liste commune (pas un profil), actif seulement pendant les Premiers pas. Coût quasi nul, tout le monde y trouve son compte. |
| A2 | Poids de l'équipement en Duel libre | Modes : 0,75 ; Équilibrage : 0,5 (0,75 seulement pour les duels de la Tour) | **0,5** (Équilibrage, qui porte les chiffres). Le Duel libre a déjà son éditeur pour tout changer. |
| A3 | Ouverture du Duel | Les deux équipes ont chacune adopté la version de l'autre (1 ou 3 duellistes) | **Duel libre au 1er duelliste battu, Ligue au 3e** (sans récompense en libre, rien ne presse). |
| A4 | Défi du jour | Modes : après la 1re run ; Progression : après 3 | **3 runs** : la 1re run ouvre déjà 5 choses. |
| A5 | Accès au Panthéon | Modes : Platine **ou** étage 100 de la Tour ; Progression : Platine seulement | **Platine seulement** : une seule échelle JcJ. |
| A6 | Cerveaux aux étages 50/100/150/200 de la Tour | Modes : retirés ; Équilibrage : sous profil Panthéon ; Interface les dessine encore | **Retirés** (Modes) : duelliste Hardcore scripté + modificateur. Le Panthéon garde l'exclusivité. |
| A7 | Cerveaux en Duel libre | Modes : choix libre ; Progression : seulement ceux déjà battus | **Progression** : le Débutant d'emblée, les autres une fois battus au Panthéon (le mode dev garde tout). |
| A8 | Cartes à la reprise de la Tour | Modes / Équilibrage : étage ÷ 5 (max 30) ; Builds : ÷ 10 avec affinité (sinon build incohérent) | **12 sorts du preset + étage ÷ 5 cartes tirées avec l'affinité d'axe** quand elle existe (B2), sinon ÷ 10. À mesurer. |
| A9 | Donjons : PV des monstres, niveaux | Modes ×1,6, Mythique 90 ; Équilibrage ×1,8, Mythique +30 | **PV ×1,8** (Équilibrage) ; **Mythique = niveau 90** (Modes : le niveau max). |
| A10 | Nom des leçons | « Académie » (Modes) ou « Épreuves de maîtrise » (Interface) | **Épreuves de maîtrise**, une carte dans la rangée Défis. |
| A11 | Rangs de certificat | Progression les abandonne, Builds les acceptait sous conditions | **Abandonnés** (principe 2). |

---

## 5. Ébauche du découpage en blocs de code (à valider)

| Lot | Contenu | Coût | Visible en jeu |
|---|---|---|---|
| **0. Corriger et mesurer** | textes justes, F5-F8 au mode dev, code « héritage » mort, couleurs des certificats et passifs posés une fois (B10/P1c/P1d), records gardés dans tous les modes, **journal de run** (compteurs communs) | S | textes, certificats |
| **1. Socle des modes** | `Modes.current` + scripts de mode + `mode_rules.gd` (valeurs actuelles), liste de modificateurs, **test de la Tour** | M | rien (rangement) |
| **2. Garde-fous de build** | projectile normalisé, Élan meurtrier, trophées 5 s, Lame large, cartes sans effet (B1), physique / magique (B5), arme qui grandit (B3) | S | oui |
| **3. Bilan et coffres** | bilan commun avec « Rejouer », coffres lisibles, « Ouvrir tout » | S-M | oui |
| **4. Déblocages, fiches, Atelier** | `unlocks.gd`, fiches, Guide F1, verrous grisés, migration de ta sauvegarde, Atelier, barre de ressources | M | oui |
| **5. Tutoriel** | accueil, Premiers pas | M | nouvelle partie |
| **6. Page Jouer et Tour** | page Jouer en 3 colonnes, reprise de Tour sans piège, duels de la Tour aux règles du Duel | S-M | oui |
| **7. JcJ** | règles JcJ complétées, Duel en 3 onglets (Ligue, Libre) | M | oui |
| **8. Carnet** | Collection = Carnet, succès, titres, grimoire des cartes, codex des trophées | M + M | oui |
| **9. Défis** | Défi du jour, Épreuves de maîtrise (zone dorée, esquive parfaite), épreuves en Survie, Ruée des boss | S-M chacun | oui |
| **10. Donjons** | Donjons, plans de fabrication, panoplies-archétypes | M + session locale | oui |
| **11. Fin de jeu** | Panthéon, étoiles d'époque, rangs héroïques ; époques réglées selon ton ressenti | M-L | oui |
| plus tard | axes de build étiquetés (B2), facettes de sort (B14), signatures (B4), Gantelet, Arènes | M-L | — |

---

## 6. Tes questions (réponses courtes suffisent : « oui », « non », « A ou B »)

**Déroulé du jeu**
1. **Ordre d'ouverture** (3.2) : Forge et Tour à la fin de l'époque I, Duel par la Tour, Donjons à la
   fin de l'époque II : d'accord ? (Ta sauvegarde garde tout ce que tu utilises déjà.)
2. **Tutoriel** dans ta 1re vraie Survie (10 étapes, monstres plus doux cette seule run), Épreuves
   à côté : d'accord ? Nouvelle partie : **choix parmi les 5 classes** de base ou toujours Guerrier ?
3. **Lobby** : une entrée **Atelier** (Forge, Armurerie, plans, réserve) et **Collection = Carnet** :
   d'accord ? Une fenêtre « Nouveau dans cette version » à chaque version qui ajoute un système ?

**Modes**
4. **Époque II** : les monstres **frappent trop fort** ou **tiennent trop longtemps** ? Et ouvres-tu
   presque tous les coffres d'une map ?
5. **Donjons avec ton équipement ramené au niveau du donjon** (les 4 équipes sont d'accord) : ok ?
6. **Champ de bataille 10v10** : le retirer, ou le remplacer par un « Siège » contre des monstres ?
   **Arènes avec alliés IA** : importantes pour toi ?
7. **Défi du jour** avec une classe imposée (au choix parmi 3) : ça te plaît ? Veux-tu des mini-jeux
   **hors combat** (pêche…) ?

**Duel et cerveaux**
8. **Panthéon** : « à armes égales » (niveau 10, sans équipement, seul ton jeu compte), ou « ton vrai
   héros » contre le cerveau (demande de réentraîner les cerveaux, gros chantier) ?
9. **Récompense des cerveaux** : une vraie panoplie (à effets, utilisable en Tour et Donjons) ou
   seulement titres, aura et apparences ?
10. **Ligue de Duel** : l'équipement compte **un peu** (comme aujourd'hui) ou **pas du tout** ?

**Collection et builds**
11. « Toutes les classes au maximum » = **maîtrise 20** (21 à 40 : titres et apparences de prestige),
    avec un rattrapage par famille : d'accord ?
12. **Autel de la fortune** : garder ses coffres d'équipement, ou les remplacer par des insignes et
    des apparences ?
13. **Signature** (attaque propre) par **famille** de classes (20) ou par **classe** (60, bien plus long) ?
14. **Zone dorée** dans la barre d'enchaînement et **ralenti sur l'esquive parfaite** (sauf en Duel) :
    d'accord ?
15. **Cartes de classe** (Puissance, Cadence, Persistance) fondues dans la carte d'amélioration de
    sort, pour voir plus souvent les cartes d'arme et d'axe : d'accord ?

---

## 7. Fichiers de l'atelier

- Brief : `00_BRIEF.md`
- Tour 1 : `progression/`, `builds/`, `equilibrage/`, `interface/`, `modes/` → `rapport_1.md`
- Concertation : même dossiers → `concertation_2.md`
- Cette synthèse : `SYNTHESE_v1.md`
