# Concept final de l'atelier (jeu 0.1.130 → 0.1.131, 14/10/2026)

Établi par la session principale à partir de `SYNTHESE_v1.md`, des **réponses du joueur**
(`REPONSES_JOUEUR_1.md`, qui font foi) et des raffinements des 5 équipes
(`<équipe>/raffinement_3.md`). Ce document est la **référence pour coder** : chaque lot de la
section 9 renvoie aux fichiers des équipes pour le détail (règles exactes, fichiers et fonctions).

---

## 1. Principes (validés)

1. Un build garde la **même identité dans tous les modes** ; seuls les chiffres changent, à un seul
   endroit par mode (`core/mode_rules.gd`), affichés sur la page du mode et réglables en mode dev.
2. **Débloquer donne plus de choix, jamais plus de puissance brute.**
3. **Rien n'est caché** (grisé avec sa condition) ; **on ne reverrouille jamais** la sauvegarde.
4. **Le jeu facile à prendre en main, c'est le clavier avec la mémoire des touches** ; le mode auto
   est une aide officielle, mais il ne fait plus ce que seul un expert fait (l'annulation parfaite).
5. **Chaque activité a son gain propre.** Le hasard (coffres, autel, plus tard creuset et loteries)
   ne donne **jamais de stat** ni d'équipement de puissance : seulement apparences, auras, insignes.
6. **Les duels ne sont ni interminables ni décidés en un coup.**
7. **D'abord corriger et mesurer, ensuite ajouter.**

---

## 2. Prise en main (nouveau, pilote Builds ; détail : `builds/raffinement_3.md`)

**Constat dans le code** (`player/player.gd`) : seules les touches de saut ont une mémoire (0,15 s) ;
un appui sur un sort pendant le verrou de 450 ms casse la chaîne (« Trop tôt ») ; un appui sur un autre
sort pendant une animation est perdu (il faut rappuyer ~1,1 s plus tard) ; enchaîner tôt coupe les
derniers coups du sort. Le Bot, lui, réussit une annulation parfaite à chaque sort (Fluidité +40 %
permanente, −25 % de recharge par sort) : environ ×2 sur les dégâts de sorts. D'où le fossé.

**Mémoire des touches** (pour le joueur seulement : les cerveaux et l'arène d'IA ne changent pas)
- jusqu'à **3 appuis gardés**, joués dans l'ordre ; appuyer en trop ne coûte rien, « Trop tôt »
  disparaît ;
- l'enchaînement part **après le dernier coup** du sort en cours (plus de coups perdus) ;
- un appui qui n'a pas pu partir s'efface après **1,2 s** ; un sort en recharge n'est gardé que s'il
  lui reste 0,3 s au plus ;
- **esquive et saut partent tout de suite** et vident la mémoire ;
- à l'écran : les icônes d'enchaînement de la case se remplissent à chaque appui gardé, 2 pastilles
  montrent le prochain sort d'une autre case ; option pour couper la mémoire.

**Autres aides** : maintenir une touche joue toute la chaîne ; les sorts posés au sol près d'un
monstre se posent sur lui ; un anneau bref annonce le moment de l'annulation parfaite.
**Refusés par le joueur** : ralenti, zone dorée.

**Aide au combat officielle, 4 niveaux** : **Manuel**, **Assisté** (par défaut), **Détente**, **Bot**.
- L'auto ne fait **plus d'annulations parfaites** : c'est le « hard to master » qui reste au joueur.
- Le niveau se voit au HUD et au bilan. **Mêmes gains en JcE.** Les succès d'adresse se font en
  Manuel ou Assisté seulement.
- **Ligue, Panthéon et duels de la Tour : Assisté au plus.**

**Défauts à corriger tout de suite** : les combos parfaits automatiques marchent en Duel
(`_auto_combo` ne teste pas le Duel) ; la pause d'impact (`_hit_pause`, `Engine.time_scale` 0,15
pendant 50 ms) ralentit aussi l'adversaire en Duel ; l'infobulle d'enchaînement (`hud.gd:492`) sera à
réécrire.

**Contrôles** : touches rangées en groupes avec bouton « Tester », libellés Xbox pour la manette,
puis manette réassignable.

---

## 3. Duel : deux modes (réponses 8 et 10 ; détail : `equilibrage/raffinement_3.md`)

| | **Duel à l'arme** | **Duel équipé** |
|---|---|---|
| Héros | arme de la classe **sans stats**, 12 sorts du preset, aucune pièce, ni talents, ni certificats, ni maîtrise | équipement, armes, certificats, maîtrise, forge |
| Niveau | **choisi de 1 à 90** (niveau 10 au Panthéon) | celui du héros |
| Chiffres | échelle des dégâts 0,030 ; cible **45-90 s** par manche | bonus en % comptés à moitié, plafonds dégâts +100 %, critiques ×2 ; cible **30-75 s** |
| Où | **Ligue**, **Panthéon**, Duel libre, **Arènes** | Duel libre, **duels de la Tour**, **Gantelet** |

**Pas de mort en un coup (les deux modes)** : un coup retire **au plus 15 % des PV max**, et **au plus
35 % sur 2 s**, critiques, combos, dégâts sur la durée et acharnement compris. Tuer prend donc au
moins 5 s ; le plus gros coup normal (~12 %) n'est pas touché. Les bonus en % (`dmg_mult`, `crit`)
sont enfin ramenés comme l'attaque.

**Mesures qui le justifient** (2 essais dans l'arène) : niveau 1 sous les règles actuelles = manches
de 105 s, finies seulement par l'acharnement ; conditions d'entraînement brutes = 19 s avec des coups
de 40-50 % des PV. **À corriger** : `Duel.gear_level` impose aujourd'hui le niveau 10 minimum.

**Arbitrages** : Gantelet en Duel équipé (le mode équipé a ainsi une activité à lui) ; Arènes en Duel
à l'arme (alliés et adversaires de même force) ; plafond par coup = valeur d'Équilibrage (15 %).

---

## 4. Déroulé et déblocages (pilote Progression ; détail : `progression/raffinement_3.md`)

| Quand | S'ouvre |
|---|---|
| Nouvelle partie | accueil, **choix parmi les 5 classes de base**, Survie (époque I), Zone d'entraînement, Épreuves, Héros, Guide |
| Fin de la 1re run | Classe (talents, maîtrise), Cartes, Collection ; Coffres ; Armurerie (Atelier) |
| Maîtrise 3 d'une classe | Plateau des certificats |
| 3 runs terminées | Défi du jour de maîtrise |
| Époque I gagnée | Forge et Réserve (Atelier) ; la Tour |
| 1er duelliste de la Tour battu | Duel libre (les deux modes) |
| 3e duelliste battu | Ligue (Duel à l'arme) |
| Époque II gagnée | Donjons (chacun dès que son boss est battu en Survie) ; Ruée des boss |
| Ligue rang Or | Gantelet ; Arènes avec alliés IA |
| Ligue rang Platine | Panthéon des cerveaux |
| Époque IV gagnée | Rangs héroïques |

Champ de bataille 10v10 **retiré**. La sauvegarde du joueur garde ouvert tout ce qu'il utilise déjà.

---

## 5. Tutoriel (pilote Interface ; détail : `interface/raffinement_3.md`)

Accueil (Je découvre / Je m'échauffe / Je connais déjà) → **choix parmi les 5 classes** → **contrôles
et niveau d'aide** → 1re Survie avec les **10 Premiers pas** (monstres adoucis par le modificateur
« tutoriel », cette seule run). ~40 fiches à la 1re rencontre (jamais en combat de boss ni en Duel),
qui servent aussi de fiches « Nouveau : … » des déblocages. **Guide (F1)** à la place de l'Aide.
Sauvegarde existante : tutoriels coupés, une fenêtre **« Nouveau dans cette version »**.

---

## 6. Activités (pilote Modes ; détail : `modes/raffinement_3.md`)

Page Jouer en 3 colonnes :
```
Aventure       [ Survie ]          [ Donjons ]               [ La Tour ]
Défis          [ Défi de maîtrise ] [ Épreuves de maîtrise ]  [ Ruée des boss ]
Affrontements  [ Duel : à l'arme · équipé ]  [ Arènes avec alliés IA ]
─ Zone d'entraînement ─
```

- **Donjons** : équipement ramené au niveau du donjon, 12 sorts, une carte par salle, Normal /
  Héroïque (+15) / Mythique (niveau 90), monstres PV ×1,8, 10-12 min ; panoplie du donjon (mythique →
  légendaire → éveillée) et plans de fabrication ; alliés IA au choix.
- **Plus de maîtrise de classe** (réponse 7) : maîtrise 20 ≈ 17 500 points, ~10 Survies gagnées par
  classe. Défi du jour ×2 (+600 à la 1re réussite), Défis de maîtrise ×3, contrats de classe
  (400-800), épreuves de classe par famille (300 / 600 / 1 000 selon la médaille), rattrapage par
  famille ×1,5, manche de Ligue gagnée +150 ; **plafond total ×3**. Les classes du Défi du jour sont
  tirées parmi celles sous la maîtrise 20. Estimation : 60 classes à la maîtrise 20 en ~300 runs au
  lieu de ~540.
- **Épreuves de Survie par paires** (réponse 4) : une de chasse, une d'exploration ; chacune rapporte
  ce qui manque à l'autre style.
- **Tour** : reprise sans piège (12 sorts + cartes selon l'étage), trophée tous les 10 étages, pas de
  cerveau dans la Tour.

### Alliés IA hors ligne (réponse 6) — par étapes
Ce qui bloque n'est pas l'IA mais le **ciblage** : monstres, annonces au sol et projectiles ne visent
que le premier `player` (`monster.gd:74`, `class_rival.gd:199`, `telegraph.gd:_resolve`,
`projectile.gd`, `hazard.gd`).
1. **Ciblage par camp** (S-M, rien de visible) : groupe `heroes`, l'ennemi vise le héros hostile le
   plus proche, revu toutes les 0,5 s ; coups au sol et projectiles testent tous les héros hostiles.
2. **Allié scripté** (M) : `ClassRival` avec `ally = true`, soins et renforts gardés, build opti de sa
   classe ; coût processeur quasi nul.
3. **Donjons avec alliés** : PV des monstres × (1 + 0,5 par allié), gains inchangés.
4. **Arènes 2v2 / 3v3** (M-L) : IA scriptées de même force, au plus un cerveau adverse (il ne voit pas
   ses alliés) ; échelle 0,022 en 2v2, 0,018 en 3v3, soins ×0,5. Un cerveau déjà battu peut devenir
   allié.
Aucune observation n'est ajoutée à `ml_arena.gd`. Pas d'alliés en Survie pour l'instant.

---

## 7. Collection, récompenses, économie (pilote Progression)

- **Collection = Carnet** (vue d'ensemble, déblocages, succès et titres, classes, cartes, archive,
  apparences, statistiques) ; **Atelier** (Forge, Armurerie avec boutique d'apparences, Fabrication,
  Réserve). Complétion en 10 catégories, **maîtrise 20** pour « classe au maximum », signatures par
  famille (20). ~115 succès, accordés pour le passé, sans stat ; un titre porté.
- **Cerveaux** (réponse 9) : la 1re victoire contre chaque cerveau donne **une pièce de sa panoplie
  légendaire** (6 cerveaux = 6 pièces, bonus d'ensemble à effets à 2, 4 et 6), **un coffre
  d'apparence**, **un titre**, et **un coffre d'auras** (nouveau ; aura exclusive pour le dernier
  cerveau). **Version éveillée** : battre le cerveau avec une classe de chacun des 5 groupes de base.
  Rejouer avec la même classe ne donne que de la maîtrise (pas de farm). La panoplie sert en Duel
  équipé, Tour et Donjons, **jamais en Duel à l'arme**. Les coffres montrent avant ouverture ce qu'ils
  peuvent donner, une pièce non possédée est garantie, un doublon devient des insignes ; emplacement
  **Aura** dans Héros > Apparence.
- **Autel de la fortune** (réponse 12) : plus d'équipement ; 15 à 120 insignes selon l'étage, coffres
  d'apparence aux étages 6 et 7 ; à espérance presque égale quel que soit l'étage où l'on s'arrête.
- **Plus tard** (réponse 7) : **Creuset des apparences** (3 doublons de même rareté + insignes → une
  apparence jamais possédée, 30 % de monter d'une rareté, montée garantie au 4e échec, jamais de
  sacrifice d'une pièce de la collection), loterie hebdomadaire, roue du Marchand masqué, **Salle des
  trophées** (housing).

---

## 8. Équilibrage par mode et mesures

- `core/mode_rules.gd` : profils Survie, Tour, Donjon, Duel à l'arme, Duel équipé, Panthéon,
  Arènes, entraînement ; Défis et rangs héroïques = Survie + **modificateurs** d'une liste unique.
- **Journal de run** (hors git) : compteurs communs aux succès ; chaque map classée « coffres »,
  « farm » ou « mixte » (part des coffres ouverts, temps en combat) ; mesure manuel / auto. **Aucun
  réglage d'époque avant ces mesures** (réponse 4). Règles : « frappent trop » si les dégâts subis par
  minute font ×1,5 d'une époque à l'autre ; économie à corriger si le DPS au boss diffère de plus de
  25 % entre styles.
- Arène d'IA : drapeau `--rules=duel_a / duel_b` pour mesurer le Panthéon ; le cerveau doit garder son
  taux de victoire à ±10 %, sinon une nuit d'entraînement de plus (sans nouvelle observation).
- Garde-fous de build : projectile normalisé, Élan meurtrier, trophées « à l'impact » 5 s, Lame large
  +100 %, physique / magique corrigé (20 classes), cartes de classe fondues dans l'amélioration de
  sort (B14).

---

## 9. Blocs de code (ordre de réalisation)

Chaque lot = un ou plusieurs envois (version +1, CHANGELOG). **L** = session locale (client Eden :
images, panoplies, auras) ; **C** = possible en session cloud.

| Lot | Contenu | Coût | Session | Le joueur voit |
|---|---|---|---|---|
| **1. Corriger** | textes faux (I7), F5-F8 au mode dev, code « héritage » mort, certificats (couleurs, passif posé une fois), records gardés dans tous les modes, défauts du Duel (combos auto, pause d'impact, niveau minimum 10) | S | C | textes et duel justes |
| **2. Prise en main** | mémoire des touches, plus de « Trop tôt », enchaînement après le dernier coup, maintien = chaîne, visée au sol, anneau d'annulation, affichage de la file ; auto sans annulations parfaites ; Aide au combat en 4 niveaux | S-M | C | **combos jouables à la main** |
| **3. Mesurer** | journal de run (styles coffres / farm, manuel / auto), compteurs communs | S | C | rien (fichiers de mesure) |
| **4. Socle des modes** | `Modes.current`, scripts de mode, `mode_rules.gd` (valeurs actuelles), modificateurs, test de la Tour, `--rules` de l'arène | M | C | rien (rangement) |
| **5. Duel en deux modes** | Duel à l'arme / équipé, plafond 15 % et 35 % sur 2 s, niveau 1, bonus en % ramenés, Ligue, page Duel, bilan avec durée de manche et plus gros coup | M | C | **nouveau Duel** |
| **6. Builds sains** | garde-fous, physique / magique, B14, arme qui grandit | S | C | cartes et armes |
| **7. Bilan, coffres, autel** | bilan commun « Rejouer », coffres lisibles et « Ouvrir tout », autel en insignes et apparences | S-M | C | oui |
| **8. Déblocages et Atelier** | `unlocks.gd`, fiches, Guide F1, verrous grisés, migration de la sauvegarde, Atelier, barre de ressources | M | C | oui |
| **9. Tutoriel** | accueil, 5 classes, contrôles et aide, Premiers pas, « Nouveau dans cette version » ; touches regroupées | M | C | nouvelle partie |
| **10. Page Jouer, Tour, Défis** | page Jouer en 3 colonnes, reprise de Tour, Défi de maîtrise, contrats, épreuves de classe et de Survie | M | C + L (images) | oui |
| **11. Carnet** | Collection = Carnet, succès, titres, grimoire des cartes, codex des trophées | M + M | C | oui |
| **12. Alliés IA** | ciblage par camp, allié scripté | S-M + M | C | allié en entraînement |
| **13. Donjons** | Donjons avec alliés, plans de fabrication, panoplies-archétypes | M + M | L | **Donjons** |
| **14. Panthéon** | Panthéon (Duel à l'arme niveau 10), panoplie, coffres d'apparence et d'auras, titres, emplacement Aura | M | L (auras) | **fin de jeu** |
| **15. Arènes** | Arènes 2v2 / 3v3 avec alliés IA, Gantelet | M-L | C | oui |
| **16. Fin de courbe** | étoiles d'époque, rangs héroïques, réglage des époques d'après le journal | S + M | C | oui |
| plus tard | axes de build étiquetés (B2), signatures par famille (B4), « Tissage » (B7), Ruée des boss, Creuset, loterie, roue, Salle des trophées, manette réassignable | — | — | — |

**Prochaine action proposée : lot 1, puis lot 2** (la prise en main est ce qui change le plus le
ressenti, et elle ne dépend d'aucun autre lot).

---

## 10. Documents à mettre à jour en codant

`DESIGN.md` (combos d'auto-attaque, « builds exotiques », Tour et Duel absents), page Aide
(`info_page.gd`), description de la Tour dans `activities.gd`, commentaires faux de `pvp_caps.gd`,
`CLAUDE.md` (chantier en cours) à la fin de chaque lot.
