# R_NET_A : socle réseau et arène « Jouer ensemble » (lot NET-A, 17/10/2026)

Premier jalon du multijoueur entre amis (étude `NETWORK.md`, prototype `R_NET0.md`) : une couche réseau propre dans le jeu,
une arène d'essai où chacun voit l'autre bouger, attaquer et lancer ses sorts, un test automatique à plusieurs processus.
**Aucun mode existant ne change en solo** : tout passe par des objets qui n'existent que pendant une session, et les huit points
d'entrée des effets ne testent qu'un booléen (`NetEvents.on`, faux hors session).

## 1. Ce qui a été livré

| Fichier | Rôle |
|---|---|
| `scripts/core/net/net_protocol.gd` (`NetProtocol`) | format des paquets, **versionné** (`PROTOCOL` = 1, plus `Version.NUMBER`) : un pair d'une autre version est refusé avec un message clair |
| `scripts/core/net/net_session.gd` (`NetSession`) | socle : ENet en paquets bruts (`ENetMultiplayerPeer` seul, **ni `@rpc` ni SceneMultiplayer** : l'API multijoueur de l'arbre n'est jamais touchée), canaux, retard et pertes simulés, mesures, départ propre (`BYE` puis déconnexion « quand tout est parti ») |
| `scripts/core/net/net_host.gd` (`NetHost`) | hôte autoritaire : le héros d'un ami est un **vrai `Player`** à sa fiche (classe, niveau, sorts) piloté par un `BotInput` rempli par ses paquets ; instantanés 30 / s ; événements visuels ; table des noms (animations, effets, sons) ; refus (version, partie pleine) |
| `scripts/core/net/net_client.gd` (`NetClient`) | client : entrées 30 / s, fantômes interpolés 100 ms dans le passé, événements rejoués à la même heure que les fantômes, mesure du retard d'entrée |
| `scripts/core/net/net_ghost.gd` (`NetGhost` extends `Player`) | fantôme : modèle, tenue, arme et animations d'un vrai héros, **sans** physique, collisions, groupes ni entrées (corrige le piège de NET-0 : les marionnettes étaient des héros ennemis) ; anneau doré (moi) ou lagon (amis), nom et PV |
| `scripts/core/net/net_events.gd` (`NetEvents`) | bus d'événements (début de NET-C) : `EdenFx.play`, `Vfx.slash / ring / flash / spark`, `DamageNumber.spawn / spawn_text`, `Telegraph.spawn`, `Sfx.play_at`, `HeroBolt.fire` ; chez l'hôte, une ligne `if NetEvents.on:` en tête de chacun ; chez le client, rejoués sur le fantôme (une zone rejouée ne touche personne : pas de source, aucun héros dans les groupes) |
| `scripts/core/net/net_intent.gd` (`NetIntent`) | entrées du joueur local (ZQSD relatif à la caméra, visée à la souris, attaque maintenue, compteurs d'appui des 4 sorts, esquive, saut, échange d'arme) et pilote automatique des mesures |
| `scripts/core/net/net_launch.gd` (`NetLaunch`) | arguments de lancement, emplacement de sauvegarde par instance |
| `scripts/world/net_arena.gd` + `scenes/net_arena.tscn` (`NetArena`) | arène d'essai : chacun pour soi, niveau 10, 4 premiers sorts de la classe, sans équipement, retour 3 s après une chute ; `Training.active` pendant la scène (aucune sauvegarde, comme l'entraînement) |
| `scripts/ui/net_panel.gd` (`NetPanel`) | fenêtre papier DA v2 « Jouer ensemble » : héros (◀ ▶), **Héberger**, **Rejoindre** une adresse, Retour ; en partie (Échap) : adresses à donner, joueurs et ping, Reprendre, Quitter la partie (le jeu ne se met jamais en pause) |
| `scripts/ui/net_overlay.gd` (`NetOverlay`) | bandeau papier en haut à gauche : rôle, joueurs, ping, envoi / réception ; **F11** : retard d'entrée, retard ressenti, images par seconde, retard simulé, profil de la fenêtre ; annonces (« Léa a rejoint la partie ») |
| `tests/test_net_a.tscn` | test à quatre processus (§ 4) |
| `tools/net_a.py` | mesures : hôte + N clients sur la machine (vraie arène), processeur et mémoire de chaque processus (modèle : `tools/net_probe.py`) |
| `Jouer_ensemble.bat` | 1 Héberger, 2 Rejoindre (adresse demandée), 3 Essai à deux sur ce PC |

Modifications ciblées de fichiers existants (une à quatre lignes chacune) : les 8 points d'entrée d'effets ci-dessus ; `Profile.slot_path` /
`last_slot` / `_remember_slot`, `Settings._ready`, `SpellPresets._path`, `RunJournal.path` (chemins par instance, inchangés sans `--profil`) ;
`Settings.DEFAULTS.net` (`friends` faux, `port` 24680, `join`, `class`) ; Paramètres > Caméra & interface > Développement : **« Mode amis
(expérimental) »** ; écran titre : bouton « Jouer ensemble » visible seulement avec ce réglage, et redirection `--host` / `--join` ; tests
`test_nav_screens` (menu « Jouer ensemble » atteignable à la manette : 6 / 6) et `test_pages` (bouton caché par défaut, visible avec le réglage).

## 2. Lancement

- **Dans le jeu** : Paramètres > Caméra & interface > « Mode amis (expérimental) » ; l'écran titre montre alors « Jouer ensemble ».
- **Ligne de commande** (arguments **avant** tout `--`, sinon `Profile` et `Settings` passent en mode test) :
  `EdenSlash.exe --host [--net-port=24680]`, `EdenSlash.exe --join=100.64.0.7[:24680]`, `--profil=<nom>` (sauvegarde, réglages,
  préréglages de sorts et journal dans `user://instances/<nom>/` : deux fenêtres sur un même PC ne se mélangent jamais) ;
  options d'essai `--net-class=`, `--net-name=`, `--net-pilot`, `--net-secs=N` (mesure puis quitte), `--net-report=<json>`, `--net-lag=<ms>`,
  `--net-loss=<%>`, `--net-snap=<n>`, `--net-shot=<png>`, `--net-bind=127.0.0.1`, `--net-version=<x>` (essai du refus).
- Dans l'éditeur ou `Jouer.bat` : `Jouer_ensemble.bat` (choix 3 = deux fenêtres sur ce PC, la 2e avec `--profil=ami`).

## 3. Protocole

| Paquet | Sens, canal | Contenu | Taille |
|---|---|---|---|
| HELLO / WELCOME / REFUSE | client ↔ hôte, fiable | protocole, version, classe, nom / ta case, horloge / raison | — |
| SPAWN / DESPAWN / NAME | hôte → clients, fiable | héros qui arrive (case, classe, nom) / qui part (a quitté, connexion perdue) / entrée de la table des noms | — |
| INPUT | client → hôte, non fiable ordonné (canal 1), 30 / s | numéro, déplacement 2 × f16, attaque, visée 3 × f32, 7 compteurs d'appui | 17 o (29 avec visée) |
| SNAP | hôte → clients, non fiable ordonné (canal 2), 30 / s | horloge + par héros : case, drapeaux, position, cap, animation (indice, position, vitesse), PV, PV max, dernier numéro d'entrée appliqué | **6 + 34 o par héros** |
| EVENTS | hôte → clients, non fiable ordonné (canal 3), avec chaque instantané | effets, arcs, anneaux, éclairs, étincelles, chiffres, textes, zones, sons, projectiles de l'image | 55-80 o par paquet (médiane) |
| BYE | les deux sens, fiable | départ propre (je quitte / l'hôte ferme) | 2 o |

Un appui est un **compteur** : un paquet perdu ne fait pas rater un sort. Chez l'hôte, un appui ne vaut qu'une image ; un ami garde son
dernier déplacement jusqu'au paquet suivant. Délai de coupure ENet ramené à 6-12 s (connexion perdue annoncée).

## 4. Test automatique `test_net_a` (vert, 70 à 130 s selon la charge)

Le test est l'hôte (arène réelle, héros au pilote) et lance de **vrais clients Godot sans `--`**, chacun avec `--profil=neta_<x>` :
1. un client d'une **autre version** : refusé, code 2, « Refusé par l'hôte : version 0.1.305 attendue (tu as 0.0.1-ancienne). Mettez-vous tous à jour. » ;
2. un client au pilote, 14 s : l'hôte voit son héros parcourir 50 m, 7 animations, 8 attaques / sorts, 17 coups portés ; le client voit l'hôte
   (42 m, 7 animations, 12 attaques / sorts) et son propre héros (49 m), **156 événements visuels rejoués** ; débit reçu 2,99 Ko/s, envoyé
   1,10 Ko/s, ping 20 ms, retard d'entrée 33 ms, retard ressenti 183 ms ; il part proprement (l'hôte annonce « Amie a quitté la partie ») ;
   il n'est **pas en mode test** et n'écrit que dans `user://instances/neta_a/` (la vraie sauvegarde n'est ni créée ni modifiée) ;
3. un client qui reste : l'hôte ferme, le client reçoit « L'hôte a fermé la partie. » et quitte (code 0) ; l'hôte revient au menu,
   `NetEvents` éteint, `Training.active` rendu.
Plus : formats des paquets (relus à l'identique, 74 o pour 2 héros), adresses (`ip:port`, IPv6, Tailscale), chemins par instance.

Non-régression (copie propre de HEAD + ce lot) : `test_nav_screens`, `test_pages`, `test_texts_fr`, `test_p4_flow`, `test_controls` **verts** ;
`check_scripts` : 585 scripts compilent.

## 5. Mesures (`python tools/net_a.py`, machine chargée : 58 processus Godot d'autres agents ; débits et tailles exacts, temps bruités)

20 s de mesure par client (1re seconde à deux exclue), médianes.

| Essai | Héros | Hôte : envoi / réception (Ko/s) | Client : envoi / réception (Ko/s) | Instantané | RTT ENet | Retard d'entrée (client) | Retard ressenti (client) | Processeur (hôte / client) | Mémoire max |
|---|---|---|---|---|---|---|---|---|---|
| 1 client, sans fenêtre | 2 | 2,80 / 1,05 | 1,10 / 2,82 | 74 o | 16-22 ms | 17 ms (p95 33) | **183 ms** (p95 217) | 0,35 / 0,39 cœur | 552 / 555 Mo |
| 1 client, **+150 ms simulés, 5 % perdus** | 2 | 2,92 / 1,02 | 1,00 / 2,84 | 74 o | 20 ms (+150) | 183 ms | **367 ms** | 0,40 / 0,43 | 555 / 556 Mo |
| 3 clients | 4 | 14,2 / 3,2 | 1,1 / 4,8-5,4 | 142 o | 20-23 ms | 17-33 ms | 167-200 ms | 0,37 / 0,39-0,44 | 573-577 Mo |
| 1 client, **en fenêtres** (1600×900, rendu réel) | 2 | 2,87 / 1,04 | 1,05 / 2,75 | 74 o | 30-36 ms | 17 ms | 183 ms | 0,58 / 0,71 | 1 161 / 1 175 Mo |

- **Débit** : < 3 Ko/s par client à deux, ≈ 5 Ko/s à quatre (les événements visuels de 4 héros comptent pour ≈ 1,5 Ko/s) ; l'hôte envoie
  ≈ 4,7 Ko/s par ami. Critère du jalon (< 5 Ko/s par client à deux) tenu ; à quatre on est à la limite à cause des effets (levier NET-C :
  les regrouper, ne pas envoyer les étincelles lointaines).
- **Coût du réseau** : encodage d'un instantané 38-48 µs, décodage 30-35 µs ; images de 1-3 ms sans fenêtre. Le coût d'une instance vient du jeu
  (0,35-0,45 cœur, 0,55 Go sans rendu ; 0,6-0,7 cœur, 1,2 Go en fenêtre), l'hôte ne coûte pas plus cher qu'un client à 2-4 héros.
- **Retard ressenti** (mesuré : de l'instant où l'on veut repartir à l'arrêt jusqu'au premier mouvement affiché de son héros, > 15 cm) :
  chez l'hôte, 33-67 ms (1-2 images + l'accélération du héros : la référence sans réseau) ; chez un client en local, **≈ 183 ms**, soit
  ≈ 120-150 ms ajoutés = 100 ms d'interpolation + 0-33 ms avant l'envoi de l'entrée + 0-33 ms avant l'instantané suivant ; à 150 ms
  d'aller-retour, **≈ 370 ms**. Les grands p95 (0,9 à 1,4 s) sont des départs pendant une attaque (le héros finit son coup avant de bouger),
  pas du réseau. **Conclusion** : jouable pour se voir et s'essayer en réseau local ou par Tailscale proche (< 40 ms), trop mou au-delà ;
  la **prédiction locale du déplacement et de l'esquive (NET-C)** est la prochaine marche avant de vraies parties à distance.
- **Le joueur de l'hôte a 0 ms** (son héros est simulé chez lui) : avantage léger en chacun pour soi (NET-H : alterner l'hôte ou compenser).

Captures regardées (fenêtres, non commitées) : le menu « Jouer ensemble » centré sur l'arène ; chez le client, les deux héros animés au bon
endroit avec nom et PV, la **zone bleue d'un sort, les effets de sorts et les chiffres de dégâts** (absents dans NET-0) ; chez l'hôte, la même scène.
Corrigé en les regardant : panneau et bandeau en haut à gauche au lieu d'être centrés (`set_anchors_and_offsets_preset`), aide des touches hors de l'écran.

## 6. Consignes de test pour le joueur et ses amis

**Sur ce PC (deux fenêtres)** : `Jouer.bat` une fois (mise à jour des ressources), puis `Jouer_ensemble.bat` > 3. La 1re fenêtre héberge,
la 2e rejoint `127.0.0.1` avec une sauvegarde à part. Cliquer dans une fenêtre pour la jouer : ZQSD, clic gauche (attaque vers la souris),
1-4 (sorts), Maj (esquive), Espace (saut). F11 : détails réseau. Échap : menu (Quitter la partie).

**Entre deux PC** (même version en bas à droite, obligatoire) :
1. Chacun installe **Tailscale** (gratuit), se connecte ; l'hôte partage sa machine avec ses amis (ou tout le monde sur le même réseau local).
2. L'hôte : Paramètres > Caméra & interface > « Mode amis (expérimental) », puis écran titre > **Jouer ensemble** > **Héberger** (ou
   `Jouer_ensemble.bat` > 1). Windows demande l'accès réseau : cocher « Réseaux privés ». Échap montre **l'adresse à donner** (Tailscale en
   premier, `100.x.y.z`) et le port (24680).
3. L'ami : Jouer ensemble > écrire l'adresse > **Rejoindre** (ou `Jouer_ensemble.bat` > 2).
4. Si « Pas de réponse » : Tailscale allumé des deux côtés, bonne adresse, pare-feu accepté chez l'hôte. Si « Refusé : version … attendue » :
   mettre tout le monde à jour. Alt + clic droit pour une note, comme d'habitude.
À noter pour les retours : le ping (bandeau), le retard ressenti (F11) et l'impression (« mou », « saccadé », « effets manquants »).

## 7. Limites et suite

- Pas de prédiction de son héros (NET-C) ; contrôles simplifiés (ZQSD + souris + manette pour bouger ; pas encore clic pour se déplacer,
  cible verrouillée, sorts automatiques, visée à la manette) ; le HUD des sorts (recharges) n'existe pas encore chez le client.
- Tous les héros jouent la fiche nue de leur classe (niveau 10, 4 premiers sorts) : la fiche d'un ami (équipement, sorts choisis, apparence)
  viendra avec NET-B (`HeroSheet`). Les auras et l'arme secondaire ne sont pas montrées.
- Non testé pour de vrai : **entre deux PC** (Tailscale, réseau local) — tout est prêt, essai du joueur demandé ; UPnP et code d'invitation (NET-L).
- `autochess_save.json`, `build_profiles.json`, `dev_edits.json` restent communs aux instances d'un même PC (sans effet sur l'arène).
- Débit des effets à quatre (≈ 5 Ko/s par client) à alléger avant la Survie co-op (NET-D / NET-E, qui ajoutera les monstres).
