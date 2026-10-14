# Équipe Nouveaux modes — raffinement (tour 3, jeu 0.1.130)

Lus : `00_BRIEF.md`, `SYNTHESE_v1.md`, `REPONSES_JOUEUR_1.md` (fait foi), notre `concertation_2.md`.
Code relu pour ce tour : `ai/monster.gd`, `ai/class_rival.gd`, `player/player.gd`,
`combat/telegraph.gd`, `combat/projectile.gd`, `combat/hazard.gd`, `combat/pvp_caps.gd`,
`core/duel.gd`, `ml/ml_arena.gd`, `core/profile.gd` (expertise), `core/run.gd`, `core/tower.gd`.

Ce que les réponses changent pour nous : le 10v10 sort (réponse 6) ; les **alliés IA passent de
« L, si le joueur le demande » à un chantier voulu** ; le Duel passe de 3 onglets à **2 modes**
(arme seule / équipé) ; le Défi du jour devient une famille de **défis de maîtrise** ; pas de
mini-jeux hors combat.

---

## 1. Alliés IA pour jouer hors ligne

### 1.1 Constats dans le code (ce qui empêche un allié aujourd'hui)

| # | Constat | Où |
|---|---|---|
| a | Tout ennemi vise **le premier nœud du groupe `player`**, fixé une fois à l'apparition | `monster.gd:74`, `class_rival.gd:199` (`_player`), ~25 lectures de `_player` dans `class_rival.gd` |
| b | Les coups ennemis ne touchent **que ce premier héros** : un allié serait invulnérable aux monstres | `telegraph.gd:_resolve` (l. 180), `projectile.gd:_physics_process` (l. 48), `hazard.gd:97` |
| c | Un 2e `Player` côté joueur **copierait le héros** : sans `foe`, il lit `Run.class_id`, `Run.skills`, `Run.passives`, `Profile.equipped` | `player.gd:_ready` (l. 143), `_passives`, `_skills`, `recalc_stats` |
| d | `ClassRival` est un `Monster` : équipe `MONSTER` en dur, sorts de **soin et de buff retirés** | `class_rival.gd:_ready`, `setup` (l. 87 : filtre `buff` / `heal`) |
| e | Le cerveau voit **un seul adversaire** (le plus proche, `_nearest`), **aucun allié**, et un repère d'arène (`center`, rayon 15 m) | `ml_arena.gd:_obs_for` (l. 813), `_fwd_for` |
| f | Coût d'un cerveau : ~5 ms la décision toutes les 3 images. 2 cerveaux décalés ≈ 3,5 ms par image (tenable) ; 5 cerveaux ≈ 8 ms (la moitié d'une image à 60 i/s : non) | `ml_brain.gd:act`, `CLAUDE.md` |
| g | Ce qui marche déjà : `Player.foes()` est générique (l. 216) ; `Combatant.is_hero` compte `ClassRival` comme héros (règles JcJ appliquées) ; le scénario d'arène `duo` a entraîné le cerveau **contre 2 adversaires** | `player.gd`, `combatant.gd:307`, `ml_arena.gd:107` |

Conclusion : le verrou n'est pas l'IA mais **le ciblage « un seul joueur »** (a, b). Une fois levé,
`ClassRival` (60 classes, 4 difficultés, déjà joué en Duel et dans la Tour) fait un allié correct
pour presque rien. Le cerveau reste pour l'adversaire, au plus un ou deux à la fois.

### 1.2 Voie par étapes (aucune observation ajoutée à `ml_arena.gd`)

**Étape A — Ciblage par camp (S-M, sans changement visible).**
- Nouveau groupe `heroes` (le joueur + ses alliés) à côté de `player` (qui reste le seul héros
  du joueur : orbes d'XP, butin, `feedback.gd`, `gamepad.gd` ne changent pas).
- `Combatant` : `hostiles()` (camp adverse selon `team`) et `nearest_hostile(max_dist)`.
- `Monster` : `_player` devient `_target`, réévalué toutes les 0,5 s = **héros hostile le plus
  proche** (avec un peu d'inertie : on ne change de cible que si la nouvelle est 30 % plus
  proche, sinon les monstres hésitent). Les boss gardent l'aggro du joueur sur leurs mécaniques
  (`boss_brain.gd`), sauf la mécanique « cible aléatoire » s'il y en a une.
- `Telegraph._resolve`, `Projectile`, `Hazard` : tester **tous les hostiles de la source**
  (`source.hostiles()`) au lieu du premier `player`. Les compteurs `ml_counts` restent sur le joueur.
- Test : `test_farm` et `test_pvp` inchangés (un seul héros), plus un test à 2 héros où un
  monstre change de cible quand l'allié s'approche.

**Étape B — Allié scripté (M).** `ClassRival` avec `ally := true` :
- `_ready` : `team = PLAYER`, couche `PHYS_PLAYER`, groupe `heroes` (+ `allies`) ; cible =
  `nearest_hostile()` ; ses annonces au sol en **bleu** (pas rouge) et visibles mais sans dégâts
  pour le joueur.
- Lecture des coups : `_read_player` / `_threat` lisent la **cible** courante (un monstre n'a pas
  de `_action` : esquive seulement sur les annonces rouges proches, déjà gérées par `Telegraph`).
- **Soutien** : garder les sorts `heal` / `buff` quand `ally` ; règle simple : soin sur le héros
  allié le plus bas sous 50 % de PV, buff au début du combat et à la recharge. C'est le seul ajout
  d'IA « neuve » (≈ 60 lignes).
- Fiche : `use_sheet` (déjà là) avec le **build opti** de sa classe (`Duel.opti_build`) au niveau
  du joueur ; difficulté = qualité de jeu de l'allié (Normal par défaut).
- Interface : portrait et barre de PV de l'allié sous la nôtre ; rien d'autre au départ.
- Coût CPU : négligeable (même prix qu'un duelliste de la Tour).

**Étape C — Arènes 2v2 / 3v3 (M une fois A et B faits).**
- Toi + 1 ou 2 alliés scriptés contre 2 ou 3 héros ennemis (`ClassRival` scriptés, ou
  **un seul cerveau** dans l'équipe adverse, les autres scriptés : règle f).
- Un cerveau en arène : `MlDuelPilot` lui passe `opps` = **les héros du camp d'en face** ;
  `_nearest` choisit déjà le plus proche, et `center` = centre de l'arène (même rayon que
  l'entraînement : arène de 15 m obligatoire). Il ne voit pas ses alliés : il joue « chacun pour
  soi », comme dans le scénario `duo`. Acceptable pour un adversaire.
- Règles : `PvpCaps` tel quel (déjà entre héros), manches sans réapparition, 2 manches gagnantes ;
  acharnement à 30 s compté sur la manche ; soins sur alliés réduits par `HEAL_MULT` comme les autres.
- Composition : le joueur choisit la classe de ses alliés (ou « au hasard parmi les familles qui
  manquent ») ; l'adversaire est tiré pour équilibrer (un soigneur en face si tu en as un).
- Les deux modes de duel (section 2) s'y appliquent : Arène à l'arme / Arène équipée.

**Étape D — Alliés en JcE (S chacun, après B).**
- **Donjons** : 1 ou 2 alliés au choix à l'entrée (« groupe d'Eden » : un tank, un soigneur…),
  synchronisés comme toi. Le Donjon reste faisable seul ; avec alliés, butin inchangé (on ne
  veut pas forcer le groupe). Boss : les mécaniques visent le joueur en priorité.
- **Survie** : **pas d'allié permanent** (la Survie est le build qui grandit, un allié brouille
  l'équilibrage des époques). À la place, un **lieu « Mercenaire »** (8e lieu de la carte) : un
  allié scripté pour 90 s contre de l'or. S.
- **Tour** : non (une seule vie, le record doit rester personnel).

**Ce qu'on ne fait pas** : cerveau allié qui soigne (il ne voit pas ses alliés : il faudrait un
nouveau cerveau à observations différentes, donc tout réentraîner) ; plus de 2 cerveaux à la fois ;
le 10v10 (retiré).

| Étape | Fichiers | Coût | Dépend de |
|---|---|---|---|
| A ciblage par camp | `combatant.gd`, `monster.gd`, `class_rival.gd`, `telegraph.gd`, `projectile.gd`, `hazard.gd`, test | S-M | — |
| B allié scripté + soutien | `class_rival.gd`, petit cadre d'allié dans le HUD | M | A, Interface |
| C Arènes 2v2 / 3v3 | `core/arena.gd` (nouveau, sur le socle `Modes`), `ml_duel_pilot.gd` (liste d'adversaires), page de l'activité | M | A, B, socle M0/E1, section 2 |
| D Donjons avec alliés, lieu Mercenaire | `dungeon` (script de mode), `world/` lieux | S chacun | B, Donjons |

---

## 2. Les deux modes de duel

### 2.1 Définition

| | **Duel à l'arme** | **Duel équipé** |
|---|---|---|
| Ce que tu emmènes | ta classe, **l'arme de base de ta classe** (sans gemme ni amélioration), les sorts de ton preset | ton héros complet : équipement, arme principale et secondaire, certificats, talents, maîtrise, aura, sorts |
| Niveau | **libre, de 1 à 90**, le même pour les deux héros | ton niveau ; l'adversaire est à ton niveau |
| Poids de l'équipement | **0** (l'équipement ne compte pas du tout, réponse 10) | plafonds JcJ (`PvpCaps.CAPS`) + poids 0,5 (synthèse A2) |
| Adversaire | IA scriptée (même fiche nue) ou cerveau | IA scriptée en build opti de sa classe (`Duel.rival_sheet`) |
| Ce qui compte | ton jeu | ton jeu **et** ton build |

Réalisation : un champ `gear` du profil de règles (`duel_arme` = 0, `duel_equipe` = 0,5) et une
fiche « nue » pour le mode à l'arme (`Player` sans `Profile.equipped`, comme une fiche `foe` sans
`foe_gear`). L'ancien choix `Duel.GEAR_MODES` (généré / copie / opti) reste dans le Libre.

### 2.2 Ni interminable, ni mort en un coup

- `PvpCaps.damage_mult` ramène déjà les dégâts à l'échelle des PV **quel que soit le niveau**
  (1,2 % des PV par coup de multiplicateur 1 en miroir) : le niveau 1 est jouable sur le papier.
- **Anti-coup fatal** (nouveau, S) : un coup entre héros ne retire **jamais plus de 30 % des PV
  max** de la cible (critique et acharnement compris, sauf après 90 s). Personne ne meurt d'un
  seul sort chanceux.
- **Anti-interminable** (déjà là) : acharnement après 30 s (dégâts ×2 toutes les 20 s, soins
  ÷ autant), soins × 0,35.
- **À mesurer par Équilibrage** avant de publier : arène d'IA `--scenario=duel` aux niveaux
  1, 10, 45 et 90 en mode à l'arme ; cible 30 s à 1 min 30 par manche, aucun coup > 30 %.
  Au niveau 1 la classe n'a que ses premiers sorts : vérifier qu'aucune classe n'est sans outil.

### 2.3 Où vont Ligue, Panthéon, Libre, Gantelet

| Activité | Mode | Pourquoi |
|---|---|---|
| **Ligue** (Bronze → Platine) | **à l'arme** | réponse 10 : l'équipement ne compte pas ; niveau choisi par le joueur (rang commun à tous les niveaux) |
| **Panthéon** (6 cerveaux) | **à l'arme, niveau 10** | les cerveaux ont appris au niveau 10 sans équipement : c'est le seul réglage juste ; le niveau n'est pas libre ici |
| **Libre** | **les deux** (interrupteur) | banc d'essai : éditeur d'adversaire, cerveaux déjà battus (synthèse A7) |
| **Gantelet** (1 contre 2 puis 3) | **équipé** | c'est là que le build doit porter : tenir à 1 contre 3 |
| **Défi des champions** (nouveau, S-M) | **équipé** | battre le build opti de chaque classe à ton niveau ; donne au mode équipé une échelle à lui |
| Duellistes de la Tour | équipé (profil `tour_duel`) | inchangé |
| Arènes 2v2 / 3v3 | les deux | section 1, étape C |

### 2.4 Ce que gagne chaque mode

| Activité | Gains |
|---|---|
| Ligue | **maîtrise de la classe jouée** (section 3), titre de rang (Bronze… Platine), insignes à chaque rang ; Platine ouvre le Panthéon |
| Panthéon | récompenses des cerveaux (2.5) |
| Défi des champions | un **titre par famille** (5 classes battues avec une classe de la famille), maîtrise, cristaux ; record « classes battues 0 / 60 » |
| Gantelet | titres, cristaux |
| Libre | rien (banc d'essai) |

Les deux modes se nourrissent : la panoplie gagnée **à l'arme** (Panthéon) sert **équipé**.

### 2.5 Récompenses des cerveaux (réponse 9)

Six cerveaux dans l'ordre : Débutant, Facile, Normal, Difficile, Hardcore, Expert (l'actuel).
**Première victoire** contre chacun :

| Cerveau | Panoplie du Panthéon | Coffre d'apparence | Titre | Coffre d'auras |
|---|---|---|---|---|
| Débutant | gants | 1 | « Élève du Panthéon » | — |
| Facile | bottes | 1 | « Duelliste » | — |
| Normal | jambières | 1 | « Bretteur » | 1 |
| Difficile | casque | 1 | « Maître d'armes » | 1 |
| Hardcore | plastron | 1 rare | « Fléau des cerveaux » | 1 |
| Expert | **arme** + bonus de panoplie complet | 1 rare | « Invaincu du Panthéon » | 1 rare |

- Panoplie : au niveau du héros, se met à jour comme l'Armurerie (Progression fixe la rareté et les
  stats ; nous proposons « éveillée » pour Hardcore et Expert). Arme : celle de la **classe qui a
  gagné** (on peut la regagner avec chaque famille, voir ci-dessous).
- **Rejouer** : battre un cerveau avec une **autre famille** (5 familles) redonne un coffre
  d'apparence et débloque l'arme de panoplie de cette famille ; avec les 5 familles contre
  l'Expert : titre « Panthéon des cinq ». Après cela, rien de plus (pas de farm de cerveaux).
- Les cerveaux du Panthéon doivent être **figés dans git** (P8).

---

## 3. Défis qui rapportent plus de maîtrise de classe

### 3.1 Le besoin, chiffré

Maîtrise 20 = **17 480 points** (`Profile.expertise_need(l) = 120 + 80 l`, l = 1 à 19). Une Survie
gagnée en époque I rapporte ~1 500 à 2 000 (`run.gd:136` : niveau × 15 + éliminations ÷ 2 + élites
× 10 + 200 + 120 par étape). Soit **~10 victoires par classe, ~600 runs pour les 60 classes** : le
but « toutes les classes au maximum » (réponse 11) est hors de portée sans sources plus riches.

### 3.2 Propositions (3 défis + un rattrapage)

**D1 — Défi du jour, version maîtrise (S-M).** Une map de Survie (~12 min), 2 modificateurs
(`core/modifiers.gd`), **3 classes proposées** dont au moins une parmi tes moins maîtrisées.
Maîtrise **×2** sur cette partie + **600 points** à la 1re réussite du jour. Insignes ×1,5 et
cosmétique de rotation gardés.

**D2 — Contrats de classe (S-M).** Pour chaque classe, 3 contrats visibles sur sa page (écran
Classe), renouvelés quand on en termine un ; ils se remplissent dans **n'importe quel mode**.
Exemples tirés d'une liste par famille : « 400 éliminations avec tes sorts », « vaincre un boss
d'époque sans être touché par sa mécanique principale », « gagner 3 manches de Ligue », « 20
annulations parfaites dans une run », « finir une Survie sans arme secondaire ». **400 à 800
points** chacun, selon la difficulté. Compteurs : ceux de `Profile.records` et du journal de run.

**D3 — Épreuve de classe (S-M, dans les Épreuves de maîtrise).** Une leçon par **famille** (20,
réponse 13) jouée avec la classe choisie : mannequin et vagues au chrono, avec ses sorts et ses
états propres (B4 / B7). Bronze / argent / or : **300 / 600 / 1 000 points**, une fois par classe
et par médaille (60 classes × 1 900 = la moitié du chemin vers la maîtrise 20 si on fait tout en or).

**R — Rattrapage (S).** Toute source de maîtrise donne **×1,5** aux classes sous maîtrise 5 (une
nouvelle classe rattrape vite, la fin reste longue). Et la **Ligue** donne 150 points par manche
gagnée (maîtrise de la classe jouée).

Estimation : avec D1 tous les jours + D2 + D3 en argent, une classe passe de 0 à 20 en ~5 victoires
de Survie au lieu de 10. Équilibrage valide les chiffres.

### 3.3 Plus tard (hors de ce chantier, porté par Progression)

Housing, loteries et « trucs RNG », **fusion de cosmétiques** (trois apparences d'une rareté pour
tenter une de la rareté au-dessus). Pas de mini-jeux hors combat pour l'instant (réponse 7).

---

## 4. Réponse 4 (coffres ou farm de monstres) et épreuves de Survie

Le joueur joue deux styles selon la partie : **chasse aux coffres** (explorer, ouvrir, s'équiper)
ou **farm de monstres** (rester au combat, niveau et cartes). Conséquences :

1. **Le journal de run (E6) mesure le style** avant tout réglage d'époque : coffres ouverts (par
   qualité), objets cassés, éliminations et élites, temps en combat contre temps de trajet, or
   gagné / dépensé, niveau à chaque boss, épreuves prises et réussies. Un indicateur simple :
   `style = coffres ouverts ÷ (éliminations ÷ 100)`. Pas de retouche d'époque avant 5 runs mesurées.
2. **Épreuves par paires** : chaque map propose deux épreuves à des stèles distinctes, une de
   **chasse** (Prime, Horde) et une d'**exploration** (Course aux reliques, Faille cachée au bout
   de la carte). Le joueur prend celle de son style ; les deux sont facultatives.
3. **Gain croisé** : l'épreuve de chasse rapporte un **coffre d'emplacement** (ce qui manque au
   farmeur), l'épreuve d'exploration rapporte des **cartes ou de l'expérience** (ce qui manque au
   chercheur de coffres). Chaque style compense son point faible sans être forcé de changer.
4. Le **Défi du jour** peut pousser un style par un modificateur (« coffres +30 % » ou « élites ×2 »),
   jamais les deux le même jour.
5. Les deux styles doivent pouvoir gagner une époque : si le journal montre qu'un style perd
   nettement, Équilibrage règle **l'apport** de ce style (or des monstres, qualité des coffres),
   pas les PV des monstres.

---

## 5. Liste finale des propositions (coût et ordre)

| Ordre | Proposition | Coût | Dépend de |
|---|---|---|---|
| 1 | Socle M0 + E1 (fiche d'activité, `Modes.current`, profils, records) | M | E1, P2 |
| 2 | Journal de run complet (style coffres / farm, épreuves) | S | E6 |
| 3 | **Deux modes de duel** : profils `duel_arme` / `duel_equipe`, fiche nue, niveau libre, anti-coup fatal (30 %) | S-M | 1, mesure Équilibrage |
| 4 | **Ligue à l'arme** (rangs, maîtrise par manche) + Libre à deux modes | M | 3, P (titres) |
| 5 | Table des modificateurs + **Défi du jour de maîtrise** (D1) | S + S-M | 1 |
| 6 | **Contrats de classe** (D2) et rattrapage (R) | S-M | 2, Interface (écran Classe) |
| 7 | Épreuves de maîtrise + **épreuve de classe par famille** (D3) | S-M | I1, B4/B7 |
| 8 | Épreuves de Survie **par paires** (Prime / Reliques, puis Horde / Faille) | S chacune | 2 |
| 9 | **Ciblage par camp** (étape A) | S-M | — (peut passer plus tôt, sans effet visible) |
| 10 | **Allié scripté** avec soutien (étape B) | M | 9 |
| 11 | Donjons (version 3.5 de la concertation) avec alliés au choix (étape D) | M + S | 10, E4, P5 |
| 12 | **Panthéon** (6 cerveaux à l'arme niveau 10, récompenses 2.5) | M (+ panoplie P8) | 4, P8 |
| 13 | **Arènes 2v2 / 3v3** (étape C, à l'arme et équipées) | M | 9, 10, 3 |
| 14 | Gantelet et Défi des champions (équipé) ; lieu Mercenaire en Survie | S-M chacun | 3, 10 |
| — | Champ de bataille 10v10 | **retiré** | réponse 6 |
| plus tard | housing, loteries, fusion de cosmétiques | — | Progression |

L'étape A (ciblage) n'a aucun effet visible et débloque tout le reste des alliés : elle peut être
glissée dans le même envoi que le socle si la session principale veut avancer les Arènes.

---

## Résumé (6 lignes)

1. **Alliés IA** : le verrou est le ciblage « premier joueur » (`monster.gd`, `telegraph.gd`, `projectile.gd`, `hazard.gd`) ; on le remplace par « héros hostile le plus proche » (S-M, invisible), puis `ClassRival` en allié (`ally`, soins et buffs gardés) pour un coût CPU nul (M).
2. **Arènes 2v2 / 3v3** ensuite (M) avec alliés scriptés et au plus un cerveau adverse (il voit l'ennemi le plus proche, jamais ses alliés) ; alliés au choix en Donjon, simple Mercenaire de 90 s en Survie, rien dans la Tour ; aucune observation ajoutée.
3. **Duel à l'arme** (arme de base, niveau 1 à 90, équipement à 0) = Ligue et Panthéon (niveau 10 pour les cerveaux) ; **Duel équipé** (héros complet sous plafonds JcJ) = Gantelet, Défi des champions, Tour ; Libre dans les deux ; nouveau plafond : aucun coup > 30 % des PV.
4. **Cerveaux** : 1re victoire = une pièce de panoplie (arme avec l'Expert), un coffre d'apparence, un titre, un coffre d'auras dès le Normal ; rejouable une fois par famille, puis plus rien.
5. **Maîtrise 20 = 17 480 points, ~10 Survies gagnées par classe** : Défi du jour de maîtrise (×2, +600), contrats de classe (400-800), épreuve de classe par famille (300 / 600 / 1 000), ×1,5 sous la maîtrise 5 ; housing, loteries, fusions plus tard.
6. **Réponse 4** : le journal de run mesure le style (coffres ou farm) avant tout réglage ; les épreuves de Survie vont par paires chasse / exploration, avec un gain qui compense le point faible de chaque style.
