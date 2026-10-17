# R_NET0 : prototype jetable de liaison hôte / client (lot NET-0, 17/10/2026)

But : prouver, avant tout lot de multijoueur, que l'architecture recommandée par `NETWORK.md` (hôte autoritaire, entrées montantes,
instantanés descendants, ENet) marche **avec les vrais héros du jeu**, et mesurer débit, retard et ressources. Rien du jeu n'a
changé : deux fichiers ajoutés dans `game/tools/` (jamais chargés par le jeu) et un lanceur Python.

## 1. Ce qui a été livré

| Fichier | Rôle |
|---|---|
| `game/tools/net_probe.tscn` + `net_probe.gd` (≈ 790 lignes, sans `class_name`) | arène vide (sol, 12 piquets de repère, lumière) ; **hôte** : ENet serveur, vrais `Player` pour tous les héros, celui d'un ami piloté par un `BotInput` rempli par ses paquets ; **client** : envoie ses entrées, affiche des marionnettes (`Player` sans physique ni logique, modèle et animations du jeu) interpolées ; mesures ; capture |
| `tools/net_probe.py` | lance 1 hôte + N clients sur la machine, chacun avec son dossier utilisateur (`APPDATA` détourné vers `net0_*`), récupère les lignes `[net] {json}`, ajoute le temps processeur et la mémoire maximale de chaque processus (Windows), résume |

Lancement :
```
python tools/net_probe.py                                    # 2 fenêtres, clavier (ZQSD, clic gauche, 1-4, Maj, Espace)
python tools/net_probe.py --clients 3 --pilot                # 4 héros au pilote automatique
python tools/net_probe.py --headless --pilot --secs 20 [--lag 150 --loss 5] [--snap 20] [--compress] [--project <copie de game/>]
Godot --path game res://tools/net_probe.tscn -- --net-host | --net-join=<adresse> [--net-class=…] [--net-port=24680]
```
Le dossier de travail partagé étant en chantier (scripts d'autres agents qui ne compilent pas), les mesures ont été faites sur une
**copie propre de HEAD 0.1.303** + les deux fichiers du prototype (`run_tests.preparer_copie`, `--import`), option `--project`.

## 2. Fonctionnement

- **Poignée de main** : le client envoie version + classe (`_rpc_hello`, fiable) ; l'hôte refuse une autre version
  (vérifié : « refusé par l'hôte : version 0.1.303 attendue (tu as 0.1.299) »), envoie au nouveau venu l'état complet (héros
  présents, table des noms d'animation), crée son héros et l'annonce à tous. Départ d'un pair : héros retiré partout.
- **Entrées** (client → hôte, 30 / s, canal 2 non fiable ordonné, **28 octets**) : numéro, déplacement (2 × f16), point visé
  (3 × f32), attaque maintenue, 7 compteurs d'appui (4 sorts, esquive, saut, échange d'arme). L'hôte pose tout dans le `BotInput`
  du héros avant la physique (`process_physics_priority = -100`) ; un compteur qui a bougé = un appui (`pulse`) pour une image :
  un paquet perdu ne fait pas rater un sort.
- **Instantanés** (hôte → tous, 30 / s, canal 1 non fiable ordonné) : instant + par héros 34 octets (id, position, cap, indice
  d'animation, position et vitesse de l'animation, PV, PV max, dernier numéro d'entrée appliqué). Les noms d'animation passent
  une fois chacun en fiable.
- **Client** : horloge d'affichage 100 ms derrière l'hôte, interpolation position / cap / PV entre les deux instantanés qui
  l'encadrent, animation relancée quand elle change ou recommence, recalée si elle dérive de plus de 0,2 s.
- **Chacun pour soi** (`set_ffa`) : tous les héros peuvent se toucher ; un héros sous 35 % de PV est soigné (essai : on veut voir
  les coups, pas des morts), un mort réapparaît après 2 s (`Player.respawn`).
- **Pilote automatique** (`--net-pilot`) : s'approche du héros le plus proche, tourne autour, attaque à portée, un sort toutes les
  3 s, une esquive toutes les 4,5 s, un saut toutes les 10 s.
- **Retard et pertes simulés** côté client (`--net-lag`, `--net-loss`) : file d'attente avant envoi et avant lecture ; l'aller-retour
  ENet affiché reste celui de la machine.

## 3. Mesures (machine chargée : 34 processus Godot d'autres agents sur 16 cœurs ; débits et tailles exacts, temps bruités)

20 s de mesure par client (les 2 premières secondes et le temps sans ami sont exclus), médianes.

| Essai | Héros | Hôte : envoi / réception (Ko/s) | Client : envoi / réception (Ko/s) | Paquets / s (hôte) | Instantané | RTT ENet | Retard d'entrée (méd. / p95) | Processeur par processus | Mémoire max |
|---|---|---|---|---|---|---|---|---|---|
| hôte seul (référence) | 1 | — | — | — | — | — | — | 0,44 cœur | 548 Mo |
| 1 client | 2 | 2,67 / 1,24 | 1,24 / 2,67 | 34 / 34 | 77 o | 12-13 ms | 50 / 50 ms | 0,40 / 0,47 | 556 / 558 Mo |
| 3 clients | 4 | 14,3 / 3,7 | 1,23 / 4,78 | 100 / 99 | 149 o | 13-14 ms | 33 / 50 ms | 0,40 / 0,42-0,43 | 571-575 Mo |
| **7 clients** | **8** | **32,4 / 7,1** | 1,24 / 7,1-8,7 | 177 / 195 | 221 o | 14-21 ms | 33 / 50-67 ms | 0,32-0,39 | 597-600 Mo |
| 1 client, **+150 ms, 5 % perdus** | 2 | 2,67 / 1,17 | 1,17 / 2,67 | 33 / 32 | 77 o | 13-14 ms (+150 simulés) | **183 / 183 ms** | 0,41 / 0,49 | 553 Mo |
| 1 client, 20 instantanés / s + compression | 2 | 1,72 / 1,18 | 1,17 / 1,72 | 24 / 34 | 77 o | 12-13 ms | 33 / 50 ms | 0,40 / 0,48 | 557 Mo |
| 1 client, compression ENet | 2 | 2,55 / 1,17 | 1,17 / 2,56 | 34 / 34 | 77 o | 13 ms | 33 / 50 ms | 0,41 / 0,50 | 559 Mo |
| 3 clients, compression ENet | 4 | 12,1 / 3,5 | 1,17 / 4,55 | 91 / 100 | 149 o | 13 ms | 33-50 / 50 ms | 0,40 / 0,43-0,50 | 571-574 Mo |
| 1 client, **en fenêtres** (1600×900, rendu réel) | 2 | 2,67 / 1,24 | 1,24 / 2,67 | 34 / 34 | 77 o | 13-17 ms | 33 / 50 ms | 0,58 / 0,56 | 1 247 / 1 149 Mo |

Coûts du code réseau lui-même : encodage d'un instantané 27-41 µs (2 à 8 héros), décodage 26-48 µs ; un héros de plus coûte
36 octets par instantané (77 o à 2 héros, 149 o à 4, 221 o à 8 : + 36 o par héros, 5 o d'en-tête).

Ce que chaque écran a vu (essai à 4 héros, extrait) : chez l'hôte, le Voleur d'un client a parcouru 110 m avec 35 attaques / sorts ;
chez ce client, son propre héros 108 m et 32 actions ; chez les deux autres clients, ce même Voleur 96 m / 30 actions et 89 m / 29
actions (fenêtres de mesure décalées de 1,5 s par client) ; 162 coups simulés chez l'hôte. Dans tous les essais, chaque instance
voit **tous** les héros bouger (40 à 185 m en 20 s) et changer d'animation (5 à 11 animations différentes : course, attaques, sorts,
esquive, saut).

Captures regardées (fenêtres, 10 s, non commitées) : l'hôte voit son Guerrier, le Clerc du client, la zone du sort et les chiffres
de dégâts ; le client voit les deux héros animés au bon endroit avec leurs PV, **mais aucun effet de sort ni chiffre de dégâts**
(ils naissent chez l'hôte : bus d'événements à faire, lot NET-C).

## 4. Enseignements

1. **L'architecture tient** : le héros d'un ami est un vrai `Player` du jeu piloté par un `BotInput` ; aucune ligne de combat
   réécrite ; 60 classes disponibles telles quelles (essais avec Guerrier, Clerc, Barde, Chevalier, Voleur, Chasseur, Magicien, Samouraï).
2. **Le débit n'est pas un problème pour les héros** : 2,7 Ko/s par client, 32 Ko/s d'envoi chez l'hôte à 8 héros (0,26 Mbit/s). Les
   monstres feront l'essentiel du débit (estimé ≈ 50 Ko/s par client en Survie : NET-D).
3. **Le retard ressenti est le vrai sujet** : retard d'entrée 33-50 ms en local (attente du prochain instantané + image de physique),
   **+ 100 ms d'interpolation** = 133-150 ms avant de voir son propre héros bouger ; à 150 ms d'aller-retour, **≈ 280 ms**. La
   **prédiction locale du déplacement et de l'esquive** (NET-C) est indispensable avant de jouer à distance.
4. **Compression ENet inutile** à ce stade (− 4 à − 15 %) ; passer à 20 instantanés / s divise l'envoi par 1,5 sans gêne visible pour
   les héros des autres (l'interpolation lisse).
5. **Ressources** : le réseau ne coûte presque rien (≈ 40 µs par instantané) ; le coût d'une instance vient du jeu lui-même
   (0,4-0,6 cœur, 0,55 Go sans fenêtre, 1,1-1,2 Go avec rendu). L'hôte ne coûte pas plus cher que l'instance seule pour 2-8 héros.
6. **Pièges rencontrés** :
   - le lanceur `Godot_…_console.exe` n'est qu'un relais : pour mesurer le processeur et la mémoire, lancer l'exécutable principal
     (il écrit bien sur la sortie redirigée) ;
   - tout argument après `--` met `Profile` et `Settings` en mode test : sans danger ici (aucune écriture du vrai profil), mais à
     régler pour un vrai lancement réseau (NET-A) ;
   - deux instances sur le même PC partagent `user://` : le lanceur détourne `APPDATA` par instance ;
   - `--resolution` est écrasé par les Paramètres du jeu (fenêtres en 1600×900) ;
   - les marionnettes sont des `Player` « ennemis » (anneau rouge au sol, groupe `foe_heroes`) : une vraie marionnette de client doit
     avoir sa propre classe légère (modèle + animations + barre) pour ne rien déclencher chez le client.

## 5. Limites (assumées : prototype jetable)

Pas de prédiction locale, pas d'effets / sons / chiffres chez le client, pas de monstres, pas de carte, pas de HUD (texte de mesure
seulement), pas de NAT (localhost uniquement ; à essayer entre deux PC par Tailscale en NET-A), pas de reconnexion, entrées au clavier
simples (ZQSD monde, clic gauche vers la souris) sans les modes de contrôle du jeu. Le code sera repris et rangé par NET-A, pas
branché tel quel.
