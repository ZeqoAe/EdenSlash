# État de l'orchestration (17/10/2026, après-midi) : à relire après une compaction ou dans une nouvelle session

## Décisions du joueur à retenir
- DA = celle du jeu existant (très coloré, animé / manga) ; icônes du jeu de base gardées ; piste d'interface B « autocollant manga » ; ressenti du clic à refaire partout.
- Le joueur dort / teste de temps en temps : **c'est l'orchestrateur qui décide** (« c'est toi qui prends les décisions »), le joueur donne l'idée globale et ses retours de testeur ; quota non limitant (« ne te soucie pas du quota »), échéance fin du mois (2 semaines).
- Toutes les recommandations par défaut des études et des rapports sont **validées**.
- Autochess : IA scriptée uniquement. Modes scellés : Survivant, Battle royale, L'Échiquier (+ les 3 futurs modes).
- Progression : niveau de héros 1-90 (compte), niveau de partie séparé, ~30 h pour un équipement 80-90 correct, Survie renommée Aventure (lot A9 en dernier : renommage en une passe, jamais les ids ni les clés de sauvegarde).
- Études comparatives par mode (`conception/benchmark/METHODE.md`) : images tierces hors dépôt (`C:\AI\benchmark_refs`), dépôt GitHub PUBLIC ; modes de progression inspirés des MMORPG sans la corvée.
- **Style visuel choisi** : LoRA `eden_style_v0b` à l'intensité 0,5 (SDXL, entraînement local ~30 min ; RunPod inutile ; 15 $ de crédit gardés pour des générations lourdes éventuelles, le joueur lancerait le pod lui-même). Scripts `tools/art/`.
- Illustrations ILL-1 validées et intégrées (ILL-2). Le menu principal garde sa scène 3D du héros.
- 3 nouveaux modes (études faites, valeurs par défaut validées) : **Le Colisée** (Arena, 6×3 Classique / 4×3 Éclair / 8×3 option si perf), **Les Deux Voies** (MOBA 4v4), **L'Assaut** (tactique 4v4 bombe, + Sanctuaire).

## Terminé et poussé (versions jusqu'à 0.1.288)
Battle royale BR1-BR5, BR-I1/I2/I3 (HUD, carte, mort, butin, bilan, accessibilité), BR-R1 (page du mode, modificateurs, autel du gardien, ligue royale) ; Survivant S9, SVX-1 (horde), SVX-2 (HUD/cartes/bilan v2) ; N2 ; refonte Aventure A1-A5, A7, H1-H4a, H4b (12 cartes mesurées), H56 (rythme ~30-32 h, activités au niveau de héros, textes) ; C1, K1, T1 ; L'Échiquier AC-A à AC-J, ACX-1/2/3 ; DV1 ; Notion ; ComfyUI ; DA v2 ; UIK-0/1/2 (polices, UiTheme v2 papier, UiFeel, raretés, flou) ; SND-1/2 (46 sons + branchement) ; ILL-1/2 ; ICO-1 (176 pictogrammes) ; HUB-1 (nouveautés, Continuer, boussole v2, Aujourd'hui, Journal des quêtes L) ; DNG-1/2 (records, « ce qui t'a battu », barre de boss, télégraphes, page Donjons v2, Carnet > Rencontres) ; GX-2/3/4 (forge sans punition, plans, Fabriquer v2, objectifs, sac, Tout monter à +5, préréglages) ; PRP-1 (chaîne image → 3D) ; études BM-BR/AUTO/SURV/HUB/GEAR/DNG/ARENA/MOBA/TAC.

## En cours (agents lancés ; leurs retours arrivent à la session)
CLS-1 (classes faibles contre les boss) · SVX-3 (Survivant : évolutions, records, codex ; corriger test_svx2 bilan 728 px) · DNG-3 (donjons P1 : étoiles, entraînement, Siège, Ruée) · HUD-2 (HUD du mode principal v2 ; vérifier le HUD absent des Arènes/Gantelet) · PRP-2 (skins d'armes et ailes intégrés) · GX-5 (talents v2, titres, Registre v2, jalons) · MB-0 (essai de performance du MOBA : GO/NO-GO) · MODE-0 (socle commun des modes d'équipes).

## À lancer ensuite (ordre)
1. Après MODE-0 + MB-0 : lots d'implémentation des 3 modes d'après les plans de lots (ARENA.md CO-A…CO-L, MOBA.md MB-*, TACTIQUE.md 15 lots) ; 2 à 3 en parallèle ; chaque mode scellé, DA v2, IA scriptée qui joue très bien, équilibre mesuré.
2. Reste Battle royale/autochess/Survivant : mesurer au calme la méta Classique de l'Échiquier (Rempart+Estoc 30 % > 20 % : levier `ROLE_BASE` tank, 2 000 parties) ; carrière BR dans le Carnet.
3. ICO-2 : brancher les icônes non branchées (activités, familles, raretés, touches) quand les écrans sont stables ; ANI/FX (effets, animations d'attaque procédurales), CHR (tenues), REV (revue de cohérence écran par écran).
4. **A9 : renommage Survie → Aventure, en dernier**, en une passe.
5. Suite complète de tests au calme (`python tools/run_tests.py -j 2`), puis éventuellement rapport du matin (seulement si le joueur le demande).

## Pièges connus
- Dossier de travail partagé : commits par index construit depuis HEAD par remplacements de texte (jamais `git apply --unidiff-zero`), jamais de `git commit` ordinaire sur l'index partagé (il contient des entrées périmées : risque d'annuler des travaux), `python tools/check_scripts.py` (sur copie de HEAD si le dossier est rouge à cause d'autres agents) avant tout push, ne jamais tuer des processus Godot d'autres agents. Quand tous les agents seront inactifs, envisager de resynchroniser l'index sur HEAD.
- Après l'ajout d'un `class_name`, `--import` (Jouer.bat le fait une fois par version) ; `.import` des icônes non commités (générés).
- Machine saturée (20 à 58 Godot en parallèle) : faux échecs de tests de durée (`test_ac_fight`, `test_ac_sim`…) ; mesures bruitées (±15 points sur 20 combats) ; lancer les tests avec `-j 1/2`.
- BR-R1 : 4 parties sur 60 arrêtées sans message (processus tués de l'extérieur ?) : à surveiller.
- Limites d'usage : un agent coupé se relance par `SendMessage` avec la consigne de relire `git status` / `git diff` de son travail en cours.
