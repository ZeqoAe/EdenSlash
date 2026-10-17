# R_DA : Direction artistique (17/10/2026), v2 après le retour du joueur

Aucun fichier de `game/` modifié : pas de changement de version.

## Ce qui a changé depuis la v1
Le joueur a corrigé deux points : (1) les icônes et assets du jeu de base **restent** (pas de remplacement) ; on améliore ce que
nous avons fait nous-mêmes (boutons, menus, cadres, jauges, onglets) et le **ressenti du clic** ; (2) la DA **existe déjà** (classes,
monstres, icônes : très coloré, animé / manga) : on l'applique, on n'invente pas de thème. La piste « bronze et émail » et sa bible
sont archivées dans `archive_v1/` ; l'audit est gardé et corrigé.

## Produit (v2)
| Fichier | Contenu |
|---|---|
| `bible/da_reelle.jpg` | planche de la DA existante : 20 monstres et 20 héros rendus par le jeu (planche des 60 classes : `tests/test_outfit.tscn -- all`), icônes de classes / sorts / états / objets agrandies |
| `bible/palette_reelle.png` | couleurs mesurées sur ≈ 1 400 fichiers (icônes, textures des héros, des monstres, des effets, vues d'activités) : saturation, valeur, dominantes ; les 5 teintes des fonds d'icônes |
| `BIBLE.md` v2 | la DA mesurée, principes, couleurs, typographie, formes « autocollant », composants et états, **spécification du clic** (durées, courbes, échelles, sons, vibrations, particules par élément), vocabulaire manga, icônes gardées, HUD, grille de revue |
| `tokens.json` v2 | encre, papier, 6 bonbons × 3 tons (= familles et raretés), texte, typo et contours, rayons, ombres dures, cel, trame, mouvement (durées, courbes Godot, échelles), sons, vibrations manette |
| `pistes/comparaison.html` | 3 pistes d'interface dans la DA (A bonbon glossy, **B autocollant manga**, C gelée de nuit), chacune sur 4 écrans réels : lobby, menu Jouer, bilan, composants avec états et clic image par image (`pistes/<a|b|c>_<écran>.jpg`, source `pistes/maquettes.html?p=&e=`) |
| `bible/typo.png` (+ `.html`) | Mochiy Pop One + M PLUS Rounded 1c face à Cinzel + Nunito |
| `AUDIT_UI.md` | audit gardé, corrigé (icônes du jeu conservées, diagnostic « l'interface ne parle pas la langue du jeu ») |

## Décision
**Piste B, autocollant manga** : contour d'encre de 3 px (la couleur des cadres d'icônes d'état), aplats en deux tons nets (l'ombrage
des personnages), reflet blanc et rayons (les icônes de sorts), 5 bonbons (les familles), ombre dure sur laquelle tout s'écrase au clic.
Panneaux papier, puits d'encre pour les listes et le HUD. Polices Mochiy Pop One + M PLUS Rounded 1c (SIL OFL 1.1, vérifiées).
Question au joueur (une seule, facultative) : panneaux papier clairs (B) ou panneaux nuit (C) pour les écrans de menu ?

## Chantiers (le plus visible d'abord, sans remplacement d'icônes)
| Ordre | Écran / chantier | Département | Contenu |
|---|---|---|---|
| 0 | Socle | TYP + UIK + ANI | polices (sous-ensembles latin), `UiTheme` v2 lu depuis `tokens.json`, shader `ui_sticker.gdshader`, autoload `UiFeel` (clic, sons, vibrations) branché sur tous les `BaseButton` |
| 1 | Écran titre | UIK | logo Mochiy contouré, un primaire soleil, deux boutons papier, étincelles |
| 2 | Lobby | UIK | menu en boutons autocollants, carte du héros, zone, bourse, avis en bulle (`pistes/b_lobby.jpg`) |
| 3 | Menu Jouer + pages d'activité | UIK | cartes d'activité autocollantes (vraies images), verrous avec condition, onglets (`pistes/b_jouer.jpg`) |
| 4 | `PageScreen` commun | UIK | en-tête, onglets, Fermer : Héros, Atelier, Carnet, Coffres, Paramètres, Guide d'un coup |
| 5 | Bilans communs (`ResultsPanel`) | UIK + ANI + SND | « Victoire ! » contouré, traits de vitesse, tuile héroïne, nombres qui défilent, confettis, signatures sonores (`pistes/b_bilan.jpg`) |
| 6 | HUD | UIK + FX | jauges et cases de sorts autocollantes, chiffres contourés, onomatopées, télégraphes lisibles |
| 7 | `CardPicker`, infobulles, `InfoCard` | UIK + ANI | choix de carte avec le clic spécifié, bulles |
| 8 | Pictogrammes manquants | ICO | seulement les menus et actions sans icône du jeu, style des icônes d'état ; remplacent `assets/ui/icons/` |
| 9 | Sons d'interface | SND | matière « jouet » (bois, plastique, carillon, papier), 6 signatures de rareté |
| 10 | L'Échiquier, écrans restants | UIK | passe de cohérence écran par écran (REV) |
LORA : utile plus tard pour des illustrations d'activité dans le style du jeu ; pas bloquant pour l'interface.
