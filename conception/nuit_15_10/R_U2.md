# R_U2 — Entrée du jeu : écran titre, accueil, Guide, tutoriel (lot L2 de A2)

Fichiers : `ui/title_screen.gd`, `ui/welcome.gd` (réécrit), `ui/guide.gd` (réécrit), `core/tutorial.gd`, tests `test_lot9`, `test_nav_screens`, outil `tests/shot_u2.tscn`.
Retouches hors lot (minimales) : `ui/info_page.gd` (intro de « Monnaies et coffres » raccourcie, puce « forge indisponible » retirée car fausse, « Armurerie (Atelier) », « cartes » au lieu de « maps », « data/classes.json » retiré), `CLAUDE.md` (6 lignes).
Captures regardées une à une : titre, Jouer, Nouvelle partie, accueil 1-2-3, Guide (6 onglets + fiche ciblée) à 1600×900, 1280×720 et 1024×576.

## Fait
- **Écran titre** : zone survolée (« Monts Calcaires, zone 1 ») supprimée ; fenêtre Jouer sans phrases superflues, fiches de sauvegarde « Guerrier · 3 runs · 1 victoire · niveau max 12 » + date en français (plus de « archive x / 1731 », « zones débloquées », « héritage »).
- **Accueil** : 3 écrans (comment commencer / classe / contrôles + aide), panneau qui s'adapte à la fenêtre (marge, défilement, bouton d'action et Retour épinglés, points de progression, colonnes côte à côte ou empilées). Le bug de l'écran 3 coupé venait de boutons dont la largeur minimale suivait le texte. Classe : portrait, rôle, phrase, **les 3 sorts de départ** ; « Les autres classes se débloquent en jouant. » ; manette détectée = « Manette » présélectionnée ; Échap / B = Retour. Textes de règles internes (« mémoire des touches… ») remplacés par une phrase par niveau d'aide. Testé 1600×900 à 800×600 (panneau toujours dans la fenêtre).
- **Guide F1** = `PageScreen` (même cadre que Carnet/Paramètres, plus d'`ItemList` native, plus de fond qui laisse voir le lobby) : **6 onglets** Commandes · Cartes · Survie · Équipement · Modes · Détails. Commandes : touches réelles du joueur (4 groupes, manette comprise), Premiers pas (avec « Passer »), aide au combat, interrupteur des fiches. Survie / Équipement / Modes : texte à jour avec la boucle réelle (équipement du hub en Survie, insignes = Armurerie, cristaux = Forge, plans = Fabrication, rôle unique de chaque activité d'après A1 §5.3 et R_E1, conditions de déblocage en gris). **Détails = l'ancienne page « ? » (`InfoPage`)**. Les fiches de découverte sont rangées par chapitre (champ `chapter`) ; ouvrir le Guide sur une fiche (bouton « Plus de détails » du HUD, `select("anvil")`) descend jusqu'au bloc, entouré d'or. Anciens identifiants (`commands`, `steps`, `tips`, `news`) conservés.
- **Touches de test retirées** du Guide (F2, F9, F4 « infos de débogage », « Tests et retours ») : elles n'apparaissent qu'en mode dev. F4 « Se débloquer » reste (utile au joueur). Alt + clic droit et F9 fonctionnent toujours.
- **Tutoriel** : Premiers pas actifs seulement en `Modes.current() == "survival"` (ni Duel, Tour, Donjon, Royale, entraînement) ; étapes réécrites (sans pourcentage, « Niveau 2 : choisis une carte » sans « puis valide » car U3 passe le choix en un geste) ; fiches ≤ 3 lignes, sans pourcentage ni « Eden » ; « Ce que tu gardes » d'après N1 ; nouvelle fiche `hub_gear` (« Ton équipement part en Survie ») annoncée comme nouveauté aux anciennes sauvegardes.
- Tests : `test_lot9` (Premiers pas par mode, qualité des textes, Guide, accueil à 4 tailles), `test_nav_screens` inchangé (Guide + accueil atteignables).

## Décisions
- 6 onglets au total (5 chapitres + Détails) plutôt que 6 chapitres + Détails ; « Nouveautés » et « Conseils » supprimés comme chapitres (la fiche récente est atteinte par `select("news")`, l'interrupteur est dans Commandes).
- Noms d'onglet courts (« Cartes », « Modes ») et sous-titre masqué sous 1150 px : sinon la ligne d'en-tête de `PageScreen` dépasse la fenêtre.
- Pas de portrait 3D à l'accueil (portrait + sorts à la place).

## Reste / pièges
- **Demande à U4 / U9** : l'onglet « ? » de `hero_screen.gd` et « Aide » de `pause_menu.gd` affichent encore leur propre `InfoPage` ; à remplacer par un bouton ouvrant `Guide.open_on(self, "details")`. `TestTools.help_text()` (U9) n'est plus utilisé par le Guide.
- Le Guide est reconstruit à chaque affichage d'onglet ; les pages longues (Modes à 1024 px) défilent, navigables à la manette bloc par bloc.
- « Fléau d'Eden » (succès) et le logo/étiquette « Alt + clic droit » (U8) non touchés.
- Version : voir CHANGELOG ; la fiche `hub_gear` porte la version de cet envoi.
