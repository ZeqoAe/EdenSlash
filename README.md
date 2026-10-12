# Eden Slash

Hack and slash RPG (fan game, projet local) dans l'univers d'**Eden Eternal**, construit avec
**Godot 4.7** à partir des données du client Eden Reforged.

## Lancer le jeu

Double-clic sur **`Jouer.bat`** (ou `Editeur.bat` pour ouvrir le projet dans Godot).

### Contrôles

| Action | Touche |
|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches |
| Attaquer (sur un monstre : auto-attaque) | Clic gauche (maintenu) |
| Tourner / incliner la caméra | Clic droit maintenu |
| Compétences | A E R T ou 1 2 3 4 |
| Sauter (sauts multiples avec le passif) / esquive (invulnérable) | Espace / Maj |
| Frappe plongeante (avec le passif) | Clic gauche en l'air |
| Esquive aérienne / saut-esquive | Maj en l'air / Espace pendant l'esquive |
| Interagir (coffre, PNJ, donjon) | F |
| Carte / menu (stats, équipement, passifs) | M / Échap |
| Objectifs détaillés (repliés par défaut) | Tab |
| Zoom | Molette |

Tout se règle dans **Échap > Paramètres** (ou depuis le lobby) : modes de jeu (Classique, Visée au
curseur, Souris ARPG, RTS / MOBA, Détente), déplacement clavier / clic gauche / clic droit, visée,
attaque et compétences automatiques, touches, plein écran / fenêtré, résolution, VSync, FPS, son,
caméra, chiffres de dégâts. Les réglages sont dans `user://settings.cfg`.

Interface : orbe de vie et orbe d'expérience (niveau au centre), compétences avec recharge
circulaire, recharge de l'esquive, indicateur de combo, buffs (à gauche) et debuffs (à droite)
avec leur durée — ils clignotent pendant les 3 dernières secondes, survol = détail —, effets de la
cible sous sa barre de vie, mini-carte ronde, objectifs repliés (Tab pour les déplier, dépliés
quelques secondes à chaque découverte), bords rouges quand la vie est basse.
Polices Cinzel et Nunito (licence OFL, `game/assets/fonts/`). Les icônes d'effets sans équivalent
dans le dépôt sont dessinées par `tools/make_ui_assets.py` (`game/assets/ui/status/`) : une vraie
icône d'Eden déposée sous le même nom (`freeze.png`, `burn.png`…) les remplace automatiquement.

### Tester et faire des retours

| Touche | Rôle |
|---|---|
| F1 | aide en jeu |
| **F9** | **signaler un problème** : capture + position + état + ta note, enregistrés dans `feedback/` |
| F4 | se débloquer |
| F2 | infos de débogage (position, FPS, état) |
| F5 / F6 / F7 / F8 | +1 niveau / aller à l'entrée du donjon / arène du boss / déclencher la rage |

### Mode test automatique (captures)

```bash
Godot_v4.7.2-stable_win64_console.exe --path game -- --autoplay --start-level=8 --shots=5,15 --quit-at=16
```

Les captures arrivent dans `%APPDATA%/Godot/app_userdata/Eden Slash/shots/`.

## Une run (voir DESIGN.md)

- Map **générée à chaque run** dans la DA d'Eden (arbres, rochers, maisons, PNJ, coffres du jeu).
- **10 minutes** pour explorer, farmer, trouver le **village**, l'**entrée du donjon** et les **coffres**.
  Brouillard de guerre sur la carte, lieux découverts affichés.
- Au **village** : Alec (vendre), Bryson (améliorer +1 → +10), Abel (boutique : compétences,
  passifs, équipement rare) ; désassemblage en fragments / essences / cristaux.
- Après 10 minutes : **rage** (monstres plus forts, élites en masse, plus d'XP et de butin).
- Entrée du donjon découverte → **[F]** → arène du boss : zones rouges au sol (cercles, ligne,
  cône, projectiles, onde), invocations, fureur sous 50 % de PV.
- Compétences du Samouraï débloquées par **cartes** à chaque niveau (4 emplacements).
  Clic sur une carte (ou 1, 2, 3) pour la sélectionner, puis **Valider** (ou Entrée) pour confirmer.
- Équipement à **jets** (qualité 90-120 %, affixes en fourchette, paliers +4/+6/+8/+10),
  **pièces de set** (bonus à 2 / 4 / 6 pièces : foudre, gel, buffs temporaires…), butin plafonné
  au niveau 15 sur la map 1.
- **Combo d'auto-attaque** en 3 coups, le dernier en saut et en zone.
- **Cartes de build** à rareté : zone, portée, effets déclenchés (foudre, gel, brûlure, explosions,
  Écho…), évolutions légendaires, 1 relance par run.

## Pipeline d'assets (`tools/`)

| Script | Rôle |
|---|---|
| `edenpkg.py` | lit les archives `pkg.idx` / `pkg###.pkg` (zlib) du client |
| `edenini.py` | lit les tables `c_*.ini` (Big5) et `t_*.ini` (textes anglais) |
| `nif.py` | lecteur NIF Gamebryo générique piloté par `third_party/nif.xml` (niftools) |
| `nif2gltf.py` | NIF + KF → `.glb` (squelette, skin, B-splines, teinture des personnages) |
| `fsm2godot.py` | map Eden → Godot : terrain FSM (blocs, couches, ombres, eau, trous), décor + collisions, scènes NIF de donjon, points clés et camps de monstres |
| `build_assets.py` | génère monstres, textures et `game/data/*.json` pour les zones jouables (rosters lus dans les camps des maps) |
| `scan_orphans.py` | cherche dans les pkg les fichiers absents de l'index |
| `blender_preview.py` | rendu de contrôle d'un `.glb` avec Blender en ligne de commande |

```bash
python -m venv .venv && .venv/Scripts/python -m pip install numpy pillow
.venv/Scripts/python -I tools/fsm2godot.py s002
.venv/Scripts/python -I tools/fsm2godot.py s100
.venv/Scripts/python -I tools/build_assets.py
# maillage de navigation (chemins praticables) de chaque map
Godot_v4.7.2-stable_win64_console.exe --headless --path game --script tools/bake_navmesh.gd -- s002
```

Options de test : `--seed=N` (même map), `--dungeon` (arène du boss), `--rage`,
`--goto=village|dungeon`, `--boss-after=N` (le bot va au boss après N s), `--open=pause|cards|map|smith|trader`,
`--teleport=x,z`, `--cam-dist=N`, `--seals=N` (sceaux du donjon), `--start-level=N`, `--end-at=N` (fin de run → choix de l'héritage),
`--cards=static_blade:2,volatile` (cartes de build au départ), `--gear=storm` (panoplie d'un set : storm, frost, blood, falcon, phoenix, wind).
Cycle héritage / remboursement : `Godot --headless --path game res://tests/test_progress.tscn`.
Choix de cartes (sélection puis Valider) : `Godot --headless --path game res://tests/test_cards.tscn`.
Paramètres et modes de jeu : `Godot --headless --path game res://tests/test_controls.tscn`.
Combo, procs, sets, cartes de build et plafond de niveau : `Godot --headless --path game res://tests/test_build.tscn`.
Interface (buffs / debuffs, objectifs, HUD sous les menus) : `Godot --headless --path game res://tests/test_hud.tscn`.
Les lancements de test (arguments après `--`, scènes `res://tests`) utilisent `user://profile_test.json`,
jamais le profil du joueur.
Saut et esquive mesurés : `Godot --path game res://tests/test_jump.tscn`.
Effets d'Eden : `Godot --path game res://tests/test_fx.tscn -- s36041` (images dans `user://shots`) ;
`.venv/Scripts/python -I tools/fx2godot.py <effets>` pour en convertir d'autres. Test des objets : `Godot --headless --path game res://tests/test_items.tscn`.

Les données brutes extraites (`extracted/`, `index.csv`) ne sont pas versionnées.
