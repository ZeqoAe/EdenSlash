# Équipe Interface & menus — rapport 1 (jeu 0.1.130)

Périmètre : tous les écrans et menus (écran titre, lobby, page Jouer et pages d'activité, écran Héros,
inventaire, Collection / Armurerie, Coffres, Paramètres, HUD de run, menu pause, choix de cartes,
écrans de fin, Tour, Duel). Le code fait foi ; tout a été lu dans `game/scripts/ui/` et les scripts
`core/` qui écrivent des textes à l'écran (aucun lancement de Godot n'a été nécessaire).
Nous sommes **pilote de l'ajout n°1 du joueur (tutoriel passable)** : proposition I1, traitée à fond.
Nous donnons aussi notre avis sur le déblocage progressif (n°2, proposition I2) et sur le suivi de la
collection et des titres (n°5, proposition I6). Les rapports Progression et Builds ont été lus ; nous
nous appuyons sur leurs propositions (P1 à P9, B1 à B13) sans les répéter.

---

## En bref

**5 constats**
1. **Aucune aide pour un nouveau joueur.** Une nouvelle partie va droit au lobby avec le Guerrier
   (`title_screen.gd:_new` → `Profile.new_game` → lobby). Il n'y a pas de tutoriel, pas d'accueil, pas
   de premier objectif. L'aide existante est cachée (bouton « ? » de l'écran Héros) ou faite pour les
   tests (F1 en run affiche les **touches de triche F5 à F8**, qui marchent en partie normale).
2. **Beaucoup de textes à l'écran sont faux depuis la Survie.** La page Aide « Monnaies et coffres »
   décrit l'ancienne run (« forge ton équipement », 30 coffres « jusqu'à épique / mythique / légendaire »,
   enclume « sur une pièce portée »). Le menu Coffres annonce des coffres « équipement, set, trophée au
   choix » qui ne tombent plus. Le menu pause promet « tu choisiras 1 objet à garder » en Survie.
   Le lobby et l'écran titre parlent de « zones débloquées » et d'« héritage ». Au total, une vingtaine
   de textes (liste en 1.5).
3. **Les fonctions du hub sont mal rangées.** La forge du hub est un bouton dans la fiche d'un objet de
   l'inventaire, l'Armurerie est le 2e onglet de Collection, les insignes et les cristaux ne s'affichent
   pas au lobby, la Tour et le Duel sont au même niveau que la Survie alors qu'ils n'ont pas le même
   rôle. Rien n'indique au joueur où aller ensuite.
4. **Les notes du joueur sur les Coffres sont à moitié traitées.** Le coffre 3D animé et le niveau des
   coffres proportionnel au niveau sont faits. Mais on ne voit toujours pas le contenu d'un coffre de
   forge ou de joaillier avant de l'ouvrir, il n'y a pas d'« Ouvrir tout », et un coffre de set peut
   proposer une pièce déjà possédée. La note sur l'écran de fin (« ne pas proposer de garder un objet
   déjà possédé ») vise un écran que la Survie n'affiche plus : c'est réglé, mais le code mort reste.
5. **Le socle est bon.** Les écrans à pages (`PageScreen`), les grilles filtrables à sélection multiple
   (Ctrl+clic, Maj+clic, Ctrl+A), les cartes à valider, le coffre 3D, les étiquettes d'activité
   illustrées et le signal `RunDirector.message` sont réutilisables tels quels pour le tutoriel, les
   fiches de déblocage et le Carnet. Pas besoin de refonte.

**Propositions phares** : I1 tutoriel passable en 3 couches, « Premiers pas », fiches de découverte et
Guide (**M**) · I2 présentation du déblocage progressif : verrous visibles, pastilles « Nouveau »
(**S**, avec P2) · I3 lobby rangé, avec une barre de ressources et un objectif suivant (**M**) · I4 menu
Coffres lisible, avec « Ouvrir tout » (**S**) · I5 écrans de fin refaits, avec « Rejouer » (**S**) ·
I6 Carnet, succès et titres : où et comment les montrer (**M**, avec P3 et P4) · I7 nettoyage des
textes faux et des touches de triche (**S**).

---

## 1. État des lieux

### 1.1 Carte des écrans aujourd'hui

```
ÉCRAN TITRE (scenes/title.tscn, ui/title_screen.gd)
 ├─ Jouer ─► Continuer · Charger (3 emplacements) · Nouvelle partie ──► LOBBY (Guerrier, sans accueil)
 ├─ Paramètres (SettingsMenu)      └─ Quitter
LOBBY (scenes/lobby.tscn, ui/lobby.gd) : héros en 3D dans la map de la zone, menu de gauche
 ├─ Jouer ─► activités (ui/activities.gd, lobby.gd:_menu_play)
 │    ├─ JcE : Survie (_menu_survival : époque I-IV, Lancer) · La Tour (_menu_tower → _menu_tower_floors :
 │    │        4 difficultés, 200 étages par pages de 10, fiche « i ») · Donjons (Bientôt)
 │    ├─ JcJ : Duel (_menu_duel : conditions ✔/✘ + « Régler », adversaire, difficulté, IA ou cerveau,
 │    │        éditeur d'adversaire ProfileEditor, préparation rapide DuelPrep) · Arènes 2v2, 3v3,
 │    │        Champ de bataille (Bientôt)
 │    └─ Zone d'entraînement (_menu_training, panneau F3 : ui/training_panel.gd)
 ├─ Héros ─► HeroScreen (ui/hero_screen.gd) : Équipement (InventoryPage, avec la forge du hub dans la
 │           fiche d'objet) · Classe (TalentsPage : talents, parcours de maîtrise, plateau des
 │           certificats ; bouton Grimoire) · Apparence (HeroPages.AppearancePage) · Cartes
 │           (HeroPages.CardsPage) · « ? » (InfoPage : guide des statistiques)
 ├─ Coffres (n) ─► PageScreen « Coffres » : ChestsPage + ChestStage (coffre 3D animé)
 ├─ Collection ─► PageScreen : Collection (ArchivePages.CollectionPage) · Armurerie (GearShopPage)
 ├─ Paramètres ─► SettingsMenu : Mode de jeu (préréglages, jeu automatique) · Combat · Touches ·
 │                 Affichage · Son · Caméra (+ Interface, mode dev)
 ├─ Quitter ─► Écran titre · Quitter le jeu
 └─ badge de classe (haut droite, menu des classes) · cadre « zone + prochaine récompense de
    maîtrise » (bas gauche) · pied de page « sauvegarde, héritage, runs » · bouton Mode dev (F10)
RUN (scenes/world.tscn, core/world.gd)
 ├─ HUD (ui/hud.gd, hud_widgets.gd, minimap.gd) : orbe de vie, 4 sorts, esquive, orbe d'XP, buffs,
 │   objectifs repliés (Tab), cible, mini-carte (M : grande carte), bandeau de messages, fil de butin
 ├─ Choix de cartes (ui/card_picker.gd) : tous les choix de la run (niveau, coffres d'emplacement,
 │   arme de départ, arme secondaire, trophées, enclume) ; Valider, Bannir, Garder, Relancer
 ├─ Autel de la fortune (ui/fortune_popup.gd) · Marchands (merchant_ui.gd, merchant_pages.gd)
 ├─ Menu pause (ui/pause_menu.gd) : Run (run_page.gd) · Héros (InventoryPage) · Aide (InfoPage) ;
 │   Grimoire et Paramètres par-dessus ; Reprendre, S'extraire, Abandonner
 ├─ F1 : aide des touches (ui/test_tools.gd:help_text) · F9 : signaler · Alt+clic droit : note
 └─ Fin : ResultsScreen (Survie) · TowerResults · DuelResults ──► LOBBY
```

### 1.2 Écran par écran

| Écran | Fichier, fonctions | Ce qui marche | Ce qui ne va pas |
|---|---|---|---|
| **Écran titre** | `title_screen.gd:_show_root`, `_slot_card`, `_new` | survol 3D des maps, 3 emplacements, confirmation avant d'écraser | résumé « Zones débloquées 3 / 8 · héritage N objet(s) » (vestiges) ; rien ne résume l'avancement réel (époques, classes, complétion) ; « Nouvelle partie » ne propose ni accueil ni classe |
| **Lobby** | `lobby.gd:_build_ui`, `_refresh_ui`, `_on_menu`, `_show_menu` | héros en 3D, caméra libre, badge de classe, barre « prochaine récompense de maîtrise » | cadre de zone périmé (`_zone_sub` : « zone 3 / 8 · N débloquée(s) ») ; pied de page « héritage » ; **insignes et cristaux invisibles** ; pas d'objectif suivant ; la forge du hub n'a pas d'entrée |
| **Jouer, activités** | `activities.gd:LIST`, `card`, `banner` ; `lobby.gd:_menu_play`, `_activity_head` | étiquettes illustrées, « Bientôt », retour « ‹ Activités » | pas de verrou possible (aucun champ `locked`) ; texte de la Tour faux (« avec une arme de base ») ; rien n'indique les récompenses de chaque activité |
| **Survie** | `lobby.gd:_menu_survival` | époques verrouillées visibles avec leur condition (bon modèle pour I2) | aucun rappel de ce que la run rapporte ; pas de record par époque |
| **La Tour** | `lobby.gd:_menu_tower`, `_menu_tower_floors` ; `tower_pages.gd` | record par difficulté, pages de 10 étages, fiche d'étage | coffres d'apparence des étages 50/100/150/200 non annoncés ; 4 difficultés ouvertes d'emblée |
| **Duel** | `lobby.gd:_menu_duel` ; `duel.gd:requirements` ; `duel_prep.gd` ; `profile_editor.gd` | conditions ✔/✘ avec bouton « Régler » qui ouvre la bonne section (excellent modèle de guidage) | 3 listes déroulantes côte à côte (classe, difficulté, IA) peu lisibles ; les cerveaux sont un simple choix sans enjeu ; « points de maîtrise » pour les points de talent |
| **Héros** | `hero_screen.gd:SECTIONS` (Équipement, Classe, Apparence, Cartes) + « ? » | tout le héros au même endroit, classe choisie en haut à droite | l'aide « ? » est la seule aide du lobby et elle ne parle que des statistiques ; Grimoire caché dans Classe ; la forge du hub cachée dans la fiche d'objet |
| **Inventaire** | `inventory_page.gd` (familles, recherche, tri, fiche, Équiper / Forge / Démonter) | complet, glisser-déposer, comparaison | en Survie, la forge est refusée avec un message de 3 s (`inventory_page.gd:973`) : il faudrait le dire avant le clic |
| **Collection** | `archive_pages.gd:CollectionPage` ; `gear_shop_page.gd` | archive façon Eden, catégories, paliers | l'Armurerie, débouché principal des insignes, est un onglet caché ; elle vend des trophées ; pas de filtre « pas encore acheté » ni « de ma classe » ; achat un par un |
| **Coffres** | `chests_page.gd:_row`, `_preview`, `open_chest`, `_show_loot`, `_show_choices` ; `chest_stage.gd` | coffre d'Eden en 3D, ouverture animée avec éclat de lumière, contenu qui apparaît pièce par pièce | voir 1.4 : contenu invisible avant ouverture, pas d'« Ouvrir tout », textes faux, set qui propose des pièces déjà possédées |
| **Paramètres** | `settings_menu.gd` (6 onglets) | préréglages de mode de jeu, jeu automatique bien expliqué, touches réassignables | pas de réglage « tutoriels » ni « réinitialiser les conseils » |
| **HUD** | `hud.gd`, `hud_widgets.gd`, `minimap.gd` | lisible, objectifs repliés, bandeau `show_message`, fil de butin | aucun emplacement prévu pour un conseil non bloquant ; la barre d'enchaînement n'a pas de zone à viser (Builds B7) |
| **Choix de cartes** | `card_picker.gd:offer`, `_make_card`, `_confirm_choice` | sélection puis Valider (anti-spam), 1/2/3 + Entrée, Bannir / Garder / Relancer, totaux avant → après | aucun résumé du build (Builds B2) ; aucune explication de la rareté, de Bannir ou de Garder la 1re fois |
| **Menu pause** | `pause_menu.gd:setup` ; `run_page.gd` ; `info_page.gd` | page Run complète (12 sorts, armes, trophées, cartes) | texte d'abandon faux en Survie ; page Aide périmée (voir 1.3) |
| **Écrans de fin** | `results_screen.gd:show_results` ; `tower_results.gd` ; `duel_results.gd` | tuiles de chiffres, maîtrise gagnée, déblocages | vestige « Nouvelle zone débloquée » au lieu de l'époque ; pas de « Rejouer » ; ~120 lignes de branche « héritage » mortes (`_item_button`, `_select`, `Profile.end_run`, `end_run_extract`) ; trois écrans de fin de styles différents |

### 1.3 Ce qui explique le jeu aujourd'hui (la base du tutoriel)

| Source | Où | Contenu | État |
|---|---|---|---|
| Messages de bandeau | `run_director.gd` (`message.emit`, ~25 messages) → `hud.gd:show_message` | début de carte (« Tu pars sans équipement : ouvre les coffres de la carte, puis trouve le donjon »), sceaux, rage, marchand, donjon | bon canal, mais 2 à 4 s et rien d'enregistré : un message raté est perdu |
| Invites d'action | `run_director.prompt_changed` → `hud.gd:show_prompt` | « [F] … » près des objets | bon |
| Aide F1 en run | `test_tools.gd:help_text` | touches de déplacement, saut, esquive, sorts ; **puis les touches de test F5 (+1 niveau), F6, F7, F8 (rage)** | les triches sont actives pour tout le monde (`test_tools.gd:_unhandled_input`, aucune condition sur le mode dev) |
| Page Aide (pause) et « ? » (Héros) | `info_page.gd:SECTIONS` (8 sections) | formules des stats, des dégâts, de la défense ; « Monnaies et coffres » ; « Survie » ; « Équipement » | « Monnaies et coffres » (`_money`) décrit l'ancienne run ; « Équipement » (`_gear`) donne l'ancien bonus d'archive ; c'est une aide de calcul, pas une aide de jeu |
| Infobulles | partout (`ItemWidgets.item_card`, `SpellInfo`, `TalentsPage.cert_tip`, cartes) | très détaillées | bonnes pour l'expert, trop denses pour un débutant |
| Conditions du Duel | `lobby.gd:_menu_duel` | liste ✔/✘ avec bouton « Régler » | **le meilleur exemple de guidage du jeu**, à généraliser |
| 1re carte de Survie plus douce | `run_director.gd:ZONE_DAMAGE` (dégâts des monstres ×0,55 sur la 1re map) | commentaire « la première carte sert de tutoriel » | en Survie l'indice est `Run.stage - 1` : **chaque époque** a sa 1re map adoucie (à vérifier par Équilibrage) |

### 1.4 Notes du joueur sur les Coffres et l'écran de fin : vérification dans le code

| Note (version) | Aujourd'hui (0.1.130) | Reste à faire |
|---|---|---|
| « Coffre équipement et forge : on ne voit pas ce qu'on choisit », « joaillier non plus » (0.1.116) | **À moitié.** Après ouverture, le contenu s'affiche en tuiles animées (`chests_page.gd:_show_loot`). Avant, la ligne ne montre que le nom et une phrase (`Rewards.TYPES.desc`). Les coffres d'équipement et de set ne tombent plus en Survie (seulement l'autel de la fortune, `fortune.gd:61`) | montrer le contenu possible avant ouverture (fourchettes et icônes) et le niveau du coffre ; rendre lisibles les coffres d'apparence (rareté possible) → I4 |
| « Améliorer la page, coffres plus jolis, animation d'ouverture qui brille » (0.1.116) | **Fait** : `chest_stage.gd` (coffre d'Eden `uc020` en 3D sur un halo de la couleur du type, il tremble, s'ouvre en `uc020_1` dans un éclat de lumière, signal `burst`) | la liste de gauche garde une icône plate teintée ; un récapitulatif pour plusieurs coffres |
| « Coffres proportionnels au niveau, j'ai des trophées 90 » (0.1.116) | **Fait** : niveau du coffre = `loot_level(niveau du monstre)` (`run_director.gd:679`), objets de la zone d'origine (`Rewards.zone_of`). Les coffres de trophées n'existent plus (0.1.130) | afficher « niv. N » sur chaque coffre |
| « Écran de fin : ne pas proposer de garder un objet déjà possédé (la hache de base) » (0.1.117) | **Réglé par la Survie** : `results_screen.gd` prend toujours la branche `Run.survival` (bilan sans choix). Le choix « héritage » n'est plus jamais affiché | supprimer la branche morte (I5, Progression P1f). **Même problème ailleurs** : `Rewards.offer` (coffre de set) peut proposer une pièce déjà dans le coffre commun ou l'archive → I4 |
| Autel de récompense en pyramide (8 étages, quitte ou double) (0.1.117) | **Fait** : `fortune.gd`, `fortune_popup.gd` | — |
| Monstres bloqués par le décor (0.1.117) | hors interface (Équilibrage, Modes) | — |

### 1.5 Textes faux ou vestiges à l'écran (code fait foi)

| Où | Texte actuel | Pourquoi c'est faux |
|---|---|---|
| `info_page.gd:_money` | « 3 étapes : la zone choisie, puis des zones à ta hauteur… forge ton équipement… 30 coffres : une pièce au choix parmi 3, coffre (jusqu'à épique), ouvragé, doré… enclume (+1 garanti sur une pièce portée)… Forge (Échap > Héros) » | Survie : époques de 3 maps, coffres d'emplacement (`slot_chests.gd`), enclume par emplacement (`Run.slot_bonus`), forge bloquée en Survie |
| `info_page.gd:_money` (tableau) | Cristaux « démonter un objet » ; coffres de récompense « mythiques et légendaires, sets, trophées », « gardés si tu t'en sors » | coffres toujours gardés (`run.gd:pick_up`) ; plus de sets ni trophées en Survie |
| `info_page.gd:_gear` | « Archive : +1 / +2 / +4 points d'attribut par entrée » | paliers de `Archive.MILESTONES` |
| `chests_page.gd:_ready` | « Gardés si tu t'en sors (victoire ou extraction). Les objets vont au coffre commun, les fournitures à la réserve de la prochaine run » | coffres toujours gardés ; réserve à revoir (Progression P1a) |
| `lobby.gd:_build_ui` (titre de Coffres) | « équipement, forge, joaillier, set au choix, trophée au choix » | apparences, forge, joaillier aujourd'hui |
| `lobby.gd:_refresh_ui` | « zone 3 / 8 · N débloquée(s) » ; « héritage N objet(s) » | époques ; coffre commun |
| `title_screen.gd:_slot_card` | « Zones débloquées N / 8 · héritage N objet(s) » | idem |
| `pause_menu.gd:setup` | « La run sera abandonnée : tu choisiras 1 objet à garder » | en Survie aucun choix ; fournitures du sac perdues |
| `results_screen.gd:show_results` | « Nouvelle zone débloquée : … » | l'époque débloquée n'est pas annoncée |
| `activities.gd:LIST` (Tour) | « Gravis les étages avec une arme de base » | préréglage d'équipement |
| `gear_shop_page.gd` | « collection, JcJ non normalisé » | le Duel est normalisé |
| `lobby.gd:_menu_duel`, `duel.gd:requirements` | « points de maîtrise » | points de talent |
| `test_tools.gd:help_text` | touches F5 à F8 dans l'aide du joueur | touches de test, à réserver au mode dev |
| En-têtes de code (pas visibles, mais trompeurs pour les sessions) | `grimoire.gd` (« combo de l'arme coup par coup »), `profile_editor.gd` (« Jouer > Profils types »), `results_screen.gd`, `rewards.gd` (« seule source des mythiques ») | refontes 0.1.122 à 0.1.130 |

### 1.6 Confort déjà en place (à garder et à généraliser)

- Grilles d'objets : filtres rareté / emplacement, tri, sélection multiple (clic, Ctrl+clic, Maj+clic,
  Ctrl+A), « sélectionner jusqu'à la rareté N » (`item_widgets.gd:ItemGrid`).
- Glisser-déposer pour équiper, double-clic, clic droit (`equipment_page.gd`, `inventory_page.gd`).
- Choix de carte en deux temps (clic puis Valider) contre les clics accidentels (`card_picker.gd`).
- Conditions ✔/✘ avec « Régler » (Duel).
- Échap ferme la fenêtre du dessus avant l'écran (`page_screen.gd:_input`, `hero_screen.gd`).
- Alt+clic droit : note du joueur (`feedback.gd`). F9 : signalement de carte.
- Jeu automatique complet (Paramètres > Mode de jeu), utile pour un joueur qui découvre.

**Ce qui manque en confort** : actions groupées dans les Coffres (« Ouvrir tout ») et à l'Armurerie
(achat multiple), « Rejouer » en fin de run, un rappel des ressources au lobby.

---

## 2. Problèmes et opportunités (du plus important au moins important)

1. **Personne n'explique le jeu** (demande n°1 du joueur). Le jeu a beaucoup de systèmes : 2 variantes
   d'arme, 12 sorts en 4 cases avec enchaînements, annulation parfaite, cartes avec rareté, bannir,
   garder et relancer, coffres d'emplacement, enclume, 12 trophées, arme secondaire, sceaux, rage,
   autels, puis au hub la maîtrise, les talents, le plateau, l'Armurerie, la forge, l'archive, la Tour,
   le Duel. Un nouveau joueur n'a qu'un bandeau de 4 s au début de la carte. → **I1**.
2. **Textes faux** : la seule page d'aide décrit l'ancien jeu, et plusieurs écrans annoncent des
   règles qui n'existent plus. Un tutoriel bâti sur ces textes enseignerait des erreurs. → **I7**
   (à faire avant ou avec I1).
3. **On ne sait pas où aller ni quoi viser** : pas de ressources au lobby, forge et Armurerie cachées,
   pas d'objectif suivant, Tour et Duel ouverts d'emblée au même rang que la Survie. → **I3**, **I2**, **I6**.
4. **Menu Coffres** : notes du joueur à moitié traitées (contenu invisible avant ouverture, pas
   d'action groupée, pièces déjà possédées proposées). → **I4**.
5. **Écran de fin** : il n'annonce pas l'époque débloquée, ne dit pas clairement ce qui est gardé ou
   perdu, n'a pas de « Rejouer » ; 3 écrans de fin de styles différents ; code mort. → **I5**.
6. **Déblocage progressif et collection** (ajouts n°2 et n°5) : il faut des règles d'affichage
   communes (verrou visible, pastille « Nouveau », fiche d'ouverture, suivi de la complétion,
   titres) pour que les propositions de Progression soient lisibles. → **I2**, **I6**.
7. **Lisibilité des nouveautés de build en run** (Builds B1, B2, B7) : icônes d'axe, résumé du build,
   « sans effet sur ton build », zone dorée de l'enchaînement. → **I8**.
8. **Confort** : achat multiple, « Ouvrir tout », filtres de l'Armurerie, menu Duel chargé. → **I9**.
9. **Triche accessible** : F5 à F8 marchent en partie normale et sont listées dans l'aide F1. → **I7**.

---

## 3. Propositions

### ★ I1 — Tutoriel passable : « Premiers pas », fiches de découverte et Guide (pilote, coût M)

**Intérêt pour le joueur** : un débutant comprend le jeu en jouant, sans long tutoriel à subir ; un
joueur qui connaît passe tout d'un clic ; un expert (ou le joueur actuel) retrouve chaque règle dans
un Guide à jour. Et chaque **nouveauté** du jeu (Donjons, succès…) arrive avec sa fiche, ce qui sert
aussi au joueur qui teste chaque version.

**Principes**
- On apprend **dans la vraie Survie**, sur la 1re map de l'époque I (déjà adoucie : dégâts des
  monstres ×0,55, `run_director.gd:ZONE_DAMAGE`), pas dans une map de tutoriel à part (coût L et à
  maintenir à chaque refonte).
- **Jamais bloquant en combat** : aucune fenêtre qui met en pause au milieu d'une horde. Les fiches
  s'ouvrent quand le jeu est déjà en pause (choix de cartes, coffre, bilan, lobby) ou au calme.
- **Une chose à la fois, au moment où elle sert** : la fiche « Enclume » arrive à la 1re enclume, pas
  avant.
- **Passer à tout moment**, à 3 niveaux (tout, les Premiers pas, une fiche). **Passer ne débloque
  rien** et ne bloque rien : cela coupe seulement les explications (accord avec Progression P2.4).
- **Tout se relit** dans le Guide (F1, menu pause, lobby).

**Couche 0 — Accueil d'une nouvelle partie** (coût S)
- Après « Nouvelle partie » (`title_screen.gd:_new`), une fenêtre à 2 gros boutons :
  « **Je découvre Eden Slash** (conseils et Premiers pas) » / « **Je connais déjà** (passer les
  tutoriels) ». Le choix règle `Settings.interface.tutorials` (voir plus bas), modifiable ensuite.
- (Question au joueur) Choix de la classe de départ parmi les 5 classes de base, avec 3 étiquettes
  (mêlée / distance, arme, rôle ; Builds B11), au lieu du Guerrier imposé (`Progression.START_CLASS`).
- Au lobby, en mode guidé : seul « Jouer » brille (pastille), et le cadre du bas affiche l'objectif
  « Lance ta première Survie ».

**Couche 1 — « Premiers pas » : une liste d'étapes dans la 1re run** (coût M)

Un petit panneau sous les objectifs du HUD (`hud.gd:_build_objectives`) avec l'étape en cours et sa
touche réelle (lue dans `Settings.action_label`, comme `test_tools.gd:help_text`). Chaque étape se
valide **en la faisant** ; une étape déjà faite par le joueur avant qu'on la demande est cochée seule.
En-tête : « Premiers pas 3 / 10 · Passer ».

| # | Étape (texte à l'écran) | Validée quand | Fiche liée |
|---|---|---|---|
| 1 | « Choisis ton arme : chacune a 2 façons d'attaquer » (au départ, choix des 2 variantes) | arme choisie (`run_director.gd:start_weapon_cards`) | Armes et variantes |
| 2 | « Déplace-toi avec [Z Q S D] et frappe en restant près des monstres » | 10 monstres tués | Auto-attaque |
| 3 | « Saute avec [Espace] » | 1 saut | — |
| 4 | « Esquive avec [Maj] : tu es invulnérable pendant la roulade » | 1 esquive | Esquive |
| 5 | « Niveau 2 : choisis une carte, puis Valider » | 1re carte prise | Cartes |
| 6 | « Lance ton sort avec [1] » | 1 sort lancé | Sorts |
| 7 | « Enchaîne : rappuie sur [1] pendant que la barre se remplit (+20 %) » | 1 enchaînement | Enchaînements |
| 8 | « Ouvre un coffre d'emplacement (or ou clé) » | 1 coffre de la carte ouvert | Coffres d'emplacement |
| 9 | « Bats un gardien d'élite : il porte un sceau (3 pour ouvrir le donjon) » | 1 sceau | Sceaux et donjon |
| 10 | « Entre dans le donjon et bats le boss » | boss de la map 1 vaincu | Boss, portail, étapes |

Ensuite le panneau disparaît (« Premiers pas terminés : le Guide [F1] garde toutes les règles »).
Pour aller plus loin (annulation parfaite, esquive aérienne, zone dorée si Builds B7), on renvoie vers
l'**Académie** (couche 4). Pas d'étape chronométrée, pas d'échec possible : si le héros tombe, la liste
reprend à la run suivante où elle en était.

**Couche 2 — Fiches de découverte** (coût M ; l'essentiel du travail est l'écriture)

Une fiche = une image (écran de chargement d'Eden ou icône du jeu), un titre, **3 lignes au plus**, et
3 boutons : « Compris », « Plus de détails » (ouvre le Guide au bon chapitre), « Ne plus afficher de
conseils ». Elle s'affiche **une seule fois par sauvegarde**, à la 1re occurrence de son déclencheur.

| Où | Déclencheur (1re fois) | Fiche |
|---|---|---|
| Run | 1er choix de cartes | Cartes : rareté (couleur), Valider, Bannir, Garder, Relancer |
| Run | 1re carte d'amélioration d'arme | L'arme grandit : 8 niveaux, l'effet légendaire de la variante |
| Run | 1re carte légendaire, 1re évolution | Cartes légendaires et évolutions (prérequis) |
| Run | 4 cases de sorts pleines | Enchaînements : 2 sorts de plus par case, 12 en tout, preset du Grimoire |
| Run | 1re annulation parfaite (ou 30 sorts lancés sans en faire) | Annulation parfaite et Fluidité |
| Run | 1er coffre de trophée | Trophées : 12 au plus, tous différents, perdus en fin de run |
| Run | 1re arme secondaire | Arme secondaire : frappe seule, 60 % des dégâts |
| Run | 1re enclume | Enclume : +1 sur un emplacement, une fois par map |
| Run | 1er autel du scribe, fontaine, pierre d'aimant, autel de cupidité, stèle du défi | une fiche par lieu à usage unique |
| Run | 1er autel de la fortune | Quitte ou double : 8 étages, encaisser ou monter |
| Run | 1er marchand | Marchands : cartes, clés, fournitures ; l'or ne sort pas de la run |
| Run | 1er sanctuaire | Sanctuaires : reste dans le cercle |
| Run | 1er coffre de récompense ramassé | Coffres de récompense : jamais perdus, à ouvrir au lobby |
| Run | rage (10 min) | La rage : plus dur, plus de butin |
| Run | 1er K.O. | Résurrections, abandon, ce que l'on garde |
| Run | 1er portail | Étapes : on garde niveau, cartes et équipement |
| Lobby | 1er bilan de Survie | Ce que tu gardes : maîtrise, insignes, pièces découvertes |
| Lobby | 1er niveau de maîtrise | Talents et parcours de maîtrise |
| Lobby | 1er certificat | Plateau des certificats et couleurs |
| Lobby | 1re pièce découverte, 1ers insignes | Armurerie |
| Lobby | 1er coffre dans le menu Coffres | Menu Coffres |
| Lobby | 1re classe débloquée | Classes et familles |
| Lobby | 1re carte débloquée | Cartes à débloquer (Héros > Cartes) |
| Lobby | ouverture d'un contenu (Progression P2 : Forge, Tour, Duel, Donjons, rangs héroïques, Panthéon…) | **fiche d'ouverture** « Nouveau : la Forge » avec « Y aller » (voir I2) |
| Activité | 1re ouverture de la Tour, du Duel, de l'entraînement, des Donjons | règles de l'activité en 3 lignes + ce qu'elle rapporte |

**Affichage selon la situation**
- Jeu **déjà en pause** (choix de cartes, coffre, fortune, bilan, lobby) : la fiche s'ouvre à côté de
  la fenêtre (à gauche du choix de cartes, `card_picker.gd`), sans la cacher.
- Jeu **en action** : une petite pastille « Nouveau conseil : Enclume [F1] » s'affiche 4 s dans le fil
  du HUD (`hud.gd:feed`). La fiche s'ouvre au prochain moment calme (aucun monstre à moins de ~15 m
  pendant 3 s) ou à la prochaine pause. **Jamais pendant un combat de boss ou en Duel.**
- Une seule fiche à la fois ; les suivantes attendent (file).

**Couche 3 — Le Guide (refonte de la page Aide)** (coût S à M)
- `InfoPage` devient le **Guide**, avec des chapitres au lieu d'un seul bloc de formules :
  Commandes · Combat (auto-attaque, armes et variantes, sorts, enchaînements, annulation parfaite,
  esquive, saut) · Cartes · Survie (époques, carte, coffres d'emplacement, enclume, trophées, arme
  secondaire, lieux, sceaux, rage, boss, résurrections, extraction, ce que l'on garde) · Hub
  (maîtrise, talents, certificats, Armurerie, coffres, forge, archive, apparences) · Activités (Tour,
  Duel, entraînement, Donjons…) · Formules (les sections actuelles : attributs, statistiques, dégâts,
  défense, équipement, « Tes valeurs »).
- Chaque fiche de découverte **est** une entrée du Guide (même texte, plus une partie « En détail »).
  Une fiche pas encore vue est marquée « nouveau » ; une fiche d'un contenu verrouillé est affichée
  « ??? — se débloque : … » (pas de surprise gâchée, mais l'objectif est visible).
- **Accès** : F1 partout (en run, il ouvre le Guide en pause au chapitre Commandes), onglet « Aide » du
  menu pause, entrée « Guide » du lobby (I3), bouton « ? » de l'écran Héros.
- F1 n'affiche plus les touches de test ; elles passent dans l'écran du mode dev (I7).

**Couche 4 — L'Académie dans la Zone d'entraînement** (coût M, plus tard)
- La Zone d'entraînement (`training.gd`, `training_panel.gd`, mannequins et adversaires réglables)
  reçoit un onglet « Leçons » : les 10 Premiers pas à rejouer, puis des leçons d'expert (annulation
  parfaite en série, esquive aérienne, enchaînement parfait si B7, esquive parfaite défensive si B7,
  duel contre un héros scripté). Chaque leçon a un objectif chiffré et une médaille (bronze, argent,
  or) qui peut compter pour les succès (P4). C'est le « hard to master » rendu apprenable.

**Réglages et « passer »**
- Paramètres > Interface : **Tutoriels : Complets / Conseils seulement (sans Premiers pas) / Aucun**,
  et le bouton « **Revoir tous les tutoriels** » (remet les fiches à zéro pour cette sauvegarde).
- « Passer » dans l'en-tête des Premiers pas et dans le menu pause pendant la 1re run.
- « Ne plus afficher de conseils » sur chaque fiche (= Aucun ; les fiches restent dans le Guide).
- **Fiches d'ouverture et de nouveauté** : elles restent affichées même en mode « Aucun »
  (une seule fenêtre courte avec « Y aller »), car elles annoncent du contenu, pas une explication.
  Une case « Aussi masquer les nouveautés » pour qui n'en veut vraiment pas.

**Sauvegardes existantes (le joueur)**
- Au 1er chargement d'une sauvegarde qui a déjà des runs (`Profile.runs_done > 0`) : tutoriels
  réglés sur « Aucun », toutes les fiches marquées vues **sauf** celles des contenus nouveaux depuis
  (succès, Donjons…), et une seule fenêtre : « Nouveau : le Guide (F1) rassemble toutes les règles ».

**Règles techniques (pour le découpage, sans code ici)**
- Une table de données `core/tutorial.gd` : identifiant, chapitre, titre, texte (BBCode, touches
  écrites `{jump}` et remplacées par `Settings.action_label`), image, déclencheur, page à ouvrir,
  priorité, « nouveauté de la version X ». Une fonction d'entrée unique `Tutorial.event("enclume")`.
- `Profile.tips_seen` (par sauvegarde) et `Settings.interface.tutorials` (global).
- Points d'appel : la plupart des déclencheurs ont déjà un `message.emit` dans `run_director.gd`
  (enclume, marchand, rage, sceau, donjon, coffre de récompense) ; `card_picker.gd:offer` ;
  `world.gd` (K.O.) ; `lobby.gd:_show_menu` (1re ouverture d'activité) ; `results_screen.gd`.
- Pour les Premiers pas, le joueur n'émet que 4 signaux (`player.gd` : xp, niveau, sorts, stats) :
  il faut des signaux « saut, esquive, sort lancé, enchaînement, annulation parfaite » (ou lire les
  compteurs `Profile.records`). **Aucune observation de l'arène d'IA n'est touchée.**
- Un seul composant d'affichage `ui/tip_panel.gd`, utilisé au lobby et en run.
- Textes : ~40 fiches à écrire en français simple, avec le vocabulaire unique de Progression P3
  (maîtrise, points de talent, coffre commun, insignes).
- Mode dev et tests (`--autoplay`, captures) : tutoriels coupés d'office.

**Ordre de réalisation conseillé** : I7 (textes justes) → Guide (couche 3) → fiches (couche 2) avec les
fiches d'ouverture de P2 → accueil (couche 0) → Premiers pas (couche 1) → Académie (couche 4).

**Touche** : nouveaux `core/tutorial.gd`, `ui/tip_panel.gd`, `ui/first_steps.gd` ; `info_page.gd`
(Guide) ; `hud.gd` ; `card_picker.gd` ; `run_director.gd` (appels) ; `player.gd` (signaux) ;
`world.gd` ; `lobby.gd` ; `title_screen.gd` ; `settings_menu.gd`, `settings.gd` ; `profile.gd` ;
`test_tools.gd` ; plus tard `training_panel.gd`.
**Dépendances** : Progression (table P2 et ses conditions = fiches d'ouverture ; vocabulaire P3 ;
médailles de l'Académie dans les succès P4) ; Modes (règles et textes de la Tour, du Duel, des
Donjons, des arènes ; place de l'Académie dans l'entraînement) ; Builds (textes des armes, des
enchaînements, de l'annulation parfaite ; zone dorée B7) ; Équilibrage (garder la 1re map adoucie ;
la limiter à l'époque I).

### ★ I2 — Présenter le déblocage progressif (avis sur l'ajout n°2, coût S en plus de P2)

**Notre avis sur P2 (Progression)** : d'accord sur le principe et presque tout l'ordre. Quatre remarques :
1. **Ne jamais cacher, toujours griser** : une entrée verrouillée reste à sa place, avec un cadenas,
   sa condition et son avancement (« La Tour · termine l'Époque I » ; « Duel · 2 / 3 duellistes de la
   Tour battus »). Le modèle existe déjà : les époques de `lobby.gd:_menu_survival`.
2. **La Zone d'entraînement reste ouverte d'emblée** : c'est l'Académie (I1, couche 4).
3. **La Forge du hub** n'a pas d'entrée aujourd'hui (boutons dans la fiche d'objet). La verrouiller
   suppose de lui donner une entrée (I3) ; d'ici là, griser les boutons avec la condition en infobulle.
4. **L'Armurerie s'ouvre dès le 1er bilan** (P2 n°4) : il faut alors la sortir de l'onglet caché de
   Collection (I3), sinon le joueur ne la trouve pas.

**Règles d'affichage communes**
- **Verrou** : carte d'activité ou bouton grisé (comme « Bientôt »), cadenas, condition en 1 ligne,
  barre d'avancement si elle est chiffrable. Clic : la fiche de l'activité (« Ce que c'est · comment
  l'ouvrir »), jamais rien.
- **Pastille « Nouveau »** (point doré) sur le bouton du menu de gauche, la carte d'activité, la
  section de l'écran Héros ou l'onglet concerné, jusqu'à la 1re visite (`Profile.seen_unlocks`, P2.3).
- **Fenêtre d'ouverture** au retour au lobby, après le bilan (jamais en run) : image, « Nouveau : la
  Tour », 3 lignes, « Y aller » / « Plus tard ». Plusieurs ouvertures d'un coup : une fenêtre avec la
  liste. C'est la fiche du tutoriel (I1) : un seul système.
- **Bilan** : une ligne « Débloqué : … » qui annonce l'ouverture (avec la fenêtre ensuite au lobby).
- **Mode dev** : tout ouvert (déjà prévu par P2.3).

**Touche** : `activities.gd` (champ de verrou, dessin dans `card`), `lobby.gd` (`_menu_play`,
`_on_menu`, pastilles des `SideButton`), `menu_widgets.gd` (pastille), `hero_screen.gd` (sections),
`results_screen.gd`. **Dépendances** : Progression (table `core/unlocks.gd`), Modes (conditions).

### I3 — Un lobby rangé : ressources, objectif suivant, une place pour chaque fonction (coût M)

**Intérêt** : le joueur voit d'un coup d'œil ce qu'il a, où il va, et chaque fonction a sa porte.

**Règles**
- **Menu de gauche** (`lobby.gd:MENU`) : Jouer · Héros · **Atelier** · Coffres (n) · **Collection** ·
  **Guide** · Paramètres · Quitter.
  - **Atelier** (nouveau) : onglets **Forge** (la forge du hub, aujourd'hui dans la fiche d'objet de
    l'inventaire : liste du coffre commun à gauche, page de forge `MerchantPages.ForgePage` à droite),
    **Armurerie** (sortie de Collection), **Réserve** (fournitures gardées). C'est là que vont les
    insignes, les cristaux et les fournitures.
  - **Collection** devient le lieu de « tout collectionner » (I6).
  - **Guide** (I1).
- **Barre de ressources** en haut, à gauche du badge de classe : insignes, cristaux, fournitures,
  coffres à ouvrir. Un clic ouvre la page qui les dépense.
- **Cadre du bas à gauche** : la zone (vestige) est remplacée par l'**objectif suivant** (les 1 à 3
  déblocages les plus proches calculés par le Carnet, Progression P3), et garde la barre de maîtrise.
- **Badge de classe** : le titre porté s'affiche sous le nom (I6).
- **Pied de page** : « Sauvegarde 1 · 42 runs, 12 victoires · complétion 18 % » (plus d'« héritage »).
- **Bouton Jouer** : un 2e clic sur « Jouer » propose « Relancer : Survie, Époque II » (dernière
  activité lancée), pour enchaîner les runs en un clic.
- **Page de chaque activité** : une ligne « Rapporte : … » (d'après Progression P5) et le record
  (meilleure époque, étage, victoires).

**Touche** : `lobby.gd` (`MENU`, `_build_ui`, `_refresh_ui`, `_menu_*`), nouvelle page Atelier
(réutilise `inventory_page.gd:_lobby_forge`, `merchant_pages.gd:ForgePage`, `gear_shop_page.gd`),
`menu_widgets.gd`. **Dépendances** : Progression (Carnet P3, gains P5, insignes au lobby), Modes.

### ★ I4 — Menu Coffres lisible (notes du joueur, coût S)

**Règles**
- **Voir avant d'ouvrir** : chaque ligne de coffre affiche son niveau (« niv. 24 ») et son contenu
  possible en icônes avec des fourchettes : forge « 1-2 parchemins de puissance, 1-3 de garde, 1-2
  pierres de sûreté, 1 pierre de chance, 2 pierres, parfois ciseaux (50 %) et parchemin béni (20 %),
  3-8 cristaux » ; joaillier « 2 gemmes de rang N, 1 parchemin d'enchantement » ; apparence « une
  apparence rare ou épique que tu n'as pas · 312 / 3 182 ». Une fonction d'aperçu à côté de
  `Rewards.open` (mêmes règles, pour ne pas mentir).
- **Ouvrir tout** (par type, ou tous les coffres sans choix) et **Ctrl+clic sur « Ouvrir »** = tous
  les coffres de ce type. Une seule animation, puis un **récapitulatif** qui additionne tout
  (« 14 parchemins, 9 pierres, 47 cristaux, 2 apparences »). Les coffres à choix restent à part.
- **Coffres à choix** : une pièce déjà dans le coffre commun ou dans l'archive est marquée « déjà
  possédée » ; mieux, `Rewards.offer` ne la tire plus (même règle que `GearShopPage.owned`, archive
  comprise : voir Progression P1b).
- **Icônes de la liste** : une vignette du coffre 3D (capture du `ChestStage`) à la place de l'icône
  plate teintée.
- **Textes justes** (I7) : « Toujours gardés, même si tu tombes ».

**Touche** : `chests_page.gd`, `rewards.gd` (aperçu, filtre de `offer`), `chest_stage.gd`.
**Dépendances** : Progression (réserve P1a, sources des coffres P5), Équilibrage (contenus).

### ★ I5 — Écrans de fin : ce que tu gardes, en clair, et « Rejouer » (coût S à M)

**Règles** (bilan de Survie, `results_screen.gd`)
- **3 blocs** :
  1. **Ta run** : époque et étape, durée, niveau, monstres, élites, boss, dégâts records ;
  2. **Gardé** : maîtrise (barre qui se remplit, niveaux gagnés et ce qu'ils donnent), insignes,
     **pièces découvertes en icônes** (bouton « Voir à l'Armurerie »), coffres de récompense ramassés
     (« 3 coffres à ouvrir »), fournitures **gardées ou perdues** (en vert ou en rouge), cartes et
     classes débloquées, **époque débloquée** (à la place de « Nouvelle zone »), succès (I6) ;
  3. **Records** : « nouveau record » à côté du chiffre battu.
- **Boutons** : « **Rejouer** (même époque, même classe) » en premier, « Lobby », et « Armurerie » si
  une pièce découverte est achetable.
- **Même gabarit** pour la Tour (`tower_results.gd`) et le Duel (`duel_results.gd`) : un composant de
  bilan commun.
- **Supprimer la branche « héritage »** (choix de l'objet gardé : `_item_button`, `_select`, `_score`,
  appels `Profile.end_run`, `end_run_extract`) : la note du joueur sur la hache de base est réglée par
  construction.
- **Menu pause** : le texte d'abandon dépend du mode ; en Survie : « Tu gardes la maîtrise, les
  insignes, les pièces découvertes et les coffres ramassés ; les fournitures du sac sont perdues ».

**Touche** : `results_screen.gd`, `tower_results.gd`, `duel_results.gd`, `pause_menu.gd`,
`profile.gd` (code mort). **Dépendances** : Progression (P1e, P1f, records P1g), Modes (Rejouer pour
chaque activité).

### ★ I6 — Suivi de la collection, succès et titres (avis sur l'ajout n°5, coût M pour l'interface)

**Notre avis sur P3 et P4 (Progression)** : d'accord sur le fond. Pour l'endroit, nous proposons de
**ne pas créer une entrée de plus** pour le Carnet : l'écran **Collection** devient le lieu unique de
« tout collectionner » et du « où j'en suis ». L'Armurerie part dans l'Atelier (I3).

**Collection, nouvelles pages** (`PageScreen` existant, onglets)
1. **Vue d'ensemble** : une tuile par catégorie, avec sa barre et son chiffre, cliquable vers sa page :
   Classes 23 / 60 · Maîtrise 20 : 3 / 60 · Cartes 40 / 49 · Certificats 30 / 120 · Panoplies 2 / 154 ·
   Apparences 312 (palier suivant 500) · Archive (palier) · Époques ★ 5 / 12 · Tour · Panthéon ·
   Succès 18 / 100. En tête, la **complétion globale** (P4.3) et les **3 objectifs les plus proches**.
2. **Succès et titres** : liste par catégorie, filtres « presque fini », « obtenus », « cachés » ;
   chaque ligne : icône, nom, condition, barre, récompense. En haut, « **Titre porté** » (liste des
   titres obtenus).
3. **Classes** : l'arbre des 60 classes par famille (réutilise `class_picker.gd`), maîtrise et condition.
4. **Cartes et certificats** (la page Héros > Cartes y renvoie).
5. **Archive** (la page actuelle).
6. **Statistiques** : les records cumulés, enfin visibles (P3).

**Titres** : affichés sous le nom dans le badge du lobby, sur la plaque des adversaires de la Tour et
du Duel, sur l'écran de fin et sur la carte de sauvegarde de l'écran titre. Pas dans le HUD de run
(déjà chargé).

**Succès obtenus** : bandeau doré en haut au centre, 3 s, non bloquant, en file (`hud.gd`, et au lobby
pour ceux gagnés hors run) ; récapitulés dans le bilan ; pastille « Nouveau » sur Collection jusqu'à
la visite.

**Écran titre** : la carte de sauvegarde montre « complétion 18 % · Époque II · 23 classes » au lieu de
« zones débloquées » et « héritage » (`title_screen.gd:_summary_text`, `Profile.slot_summary`).

**Touche** : `archive_pages.gd` (+ nouvelles pages), `lobby.gd`, `hud.gd`, `title_screen.gd`,
`profile.gd:slot_summary`, `class_picker.gd`. **Dépendances** : Progression (données P3, P4),
Builds (cartes et passifs comptés), Modes (sources), Équilibrage (seuils).

### I7 — Textes justes et touches de triche (coût S, à faire en premier)

- Corriger tous les textes de 1.5 ; réécrire `info_page.gd:_money` et `_gear` (ou les remplacer par
  le Guide, I1).
- Vocabulaire unique de Progression P3 dans toute l'interface (maîtrise, points de talent, coffre
  commun, insignes).
- **F5 à F8** (`test_tools.gd:_unhandled_input`) : actives seulement si le mode dev est activé ;
  retirées de l'aide F1 (une ligne « Mode dev : F5… » seulement en mode dev).
- Mettre à jour les en-têtes de code trompeurs (`grimoire.gd`, `profile_editor.gd`, `rewards.gd`,
  `results_screen.gd`) pour les sessions qui codent.

**Touche** : `info_page.gd`, `chests_page.gd`, `lobby.gd`, `title_screen.gd`, `pause_menu.gd`,
`results_screen.gd`, `activities.gd`, `gear_shop_page.gd`, `duel.gd`, `test_tools.gd`.
**Dépendances** : Progression (P1, mêmes fichiers : à faire ensemble).

### I8 — Lisibilité des nouveautés de build en run (avec Builds, coût S chacune)

- **Icône d'axe** (B2) : en haut à droite de chaque carte (`card_picker.gd:_make_card`) et de chaque
  trophée, 24 px, avec infobulle ; mêmes icônes dans la page Run du menu pause.
- **Résumé du build** (B2) pendant le choix de cartes : colonne repliable à gauche du choix (axes et
  nombre d'éléments), qui laisse la place aux fiches de tutoriel quand il y en a une.
- **« Sans effet sur ton build » / « plafond atteint »** (B1) : bandeau gris en bas de la carte.
- **Zone dorée de l'enchaînement** (B7) : segment doré dans la barre circulaire du sort
  (`hud_widgets.gd:SkillSlot`, `chain_bar`), texte « PARFAIT » à la réussite, comme « ESQUIVE ! ».
- **Esquive parfaite défensive** (B7) : ralenti court avec un anneau blanc autour du héros, sans
  assombrir l'écran (les hordes doivent rester lisibles).

**Dépendances** : Builds (B1, B2, B7), Équilibrage.

### I9 — Confort (coût S)

- **Armurerie** : filtres « pas encore acheté », « de ma classe », époque, emplacement ; **achat
  multiple** (Ctrl+clic, Maj+clic, puis « Acheter la sélection · N insignes ») avec la grille à
  sélection multiple qui existe déjà (`ItemGrid.new(true, …)`).
- **Forge en Survie** : bouton grisé avec la raison en infobulle au lieu du message de 3 s après le
  clic (`inventory_page.gd:973`).
- **Menu Duel** en 3 blocs clairs : « Ton build » (conditions ✔/✘), « Adversaire » (classe, IA ou
  cerveau, difficulté), « S'inscrire » ; les cerveaux rejoignent le Panthéon si P8 est retenu.
- **Tour** : les étages 50 / 100 / 150 / 200 marqués d'une icône de coffre d'apparence dans la liste
  (`lobby.gd:_menu_tower_floors`) — réponse à Progression, question 4.

---

## 4. Questions aux autres équipes

**Progression**
1. D'accord pour que la **fiche d'ouverture** de P2 et la **fiche de tutoriel** de I1 soient un seul
   système (`core/tutorial.gd` lit la table `core/unlocks.gd`) ?
2. D'accord pour que **Collection** devienne le Carnet (vue d'ensemble, succès et titres, classes,
   cartes, archive, statistiques) et que l'Armurerie parte dans un **Atelier** avec la Forge du hub ?
3. Les médailles de l'Académie (I1, couche 4) peuvent-elles compter dans les succès (P4) ?
4. La Forge verrouillée jusqu'à la fin de l'époque I : on lui donne d'abord une entrée (Atelier),
   sinon le verrou se voit mal. D'accord sur cet ordre ?

**Modes**
1. Pouvez-vous fournir, pour chaque activité (existante et à venir), sa fiche en 3 lignes et sa ligne
   « Rapporte : … » ? Et sa condition d'ouverture (avec Progression) ?
2. L'Académie dans la Zone d'entraînement vous convient-elle (onglet « Leçons »), ou préférez-vous
   une activité à part ?
3. « Rejouer » en fin de Tour : repartir de l'étage de départ ou du record ?

**Builds**
1. Combien d'axes (B2) et quelles icônes ? Nous prévoyons 24 px sur la carte : 12 axes au plus.
2. Les textes « Armes et variantes », « Enchaînements », « Annulation parfaite » du Guide : pouvez-vous
   relire nos fiches (elles changent si B3 et B7 sont retenus) ?
3. La zone dorée (B7) : position fixe par sort ou variable ? Variable demande un repère visible à
   chaque appui.

**Équilibrage**
1. `ZONE_DAMAGE` adoucit la 1re map de **chaque** époque en Survie (`Run.stage - 1`) : est-ce voulu ?
   Les Premiers pas n'en ont besoin que pour l'époque I.
2. Les fourchettes affichées dans le menu Coffres (I4) seront celles du code : prévenez-nous si les
   contenus changent.

---

## 5. Questions au joueur (l'indispensable)

1. **Tutoriel** : d'accord pour apprendre **dans ta 1re vraie Survie** (une liste de 10 étapes à cocher
   en jouant, plus des fiches courtes la 1re fois que tu croises chaque chose), plutôt qu'une map de
   tutoriel à part ? Tout se passe d'un clic et se relit dans un Guide (F1).
2. **Nouvelle partie** : choisir sa classe parmi les 5 classes de base dès le départ, ou commencer
   toujours en Guerrier ?
3. **Lobby** : d'accord pour une entrée **Atelier** (Forge du hub, Armurerie, réserve de fournitures)
   et pour que **Collection** devienne la page « tout collectionner » (complétion, succès, titres) ?
4. **Nouveautés** : veux-tu, toi aussi, une fiche « Nouveau : … » quand une version ajoute un système
   (Donjons, succès…) ?

---

## Résumé (5 lignes)

1. **I1 Tutoriel passable** (M) : accueil « Je découvre / Je connais », 10 « Premiers pas » cochés en jouant dans la 1re Survie, ~40 fiches courtes à la 1re rencontre (jamais bloquantes en combat), un Guide F1 qui remplace l'aide périmée, puis une Académie dans l'entraînement ; passer ne débloque rien.
2. **I7 + I5** (S) : corriger la vingtaine de textes faux (aide, Coffres, pause, lobby, écran titre), réserver F5-F8 au mode dev, et refaire le bilan (époque débloquée, gardé / perdu en clair, pièces découvertes, « Rejouer »), en supprimant le code « héritage ».
3. **I4 Coffres** (S) : contenu et niveau visibles avant ouverture, « Ouvrir tout » et Ctrl+clic avec récapitulatif, plus de pièce déjà possédée proposée ; animation 3D et niveau proportionnel déjà faits.
4. **I2 + I3** (S + M) : déblocage progressif toujours visible (grisé, condition, pastille « Nouveau », fenêtre d'ouverture = fiche du tutoriel) ; lobby avec barre de ressources, objectif suivant, entrées Atelier (Forge, Armurerie, réserve) et Guide, « Relancer » en un clic.
5. **I6** (M) : Collection devient le Carnet « tout collectionner » (vue d'ensemble et complétion, succès et titres, classes, cartes, archive, statistiques), titres sous le nom du héros, bandeau de succès non bloquant ; I8 / I9 pour la lisibilité des builds et le confort (Armurerie filtrée, achat multiple).
