# R_P4 — QA d'intégration (nuit du 15/10, version 0.1.185)

Méthode : le dossier de travail est partagé par une dizaine de sessions et bouge en permanence (un fichier d'un autre lot qui ne compile pas
pendant quelques minutes fait échouer toute la suite). Les mesures ont donc été faites sur **des copies de `game/`** (`scratchpad/snap`, `snap2`,
avec `config/custom_user_dir_name` à part : aucun test ne touche aux profils des autres sessions ni à ceux du joueur), les fichiers modifiés non
commités remis à leur version de `HEAD`. Dernier passage : `HEAD` = 0.1.182 (E6), puis contrôle sur 0.1.184 (P1, P5) + les fichiers de cette passe.

## 1. Import et compilation
`--import` : aucune erreur ni avertissement de script. Vérifications statiques ajoutées à la main (non gardées dans le dépôt) : tous les
`Classe.membre` et `Classe.fonction(args)` du projet existent avec le bon nombre d'arguments (0 écart), 35 JSON de `data/` valides,
tous les `res://` littéraux existent (2 faux positifs : outil `test_fx`, motif de `dev_cards`).

## 2. Tests (52 scènes `test_*.tscn` ; 6 sont des outils de capture, voir plus bas)
| Test | Résultat | Test | Résultat |
|---|---|---|---|
| build, cards, cc, controls, duel_modes | vert | lot7 à lot12, lot13, lot13b, lot14, lot14b | vert |
| e2, e3, e4, e5, e6 | vert | lot15, lot16, lot17, lot18 | vert (lot17 : voir bug 3) |
| farm, gear_run, guards, hud, ideas, items | vert | memory, ml_brain, modes, names_fr | vert |
| journal | vert (voir bug 2) | nav, nav_entry, **nav_screens (manette, 67 contrôles)** | vert |
| loot, results, tooltips, tower, u3, workshop | vert | pages, progress, pvp, royale (105 s), siege (156 s), skills | vert |
| **p4_flow, p4_migration, p4_activities** (nouveaux) | vert | outils : aura, backs, combo, fx, jump, outfit | non exécutables en headless (attendent le rendu), exclus |

Premier passage (HEAD 0.1.180 + arbre en mouvement) : tout vert sauf `test_journal` (plantage à la sortie, voir bug 2), `test_lot17` (1 échec sous
charge) et, tant que `run.gd` ne compilait pas, tout (bug 1). Deuxième passage (HEAD 0.1.182) : 0 échec. `test_p1` / `test_p2` (autres sessions,
non commités, écrits contre du code non commité) ne passent pas sur `HEAD` : à relancer par leurs auteurs.

## 3. Parcours de bout en bout
`test_p4_flow` (sans changement de scène, 41 contrôles) : compte neuf (8 pièces, rien d'ouvert à tort, 60 classes au Registre) -> Survie (coffre
d'emplacement, mort, insignes = participation, équipement du hub restauré, or et clés à zéro, pièce à découvrir) -> Armurerie (achat au prix exact,
pièce possédée) -> Forge (+N, emplacement percé, gemme sertie, enchantement) -> Fabrication (sans plan = erreur lisible, avec plan = pièce de
l'archétype) -> Coffres (aperçu, ouverture) -> Roulette (2 lancers) -> Registre / « Équiper le meilleur » (idempotent, annulable) -> 2e Survie sur
l'équipement amélioré (copie jetée, hub intact) -> sauvegarde puis rechargement à l'identique.

`test_p4_activities` : le pilote vit dans la racine, lance chaque activité par la **vraie fonction du lobby** (`_start_*`, y compris la file
d'attente du Duel : accepter, verrouiller, récapitulatif), passe la scène du jeu, joue en pilote automatique, termine comme un joueur
(mort, victoire de manches, abandon), attend le bilan, presse « Rejouer » (partie relancée propre, puis refinie) et « Retour au lobby », puis vérifie
que `Run / Duel / Tour / Royale / pause` sont remis à zéro. Résultats (secondes, machine chargée) : Survie+Rejouer 25, Survie gagnée par 3 portails
22 (époque I gagnée -> Tour et Forge s'ouvrent), Entraînement 14, Tour+Rejouer 20, Donjon Normal+Rejouer 19 / Héroïque 10 / Mythique 10, Ruée+Rejouer 18,
Siège+Rejouer 18, Duel libre+Rejouer 44, Ligue 27, Panthéon 28, Gantelet 18, Arènes 2v2+Rejouer 34 / 3v3 19, Royale+Rejouer 19, Défi de maîtrise 14.
**16 activités sur 16 vertes.** Survie avec `--epoch=2/3/4 --hub=…` en ligne de commande : sans erreur ; Survie jusqu'au boss (`--boss-after`) : boss vaincu à 219 s.

## 4. Console
Dans tous les tests et parcours : aucun `SCRIPT ERROR`, aucune propriété nulle, aucun signal orphelin, aucune ressource manquante. Reste seulement :
- `WARNING … invalid UID uid://dhh8iip5ln3j` sur ≈ 6 modèles de tenue (`l210_…`, `l213_…`, `l237_…`, `l262_…`…) : le cache `.godot/imported` de cette machine
  garde l'ancien UID d'une texture (`lx01as01a__9d2446.png`) ; le moteur retombe sur le chemin, rien ne manque. Un réimport des `.glb` concernés
  (session locale) le supprime. Sans effet côté joueur.
- `WARNING: Navigation region synchronization had 2 edge error(s)` sur certaines graines de carte (génération de la navigation, déjà là avant).
- Fuites « à la sortie » du moteur (`RID … leaked`, `resources still in use`) : propres au mode sans rendu, présentes avant la nuit.
- `test_pages` : `Parameter "t" is null` (capture d'écran du rapport de note, moteur sans rendu) et `test_ideas` : `!is_inside_tree()` (héros de test
  hors de l'arbre pour les potions) : tests seulement, voulus.

## 5. Vieilles sauvegardes (`test_p4_migration`, 38 contrôles)
Formats reconstruits : génération 1 (inventory + equipped, stats figées, raretés 0-4, clés de sac « luck / protect », archive par type, coffre « trophée »,
collection en décimaux, interrupteur dev), génération 2 (coffre sans uid / qualité / affixes), sauvegarde d'avant le fil d'éveil (clés récentes retirées),
quasi vide, « null », classe inconnue + équipement fantôme. Vérifié : aucun objet perdu, objets au format actuel, clés renommées sans perte, coffres « set »,
Survie / Carnet / Coffres gardés ouverts pour un compte qui a joué, activités nouvelles non ouvertes à tort, une Survie démarre, réécriture -> rechargement à l'identique.
Avec `P4_REAL_SAVES` : les 5 vrais profils du dossier utilisateur (dont celui à 60 classes de maîtrise maximale) se chargent sans perte, lecture seule.
Les réglages (`settings.cfg`) ignorent déjà les clés manquantes ou de mauvais type ; aucune clé n'a été retirée cette nuit.

## 6. Manette
`test_nav_screens` complet : 67 / 67 écrans atteignables à la croix (lobby, Coffres, Roulette, Carnet et ses onglets dont Registre, Atelier, Héros,
Paramètres, accueil, Guide, pause, bilans des 5 modes, autel). Pas couverts par ce test : file d'attente du Duel, choix de carte en run, marchand (à ajouter).

## 7. Bugs trouvés
1. **`HEAD` ne compilait pas (0.1.179 à 0.1.181)** : `run.gd` (E4) avait un bloc `weapon_up` d'`apply_card` collé au mauvais endroit (« Expected statement, found Indent » ligne 828) et
   `trophy_procs` coupé en deux : tout le jeu échouait au chargement. Cause : écritures concurrentes de deux lots sur le même fichier. Corrigé par E6 dans 0.1.182 (je l'ai
   constaté sur la copie de `HEAD`). Non-régression : `test_p4_flow` / `test_p4_activities` (le jeu démarre, une Survie se joue) et la vérification d'import sans erreur.
2. **`test_journal` plantait à la sortie (signal 139)** : `RunJournal.context` gardait un rappel vers le nœud de test libéré. Test corrigé (le rappel est remis à zéro avant la fin) ;
   dans le jeu `context.is_valid()` protège déjà.
3. **`test_lot17` instable sous charge** : le coup qui achève le cerveau était donné une seule fois avant 60 images d'attente. Réessayé à chaque image jusqu'à 240 images.
4. **Erreur `Parent node is busy setting up children`** au lancement direct de la scène du jeu en ligne de commande (`world.tscn -- --autoplay…`, utilisé par toutes les mesures) :
   `ScreenFade.reveal` ajoutait son calque à la racine pendant qu'elle installait ses enfants (le fondu d'arrivée n'existait pas). Corrigé (ajout différé). Sans effet dans le jeu normal.

## 8. Restes et conseils
- **Sauvegarde non atomique** : `Profile.save_profile` écrit directement `profile.json` ; un fichier tronqué (coupure pendant l'écriture) est lu comme « pas de sauvegarde » et
  remplacé au prochain enregistrement. À durcir (écrire dans `profile.json.tmp`, renommer, garder `.bak`) : fichier partagé, pas touché cette nuit.
- `lobby.gd` : `Dev.is_open() if Dev.has_method("is_open")` est du code mort (Dev n'a pas `is_open`) ; inoffensif.
- Les tests des autres sessions écrits contre du code non commité (`test_p1`, `test_p2`) bloquent le lanceur s'ils ne compilent pas (la scène ne quitte jamais) : lancer avec un `timeout`.
- Lancer toute la suite : copier `game/` (≈ 20 s), restaurer les fichiers non commités depuis `HEAD`, ajouter `config/custom_user_dir_name` à `project.godot` de la copie, `--import`, puis un
  `timeout 600 Godot --headless --path . res://tests/<test>.tscn` par scène (≈ 12 min au total, `test_p4_activities` ≈ 7 min).
- Idée pour la suite : ajouter la file d'attente du Duel, le choix de carte et le marchand à `test_nav_screens`.
