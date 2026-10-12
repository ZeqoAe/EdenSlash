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

Au lancement, **écran titre** : les maps des zones défilent en fond (survol 3D) ; **Jouer** propose
*Continuer*, *Charger une partie* ou *Nouvelle partie* sur **3 emplacements de sauvegarde**
(l'emplacement 1 reprend l'ancienne sauvegarde), puis Paramètres et Quitter.
**Menu principal** : le héros posé dans la map de la zone choisie ; menu à icônes à gauche, une
fonction = un seul endroit : **Jouer** (*Lancer une run* en un clic, résumé du héros, zone de farm),
**Héros** (un seul écran : Équipement, Talents, Apparence — tenue, tête, dos, auras, arme —,
Grimoire, Classe, et « ? » pour le guide des statistiques), **Collection** (l'archive seule),
**Paramètres**, **Quitter** ; badge de la classe en haut à droite ; zone et prochaine récompense
(expertise) en bas. En run, le menu pause suit la même structure : Run, Héros, Aide.
Icônes de menu : `tools/make_menu_icons.py` ; trophées : `tools/make_trophy_icons.py`.

**Trophées** : tout le monde commence avec un trophée de départ (Éveil) ; les autres tombent des
élites et des boss. Un trophée n'a plus de stats fixes mais un **buff sous condition** inspiré de
son texte d'Eden (ex. « 5 % de chances à l'impact : +30 % d'Agilité pendant 8 s », Agi + Int,
critique et dégâts critiques, double frappe, vitesse d'attaque sur un critique, carapace quand
on est touché, orage, givre…) ; la rareté règle la chance et la force du buff
(`scripts/core/trophies.gd`, familles écrites par `tools/rework_trophies.py`). Les familiers,
objets de test et bonus de sorts d'autres classes glissés parmi les trophées ne tombent plus
(ils restent dans l'archive).

**Graphismes** (Paramètres → Affichage → *Qualité graphique* : basse, moyenne, haute, ultra) :
herbe 3D animée par le vent et couchée par le héros (`GrassField`), sol sans motif répété avec
relief et variations de teinte, éclairage stylisé des personnages et du décor (ombres douces et
teintées, contour lumineux), occlusion ambiante, ombres douces, lueur des effets d'attaque qui se
fondent au contact du sol (`shaders/eden_fx.gdshader`). Banc de comparaison :
`res://tests/bench_gfx.tscn -- <zone> [effet]` (captures `user://shots/gfx_<zone>*.png`, à lancer
avec `--rendering-driver vulkan`).

**Progression** (`scripts/core/progression.gd`) : on commence **Guerrier** ; chaque autre classe se
débloque par une **mission** sur l'ensemble des runs (Samouraï : 250 monstres, Clerc : soigner
4000 PV, Magicien : un coup de 800 dégâts, Voleur : 40 esquives, Chasseur : 15 élites). Une classe
n'a que **4 sorts au départ** ; la **maîtrise** (expertise) de la classe débloque les suivants, des
points de talent et ses certificats (*parcours de maîtrise* dans la page Expertise).
**Certificats** : plateau de 7 emplacements en **1-2-1-2-1** (`scripts/core/cert_board.gd`) ;
couleurs orange (puissance), jaune (vigueur), bleu (précision) : deux de même couleur reliés,
triangle de 3 couleurs (*Prisme*) ou losange de 4 de même couleur donnent des bonus.

Écrans plein écran (style du grimoire) :
- **Lancer la run** : page **Équipement** (préréglage ou à la main ; l'arme portée décide du combo
  d'auto-attaque, plus de choix d'arme au lobby) → *Valider* → page **Expertise & talents** (talents
  de classe, **7 certificats de maîtrise** au plus) → *Valider* → la run démarre.
- **Équipement** (lobby, et menu pause pendant la run) : chaque classe a son propre
  équipement en **3 préréglages** nommés ; le **coffre est commun** à toutes les classes (★ = objet
  utilisé par un préréglage) ; 10 emplacements dont **collier, bague et trophée** ; glisser-déposer,
  double-clic ou clic droit pour équiper / retirer ; aperçu 3D du héros, statistiques, bonus de set.
- **Carte d'objet au survol** partout (coffre, sac, poupée, village, archive) : stats et bonus de
  qualité, affixes, amélioration, gemmes, enchantement, set et ses effets, comparaison avec la pièce
  portée.
- **Raretés d'Eden** : commun (blanc), spécial (vert), rare (bleu), épique (violet), **mythique
  (orange)** et **légendaire (or)**. Du commun à l'épique, tout tombe partout, avec un jet aléatoire
  des stats et de la qualité ; mythique (qualité toujours 100 %) et légendaire (101 à 120 %) ne
  tombent que des **boss** (un garanti par boss) ou se **fabriquent** chez le forgeron (mythiques).
  Les armes mythiques et légendaires portent leur **passif d'Eden**, les pièces de set leurs vrais
  **effets de set** (2, 3, 4… pièces).
- **Niveaux d'Eden** : un objet affiche son niveau d'Eden (le set 23 est niveau 23) et chaque
  zone donne les objets de sa tranche d'Eden, dans l'ordre chronologique (Limestone 1-13,
  Rainbowfall 14-23, Beluga 24-28, Wetlands 29-36, Avila 37-44, Arid 45-48, Delphi 49-51,
  Blackflame 52-100) ; sa puissance suit le niveau de run où il est tombé.
- **Archive des trésors** (lobby, comme dans Eden) : les 10 554 entrées de l'archive d'Eden dans
  ses catégories — apparences (tête, dos, corps, armes), armes et boucliers, armures, bijoux,
  capes, trophées, objets spéciaux (montures, familiers, boîte arcanique, autres objets) — avec
  taux, recherche, « obtenus uniquement » et trésors du jeu / de la boutique. Archiver un
  équipement mythique ou légendaire du coffre donne +1 / +2 points d'attribut et des paliers ;
  les autres entrées (**trésors de collection**) tombent des boss. La Collection n'a plus
  d'onglets : tenues, chapeaux et masques, ailes et dos, **auras** (une pierre étoilée et une
  pierre de lune portées, effet lumineux d'Eden autour du héros et bonus en run) et apparences
  d'armes se choisissent dans **Héros > Apparence**.
- **Aide** (« ? » de l'écran Héros, page Aide du menu pause) : ce que rapporte un point de chaque
  attribut, formules de chaque statistique, calcul des dégâts et de la défense, et en run tes valeurs.
- **Menu pause** : pages Run (compétences, cartes, sac, bilan, actions), Héros et Aide.
- **Mode dev** (Paramètres > Caméra & interface > *Mode dev*, puis **F10** ou le bouton du menu) :
  écran à part, invisible si l'option n'est pas cochée. **Objets** : tout le catalogue (équipements,
  trésors, cosmétiques) avec les filtres (catégorie, type d'armure, rareté, niveaux, sets, archive,
  tri, par pièce ou **par set et niveau**), ajout ×1 / ×5 au coffre ou au sac avec la rareté et le
  niveau de puissance choisis ; **Ressources** (or, matériaux, fournitures, en run ou au départ des
  runs) ; **Progression** (maîtrise, classes, zones, tenues, trésors — avec confirmation) ; **Run**
  (niveau, invincible, soins, tuer les monstres, faire apparaître élite / boss / coffre, rage, donjon).
- **Village**, un PNJ par métier : Alec (acheter, vendre), Bryson le forgeron (améliorer, enchanter,
  réforger une stat, polir la qualité), Starnoc le recycleur (désassembler, convertir les matériaux),
  Lertia la joaillière (percer et sertir, fusionner 3 gemmes en une gemme supérieure).

### Tester et faire des retours

| Touche | Rôle |
|---|---|
| F1 | aide en jeu |
| **F9** | **signaler un problème** : capture + position + état + ta note, enregistrés dans `feedback/` |
| F4 | se débloquer |
| F2 | infos de débogage (position, FPS, état) |
| F5 / F6 / F7 / F8 | +1 niveau / aller à l'entrée du donjon / arène du boss / déclencher la rage |
| F10 | écran du mode dev (si activé dans les Paramètres) |

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
| `build_classes.py` | les 60 classes : 6 réglées à la main + `auto_classes.py` / `auto_spells.py` (conversion automatique des sorts d'Eden, noms français dans `eden_fr.py`), corps animé commun, tenues et cheveux, armes, effets |
| `build_talents.py` | arbres de talents et certificats de toutes les classes |
| `build_items.py` | catalogue d'Eden (`data/eden_catalog.json`) : 5 947 équipements (raretés, stats relatives, 326 sets et leurs effets, passifs d'armes et effets des trophées), toute l'archive d'Eden (`c_collection`, objets de `c_item` et `c_itemmall`), 242 auras (effets convertis par `fx2godot.py`), 652 apparences d'armes, icônes et modèles |
| `build_cosmetics.py` | cosmétiques d'Eden (table `[TableLoli]` de `4pequip.ini`) → tenues, accessoires de tête, ailes et dos (`assets/player/outfits/`) |

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
`--class=warrior|thief|hunter|cleric|magician|samurai`, `--zone=limestone|rainbowfall|beluga|wetlands|avila|arid`.
Classes : `.venv/Scripts/python -I tools/build_classes.py` ; biomes : `.venv/Scripts/python -I tools/build_biomes.py`
(aperçu d'une map d'Eden : `tools/scan_biome.py s004`).
Talents d'Eden : `.venv/Scripts/python -I tools/build_talents.py` (après build_classes) ; bancs : `res://tests/test_skills.tscn -- <classe>` (tous les sorts), `res://tests/test_combo.tscn -- <classe> 0.3,0.7` (combo + captures), `--expertise=N --talents` (écran d'expertise), `--prep=0|1` (préparation de la run), `--archive=0|1`, `--info` (écrans du lobby).
`--weapon=katana|axe|dagger|bow|scepter|staff`, `--extract-at=N` (lance l'extraction à N s).
Cycle héritage / remboursement : `Godot --headless --path game res://tests/test_progress.tscn`.
Choix de cartes (sélection puis Valider) : `Godot --headless --path game res://tests/test_cards.tscn`.
Paramètres et modes de jeu : `Godot --headless --path game res://tests/test_controls.tscn`.
Combo, procs, sets, cartes de build et plafond de niveau : `Godot --headless --path game res://tests/test_build.tscn`.
Interface (buffs / debuffs, objectifs, HUD sous les menus) : `Godot --headless --path game res://tests/test_hud.tscn`.
Préréglages, menu pause et village : `Godot --headless --path game res://tests/test_pages.tscn`.
Les lancements de test (arguments après `--`, scènes `res://tests`) utilisent `user://profile_test.json`,
jamais le profil du joueur.
Saut et esquive mesurés : `Godot --path game res://tests/test_jump.tscn`.
Effets d'Eden : `Godot --path game res://tests/test_fx.tscn -- s36041` (images dans `user://shots`) ;
`.venv/Scripts/python -I tools/fx2godot.py <effets>` pour en convertir d'autres. Test des objets : `Godot --headless --path game res://tests/test_items.tscn`.

Les données brutes extraites (`extracted/`, `index.csv`) ne sont pas versionnées.
