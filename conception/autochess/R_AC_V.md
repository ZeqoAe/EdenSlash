# R_AC_V — L'Échiquier, lot AC-V : la mise en scène (17/10/2026)

Demande du joueur : jouer l'Échiquier dans une vraie arène (celle du Duel / des Arènes 3v3) plutôt que sur un petit socle,
avec le HUD par-dessus l'arène comme en Duel, et les statistiques de combat « comme dans TFT » (dégâts infligés, reçus, soins).

## Fait
1. **Arène** — `world/autochess_arena.gd` (`AutochessArena`) : l'arène du Duel (`ProcMap.generate_arena`, cuvette fermée de
   falaises, rochers, 6 torches et leur feu, ciel / brouillard / lumière du biome comme `World._build_environment`, musique du
   duel `Music.DUEL`), sans dangers. Le décor change avec l'étape (`ARENA_BIOMES` : arid = l'arène du Duel, puis rainbowfall,
   beluga, wetlands, delphi, avila, blackflame). Centre aplani (`ProcMap.arena_flat`, 18 m : seule retouche de `proc_map.gd`,
   0 par défaut = rien ne change ailleurs) ; carte retirée du groupe « map » (les unités ne cherchent pas de chemin : les
   plateaux cachés sont loin du maillage). Le plateau (`AutochessBoard.arena_style`) n'a plus de socle : cases plates en
   filigrane (fond bleu nuit translucide, filet doré lumineux) tracées 2 cm au-dessus du sol, cercle doré et ligne de partage ;
   elles s'allument en préparation et s'estompent au combat (`light_up`, 0,6 s) ; « Héros placés » caché au combat. Mêmes
   cases, même miroir, même curseur (tests d'AC-F inchangés). Grille 7 × 8 de 2 m : 15 × 14 m, bancs et allée du stratège
   compris (12,2 m au plus), dans le cercle peint de l'arène (14 m) ; le fond plat de l'arène fait 26 m.
   Caméra : en préparation celle du plateau (deux zooms, les cases se visent) ; au combat une caméra large et inclinée comme
   celle du Duel (50°, 27 m, champ 45°) qui arrive en douceur (0,7 s) : molette (et stick droit vertical) = zoom 15-36 m,
   stick droit horizontal ou clic droit maintenu = rotation (±50°) ; si le joueur est le camp 1, elle passe de l'autre côté.
   **Vrai combat branché dans l'écran** (`AutochessScreen._arena_combat`) : `AutochessDirector` (plateau du joueur regardé dans
   l'arène, les autres cachés à 300 m comme validé par AC-E), Vitesse ×1 / ×2 sur le directeur, clic sur un stratège pendant
   le combat = regarder son combat (l'arène et la caméra suivent). Durées réduites (`config.fast`, tests) ou `config.real =
   false` : combat de données instantané, même couche d'effets (`AutochessStats.data_fight`, au lieu de `power_fight`).
2. **HUD par-dessus l'arène** — `ui/autochess_team_bars.gd` (`AutochessTeamBars`) en haut, comme les barres d'équipe des
   Arènes : ton nom (or) et tes unités à gauche, l'adversaire (nom de son IA, « Monstres », « Gardien », « Écho de … ») à
   droite ; une pastille par unité (icône de la classe, cadre de la couleur du coût, étoiles, PV vert / rouge, mana bleue,
   croix rouge à terre) ; au centre le chronomètre (m:ss), l'étape et la manche, « Fureur » en rouge à 30 s, ×2. Le cadre
   d'AC-G se replie au combat : frise cachée, colonnes sous les barres (`COMBAT_TOP`), pied réduit au bouton de vitesse.
3. **Statistiques façon TFT** — `core/autochess_stats.gd` (`AutochessStats`, données pures lues dans `ctx.units[fid].stats`
   de la couche ; compteur ajouté à la couche : `dealt_attack`, dégâts des auto-attaques). Compteur en direct
   `ui/autochess_meter.gd` (`AutochessMeter`, colonne gauche au combat à la place des traits) : une ligne par unité, classées,
   chiffre et barre de la couleur du camp (dégâts en trois tons : auto-attaques, sorts, autres), onglets Dégâts / Subis /
   Soins / Boucliers (clic, A, Tab, LB / RB), repliable. Bilan de manche `ui/autochess_recap.gd` (`AutochessRecap`, calque à
   part) : résultat en tête (à la place du bandeau), MVP de la manche, barres classées des deux camps, total de chaque camp,
   [Continuer] (A, Entrée) ; B / Échap ferme ; il retient la manche suivante au plus 20 s. Bilan de partie : bouton
   « Statistiques » de la fin de partie (cumul par classe de tes héros, héros de la partie, MVP ×N).

## Décisions
- MVP = dégâts + soins + la moitié de ce qu'il a encaissé (subis + arrêtés par ses boucliers) : un tank qui tient compte.
- « Boucliers » = dégâts arrêtés par les boucliers de l'unité (la couche ne sait pas qui a donné un bouclier).
- « Soins » = soins donnés par l'unité (sorts, vol de vie, objets) ; les soins sans auteur (Ferveur, Ralliement) ne sont
  crédités à personne (la somme des soins donnés est donc ≤ celle des soins reçus).
- Le combat continue pendant la pause (comme TFT) ; le cumul de partie n'est pas sauvegardé (une partie reprise repart de 0).

## Chiffres
- Rendu (captures `tests/shot_ac.tscn`, vraie fenêtre, 4 combats dont 80 unités au plus, plateau regardé dans l'arène) :
  image médiane **5,9-6,1 ms**, p95 10-11 ms, en 1280 × 720 comme en 1600 × 900 ; 0 débord, 0 chevauchement.
- `test_ac_fight` (machine chargée par d'autres sessions) : 80 unités, image physique médiane 16,7 ms sans arène, 15,8 ms
  avec l'arène (même coût) ; 5 contre 5 : médiane 20 s ; tout le reste inchangé.
- Combat de données connu (`test_ac_stats`) : 13 487 dégâts infligés = 13 487 subis (à 0,01 près), éliminations = chutes ;
  coups posés à la main : chiffres exacts (auto-attaques, sort, soin borné). Partie au pilote : 23 manches cumulées.

## Tests
`test_ac_stats` (nouveau, 36 vérifications), `test_ac_board` (+7 : style arène), `test_ac_fight` (+2 : arène),
`test_ac_ui` (+4 : Statistiques), captures `tests/shot_ac.tscn` (+5 vues : combat, mêlée, compteur Soins, bilan à la manette,
bilan de partie), regardées. Commits : 0.1.249 (arène), puis HUD et statistiques ensemble (les branchements des deux
sous-lots sont dans les mêmes fonctions de l'écran).

## Reste / pour les autres lots
- AC-U : les barres 3D au-dessus des unités sont vertes pour le camp 0 et rouges pour le camp 1 (`AutochessUnit.SIDE_COLORS`) ;
  quand le joueur est le camp 1, ses unités ont des barres rouges alors que le HUD les montre en vert.
- AC-I : entrée du lobby, bilan `ResultsPanel` (le cumul `AutochessScreen.game_stats` est prêt à y entrer).

## Pièges
- Le plateau en style arène doit recevoir `arena_style = true` avant d'entrer dans l'arbre.
- `ProcMap.generate_arena` met la carte dans le groupe « map » : `AutochessArena.build` l'en retire aussitôt.
