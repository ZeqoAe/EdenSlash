# Jeu de données d'un LoRA de style (procédure)

Département LORA. But : un style maison appris sur **nos** images, rangé sous le mot-clé `edenstyle`.

## Ce qui entre (et ce qui n'entre pas)
| Source | Entre ? | Pourquoi |
|---|---|---|
| Cartes d'activité `game/assets/ui/activities/` (960 × 320) | oui | vues de notre jeu, déjà à l'écran |
| Captures sans interface de notre jeu (`tools/art/godot/lora_capture.gd`, copie propre de HEAD) | oui (v0), un peu (v0b) | paysages, villages, combat vu par la caméra du jeu |
| Images générées **validées par le joueur** (planches de la DA, v1) | oui, à partir de la v1 | le style choisi doit primer sur l'existant |
| Captures de menus (`conception/nuit_15_10/captures/`, `conception/art/audit/`) | non pour un LoRA d'illustration | le texte et les cadres plats s'impriment dans le modèle (faux texte) ; un LoRA « interface » à part, plus tard, pour l'UIK |
| Héros, bustes, monstres rendus par notre jeu (`tools/art/godot/lora_studio.gd`) | **oui, la matière principale (v0b)** | la DA du jeu : très colorée, anime / manga (précision du joueur, 17/10) |
| Icônes du jeu (objets, sorts, talents, 64 px) | oui, en planches 8 × 8 agrandies 2× (1024²) | une icône seule agrandie 16× n'apprendrait que le flou ; la planche garde leur trait |
| Essais FLUX de G1 (`conception/art/g1_test/`) | non | pas validés ; style différent (plus sombre, « peinture numérique ») |
| Images d'autres jeux, du web, icônes de collaboration avec une marque (personnages sous licence) | **jamais** | droits ; vérifier chaque planche d'icônes à l'œil |

Provenance : le joueur a confirmé (17/10) que les assets du jeu de base (icônes, classes, monstres, illustrations) sont **notre DA** et
peuvent entrer dans le jeu de données. Le LoRA apprend donc l'allure actuelle du jeu (modèles et textures rendus par notre moteur :
éclairage, ciel, brouillard, shaders toon de `game/shaders/`). Une variante « interface » (boutons, cadres, icônes) viendra avec la bible v2.

## Étapes
1. **Portraits** (v0b, ≈ 6 min, une petite fenêtre Godot s'ouvre) :
   `python tools/art/lora_dataset.py --portraits "heros:30:0;buste:15:2;monstre:36:3" --studio C:/AI/lora_studio`
   - héros en pied (832 × 1216, pose de repos : certaines poses de combat tournent le corps), bustes et monstres (1024²), cadrés
     d'après la boîte englobante, devant le village d'une zone différente à chaque image ; sujets répartis sur les 60 classes et 219 monstres.
   **Captures de décor** (v0, ≈ 5 min) :
   `python tools/art/lora_dataset.py --capture --shots C:/AI/lora_shots`
   - copie propre de HEAD dans `C:/AI/lora_snap` (même méthode que `tools/run_tests.py`), dossier utilisateur à part ;
   - 8 zones × 6 vues (`paysage`, `aerien`, `heros`, `heros2`, `combat`, `monstre`), 1216 × 832, rendues en 2× puis réduites ;
   - sous-ensemble : `--zones limestone,avila --views heros,monstre`.
2. **Tri à l'œil** (planche : étape 4) : retirer les vues ratées (caméra dans un arbre, scène vide, doublons de classe),
   garder 30 à 60 images, varier les sujets (v0b : ≈ 1/2 héros, 1/3 monstres, le reste icônes et illustrations).
3. **Légendes à la main** dans la liste JSON (`conception/art/lora/dataset_v0b.json`) :
   - commencer par `edenstyle, ` ;
   - décrire le **contenu** (sujet, pose, décor, lumière, cadrage), jamais le style (« toon », « 3D », « anime ») : ce qui
     n'est pas décrit est appris par le mot-clé ;
   - 15 à 35 mots, anglais (l'encodeur de texte de SDXL), pas de nom propre du jeu.
4. **Dossier d'entraînement** + planche de contrôle :
   `python tools/art/lora_dataset.py --list conception/art/lora/dataset_v0b.json --out C:/AI/lora_data/eden_style_v0b --sheet conception/art/lora/v0b/jeu_de_donnees.jpg`
   (une image `NNN_nom.png` + `NNN_nom.txt` par entrée).
5. **Formats** : aucun recadrage forcé ; l'entraîneur range par format (bucketing, `bucket_no_upscale` : jamais d'agrandissement).
   Héros 832 × 1216, bustes / monstres / icônes 1024², décors 1216 × 832, cartes 960 × 320. Pour une image plus grande que 1024² de surface, elle est réduite.

## Versions
### v0b (17/10/2026, retenue)
60 images : 20 héros en pied, 10 bustes, 22 monstres, 4 planches d'icônes (armes, armures, sorts, talents ; 64 icônes chacune, tirées
à graine fixe, listes dans le JSON), 4 cartes d'activité. Liste et légendes : `dataset_v0b.json` ; planche : `v0b/jeu_de_donnees.jpg`.

### v0 (17/10/2026, décors)
52 images : 10 cartes d'activité + 42 captures (8 zones). Liste, sources et exclusions : `dataset_v0.json` ;
planche : `v0/jeu_de_donnees.jpg`. Images hors dépôt (`C:/AI/lora_shots`, `C:/AI/lora_data`) : refaites par les étapes 1 et 4.
