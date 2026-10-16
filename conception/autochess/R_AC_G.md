# R_AC_G — L'Échiquier, lot AC-G : l'interface (17/10/2026)

## Fait
- **Écran jouable** `game/scenes/autochess.tscn` (`ui/autochess_screen.gd`, `AutochessScreen`) : plateau d'AC-F + cadre + partie
  d'AC-B contre 7 `Autochess.RandomStrategist`, combat provisoire `power_fight` montré 3 s (×2 possible), bilan de manche
  3 s, puis manche suivante ; une partie se joue de bout en bout à la souris, au clavier et à la manette.
  `godot --path game res://scenes/autochess.tscn [-- --seed=N --ac-resume --autoplay]` ; réglages de lancement par
  `AutochessScreen.config` (seed, resume, save_path, autoplay, fast) pour AC-I et les tests.
- **Cadre** `ui/autochess_hud.gd` (`AutochessHud`) : frise de l'étape dessinée (● combat, ▲ monstres, ◆ choix partagé,
  rond rouge gardien, point doré = atout), étape / manche, minuteur ; niveau + barre d'XP + [Acheter de l'XP] ; or au centre
  en onglet (pastilles d'intérêts, infobulle) ; [Actualiser] [Verrouiller] [Prêt] avec la touche rappelée dans le coin
  (clavier ou manette selon la dernière entrée) ; en combat la boutique se replie (« Combat contre … », barre, Vitesse ×1 / ×2) ;
  bandeau de manche (revenu détaillé : base, intérêts, série ; puis Victoire / Défaite / Égalité, PV perdus, or, butin) ;
  petits avis ; fin de partie provisoire (place, manches gagnées, or dépensé, Rejouer / Retour). Aides de style communes
  `AutochessHud.lbl / box / button`.
- **Boutique** `ui/autochess_shop.gd` (`AutochessShop`) : 5 cartes (bord et bandeau couleur du coût, portrait, nom,
  2 traits, coût, pastilles des copies possédées ; la carte qui donnerait une étoile brille d'or) ; clic, A, touches 1-5.
- **Traits** `ui/autochess_traits.gd` (`AutochessTraitPanel`) : une ligne par trait (pastille hexagonale du palier, nom,
  seuils, atteints en or), actifs d'abord, autant de lignes que la hauteur le permet ; clic / A : petite carte de détail.
- **Stratèges** `ui/autochess_players.gd` (`AutochessPlayers`) : classés par PV (rang, portrait, nom, barre, frise des
  6 dernières manches), toi en or, l'adversaire de la manche en rouge, éliminés grisés avec leur place ; clic / A en
  préparation : son plateau sur la moitié adverse (reclic : retour).
- **Choix à cartes** `ui/autochess_augments.gd` (`AutochessChoicePanel`) : atout (3 cartes de la rareté, Relancer une
  fois), premier héros, héros légendaire, objet, composant, famille, trait d'Emblème ; [Voir le plateau] replie le choix,
  « Revenir au choix » dans la frise. Détail chiffré seulement sur la carte visée.
- **Choix partagé** `ui/autochess_carousel.gd` (`AutochessCarousel`) : 9 cartes en anneau (unité + composant), ordre des
  stratèges en haut, choix des autres montrés un à un (0,6 s), 10 s à ton tour puis première carte libre d'office.
- **Fiche d'unité** `ui/autochess_unit_card.gd` (`AutochessUnitCard`) : à la place des traits quand la souris ou le cadre
  vise une unité (plateau, banc, boutique) ou un objet : portrait, étoiles, coût, rôle et place, 2 traits (compte / palier
  suivant), sort (type, mana ; description chiffrée en infobulle), PV / attaque / portée en barres, objets portés.
- Tests : `test_ac_ui` (56 vérifications : choix du 1er héros, achat au clic et à la touche, actualisation, refus sans or,
  XP, verrou, placement, objet donné, vente, unité tenue, fiche, détail d'un trait, plateau d'un stratège, Prêt au bouton
  et à Y, bandeau, atout avec relance / repli / retour, choix partagé, atteignabilité à la manette de chaque bouton et des
  47 cases, aucun mot anglais, partie complète au pilote, Rejouer) ; `test_nav_screens` (premier héros, préparation) ;
  captures `tests/shot_ac.tscn` (10 vues en 1280 × 720 et 1600 × 900, 0 ligne `[débord]`), regardées.

## Décisions
- Calques : cadre et cases sur `AutochessCursor.LAYER` (6), cadre ajouté après le curseur (il prend la souris en premier) ;
  choix et anneau sur le calque 8 (la manette n'y voit qu'eux) ; petites cartes `InfoCard` (118). Pendant qu'une unité est
  tenue, la boutique se replie : la zone « Vendre » du curseur apparaît à sa place.
- Le plateau applique lui-même les déplacements : l'écran rejoue chaque signal sur la partie (`place`, `to_bench`, `sell`,
  `equip`) puis remet l'état de la partie (`set_state`) : la partie reste la seule vérité. Objet donné : indice retrouvé par
  son nom dans le banc d'objets de la partie (le plateau peut avoir échangé deux cases d'objets).
- Manette (SPEC §7.1) : Y Prêt (Vitesse en combat), LB XP, RB boutique, LT actualiser, RT verrou, Start pause ; Y n'ouvre
  plus le curseur libre sur cet écran. Clavier : V verrouille (non prévu par la SPEC).
- Stats de la fiche en barres (√ de la base de la classe × coût × étoiles, rapportée au plus fort) : les vraies fiches de
  combat viendront d'AC-E ; les chiffres sont dans l'infobulle. Niveau 1 : [Acheter de l'XP] grisé (le niveau 2 est donné
  à 1-2, AC-B n'a pas d'XP de 1 à 2).
- Noms des 7 stratèges tirés à la graine de la partie (une partie reprise garde les mêmes) ; portraits = icônes de classe.
- Classes renommées `AutochessTraitPanel` / `AutochessChoicePanel` : `AutochessTraits` / `AutochessAugments` sont pris par
  AC-H (`core/`).

## Reste (autres lots)
- AC-I : entrée du lobby (« Reprendre la partie » = `config.resume`), bilan `ResultsPanel`, fiches du tutoriel, Guide.
- AC-E / AC-C : vrai combat (barres de PV et mana au-dessus des unités, compteur de dégâts) ; AC-D : stratèges ; regarder
  un autre combat pendant la manche (aujourd'hui : son plateau en préparation seulement).
- Spectateur après élimination (aujourd'hui : fin de partie directe avec la place).

## Pièges
- `UiNav` ne voit que le calque le plus haut **qui a des candidats** : une carte de l'anneau grisée resterait inatteignable,
  donc les cartes « pas à ton tour » restent actives et l'écran ignore le choix.
- Le pied de l'écran grandit vers le haut (`grow_vertical`) et laisse 40 px à la barre d'aide de la manette et au numéro de
  version ; les bancs du plateau finissent juste au-dessus de l'onglet de l'or en 1280 × 720.
