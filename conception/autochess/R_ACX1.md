# R_ACX1 : L'Échiquier, interface v2 (P0 n° 1 à 4 de l'étude BM-AUTO), 17/10/2026

Lot : `conception/benchmark/AUTOCHESS.md` §6, P0 n° 1 (habillage DA v2, plateau ≥ 70 %), 2 (traits toujours visibles), 3 (boutique v2),
4 (aides d'économie). DA : `conception/art/BIBLE.md` v2 + `tokens.json`, maquette `benchmark/autochess_maquettes/preparation.html`.
Aucune règle de jeu ni réglage mesuré touché (`tests/ac_mesures.json` intact) : seulement l'affichage.

## Ce qui est fait
- **Style centralisé, branché sur UiTheme v2** (`ui/autochess_hud.gd`, tête du fichier) : une seule source pour tout le mode.
  Polices `pop_font` / `round_font(500..900)` = `UiTheme.title_font` … `number_font` (Mochiy Pop One, M PLUS Rounded 1c) ; boutons
  `button()` / `style_button()` = `UiTheme.style_button` (papier, soleil primaire, lagon, fraise ; verrou allumé en soleil, ressenti
  « toggle ») ; grands panneaux `paper_panel()` = `UiTheme.sticker("papier")` (toujours papier : les textes du mode sont à l'encre) ;
  petites pièces (tuiles de trait, pastilles, lignes, jauges) en `sticker()` / `gauge()` (StyleBoxFlat contouré d'encre, ombre dure) ;
  palette `INK`, `PAPER`, `candy(nom, ton)`, `cost_candy`, `trait_candy` (valeurs de `tokens.json`) ; `ink_lbl` / `pop_lbl` /
  `panel_title` (titre collé incliné −3°), pastilles de touche (A pomme, B fraise, X lagon, Y soleil ; clavier en papier), `draw_star`.
  UiFeel : lignes des traits et des stratèges `row`, cartes de boutique et du choix partagé `card`. Échelle `AutochessHud.k` = largeur
  / 1600 (0,8 à 1280 × 720), texte ≥ 13 px. `lbl()` / `box()` / `button()` gardent leur signature pour les panneaux des autres lots.
- **Cadre** : frise en pastilles contourées (manche en cours en soleil, gardien en fraise, étoile d'atout), minuteur Mochiy + jauge (fraise
  sous 5 s) ; colonnes de 212 px (au lieu de 236), pied de 140 px ; « Retour » → « Menu principal » (mot de la BIBLE).
- **Traits toujours visibles** (`ui/autochess_traits.gd`) : la fiche n'occupe plus la colonne. Pastille hexagonale à la couleur de la famille
  (armes en lagon clair), plots des seuils, actifs sur papier puis inactifs grisés sous un filet. Survol (souris) ou cadre de la manette
  sur une ligne → `trait_hovered` : unités du trait entourées d'un anneau lagon au plateau et au banc (`AutochessBoard.mark_units`, nouveau)
  et cartes de boutique du trait entourées de lagon (`AutochessShop.mark_trait`). Les lignes ne sont jamais refaites au survol (le cadre de
  la manette reste posé).
- **Fiche d'unité en bulle** (`ui/autochess_unit_card.gd`, `place_near`) : bulle papier avec queue, posée à droite / gauche / au-dessus de la
  cible (case, carte de boutique — au-dessus de l'onglet de l'or —, objet) sans chevaucher les panneaux ni la cible ; même chose à la manette.
- **Boutique v2** (`ui/autochess_shop.gd`) : carte papier, bandeau du coût (lilas, pomme, lagon, améthyste, soleil), icône sur sa tuile, nom,
  2 tuiles de trait colorées, flèche pomme sur la tuile d'un trait qui passerait un seuil (héros pas encore sur le plateau), pastille de
  coût soleil, copies possédées (losanges) ; achat qui fusionne : halo soleil, étoile autocollant dans le coin, mini ★★ ou ★★★ (les ★★ qui
  fusionnent aussi). `AutochessShop.info[i]` = `{star_up, stars, rising, afford}` (tests). Survol d'une carte → copies déjà possédées
  marquées au plateau et « 2 → 3 » dans la colonne (lignes fantômes « 0 → 1 » pour les traits nouveaux).
- **Aides d'économie** (`AutochessHud`) : barre des taux de la boutique (`OddsBar`, 5 couleurs de coût, pourcentages seulement dans
  l'infobulle), flamme de série (`Flame` : mandarine en victoires, lagon en défaites, à partir de 2 ; or gagné en infobulle), revenu de la
  prochaine manche en pastille « +9 » sur l'onglet de l'or (`Autochess.income_for` de la manche suivante, détail base / intérêts / série en
  infobulle), intérêts en pastilles pomme.
- **Plateau plus grand** (`AutochessScreen._fit_board`) : la caméra de préparation garde l'angle de `frame_camera` mais avance et glisse
  pour que les 8 rangées, le banc et le banc d'objets tiennent au plus grand hors des panneaux (calculés : `_frame_guess`).
- Choix partagé (`ui/autochess_carousel.gd`) : voile d'encre, cartes et ordre en autocollants papier, composant sur tuile d'encre.
- Outil de capture `tests/shot_ac.gd` : la passe 1600 × 900 restait à 1-1 car le bilan de fin de la 1re passe laissait l'arbre en pause
  (`ResultsPanel`) ; corrigé (bilan fermé, pause levée).

## Mesures (test `test_acx1`, 34 vérifications)
| | 1600 × 900 | 1280 × 720 |
|---|---|---|
| cadre au repos (préparation) | 23 % de l'écran (cible ≤ 30 %) | 25 % |
| plateau + banc + objets (cadre projeté) | 60 % × 65 % de l'écran, hors des panneaux | 58 % × 64 % |
| contrôles hors de l'écran | 0 | 0 |
Image médiane du vrai combat (`shot_ac`, arène) : 6,1 à 6,2 ms (avant : 6,3 à 6,9 ms), p95 ≈ 12-16 ms : pas de régression.

## Décisions
- Bulle plutôt que panneau droit en manette (proposé par l'étude) : les stratèges restent atteignables à la croix, et la bulle suit le cadre.
- Tuiles de trait : famille = aplat de sa couleur, armes = lagon clair (BIBLE §7.1) ; texte d'encre (lisible sur les 6 aplats).
- Flèche « trait qui monte » seulement quand le +1 atteint un seuil (sinon la colonne montre « 2 → 3 » au survol, sans marque permanente).
- Revenu projeté = `income_for` de la manche suivante avec l'or et la série actuels (une victoire JcJ ajoute +1, dit en infobulle).

## Reste / pièges
- Le compteur de dégâts, les barres d'équipe, le bilan et les atouts (fichiers d'ACX-2) prennent déjà les boutons et polices v2 par
  `AutochessHud.button()` / `lbl()`, mais gardent leurs fonds nuit : à passer au papier avec leur lot.
- P0 suivants (curseur, annulation, combat lisible, bilan non bloquant, moments manga, atout v2) : lot ACX-2.
- `test_ac_ui` (retouche) : la fiche ne remplace plus les traits ; le passage « bouton Prêt → combat » se joue aux durées réelles
  (sous charge, les durées réduites enchaînaient combat, bilan et préparation entre deux vérifications : faux échec 2 fois sur 6).
- Captures : `tests/shot_ac.tscn` (APPDATA détourné), 0 débord aux deux résolutions.
