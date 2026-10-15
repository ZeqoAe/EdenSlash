# R_U1 — Lot U1 (= L1 de A2) : socle des menus du lobby — version 0.1.169

Fichiers à moi : `ui/lobby.gd`, `ui/menu_widgets.gd`, `ui/activities.gd`, `ui/tower_pages.gd` (+ `tests/test_pages.gd`, `tests/test_nav_screens.gd`).
Captures avant / après regardées une à une : `captures/u1/` (les « avant » viennent de la copie du dépôt à 0.1.167 ; les autres « avant » : captures de A2).

## Fait
- **Pages d'activité (T1)** : le contenu défile (`ScrollContainer`), le panneau a une **largeur fixe** (`PANEL_W` 580, `PLAY_W` 760 pour la grille) et
  ne dépasse plus l'écran ; le **bouton d'action est épinglé** sous la zone qui défile (`_foot`, `_pin`) : Lancer / Entrer / S'inscrire / Commencer à l'étage
  toujours visibles (Siège, Duel, Donjon, Royale, Tour…). La position de défilement est gardée quand la page se reconstruit (choix d'un donjon en bas de liste).
  Bouton grisé : `_pin_go(bouton, raison)` écrit la **raison en rouge au-dessus** du bouton (plus seulement en infobulle : Siège « Ouvre les Donjons… », Arènes, Ligue, Ruée, Donjon).
- **`RowButton` à hauteur automatique** (`MenuWidgets.RowButton._fit`) : plus de lignes qui se chevauchent (Survie, Tour, Panthéon). `height` = hauteur minimale.
- **Pied de page (T2)** : une seule ligne « insignes · cristaux » + heure, carte de 50 px qui tient dans l'écran (plus de chevauchement avec « Alt + clic droit… / version »,
  sans toucher `core/feedback.gd` ni `ui_theme.gd`). Astuce de caméra : « Glisser : tourner · Molette : zoom ». Carte de zone : plus de « zone 1 / 8 · débloquée(s) » ;
  barre de maîtrise avec ses chiffres (« 120 / 400 ») ; pastille rouge sur **Coffres** (nombre, ★ si roulette) à la place de « (11) ★ » (`SideButton.set_badge`).
- **Jouer** : 3 rangées de 3 (le Siège passe dans « Défis », « Épreuves de maîtrise » (Bientôt) est cachée), sous-titres ≤ 28 caractères + ellipse, infobulle « Donne : … ».
  Le texte faux de la Tour est corrigé : « Cristaux, gemmes, apparences » (d'après `core/tower.gd` / `ActivityLoot` d'E1, déjà dans l'arbre : cristaux par étage, coffre de gemmes tous les 10 étages, coffre de forge tous les 50, apparences aux paliers). Donjons / Siège : « cristaux » ajouté.
- **Survie** : lignes d'époque en 2 lignes (zones / ★☆☆ · Défi · Rang héroïque), « Paliers… » supprimé, « Rang héroïque N » avec le détail en infobulle, note « Tu pars… » supprimée.
- **Tour** : difficultés avec 4 icônes différentes et « Normal · 3 / 200 » ; étages (« Mon étage », « ‹ Difficulté » en haut, « 3 / 200 battus ») ; pluriel « 1 élite / 2 élites » ;
  **fiche d'étage stylée** (`TowerPages.Sheet` : cadre doré du lobby, taille du texte, Échap/B/clic pour fermer, bouton Fermer), sans PV / attaque / défense / IA : ennemis (élites séparées), sorts et équipement du duelliste, « Récompense : une carte, puis un coffre. »
- **Textes supprimés (§6.2, parties lobby/activities/tower)** : intro des Arènes, de la Ligue, du Gantelet, du Duel (2 phrases), du Donjon, de la Ruée, de l'Entraînement, du Défi de maîtrise
  (+ « Réussite du jour… », « Les contrats se remplissent… »), du Battle royale (paragraphe + 5 puces → 3 puces de 6 mots), « Alliés IA » (détails en infobulle), « Préparation rapide (PV ×1.0…) » (valeurs en infobulle),
  « catalogue d'Eden », jargon ML des infobulles de cerveau, « Des donjons d'Eden… », « Tu pars sans équipement… », « Sauvegarde 1 · coffre commun… », « zone 1 / 8 ».
- Argument de test `--duel-tab=free|league|pantheon|gauntlet` (captures). Tests : `test_pages` vérifie pour 11 pages la largeur fixe, la hauteur ≤ écran, le bouton épinglé visible, les lignes assez hautes ;
  `test_nav_screens` : Donjons, Tour (2 pages). Verts (voir plus bas).

## Décisions
- Largeur 580 (et non 560) : la ligne « Adversaire ▾ · Difficulté ▾ · IA » du Duel élargissait le panneau.
- Étages de la Tour : on garde 5 par page (2 lignes par étage, tient sans défiler) et on ajoute « Mon étage » plutôt que 10 par page.
- Siège : la phrase d'intro a été retirée aussi (le bandeau dit déjà « Vagues, boss, chacun pour soi »).
- Panthéon : 6 icônes distinctes (les portraits de classe ne s'appliquent pas, un cerveau joue les 60 classes).

## Demandes à d'autres lots
- **U8 / `ui_nav.gd`** : la barre d'aide manette est déjà redessinée par U8 (coin bas gauche) ; vérifier qu'elle ne recouvre pas le bouton épinglé (le panneau finit à 36 px du bas de l'écran, la barre fait 28 px et se pose à gauche, sous le menu : devrait être libre).
- **U10 / E1** : noms de donjons encore à moitié anglais côté `Dungeons.name_of` (« Requin vil de Repaire des » dans la liste de donjons : coupure à corriger dans la table de noms).

## Reste / pièges
- Non fait (P2/P3 de A2) : cartes d'époque à étoiles dessinées, jauge de puissance (la ligne « PE x / y attendue » reste du texte), vignettes illustrées des donjons, « Premier adversaire » replié sous « Avancé » (Arènes/Gantelet l'affichent dès qu'un cerveau existe), un seul contrôle « À l'arme | Équipé », date du Défi du jour en ISO (« 2026-10-15 »), images distinctes Défi de maîtrise / Ruée (la Ruée utilise l'image du Donjon).
- Piège : les `queue_free` sont remplacés par `remove_child` + `queue_free` dans `_show_menu` (sinon l'ancienne page compte dans la hauteur). Les tests qui comptent `lobby._sub.get_children()` restent valables.
- Les tests lancent `Profile.reset_all()` : lancer les captures avec `APPDATA` détourné (sinon le profil de test du dossier est écrasé).
