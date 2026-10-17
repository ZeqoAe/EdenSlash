# État de l'orchestration (17/10/2026, matin) : à relire après une compaction ou dans une nouvelle session

## Décisions du joueur à retenir
- DA = celle du jeu existant (très coloré, animé / manga) ; icônes du jeu de base gardées ; piste d'interface B « autocollant manga » ; ressenti du clic à refaire partout.
- Toutes les recommandations par défaut des études et des rapports sont **validées** (« on garde toutes tes recommandations »).
- Autochess : IA scriptée uniquement (aucun cerveau neuronal). Modes scellés : Survivant, Battle royale, L'Échiquier.
- Progression : niveau de héros 1-90 (compte), niveau de run séparé (cartes), 30 h pour un équipement 80-90 correct, Survie renommée Aventure (lot A9 en dernier : renommage en une passe).
- Études comparatives par mode (`conception/benchmark/METHODE.md`) : images tierces hors dépôt (`C:\AI\benchmark_refs`), dépôt GitHub public ; modes de progression inspirés des MMORPG sans la corvée.
- 3 activités à ajouter ensuite : Arena façon LoL, MOBA 4v4, mode tactique 4v4 (bombe façon CS / Valorant ou objectifs façon Overwatch) : étude → spécification → lots.

## Terminé et poussé (versions 0.1.214 → 0.1.256 et plus)
Battle royale BR1-BR5 ; Survivant S9 (12 sorts, orbes) ; N2 (deux armes, plus d'enclume) ; refonte Aventure A1-A5, A7, H1-H4a, H7 ; C1 (création de personnage) ; K1 (curseurs) ; T1 (tests) ; L'Échiquier AC-A à AC-J, AC-I ; DV1 (intégration continue, `check_scripts`) ; NT1 (hub Notion) ; G1 (ComfyUI) ; DA v1 / v2 (bible, tokens, pistes) ; études BM-BR, BM-AUTO, BM-SURV.

## En cours (agents lancés ; leurs retours arrivent à la session)
UIK-0 (socle d'interface : polices, `UiTheme` v2, `UiFeel`) · H4b (équilibre mesuré des 12 cartes d'Aventure) · LORA (modèle de style Kohya) · BR-I1 (HUD tactique Battle royale) · BR-I2 (carte, mort, butin, bilan Battle royale) · ACX-1 (autochess : DA v2, traits, boutique, éco) · SVX-1 (Survivant : horde, lisibilité) · BM-HUB (étude hub / HUD / quêtes) · BM-GEAR (étude héros / équipement / forge) · BM-DNG (étude donjons / tour / ruée / siège).

## À lancer ensuite (ordre)
1. ACX-2 (autochess : curseur et annulations, combat lisible, bilan non bloquant, moments manga) ; SVX-2 (Survivant : HUD v2, choix de carte v2, évolutions, bilan v2, mots) : après UIK-0.
2. Lots d'implémentation issus des études BM-HUB, BM-GEAR, BM-DNG (backlogs P0) ; étude + lots Duel / Ligue / Panthéon / Arènes ; étude Quêtes si séparée.
3. Département DA : TYP, ICO (pictogrammes manquants), ILL (illustrations d'activités), FX, ANI, SND, PRP, CHR, REV (voir `conception/art/ORGANISATION.md`) ; Figma (système de composants) ; LoRA v1 entraîné sur les choix du joueur.
4. Titre, lobby, menu Jouer, `PageScreen`, bilans communs, HUD de l'Aventure dans la DA v2.
5. Lots restants de la refonte Aventure : H5 (activités au niveau de héros), H6 (textes, boussole, Registre), A8, **A9 (renommage Survie → Aventure, en dernier)**, H4b fini.
6. Les 3 nouvelles activités (Arena, MOBA 4v4, mode tactique 4v4).
7. Suite complète de tests (`python tools/run_tests.py -j 4`), puis rapport du matin au joueur (ne le faire que s'il le demande).

## Pièges connus
- Le dossier de travail est partagé entre agents : commits par index construit depuis HEAD par remplacements de texte (jamais `git apply --unidiff-zero`), `python tools/check_scripts.py` avant tout push, ne jamais tuer des processus Godot d'autres agents.
- Après l'ajout d'un `class_name`, il faut `--import` (le lanceur `Jouer.bat` le fait une fois par nouvelle version).
- Plusieurs agents à la fois saturent le processeur : certains tests de budget d'image (`test_ac_fight`) échouent alors sans bug réel.
- Limites d'usage : un agent coupé se relance par `SendMessage` avec la consigne de relire `git status` / `git diff` de son travail en cours.
