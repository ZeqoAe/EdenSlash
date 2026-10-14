# Équipe Interface & menus — raffinement (tour 3, jeu 0.1.130)

Lu : `00_BRIEF.md`, `SYNTHESE_v1.md`, **`REPONSES_JOUEUR_1.md` (fait foi)**, notre `concertation_2.md`.
Code relu pour être concret : `player/player.gd` (enchaînements, `_wants`, `_chain_press`),
`ui/hud_widgets.gd:SkillSlot`, `ui/hud.gd:518-535`, `core/settings.gd` (actions, presets, manette),
`ui/settings_menu.gd`, `core/gamepad.gd`, `ui/lobby.gd:_menu_duel`, `ui/activities.gd`, `core/fortune.gd`.
Rien n'est codé.

---

## 1. Tutoriel final (réponses 2, 3 et 14)

### 1.1 Ce qui change par rapport au tour 2
- **Classe de départ** : choix parmi les **5 classes de base** (Guerrier, Voleur, Chasseur, Clerc,
  Magicien ; les vertes de `class_picker.gd`). Fiche à 5 portraits, 3 étiquettes de style (B11),
  une phrase « Comment elle se joue », Guerrier présélectionné. Les 5 restent ouvertes au lobby (P2).
- **Retirés** (réponse 14) : la zone dorée « PARFAIT » sur l'anneau de recharge et le ralenti de
  l'esquive parfaite. L'esquive parfaite garde ce qui existe (`_perfect_cancel`, texte « ESQUIVE ! »,
  anneau blanc bref autour du héros, **sans ralenti**). L'Épreuve « Expert » sur la zone dorée est
  remplacée par une épreuve d'**annulation parfaite** (geste existant, `PERFECT_WINDOW` 0,28 s).
- **Nouvelle étape d'accueil** : le **style de contrôle et l'aide** (§2.3), juste après la classe.
- Le modificateur « tutoriel » (arbitrage A1 de la synthèse) remplace le « profil » : actif seulement
  pendant les Premiers pas, retiré **à la map suivante** si on les passe.

### 1.2 Déroulé définitif (nouvelle partie)
```
1. Accueil         « Je découvre » · « Je m'échauffe d'abord (Épreuves) » · « Je connais déjà »
2. Classe          5 portraits (base), Guerrier présélectionné
3. Contrôles       Clavier + souris · Souris seule · Manette (si branchée)   + Aide : Aucune / Assistée / Sorts auto
4. 1re Survie      Premiers pas (10 étapes cochées en jouant), modificateur tutoriel
5. Bilan           fiche « Ce que tu gardes »
6. Lobby           fiches d'ouverture du fil d'éveil, une fenêtre à la fois, jamais en run
```
L'étape « Enchaînement » des Premiers pas est réécrite pour la mémoire des entrées (§2.2) :
« Appuie sur **1** : ton sort part, puis ses enchaînements s'affichent au-dessus de la case. Appuie à
nouveau sur **1** quand tu veux : l'appui est gardé et le coup suivant part dès qu'il peut. »
Les « Trop tôt » ne sont plus montrés au débutant (avec la mémoire, un appui tôt n'est plus une faute).

### 1.3 « Nouveau dans cette version » (validé, réponse 3)
- Une fenêtre au **1er lancement d'une version qui ajoute une fiche** (`tutorial.gd`, champ
  `version` de chaque fiche ; `Profile.last_seen_version`). Rien de nouveau : pas de fenêtre.
- Contenu : une ligne par nouveauté (icône, titre, une phrase, bouton « Y aller »), en tête le numéro
  (`Version.NUMBER`) ; en bas « Tout voir dans le Guide ». Plusieurs versions sautées : une seule
  fenêtre, groupée par version.
- Relisible : Guide F1 > chapitre **Nouveautés**. Case « Aussi masquer les nouveautés » dans
  Paramètres > Interface (désactivée par défaut). Coupée en mode test / `--autoplay`.
- C'est aussi l'outil du joueur pour tester une version : chaque ligne ouvre l'endroit à vérifier.

---

## 2. Prise en main (pilote : Builds ; ici l'avis Interface)

### 2.1 Ce que le code fait aujourd'hui (pourquoi le fossé est « abyssal »)
- **Enchaînement** (`player.gd:_chain_open`, `chain_state`, `_chain_press`) : après un sort, une phase
  « verrou » de `CHAIN_DELAY` = `SKILL_RECOVERY` = **0,45 s**, puis une barre de **3 s**
  (`CHAIN_BAR`). `CHAIN_ZONE` vaut déjà (0, 1) : toute la barre est « bonne ». **Un appui pendant le
  verrou casse la chaîne** (« Trop tôt », `_chain_press` efface `_chain[slot]`). Le joueur qui
  martèle 1 perd donc ses enchaînements ; le pilote auto (`auto_combo`) appuie au bon moment.
- **Les autres sorts** passent par `_wants` = `Input.is_action_just_pressed` : un appui sur 2 pendant
  l'animation d'un sort est **perdu**. Seul le saut a une mémoire (`JUMP_BUFFER` 0,15 s).
- **Annulation parfaite** : fenêtre de 0,28 s après l'impact (`PERFECT_WINDOW`), faite seule par
  `auto_combo`. C'est le vrai geste d'expert ; il doit le rester.
- **HUD** (`hud_widgets.gd:SkillSlot`) : icônes des enchaînements au-dessus de la case, barre de
  timing avec une zone dorée (qui couvre toute la barre puisque `CHAIN_ZONE` = (0, 1)), lueur
  bleue quand c'est prêt, étiquette « AUTO ».
- **Aides** (`settings.gd:DEFAULTS.game`, onglet Combat) : `attack_mode` auto, `auto_skills` par case,
  `auto_target`, `auto_combo`, `auto_move`, `auto_cards` ; 7 modes de jeu (`PRESETS`) dont
  « Détente » et « Bot ». Tout existe, mais c'est **caché** dans les Paramètres et présenté comme un
  outil de test, pas comme une façon de jouer.

**Avis** : la mémoire des entrées proposée par le joueur vise juste. Elle ne retire rien au
« hard to master » (annulation parfaite, esquive, placement, choix de l'ordre des sorts) et retire
seulement la punition du martèlement. Les chiffres (durée de mémoire, taille de la file) sont à
Builds ; l'interface ci-dessous marche quels qu'ils soient.

### 2.2 Rendre lisible la file (sorts mémorisés)
Règle d'or : **ce qui est en mémoire se voit là où le joueur regarde déjà** (sa barre de sorts).
1. **Sur la case** : les icônes d'enchaînement au-dessus de la case (`chain_icons`) existent. Chaque
   appui gardé **remplit** l'icône du coup suivant (cadre bleu plein + petit chevron), dans l'ordre.
   Appuyer 3 fois sur 1 = les 2 icônes d'enchaînement pleines : « les 3 frappes sont parties ».
   Un 4e appui « dans le vide » ne montre rien (pas de message d'erreur).
2. **File inter-sorts** : une bande de **2 pastilles** (24 px) centrée juste au-dessus de la barre de
   sorts : l'icône du prochain sort d'une autre case (appui sur 2 pendant le sort 1), avec sa touche.
   Elle s'efface quand le sort part (petit glissement vers sa case). Au plus la taille de file de Builds.
3. **Vidage** : esquive, saut ou étourdissement **vident** la file (règle à confirmer par Builds) :
   les pastilles s'éteignent en gris 0,2 s. Le joueur comprend pourquoi son sort n'est pas parti.
4. **La barre de timing simplifiée** : avec la mémoire, la zone dorée n'a plus de sens (et elle
   couvre déjà toute la barre). On garde une **fine jauge qui se vide** (temps restant pour enchaîner,
   3 s), sans zone dorée ni curseur. « ENCHAÎNEMENT ×n » reste.
5. **Option** Paramètres > Combat : « Mémoire des entrées : Activée (conseillé) / Désactivée ». Désactivée,
   on retrouve l'ancien comportement (« Trop tôt ») pour qui veut le timing pur. En JcJ la mémoire
   reste permise (ce n'est pas une aide, c'est du confort).

### 2.3 Le mode auto devient une aide officielle : « Aide au combat »
On regroupe les cases existantes en **4 niveaux** (un seul réglage visible), les cases détaillées
restant dessous (« Personnalisé » si on les mélange) :

| Niveau | Ce que fait le jeu | Réglages existants |
|---|---|---|
| **Aucune** | rien (mémoire des entrées seulement) | tout à `false`, `attack_mode` manual |
| **Assistée** | auto-attaque seule au contact + **annulation parfaite automatique** | `attack_mode` auto + la partie « annulation » d'`auto_combo` (à séparer en `auto_cancel`) |
| **Sorts auto** | + les 4 sorts et leurs enchaînements partent seuls | + `auto_skills` ×4, `auto_combo` |
| **Bot** | + déplacement et choix des cartes | + `auto_move`, `auto_cards` (preset « Bot ») |

- **Où** : accueil (étape 3), Paramètres > Contrôles (en tête, au-dessus des 7 modes de contrôle
  qui ne gardent que le déplacement et la visée), **menu pause** (changeable à tout moment, hors JcJ),
  page de chaque activité (ligne « Aide : Assistée · Changer »).
- **En jeu** : une étiquette discrète à gauche de la barre de sorts (« ASSISTÉE » vert, « SORTS AUTO »
  bleu, « BOT » violet ; rien en « Aucune »). Les cases gardent leur « AUTO ». Une action
  « Changer d'aide » ajoutée à `Settings.ACTIONS`, **sans touche par défaut** (le joueur la pose).
- **Au bilan** : une ligne neutre dans « Ta partie » : « Aide : Sorts auto (toute la run) » ou
  « Aide : Assistée puis Aucune ». Aucun malus de récompense en JcE : l'aide **est** l'« easy to play ».
  Le journal de run (E6) enregistre le niveau : utile pour mesurer les deux styles (réponse 4).
- **Records** : Défi du jour, Ruée et Tour gardent le record avec une petite icône d'aide ; pas de
  classement séparé (un seul joueur). Quelques **succès « sans aide »** (Carnet) donnent des titres
  (« Main de maître » : finir une époque en « Aucune ») : le « hard to master » est récompensé, pas imposé.
- **JcJ** (réponse du joueur : « sauf en JcJ ») : en **Ligue et Panthéon**, aide forcée à « Aucune »
  (mémoire permise), annoncé dans les règles du mode et sur la page (« Aide coupée en Ligue »).
  En **Duel libre**, l'aide est permise (c'est l'entraînement) et affichée sur la plaque du héros.
  Duels de la Tour : même règle que la Ligue (règles du Duel, arbitrage de la synthèse).

### 2.4 Contrôles, réassignation, manette
- **Touches** (`settings_menu.gd:_build_keys_tab`) : 22 actions en liste plate, 2 touches chacune.
  Proposé : **4 groupes** (Déplacement, Combat, Sorts, Interface), et un bouton « Tester » qui allume
  l'action appuyée (utile pour un joueur peu sûr au clavier). S.
- **Deux dispositions proposées** pour les sorts, au choix à l'accueil et dans Touches :
  « 1 2 3 4 » (actuelle) et « **A E R T** autour de ZQSD » (déjà en 2e touche) mise en 1re ; plus
  « Sorts sur la souris » (boutons latéraux de souris pour 3 et 4) pour qui joue avec peu de touches.
- **Manette** (`PAD_BINDS`, disposition fixe façon PlayStation, `PAD_LABELS` « Carré », « R1 ») :
  1. libellés **Xbox** (A B X Y, RB RT) quand `Input.get_joy_name` le dit (S) ;
  2. 3e colonne « Manette » dans l'onglet Touches pour réassigner les boutons (M) ;
  3. la manette compte chaque passage de gâchette (R2, L2) comme un appui pour la mémoire des entrées ;
  4. les fiches et le Guide affichent les boutons de la manette quand `Gamepad.active` (déjà fait par
     `Settings.action_label`) : à vérifier sur chaque nouveau texte (`{skill_1}` au lieu de « 1 »).
- **Guide > Commandes** : tableau des touches **réelles** du joueur (clavier ou manette), pas un texte figé.

---

## 3. Page Jouer et page Duel

### 3.1 Page Jouer (réponse 6 : 10v10 retiré ; réponse 7 : pas de mini-jeux pour l'instant)
```
JOUER                                                    (3 colonnes, cartes ~230 × 100)
 Aventure       [ Survie ~40 min ]   [ Donjons 🔒 ]          [ La Tour 🔒 ]
 Défis          [ Défi de maîtrise ]  [ Épreuves de maîtrise ] [ Ruée des boss 🔒 ]
 Affrontements  [ Duel 🔒 ]           [ Arènes · alliés IA · Bientôt ]
 ─ Zone d'entraînement (bouton plat) ─
```
- `battlefield` sort de `Activities.LIST` ; `arena2` et `arena3` deviennent **une** carte « Arènes ».
- « Défi du jour » devient **Défi de maîtrise** (réponse 7 : des défis qui rapportent plus de
  maîtrise de classe) : la carte affiche la classe du défi et le bonus (« Clerc · maîtrise ×2 »).
- Chaque carte : durée en haut à droite, gain en une ligne, cadenas + condition si verrouillée.

### 3.2 Carte et page Arènes (alliés IA importants, réponse 6)
- Carte : « Arènes 2v2 / 3v3 — toi et tes alliés IA contre une équipe IA · hors ligne ».
- Page (quand le mode sera fait) : format 2v2 / 3v3 ; **tes alliés** : une case par allié (classe,
  bouton « Composition conseillée » qui propose tank / soin / dégâts), niveau de l'IA (scripté par
  difficulté, ou **cerveau** une fois battu au Panthéon : un cerveau vaincu devient un allié) ;
  l'équipe adverse ; règles du mode générées ; Lancer.
- En jeu : portraits des alliés (PV, sort en recharge) sous le cadre du héros, à gauche ; marqueur
  de couleur sous chaque allié ; un **ordre simple** sur une touche : « Suivez-moi / Sur ma cible »
  (action « Ordre aux alliés », sans touche par défaut, croix bas à la manette).

### 3.3 Page Duel : deux modes (réponses 8 et 10)
En tête de la page, un **sélecteur à deux grandes cases**, puis les 3 onglets de la synthèse :
```
DUEL
 ┌ À ARMES ÉGALES ────────────────┐  ┌ HÉROS COMPLET ────────────────────┐
 │ Juste ton arme, sans équipement│  │ Ton équipement, tes armes,         │
 │ Niveau libre, même 1           │  │ certificats, maîtrise, trophée     │
 │ Seul ton jeu compte            │  │ Niveau = celui de ton équipement   │
 └────────────────────────────────┘  └────────────────────────────────────┘
 [ Ligue ]  [ Panthéon ]  [ Libre ]
```
- **Ligue et Panthéon** : toujours **À armes égales** (réponse 10 : l'équipement ne compte pas du
  tout). Le sélecteur y est verrouillé avec la mention « La Ligue se joue à armes égales ».
- **Libre** : les deux modes au choix.
- **Réglages À armes égales** : curseur de **niveau** (1 au niveau max, défaut 10, celui des
  cerveaux) ; l'arme de la classe et sa **variante** (les 2 de `weapon_attacks.gd`) ; les sorts
  disponibles **à ce niveau** (grisés au-dessus, « s'ouvre au niveau 15 ») ; l'adversaire est au même
  niveau, sous la même règle. Pas de liste ✔/✘ d'équipement : seul le preset de sorts est vérifié.
- **Réglages Héros complet** : la page actuelle (`lobby.gd:_menu_duel` : conditions ✔/✘ « Régler »,
  niveau du duel = `Duel.gear_level()`, éditeur d'adversaire, préparation rapide, IA scriptée ou cerveau).
- **Règles du mode** (bloc repliable, généré des profils d'Équilibrage) : rappelle le but du joueur
  « ni interminable, ni mort en un coup » (ex. « un coup ne retire jamais plus de N % des PV »,
  « acharnement après 30 s ») ; le chiffre vient de `PvpCaps`, jamais écrit à la main.
- **Plaque du héros en duel** : nom, titre porté, mode (« Armes égales · niv. 1 »), aide (Libre seulement).
- **Bilan de duel** (`duel_results.gd`) : manche par manche, durée de chaque manche (pour voir la
  cible 30-90 s), plus gros coup reçu en % des PV (vérifie « pas de one-shot »).

---

## 4. Atelier, Carnet, coffres des cerveaux, autel (réponses 3, 9, 12)

### 4.1 Atelier et Carnet (validés)
- **Atelier** : Forge (verrou époque I) · Armurerie (Équipement, Apparences) · Fabrication (dès le
  1er plan) · Réserve. Inchangé depuis la concertation.
- **Carnet** (= Collection) : Vue d'ensemble « Carnet » · Déblocages · Succès et titres · Classes
  (maîtrise 20 = « au maximum », réponse 11) · Cartes et certificats · Archive · **Apparences**
  (sous-onglets Tenues, Armes, **Auras**) · Statistiques. Signature par **famille** (réponse 13) :
  une ligne par famille dans Classes.

### 4.2 Récompense d'un cerveau (réponse 9 : panoplie, coffres d'apparence, titre, coffres d'auras)
- **Panthéon, colonne de chaque cerveau** : portrait, classe, et sous lui ses 4 récompenses en
  icônes : panoplie (pièces), coffre d'apparence, coffre d'auras, titre « … ». Obtenu : coche dorée ;
  pas encore : silhouette grise avec infobulle (« Bats le cerveau Normal »).
- **Écran de victoire** : les 4 récompenses arrivent une par une (tuiles animées comme
  `chests_page.gd:_show_loot`), puis 2 boutons : « Porter le titre » et « Ouvrir les coffres »
  (mène au menu Coffres, coffres déjà sélectionnés).
- **Coffres d'apparence et d'auras** (menu Coffres, I4) : avant ouverture, **aperçu du contenu
  possible** : grille des apparences ou auras de ce coffre, possédées cochées, rareté par couleur ;
  mention « garantie : une pièce que tu n'as pas » tant qu'il en reste. Doublon : converti en
  insignes, affiché « doublon → +N insignes » (plus tard : matière des fusions de cosmétiques, réponse 7).
- **Auras** : nouvel emplacement « Aura » dans Héros > Apparence avec aperçu 3D qui tourne ; visibles
  en lobby, Duel, Tour ; **jamais assez fortes pour gêner la lecture d'une horde** (option
  « Auras des autres héros : réduites » pour les arènes).

### 4.3 Autel de la fortune : insignes et apparences (réponse 12)
`core/fortune.gd:PRIZES` donne aujourd'hui de l'or puis des coffres de forge, d'équipement, de set.
Côté interface (`fortune_popup.gd`, pyramide de 8 étages inchangée) :
- chaque étage montre **ce qu'on encaisse** : icône d'insigne + nombre (étages bas), puis coffre
  d'apparence (étages hauts), sommet : coffre d'apparence rare + insignes ; quantités à Équilibrage ;
- à côté de la pyramide, deux lignes fixes : « Si tu t'arrêtes : 120 insignes » · « Si tu montes et
  gagnes : coffre d'apparence » ; l'échec dit ce qui est perdu ;
- le bilan de Survie liste dans « Gardé » les insignes et coffres de l'autel.

---

## 5. Liste finale de nos propositions (coût et ordre)

| Ordre | Proposition | Coût | Dépend de |
|---|---|---|---|
| 1 | **I7** Textes justes, vocabulaire unique, F5-F8 réservés au mode dev, `battlefield` retiré | S | — |
| 2 | **Mémoire des entrées : affichage** (icônes d'enchaînement remplies, 2 pastilles de file, vidage gris, jauge sans zone dorée, option « Désactivée ») | S | Builds (règle et chiffres de la mémoire) |
| 3 | **Aide au combat** en 4 niveaux (accueil, Contrôles, menu pause, étiquette HUD, ligne du bilan, coupée en Ligue / Panthéon), `auto_cancel` séparé d'`auto_combo` | S-M | Builds (niveaux), E6 (journal) |
| 4 | **I5** Bilan commun (gardé / perdu, Rejouer, aide utilisée) | S-M | P1 |
| 5 | **I4** Coffres lisibles : aperçu du contenu, garantie, doublons → insignes, « Ouvrir tout » | S | P1b |
| 6 | **Guide F1 + fiches** (`tip_panel`, `tutorial.gd`), chapitres Commandes (touches réelles) et Nouveautés | M | I7, `unlocks.gd` |
| 7 | **« Nouveau dans cette version »** | S | 6 |
| 8 | **I2** Verrous visibles et fenêtres d'ouverture | S | P2 |
| 9 | **I3** Lobby rangé : barre de ressources, objectif suivant, Atelier | M | P2, P3, P9 |
| 10 | **Accueil** (3 choix, 5 classes, contrôles et aide) + **Premiers pas** (modificateur tutoriel) | M | 3, E1, signaux du héros |
| 11 | **Touches** groupées, « Tester », dispositions de sorts ; libellés Xbox | S | — |
| 12 | **Page Jouer** 3 colonnes, Défi de maîtrise, carte Arènes unique | S-M | M0, E1 |
| 13 | **Page Duel** : sélecteur À armes égales / Héros complet, onglets Ligue · Panthéon · Libre, règles générées, bilan de duel avec durées et plus gros coup | M | E1, `PvpCaps`, M4 |
| 14 | **I8** Lisibilité des builds (icônes d'axe, résumé, « sans effet », jauge d'arme) | S chacune | B1-B3, E7 |
| 15 | **I6** Carnet (succès, titres, Apparences avec Auras, signature par famille) | M | P3, P4 |
| 16 | **Panthéon** : récompenses par cerveau, écran de victoire, coffres d'auras, emplacement Aura | M | P8, Modes |
| 17 | **Autel** en insignes et apparences (affichage) | S | E8 (quantités) |
| 18 | **Manette** réassignable (3e colonne) | M | 11 |
| 19 | **Arènes** : page, alliés IA, portraits, ordre aux alliés | M (+ L côté Modes) | Modes |

**Abandonné** : zone dorée « PARFAIT », ralenti de l'esquive parfaite, épreuve « zone dorée »,
carte Champ de bataille, deux cartes d'Arènes, mini-jeux.

---

## Résumé (6 lignes)

1. **Tutoriel final** : accueil à 3 choix → **5 classes de base** → style de contrôle et niveau d'aide → 1re Survie en Premiers pas (modificateur tutoriel) ; zone dorée et ralenti retirés ; fenêtre « Nouveau dans cette version » pilotée par le champ `version` des fiches.
2. **Constat code** : un appui pendant le verrou de 0,45 s casse l'enchaînement (`_chain_press`, « Trop tôt ») et un appui sur un autre sort pendant une animation est perdu (`is_action_just_pressed`) : c'est là que se creuse le fossé avec l'auto.
3. **Mémoire des entrées lisible** : icônes d'enchaînement qui se remplissent sur la case, 2 pastilles de file au-dessus de la barre, vidage gris à l'esquive, jauge simple sans zone dorée.
4. **Aide au combat officielle** en 4 niveaux (Aucune, Assistée, Sorts auto, Bot) construite sur les réglages existants, visible au HUD et au bilan, sans malus en JcE, **coupée en Ligue et Panthéon**.
5. **Duel** : sélecteur « À armes égales » (une arme, niveau libre dès 1, seul mode de la Ligue et du Panthéon) / « Héros complet » (Libre) ; bilan avec durée des manches et plus gros coup ; une carte Arènes avec alliés IA, 10v10 retiré.
6. **Cosmétiques** : récompenses des cerveaux affichées par colonne au Panthéon, coffres d'apparence et d'auras avec aperçu et garantie, emplacement Aura ; autel en insignes et apparences ; 19 propositions ordonnées, textes et affichage de la mémoire d'abord.
