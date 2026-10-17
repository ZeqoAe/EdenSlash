# R_UIK1 : les écrans passent au papier autocollant (17/10/2026)

Suite du socle (`R_UIK0.md`), piste B « autocollant manga » (`BIBLE.md`). Principe appliqué : **clair dehors, encre dedans**
(bible § 2) : la feuille, les en-têtes, les menus et les fenêtres sont du papier crème contouré d'encre ; les listes, grilles,
tuiles et pages denses restent des puits d'encre. Aucune logique de jeu touchée.

## L'outil : `UiTheme.paper(panneau)`
Une ligne remplace la boîte d'un panneau existant : papier autocollant (ombre dure, contour d'encre), thème papier (boutons
papier, onglets mandarine) et **adaptation des textes déjà écrits pour un fond d'encre** : un texte clair posé sur le papier
passe à l'encre (couleurs gardées mais foncées : or → or brun, vert → gain, rouge → perte ; contour retiré), un texte posé
dans un puits d'encre ou sur un bouton sombre reste clair, une pastille bonbon garde son blanc contouré. Les contrôles ajoutés
plus tard (pages reconstruites) sont adaptés aussi (UiFeel les voit passer) ; une couleur changée par l'écran est réadaptée à
son prochain dessin. `meta ink_keep` : un titre autocollant (soleil contouré) garde sa couleur. `UiTheme.on_paper(couleur)`.
Coût : nul hors des zones papier ; un contrôle adapté une fois par changement de couleur.

## Chantiers faits
| Chantier | Écran | Ce qui change |
|---|---|---|
| 1 | Menu principal (`lobby.gd`) | sous-menu (Jouer et pages d'activité), carte du héros, zone, pied de page en papier ; voile sombre allégé ; « Continuer » en action douce lagon (`SideButton.accent`) |
| 1 | Cartes d'activité (`activities.gd`) | contour d'encre 3 px, coins 16, survol liseré soleil + lueur, ressenti « carte » (monte et penche) ; bandeau des pages idem (entré avec HUB-1, 0.1.269) |
| 1 | Écran titre | boutons secondaires papier (`MenuWidgets.paper_button`), fenêtre Jouer en papier (les fonds ILL-2 ne sont pas touchés) |
| 1 | HUB-1 | Aujourd'hui (`today_panel.gd`) et bulle « Ta quête » (`compass_bubble.gd`) en papier, boutons papier ; lignes du Journal (`QuestsPage._box`) en puits d'encre contourés ; pastilles `NewsDot` aux couleurs des jetons, contour et ombre dure |
| 2 | `PageScreen` (Carnet, Atelier, Coffres, Paramètres, Guide, Journal, pause…) | fond clair (papier → ciel), feuille papier autocollant, en-tête sur le papier (titre soleil contouré, onglets papier, l'actif mandarine, Fermer papier), pages dans un puits d'encre ; en-tête qui ne déborde jamais (onglets en M PLUS puis plus serrés si Mochiy ne tient pas) |
| 2 | Héros (`hero_screen.gd`) | même feuille ; Retour, Personnage en papier, Aide en lagon, menu de côté en autocollants papier (section ouverte lagon) |
| 2 | Paramètres | **bug corrigé** : la colonne sortait de l'écran à droite (1280 et 1600) : largeur `min(1180, écran − 140)`, suivie si la fenêtre change ; en-tête qui tient |
| 3 | Bilans (`ResultsPanel`, donc tous les bilans) | feuille papier, « Victoire ! » contouré, tuiles et colonnes en puits d'encre, bouton secondaire papier, **confettis** à la victoire |
| 3 | `InfoCard` (petites cartes, confirmations) | cartes et fenêtres papier ; petits boutons autocollants (primaire soleil, danger fraise, discret papier) |
| 4 | Restes du socle | **rayons de soleil** qui tournent derrière le bouton primaire survolé (`StickerBox.rays`) ; genre **« slot »** des cases d'objet (`ItemWidgets.ItemSlot`) ; **raretés** aux couleurs des icônes (lilas-gris, pomme, lagon, améthyste, mandarine, soleil : `Items.RARITIES`) |
| 3 | Carte d'objet (`ItemWidgets.item_card`, lot GX-3) | carte papier, texte à l'encre, couleurs du BBCode d'`Items.describe` foncées par `UiTheme.paper_bbcode` (rareté, gains, pertes) |
| 2 | Carnet > Registre | une page plus haute que sa place ne déborde plus sur la feuille (`PageScreen._content` coupe) |
| API | Pastilles d'onglet | `PageScreen.set_tab_badge(i, groupes, action)` et `HeroScreen.set_tab_badge(section, groupes)` / `section_button` remplacent la lecture de `_tab_buttons` / `_nav` (lobby, Journal) |

Captures (1280×720 et 1600×900, regardées) : `conception/art/uik1/`.

## Non touchés (autres équipes, déjà en v2 ou en cours)
Survivant, L'Échiquier, Battle royale, Fabriquer / Forge, barre de boss et page Donjons (DNG-2), inventaire et fiche d'objet
(GX-3) : leurs panneaux intérieurs gardent leur style ; la feuille papier autour d'eux vient de `PageScreen` / `HeroScreen`.
Les fonds titre / menu / bilans (ILL-2) restent à leur équipe.

## Pour HUB-1
- `hud_scale` / `hud_opacity` : vérifier qu'ils sont bien **commités** dans `Settings.DEFAULTS` (`settings.gd`) ; en attendant, un curseur
  dont le réglage manque prend 100 % au lieu d'une erreur.
- Pastilles d'onglet : passer par `set_tab_badge` (fait dans `lobby._tab_dots` et le Journal).

## Reste
- Pages intérieures des écrans (Carnet, Atelier, Héros) : leurs tuiles gardent l'ancien liseré or (passer à `UiTheme.well_style`
  page par page, avec leurs équipes).
- Cartes et passifs (`Cards.TIERS`, `Boons.RARITY`) : leurs couleurs d'Épique / Mythique suivent l'ancien code (à aligner sur les raretés).
- Pause en partie : la feuille papier couvre le jeu ; un fond flou de la scène (bible) serait plus doux.
