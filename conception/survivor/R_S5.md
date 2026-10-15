# R_S5 — Survivant, interface en run (15/10/2026)

Lu : `DECISIONS_JOUEUR.md` (prime), `SPEC.md` §10, `R_S1.md` à `R_S4.md`, `PLAN_NUIT.md`, `A2_interface.md`, `R_U9.md`, `R_P3.md`,
`R_P8.md`, `R_U6.md`, `R_P13.md`, `CLAUDE.md`.
Nouveaux fichiers : `ui/survivor_cards_view.gd` (rendu des cartes), `ui/survivor_build_page.gd` (page Build), `ui/survivor_hud.gd`
(frise du HUD), `tests/test_sv5`, `tests/shot_sv5`. Retouches ciblées : `card_picker.gd` (délégation, Bannir / Garder épinglés,
fiche, LB / RB), `pause_menu.gd` (page Build, pas d'inventaire), `run_page.gd` (sans colonne trophées / passifs ni arme
secondaire en Survivant, sorts x / 6), `hud.gd` (frise, ligne des gardiens retirée de l'en-tête, niveau des sorts),
`hud_widgets.gd` (`SkillSlot.level_badge`), `lobby.gd` (`_survivor_overview`, ligne Classe), `tutorial.gd` (3 fiches, champ
`news`), `cards.gd` (`_num` : virgule décimale), `test_nav_screens`.

## Fait
- **Cartes** (`SurvivorCardView`, une famille = une mise en page) : en-tête court (« Torse · Légendaire », « Tête · épique »,
  « Sort · rare ») ; **pièce / arme** : icône encadrée à la couleur de la rareté, nom, statistique principale en gros, 4
  statistiques secondaires en deux colonnes, barre du jet 100 → 120 (dorée et « ★ Jet parfait » à 120), set « ◆ nom ●◉○○○ 2 / 5 »
  et le prochain bonus (vert s'il s'active avec cette pièce), passif fixe encadré (icône, nom, effet), « 🔒 Gardée à vie ·
  Passifs à +6 +8 +10 » ; arme : variante d'auto-attaque et son effet ★ à +4. **Amélioration** : « +4 → +6 » en gros, jauge de 10
  segments (acquis en or, gain qui pulse en vert, losanges et « +6 +8 +10 »), passif du palier tiré encadré d'or, deux
  statistiques avant → après ▲, jet relevé, prochain palier, auto-attaque de l'arme, « Acquis : … ». **Sort** : nouveau (niveau
  1 / 10, case ou enchaînement) ; amélioration « Niv. 4 → 5 », jauge (losanges aux niveaux 5 et 10), « Ce niveau » puis « Total
  au niveau 5 ». **Comparaison** ▲ / ▼ avec la pièce portée (avant → après). Bannir / Garder épinglés en bas de chaque carte ;
  Relancer (compteur) et Passer sous la rangée.
- **Manette** : cadre sur la 1re carte (P13), croix, A, **LB relance, RB passe** (écrit sur les boutons quand la manette est
  active), Bannir / Garder atteignables à la croix ; le jeu reste en pause (P13 inchangé).
- **Fiches à la 1re rencontre** (`Tutorial.CARDS` `sv_first`, `sv_locked`, `sv_tier`, chapitres Cartes / Équipement du Guide) :
  montrées **dans le choix lui-même**, sous le titre, au style des cartes P8 (icône, titre, une phrase), une seule fois. Décision :
  une `InfoCard` du HUD attend la fin du choix (P8) et arrive trop tard ; la place à droite manque à 1280. `news: false` : elles ne
  s'annoncent pas au lobby tant que le mode est en mode dev.
- **Pause > Build** (page d'abord, plus d'inventaire) : arme en grand (+N, jauge, auto-attaque), 8 cases (icône, rareté, +N,
  cadenas, losanges des paliers, ★ jet parfait, « Libre »), survol = carte de la pièce, clic = « 🔒 Gardée toute la run : elle ne
  se retire pas. » ; héros (PV, attaque, défense, critique, vitesse d'attaque, recharge) ; sorts x / 6 (niveau x / 10, jauge, effet
  cumulé) ; passifs actifs (valeur cumulée, ×2 sources, « max » au plafond), évolutions possibles ; sets (x / 5, paliers 2 / 3 / 5) ;
  Reprendre. Chaque colonne défile (1280 × 720).
- **HUD** : sous l'en-tête des objectifs, frise des 20 minutes (temps écoulé, gardiens à 5 / 10 / 15 : gris, rouge à l'annonce et
  debout, or vaincus ; portail violet à 15:00, boss au bout), puis dans l'arène la jauge de rage du boss à encoches (« Rage », ×2,
  ×11, ×101) ; « Équipement 7 / 9 · Sorts 5 / 6 » ; niveau de chaque sort en chiffre sur sa case (doré à 10). Le chronomètre (temps
  avant le boss), la Menace (P12), le bandeau des gardiens / du portail (S4) et les potions restent.
- **Lobby** : trois idées en pastilles (Pièces à vie · Passifs +6 +8 +10 · Boss à 20:00), ligne Classe (« Changer de classe »),
  puis les coffres (S6) et la zone.
- Textes : virgule décimale partout (`Cards._num`, et `SurvivorCardView.fr` pour les textes d'armes), aucune mention d'Eden.

## Mesures et tests
- `test_sv5` : 200 états de run (5 classes, 0 à 60 cartes prises, offres de niveau, de coffres, premier choix) = 600 cartes
  rendues, toutes les familles (pièce, arme, améliorations, sorts, évolution) ; aucune vide, **aucune ne déborde à 1280 × 720**
  (52 débordaient avant la passe de compactage), ni « Eden » ni point décimal ; fiches (une fois) ; manette (cadre, croix, LB,
  RB) ; page Build (clic sans retrait, `Profile.unequip` refusé, infobulle) ; en jeu (frise, niveau 4 sur la case, gardien
  annoncé, pause Build d'abord). Rejoués : voir STATUT.
- Captures regardées (`tests/shot_sv5.tscn -- tout`, `SV5_RES=1280x720`) : premier choix, pièce + fiche, amélioration à passif,
  coffre, jet parfait, page Build, HUD début / milieu / fin / annonce du gardien / boss, lobby, en 1600 × 900 et 1280 × 720.

## Restes, pièges
- Critique affichée à 109 % sur l'état riche de test (statistique du héros, pas de l'interface) : à regarder en S7.
- Les fiches ne s'ouvrent pas au Guide comme nouveauté ; S6 / S8 écriront la fiche « Survivant » de découverte du mode.
- `CardPicker.card_cap()` : en Survivant la hauteur des cartes suit la fenêtre (430 à 600) ; un nouveau contenu de carte doit
  repasser `test_sv5` (débordement mesuré).
- Écrire un fichier de `ui/` depuis Python échoue (`Errno 22`) quand d'autres Godot tournent : passer par un fichier temporaire.
