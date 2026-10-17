# R_UIK2 : finitions de la peau papier autocollant (17/10/2026)

Suite de `R_UIK0.md` (socle) et `R_UIK1.md` (écrans au papier), cahier des charges = la liste « Reste » d'UIK1 et la bible
(`BIBLE.md` § 2-8). **Aucune logique de jeu touchée** : couleurs, boîtes, mouvements et composants d'affichage seulement.
Captures regardées (1280×720 et 1600×900, comptes neuf et avancé) : `conception/art/uik2/`. Test : `tests/test_uik2.tscn`
(36 contrôles) ; captures : `tests/shot_uik2.tscn` (`UIK2_WHAT=jeu|lobby`, `UIK2_RES=1280x720`).

## 1. Tuiles intérieures des pages : un seul levier, `UiTheme.flat_box`
Les pages intérieures (Carnet, Atelier, Héros, Collection, Coffres, Guide, Paramètres, pause, HUD…) dessinent leurs tuiles,
fiches, rangées et fenêtres avec `UiTheme.flat_box` (165 appels, 40 fichiers). Plutôt que de réécrire 165 appels, la
fonction **traduit les couleurs d'avant dans la DA** (`da_fill`, `da_border`) :

| Avant | Après (bible) |
|---|---|
| fond presque noir (`Color(0.06, 0.05, 0.12)`…) | encre `#342A5C` → `#4C3F7D` selon la clarté d'avant (repos / survol gardés), plus clair que le puits d'encre 500 où la tuile est posée |
| liseré or terni, gris ou lilas | contour d'encre 2-3 px (900 sur fond sombre, 700 sur clair) |
| fond brun doré « choisi » + or vif | **lagon** (clair sous un texte foncé, foncé sous un texte clair), contour d'encre : la sélection de la bible |
| fenêtre à liseré or (rayon ≥ 12, ombre) | contour d'encre + ombre dure |
| ombre floue noire | ombre dure d'encre décalée (4 px) ; une tuile pleine sans ombre prend un relief de 3 px |
| coins 6-9 px | 10-13 px ; 10 et plus → 14 (puits, cases) |
| couleurs vives (rareté, accent, jauges, pastilles) | **gardées** |

`UiTheme.GOLD_DIM` (« or terni », 76 usages : filets, ◇, liserés) devient le **lilas d'encre 100** : plus aucun filet doré.
`UiTheme.legacy_boxes = true` rend les boîtes d'avant (essais, mesure de `test_uik0`).

Composants ajoutés pour les pages (`UiTheme`) :
- `section_header(parent, texte, compteur)` : titre de section en Mochiy soleil contouré, compteur à droite (Carnet, Registre) ;
  Paramètres : en-têtes de section Mochiy, filet lilas, survol des lignes en lagon (`_row_box`).
- `empty_state(parent, phrase, icône, action, cb)` : icône du jeu dans une tuile bonbon collée (−4°), une phrase, une action
  (bible § 6) : Coffres vides, Carnet (Succès, Trophées, Registre via `ScrollPage.empty`), grilles d'objets vides
  (`ItemWidgets.ItemGrid` : Collection, coffre commun), Atelier > Plans de donjon (même tuile).
- `Loading` : trois pastilles bonbon qui sautent l'une après l'autre + phrase (file du duel ; immobiles avec « Réduire les animations »).
- Case d'objet (`ItemWidgets.ItemSlot`) : contour d'encre, bord de rareté 3 px, fond d'encre 500 (plus de fond noir), coins
  ronds ; choisie = bord et lueur **lagon** (au lieu de l'or) ; vide = bord d'encre clair.
- Bouton d'action mis en avant (`ItemWidgets.action_button(…, accent)`) : autocollant lagon (action douce) au lieu de l'or brun.
- Petit primaire (`MenuWidgets.gold_button` de moins de 44 px, « Y aller ») : ombre de 3 px, Mochiy contouré ne touche plus le bord.
- Reflet blanc des boutons (`StickerBox`) seulement à partir de 36 px de haut : il mordait le texte des pastilles basses
  (« Tous / En cours », listes de la Collection et de l'Atelier).
- Aperçu 3D du héros (`EquipmentPage.Preview`) : fond d'encre 500 au lieu d'un rectangle presque noir.

Choix assumé : les boutons **dans** les puits d'encre restent des autocollants « nuit » (contour d'encre, deux tons, ombre
dure) : leurs textes clairs sont écrits pour l'encre ; un passage au papier demanderait d'adapter le texte de chaque bouton
(et des rangées-boutons qui portent des étiquettes) un par un. Les boutons des zones papier sont papier (UIK1).

## 2. Raretés : un seul code partout
Code de la bible (§ 3) : commun lilas-gris, spécial pomme, rare **lagon**, épique améthyste, mythique mandarine, légendaire **soleil**.
- `Cards.TIERS` et `Boons.RARITY` (cartes de niveau, passifs, Héros > Cartes, Carnet > Cartes, entraînement, marchand, page
  Partie) : mêmes couleurs que `Items.RARITIES` (le légendaire était orange, le rare bleu ciel).
- `CardPicker.TYPE_COLORS` : nouveau sort pomme, enchaînement pomme clair, amélioration / passif lilas-gris.
- `Rewards.TYPES` (coffres) : équipement et apparence mythique mandarine, set et légendaires soleil, rare lagon, forge commun, joaillier pomme.
- Mini-carte (`Minimap.ICONS`, monstres, chemin, cadre) : bonbons de la bible (coffre doré soleil, ouvragé fraise comme dans
  le monde, élite mandarine, boss améthyste, monstres fraise), cadre carré d'encre 3 px.

## 3. Fond flou de la scène (bible § 2)
`UiTheme.blur_material(voile, lod)` (shader `hint_screen_texture` à mip, voile `monde.voile-modale`) et `UiTheme.veil(rect, force)` :
- **pause et tout écran à pages ouvert en partie** (Guide, Journal, marchand) : la scène floutée derrière la feuille au lieu
  du dégradé clair ; sur un grand écran (≥ 1500 px) la feuille est en retrait (34 / 22 px) pour que le jeu se voie autour ;
  à 1280×720 les marges restent de 10 px (les pages tiennent) ; au menu principal, le fond clair d'UIK1 ;
- **choix de carte de la Survie** (`CardPicker`) : jeu flouté au lieu du voile noir à 72 % ; cartes d'encre bordées de
  leur rareté (4 px), ombre dure, pastille de touche contourée, « Relancer » en action douce lagon ;
- **confirmations** (`InfoCard.ask`), choix de classe, autel de la fortune, préparation du duel, accueil : écran derrière
  flouté sous un voile d'encre (≤ 0,7) au lieu d'un rectangle presque noir. Un clic à côté ferme toujours.

## 4. Mouvements (UiFeel), « Réduire les animations » respecté
- `UiFeel.screen_in(racine, feuilles)` : ouverture commune des écrans plein cadre — fondu 120 ms et feuille qui se pose en
  ressort (0,985 → 1, durée « apparition ») ; `PageScreen` et **Héros** (qui n'avait ni animation ni son d'ouverture /
  fermeture : souffle et pincé de SND-1 ajoutés).
- **Bug corrigé** : `UiFeel.slide_in` (contenu d'onglet qui glisse) déplaçait la *position* d'une page ancrée ; une page
  jamais posée (Paramètres ouverts directement sur « Caméra & interface », Carnet ouvert sur « Succès ») gardait une
  position périmée et restait **décalée de la moitié de l'écran**, contrôles hors écran. La glissade passe par les marges
  d'ancrage, et un changement d'onglet rapide repart des marges d'origine.
- `UiFeel.number(label, valeur, format)` : un montant qui change pendant que le label est visible défile jusqu'à sa nouvelle
  valeur (500 ms) au lieu de sauter — bourse des écrans à pages (or, clés, cristaux) et bourse de l'Atelier (insignes,
  cristaux, après un achat ou une fabrication) ; instantané sans écran (tests) et avec « Réduire les animations ».
- Rangées (`ui_feel = "row"`) : elles s'éclairent au survol (modulate, rien ne bouge) ; la couleur reste avec les animations réduites.
- Choix de carte : la carte choisie grossit en ressort (1,12) puis s'efface en montant, par-dessus le choix suivant
  (purement visuel, coupé par « Réduire les animations » et sans écran).

## 5. Passe de cohérence (captures regardées)
Corrigé en plus : Carnet > Succès qui débordait à droite à 1280 px (glissade + titres longs : nom et « titre « … » »
abrégés avec infobulle), Paramètres décalés (glissade), reflets sur les pastilles basses, onglet choisi brun à texte foncé
illisible (Héros > Classe > Sorts : lagon). Vérifiés sans régression : menu principal (HUB-1), Journal, Héros (GX-3 :
poupée, sac, fiche d'objet), Atelier, Collection, Coffres, Guide, pause, HUD de la Survie, planche `shot_uik0`.

## Reste (autres équipes ou plus tard)
- HUD de la Survie (chantier 6 de `R_DA.md`) : anneaux dorés de la vie, de la mini-carte et des cases de sorts (`hud_widgets.gd`).
- Bilans (`ResultsPanel`, DNG-2 / SND-2) : nombres qui défilent (`UiFeel.number` est prêt).
- Boutons dans les puits d'encre : nuit (voir § 1) ; s'ils doivent passer au papier, le faire écran par écran avec `UiTheme.paper`.
- Écrans de développement (`profile_editor`, `dev_*`) : non repris.

## Tests (copie propre de HEAD + UIK2, `run_tests.py -j 2`)
Verts : test_uik0, test_uik2, test_nav_screens, test_pages, test_results, test_texts_fr, test_hud, test_p8, test_cards,
test_gx3, test_hub1, test_p2, test_dng2, test_a4, test_bri3. Rouge **déjà sur HEAD 0.1.281 sans UIK2** (vérifié sur une
copie à part) : test_svx2 « 1280x720 bilan : tient dans la fenêtre » (bilan du Survivant haut de 728 px), à reprendre par
l'équipe des bilans (ResultsPanel, DNG-2 / SND-2). `check_scripts` : aucune erreur dans les fichiers UIK2.
