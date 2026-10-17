# R_UIK0 : socle de la refonte graphique (UIK + TYP + ANI), 17/10/2026

Piste B « autocollant manga » (décision du joueur), `BIBLE.md` v2. Planche : `tests/shot_uik0.tscn` → `user://shots/uik0/`
(papier à gauche, puits d'encre des écrans actuels à droite, 1280×720 et 1600×900). Test : `tests/test_uik0.tscn`.
Captures : `uik0/planche_1600x900.jpg` (à regarder d'abord, à comparer à `pistes/b_kit.jpg`), `uik0/planche_1280x720.jpg`,
`uik0/planche_nuit_1280x720.jpg` (peau technique), `uik0/lobby_jouer_1600x900.jpg`, `uik0/lobby_neuf_1280x720.jpg`, `uik0/parametres_1280x720.jpg`.

## En place
| Brique | Fichiers | Contenu |
|---|---|---|
| Polices | `game/assets/fonts/` (`MochiyPopOne-Regular`, `MPLUSRounded1c-Medium/Bold/ExtraBold/Black` .woff2, licences `OFL-*.txt`), `tools/art/fonts_subset.py` | sous-ensembles latin + signes du jeu (20 à 38 Ko par graisse) ; accents, `Œ œ Ç « » €`, chiffres et `× → ▲ ▼ ★ ✔ ✕ ›` vérifiés ; repli Nunito puis polices du système (⚔, 🔒…). `UiTheme.title_font` (Mochiy), `body_font` (500), `label_font` (700), `bold_font` (800), `number_font` (900). Lignes resserrées (`spacing_top`) : même hauteur que Cinzel / Nunito, aucun débord à 1280×720 (`shot_p1`). |
| `MIN_TEXT` | `ui/ui_theme.gd` | **gardé à 14** : M PLUS Rounded a un œil plus grand que Nunito (hauteur d'x 0,52 em contre 0,495), 14 px y valent ≈ 15 px de Nunito : la proposition de la DA (15) est tenue sans élargir les textes (+4 à 7 % de largeur déjà). |
| Jetons | `game/data/ui_tokens.json` (copie de `tokens.json`) | `UiTheme.tok("forme.rayon.bouton")`, `color("bonbon.lagon.fonce")`, `dur("appui")`, `tones("soleil")` (clair, base, foncé). |
| Boîtes | `UiTheme.StickerBox` | contour d'encre, deux tons cel nets (bords épais qui suivent les coins), reflet blanc incliné, ombre dure réservée dans la hauteur (la face monte de 3 px au survol, se pose sur l'ombre à l'appui : hauteur identique dans tous les états), trame (désactivé), lueur (primaire survolé). Sans shader, StyleBoxFlat natifs : 20 µs par dessin (14 µs pour l'ancien bouton à ombre floue). |
| Shader | `game/shaders/ui_sticker.gdshader`, `UiTheme.StickerPanel` | grand panneau (SDF : contour, deux tons, trame du bas, liseré de relief, lueur animable) dessiné derrière le contenu ; `UiTheme.use_shader = false` → même panneau en StickerBox. |
| Thème | `UiTheme.build_theme`, `scope`, `button_states`, `style_button`, `panel_style`, `well_style` | écrans actuels : textes clairs sur puits d'encre, boutons autocollants « nuit », bascules choisies en lagon (texte blanc contouré), onglets d'écran `PageTab` (actif mandarine), jauges soleil contourées, curseurs lagon à bouton blanc, infobulles et menus déroulants papier. Zones papier des écrans refaits : `UiTheme.scope(conteneur)` (textes encre, boutons papier). Peau `UiTheme.skin` : « sticker » (défaut) ; « night » = option technique (`--ui-skin=night`, réglage caché `interface/ui_skin`). |
| MenuWidgets | `ui/menu_widgets.gd` (API inchangée) | menu de gauche et lignes en papier (texte et icônes à l'encre ; choisi = lagon), primaire soleil (`gold_button`, Mochiy contouré), secondaire nuit (`glass_button`), panneaux = puits d'encre, pastille fraise, logo Mochiy « Eden Slash » contouré avec étincelle. |
| Ressenti | `core/ui_feel.gd` (autoload `UiFeel`) | tous les BaseButton sans branchement (contrôle survolé relu à chaque image, appui / relâchement lus dans `_input`) : survol 1,04 en ressort, appui écrasé (quad 60 ms), rebond (220 ms), refus (secousse ±4 px + « bonk »), interrupteur aplati + 2 étoiles, primaire = anneau + 4 étincelles, onglet, carte, case ; sons d'interface (`Sfx.ui`, noms `ui_*` provisoires) ; vibration courte (menus seulement) ; seules `scale` / `rotation` bougent (zone cliquable au repos, navigation manette inchangées) ; tourne en pause. Outils : `pop_in` / `pop_out`, `slide_in`, `count`, `sparkle` / `ring` / `confetti` (CPU, coupés au-delà de 40 boutons visibles). |
| Manette | `core/ui_nav.gd` | cadre de focus = liseré blanc 6 px + anneau lagon foncé 3 px, coins ronds, qui glisse (120 ms) et respire ; le contrôle visé prend l'état « survolé » (UiFeel.nav_focus). |
| PageScreen | `ui/page_screen.gd` | onglets `PageTab`, contenu qui glisse de 24 px au changement d'onglet, fondu à l'ouverture. |
| Paramètres | Caméra & interface > Menus | « Réduire les animations », « Vibration manette » (interrupteurs), « Intensité des effets d'interface » (curseur 0 à 150 %). |

Mesures : UiFeel coûte 80 µs pour un écran de 300 nœuds ; `perf_ui` (boot, lobby, pages) : voir le commit (écarts dans le bruit
de la machine partagée, mesures alternées avant / après).

## Ajouter un composant
1. Couleurs, rayons, durées : `UiTheme.color(...)`, `UiTheme.tok(...)`, `UiTheme.dur(...)` ; jamais de couleur en dur.
2. Fond : `UiTheme.sticker(ton, {shadow, radius, gloss, trame, glow, pad…})` ; bouton : `UiTheme.style_button(b, "papier" | "nuit" | "soleil" | "lagon" | "fraise", taille)` ; tous les états : `UiTheme.button_states(ton)`.
3. Panneau papier : `UiTheme.StickerPanel.new("papier")` puis `UiTheme.scope(panneau, false)` : ses enfants prennent textes et boutons du papier.
4. Ressenti : rien à faire pour un BaseButton ; genre par meta `ui_feel` (`primary`, `tab`, `slot`, `card`, `toggle`, `off`) ; panneau cliquable : `UiFeel.attach(c, genre)`.
5. L'ajouter à la planche `shot_uik0` et, s'il a un état, à `test_uik0`.

## Reste
- Les écrans eux-mêmes passent au papier chantier par chantier (`R_DA.md` 1 à 10) : `UiTheme.scope` + `StickerPanel`.
- Sons d'interface provisoires (sons du jeu, hauteur réglée) : département SND (`Sfx.UI` noms `ui_*`).
- Rayons de soleil derrière le primaire survolé, onomatopées du HUD, signatures de rareté, infobulle à queue de bulle, choix de carte animé
  (CardPicker) et confettis des bilans (`UiFeel.confetti` prêt, non branché) : chantiers 5 à 7.
- Cases d'objet (`ItemSlot`) : genre `slot` à poser (meta `ui_feel`) avec leur refonte.
