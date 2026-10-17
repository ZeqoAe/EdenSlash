# Jouer ensemble entre amis : étude et plan du multijoueur (lot NET-0, 17/10/2026)

Demande du joueur : envoyer le jeu à ses amis pour **tester ensemble**. Aujourd'hui il n'existe **aucun code réseau** (0 appel
`multiplayer`, `rpc`, `ENet` dans `game/scripts`) : tous les modes sont solo contre des IA, y compris les trois modes d'équipes en
cours (Colisée, Deux Voies, Assaut). Ce document pèse les architectures possibles, classe les modes, chiffre ce qui bloque dans le
code, propose un découpage en lots et un premier jalon, et dit comment distribuer le jeu aux amis sans risque. Un prototype
jetable prouve la liaison hôte / client avec les vrais héros du jeu : `R_NET0.md`.

## 0. Décision recommandée (résumé)

1. **Hôte autoritaire « listen server »** : un ami héberge (il joue ET simule la partie), les autres envoient leurs **entrées** et
   reçoivent des **instantanés** ; API multijoueur de haut niveau de Godot sur **ENet** (UDP), rien d'autre à installer.
   Pas de lockstep déterministe (338 tirages au hasard global dans 65 fichiers, physique Jolt non déterministe), pas de serveur
   dédié (coût, hébergement, maintenance) — le même code pourra tourner plus tard en hôte sans fenêtre si besoin.
2. **Le héros d'un ami, chez l'hôte, est un vrai `Player` piloté par un `BotInput`** (le point d'entrée déjà utilisé par l'arène
   d'IA) rempli par les paquets du réseau : la logique de combat n'est **pas** réécrite. Prouvé par le prototype.
3. **Connexion** : d'abord un réseau privé virtuel gratuit entre amis (Tailscale, ou ZeroTier / Radmin VPN) + « Rejoindre » par
   adresse, puis l'ouverture automatique du port (UPnP intégré à Godot) et un code d'invitation. Pas de Steam (impossible pour un
   projet de fan), pas de relais maison payant.
4. **Ordre des modes** : arène d'essai (jalon) → **co-op Survie à 2-4** (le cœur du jeu, celui que les amis comprennent) →
   Duel / Arènes entre amis → L'Échiquier (presque gratuit : actions au tour par tour) → Donjons / Tour → Battle royale avec
   humains → Survivant co-op → modes d'équipes 4 contre 4 (Colisée, Assaut, Deux Voies).
5. **Premier jalon (NET-A, 1 lot)** : deux instances (même PC, puis deux PC par Tailscale) où chacun voit l'autre héros bouger,
   attaquer et lancer ses sorts dans une arène vide, avec ping et débit affichés ; test automatique à deux processus.
6. **Distribution** : zip privé (≈ 1,1 Go) par lien de partage privé, jamais de lien public ni de « Release » GitHub ; contrôle de
   version à la connexion ; correctifs légers en `.pck` additionnel ; et **rendre le dépôt GitHub privé** (§ 7.5 : il contient déjà
   31 230 fichiers d'assets extraits du jeu d'origine, dont 2 150 modèles et la musique).

## 1. Point de départ (HEAD 0.1.303)

| Constat | Chiffre | Conséquence |
|---|---|---|
| Code réseau existant | 0 | tout est à faire, mais rien à défaire |
| Scripts du jeu (`game/scripts`) | 301 fichiers, 116 465 lignes | refonte impossible : on greffe le réseau aux bons endroits |
| Autoloads (singletons) | 10 : Settings, Gamepad, UiNav, UiFeel, GameData, **Profile**, **Run**, Dev, Feedback, Music | `Profile` et `Run` = « le » joueur |
| Variables statiques (`static var`) | 387 dans 108 fichiers (dont 274 dans 65 fichiers de `core/`) | état global des modes (Duel 28, Assault 23, Tower 17, TeamMatch 15, Royale 13…) : un seul combat à la fois, ce qui va bien à un hôte unique |
| Physique | Jolt, 60 images/s, `max_physics_steps_per_frame` 3 | non déterministe d'une machine à l'autre |
| Combat d'action | 60 classes, sorts, esquive, coups parfaits | sensible au retard (cible : < 120 ms entre l'appui et l'effet) |

Atouts déjà en place, découverts par l'audit :
- **`BotInput`** (`ml/bot_input.gd`, 20 lignes) : `Player` lit `move`, `aim`, `hold`, `pulse` à la place du clavier dès que
  `player.bot` est posé (`_read_move_input`, `_wants`, `_on_attack_pressed`) ; c'est exactement l'« entrée réseau ».
- **Héros autonome** : `Player.foe` + `use_build` + `kit_skills` font jouer un héros sur sa propre fiche, sans lire `Run` ni `Profile`
  (adversaire du Duel, arène d'IA) ; il manque seulement la même chose **dans le camp du joueur** (allié humain).
- **Alliés et camps** : groupe `heroes`, `Combatant.hostile_targets` / `ffa_foes`, `TeamMatch` (équipes, arènes, couleurs), réanimation
  du Battle royale (`RoyaleDirector._revive_player`) : la co-op et les équipes existent déjà contre l'IA.
- **Cartes à graine** : `ProcMap` tire presque tout dans son propre `RandomNumberGenerator` (55 appels sur `rng`, 3 tirages globaux
  seulement) : un client peut **regénérer la carte depuis la graine** au lieu de la recevoir.
- **L'Échiquier** est une machine d'états pure (`Autochess`, `RefCounted`, son propre `rng`, 0 tirage global, actions publiques
  `buy` / `sell` / `reroll` / `place` / `equip` / `choose`, stratèges interchangeables) : un humain distant = un stratège de plus.

## 2. Architecture

### 2.1 Transports disponibles dans Godot 4.7

| Transport | Pour | Contre | Verdict |
|---|---|---|---|
| **ENet** (`ENetMultiplayerPeer`, UDP) | intégré, canaux fiables / non fiables / ordonnés, statistiques (RTT, octets), compression ; marche avec l'API de haut niveau (`@rpc`) | UDP : il faut un port joignable (NAT) | **retenu** |
| WebSocket (`WebSocketMultiplayerPeer`, TCP) | passe partout (navigateur, proxys) | TCP : un paquet perdu bloque tous les suivants (saccades en combat) | non (seulement si un jour version navigateur) |
| WebRTC (`WebRTCMultiplayerPeer`) | pair à pair avec traversée de NAT (STUN / TURN) | sur PC il faut l'extension native webrtc + un serveur de signalisation + un serveur TURN pour les cas difficiles | non (trop de pièces pour 2-4 amis) |
| Steam (GodotSteam, Steam Networking Sockets) | relais, invitations, NAT résolu | exige que le jeu soit **publié sur Steam** (identifiant d'application) : impossible pour un projet de fan avec des assets d'Eden | exclu |

### 2.2 Topologies

| Topologie | Principe | Pour | Contre | Verdict |
|---|---|---|---|---|
| **Hôte autoritaire (listen server)** | un joueur héberge : il simule tout, les autres envoient leurs entrées et affichent ses instantanés | une seule simulation (aucune désynchronisation possible), triche limitée de fait, le code des modes tourne presque tel quel chez l'hôte | l'hôte a 0 ms de retard (avantage léger en JcJ) ; sa machine et son envoi portent la partie ; s'il part, la partie s'arrête | **retenu** |
| Serveur dédié | un processus sans fenêtre héberge, tout le monde est client | équitable, partie qui survit aux départs | il faut une machine allumée et joignable (VPS ≈ 5 €/mois), des mises à jour serveur, de la surveillance | plus tard, éventuellement : le même code en `--headless` |
| Lockstep déterministe | chacun simule tout, seules les entrées circulent | très peu de débit, idéal pour des centaines d'unités | **exige une simulation bit à bit identique** : 338 tirages au hasard global (65 fichiers), physique Jolt, flottants, `Time.get_ticks` lu par 42 fichiers, IA à temps réel ; une seule divergence = parties différentes | exclu pour l'action ; envisageable pour L'Échiquier seul (déjà déterministe hors combat) |
| Relais (serveur qui ne fait que transmettre) | contourne le NAT | aucun port à ouvrir | il faut l'héberger, ajoute du retard | remplacé par un réseau privé virtuel gratuit (§ 2.4) |

### 2.3 Le modèle retenu en détail

- **Montée** (client → hôte), 30 paquets / s, **28 octets** mesurés : numéro, déplacement (2 demi-flottants), point visé, attaque
  maintenue, et un **compteur par touche** (sorts, esquive, saut, échange d'arme) : un paquet perdu ne perd pas l'appui.
- **Descente** (hôte → clients), 20 à 30 instantanés / s, **34 octets par héros** (position, cap, animation et sa position, vitesse,
  PV, dernier numéro d'entrée appliqué) + événements fiables (apparitions, noms d'animation, effets, sons, chiffres de dégâts).
- **Affichage du client** : interpolation à 100 ms dans le passé (3 instantanés d'avance) ; **prédiction de son propre héros**
  (déplacement et esquive joués tout de suite, corrigés par l'hôte) à ajouter en NET-C : sans elle, le retard ressenti est
  RTT + 33 ms + 100 ms (mesuré : 133-150 ms en local, **≈ 280 ms avec 150 ms d'aller-retour**), trop mou pour un jeu d'action.
- **JcJ** : l'hôte peut compenser le retard des clients (rembobiner les positions de 100-150 ms au moment d'un coup) ; entre amis,
  à faire seulement si le Duel paraît injuste.
- **Débit mesuré** (prototype, héros seuls) : 2,7 Ko/s par client ; hôte 2,7 Ko/s (2 joueurs), 14 Ko/s (4), 32 Ko/s (8).
  Estimation avec les monstres de la Survie (≈ 16 octets par monstre quantifié, 150 monstres proches, 20 / s, tri par distance) :
  ≈ 50 Ko/s par client, **≈ 150 Ko/s (1,2 Mbit/s) d'envoi chez l'hôte à 4 joueurs** : bon en fibre, juste sur un vieil ADSL
  (envoi ≈ 1 Mbit/s) ; leviers : 15 instantanés / s pour les monstres, différences seulement, distance de pertinence.
- **Compression ENet** : − 4 à − 15 % sur ces petits paquets (mesuré) : inutile tant que les instantanés sont compacts.

### 2.4 NAT : comment un ami joint l'hôte

| Solution | Pour | Contre | Recommandation |
|---|---|---|---|
| **Tailscale** (réseau privé virtuel, gratuit pour un usage personnel) | 5 minutes d'installation, aucune box à régler, adresse fixe 100.x.y.z, chiffré, marche derrière presque tous les NAT (relais automatiques sinon) | un compte par personne (Google / Microsoft…), l'hôte partage sa machine avec ses amis ; conditions du plan gratuit à revérifier | **étape 1** (guide § 7.4) |
| ZeroTier, Radmin VPN | même principe (Radmin : pensé pour le jeu en « LAN », Windows) | idem ; plafonds gratuits à revérifier | alternatives si Tailscale déplaît |
| **UPnP** (classe `UPNP` de Godot : découverte de la box, ouverture du port UDP) | rien à installer, automatique | ~70-80 % des box le permettent (non vérifié), échoue derrière double NAT / 4G / CGNAT | **étape 2** : tentée d'office par « Héberger », message clair si échec |
| Redirection de port à la main | universelle | technique pour des non-techniciens | dernier recours, guide pas à pas |
| playit.gg (tunnel UDP gratuit) | l'hôte n'ouvre rien | programme tiers sur la machine de l'hôte, retard ajouté par le tunnel, conditions à revérifier | possible, non prioritaire |
| Steam Networking | NAT résolu | exclu (§ 2.1) | — |

Pare-feu Windows : la 1re fois qu'il héberge, l'hôte voit « Autoriser l'accès » pour EdenSlash.exe : cocher **Réseaux privés**
(et publics si la box est classée publique). Port proposé : **UDP 24680** (réglable).

### 2.5 Nombre de joueurs

2 à 4 d'abord (co-op, Duel, Arènes) ; 8 héros mesurés sans difficulté côté réseau (221 octets par instantané, 32 Ko/s chez l'hôte) :
le 4 contre 4 et un Battle royale à quelques humains sont réalistes ensuite. Au-delà, c'est la simulation de l'hôte (monstres, IA)
qui limite, pas le réseau.

## 3. Les modes : lesquels, dans quel ordre

Note d'intérêt entre amis (★ à ★★★) et difficulté d'adaptation (taille en lots, après le socle NET-A à NET-D).

| Mode | Intérêt entre amis | Forme | Difficulté | Ce qui coince | Ordre |
|---|---|---|---|---|---|
| **Survie (Aventure)** | ★★★ cœur du jeu, co-op évidente | 2-4 en co-op | **3 lots** (NET-E) | `Run` = un seul joueur (60 variables : cartes, passifs, or, trophées) ; choix de cartes qui **met le jeu en pause** (55 `paused =` dans 23 fichiers) ; monstres et boss à rééchelonner selon le nombre ; qui ramasse quoi ; mort / réanimation ; sauvegarde de chaque ami | **1** |
| **Duel / Arènes 2v2 / 3v3 / Gantelet** | ★★★ « qui est le meilleur » | 1 contre 1 ou équipes humains + IA | 1 lot (NET-H) | 28 statiques de `Duel` (un seul combat : va bien à un hôte) ; `PvpCaps` global (un match à la fois : va bien) ; `hit_stop` à couper ; avantage de l'hôte (0 ms) | **2** |
| **L'Échiquier** | ★★★ très bon entre amis, tolère le retard | 2 à 8 humains + IA | 1-2 lots (NET-J), dépend seulement de NET-A | presque rien : actions au tour par tour ; l'hôte joue la partie, les clients envoient leurs actions et regardent le combat de leur plateau (diffusé comme des héros) ; écran `AutochessScreen` à lier à un stratège réseau | **3** (peut passer avant le Duel : indépendant du socle de combat) |
| **Donjons / Tour / Ruée / Siège** | ★★ co-op contre les boss | 2-4 en co-op | 1-2 lots (NET-F) après la Survie | mêmes points que la Survie (moteur de salles de la Tour), `Tower` 17 statiques, alliés IA à remplacer par des humains, butin par joueur ; le Siège est en chacun pour soi | 4 |
| **Battle royale** | ★★ quelques humains parmi les IA | 2-4 humains + IA | 2 lots (NET-I) | carte immense (pertinence par distance indispensable), largage (`royale_drop`), butin au sol, fiche de chacun (`RoyaleLoot`), `Royale` 13 statiques, 67 lectures de `Royale.active` | 5 |
| **Survivant** | ★★ co-op contre la horde | 2-4 en co-op | 1-2 lots (NET-G) | horde de centaines de monstres : débit (10-15 instantanés / s, positions quantifiées) ; cartes et armes par joueur (`Survivor` 10 statiques) ; scellé, donc aucune sauvegarde de compte à gérer | 6 |
| **Colisée** (6 × 3) | ★★ | équipes mêlant humains et IA | 1 lot (NET-K1) après le Duel | arènes simultanées déjà gérées par `TeamMatch` ; `PvpCaps.elapsed` global (une manche à la fois : va bien) | 7 |
| **L'Assaut** (4 contre 4) | ★★★ quand on est 4+ | 4 contre 4 | 1-2 lots (NET-K2) | **brouillard d'équipe** (`AssaultVision`) : l'hôte ne doit envoyer à un client que ce que son équipe voit (sinon triche « à travers les murs », secondaire entre amis), bombe, manches | 8 |
| **Les Deux Voies** (MOBA 4 contre 4) | ★★★ quand on est 8 | 4 contre 4 | 2 lots (NET-K3) | sbires, tours, jungle : beaucoup d'unités (débit), parties longues (départ de l'hôte = fin) | 9 |

Recommandation : viser **la co-op Survie à 2-4** comme premier mode vraiment jouable (c'est ce que les amis attendent d'un jeu
« à la Megabonk »), avec le **Duel entre amis** et **L'Échiquier** en parallèle ou juste après, parce qu'ils réutilisent le socle sans
le problème des monstres.

## 4. Audit du code : ce qui bloque (comptes à HEAD 0.1.303, `game/scripts`, hors tests et outils)

| Point | Comptage | Pourquoi ça bloque | Lot |
|---|---|---|---|
| **`Profile`** (autoload) | 1 637 lectures dans 135 fichiers ; 68 variables ; `save_profile()` appelé 133 fois dans 49 fichiers | le compte **du joueur local** ; un ami a le sien : chez l'hôte, ses lectures doivent passer par sa fiche ; chacun n'écrit **que sa** sauvegarde | NET-B, NET-E |
| **`Run`** (autoload) | 866 lectures dans 88 fichiers ; 60 variables + 4 statiques | la partie d'**un** joueur (sorts, cartes, passifs, or, trophées, niveau) ; en co-op il en faut une par joueur | NET-E |
| **`Player`** = le joueur | `player.gd` 2 596 lignes : 67 branches `foe` / non-`foe`, 22 lectures de `Profile`, 35 de `Run`, 19 de `Settings`, 11 de `Input` ; ailleurs 207 `.player` dans 23 fichiers (`royale_director` 65, `survivor_director` 27, `siege_director` 23…), groupe `"player"` 23 fois / 17 fichiers, `get_first_node_in_group("player")` 15 fois / 12 fichiers (`Monster` le prend comme cible par défaut) | « non-`foe` » veut dire « le joueur local » ; il faut un 3e cas : **héros allié distant** (fiche à lui, aucune lecture globale) ; les directeurs supposent un seul héros humain | NET-B (héros), NET-E (directeurs) |
| **Entrées** | `Input.` 66 / 20 fichiers ; `_input` / `_unhandled_input` 83 / 47 ; souris → sol (`get_mouse_position`, `project_ray`) 23 / 9 ; caméra lue par 21 fichiers | côté client, l'intention (clic pour se déplacer, cible verrouillée, visée au curseur, sorts automatiques, manette) doit être calculée **localement** puis envoyée comme un `BotInput` | NET-C |
| **Pause et temps** | `paused =` 55 / 23 fichiers ; `Engine.time_scale =` 10 / 5 fichiers (arrêt sur image, ralentis) | en réseau, **personne ne met le monde en pause** : choix de cartes, menus, Guide F1 doivent se faire jeu en marche (ou ralenti local + courte invulnérabilité) | NET-E |
| **Hasard** | 338 tirages au hasard **global** (`randf`, `randi`, `pick_random`, `shuffle`…) dans 65 fichiers (`run_director` 48, `class_rival` 27, `spawn_director` 24, `items` 22…) ; 189 tirages sur des générateurs à graine | sans importance pour un hôte autoritaire (lui seul tire) ; c'est ce qui **interdit le lockstep** ; les 3 tirages globaux de `ProcMap` sont à passer sur sa graine pour que le client regénère la même carte | NET-D (carte) |
| **Effets et retours** | `Vfx` / `EdenFx` 93 appels / 30 fichiers ; `DamageNumber.spawn` 37 / 14 ; `Sfx.` 109 / 55 ; `Telegraph.` 27 / 17 ; projectiles 7 / 5 | ils naissent chez l'hôte : à diffuser comme **événements** (sinon le client voit des héros qui gesticulent sans effets : constaté dans le prototype) | NET-C |
| **Monstres** | `monster.gd` 777 lignes, IA chez l'hôte seulement ; cible par défaut `get_first_node_in_group("player")` | côté client : marionnettes (comme les héros) ; côté hôte, viser **le héros le plus proche** parmi `heroes` (déjà fait par `hostile_heroes` pour la plupart) | NET-D |
| **HUD, caméra, carte** | `hud.gd` 1 494 lignes ; `CameraRig` (157 lignes, `rig.target` = héros local) | lisent le joueur local : chez un client, le héros local est une marionnette qui doit porter PV, recharges, statuts reçus de l'hôte (paquet « mon état » réservé au propriétaire) | NET-C |
| **États globaux des modes** | `Duel` 28 statiques, `Assault` 23, `Tower` 17, `TeamMatch` 15, `Royale` 13, `Survivor` 10, `PvpCaps` 5… ; `Duel.active` 44 lectures / 16 fichiers, `Royale.active` 67 / 25, `TeamMatch.` 91 / 21 | **pas bloquant** avec un hôte unique (une seule partie par processus) ; les règles valent chez l'hôte ; les clients n'ont besoin que des réglages d'affichage | par mode |
| **Démarrage et sauvegarde** | tout argument après `--` met `Profile` et `Settings` en **mode test** (`profile_test.json`, `profile.gd` l. 182, `settings.gd` l. 166) | un lancement `EdenSlash.exe -- --join=…` jouerait sur un profil vide : prévoir des arguments sans `--` ou une détection plus stricte (`res://tests/`, `--test`) | NET-A |
| **Deux instances sur un PC** | même `%APPDATA%\Godot\app_userdata\Eden Slash\` (profil, réglages, journal, `armory_cache.json`) | écritures croisées : `--profil=2` (emplacement de sauvegarde séparé) ou `EDEN_PROFILE` ; le prototype détourne `APPDATA` | NET-A |
| **Changements de scène** | `change_scene_to` 39 / 16 fichiers | lobby → monde → bilan : l'hôte annonce chaque passage, les clients suivent ; un client qui charge plus lentement doit être attendu | NET-E |

Ce qui **ne** bloque **pas** : la physique et l'IA (chez l'hôte seul), les 60 classes (même code de combat), les règles des modes
(chez l'hôte), la génération des cartes (graine), les tests existants (le réseau ne s'active que dans une session réseau).

## 5. Découpage en lots

Règle commune : **rien ne change hors session réseau** (même patron que MODE-0 : table de vérité / non-régression avant-après), tests à
deux processus `headless` sur la même machine (comme `tools/net_probe.py`), mesures de débit et de retard dans chaque rapport.
Estimation honnête en « lots d'agent » (≈ une session de travail d'un agent, comme les lots CO-*, TAC-*), marge × 1,5 pour le débogage
à plusieurs processus.

| Lot | Contenu | Dépend de | Taille | Preuve |
|---|---|---|---|---|
| **NET-A** — socle et arène à deux (**jalon 1**) | `core/net_session.gd` (hôte / client ENet, poignée de main : version, nom, classe ; départs), protocole entrées / instantanés repris du prototype, héros distant = `Player` + `BotInput` chez l'hôte, marionnettes chez le client, écran « Jouer ensemble » (Héberger / Rejoindre une adresse, ping, débit), arguments sans `--` (ou détection de test stricte), `--profil=N` | — | 1 | `test_net_a` : 2 processus, chacun voit l'autre bouger, attaquer, lancer ; ping, débit, retard d'entrée dans le rapport ; essai réel entre 2 PC par Tailscale |
| **NET-B** — fiche de héros | `HeroSheet` : classe, niveau, sorts, enchaînements, passifs, équipement, apparence, nom, réglages de combat ; `Player` lit sa fiche au lieu de `Run` / `Profile` / `Settings` (67 branches) ; le héros local la construit depuis les globaux (comportement identique) ; allié humain distant = fiche reçue à la connexion (son équipement du hub) | — (parallèle à A) | 1-2 | table de vérité : `stat_sheet()`, sorts, recharges, apparence identiques avant / après pour les 60 classes ; suite de non-régression |
| **NET-C** — ressenti du client | bus d'événements (effets, télégraphes, chiffres, sons, projectiles : 4 points d'entrée statiques à brancher), intention locale (clavier, souris, manette, clic pour se déplacer, cible) envoyée comme `BotInput`, **prédiction** du déplacement et de l'esquive du héros local + correction, paquet « mon état » (PV, recharges, statuts) pour le HUD | A, B | 2 | essai à +150 ms et 5 % de pertes : retard ressenti du déplacement < 50 ms, écart de correction < 0,5 m ; captures hôte / client côte à côte |
| **NET-D** — monstres et monde | carte regénérée depuis la graine (3 tirages globaux de `ProcMap` passés sur sa graine), instantanés compacts des monstres (quantifiés, par distance, 15-20 / s), apparitions / morts / butin en événements, cibles des monstres = héros le plus proche | A | 2 | même carte (empreinte des positions) sur 2 processus ; 150 monstres : débit mesuré < 60 Ko/s par client |
| **NET-E** — co-op Survie 2-4 (**jalon 2**) | une partie (`Run`) par joueur (l'autoload devient « la partie du joueur local », l'hôte tient celles des amis), choix de cartes **sans pause** (jeu en marche, ralenti local, invulnérabilité courte), mort et réanimation d'un allié (patron du Battle royale), PV des monstres / boss × nombre de joueurs, butin et or par joueur, bilan pour chacun ; chaque ami écrit **sa** sauvegarde d'après le bilan de l'hôte (confiance entre amis), départ d'un ami en cours de partie | B, C, D | 3 | Survie complète à 2 et 4 au pilote (`--autoplay`) sur 2-4 processus ; aucune écriture de profil chez l'hôte pour les amis ; captures |
| **NET-F** — Donjons, Tour, Ruée, Siège | moteur de salles de la Tour à plusieurs, alliés IA remplacés par des humains (ou complétés), butin par joueur | E | 1-2 | un donjon et 10 étages de Tour à 2 |
| **NET-G** — Survivant co-op | horde à débit réduit (10-15 / s, positions sur 16 bits), cartes et armes par joueur, coffres d'apparence chacun | E | 1-2 | palier I à 2, débit mesuré |
| **NET-H** — Duel et Arènes entre amis | humain contre humain (et équipes humains + IA), `hit_stop` coupé, profil `duel_a` / `duel_b`, compensation de retard optionnelle | C | 1 | Duel 2 manches au pilote ; durées de manche dans la plage mesurée (66-81 s à l'arme) |
| **NET-I** — Battle royale avec humains | largage, butin, réanimation, carte de 8 héros, pertinence par distance | D, H | 2 | partie complète avec 2 humains au pilote |
| **NET-J** — L'Échiquier entre amis | stratège réseau (actions publiques envoyées à l'hôte), état des joueurs diffusé, combat regardé (diffusé comme des héros), reprise si un ami décroche (l'IA prend sa place) | A | 1-2 | partie complète à 2 humains + 6 IA ; résultats identiques à une partie locale de même graine (actions rejouées) |
| **NET-K1 / K2 / K3** — Colisée, Assaut, Deux Voies | humains dans les équipes de `TeamMatch` ; Assaut : n'envoyer que ce que l'équipe voit (`AssaultVision`) ; Deux Voies : pertinence des sbires | H (+ D) | 1 / 1-2 / 2 | une partie de chaque au pilote |
| **NET-L** — connexion facile | « Héberger » tente l'UPnP, code d'invitation (adresse + port encodés), test de joignabilité, messages clairs (« ton ami n'a pas pu te joindre : … »), guide Tailscale intégré au LISEZMOI | A | 1 | essais : même PC, réseau local, Tailscale, UPnP |
| **NET-M** — distribution | contrôle de version (déjà dans le prototype), correctifs `.pck` additionnels (`ProjectSettings.load_resource_pack`), `make_release.py` (LISEZMOI multijoueur, `Jouer_ensemble.bat`), emplacement de sauvegarde par instance | A | 0,5-1 | correctif de 5-20 Mo appliqué sur un zip de 1,1 Go |

Total jusqu'à la co-op Survie jouable (A, B, C, D, E, L, M) : **≈ 10 à 12 lots**, soit 1,5 à 2 semaines avec 2-3 agents en parallèle
(B en parallèle de A ; D en parallèle de C) ; l'ensemble du catalogue : ≈ 22-28 lots. Échéance de fin de mois : **réaliste pour
NET-A + L + M + J (Échiquier entre amis) et probablement NET-E (co-op Survie à 2)** ; les autres modes après.

Ordre recommandé : **A ‖ B → L, M → C ‖ D → E** (jalon co-op), puis **J** dès que A est fait (indépendant), **H**, **F**, **I**, **G**, **K**.

## 6. Premier jalon (NET-A) : très petit, testable

- **Ce que le joueur voit** : Paramètres (ou Jouer) > « Jouer ensemble » > **Héberger** (affiche l'adresse à donner et le port) ou
  **Rejoindre** (saisir l'adresse). Arène vide (celle du prototype), chacun son héros (sa classe choisie), ping et débit en haut à
  gauche. Chacun voit l'autre courir, attaquer, lancer ses 4 sorts, esquiver, sauter ; les coups font baisser les PV.
- **Déjà prouvé par NET-0** (`R_NET0.md`) : liaison ENet locale, héros distant joué par un vrai `Player` + `BotInput`, marionnettes
  animées chez le client, 2 à 8 héros, débit et retards mesurés, refus d'une version différente.
- **Reste à faire en NET-A** : ranger le prototype dans le jeu (`core/net_session.gd`, écran), arguments de lancement sans `--`
  (sinon profil de test), emplacement de sauvegarde par instance, effets des sorts visibles chez le client (au minimum les
  télégraphes et chiffres de dégâts : début de NET-C), test automatique `test_net_a` (lance 2 processus), essai réel entre
  deux PC (Tailscale).
- **Critères d'acceptation** : 2 instances sur 1 PC et sur 2 PC ; le client voit l'hôte bouger avec moins de 150 ms de retard en
  local ; débit < 5 Ko/s par client ; déconnexion propre (« ton ami a quitté ») ; aucune écriture dans le vrai profil ; suite de
  non-régression verte.

Jalon 2 : **co-op Survie à 2** sur une carte d'époque I (NET-E), au pilote automatique puis joué par deux humains.

## 7. Distribuer le jeu aux amis

### 7.1 Ce qui existe

`Creer_version.bat` → `tools/make_release.py` : export du paquet `EdenSlash.pck` (préréglage « Windows Desktop ») + moteur renommé
`EdenSlash.exe` + `Jouer_plein_ecran.bat` + `LISEZMOI.txt`, zippés dans `build/EdenSlash_v<version>.zip`. Tailles mesurées :
**1,1 Go** zippé (0.1.150 : 1 159 Mo ; 0.1.71 : 1 118 Mo), 1,3 Go dézippé (`game/assets` : 1,6 Go). Rien à installer ; Windows 10/11
64 bits, carte compatible Vulkan. Sauvegardes : `%APPDATA%\Godot\app_userdata\Eden Slash\` (gardées d'une version à l'autre) ;
notes Alt + clic droit dans `feedback\` à côté de l'exe.

### 7.2 Ce qu'il faut ajouter pour le multijoueur

- **Même version pour tous** : la poignée de main refuse une autre version (fait dans le prototype : « version 0.1.x attendue ») ;
  le numéro est déjà affiché en bas à droite.
- **Mises à jour** : 1,1 Go à chaque version, c'est lourd. Correctifs : un `patch_<version>.pck` (scripts et données qui ont changé,
  quelques Mo) chargé au démarrage par `ProjectSettings.load_resource_pack` ; un nouveau zip complet seulement quand les assets
  changent (NET-M). Mise à jour par GitHub : **non** (dépôt public, voir § 7.5) ; par lien privé (OneDrive / Google Drive / WeTransfer)
  envoyé aux amis.
- **Profils séparés** : chaque ami a son PC, donc ses sauvegardes ; aucun mélange possible. Seul cas à gérer : deux instances sur le
  même PC (essais) → `--profil=2` (NET-A). L'hôte n'écrit **jamais** le profil d'un ami : chaque client écrit sa propre sauvegarde à
  la fin d'une partie, d'après le bilan reçu.
- **Lancement** : `Jouer_ensemble.bat` ou boutons dans le jeu ; ne jamais utiliser `--` pour ces arguments (§ 4, mode test).

### 7.3 Prérequis réseau

- Hôte : connexion avec ≥ 1 Mbit/s d'envoi pour 4 joueurs en Survie (estimation § 2.3), PC capable de faire tourner le jeu
  confortablement (il simule tout : mesuré ≈ 0,4-0,6 cœur pour l'arène, plus pour une Survie pleine), accepter le pare-feu Windows.
- Amis : n'importe quelle connexion stable ; le Wi-Fi marche, le câble est mieux ; ping < 80 ms vers l'hôte idéalement (même pays).

### 7.4 Guide simple (à mettre dans le LISEZMOI de la version multijoueur)

**Pour tout le monde (une seule fois)**
1. Dézippe le dossier EdenSlash reçu (pas besoin d'installer). Vérifie le numéro en bas à droite : il doit être le même chez tous.
2. Installe **Tailscale** (site officiel, gratuit), connecte-toi avec ton compte Google ou Microsoft.
3. L'hôte (celui qui héberge) partage sa machine avec ses amis depuis Tailscale (« Share ») ; chaque ami accepte l'invitation.

**L'hôte**
4. Lance le jeu > Jouer ensemble > **Héberger**. Windows demande « Autoriser l'accès » : coche *Réseaux privés*, valide.
5. Donne à tes amis l'**adresse Tailscale** affichée (100.x.y.z) ou le code d'invitation.

**Les amis**
6. Lance le jeu > Jouer ensemble > **Rejoindre**, colle l'adresse ou le code, valide.
7. Si ça ne marche pas : vérifie que Tailscale est allumé des deux côtés, que vous avez la même version, que l'hôte a bien
   autorisé le pare-feu. Sinon Alt + clic droit pour écrire une note, et envoie le dossier `feedback`.

### 7.5 Notes juridiques simples (pas un avis d'avocat)

- Eden Slash est un **projet de fan non commercial** qui contient des éléments **extraits du jeu d'origine** (modèles, textures,
  animations, musiques, noms) dont les droits appartiennent à leurs éditeurs. Ce n'est pas à nous de les redistribuer.
- **Partager le zip avec quelques amis proches**, en privé, pour tester ensemble : risque faible, c'est déjà l'esprit du LISEZMOI
  (« ne pas le redistribuer publiquement »).
- **À éviter** : un lien de téléchargement public (forum, Discord public, réseaux sociaux), une « Release » GitHub, une page itch.io /
  Steam, des vidéos ou diffusions monétisées, toute vente ou don lié au jeu, un serveur public ouvert à des inconnus.
- **Le dépôt GitHub public est aujourd'hui le plus gros risque** : il expose 31 230 fichiers d'assets du jeu d'origine
  (2 150 modèles `.glb`, la musique `game/assets/music`, les textures) à n'importe qui. Recommandation : **passer le dépôt en privé**
  (gratuit sur GitHub ; à savoir : les minutes d'Actions gratuites sont limitées pour un dépôt privé — environ 2 000 min/mois sur le
  plan gratuit, à revérifier — ce qui peut obliger à alléger l'intégration continue `controle.yml`). Décision du joueur.
- Le moteur Godot (et ENet qu'il contient) est sous licence MIT : la mention est déjà dans le LISEZMOI.
- Tailscale / ZeroTier / Radmin : services tiers, chacun accepte leurs conditions pour lui-même ; aucune donnée du jeu n'y transite
  autrement que chiffrée entre amis.

## 8. Pièges à retenir

1. **`--` = mode test** : tout argument utilisateur bascule `Profile` et `Settings` sur les fichiers de test.
2. **Pause** : en réseau, aucune pause globale ; tout écran qui pose `get_tree().paused` doit avoir une variante « jeu en marche ».
3. **Effets** : un client sans bus d'événements voit des héros qui gesticulent sans effets ni dégâts affichés (constaté).
4. **Hôte qui part = fin de partie** (listen server) : prévenir clairement, sauvegarder ce qui est acquis chez chacun.
5. **Retard ressenti** : sans prédiction locale, ≈ 130-150 ms en local et ≈ 280 ms à 150 ms d'aller-retour : la prédiction du
   déplacement est indispensable avant de faire jouer des amis à distance.
6. **Deux instances sur un PC** partagent `user://` : un `APPDATA` ou un emplacement de profil par instance.
7. **Machine saturée** (20 à 58 Godot d'autres agents) : mesures de temps bruitées ; les débits et tailles de paquets, eux, sont exacts.
8. **Débit des monstres** : à mesurer dès NET-D ; la pertinence par distance n'est pas une option en Survivant et en Battle royale.
9. **Équité JcJ** : l'hôte a 0 ms ; entre amis, alterner l'hôte ou ajouter la compensation de retard (NET-H).
10. **Version** : un ami en retard d'une version = refus net à la connexion (sinon désynchronisation garantie des fiches et des règles).
