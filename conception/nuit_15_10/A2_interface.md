# A2 — Audit visuel et ergonomique de l'interface (version 0.1.163)

Audit en **lecture seule** : aucun fichier du jeu n'a été modifié, rien n'a été `git add` / commité / poussé.
Seuls ajouts : ce rapport et `conception/nuit_15_10/captures/` (captures PNG 1600×900).

## 0. Méthode, périmètre, limites (à lire d'abord)

**Le jeu a pu être lancé et capturé pour de vrai** (Godot 4.7.2, rendu Vulkan, fenêtre 1600×900 = la résolution de conception du projet).
Chaque capture a été regardée à l'écran (outil de lecture d'image), pas déduite du code ; le code des pages (`ui/*.gd`) a servi à retrouver
les chaînes exactes et les numéros de ligne.

- **Copie figée du dépôt.** La session N1 modifie en ce moment `core/craft.gd`, `core/profile.gd`, `core/run.gd`, `core/run_director.gd`,
  `core/world.gd`, `ui/item_widgets.gd` (+ nouveau `core/starter_gear.gd`) : la compilation du jeu casse par moments (deux de mes premières
  captures ont planté pour cette raison). Toutes les captures du rapport viennent donc d'une **copie de `game/` au commit HEAD `6600b916`** (0.1.163),
  fichiers de N1 remis à leur version HEAD. Conséquence : les écrans de Survie décrits ici sont ceux **d'avant** le travail de N1 ; les lots de polissage
  qui touchent `item_widgets.gd`, `profile.gd`, `run.gd`, `world.gd`… doivent attendre que N1 ait poussé.
- **Aucun risque pour la sauvegarde du joueur** : le processus de capture a été lancé avec un `APPDATA` détourné (profil de test = copie du
  profil du joueur, déverrouillée, 380 insignes, 420 cristaux, 11 coffres) ; rien n'a été écrit dans `%APPDATA%/Godot/app_userdata/Eden Slash`.
- **Captures « nouvelle partie »** : `carnet_0..3`, `duel_league/pantheon/gauntlet` et `welcome_*`/`guide_*` ont été prises avec une sauvegarde vierge
  (utile : c'est ce que voit un nouveau joueur — beaucoup de cadenas, 0 insigne).
- **Pas pu faire** : test à la vraie manette (les bandeaux d'aide manette sont visibles sur les captures, la navigation elle-même est jugée d'après
  `core/ui_nav.gd` et les tests existants) ; survol réel des infobulles natives (reconstruites avec `ItemWidgets.item_card` / `SpellInfo.skill_bbcode`,
  exactement ce que le survol affiche) ; résolutions autres que 1600×900 ; mode dev (F10, écrans `dev_*`, `profile_editor`, `test_tools` : hors périmètre joueur).
- Le HUD de Survie a été capturé en pilote automatique (`--autoplay`) ; l'état « boss » et « bilan » de Survie via `--end-at`.

Légende des tailles : **S** = quelques lignes / un fichier, **M** = une demi-journée, **L** = refonte d'un écran ou d'un composant partagé.
Priorités : **P1** = défaut visible qui gêne ou qui casse, **P2** = vrai gain de lisibilité / d'ergonomie, **P3** = finition.

---

## 1. Verdict en dix lignes

1. **Le style est cohérent et joli** (or sur indigo, titres en petites capitales, orbes de vie / d'XP, coffre 3D, roue) : on voit un vrai jeu, pas un outil.
   Le **HUD de run est le meilleur écran** : sobre, lisible, pas de texte parasite.
2. **Le problème n°1 n'est pas le style, c'est le texte** : presque chaque page ajoute une, deux ou trois phrases d'explication « pour être sûr »
   (règles, pourcentages, mode d'emploi du bouton qu'on regarde). Un jeu AAA montre l'état, pas la notice.
3. **Les pages du lobby débordent de l'écran** : le panneau central (Siège, Donjon, Duel, Tour) n'a aucun `ScrollContainer` ; le bouton **Lancer** sort de l'écran
   (invisible dans Siège, Duel…, coupé dans Donjon). C'est le défaut le plus grave de l'audit.
4. **Pied de page du lobby cassé** : la carte « sauvegarde » est coupée en bas de l'écran et chevauchée par le texte permanent
   « Alt + clic droit : noter un problème · Eden Slash v0.1.163 » ; en mode manette, la barre d'aide recouvre en plus tout le bas de l'écran.
5. **Les noms d'objets et de monstres sont en anglais brut d'Eden** (« Rage Battle Axe », « Awaken Honor Impact Crown », « Rocky High Mushroid ») dans un jeu en français,
   et plusieurs écrans racontent le jeu d'origine (« niveau 57 dans Eden », « Dans Eden : Awaken Armor », « Eden Eternal : Deep Impact »).
6. **Trois à quatre systèmes d'aide se recouvrent** : page « Aide » du menu Héros / de la pause (formules), Guide F1, fiches de découverte, panneau « Premiers pas »,
   plus les notes sous chaque réglage. Le joueur ne sait pas où regarder ; chacun répète les autres.
7. **Mêmes données, trois écrans** : les cartes sont dans Héros > Cartes (grille d'icônes), Carnet > Cartes (liste texte) et Grimoire ; l'équipement est dans
   Héros > Équipement ET Pause > Héros (même page) ; cinq écrans de bilan différents (Survie, Duel, Tour, Donjon, Battle royale) refont la même mise en page à la main.
8. **Beaucoup d'écrans sont à moitié vides** (Fabrication, Forge, Armurerie, Roulette, fiche de carte) alors que d'autres sont tassés (Paramètres : fenêtre de 650 px de haut dans 900,
   Touches : 8 lignes sur 24 visibles ; pause Run : 8 lignes « Enchaînement libre » identiques).
9. **Le choix de carte en deux temps** (cliquer la carte, puis « Valider ») est le geste le plus répété du jeu : c'est un clic de trop par niveau.
10. **Une vraie bombe** : le bouton « Quitter le jeu » de la pause (`ui/run_page.gd:64`) quitte immédiatement, sans confirmation, juste sous « Abandonner ».

---

## 2. Constats transversaux (reviennent sur plusieurs écrans)

### T1 — Débordement vertical des pages du lobby (P1, M) — `ui/lobby.gd`
- Le sous-menu est un `PanelContainer` (`_sub_panel`, `lobby.gd:~905-915`) posé à (372, 196) **sans hauteur maximale ni défilement** ; sa hauteur suit le contenu.
- Captures : `siege.png` (le bouton « Lancer » n'est pas à l'écran, les sélecteurs d'alliés sont coupés), `duel.png` / `duel_league.png` (on perd « Éditeur d'adversaire »,
  « Préparation rapide » et le bouton d'inscription), `donjon.png` (le bouton « Entrer dans … » est à moitié sous le bord et sous la barre d'aide), `royale.png` (« Lancer le Battle royale »
  collé au bord), `tour.png` (4e carte « Hardcore » : sa 4e ligne déborde du cadre).
- Correction : contenu dans un `ScrollContainer` (max = hauteur écran − 196 − 130), et **bouton d'action (Lancer / Entrer / S'inscrire) épinglé en bas, hors du défilement**,
  toujours visible. Largeur du panneau fixe (aujourd'hui 760 px pour « Jouer », 470 pour le reste, et la page Donjon/Siège s'élargit encore toute seule : le panneau « saute » d'une page à l'autre).

### T2 — Pied de page et bandeaux parasites (P1, S) — `ui/lobby.gd`, `core/ui_nav.gd`, `core/feedback.gd`
- `lobby.png` : la carte en bas à droite (`lobby.gd:~985-1015`) affiche deux lignes (`lobby.gd:1610`) mais n'a que 50 px de haut et 532 px de large : la 2e ligne
  (« Sauvegarde 1 · coffre commun 4 objet(s) · 8 run(s), 3 victoire(s) ») est coupée par le bas de l'écran et **écrasée par** « Alt + clic droit : noter un problème · Eden Slash v0.1.163 »
  (étiquette globale de `core/feedback.gd`, visible sur tous les écrans, y compris en pleine partie).
- L'astuce de caméra « Glisser : tourner autour du héros · molette : zoom · clic droit glissé : hauteur · double-clic : vue de départ » (`lobby.gd:1000`) s'efface après 8 s : bonne idée, mais
  une phrase de 118 caractères pour une fonction que 90 % des joueurs ne chercheront pas ; garder « Glisser : tourner · Molette : zoom » (35 caractères).
- **Barre d'aide manette** (`ui_nav.gd:366`) : 150 caractères en bas de TOUS les écrans dès qu'on navigue au clavier/manette ; sur `donjon.png`, `royale.png`, `duel.png` elle recouvre le bouton Lancer.
  AAA : 3 icônes de boutons (A Valider · B Retour · LB/RB Onglets), 20 px, dans un coin, posées dans une marge réservée (aujourd'hui le texte est posé par-dessus le contenu, en
  jaune sans fond : illisible quand il croise le pied de page ou un bouton). Elle n'apparaît que si `Gamepad.active` (une manette était branchée sur ce PC pendant l'audit : elle
  se voit sur toutes les captures prises en navigation « cadre »).
- Double surbrillance : le cadre doré du curseur manette reste sur « Jouer » (`quitter.png`, `heros_classe.png`) alors que « Quitter » / « Apparence » est l'entrée sélectionnée : deux entrées
  semblent actives. Le cadre ne devrait apparaître qu'après un mouvement de croix / stick.

### T3 — Murs de texte explicatif (P2, M, transversal) — voir la table §6.2
Les trois formes récurrentes :
1. **Sous-titre qui répète le titre** (« Coffres » / « Coffres de récompense rapportés des runs : apparences, forge, joaillier · Roulette : 3 lancers par jour »).
2. **Notice sous le contrôle** (« Automatique : quand tu ne te déplaces pas, le héros frappe… » sous la liste « Mode d'attaque » qui dit déjà « Automatique : frappe seul… »).
3. **Règles chiffrées** que seul un testeur lit (chances de roulette « Après 6 « Perdu » d'affilée… après 25 lancers sans rare », formules de dégâts, taux de coffres).
AAA : un titre, une valeur, une icône ; le détail dans une infobulle (survol / bouton Y), jamais en paragraphe permanent. Règle simple à appliquer partout : **une phrase par écran maximum**,
15 mots, jamais de pourcentage dans le texte permanent.

### T4 — L'Eden d'origine ne regarde pas le joueur (P2, S) — voir table §6.1
Mentions du jeu d'origine à supprimer : niveaux d'Eden d'une pièce, « Dans Eden : … », « Eden Eternal : « … » » sur les sorts et talents, « Plans d'Eden de cette zone », « catalogue d'Eden », « Costumes d'Eden… ».
Le joueur n'a ni connu ni besoin de ces repères (les données restent dans les fichiers pour les outils).

### T5 — Noms en anglais (P1, M) — `data/`, `ui/item_widgets.gd`, `core/items.gd`
Noms d'objets (« Rage Battle Axe », « Bone Harvest Axe », « Agile Fox Cloak », « Temple Knights- Rainbow Aurora Gloves », « Awaken Honor Impact Crown », « Pure Feather Crown »),
de monstres (cible du HUD : « Rocky High Mushroid », « Limestone Forged »), de zones (« Limestone Mtn. », « Delphi Forest »), de costumes (« Cantonese Version Serial Number ») s'affichent dans
chaque écran important (choix d'arme du run, coffres, Armurerie, HUD). Le reste du jeu est en français : c'est le contraste le plus choquant de l'interface.
Correction rentable : une **table de traduction / renommage** (`data/names_fr.json`, ~600 lignes pour les pièces mythiques / légendaires qui sont proposées, ~40 monstres, 8 zones) appliquée
à un seul endroit (`Items.display_name`, `GameData.zone_name`, nom de monstre du HUD) ; en attendant, au minimum **traduire le type** (déjà fait : « Hache · Taille large ») et
**retirer les noms propres parasites** comme « Temple Knights- » (tiret mal formé).
Doute à vérifier : sur `gearshot` la carte « Cape · Légendaire · niv. 50 » montre une **icône de gants** et la carte « Gants » une icône de chaussette/botte ; si l'icône vient bien de la fiche
Eden, c'est une donnée à corriger (icône par emplacement) ; sinon c'est une confusion `slot ↔ icône`.

### T6 — Doublons d'écrans et de systèmes (P2, L)
| Contenu | Où il apparaît | Proposition |
|---|---|---|
| Cartes de build | Héros > Cartes (grille d'icônes + fiche), Carnet > Cartes (liste texte), Héros > Classe > Grimoire (passifs), fiche « Les cartes » du Guide | **Un seul** : Héros > Cartes (gardé), le Carnet n'affiche que « 31/49 » + lien |
| Équipement | Héros > Équipement ; Pause > Héros (même `InventoryPage`) | normal (même composant) mais retirer « Classe affichée » + doublon de fiche |
| Aide | Héros > « ? » (page formules `InfoPage`), Pause > Aide (même `InfoPage`), Guide F1, fiches de découverte, panneau « Premiers pas » | Guide F1 = **seule** aide ; `InfoPage` devient un onglet « Détails » du Guide pour les curieux |
| Progression | Carnet > Vue d'ensemble (« Complétion 7 % », 10 barres) + Carnet > Succès (42) + titre | garder la vue d'ensemble, la remonter en bandeau fixe |
| Bilans de fin | `results_screen`, `duel_results`, `tower_results`, `dungeon_results`, `royale_results` (5 fichiers, 5 mises en page, mêmes blocs « gardé / perdu ») | **1 composant** `ResultsPanel` |

### T7 — Hétérogénéité visuelle (P2, M)
- **Paramètres** (`settings_menu.gd`) est une fenêtre centrée de 1070×650 avec ses propres onglets (look « thème Godot » : étroits, boutons violets, cases « Activé/Désactivé » en gros boutons),
  alors que tout le reste (Carnet, Atelier, Coffres, Pause) utilise `PageScreen` plein écran à cadres dorés. On le voit en passant de l'un à l'autre : deux familles de boutons, deux polices de titre.
- Boutons : `MenuWidgets.glass_button / gold_button` (lobby), `Hud.style(...)` + `Button.new()` manuels (résultats, cartes, pause), `UiTheme.flat_box` (Atelier) : au moins trois fabriques de bouton.
- Fenêtres modales natives non stylées : `ConfirmationDialog` de la pause (`pause_menu.gd:44-62`), `AcceptDialog` de la fiche d'étage de la Tour (`tower_fiche.png` : boîte noire avec 240 px de vide),
  `InfoDialog` des sets.

### T8 — Le geste le plus répété coûte un clic de trop (P1, S) — `ui/card_picker.gd`
`card_picker.gd:95` : « Clique sur une carte (ou 1, 2, 3) puis sur Valider (ou Entrée) ». À chaque niveau de chaque run : sélection, puis bouton « Valider » (désactivé 0,3 s après l'ouverture).
AAA (Vampire Survivors, Megabonk, Hades, Slay the Spire) : **un seul geste** (clic ou touche = choisi). Garder la sécurité anti-rafale (0,3 s) mais supprimer l'étape « Valider » ;
laisser un « double-clic / appui long pour confirmer » en option d'accessibilité. Gain : ~40 clics économisés par run.

### T9 — Accessibilité / lisibilité de base (P2, S)
- Texte 11–13 px (« SORTS AUTO », « [Tab] objectifs », « F1 : aide · F9 : signaler un problème », `recordde la run … · record …`, notes grises MUTED `#9a98a8` sur indigo) : sous le seuil confortable
  à 1080p et illisible sur télévision (Steam Link / Apple TV évoqués dans CLAUDE.md). Plancher de 14 px pour tout texte permanent, 12 px seulement pour les chiffres secondaires.
- `Settings.ui_scale` existe (Affichage > Taille de l'interface) mais le lobby, le HUD et la plupart des pages sont posés en coordonnées absolues (`position = Vector2(-450,-204)`, `offset_left = -560`) :
  à vérifier à 125 / 150 %.
- Couleur seule pour distinguer 7 types de coffres (`coffres.png` : même icône de coffre, 7 teintes) → ajouter une pastille d'icône par type (apparence / aura / forge / joaillier / set).

### T10 — Navigation manette (P2)
Le moteur `UiNav` couvre tout automatiquement (bonne décision) ; les points fragiles vus dans le code et les captures :
- Les `Button` avec `focus_mode = FOCUS_NONE` (partout) ne gardent pas d'état « focus » propre ; tout repose sur le cadre `UiNav` : les contrôles à `gui_input` seul (badge classe du lobby, cases de grille d'inventaire,
  roue) doivent être testés (`tests/test_nav_screens.tscn` : y ajouter Atelier, Coffres/Roulette, Paramètres > Touches, Guide, Pause).
- Grands formulaires (Touches : 24 actions × 2 colonnes, Armurerie : grille 9 colonnes) : prévoir **sauts de section** (LB/RB déjà pris par les onglets de page → utiliser la croix gauche/droite pour sauter de groupe).
- Le panneau « Premiers pas » (HUD) et la fiche « Les cartes » sont fermés par L3 / R3 uniquement (`hud.gd:280`) : non découvrable ; ajouter l'indication « L3 : fermer » dans la fiche elle-même.

---

## 3. Lobby : écran par écran

> Pour chaque écran : **(a)** ce qui marche · **(b)** ce qui gêne · **(c)** texte à supprimer (chaîne exacte, fichier:ligne) · **(d)** ce que ferait un AAA · **(e)** corrections P1/P2/P3 (fichiers, taille).

### 3.1 Lobby principal — `captures/lobby.png`
**(a)** Menu de gauche net (6 entrées + Quitter, icônes, état survol / sélectionné), logo, badge de classe en haut à droite, héros 3D sur la carte, ressources en bas : on comprend tout en 2 s.
**(b)**
- Carte de zone en bas à gauche « Limestone Mtn. — Niv. 1+ · zone 1 / 8 · 1 débloquée(s) » (`lobby.gd:1600`) : reliquat d'avant les époques (la Survie se choisit maintenant par époque) ; elle montre une « zone » que le joueur ne choisit plus ici.
- « Prochaine récompense » : barre de maîtrise sans chiffres, on ne voit pas combien il manque ; le texte « Maîtrise Guerrier niv. 2 : Ruée » ne dit pas ce que « Ruée » est (un sort).
- Pied de page cassé (T2), deux lignes dont une de statistiques de sauvegarde sans intérêt.
- Le badge de classe se lit « Guerrier ▾ » mais rien ne dit qu'on peut cliquer pour changer de classe (seulement l'infobulle).
- Aucune indication « quoi faire maintenant » au retour d'une run (coffres à ouvrir ? roulette ? pièce achetable ?) : les badges existent (« Coffres ★ », « (11) ») mais en texte accolé au nom.
**(c)** `lobby.gd:1610` « Sauvegarde %d · coffre commun %d objet(s) · %d run(s), %d victoire(s) » → supprimer (déjà dans Carnet) ; `lobby.gd:1000` astuce de caméra → raccourcir ; `lobby.gd:1600` « … · zone %d / %d · %d débloquée(s) » → supprimer.
**(d)** Un hub AAA met une action « Continuer / Jouer » en avant et 2–3 pastilles de notification (coffres à ouvrir, roulette disponible, nouvelle pièce) ; la barre de maîtrise a ses chiffres (« 1 240 / 2 000 ») et l'icône de la récompense.
**(e)**
- **P1 S** : carte du pied de page → une seule ligne « insignes · cristaux », hauteur fixe ; retirer l'étiquette globale « Alt + clic droit… » des écrans de menu. Fichiers : `ui/lobby.gd`, `core/feedback.gd` (hors dossier ui).
- P2 S : pastilles rouges sur « Coffres » / « Atelier » (nouveauté) à la place de `(11)` / `★` ; `ui/lobby.gd`, `ui/menu_widgets.gd`.
- P2 S : chiffres sur la barre de maîtrise ; supprimer la carte de zone ou la remplacer par « Reprendre : Époque III ». `ui/lobby.gd`.
- P3 S : flèche `▾` plus visible sur le badge de classe ; `ui/lobby.gd`.

### 3.2 Jouer (activités) — `captures/jouer.png`
**(a)** **Très bon écran** : étiquettes illustrées en trois rangées (Aventure / Défis / Affrontements), pastille JcE / JcJ, cadenas + condition en infobulle. C'est la bonne direction.
**(b)**
- Sous-titres tronqués : « Trois héros, cinq vagues, un boss, puis… » (Siège) coupé ; « 8 héros, un anneau, un seul survivant » touche le bord ; la chevron `›` se superpose au texte (Donjons, Arènes, Duel, Siège).
- La rangée « Défis » contient « **Épreuves de maîtrise** » grisée « BIENTÔT » : une carte entière pour une fonction inexistante.
- Composition 3-3-3-1-1 : le Siège est seul sur sa ligne, « Zone d'entraînement » en barre pleine largeur sans illustration lisible.
- Le panneau (760 px) recouvre le héros 3D.
- Survie et Défi de maîtrise ont la même image ; Donjons et Ruée aussi.
**(c)** `activities.gd` : champs `sub` > 28 caractères (« Trois héros, cinq vagues, un boss, puis chacun pour soi » → « 5 vagues, un boss, chacun pour soi ») ; champ `desc` : répété sur la page de l'activité (voir ci-dessous).
**(d)** Cartes de mode avec trois petites icônes de gain (insignes, cristaux, titre) à la place de la phrase `gain`, nombre de joueurs, durée estimée (« ~12 min ») ; les modes à venir sont masqués.
**(e)**
- P1 S : `clip_text` + infobulle, ou raccourcir les `sub` ; chevron hors de la zone de texte — `ui/activities.gd` (`card()`).
- P2 S : masquer « Épreuves de maîtrise » tant que `soon` ; grille 4 colonnes avec Entraînement en petit bouton — `ui/activities.gd`, `ui/lobby.gd` (`_menu_play`).
- P3 S : images distinctes pour Défi de maîtrise et Ruée (`img` dans `activities.gd` ; DDS d'Eden disponibles).

### 3.3 Survie (page d'activité) — `captures/survie.png`
**(a)** Bandeau illustré, liste des époques, bouton **LANCER LA RUN** doré bien visible (ici il tient dans l'écran).
**(b)**
- **Lignes d'époque qui se chevauchent** (P1) : chaque ligne fait 62 px (`lobby.gd:1255`, `_row(..., 62.0)`) mais contient jusqu'à 3 lignes de texte (zones / « Paliers … » / « Étoiles … défi … rang héroïque »). Sur la capture, « Paliers 65, 70, 70 · éveillé » et « avant la rage » flottent entre deux lignes, « Époque IV » est illisible.
- « Paliers 65, 70, 70 · éveillé » : jargon interne (palier d'armure ?) incompréhensible.
- Noms de zones en anglais : « Limestone Mtn. → Rainbowfall Forest → Beluga Bay ».
- Stepper « − Run normale (rangs héroïques ouverts) + » : libellé incohérent, boutons carrés nus.
- La note du bas « Tu pars sans équipement… » est la règle de base répétée dans le Guide, l'Aide, la page Jouer et le bilan.
**(c)** `lobby.gd:1244-1245` (`"%s\nPaliers %s · %s"` et `"\nÉtoiles : %s  ·  défi : %s%s"`) → 3 étoiles + une icône verrou ; `lobby.gd:1281` « Run normale (rangs héroïques ouverts) » → « Rang héroïque 0 » ; `lobby.gd:1293` « Tu pars sans équipement : arme au choix au départ, puis coffres d'emplacement sur chaque carte. » → supprimer ; `lobby.gd:1281` « Rang héroïque %d : monstres +%d %% PV, +%d %% dégâts, insignes +%d %% » → « Rang 3 · +36 % PV · +24 % dégâts · +45 % insignes ».
**(d)** Carte d'époque AAA : grande vignette de la 1re zone, nom de l'époque, **3 étoiles dessinées**, cadenas si verrouillée, rang héroïque en pastille ; détails au survol ; bouton « Lancer l'Époque III ».
**(e)**
- **P1 S** : hauteur de ligne automatique, 2 lignes max (`menu_widgets.gd` `RowButton`, `lobby.gd:1255`) ; supprimer « Paliers… ».
- P2 M : cartes d'époque à étoiles dessinées, zones en français ; `lobby.gd`, `menu_widgets.gd`.
- P2 S : stepper de rang héroïque 0…10 en pastilles.

### 3.4 Zone d'entraînement — `captures/entrainement.png`
**(a)** Page minimale : bandeau, une phrase, « ENTRER ». Rien à ajouter.
**(c)** `activities.gd` : le `desc` « Teste tes sorts, tes armes et tes cartes sur des mannequins et des adversaires réglables : rien n'est gagné ni perdu. » répète le sous-titre (« Sorts, armes et cartes, sans enjeu ») → garder un des deux. **(e)** P3 S.

### 3.5 Donjons — `captures/donjon.png`
**(a)** Sélecteur de donjon en 2 colonnes (▶ sur le choix actif, cadenas), difficulté Normal / Héroïque / Mythique avec niveau, notion de puissance affichée (« PE 126 / 4 320 attendue (niveau 14) · Faible »).
**(b)**
- Débordement (T1) : « ENTRER DANS ANDREW V. MINE » à moitié sous le bord et sous la barre manette.
- Noms de donjons mi-anglais mi-français (« Andrew V. Mine », « Repaire des Vileshark »).
- Intro « Des donjons d'Eden en plusieurs salles : vagues de monstres, mécaniques de boss et butin propre à chaque donjon. » : décrit la fonction du mode, pas le choix à faire.
- « PE 126 / 4 320 attendue … · Faible » : « PE » jamais défini à l'écran, « attendue » ambigu ; devrait être une **jauge** (126 → 4 320) avec « Faible » en rouge.
- « Alliés IA (PV des monstres +50 % par allié, butin inchangé) » : règle chiffrée dans un titre de section ; deux `OptionButton` « Aucun allié » (style Godot par défaut).
**(c)** `activities.gd:16` (desc du donjon) ; `lobby.gd` titre « Alliés IA (PV des monstres +50 % par allié, butin inchangé) » → « Alliés IA » + infobulle ; « PE … attendue … » → jauge.
**(d)** Deux colonnes : 8 donjons en vignettes (image, panoplie, ✓ Normal / Héroïque / Mythique), détails du donjon sélectionné à droite, **Entrer** épinglé en bas.
**(e)** **P1 M** : défilement + bouton épinglé (T1) ; P2 M : vignettes illustrées ; P2 S : jauge de puissance ; `ui/lobby.gd` (`_menu_dungeon`, `_dungeon_pickers`, `_dungeon_allies_picker`), `core/dungeons.gd` (noms).

### 3.6 Ruée des boss — `captures/ruee.png`
**(a)** Page la plus propre du menu : tout tient, un titre, une phrase, 3 difficultés (« Normal (0 / 8) »), alliés, **LANCER LA RUÉE**.
**(b)** Les sélecteurs d'alliés nus ; « (0 / 8) » est un meilleur score mais se lit comme un prérequis.
**(e)** P3 S : « Meilleur : 0 / 8 » en gris sous la difficulté ; `lobby.gd` (`_dungeon_pickers`).

### 3.7 Le Siège — `captures/siege.png`
**(a)** Même structure que Donjons ; difficultés verrouillées avec condition chiffrée (« PE requise : 1 512 (la tienne : 126) »).
**(b)** **Page la plus débordante** : au 1600×900 on perd le sélecteur d'alliés (coupé), la ligne « Victoires du chacun pour soi : … » et le bouton **Lancer** (invisible). Les trois difficultés sont **toutes verrouillées** : l'écran n'offre aucune action et ne le dit que par le petit texte « PE requise… ».
Description de 5 lignes (`activities.gd`, Siège), titre d'alliés de 71 caractères (« Tes deux alliés IA (« Au hasard » sinon) : ils deviennent tes rivaux quand le boss tombe », `lobby.gd:1423`).
**(c)** `lobby.gd:1423` → « Alliés IA » ; `activities.gd` desc du Siège → « 5 vagues, un boss, puis c'est chacun pour soi. Le dernier debout gagne. »
**(e)** **P1 M** (T1) ; P2 S : si aucune difficulté n'est ouverte, un seul message « Verrouillé : puissance 1 512 requise (tu as 126) » avec jauge ; `lobby.gd` (`_menu_siege`).

### 3.8 Défi de maîtrise — `captures/defi.png`
**(a)** Contenu utile (modificateurs du jour, classes proposées, contrats) sur une page qui tient dans l'écran.
**(b)** Trois paragraphes d'explication avant les données ; modificateurs en puces « • Or +30 % (et monstres +15 % de PV) » ; les boutons de classe « Voleur / maîtrise 1 » ; le bandeau dit « Une Survie par jour, deux contraintes » puis le texte répète « Une Survie de l'époque I avec deux modificateurs imposés… ».
**(c)** `activities.gd` `desc` de `mastery` (4 lignes, répète le sous-titre) ; `lobby.gd` « Réussite du jour : +%d points à la première victoire » et « Les contrats se remplissent à chaque Survie avec cette classe. » → supprimer.
**(d)** Cartes de modificateur avec icône ; classes en vignettes à portrait ; contrats avec barres de progression.
**(e)** P2 M : `lobby.gd` (`_menu_mastery`), `core/challenge.gd` (textes) ; P3 S : retirer le paragraphe.

### 3.9 Épreuves de maîtrise (« Bientôt ») — `captures/epreuves.png`
Page « À venir » acceptable ; c'est l'étiquette dans Jouer qui ne devrait pas exister (§3.2).

### 3.10 La Tour — `captures/tour.png`, `tour_etages.png`, `tour_fiche.png`
**(a)** Étages par pages de 5, verrous, bouton « COMMENCER À L'ÉTAGE 1 », « Changer de difficulté », fiche « i » par étage.
**(b)**
- Choix de difficulté : quatre grosses lignes **avec la même icône ↑**, chacune avec 2–3 lignes de description qui débordent du cadre (Hardcore : la 4e ligne « Étages battus : 0 / 200 » sort du cadre).
- « LA TOUR · NORMAL » : pagination `◀ Étages 1 à 5 · battus : 0 ▶` : 5 étages visibles sur 200 ; il manque un saut par paliers de 10 / « aller à l'étage atteint ».
- Libellés d'étage hétérogènes : « Étage 1 · Duel 1/60 : Chasseur », « Étage 2 · 8 monstres », « Étage 5 · 9 monstres et 1 élite(s) » (pluriel `élite(s)`).
- **Fiche d'étage** : `AcceptDialog` natif sans style (fond noir, 240 px de vide sous le texte, bouton « Fermer » sur 740 px) ; liste des **8 monstres en anglais avec PV / attaque / défense** (« Red Cap Mushroid — PV 579 · attaque 86 · défense 3 : 3 % des dégâts subis en moins ») : chiffres de balance sans intérêt pour décider ; seule la ligne « Récompense : une carte, puis un coffre… » est utile.
**(c)** `tower_pages.gd` (info_popup) : « Monstres de la zone » avec stats ; « 6 en même temps au plus · force +4 % » ; « (son objet rejoint ton coffre commun à la fin de l'ascension) ».
**(d)** Tour verticale : colonne d'étages défilante avec l'étage courant au centre, jalons d'icônes (boss tous les 10, récompenses 50 / 100 / 150 / 200) ; fiche d'étage en infobulle illustrée.
**(e)** P1 S : hauteur des lignes de difficulté ; P2 M : icônes distinctes par difficulté (épée, bouclier, crâne, flamme) ; P2 M : fiche d'étage stylée (`MenuWidgets.glass`) sans PV / attaque / défense ; P2 S : « Aller à l'étage… » ; `ui/tower_pages.gd`, `ui/lobby.gd` (`_menu_tower*`).

### 3.11 Duel (4 onglets) et préparation — `duel.png`, `duel_league.png`, `duel_pantheon.png`, `duel_gauntlet.png`, `duel_prep.png`
**(a)** Onglets Libre / Ligue / Panthéon / Gantelet avec cadenas ; **liste de prérequis avec ✓ / ✗ et bouton « Régler »** : excellent retour d'état (le joueur voit pourquoi il ne peut pas s'inscrire et corrige en un clic).
**(b)**
- Page trop haute (T1) : « Éditeur d'adversaire », « Préparation rapide (PV ×1.0, dégâts ×1.0) » et le bouton d'inscription sont sous le bord.
- Deux rangées de sélecteurs superposées qui se ressemblent (onglets, puis « À l'arme / Équipé ✓ ») ; « ✓ » après le mot ici, avant ailleurs (« ✓ Normal »).
- Ligne « Adversaire : Guerrier ▾ · Difficile ▾ · IA scriptée ▾ » : trois contrôles de styles différents.
- « Préparation rapide (PV ×1.0, dégâts ×1.0) » : valeurs techniques dans un libellé de bouton.
- Fenêtre « Préparer l'adversaire » : 12 listes « Auto » (4 cases × 3 rangs), champs « PV × / Dégâts × », deux paragraphes de statistiques (« Adversaire : PV 1 154 · attaque 133 · défense 33 · critiques 7 % (+52 % de dégâts) ») et un paragraphe de règle (« En duel, les dégâts sont ramenés à l'échelle des deux héros : une auto-attaque retire environ 0.7 % de ses PV… l'acharnement double les dégâts toutes les 20 s. », `duel_prep.gd`).
**(c)** `lobby.gd:381` (Arènes) « Duel à l'arme, niveau 10 : tu joues avec ton preset de sorts ; si tu tombes, tes alliés continuent. 2 manches gagnantes. » ; `lobby.gd:471` (Ligue) « Duel à l'arme, niveau 10 : seul ton preset de sorts compte. L'aide est limitée à « Assistée ». Chaque victoire rapporte de la maîtrise à ta classe. » ; `lobby.gd:563` (infobulles À l'arme / Équipé) ; `lobby.gd:589` « À l'arme : seul ton preset de sorts compte, à armes égales avec l'adversaire. » / « Ton build doit être prêt avant de t'inscrire : tu te bats avec exactement ce que tu as réglé. » ; `lobby.gd:326` (Gantelet) ; `duel_prep.gd` paragraphe d'acharnement.
**(d)** Une liste de défis (adversaires en cartes à portrait de classe, rang, récompense) plutôt qu'un formulaire ; « Équipé / À l'arme » = un seul interrupteur ; l'éditeur d'adversaire dans un écran à part, hors du tunnel normal.
**(e)** P1 M (T1) ; P2 M : un seul contrôle « À l'arme | Équipé » ; P2 S : supprimer les 3 phrases d'intro ; P2 M : `duel_prep.gd` (grille 4×3 de vignettes de sort) ; `ui/lobby.gd` (`_menu_duel*`), `ui/duel_prep.gd`.

### 3.12 Arènes — `captures/arenes.png`
**(a)** Page courte, tient dans l'écran, choix 2 contre 2 / 3 contre 3 en deux boutons larges.
**(b)** « Tes alliés IA (classes au choix, « Au hasard » sinon) » (titre = phrase) ; « Premier adversaire » + « IA scriptée » : choix réservé aux testeurs de cerveaux (`MlDuelPilot.available()`), affiché pour tout joueur dès qu'un cerveau existe.
**(c)** `lobby.gd:381` ; `lobby.gd:~1423` ; `activities.gd` desc d'Arènes (« …hors ligne » inutile).
**(e)** P2 S : « Premier adversaire » dans un menu « Avancé » replié ; `lobby.gd` (`_team_brain_picker`).

### 3.13 Battle royale — `captures/royale.png`
**(a)** Difficulté en 5 boutons (« ✔ Mélange · Facile · Normal · Difficile · Hardcore ») ; score personnel (« Victoires : 0 · meilleure place : — · éliminations : 0 »).
**(b)** **Deux fois la même règle** : un paragraphe de 5 lignes (`activities.gd`, desc de `royale`) puis 5 puces (`lobby.gd:419`) qui le redisent ; mur de 11 lignes en 13 px gris avant le bouton ; « LANCER LE BATTLE ROYALE » collé au bord bas (T1), recouvert par la barre manette.
**(c)** `lobby.gd:419` (bloc de 5 puces) **ou** le `desc` d'`activities.gd` : en supprimer un, garder 3 puces de 6 mots (« 8 héros, 1 survivant · Coffres à piller · Zone qui se referme »).
**(e)** P1 S ; P2 S ; `lobby.gd`, `activities.gd`.

### 3.14 Quitter — `captures/quitter.png`
**(a)** Deux lignes claires (« Écran titre — Changer de sauvegarde, nouvelle partie » / « Quitter le jeu — Ta progression est sauvegardée »).
**(b)** Double surbrillance (T2) : « Jouer » reste encadré alors que « Quitter » est actif. `lobby.gd:1563`. **(e)** P3 S.

---

### 3.15 Duel : onglets Ligue / Panthéon / Gantelet — `duel_tab_*.png`, `duel_league.png`, `duel_pantheon.png`
**(a)** Ligue : page propre (rang, objectif « 3 victoires d'affilée », gros bouton **COMBAT DE LIGUE**). Panthéon : bonne idée de liste de défis avec **récompense annoncée** (« pièce « bottes », coffre d'apparence, titre « Éveillé » »).
**(b)** **Panthéon : les lignes se chevauchent** (P1) : chaque cerveau fait ~75 px mais contient 3 lignes ; « 🔒 bats le précédent » se superpose au titre de la ligne suivante (« Cerveau Facile », « Cerveau Normal »…) ; tout l'écran est en gris sauf le 1er. Les 6 cerveaux ont **la même icône flèche ↑**.
Phrase d'intro « Les cerveaux d'IA — à l'arme, niveau 10, meilleur de 3. » (clair, garder).
**(c)** `lobby.gd:471` (Ligue : « Duel à l'arme, niveau 10 : seul ton preset de sorts compte. L'aide est limitée à « Assistée ». Chaque victoire rapporte de la maîtrise à ta classe. ») ; verrou : un seul mot « Verrouillé » + infobulle, pas le texte de la condition en toutes lettres sous chaque ligne.
**(e)** P1 S : hauteur auto des lignes (`MenuWidgets.RowButton` : un seul correctif pour Survie, Tour et Panthéon) ; P2 S : icônes d'adversaire = portrait de la classe du cerveau ; `ui/lobby.gd`, `ui/menu_widgets.gd`.

---

## 4. Écrans plein écran (Héros, Coffres, Atelier, Carnet, Paramètres, Aide)

### 4.1 Écran titre — `title.png`
**(a)** Net, élégant (logo, 3 boutons, zone en bas à gauche). Rien à toucher.
**(c)** « Limestone Mtn. / Zone 1 · niveau 1+ » en bas à gauche : décor de menu sans fonction (le joueur ne choisit plus la zone ici). Suppression S : `ui/title_screen.gd:119` (`_on_zone`).

### 4.2 Accueil nouvelle partie — `welcome_1.png` à `welcome_3.png`
**(a)** Trois départs clairs (« Je découvre… / Je m'échauffe… / Je connais déjà »), 5 classes présentées en colonnes : **bon tutoriel**, court, non bloquant.
**(b)**
- Étape 1 : panneau 920×540 à moitié vide (bas de la fenêtre inutilisé).
- Étape 2 : 5 cartes de classe très hautes avec 3 lignes de texte seulement (60 % de la carte vide) ; pas de portrait 3D ni d'arme dessinée : le choix de classe est l'acte le plus engageant du jeu et il est le plus pauvre visuellement.
- **Étape 3 sort de l'écran** : le panneau « Contrôles et aide » est plus large que la fenêtre (3 colonnes de contrôles : la 3e « Manette » est coupée à droite à 1600 px ; le bouton « C'EST PARTI » aussi). P1.
**(c)** `welcome.gd` étape 2 : « Les 5 classes restent ouvertes : ce choix dit seulement avec laquelle tu commences. Les autres se gagnent à la maîtrise. » (2 phrases pour dire « tu pourras changer ») → « 55 autres classes se débloquent en jouant. » ; étape 3 : « Tout se change ensuite dans Échap > Paramètres. L'aide n'enlève aucune récompense en JcE. » ; « Mémoire des touches (3 appuis gardés), tenir la touche enchaîne, anneau d'annonce de l'annulation parfaite. Les sorts, le déplacement et l'esquive restent à toi. » (vocabulaire interne : à supprimer, l'aide se comprend à l'usage).
**(d)** Choix de classe AAA : modèle 3D qui tourne + 3 icônes de rôle (Mêlée / Distance / Soutien) ; pas de paragraphe.
**(e)** **P1 S** étape 3 (largeur fixe 920, colonnes en `GridContainer` à 3 colonnes de 280 px) ; P2 M portrait 3D ; `ui/welcome.gd`.

### 4.3 Guide (F1) — `guide_commands.png`, `guide_steps.png`, `guide_cards.png`
**(a)** Sommaire à gauche, contenu à droite, chapitres courts : bonne structure.
**(b)** La liste fait **22 chapitres** (« Commandes, Premiers pas, Les cartes, L'arme grandit, Enchaînements, Annulation parfaite, Trophées, Arme secondaire, L'enclume, Autel de la fortune, Marchands, Sanctuaires, Coffres de récompense, La rage, Les étapes, Ce que tu gardes, Aide au combat, Nouveau : Donjons, Nouveautés, Conseils… ») sans regroupement. Le chapitre « Commandes » mélange des touches **en dur** (Z/Q/S/D, Maj, Comma) et la section « Tests et retours » (« F4 : se débloquer · F2 : infos de débogage (position, FPS…) · F9 : signaler un problème de carte (capture + position + ta note, dossier feedback) ») : texte de testeur, pas de joueur. Fond grisé : le Guide s'affiche **par-dessus le lobby encore visible**, dont le pied de page déborde.
Le Guide est une `ItemList` Godot native (texte brut, sélection grise) alors que tout le reste est doré.
**(c)** `ui/guide.gd` / `core/tutorial.gd` : « Tests et retours » (retirer de la version joueur, ou le replier) ; la fiche « Nouveau : Donjons » (« version » à la place d'une news) ; « Conseils : couper ou remettre ».
**(d)** Un Guide AAA est **contextuel** (bouton « ? » sur l'écran qu'on regarde) et en 6 chapitres maximum : Bouger/Combattre · Sorts et cartes · Équipement · Modes de jeu · Progression · Commandes.
**(e)** P2 M : regrouper en 6 chapitres avec sous-titres repliables, sélection dorée (`ui/guide.gd`, `core/tutorial.gd`) ; P2 S : retirer les touches de test ; P3 S : le bouton « Fermer (F1) » est bien, garder.

### 4.4 Héros > Équipement — `heros_equipement.png`, `pause_heros.png`
**(a)** **Meilleure page de l'audit** : poupée 3D, 10 emplacements, puissance d'équipement, 4 stats clés, grille d'inventaire à filtres, fiche d'objet en bas. Comparaison automatique avec la pièce portée. Format familier (Diablo / Path of Exile).
**(b)**
- Grille 9×5 quasi vide (4 à 8 objets) : 2/3 de la page est de l'espace mort ; pas d'état vide qui explique (« Ton coffre est vide : ramène des pièces de la Survie »).
- Fiche d'objet sans objet choisi : « CHOISIS UN OBJET / Clique une case de l'inventaire ou de l'équipement. / Double-clic (ou glisser-déposer) : équiper / retirer. / ★ : objet utilisé dans le préréglage d'une classe. » + panneau **Bonus de set** : « Les pièces de set ont un cadre vert ; 2, 4 et 6 pièces portées donnent des bonus. » : 5 lignes de mode d'emploi pour 2 lignes de vide.
- **Pause > Héros** réaffiche la page entière dont « Classe affichée ▾ » (carte de classe en plus, car l'en-tête « Héros » n'existe pas dans la pause) et un bouton **Forge** qui n'existe qu'au hub.
- La barre manette recouvre les stats du bas (PV / Attaque / Défense) et le bouton « Détail ».
- Noms anglais partout (« Defender Helmet », « Awaken Honor Impact Crown »).
- Bouton « Voir les sets » + « Set d'équipement — Aucun bonus actif » : 2 libellés pour une info absente.
**(c)** `inventory_page.gd:322` / `equipment_page.gd:322` (« Clique un objet pour voir ses statistiques… ») ; `inventory_page.gd:778` « Les pièces de set ont un cadre vert ; 2, 4 et 6 pièces portées donnent des bonus. » ; `equipment_page.gd:286` « Aucun bonus actif : porte 2, 4 ou 6 pièces d'un même set (cadre vert). » ; `inventory_page.gd:836` « « %s » : objet d'Eden (niveau %d dans le jeu d'origine). » ; `items.gd:773-777` « Suit ton niveau en run jusqu'au niveau 50 » (à garder en infobulle) et « Dans Eden : … ».
**(d)** Fiche d'objet AAA à droite en **infobulle flottante** (pas de panneau fixe vide), avec « Équiper » en clic droit ; filtres en icônes ; grille compacte.
**(e)** **P1 S** : supprimer les 2 notices et les lignes d'Eden ; P2 M : panneau de détail masqué tant qu'aucun objet n'est sélectionné (la grille gagne 250 px) ; P2 S : cacher « Classe affichée » et « Forge » dans la pause ; `ui/inventory_page.gd`, `ui/equipment_page.gd` (+ `ui/hero_screen.gd` pour le sous-titre).

### 4.5 Héros > Classe — `heros_classe.png`
**(a)** Très riche : parcours de maîtrise en niveaux 1-8 avec icônes, sorts de la classe, arbre de talents, plateau de certificats : l'écran « build » est de qualité Path of Exile / Last Epoch.
**(b)**
- Beaucoup trop dense (4 blocs, 60+ icônes, 4 sous-titres explicatifs) : un joueur novice ne sait pas par où commencer.
- « Certificats disponibles (clic ou glisser sur le plateau ; clic sur une case du plateau pour retirer) » est coupé en bas par la barre manette.
- Le plateau des certificats (7 cercles, verrous) est **sans légende** des couleurs (Puissance orange, Vigueur jaune, Précision bleu) autrement que dans 4 phrases de bonus ; zone 100 px × 100 px d'icônes de couleurs sans titre.
- Titre « GUERRIER — MAÎTRISE NIVEAU 1 / 40 » avec barre de progression noire sans valeur.
- Nombre de points « Points de talent : 2 / 2 » + bouton « Réinitialiser les talents » : ok.
**(c)** `talents_page.gd:64` « Chaque run fait monter la maîtrise de la classe jouée : points de talent, nouveaux sorts, certificats... (survole un niveau) » ; `talents_page.gd:126` « Clic : +1 point · survol : détail. Paliers : 15, 20, 25, 30 puis 35 points dépensés pour les colonnes de droite. » ; `talents_page.gd:137` « Posés sur le plateau : acquis dès le début de la run (toutes classes confondues). Les autres peuvent tomber en run comme des cartes. » ; `talents_page.gd:150` « Certificats disponibles (clic ou glisser sur le plateau ; clic sur une case du plateau pour retirer) » ; `talents_page.gd:206` « … · survol : détail » ; `talents_page.gd:336` « Eden Eternal : %s » ; `hero_screen.gd:299` (sous-titre « Sorts de la classe, parcours de maîtrise, talents et certificats (7 au plus). »).
**(d)** Onglets internes (Sorts | Talents | Certificats) ou défilement par sections ; la page ne montre qu'un bloc à la fois à 1600×900.
**(e)** P1 S : texte coupé en bas ; P2 L : scinder en 3 sous-onglets ; P2 S : supprimer 4 notices ; `ui/talents_page.gd`, `ui/hero_screen.gd`.

### 4.6 Héros > Apparence — `heros_apparence.png`
**(a)** Poupée 3D, emplacements Tenue / Tête / Dos / Aura / Arme à gauche, grille de tenues à droite, recherche + « Débloqués uniquement ».
**(b)**
- **122 tenues dont 121 verrouillées** affichées par défaut : mur de cadenas et de « Tenue secrète n°1 … n°10 » (10 vignettes sans nom ni image), le filtre « Débloqués uniquement » est une case **sans case visible** (le texte seul).
- Noms anglais d'Eden (« Cantonese Version Serial Number », « Heavy Metal Rockette », « Gothika Plumed Gown », « Emerald Tai Chi Dress »).
- Le texte « Costumes d'Eden : trésors de collection des boss (1 chance sur 4, plus s'ils sont enragés). Ils se portent avec n'importe quelle classe. » dit le taux de butin dans un écran de garde-robe.
- Bloc de texte en bas à gauche coupé (« Guerrier / Tenue : tenue de la classe / Tête : aucun / Dos : aucun / Arme : Iron Axe / Aura… »).
**(c)** `hero_pages.gd:329` « Costumes d'Eden : trésors de collection des boss (1 chance sur 4, plus s'ils sont enragés). Ils se portent avec n'importe quelle classe. » → « Obtenues sur les boss. » ; `hero_pages.gd:350` (aura) et `hero_pages.gd:368` (« Arme portée : « Auto » garde son propre modèle ; les modèles de base et les armes mythiques ou légendaires archivées de ce type sont libres. Les apparences d'armes d'Eden… », 330 caractères) ; `hero_pages.gd:377` « Apparences d'armes d'Eden : %d / %d obtenues (pour %s) » ; `hero_pages.gd:53` astuce de caméra ; texte récapitulatif sous la poupée (doublon des emplacements).
**(d)** « Débloqués uniquement » **activé par défaut** + un compteur « 1 / 122 » + une ligne « 121 à découvrir » repliée ; aperçu au survol sur la poupée.
**(e)** P1 S : filtre débloqués par défaut + case visible ; P2 M : traduire/renommer ; P2 S : supprimer 4 phrases ; `ui/hero_pages.gd` (AppearancePage), `core/game_data.gd` (noms).

### 4.7 Héros > Cartes — `heros_cartes.png`
**(a)** Grille d'icônes nettes avec bordure de couleur de rareté, fiche à droite, filtre « Toutes ».
**(b)** Doublon du Carnet > Cartes et du Grimoire ; 3 lignes de sous-titre (« Cartes de build : celles qui sont débloquées, et l'exploit qui débloque les autres. » / « Cartes de build 31 / 49 communes débloquées · 39 cartes Guerrier » / « Gagnées en montant de niveau, dans les sanctuaires, sur les gardiens d'élite et chez les marchands · survol : détail ») ; fiche de droite très vide (4 lignes pour 800 px) ; la dernière ligne de la grille est coupée sous la barre.
**(c)** `hero_screen.gd:301` ; `hero_pages.gd:609` « Gagnées en montant de niveau, dans les sanctuaires, sur les gardiens d'élite et chez les marchands · survol : détail ».
**(e)** P2 S : supprimer les 2 sous-titres ; P2 M : retirer l'onglet « Cartes » du Carnet (garder un compteur) ; `ui/hero_pages.gd`, `ui/carnet_pages.gd`.

### 4.8 Grimoire — `heros_grimoire.png`
**(a)** Trois colonnes (classe / compétences / détail du sort avec les 5 rangs, **tableau R1…R5** de dégâts et de recharge) : excellent pour l'optimiseur ; mises en page propres.
**(b)** Lisible mais **long** : colonne de gauche = statistiques de base (8 lignes), attributs (5), légende de stats (4 lignes), « Combo d'auto-attaque (clic gauche répété) : clique pour le détail. » (le combo n'existe plus depuis 0.1.127 : texte **faux**), puis arme, certificats, presets ; colonne de droite : « Eden Eternal : « Deep Impact » » en pied de chaque sort.
**(c)** `grimoire.gd:118` « Combo d'auto-attaque (clic gauche répété) : clique pour le détail. » (obsolète) ; `spell_info.gd:89` « Eden Eternal : « %s » » ; `grimoire.gd:133` « À débloquer avec les cartes de niveau (4 par run) ; certaines demandent un niveau de maîtrise. » ; `grimoire.gd:387` (« Fais glisser les sorts de la liste ci-dessus dans les cases… » 4 lignes).
**(e)** P1 S : corriger/supprimer la ligne du combo ; P2 S : supprimer « Eden Eternal » ; `ui/grimoire.gd`, `ui/spell_info.gd`.

### 4.9 Aide (« ? ») — `heros_aide.png`, `pause_aide.png`
**(a)** Tableau Monnaies (Où l'obtenir / À quoi elle sert / En fin de run) : **le plus clair des écrans d'aide** (source / usage / sort en fin de run).
**(b)** Page très technique : 8 chapitres dont « Calcul des dégâts », « Défense », formules (`Dégâts = Attaque × Puissance × aléa (92 à 108 %) × Critique × Statuts × Flow × …`) ; paragraphe d'intro de 4 lignes avant le tableau ; 5 puces de 2 lignes pour « Sur la carte » coupées en bas. Doublon complet du Guide F1.
**(c)** `info_page.gd:86` (« Une run de Survie = une époque de 3 maps… » 4 lignes) ; `info_page.gd:96-103` (« Sur la carte » 5 puces) ; `info_page.gd:107-178` (formules : à déplacer dans un chapitre « Pour les curieux » du Guide).
**(e)** P2 M : fusionner avec le Guide (voir T6) ; `ui/info_page.gd`, `ui/guide.gd`.

### 4.10 Coffres — `coffres.png`, `coffres_ouvert.png`
**(a)** **Le coffre 3D qui s'ouvre** est la meilleure idée visuelle du lobby ; colonne de liste avec icône colorée, nom, **×N**, bouton Ouvrir à droite : lisible. « Ouvrir tous les coffres sans choix » : bon raccourci.
**(b)**
- Paragraphe de 4 lignes sous le bouton (« Survie : chaque boss (un coffre d'apparence, plus un coffre de forge ou de joaillier), stèles du défi, élites 1 fois sur 5, monstres rarement, autel de la fortune. Tour : paliers 50, 100, 150 et 200 (apparence). Un coffre ramassé est toujours gardé. Les objets vont au coffre commun, les fournitures à ta réserve. ») : explique d'où viennent les coffres, au moment où on les ouvre.
- Détail d'un coffre : « Niveau 25 · Une aura légendaire que tu n'as pas encore. » **puis** « Une aura que tu n'as pas (77 encore à trouver à cette rareté) ; toutes obtenues : 60 insignes. » : la même phrase deux fois.
- Les 7 types se distinguent par la teinte seule (T9) ; le coffre sélectionné est surligné d'un liseré presque invisible ; la liste est coupée (ascenseur).
- Coffre ouvert « de set » : texte « Choisis 1 objet (clic sur une icône : sa fiche complète en dessous). Les autres disparaissent. », objets **« Pure Feather Crown / Gloves / Belt » en anglais**, la fiche détaillée sous les 3 choix est coupée (besoin de défiler dans un panneau déjà haut de 270 px de coffre).
- Sous-titre de l'écran : « Coffres de récompense rapportés des runs : apparences, forge, joaillier · Roulette : 3 lancers par jour » (identique sur les deux onglets).
**(c)** `chests_page.gd:30` (le paragraphe, 330 caractères) ; `chests_page.gd:341` ; `rewards.gd:188-191` (`« Une aura que tu n'as pas (%d encore à trouver…) »`, à afficher en infobulle ou supprimer, la 1re phrase suffit) ; `lobby.gd:1055` (sous-titre) ; `chests_page.gd:27` infobulle du bouton « Ouvrir tous… ».
**(d)** AAA (Diablo, Genshin) : au clic le coffre s'ouvre, **les récompenses volent en cercle**, une seule ligne de nom, pas de paragraphe ; le contenu d'un « choix » est en cartes plein écran.
**(e)** P1 S : supprimer le paragraphe et la 2e phrase ; P2 S : pastille d'icône par type ; P2 M : taille de la fiche d'objet sous les 3 choix (le coffre peut rétrécir à l'ouverture) ; `ui/chests_page.gd`, `core/rewards.gd`.

### 4.11 Roulette — `roulette.png`
**(a)** **Belle roue**, couleurs claires, légende « ■ Jackpot : apparence dorée : 4 % … » en couleur, compteur « Lancers offerts restants aujourd'hui : 0 / 3 ».
**(b)** Le bouton « Lancer en plus (100 insignes · tu as 380) » domine quand il ne reste plus de lancers offerts ; titre « LES GAINS (LA LARGEUR DE LA CASE = SA CHANCE) » **et** pourcentages : doublon ; « Série sans gain : 0 / 6 · lancers depuis le dernier rare : 0 / 25 » (compteurs de pitié) ; paragraphe de règles (« Trois lancers par jour, offerts… Après 6 « Perdu » d'affilée, tu gagnes au moins du commun ; après 25 lancers sans rare, un rare est garanti. ») ; la moitié du panneau de gauche est vide.
**(c)** `wheel_page.gd:29` (titre → « Gains »), `wheel_page.gd:37` (paragraphe → supprimer, garder « 3 lancers par jour »), `wheel_page.gd:65` (compteurs de pitié → supprimer ou infobulle).
**(d)** Un bouton « Tourner » **au centre de la roue**, le reste en légende ; l'animation de gain en plein écran.
**(e)** P2 S ; `ui/wheel_page.gd`.

### 4.12 Atelier : Armurerie / Fabrication / Forge — `atelier_*.png`
**(a)** Armurerie : grille d'objets avec prix en pastille, détail + bouton **ACHETER · 250 INSIGNES** doré, comparaison « Par rapport à ta pièce portée : Meilleur +85 % » : fonctionnelle.
**(b)**
- **Armurerie** : 12 objets sur 45 emplacements (grille vide), puis détail avec **noms anglais**, `Force 1023 · Agilité 647 · Chance 568 · PV 10399 · Dégâts 4 % · Critique magique 4 %`, « Awaken Honor Impact (0 pièce portée) / 2 pièces : +4 % Chance / 3 pièces … / 5 pièces … / Suit ton niveau en run jusqu'au niveau 70 / **Dans Eden : Awaken Armor** » puis un pavé de comparaison de 6 lignes de pourcentages (« +636 Agilité -3 % Recharge -2 % Esquive +10205 PV -11 Sagesse +1023 Force +568 Chance +4 % Dégâts +4 % Critique magique ») : illisible, ne dit pas si la pièce est **bonne**. L'indicateur « Meilleur +85 % » est la seule vraie info.
- **Fabrication** : page **vide** (une phrase d'explication + « Aucun plan : un donjon terminé en rapporte un une fois sur dix (le premier terminé en Héroïque ou Mythique en donne un à coup sûr). ») ; 800 px de noir.
- **Forge** : 5 boutons (« Améliorer · Enchanter · Gemmes · Polir · Réajuster · Démonter ») et un 6e ; à droite un panneau **vide** (« Forge prête ... Choisis un établi, puis lance l'action ») avec 2 notices (« Choisis une pièce dans la grille, puis un établi. » / « Hors run : les fournitures de ta réserve servent, et l'or est remplacé par des cristaux (1 pour 25 or). »). Une page où il faut sélectionner (a) une pièce, (b) un établi, (c) lancer : 3 étapes pour une seule action.
- Sous-titre « Armurerie · Fabrication des plans · Forge (améliorer, enchanter, sertir, polir, réajuster, démonter) » : liste des onglets **qui sont déjà affichés** à côté.
- Le total de ressources (300 insignes / 420 cristaux) change selon l'onglet : pas de bourse commune.
**(c)** `gear_shop_page.gd:50` « Les pièces que tu as choisies dans les coffres de la Survie, à acheter avec tes insignes : elles rejoignent ton coffre commun (collection, JcJ, forge). » ; `gear_shop_page.gd:52` (état vide) ; `fabrication_page.gd:69` (paragraphe) et `:89` (« Aucun plan : … ») ; `forge_bench.gd:35` (hint) et `:75` (« Hors run : … ») ; `lobby.gd:1053` (sous-titre de l'Atelier) ; `items.gd:773-777` « Dans Eden : … » et « Suit ton niveau en run jusqu'au niveau 70 ».
**(d)** Établi AAA (Diablo 3 Kanai, Path of Exile) : **un seul panneau** « glisse la pièce ici » ; le résultat à droite avec **avant → après** en 2 colonnes (« PV 10 399 → 10 702 »), pas de liste de pourcentages ; état vide avec **illustration** et la phrase d'invite.
**(e)** P1 S : retirer « Dans Eden… » et le pavé de comparaison (garder « Meilleur +85 % » et 3 écarts maximum) ; P1 S : état vide de la Fabrication (cadre avec icône + 1 phrase) ; P2 M : Forge en un seul panneau ; P2 S : bourse commune dans l'en-tête de l'Atelier ; `ui/gear_shop_page.gd`, `ui/fabrication_page.gd`, `ui/forge_bench.gd`, `core/items.gd`.

### 4.13 Carnet : Vue d'ensemble, Succès, Cartes, Trophées, Collection — `carnet_0..3.png`, `carnet_collection.png`
**(a)** Vue d'ensemble : **10 barres de complétion** avec compteur (5 / 60 classes, 31 / 49 cartes…) : très lisible, motivant ; Succès : étoile ☆/★, nom, description + progression « (0 / 1000) » : sobre et utile ; Collection : grille d'icônes + bonus d'archive + recherche.
**(b)**
- **Sous-titre erroné** : « Archive des trésors : chaque entrée donne un bonus permanent à tous les héros » s'affiche sur **tous** les onglets (même Succès et Cartes) alors qu'il ne décrit que la Collection.
- Vue d'ensemble : la liste « Déblocages » en dessous (Survie ✓, Zone d'entraînement ✓, Carnet 🔒 « Termine une première Survie »…) : le joueur est **dans** le Carnet et voit « Carnet : verrouillé » ; 18 lignes de verrous sans hiérarchie ; la phrase « Rien de ce qui est compté ici ne donne de la puissance : c'est la vue d'ensemble de ta sauvegarde. » ne sert qu'à se justifier.
- Succès : texte « Accordés pour le passé, sans aucune statistique. Titre porté : aucun » ; bouton « Aucun titre » sans mise en page ; 42 lignes sans catégories ni filtre « en cours / obtenus ».
- Cartes : 49 lignes de texte (doublon de Héros > Cartes) ; aucune icône (alors que la grille de Héros les a).
- Collection : « Taux : 1.0 % (16 / 1620) », « Score total de l'archive : 28 », « Entrées : 28 / 10500 (équipement : 0 / 3666) », « Apparences : 28 / 5330 (0.5 %) », « Armes : 0 / 1162 (0.0 %) »… : 5 statistiques d'archive dont aucune ne dit ce que le joueur **gagne** (« Bonus permanent, toutes classes : aucun pour l'instant »), cases à cocher « Obtenus uniquement / Ordre inversé » **sans case visible**, 4 phrases d'aide en bas (« Choisis une entrée (survol : fiche complète) ou un objet mythique / légendaire du coffre. Archiver retire l'objet du coffre et des préréglages ; on peut le retirer plus tard. »).
**(c)** `lobby.gd:1051` sous-titre ; `carnet_pages.gd:53` « Rien de ce qui est compté ici ne donne de la puissance… » ; `carnet_pages.gd:71` « Accordés pour le passé, sans aucune statistique. » ; `carnet_pages.gd:133` « Un effet se découvre en le ramassant en run (coffres de trophée, sanctuaires). 12 trophées au plus par run, tous différents. » ; `archive_pages.gd:221-246` (Score total + 3 lignes d'entrées) ; `archive_pages.gd:260` et `:267` (« Choisis une entrée… ») ; `archive_pages.gd:264` « (niveau %d dans Eden) » ; `archive.gd:217-226` (`« Dans Eden : … »`, `« Niveau %d d'Eden. »`).
**(d)** Carnet AAA (Hades, Genshin) : un **tableau de bord** (anneau de complétion + prochaine récompense) puis des **pages en grille** avec silhouettes grisées pour l'inconnu ; la liste des déblocages = une frise de la progression, pas un tableau de cadenas.
**(e)** **P1 S** : sous-titre par onglet (`PageScreen.set_title` à appeler à `page_changed`) ; P2 S : retirer « Déblocages » de la vue d'ensemble (le lobby les montre déjà grisés) ; P2 M : Succès en deux colonnes avec filtres, Cartes en grille avec icônes ; P2 S : cases à cocher visibles ; `ui/carnet_pages.gd`, `ui/archive_pages.gd`, `ui/page_screen.gd`, `core/archive.gd`.

### 4.14 Paramètres — `parametres0..5.png`
**(a)** Six onglets nets, **presets de mode de jeu** en cartes cliquables (Classique, Visée au curseur, Souris ARPG, RTS/MOBA, Action, Détente, Bot) : bonne idée, très AAA (Diablo IV « style de jeu »).
**(b)**
- **Fenêtre au look différent** du reste du jeu (fond plat, onglets étroits, boutons violets, OptionButton Godot, fenêtre 1070×650 centrée) et **trop petite** : on ne voit que 8 lignes de contrôles sur 24 dans l'onglet Touches (`parametres2`), 5 réglages sur 12 dans « Caméra & interface » (`parametres5`) ; le bouton « Touches par défaut » **flotte par-dessus la liste** (il masque la ligne suivante).
- Onglet « Combat » : 11 notes grises (« Automatique : quand tu ne te déplaces pas, le héros frappe le monstre le plus proche à portée. Se déplacer arrête l'attaque (pour esquiver). » sous un contrôle qui dit « Automatique : frappe seul les monstres au contact »).
- **Étiquettes d'état** : les interrupteurs affichent le mot « Activé » en vert **ou** « Désactivé » en gris dans un bouton de 200 px (pas de case / glissière) : on ne sait pas si c'est l'état ou l'action.
- Onglet « Affichage » à moitié vide (6 réglages), « Son » 3 curseurs : onglets de contenu très inégal.
- Cases « AUTO » : « Case 1 : AUTO » (vert) — état ou bouton ?
- Mode dev (F10) proposé dans « Caméra & interface » : « Mode dev (F10 : objets, ressources, progression, actions en run — pour tester) ».
**(c)** `settings_menu.gd:148-156` (4 phrases de description des modes de déplacement) ; `:175` (descriptions du niveau d'aide) ; `:179` ; `:181` ; `:204` « Jusqu'à 3 appuis de sorts sont gardés et joués dans l'ordre : marteler la touche d'une case donne toute la chaîne, taper 1-2-3 pendant un sort les lance l'un après l'autre. Plus de « Trop tôt ». L'esquive et le saut partent tout de suite et vident la mémoire. … » ; `:207` ; `:210` ; `:212` ; `:214` ; `:234` « Clique sur une case puis appuie sur une touche ou un bouton de souris. Échap : annuler · Suppr / Retour : effacer. Une touche déjà prise est retirée de l'autre action. » ; `:477` « Les zones d'attaque (avertissements rouges, cercles au sol) restent toujours visibles : seuls les décors lumineux des sorts et des skins sont concernés. » ; `:485` Mode dev.
**(d)** AAA : paramètres **plein écran** en 2 colonnes (catégories à gauche, réglages à droite), **interrupteurs** (glissières), **info au survol d'un réglage** dans un cadre fixe en bas de page (pas de notes sous chaque ligne), bouton « Rétablir » par catégorie.
**(e)** P1 M : fenêtre plein écran `PageScreen` (même habillage que Carnet) avec onglets à gauche ; P1 S : bouton « Touches par défaut » en pied de page fixe ; P2 M : interrupteurs à glissière ; P2 S : supprimer 9 notes ; `ui/settings_menu.gd`, `ui/ui_theme.gd`.

---

## 5. En partie : HUD, cartes, coffres, pause, bilans, infobulles

### 5.1 HUD de Survie — `hud_survie_1/2/3.png`, `hud_grande_carte.png`, `run_choix_arme.png`
**(a)** **Très bon HUD** : orbe de vie à gauche, orbe d'expérience (niveau au centre) à droite, 4 cases de sorts + esquive + 2 potions au centre-bas, mini-carte ronde en haut à droite, cible en haut au centre (PV et niveau), objectifs repliables : hiérarchie nette, centre de l'écran dégagé, aucun ornement qui masque le jeu. Chiffres de dégâts, « ESQUIVE ! » : bon feedback. Compteur de dégâts cumulés à droite : grossit à chaque coup (fort retour).
**(b)**
- **Bas gauche** : « F1 : aide · F9 : signaler un problème » en 13 px à 65 % d'opacité **sur l'herbe** : invisible. Bas droit : « Alt + clic droit : noter un problème · Eden Slash v0.1.163 » : idem, deux étiquettes de testeur en permanence.
- **Pile de panneaux haut gauche** : objectifs, puis « Premiers pas 5 / 10 » (aussi large que les objectifs, avec un bouton « Passer »), puis fil de butin (« Coffre ouvragé ouvert ») : trois blocs empilés qui se touchent.
- Les 4 cases de sorts affichent « AUTO » en vert **même vides** (dans cette capture : sorts non appris) : le badge dit « AUTO » sur un emplacement sans sort ; la légende « SORTS AUTO » à gauche en bleu à 11 px.
- La barre fait 600 px dans un cadre de 900 : l'esquive (Maj) et les potions (C, V) sont petites (40 px) ; potions avec compteur « 2 » collé à l'icône.
- **Compteur FPS** (« 165 FPS » 12 px) sous la mini-carte en permanence (option `Settings.interface.show_fps`, activée dans les réglages du joueur).
- Cible : « Limestone Forged / Nv 8 » : nom en anglais.
- Mini-carte : pas de légende ; la **grande carte (M)** a une légende de 14 lignes (Donjon, Marchand, Sanctuaire, Fort d'élite, Coffre, Coffre ouvragé, Coffre doré, Enclume, Autel du scribe, Fontaine de vie, Pierre d'aimant, Autel de cupidité, Stèle du défi, Autel de la fortune) en **overlay opaque sur la carte** : cache une partie de la carte ; icônes de 6 px quasi indiscernables (11 couleurs de ronds).
- En-tête objectifs : « LIMESTONE MTN. · ÉTAPE 1/3 · NV 1-15 » + « ⏳ 09:48 » + « Sceaux ◇◇◇ » + « 30 or · 0 clé » + « [Tab] objectifs » : 5 informations sur 2 lignes de 14 px.
- Le texte « Rage dans 09:57 (monstres et butin plus forts) » : phrase d'explication dans un panneau d'objectifs.
**(c)** `test_tools.gd:116` « F1 : aide · F9 : signaler un problème » ; `ui_theme.gd:149` « Alt + clic droit : noter un problème · » + version (garder la version seule, 12 px, 40 % d'opacité) ; `hud.gd:426` « Rage dans %02d:%02d (monstres et butin plus forts) » → « Rage dans 09:57 » ; `hud.gd:408-409` (« Évite les zones rouges ([Maj] : esquive) / Miroir : ne frappe pas le boss pendant 3 s / L'onde au bord jaune se saute ») : conseil de boss en texte permanent, à passer en fiche de découverte à la première rencontre ; `hud.gd:439` (légende de la grande carte) ; `hud.gd:473` « DÉGÂTS CUMULÉS » + `:967` « record de la run 297 · record 297 ».
**(d)** HUD AAA (Diablo IV, Last Epoch) : **tout ce qui n'est pas vital disparaît** (FPS, aide, version) ; les objectifs sont **une ligne** (« Trouve 3 sceaux · 0/3 ») ; la carte est ouverte par M avec légende repliée.
**(e)** P1 S : cacher F1/F9/Alt-clic (afficher 5 s au début de la run) ; P1 S : « AUTO » seulement sur une case remplie ; P2 S : fusionner « Premiers pas » avec les objectifs (une seule pile) ; P2 S : légende de carte repliable ; P2 S : FPS désactivé par défaut ; fichiers : `ui/hud.gd`, `ui/hud_widgets.gd`, `ui/minimap.gd`, `ui/test_tools.gd`, `ui/ui_theme.gd`.

### 5.2 Choix de carte / de variante d'arme / coffre d'équipement — `run_choix_arme.png`, `run_choix_variante_arme.png`, `run_coffre_equipement.png`, `hud_tour_choix_carte.png`
**(a)** **Cartes lisibles et belles** : bordure de la couleur de la rareté, icône, nom, description, **totaux avant → après** (« niv. 0 → 1 », « Dégâts sur la durée : +30 % ») ; 1, 2, 3 au clavier ; « Relancer (N) », « Bannir », « Garder » : bien pensé.
**(b)**
- **Deux étapes** (cliquer puis « Valider ») : voir T8.
- Phrase « Clique sur une carte (ou 1, 2, 3) puis sur Valider (ou Entrée) » sous le bouton.
- Choix d'arme au départ : « Rage Battle Axe » / « Bone Harvest Axe » (anglais), la différence entre les deux cartes est dans le texte (« Taille large » / « Hache de jet ») ; le choix est l'**acte le plus important** de la run et il est présenté avec 6 lignes de stats « +3 Force +3 Agilité +3 Chance » **identiques** pour les deux, qui ne différencient rien.
- Coffre doré : « Agile Fox Cloak » : type **Cape** mais icône de gants ; « Temple Knights- Rainbow Aurora Gloves » avec icône de chaussette ; 3e carte « Sorcery Robe » (niveau 1) : le niveau affiché « niv. 50 / niv. 50 / niv. 1 » ne dit pas laquelle est la meilleure ; 6 lignes de stats, la dernière **coupée** (« +4 % Vitesse… ») ; « Emplacement libre » en vert répété sur chaque carte.
- **Bug de libellé** : en Donjon, en Siège et dans la Tour la 1re carte s'appelle « **La Tour : ta carte de départ** » (`world.gd:244`), même dans « Le Siège ». 
- Cartes superposées avec le panneau de fiche de découverte (« LES CARTES — À chaque niveau, choisis une carte parmi trois… ») qui reste à droite et déborde du bandeau de la carte.
- Fond : jeu atténué, mais HUD (jauge de vie, mini-carte) restent par-dessus : bien.
**(c)** `card_picker.gd:95` ; `world.gd:244` ; `run_page.gd`…
**(d)** Cartes AAA : plus grandes, **animation de retournement**, **sélection au clic = validation**, rareté en halo ; pour l'équipement : **comparaison avec la pièce portée en une ligne** (« +12 % vs ta cape ») au lieu de 6 lignes.
**(e)** **P1 S** : clic = choix (T8), garder le délai anti-rafale ; **P1 S** : titre « Ta carte de départ » (`core/world.gd` : hors lot ui) ; P2 S : 3 lignes de stats maximum + comparaison ; P2 S : icône par emplacement ; `ui/card_picker.gd`, `ui/item_widgets.gd`.

### 5.3 Menu pause — `pause_run.png`, `pause_heros.png`, `pause_aide.png`
**(a)** Plein écran, 3 onglets, bourse (or, clé, cristaux), bouton « Reprendre » **doré** bien visible, bilan à droite, sac de fournitures.
**(b)**
- **Page « Run » : 8 des 12 lignes sont « Case N : libre / Enchaînement 2 : libre / Enchaînement 3 : libre »**, chacune avec sa phrase (« Quand les 4 cases sont pleines, les cartes de sort deviennent des enchaînements. » **répétée 8 fois**) ; le défilement est nécessaire pour voir la case 4 ; 12 lignes vides pour un joueur au niveau 1.
- Colonne du milieu : « TROPHÉES (0 / 12) — Aucun trophée pour l'instant. Coffres de trophée (4 par map) et sanctuaires : jusqu'à 12 trophées par run, tous d'effets différents, tous actifs. » + « CARTES DE BUILD ET PASSIFS — Aucune carte pour l'instant : monte de niveau pour en choisir. » : 2 messages d'état vide très verbeux dans un écran vide à 60 %.
- Bilan : « Classe : Guerrier · niveau 1 / Durée : 0 min 05 s / Monstres vaincus : 0 · élites : 0 / Butin ramassé : 0 objet(s) · or gagné : 0 » en texte brut, **sans icône** (le HUD en a).
- **« Quitter le jeu » sans confirmation**, collé sous « Abandonner : retour au lobby » : risque de fausse manœuvre (P1).
- « S'extraire (10 s · X) » : parenthèse d'infos dans le bouton.
- Pas de « Sorties en 2 clics » pour manette : « Reprendre » n'est pas le bouton par défaut (le cadre part sur le 1er contrôle de la 1re colonne).
- Page « Héros » : identique à l'écran Héros (§4.4) ; page « Aide » : voir §4.9.
- Le menu pause ne montre pas le **temps de run restant** ni la carte.
**(c)** `run_page.gd:76` « Glisse un sort sur un autre pour échanger leurs places (touches et enchaînements). » ; `run_page.gd:80` « Les compétences s'obtiennent avec les cartes de niveau. » ; `run_page.gd:92` « Quand les 4 cases sont pleines, les cartes de sort deviennent des enchaînements. » (×8) ; `run_page.gd:111` « Coffres de trophée (4 par map) et sanctuaires : jusqu'à %d trophées par run… » ; `run_page.gd:64` bouton « Quitter le jeu » ; `pause_menu.gd:46-56` (4 textes de confirmation : « La run sera abandonnée : l'or, les clés et les fournitures de la run sont perdus (les coffres de récompense ramassés et les insignes sont gardés). Retourner au lobby ? »).
**(d)** Pause AAA : **colonne de 5 boutons** au centre (Reprendre · Options · Aide · Quitter la partie), le reste (build, bilan) via un bouton « Personnage » ; jamais de liste de cases vides.
**(e)** **P1 S** : confirmation « Quitter le jeu » ou retrait du bouton (Échap > Quitter la partie > confirmer) ; **P1 S** : n'afficher que les cases **occupées** + 1 case « + » ; P2 S : supprimer les 4 phrases d'état vide ; P2 M : bilan avec icônes ; `ui/run_page.gd`, `ui/pause_menu.gd`.

### 5.4 Bilans de fin de run — `bilan_survie.png`, `bilan_duel.png`, `bilan_tour.png`, `bilan_donjon.png`, `bilan_royale.png`
**(a)** Titre en gros (« RUN ABANDONNÉE », « VICTOIRE ! », « TOP 3 »), **7 tuiles de chiffres** (classe, niveau, durée, monstres, élites, or, étape), boutons **Rejouer** (vert) / **Retour au lobby** (violet) : bonne idée récente (0.1.139). Code couleur gardé (vert) / perdu (rouge) clair.
**(b)**
- Cinq écrans, cinq mises en page : tailles 760×380, 800×460, 760×460, 1120×720 ; titres 42 / 46 px ; deux familles de boutons (`Hud.style` à la main).
- **Bilan Survie** : 720 px de haut pour 40 % de contenu : tuiles, puis 6 lignes de texte colorées **qui se répètent** (« Expertise Guerrier : +15 » / « Aide au combat : Détente » / « 25 insignes · 1 pièce(s) découverte(s) · 0 coffre(s) à ouvrir · 2 fourniture(s) perdues · or et clés perdus » / « Gardé : 25 insignes · 1 pièce(s) découverte(s) dans les coffres » / « L'équipement de la run n'est pas gardé : chaque pièce choisie dans un coffre devient achetable à l'Armurerie avec tes insignes. Les fournitures de la run, l'or et les clés sont perdus. Les coffres de récompense ramassés sont toujours gardés. ») ; « 25 insignes » et « 1 pièce découverte » **apparaissent deux fois** ; les boutons sont **au milieu de l'écran** au lieu du bas du panneau ; **le panneau du HUD derrière** (fiche « Les cartes », jauge de vie) reste visible et se lit à travers.
- Duel : « Équipé niveau 1 · manches : — / Plus gros coup porté : 0 % des PV de l'adversaire · reçu : 0 % de tes PV » : statistiques sans contexte ; « Victoires contre cette classe dans cette difficulté : 3 ».
- Tour : « ÉTAGE ATTEINT : 14 / 200 · NORMAL · DUELS GAGNÉS : 4 / 60 » (3 informations dans un titre), « Samouraï · niveau 1 · 0 min 06 s · monstres vaincus : 0 · élites : 0 » : une ligne dense.
- Donjon / Royale : 200 px vides sous le texte ; « Butin : 0 cristaux (menu Coffres) » ; « Seules les récompenses ci-dessus sont gardées (équipement, niveaux et potions de la partie restent dans la partie). ».
- Aucun bilan n'a de **récompense animée** (cristaux qui montent, coffre qui apparaît, barre de maîtrise qui se remplit).
**(c)** `results_screen.gd:78` « Aide au combat : %s » ; `:117-121` (les 3 lignes « Gardé… » + « L'équipement de la run n'est pas gardé… ») ; `royale_results.gd:42` ; `duel_results.gd:49,54,56` ; `tower_results.gd:32,39,53` ; `dungeon_results.gd:57` « (menu Coffres) ».
**(d)** AAA (Hades, Slay the Spire, Diablo IV) : bilan **plein écran** avec 3 chiffres vedettes, **récompenses qui se déroulent** une par une (insignes +25, pièce découverte, étoile), un bouton principal « Continuer », et la barre de maîtrise qui monte.
**(e)** **P1 M** : un composant unique `ResultsPanel` (titre, tuiles, bloc « gagné / perdu » à 2 colonnes, 2 boutons en pied) utilisé par les 5 bilans ; P2 S : supprimer les 4 lignes de justification ; P3 M : animation des gains ; `ui/results_screen.gd`, `ui/duel_results.gd`, `ui/tower_results.gd`, `ui/dungeon_results.gd`, `ui/royale_results.gd` (+ nouveau `ui/results_panel.gd`).

### 5.5 HUD des autres modes — `hud_duel.png`, `hud_royale.png`, `hud_tour_choix_carte.png`, `hud_donjon_choix_carte.png`, `hud_entrainement.png`
**(a)** Duel : en-tête « DUEL · GUERRIER · NV 20-20 — Manche 1 · 0 - 0 » + « Duel difficile · 2 manches gagnantes », barre de l'adversaire en haut au centre avec PV chiffrés (« 3 422 / 3 868 »), **icônes de sorts de l'adversaire sous sa barre** et sur la barre du joueur (délais) : très bon feedback de duel. Royale : objectifs en puces avec ◇, anneau en temps réel (« Anneau 1/4 · se referme dans 17 s »).
**(b)**
- En duel, **« Duel difficile · 2 manches gagnantes »** est une phrase fixe pendant tout le combat ; « [Tab] objectifs » reste affiché alors qu'il n'y a pas d'objectif ; le compteur « DÉGÂTS CUMULÉS 297 · record de la run 297 · record 297 » s'affiche **en duel** (où le record n'a pas de sens, `hud.gd:473`).
- Royale : panneau d'objectifs de 590 px de large, 5 lignes, **déplié en permanence** ; « Premiers pas 2 / 10 » (tutoriel de la Survie : « Déplace-toi avec ZQSD et frappe en restant près des monstres : 10 à vaincre. ») **affiché dans un Battle royale** (hors sujet) ; « Coffre ouvragé ouvert » dans le fil.
- Tour/Donjon/Siège : en-tête « LA TOUR · LIMESTONE MTN. · NV 1-1 — Étage 1/200 » (la 2e ligne « Normal · record : étage 0 ») : la barre de PV de la salle n'est pas affichée ; « NV 14-14 » (intervalle identique répété).
- **Intervalle de niveau** « NV 1-15 / 20-20 / 14-14 » dans chaque titre : format technique.
**(c)** `hud.gd:392` (`"%s · record : étage %d"`) ; `hud.gd:390` (« Duel %s · 2 manches gagnantes ») ; `hud.gd:424-426` ; `hud.gd:238` / `core/tutorial.gd` (Premiers pas dans les autres modes).
**(e)** P1 S : pas de « Premiers pas » hors Survie ; P2 S : pas de compteur de dégâts cumulés en duel ; P2 S : « NV 14 » si l'intervalle est nul ; P3 S ; `ui/hud.gd`.

### 5.6 Infobulles — `tip_items.png`, `tip_spells.png`
**(a)** **Infobulle d'objet** (`ItemWidgets.item_card`) : cadre de la couleur de rareté, icône, nom, « Légendaire · Torse · pièce de set · niveau 50 », Qualité 116 %, stats avec bonus entre parenthèses (« Force 83 (+11) » en vert), set et ses paliers : **format correct** et complet. Infobulle de sort : portée, recharge, zone, effets en puces, **tableau R1…R5** : très bon pour l'optimiseur.
**(b)**
- Trop dense (14 lignes de stats pour une cape) : le joueur ne voit pas **ce qui compte** (la stat principale) : toutes les lignes ont la même taille/graisse.
- Doublon de stat : « Défense 4 % » **et** « Défense 231 (+32) » sur la même pièce (pourcentage et valeur : deux lignes du même nom).
- « Temple Knights- First Dawn Brigandine » : **tiret mal formé**, nom du set préfixant le nom de la pièce, en anglais.
- Pied de carte : « Prochaine amélioration : 100 % de réussite » (sur une pièce non améliorable en run), « Temple Knights - First Dawn (0 pièce portée) / 2 pièces : +4 % Force ; +2 % Esquive / 5 pièces : +10 % Agilité ; +10 % Attaque / Suit ton niveau en run jusqu'au niveau 50 / **Dans Eden : …** » : 5 lignes de bas de carte dont 2 sans valeur.
- Infobulle de sort : « Impact profond : 200 % en cône et renverse (0,8 s). » (phrase), puis **le même contenu** sous « Effets » en 3 puces (« Dégâts : 200 % de l'attaque… · Cibles : tous les ennemis de la zone · Applique Renversé (0,8 s) : Ne peut plus agir »), puis l'amélioration par rang en 3 lignes, puis « Eden Eternal : « Deep Impact » » : la description est répétée.
**(c)** `items.gd:773-777` ; `spell_info.gd:89` ; `spell_info.gd:58-94` (description + effets : une des deux) ; `items.gd:753` « Prochaine amélioration : %d %% de réussite ».
**(d)** AAA : 1) **stat principale en gros** (« 231 Défense »), 2) 3 à 5 lignes secondaires, 3) **comparaison par flèche ▲▼** + valeur, 4) set en bas replié, 5) **Maj = détails**.
**(e)** P1 S : supprimer « Dans Eden » / « Eden Eternal » / description répétée ; P2 M : stat principale en gros + « Maj : détails » (`ui/item_widgets.gd` : **fichier modifié par N1 en ce moment**, à faire après) ; P2 S : dédoublonner « Défense » ; `ui/item_widgets.gd`, `ui/spell_info.gd`, `core/items.gd`.

---

## 6. Texte superflu : table exhaustive (chaîne exacte → fichier:ligne → action)

### 6.1 Le jeu d'Eden d'origine (à retirer de l'affichage joueur ; garder les données)
| Chaîne affichée | Fichier:ligne | Action |
|---|---|---|
| « « %s » : objet d'Eden (niveau %d dans le jeu d'origine). » | `ui/inventory_page.gd:836` | supprimer |
| « Dans Eden : %s » (infobulle d'objet) | `core/items.gd:777` | supprimer |
| « [b]%s[/b] (niveau %d dans Eden) — %s » (Archive) | `ui/archive_pages.gd:264` | « [b]%s[/b] — %s » |
| « Niveau %d d'Eden. Légendaire : butin du boss de %s (30 %%, 50 %% s'il est enragé).%s » | `core/archive.gd:223` | « Légendaire : boss de %s. » |
| « Niveau %d d'Eden. Mythique : butin du boss de %s, ou fabrication chez un marchand ambulant de cette zone.%s » | `core/archive.gd:225` | « Mythique : boss de %s ou marchand. » |
| « Niveau %d d'Eden : tombe dans %s.%s » | `core/archive.gd:226` | « Tombe dans %s. » |
| « Dans Eden : %s. » (suffixe) | `core/archive.gd:217` | supprimer |
| « Eden Eternal : « %s » » (infobulle de sort) | `ui/spell_info.gd:89` | supprimer |
| « Eden Eternal : %s » (talent) | `ui/talents_page.gd:336` | supprimer |
| « Costumes d'Eden : trésors de collection des boss (1 chance sur 4, plus s'ils sont enragés). Ils se portent avec n'importe quelle classe. » | `ui/hero_pages.gd:329` | « Butin des boss. » |
| « Apparences d'armes d'Eden : %d / %d obtenues (pour %s) » | `ui/hero_pages.gd:377` | « Apparences d'armes : %d / %d » |
| « Plans d'Eden de cette zone : objets mythiques (orange) jusqu'au niveau d'Eden atteint, pièces de set comprises. Toujours 100 % de qualité. » | `ui/merchant_pages.gd:278` | supprimer |
| « Des donjons d'Eden en plusieurs salles : vagues… » | `ui/activities.gd:16` | « Quatre salles, un boss. » |
| « Chaque monstre garde la défense de sa fiche d'Eden, ×1,1 par niveau… » | `ui/info_page.gd:178` | supprimer (ou section « curieux ») |
| « Les sets d'Eden sont des pièces mythiques (orange) : boss et fabrication. Bonus à 2 et 5 pièces portées. » | `ui/inventory_page.gd:1046` | « Bonus à 2, 4 et 6 pièces. » |
| « Bonus d'Eden de toutes les classes (débloqués par leur maîtrise)… » (infobulle) | `ui/talents_page.gd:133` | « Certificats » |
| « Un coffre d'équipement propose 3 pièces d'Eden de l'époque, avec une relance… » | `ui/info_page.gd:96` | « 3 pièces au choix. » |
| « Sa classe, son équipement du catalogue d'Eden, son trophée… » | `ui/lobby.gd:651` | supprimer l'infobulle |
| « %s : catalogue d'Eden (profil niveau %d) » | `ui/profile_editor.gd:504` (éditeur dev : P3) | — |
| « Suit ton niveau en run jusqu'au niveau %d » | `core/items.gd:773-774` | infobulle (Maj) |
| Noms de pièces / monstres / zones / costumes en anglais | `data/eden_items*.json`, `data/monsters*.json`, `data/zones.json`, `data/cosmetics*.json` | table `data/names_fr.json` (T5) |

### 6.2 Phrases d'explication qui répètent l'évident / règles de jeu en texte permanent
| Chaîne | Fichier:ligne | Action |
|---|---|---|
| « Clique sur une carte (ou 1, 2, 3) puis sur Valider (ou Entrée) » | `ui/card_picker.gd:95` | supprimer (T8) |
| « Tu pars sans équipement : arme au choix au départ, puis coffres d'emplacement sur chaque carte. » | `ui/lobby.gd:1293` | supprimer |
| « Une Survie de l'époque I avec deux modificateurs imposés et trois classes proposées… » | `ui/activities.gd` (`mastery`.desc) | supprimer |
| « Les contrats se remplissent à chaque Survie avec cette classe. » | `ui/lobby.gd` (`_menu_mastery`) | supprimer |
| « Survie : chaque boss (un coffre d'apparence…) » (330 caractères) | `ui/chests_page.gd:30` | supprimer |
| « Trois lancers par jour, offerts. Les gains sont des apparences… Après 6 « Perdu »… » | `ui/wheel_page.gd:37` | « 3 lancers offerts par jour. » |
| « Série sans gain : %d / %d · lancers depuis le dernier rare : %d / %d » | `ui/wheel_page.gd:65` | supprimer |
| « Les gains (la largeur de la case = sa chance) » | `ui/wheel_page.gd:29` | « Gains » |
| « Rien de ce qui est compté ici ne donne de la puissance : c'est la vue d'ensemble de ta sauvegarde. » | `ui/carnet_pages.gd:53` | supprimer |
| « Accordés pour le passé, sans aucune statistique. » | `ui/carnet_pages.gd:71` | supprimer |
| « Un effet se découvre en le ramassant en run (coffres de trophée, sanctuaires). 12 trophées au plus par run, tous différents. » | `ui/carnet_pages.gd:133` | supprimer |
| « Archive des trésors : chaque entrée donne un bonus permanent à tous les héros » (sur tous les onglets) | `ui/lobby.gd:1051` | par onglet |
| « Coffres de récompense rapportés des runs : apparences, forge, joaillier · Roulette : 3 lancers par jour » | `ui/lobby.gd:1055` | « Coffres » seul |
| « Armurerie · Fabrication des plans · Forge (améliorer, enchanter, sertir, polir, réajuster, démonter) » | `ui/lobby.gd:1053` | supprimer |
| « Les pièces que tu as choisies dans les coffres de la Survie, à acheter avec tes insignes… » | `ui/gear_shop_page.gd:50` | « Pièces découvertes en Survie. » |
| « Un plan trouvé dans un donjon te laisse fabriquer… Le plan reste à toi. » | `ui/fabrication_page.gd:69` | 1 phrase |
| « Choisis une pièce (portée ou dans ton coffre), puis un établi. Hors run… » | `ui/forge_bench.gd:35,75` ; `ui/merchant_pages.gd:365,371` | supprimer |
| « Chaque run fait monter la maîtrise de la classe jouée : points de talent, nouveaux sorts, certificats... (survole un niveau) » | `ui/talents_page.gd:64` | supprimer |
| « Clic : +1 point · survol : détail. Paliers : 15, 20, 25, 30 puis 35 points… » | `ui/talents_page.gd:126` | infobulle |
| « Posés sur le plateau : acquis dès le début de la run… » | `ui/talents_page.gd:137,362` | 1 fois |
| « Combo d'auto-attaque (clic gauche répété) : clique pour le détail. » (**obsolète**) | `ui/grimoire.gd:118` | supprimer |
| « À débloquer avec les cartes de niveau (4 par run)… » | `ui/grimoire.gd:133` | supprimer |
| « Fais glisser les sorts de la liste ci-dessus dans les cases… » | `ui/grimoire.gd:387` | infobulle |
| « Glisse un sort sur un autre pour échanger leurs places… » | `ui/run_page.gd:76` | infobulle |
| « Quand les 4 cases sont pleines, les cartes de sort deviennent des enchaînements. » (×8) | `ui/run_page.gd:92` | supprimer |
| « Les compétences s'obtiennent avec les cartes de niveau. » (×4) | `ui/run_page.gd:80` | supprimer |
| « Coffres de trophée (4 par map) et sanctuaires : jusqu'à %d trophées par run… » | `ui/run_page.gd:111` | « Aucun trophée » |
| « Clique un objet pour voir ses statistiques… ★ : objet utilisé dans le préréglage d'une classe. » | `ui/inventory_page.gd:322`, `ui/equipment_page.gd:322` | supprimer |
| « Les pièces de set ont un cadre vert ; 2, 4 et 6 pièces portées donnent des bonus. » | `ui/inventory_page.gd:778` | supprimer |
| « Aucun bonus actif : porte 2, 4 ou 6 pièces d'un même set (cadre vert). » | `ui/equipment_page.gd:286` | « Aucun bonus » |
| « Pendant la run, tu portes les copies de ton équipement de départ et le butin trouvé. » | `ui/equipment_page.gd:213` | supprimer |
| « Cartes de build : celles qui sont débloquées, et l'exploit qui débloque les autres. » | `ui/hero_screen.gd:301` | supprimer |
| « Gagnées en montant de niveau, dans les sanctuaires… · survol : détail » | `ui/hero_pages.gd:609` | supprimer |
| « Choisis 1 objet (clic sur une icône : sa fiche complète en dessous). Les autres disparaissent. » | `ui/chests_page.gd:341` | « Choisis 1 objet » |
| « Une aura que tu n'as pas (%d encore à trouver à cette rareté) ; toutes obtenues : 60 insignes. » (2e phrase du détail) | `core/rewards.gd:188` | supprimer |
| « Duel à l'arme, niveau 10 : tu joues avec ton preset de sorts ; si tu tombes, tes alliés continuent. 2 manches gagnantes. » | `ui/lobby.gd:381` | supprimer |
| « Duel à l'arme, niveau 10 : seul ton preset de sorts compte. L'aide est limitée à « Assistée »… » | `ui/lobby.gd:471` | supprimer |
| « À l'arme : seul ton preset de sorts compte, à armes égales… » / « Ton build doit être prêt avant de t'inscrire… » | `ui/lobby.gd:589` | supprimer (les ✓/✗ le disent) |
| « Tout ton build compte (équipement, maîtrise, certificats), sous les plafonds du Duel… » | `ui/lobby.gd:326` | supprimer |
| Bloc de 5 puces du Battle royale « • Chacun pour soi : 7 héros IA… » | `ui/lobby.gd:419` | 3 puces de 6 mots |
| « Tes deux alliés IA (« Au hasard » sinon) : ils deviennent tes rivaux quand le boss tombe » | `ui/lobby.gd:1423` | « Alliés IA » |
| « Alliés IA (PV des monstres +50 % par allié, butin inchangé) » | `ui/lobby.gd` (`_dungeon_allies_picker`) | « Alliés IA » + infobulle |
| « Un cerveau d'IA entraînée joue le premier adversaire (très fort aux paliers élevés)… » | `ui/lobby.gd:319,639` | infobulle |
| « Rang héroïque %d : monstres +%d %% PV, +%d %% dégâts, insignes +%d %% » | `ui/lobby.gd:1281` | forme courte |
| « Run normale (rangs héroïques ouverts) » | `ui/lobby.gd:1281` | « Rang héroïque 0 » |
| « Sauvegarde %d · coffre commun %d objet(s) · %d run(s), %d victoire(s) » | `ui/lobby.gd:1610` | supprimer |
| « … · zone %d / %d · %d débloquée(s) » | `ui/lobby.gd:1600` | supprimer |
| « Glisser : tourner autour du héros · molette : zoom · clic droit glissé : hauteur · double-clic : vue de départ » | `ui/lobby.gd:1000` | « Glisser : tourner · Molette : zoom » |
| « Alt + clic droit : noter un problème · » | `ui/ui_theme.gd:149` | masquer |
| « F1 : aide · F9 : signaler un problème » | `ui/test_tools.gd:116` | masquer |
| « Tout se change ensuite dans Échap > Paramètres. L'aide n'enlève aucune récompense en JcE. » | `ui/welcome.gd` (étape 3) | supprimer |
| « Les 5 classes restent ouvertes : ce choix dit seulement avec laquelle tu commences… » | `ui/welcome.gd` (étape 2) | « Les autres classes se débloquent en jouant. » |
| « Mémoire des touches (3 appuis gardés), tenir la touche enchaîne, anneau d'annonce… » | `ui/welcome.gd` (étape 3) | supprimer |
| Notes sous chaque réglage (Combat, Touches, Interface) | `ui/settings_menu.gd:148-156,175,179,181,204,207,210,212,214,234,477` | description au survol |
| « L'équipement de la run n'est pas gardé : chaque pièce choisie dans un coffre devient achetable… » (bilan) | `ui/results_screen.gd:119-121` | supprimer |
| « Gardé : %d insignes · %d pièce(s) découverte(s) dans les coffres » (doublon de la ligne au-dessus) | `ui/results_screen.gd:117` | supprimer |
| « Seules les récompenses ci-dessus sont gardées (équipement, niveaux et potions de la partie restent dans la partie). » | `ui/royale_results.gd:42` | supprimer |
| « Aide au combat : %s » (bilan) | `ui/results_screen.gd:78` | supprimer |
| « La run sera abandonnée : l'or, les clés et les fournitures de la run sont perdus (les coffres de récompense ramassés et les insignes sont gardés). Retourner au lobby ? » | `ui/pause_menu.gd:46` | « Abandonner la run ? Or, clés et fournitures seront perdus. » |
| « Rage dans %02d:%02d (monstres et butin plus forts) » | `ui/hud.gd:426` | « Rage dans 09:57 » |
| « ⚔ Vaincs le boss du donjon / Évite les zones rouges ([Maj] : esquive) / Miroir : ne frappe pas le boss… / L'onde au bord jaune se saute » | `ui/hud.gd:408-409` | fiche de découverte, une fois |
| « Duel %s · 2 manches gagnantes » (HUD de duel, permanent) | `ui/hud.gd:390` | supprimer après la manche 1 |
| « Un cerveau… » / « IA scriptée : celle de l'entraînement, réglée par la difficulté. Cerveau : IA entraînée (apprentissage par renforcement)… » | `ui/lobby.gd:639` | supprimer (jargon ML) |
| « Hors run : les fournitures de ta réserve servent, et l'or est remplacé par des cristaux (1 pour %d or). » | `ui/forge_bench.gd:75`, `ui/merchant_pages.gd:371`, `ui/inventory_page.gd` (`_b_upgrade.tooltip_text`) | une fois, en infobulle |
| Page Aide : « Une run de Survie = une époque de 3 maps… » (4 lignes) ; formules | `ui/info_page.gd:86…178` | déplacer dans « Pour les curieux » du Guide |

### 6.3 Libellés à corriger (bugs de texte)
- « La Tour : ta carte de départ » affiché en **Donjon / Siège / Ruée** — `core/world.gd:244` (titre à générer selon le mode).
- « 9 monstres et 1 élite(s) » — pluriel manuel (`tower_pages.gd`).
- « Rage Battle Axe », « Bone Harvest Axe », « Temple Knights- Rainbow Aurora Gloves » (tiret collé) — noms d'objets (`data/`).
- Icône de cape = gants, icône de gants = chaussette dans le coffre doré (`run_coffre_equipement.png`) : vérifier l'icône par emplacement (`core/items.gd`).
- Carnet : sous-titre « Archive des trésors » sur tous les onglets.
- « Combo d'auto-attaque (clic gauche répété) » : fonctionnalité retirée en 0.1.127.
- « Il te faut un %s (ou de niveau supérieur). » etc. : voir `merchant_pages.gd:464`.

---

## 7. Top 15 des corrections les plus rentables

Critère : (visibilité × fréquence) ÷ coût. Les 8 premières sont des **S** (une heure chacune).

| # | Correction | Pourquoi | Taille | Fichiers |
|---|---|---|---|---|
| 1 | **Les pages d'activité (Siège, Donjon, Duel, Royale, Tour) défilent et le bouton d'action est épinglé en bas** | le joueur ne voit pas « Lancer » sur 3 modes sur 8 | M | `ui/lobby.gd`, `ui/menu_widgets.gd` |
| 2 | **Choix de carte en un geste** (clic = choisi, anti-rafale gardé) | 1 clic de moins × 40 niveaux par run | S | `ui/card_picker.gd` |
| 3 | **Pied de page du lobby + étiquettes F1/F9/Alt-clic masquées** | défaut visible sur **tous** les écrans | S | `ui/lobby.gd`, `ui/ui_theme.gd`, `ui/test_tools.gd`, `core/feedback.gd` |
| 4 | **Supprimer les mentions d'Eden** (niveau d'Eden, « Dans Eden », « Eden Eternal ») | demande explicite du joueur | S | `ui/inventory_page.gd`, `core/items.gd`, `core/archive.gd`, `ui/archive_pages.gd`, `ui/spell_info.gd`, `ui/talents_page.gd`, `ui/hero_pages.gd`, `ui/merchant_pages.gd` |
| 5 | **Pause > Run : n'afficher que les cases occupées** + confirmation de « Quitter le jeu » | 8 lignes identiques ; fausse manœuvre | S | `ui/run_page.gd`, `ui/pause_menu.gd` |
| 6 | **Lignes qui se chevauchent** (Survie, Tour, Panthéon) : hauteur auto de `RowButton` | 3 écrans à la fois | S | `ui/menu_widgets.gd`, `ui/lobby.gd` |
| 7 | **Welcome étape 3 : tient dans la fenêtre** | premier écran vu par un nouveau joueur, coupé | S | `ui/welcome.gd` |
| 8 | **Bilan de Survie sans doublon** (insignes et pièces dits 2 fois, 3 paragraphes) | écran vu à **chaque** run | S | `ui/results_screen.gd` |
| 9 | **Notes d'explication supprimées** (table §6.2, ~60 chaînes) | demande du joueur ; allège 15 écrans | M | tous les `ui/*` listés |
| 10 | **Noms français** (objets mythiques/légendaires proposés, monstres, zones) | contraste anglais/français sur chaque choix | L | `data/names_fr.json`, `core/items.gd`, `core/game_data.gd` |
| 11 | **Carnet : sous-titre par onglet, retirer « Déblocages » et les 3 notes** | écran qui affiche une info fausse | S | `ui/carnet_pages.gd`, `ui/page_screen.gd`, `ui/lobby.gd` |
| 12 | **Paramètres plein écran** (même cadre que Carnet), « Touches » visibles en entier, interrupteurs à glissière | fenêtre à part, 8/24 lignes visibles | M | `ui/settings_menu.gd` |
| 13 | **Un seul composant de bilan** pour les 5 modes | cohérence + animation future | M | `ui/results_*.gd`, `ui/duel_results.gd`, `ui/tower_results.gd`, `ui/dungeon_results.gd`, `ui/royale_results.gd` |
| 14 | **Apparence : « Débloqués uniquement » par défaut + noms** | 121/122 tenues cadenassées au 1er affichage | S | `ui/hero_pages.gd` |
| 15 | **HUD : AUTO seulement sur case remplie, FPS off, Premiers pas hors Duel / Royale / Tour, dégâts cumulés hors Duel** | HUD = écran le plus long à l'écran | S | `ui/hud.gd`, `ui/hud_widgets.gd` |

---

## 8. Lots de polissage sans recouvrement de fichiers `ui/`

> Chaque lot a **son propre ensemble de fichiers** : on peut les traiter dans n'importe quel ordre, l'un après l'autre. Les fichiers `core/*` et `data/*` cités sont rattachés à un seul lot (pas de partage). **Attendre que N1 ait poussé** avant les lots qui touchent `ui/item_widgets.gd` (L6) et `core/profile.gd` / `core/run.gd` / `core/world.gd` (L9).

| Lot | Thème | Fichiers (exclusifs) | Contenu | Taille |
|---|---|---|---|---|
| **L1 — Socle des menus du lobby** | pages d'activité qui défilent, bouton d'action épinglé, lignes à hauteur auto, pied de page, activités, cartes d'époque | `ui/lobby.gd`, `ui/menu_widgets.gd`, `ui/activities.gd`, `ui/tower_pages.gd` | Top 15 n° 1, 3 (partie lobby), 6 ; sections §3 ; suppression des phrases du §6.2 marquées « lobby / activities / tower » ; fiche d'étage stylée | L |
| **L2 — Entrée du jeu** | écran titre, accueil, Guide, tutoriel | `ui/title_screen.gd`, `ui/welcome.gd`, `ui/guide.gd`, `core/tutorial.gd` | n° 7 ; Guide en 6 chapitres ; retrait des touches de test ; « Premiers pas » masqués hors Survie | M |
| **L3 — Choix et récompenses en run** | choix de cartes, coffres d'emplacement, titres de carte | `ui/card_picker.gd`, `ui/chest_stage.gd`, `ui/chests_page.gd`, `ui/wheel_page.gd`, `core/rewards.gd` | n° 2 ; coffres lisibles (§4.10-4.11) ; roulette ; doublons du détail de coffre | M |
| **L4 — Héros** | Équipement, Classe, Apparence, Cartes, Grimoire | `ui/hero_screen.gd`, `ui/hero_pages.gd`, `ui/inventory_page.gd`, `ui/equipment_page.gd`, `ui/talents_page.gd`, `ui/grimoire.gd`, `ui/spell_info.gd`, `ui/class_picker.gd` | n° 4 (partie héros), 14 ; §4.4-4.8 ; sous-onglets de Classe ; fiche masquée sans sélection | L |
| **L5 — Atelier et marchand** | Armurerie, Fabrication, Forge, marchand de run | `ui/gear_shop_page.gd`, `ui/fabrication_page.gd`, `ui/forge_bench.gd`, `ui/merchant_pages.gd`, `ui/merchant_ui.gd` | §4.12 ; état vide de la Fabrication ; Forge en un panneau ; avant → après | M |
| **L6 — Infobulles d'objets** (après N1) | carte d'objet, comparaison, cartes d'infobulle | `ui/item_widgets.gd`, `core/items.gd`, `core/archive.gd` | n° 4 (infobulle) ; stat principale en gros ; « Maj : détails » ; dédoublonnage « Défense » ; retrait « Dans Eden » | M |
| **L7 — Carnet et collection** | Carnet (5 onglets), cadre des pages | `ui/carnet_pages.gd`, `ui/archive_pages.gd`, `ui/page_screen.gd`, `ui/info_page.gd` | n° 11 ; §4.13 ; Aide fusionnée dans le Guide (si L2 passé) ; sous-titre par onglet | M |
| **L8 — Paramètres** | fenêtre plein écran, interrupteurs, touches | `ui/settings_menu.gd`, `ui/ui_theme.gd`, `core/ui_nav.gd`, `core/gamepad.gd` | n° 12 ; barre d'aide manette en marge réservée (T2) ; cadre doré par défaut ; teste `test_nav_screens` | M |
| **L9 — HUD, pause et bilans** | HUD, mini-carte, pause, 5 bilans | `ui/hud.gd`, `ui/hud_widgets.gd`, `ui/minimap.gd`, `ui/test_tools.gd`, `ui/run_page.gd`, `ui/pause_menu.gd`, `ui/results_screen.gd`, `ui/duel_results.gd`, `ui/tower_results.gd`, `ui/dungeon_results.gd`, `ui/royale_results.gd` (+ nouveau `ui/results_panel.gd`), `core/world.gd` (une ligne : titre « carte de départ » ; **après N1**) | n° 5, 8, 13, 15 ; §5.1, 5.3-5.5 | L |
| **L10 — Noms français** | données uniquement | `data/names_fr.json` (nouveau), `core/game_data.gd` | n° 10 ; table de traduction + appliquer dans `display_name` ; aucune modification de `ui/*` | L |

**Ordre conseillé** : L1 → L9 (les deux écrans les plus vus) → L3 → L4 → L5 → L6 (après N1) → L7 → L8 → L2 → L10.
**Dépendances** : L9 et L6 attendent N1 ; L7 gagne à passer après L2 (Guide) ; L1 et L9 sont indépendants entre eux (aucun fichier commun).

---

## 9. Résumé des captures (`conception/nuit_15_10/captures/`)
Lobby : `title`, `lobby`, `jouer`, `jouer_debloque`, `survie`, `entrainement`, `donjon`, `donjon_debloque`, `ruee`, `siege`, `siege_debloque`, `epreuves`, `defi`, `tour`, `tour_etages`, `tour_fiche`, `duel`, `duel_tab_free/league/pantheon/gauntlet`, `duel_league/pantheon/gauntlet`, `duel_prep`, `arenes`, `royale`, `quitter`.
Héros : `heros_equipement`, `heros_classe`, `heros_apparence`, `heros_cartes`, `heros_grimoire`, `heros_aide`. Coffres : `coffres`, `coffres_ouvert`, `roulette`. Atelier : `atelier_armurerie`, `atelier_fabrication`, `atelier_forge`. Carnet : `carnet_0` à `carnet_3`, `carnet_collection`. Paramètres : `parametres0` à `parametres5`. Accueil / Guide : `welcome_1-3`, `guide_commands/steps/cards/news/tips`.
En run : `run_choix_arme`, `run_choix_variante_arme`, `run_coffre_equipement`, `hud_survie_1-3`, `hud_grande_carte`, `hud_boss_1-2`, `hud_duel`, `hud_royale`, `hud_tour_choix_carte`, `hud_donjon_choix_carte`, `hud_siege_choix_carte`, `hud_entrainement`, `pause_run/heros/aide`, `bilan_survie/duel/tour/donjon/royale`, `tip_items`, `tip_spells`.

**Non vérifié** (honnêteté) : navigation réelle à la manette ; rendu à ≠ 1600×900 et à `ui_scale` ≠ 100 % ; infobulles au survol réel (reconstruites avec les mêmes fonctions) ; bilans de Duel / Tour / Donjon / Royale lancés avec des données de démonstration (mise en page fidèle, valeurs fictives) sur fond uni ; les écrans « boss » de Survie (`hud_boss_*`) n'ont pas été relus dans le détail ; l'éditeur du mode dev n'est pas audité.
