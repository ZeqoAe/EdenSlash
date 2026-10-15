# R_U8 — Paramètres plein écran, barre d'aide manette (version 0.1.167)

Lot U8 = L8 de `A2_interface.md` (§2 T2 / T7 / T9 / T10, §4.14, §7 n°12). Captures regardées une à une : `captures/u8/`
(`u8_set0..5` : les six onglets à la souris ; `set_*` : manette, survol, PlayStation).

## Fait
- **Paramètres = `PageScreen`** (`SettingsMenu extends PageScreen`, calque 30) : même cadre que le Carnet, six onglets en haut (Mode de jeu,
  Combat, Touches, Affichage, Son, Caméra & interface), bouton Fermer commun. Même API qu'avant (`open(tab)`, `close()`, `is_open()`, `closed`) :
  lobby, écran titre et pause n'ont pas bougé.
- **Lignes titre à gauche / contrôle à droite**, séparées par un filet ; **interrupteurs à glissière** (`UiTheme.Switch`, un `Button` à bascule :
  navigable à la manette, anime la pastille) à la place des gros « Activé / Désactivé » ; listes, curseurs (la molette ne les règle plus, elle fait
  défiler), boutons segmentés pour le niveau d'aide, cartes pour les 7 modes de jeu (l'or = le choix actif, le reste a un filet gris).
- **Cadre fixe en bas** : au survol d'une ligne (ou quand le cadre manette est dessus) il affiche le détail du réglage ; les 11 notes grises sont
  parties dans ce cadre (les textes dynamiques, comme la visée ou le niveau d'aide, suivent la valeur choisie). Le même cadre porte l'état
  (« Mode X activé », touche assignée) et les boutons de la page : *Touches par défaut* et *Manette par défaut* (Touches), *Tout réinitialiser*
  (toujours, deux clics).
- **Touches en entier** : 4 groupes + Manette, liste qui défile, **colonne de groupes à gauche** (un bouton défile jusqu'au groupe) ; à la croix,
  gauche depuis une touche mène au bouton de son groupe, droite en revient (`meta nav_left / nav_right` sur le contrôle, lus par `UiNav.move` ;
  généralisable à `nav_up / nav_down`). Test de touche, écoute clavier et manette inchangés.
- **Plancher de lisibilité** : `UiTheme.MIN_TEXT = 14`, `UiTheme.text_size()` (tous les textes des Paramètres ≥ 14, titres de ligne 17) ; `MUTED`
  éclairci ; étiquette de version globale passée de 12 à 14 px. Les autres écrans n'ont pas été retouchés (fichiers des autres lots) : à eux d'appeler `text_size`.
- **Barre d'aide manette** (`UiNav`) : trois icônes (A Valider · B Retour · LB/RB Onglets) dans une pastille en bas à gauche, seulement quand la manette est la
  dernière entrée et dans un menu ; « Onglets » n'apparaît que si l'écran en a (`has_tabs()`), icônes Xbox (disques colorés) ou PlayStation (symboles) selon
  `Settings.pad_layout()`. Curseur libre : « A Clic · B Retour · Y Cadre ». L'ancien texte de 150 caractères posé sur le contenu a disparu.
- **Cadre doré** : caché tant qu'aucun mouvement de croix / stick n'a eu lieu (`UiNav.shown`) ; un appui sur A le montre sans rien valider (le premier
  appui ne déclenche jamais un contrôle qu'on ne voit pas) ; il se recache dès que la souris reprend la main, qu'on quitte les menus ou qu'on passe en curseur libre.
- Tests : `test_nav_screens` (6 pages des Paramètres atteignables à 100 %, saut de groupe aller-retour, interrupteur validé par A, cadre caché / révélé,
  barre d'aide, retour à la souris) ; `test_controls` adapté ; `tests/shot_settings.tscn` pour les captures manette / survol.

## Décisions
- Sections par page plutôt que des onglets de plus : Affichage et Son restent courts (6 et 3 lignes), c'est voulu (une idée par page).
- « Rétablir par catégorie » (suggestion A2) non fait : le pied garde *Tout réinitialiser* + remises à zéro des touches / de la manette. Facile à ajouter si le joueur le veut.
- `gamepad.gd` : seulement le commentaire d'en-tête (la logique d'entrée n'avait pas à changer).
- Le mode dev (F10) reste un interrupteur, dans une section « Développement » en bas de Caméra & interface.

## Restes et pièges
- Le premier appui sur A est « mort » (il affiche le cadre) : voulu par la consigne ; si ça gêne dans le choix de carte en run (lot U3), l'écran concerné peut appeler `UiNav.reveal()` à l'ouverture.
- Plancher 14 px : seul `settings_menu.gd` et `ui_theme.gd` ont été passés ; HUD, lobby, bilans à faire par leurs lots (12-13 px nombreux).
- Les lignes se repèrent au pointeur par rectangle (pas par `mouse_entered`) : un contrôle posé par-dessus une ligne reste « survolé » ; sans conséquence ici.
- Deux scènes ou plus ouvrant `SettingsMenu` en même temps ne sont pas prévues (comme avant).
