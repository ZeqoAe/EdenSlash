# R_P2 — passe P2 « performances » (version 0.1.186)

Outil réutilisable : `game/tools/perf_ui.tscn` (mesures headless chiffrées), test de protection : `game/tests/test_p2.tscn` (≈ 75 vérifications).
Mode d'emploi : `PERF_ARGS="--only=boot,data,save,lobby,pages,leaks,process,detail,run,slots,compile,soak --fat --loops=20 --soak=120 --prefetch --out=user://x.json"
EDEN_PROFILE=<fichier perso> Godot --headless --path game res://tools/perf_ui.tscn` (les options passent par l'environnement : le lobby prend tout argument `--`
pour un lancement de run). `--fat` = compte de fin de jeu (toutes les classes, 408 pièces au coffre, 1 810 pièces vues, 60 coffres ; sauvegarde de 135 Ko).
Méthode : « avant » = copie isolée du dépôt sans mes changements (scratchpad `p2/pb`), « après » = dépôt réel ; mêmes commandes, fenêtres calmes, le headless
ne mesure ni le GPU ni le rendu (scripts, nœuds, mise en page seulement). La machine était partagée avec 10 à 19 autres Godot : chaque chiffre est le meilleur
de 2 à 3 passages, les écarts de moins de 15 % sont du bruit.

## Ce qui a été mesuré, ce qui a été corrigé

| # | Constat (mesure) | Correction | Après |
|---|---|---|---|
| 1 | **Chaque case d'objet redessinée à chaque image** : `ItemSlot` garde son `_process` (le moteur le réactive à l'entrée dans l'arbre, `set_item` avant `add_child` n'y change rien) ; 192 cases vides ou pleines dans le lobby après avoir ouvert Héros / Carnet / Atelier, `TIME_PROCESS` de 16,6 ms par image au repos | `ItemSlot._ready` : `_process` seulement pour une pièce éveillée | 200 cases affichées : **3,6 à 7,3 ms -> 0,05 à 0,12 ms par image** ; 17 cases actives (éveillées) au lieu de 192-200 |
| 2 | **Fuite de matériaux** : `EdenModel._toon_cache` était clé par `get_instance_id()` du matériau du .glb ; le .glb se recharge à chaque héros (rien ne garde le PackedScene), donc chaque héros bâti (lobby à chaque fermeture d'écran, aperçu d'équipement, monstres qui réapparaissent) ajoutait ses ShaderMaterial sans jamais retrouver ceux d'avant | clé = chemin du sous-ressource (`res://….glb::StandardMaterial3D_xxx`, stable) | `_show_hero` x 60 : **+119 objets -> +1** ; 6 héros reconstruits : 0 entrée de plus. Run de 80 pas en pilote auto : cache de 19 à 30 matériaux avant, 17 à 19 après |
| 3 | **Gain d'or = rechargement de l'arme** : `Profile.add_gold` émet `changed`, `Player._on_profile_changed` détruisait et recréait le modèle d'arme + recalculait les stats à chaque monstre tué | le modèle n'est rechargé que si le code d'arme change (`Player._weapon_code`) | `Run.add_gold` **1,6 -> 0,2 ms** par kill (`Profile.changed.emit` 1,4 -> 0,2 ms) |
| 4 | **Armurerie** : `Completion.armory_ids()` (324 tirages de `SlotChests.pool`) ≈ 0,74 s au 1er appel, lancé en différé au chargement du lobby = un à-coup juste après l'affichage | cache disque `user://armory_cache.json` (clé = version + taille du catalogue + empreinte de `slot_chests` / `epochs` / `trophies` / `game_data` / `dev_edits`) ; sans cache, calcul par tranches de 5 ms, une par image (`Completion.warm_armory`), un appel direct termine le travail | **740 ms -> 8-9 ms** (cache), à froid l'à-coup disparaît (tranches) ; même catalogue, vérifié contre l'ancien algorithme (1 811 pièces) |
| 5 | **Lobby, 1re ouverture** : la map du titre est générée sans mini-carte, le lobby la demande avec ; l'ancien code la **régénérait** (≈ 1 s) au lieu de la compléter | `ProcMap.ensure_minimap()` dessine la mini-carte de la map en cache | ≈ 1 s de génération en moins quand la zone du lobby est celle du survol (test : même objet `ProcMap`) |
| 6 | **Chargement à froid** : lobby 2,6 s (0,7 s de scène/scripts + 1,85 s de `_ready`), `world.tscn` 0,6 s au clic sur Lancer | `ResourceLoader.load_threaded_request` : le titre précharge le lobby, le lobby (2 s après son affichage) la scène de run | lobby : **2,6 -> 1,85 s** bloquants ; Lancer : chargement de la scène **606 -> 0 ms** |
| 7 | **Index de collection** : `Profile.collected` / `outfit_unlocked` faisaient `x in tableau` (parcours complet) pour chaque entrée du catalogue (6 834) : Roulette, Collection, coffres d'apparence | index `Dictionary` reconstruit si le tableau change de taille ou d'identité | 6 834 entrées contre 3 000 trésors : **14-22 ms** (avant : un parcours de 3 000 par entrée) |
| 8 | **Pages reconstruites à chaque ouverture** (Registre : 60 fiches, Succès : 40 cartes) | `ScrollPage.unchanged(signature)` / `built()` : rouvrir sans changement ne reconstruit rien (garde aussi le défilement) | Registre, compte de fin de jeu : 2e ouverture **234 -> 14 ms** ; `refresh()` 164 -> 2 ms |
| 9 | **Collection** : l'avancement de chaque catégorie calculé 3 fois par rafraîchissement | mémo par `refresh()` (`_cat_rate`) | `_build_tree` 19 -> 6 ms ; `refresh()` 67 -> 54 ms (compte vide), 79 -> 51 ms (gonflé) |
| 10 | **Armurerie : tri de 1 811 pièces** avec un appel de fonction par comparaison | clés de tri calculées une fois à la construction (`k0`, `k1`) | compte de fin de jeu : 1re ouverture 573 -> 221 ms, 2e 162 -> 125 ms |
| 11 | **Paramètres** : 825 nœuds / ≈ 100 ms construits au démarrage du titre, du lobby et de la pause en run | `SettingsMenu` construit une page par image en arrière-plan, ou d'un coup à la première demande (`ensure_built`) | 0 nœud à la création, 6 pages en 10 images |

## Mesures de référence (tout est dans `perf_ui`)

- **Démarrage** : 3,9 à 4,5 s entre le lancement du moteur et `GameData._ready` (dont ≈ 3,4 s avant le premier autoload : les 9 autoloads et leurs `class_name` compilent
  presque tous les scripts ; recompiler les 140 scripts hors autoloads prend 4,0 s, `lobby.gd` 360 ms, `run_director` 190, `world` 160, `player` 143). Pas de gain
  trouvé à coût raisonnable : l'export est déjà en jetons binaires (`script_export_mode=2`), délier `Dev` du reste n'a rien changé de mesurable. `GameData._ready` : 225-285 ms
  (catalogue JSON 110-135 ms, `NamesFr.apply` 43-55 ms, `names_fr.json` 16-18 ms, index 18-35 ms). `Profile._ready` : 7 ms.
- **Pages** (compte moyen, headless, hors rendu) : toutes les pages du lobby / Carnet / Atelier / Héros / Registre / Armurerie / Paramètres s'ouvrent en 10 à 70 ms
  (13,8 ms = le plancher de 2 images du headless), sauf 1re ouverture de Collection (200 ms, 120 cases) et Roulette (180-220 ms, une fois par jour : 9 tirages de look).
- **Fuites** : 20 ouvertures / fermetures de chaque page (Carnet 6 onglets, Atelier 3, Coffres 2, Héros 4, 5 menus du lobby) : **0 nœud, 0 orphelin, 0 ressource** gardés.
  Seule fuite trouvée : les ShaderMaterial du n° 2 (+2 objets par ouverture / fermeture d'écran, via `_show_hero`).
- **Sauvegarde** : 0,6-0,8 ms pour 4 Ko (compte neuf), 5,4-6 ms pour 135 Ko (fin de jeu) ; `save_profile` n'est PAS appelé à chaque ramassage (seulement début / fin de run, équipement,
  achat, forge, coffre, roulette, tutoriel) ; le ramassage d'or émet seulement `changed` (voir n° 3). Rien à changer.
- **`_process` du lobby** : seuls restent actifs `SettingsMenu` (une comparaison par image), la boucle de l'horloge et les cases éveillées ; image au repos 0,3 ms de script.

## Mesure finale (avant -> après, ms, même profil)

Compte de fin de jeu (`--fat`, 408 pièces au coffre, 1 810 vues), ms par ouverture :

| Page | Avant | Après |
|---|---|---|
| Héros > Équipement, 1re / 2e ouverture | 267 / 159 | 163 / 65 |
| Héros > Classe, 1re | 289 | 103 |
| Carnet > Succès, 2e | 48 | 13,6 (plancher du headless) |
| Carnet > Collection, 1re / 2e | 256 / 92 | 178 / 57 |
| Carnet > Registre, 1re / 2e | 318 / 234 | 269 / 13,5 |
| Atelier > Armurerie, 1re / 2e | 573 / 162 | 221 / 125 |
| Atelier > Forge, 1re / 2e | 122 / 160 | 78 / 84 |
| 20 ouvertures-fermetures du Registre (moyenne) | 296 | 36 |

Compte neuf : ouverture du lobby 2,6 -> 1,85 s bloquantes (préchargement), ouverture d'une run 2,2 -> 1,5 s (scène préchargée), idle des cases 3,6-7,3 -> 0,05-0,12 ms.

## Sauvegardes atomiques (demande du coordinateur, `R_P4.md` §8)

`core/safe_file.gd` (`SafeFile`) : `write` écrit `fichier.tmp`, le relit (identique + JSON valide, ou `ConfigFile` valide pour `settings.cfg`), copie l'ancien fichier **sain** en `.bak`,
puis remplace ; `read` essaie le fichier, puis `.tmp` (coupure entre l'écriture et le renommage : aucune alerte), puis `.bak` (alerte). Un repli est noté dans `SafeFile.notices` et le lobby
affiche une fois « Ta sauvegarde était abîmée… » (boîte « Compris »). Branché sur : `Profile` (profil des 3 emplacements, résumé du titre `slot_summary`, `slot_exists` voit un `.bak`,
`delete_slot` / `new_game` effacent les copies), `last_slot.txt`, `Settings` (`settings.cfg`), `RivalBuilds`, `SpellPresets`, `DevEdits` (leurs fichiers user://). Exclus : journal de run
(`journal.jsonl`, ajout en fin de fichier), rapports de notes, cache d'armurerie (se recalcule). Coût : `save_profile` 0,7 -> 2,6 ms (4 Ko) et 6 -> 16 ms (135 Ko), sans appel de plus.
Compatibilité : une sauvegarde sans `.bak` se lit comme avant (`test_p4_migration` vert, 38 contrôles ; les 5 vrais profils non touchés, lecture seule). Tests : `test_p2` (écriture, `.bak`,
fichier tronqué -> copie saine, `.tmp` seul, tout abîmé -> partie neuve, profil tronqué rechargé à 4242, réglages relus depuis `.bak`).

## Suite complète de `game/tests` (headless, dépôt réel, après toutes les modifications)

Tout vert : build, cards, cc, controls, duel_modes, e2 à e6, farm, gear_run, guards, hud, ideas, items, journal, loot, lot7 à lot18, memory, ml_brain, modes, names_fr, nav, nav_entry,
**nav_screens (70)**, p1, **p2**, p4_flow, p4_migration, p4_activities (63), pages, progress, pvp, results, royale, skills, tooltips, tower, u3, workshop. `profil de test` (test_build, test_pages,
test_progress) échoue seulement parce que mon lanceur isole le profil avec `EDEN_PROFILE`. Échecs : **test_siege (3)** — « dernier debout », « coffre d'apparence légendaire », « moteur remis à zéro »,
identiques sur la copie sans mes changements (pas de ma faute, à regarder par l'auteur du Siège). Outils de capture qui n'ont pas de mode headless (attendent le rendu, même résultat avant) :
aura, backs, fx, outfit, combo, jump, items. `test_p4_activities` demande ≈ 7 min.

## Non fait, à savoir

- Les 3,4 s de compilation avant le premier autoload (voir plus haut) ; piste : réduire les références typées entre autoloads et gros scripts UI (`Dev` -> `DevScreen`),
  mais l'export binaire change déjà la donne et le gain réel ne s'obtient qu'avec un build exporté.
- `l210_ec2bc2.glb` (une tenue) affiche « invalid UID … using text path instead » à chaque chargement (≈ 330 fois par passe) : le .glb garde un UID de texture périmé ;
  à réimporter par la session locale (`--import` après avoir touché l'asset). Coût : une impression et un chargement par chemin à chaque héros qui la porte.
- Armurerie à 1 811 pièces : 2e ouverture 140 ms avec un compte de fin de jeu (reconstruction de la liste entière à chaque ouverture) ; une signature comme celle du Registre
  y gagnerait, mais la liste dépend de l'argent, des filtres et de la taille de la fenêtre : laissé tel quel.
- `Profile.save_profile` écrit tout le profil (135 Ko en fin de jeu) : acceptable à cette fréquence ; à surveiller si on sauve à chaque ramassage un jour.
- `Rewards.roll_look` refiltre tout le catalogue à chaque appel (9 appels par roue) : rewards.gd était réservé (E4/U9) ; gain possible ≈ 150 ms une fois par jour.
- Rendu GPU, cheveux / ombres / herbe : hors de portée du headless (`tests/bench_gfx.tscn` pour le rendu).

## Pièges

- `PERF_ARGS` et non des arguments : tout `--option` après `--` lance une run depuis le lobby.
- `tests/test_controls.gd` lisait `menu._pages` juste après la création : il passe maintenant par `page_count()` (les pages de Paramètres se construisent en arrière-plan).
- Le cache d'armurerie est invalidé par la version : un changement de `SlotChests.pool` sans changement de numéro est détecté par l'empreinte des sources (dans le jeu exporté,
  où les .gd n'existent plus, seule la version compte, ce qui suffit : un export ne change pas).
