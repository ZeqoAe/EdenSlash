# R_DA : Direction artistique, vague 1 (17/10/2026)

Aucun fichier de `game/` modifié : pas de changement de version.

## Produit
| Fichier | Contenu |
|---|---|
| `AUDIT_UI.md` + `audit/` | critique de 28 écrans (45 captures 1600×900 et 1280×720, comptes neuf et avancé), contrastes mesurés, liste de 13 signes « prototype / IA », ce qu'on garde, priorités ; `audit/icones_planche.png` (les 4 familles d'icônes actuelles) |
| `BIBLE.md` | principes, palette fermée, typographie, formes, composants et états, icônes, illustration, effets, mouvement, son, grille de revue |
| `tokens.json` | couleurs (dont raretés et familles), typo, espacements, chanfreins, bordures, ombres, lueurs, tailles, durées, courbes (équivalents Godot), niveaux sonores |
| `bible/composants.png` (+ `.html`) | chaque composant dans tous ses états, en CSS pur à partir des jetons : la cible du kit d'interface |
| `bible/maquette_lobby.png` (+ `.html`) | le lobby refait dans la piste B sur une vraie vue du jeu sans interface |
| `bible/palette.png`, `bible/typo.png` | palette et spécimen (Alegreya SC + Alegreya Sans, variante Grenze Gotisch, face à Cinzel + Nunito) |
| `pistes/comparaison.html` (+ `comparaison.jpg`) | les 3 pistes côte à côte, notes, recommandation, 3 questions au joueur |
| `pistes/variantes/`, `planche_*.jpg`, `prompts_pistes.json` | 36 images ComfyUI (FLUX.1-schnell, 5 à 15 s chacune, graines 7100-7151) : planche, cadre, bouton, case, jauge, épée × 2 graines × 3 pistes |

Méthode des captures : copie propre de HEAD (`tools/run_tests.py preparer_copie` dans `%TEMP%/eden_da`), APPDATA détourné, outils
`shot_p1`, `shot_hud`, `shot_cards`, `shot_results`, `shot_registry`, `shot_ac`, `world.tscn -- --card-shot | --gear-shot | --pause=1`,
plus deux scènes de capture écrites dans la copie seulement (écran titre, lobby sans interface). Aucun débord à 1280×720.

## Recommandation
**Piste B, bronze et émail.** Elle garde ce qui marche (or sur nuit, contrastes de 10 à 16:1, manette, scène 3D derrière les menus),
remplace la forme unique (rectangle arrondi à filet doré) par une famille de formes reproductible en code (coins coupés via
`StyleBoxFlat.corner_detail = 1`, double filet réservé aux fenêtres, biseaux, usure par bruit) et ajoute une couleur d'état qui
n'est pas l'or (émail bleu = sélection). Polices : Alegreya SC (titres) + Alegreya Sans (texte), OFL 1.1 vérifiées. Le parchemin
reste une matière secondaire pour les pages « papier ».

## À trancher par le joueur
1. Piste : B (bronze et émail), A (parchemin) ou C (cristal) ?
2. Police des titres : Alegreya SC (sobre) ou Grenze Gotisch (marquée) ?
3. Ornements : sobres (coins et titres) ou riches (volutes gravées sur les fenêtres) ?

## Chantiers de l'équipe (dans l'ordre)
1. **TYP** (dès la réponse 2) : polices + OFL dans `game/assets/fonts/`, `FontVariation` (lnum, tnum), échelle de 7 tailles dans
   `UiTheme.text_size`, plancher 15 avec Alegreya Sans ; chasse aux 15 réglages sous le plancher et aux mots anglais / % permanents
   (avec `test_texts_fr`).
2. **UIK** (dès la réponse 1) : `UiTheme` v2 lu depuis `tokens.json` ; chanfreins, trois profondeurs, onglets en rail, focus en anneau
   clair, sélection en émail, désactivé avec raison ; shader `ui_plate.gdshader` ; fin de `frame/panel.png`. Revue REV à chaque écran.
3. **ICO** : ~40 pictogrammes maison pleins (remplacent `assets/ui/icons/`, puis monnaies) ; ensuite les icônes de contenu peintes
   (objets, sorts, classes, statuts) qui remplacent celles du client d'origine (gros lot, avec LORA).
4. **LORA** (en parallèle dès maintenant) : jeu de données = vues du jeu + planches B retenues ; sert ICO et ILL.
5. **ILL** : lettrage du logo, cartes d'activité repeintes sur des vues du jeu, états vides, fond du titre.
6. **FX** : télégraphes lisibles (bord net, intérieur désaturé), textes flottants empilés (audit `20_hud_donjon`).
7. **ANI** : `UiMotion` (durées et courbes de `tokens.json`), focus qui glisse, nombres qui défilent, option « réduire les animations ».
8. **SND** : sons d'interface par matière (bronze, émail, parchemin), signatures de rareté.
9. **CHR, PRP** : après la vague 3.

## Premiers écrans à refaire (effet de levier)
1. **Écran titre + lobby** (premier contact ; maquette prête).
2. **Menu Jouer + pages d'activité** (cartes : image, voile, titre, une ligne ; verrous sans chaînes).
3. **`ResultsPanel`** : un composant, 6 bilans d'un coup.
4. **En-tête `PageScreen`** : Héros, Atelier, Carnet, Coffres, Paramètres, Guide d'un coup.
5. **`CardPicker`** (choix de carte et d'équipement), puis le **HUD**.
