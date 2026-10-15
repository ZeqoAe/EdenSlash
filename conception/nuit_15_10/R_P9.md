# R_P9 — Notes du joueur (passe P9, version 0.1.189)

14 notes lues (`feedback/*/rapport.json`) et 14 captures regardées ; aucune nouvelle note pendant la passe. Statut de chacune
dans `feedback/_SUIVI.md` (hors git, lisible par le joueur ; CLAUDE.md dit d'y ajouter chaque nouvelle note).

## Bilan des notes
- **Déjà traitées avant cette passe (9)** : autel en pyramide (0.1.121, `core/fortune.gd`, conforme à la description : 8 étages,
  8 à 2 cases dont une piégée, encaisser ou monter, sommet = apparence dorée, 1 chance sur 8) ; coffres lisibles et animés (0.1.119,
  0.1.139, 0.1.174 ; capture `shot_chests` regardée) ; niveau des coffres (0.1.119 + trophées hors équipement 0.1.130) ; roulette
  (0.1.174) ; gains par activité : Survie (fournitures, coffres de forge et du joaillier, E4), Tour (forge + joaillier « gemmes », E1),
  Donjons (panoplies, plans, légendaire, Fabrication). Seul écart : les pièces **éveillées** viennent de la Survie (époques III-IV),
  pas des donjons — à débattre avec le joueur.
- **Corrigées ici (5)** : bug d'icône, monstres bloqués, pièce possédée reproposée, rage en paliers, cadenas des activités.

## Ce qui est fait
1. **Bug (15/10 12:10)** : onglets de l'inventaire (Héros > Équipement) : icône centrée = dessinée sous le texte par Godot ;
   maintenant à gauche du nom (`inventory_page.gd`), seule au centre à 1280 px. Captures 1600×900 et 1280×720 regardées.
2. **Horde bloquée par le décor (14/10)** : vraie cause trouvée par mesure (`tests/test_pursuit` : le héros court 130 m, 40 monstres
   suivent). `Monster._path_step` visait le premier point du chemin à plus de 1,2 m, souvent son **point de départ resté derrière**
   (chemin recalculé toutes les 0,4-0,7 s) : demi-tours permanents. Désormais un index de point de passage qui n'avance que vers
   l'avant. Mesures : vitesse réelle / voulue **0,38 → 0,95**, immobiles 6,7 % → 2,9 %, distance au héros à la fin **91 m → 18 m**.
3. **Pièce déjà possédée (14/10)** : l'écran d'héritage n'existe plus ; en plus, un coffre d'emplacement ne repropose plus la pièce
   portée (même modèle d'Eden ; arme secondaire comprise pour le coffre d'arme), sauf s'il ne reste qu'elle (`SlotChests.worn_eden`).
4. **Rage en paliers (15/10 06:02)** : barème du joueur appliqué tel quel, une minute par palier, PV **et** dégâts des monstres de
   la carte : 10:00 ×1,1 ; 11:00 ×2 ; 12:00 ×11 ; 13:00 et après ×101 (en plus de la rage existante : +3 niveaux, dégâts ×1,3,
   vitesse ×1,25). Boss non concerné (l'arène arrête le chronomètre), PV gardés en proportion, nouveaux monstres nés au palier.
   HUD « RAGE ×2 · 0:42 », ligne d'objectif « Rage : monstres ×2, ×11 dans 0:42 », bandeau à chaque palier.
5. **Activités verrouillées (15/10 06:32)** : image presque noire, cadenas doré sur deux chaînes en croix (dessinés, pas d'image),
   placé au-dessus du nom même quand la condition tient sur deux lignes ; condition sous le nom (le 🔒 du texte est retiré).

## Décisions
- Rage : cohérente avec « la rage est un chronomètre qui force la fin de carte ». Elle ne touche pas l'économie mesurée par E6/P5
  (plafonds de monstres comptés, insignes au prorata) ; elle supprime de fait la ferme en rage. XP des monstres non multipliée.
- Le plancher des coffres (pièces 23 pour un coffre de niveau 10) vient des données d'Eden (mythiques et panoplies dès 20-23).

## Risques et reste
- Les monstres suivent maintenant à pleine vitesse : la Survie est plus pressante (c'était le but). Les mesures au pilote
  automatique de P5 (« boss atteint une run sur deux ») peuvent baisser, d'autant que la rage tue vers 12-13 min : à revoir avec le
  journal de run du joueur.
- Tests verts : test_p9 (19), test_pursuit (3), test_pages, test_nav_screens, test_farm, test_progress, test_hud, test_cards,
  test_e6, test_build, test_controls, test_lot8, test_p1, test_results, test_p4_flow, test_lot7, test_u3, test_e4, test_royale,
  test_siege, test_lot16. Captures : `tests/shot_p9.tscn` (`P9_RES=1280x720`).
