# R_TAC_2 : murs, vue, brouillard, voile et bruits de L'Assaut (lot TAC-2, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.6 (« Murs ») et § 7.7 (« Vue, brouillard et bruits », le cœur du mode) ; risque
n° 1 de l'étude (« le moteur n'a jamais arrêté un coup sur un mur ni caché un ennemi »). Cartes : `R_TAC_1.md`.

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Vision de la partie | `game/scripts/world/assault_vision.gd` (`AssaultVision`, `current`) | vue d'équipe, adversaires cachés, dernière position, voile, bruits, API de perception |
| Coups et décor | `combat/telegraph.gd`, `player/player.gd`, `combat/hero_bolt.gd`, `combat/projectile.gd` | une ligne chacun, gardée par `AssaultVision.current != null` : rien ne change hors Assaut |
| IA honnête | `ai/class_rival.gd` | `_hostile_pool` filtré par ce que l'équipe voit (plus le contact à 2,5 m), `_can_target` idem ; sans cible en vue, le héros scripté rejoint son poste (`goal`) au lieu de rester planté — seulement quand une vision d'Assaut tourne |
| Ce qu'on ne voit pas | `ui/minimap.gd`, `ui/hud.gd` | un adversaire caché n'est ni sur la mini-carte ni dans la barre de cible (mode d'équipes seulement) |
| Voir les sons | `game/scripts/ui/assault_cues.gd` (`AssaultCues`, sur `RoyaleCues`) | arcs des bruits entendus par ton équipe, autour du héros regardé ; activé dans ce mode (Q7 de l'étude) |
| Directeur | `core/assault_director.gd` | monte la vision et les arcs, `view_hero()` (le joueur, ou l'allié suivi après sa mort), `can_perceive` = la vision, bruits de pose et de désamorçage (toute la carte, toutes les 1,5 s), mesure `--assault-perf` ; **carte par défaut : le Bourg** (`--assault-map=arena` pour l'arène d'essai) |
| Test | `game/tests/test_tac2.tscn` | voir § 4 |

## 2. Règles codées

| Règle | Valeur | Où |
|---|---|---|
| Portée de vue | 22 m, yeux à 1,5 m, corps visé à 1,1 m | `AssaultVision.RANGE`, `EYE`, `BODY` |
| Ce qui coupe la vue | murs pleins (couche `AssaultMap.SIGHT`), brumes (`smokes`, lot TAC-5 pour l'objet) ; **pas** les murets ni la fontaine | `los` |
| Hautes herbes | caché au-delà de 3 m | `GRASS_SEE` |
| Invisibilité | caché au-delà de 5 m | `INVIS_SEE` (TAC-4 : 2,5 s au plus, scintillement) |
| Vue d'équipe | un adversaire est vu si UN héros debout de l'équipe le voit ; 10 fois par seconde | `_team_vision`, `TICK` |
| Caché | modèle, plaque, mini-carte, barre de cible ; les morts et les équipiers restent visibles | `_apply` |
| Dernière position | « ? » fraise à l'endroit où l'adversaire a été vu, s'efface en 4 s | `_update_ghosts`, `LAST_SEEN` |
| Voile | ce que TON héros ne voit pas : encre-500 à 35 % + trame de points (BIBLE § 3) | quad plein écran (`VEIL_SHADER`) |
| Coups et décor | hauteur d'un coup au sol 1 m : murs **et** murets (1,2 m) l'arrêtent ; depuis une terrasse on tire par-dessus ; une zone posée au loin exige la ligne de tir du lanceur au centre | `blocks_shot`, `blocks_zone`, `blocks_segment` |
| Bruits | pas (course > 4,2 m/s) 14 m ; esquive 18 m ; coup ou sort 24 m ; pose et désamorçage : toute la carte | `noise`, `_listen` |
| Ciblage de l'IA | ce que son équipe voit, ou ce qui la touche presque (2,5 m) ; jamais la position réelle d'un ennemi non vu | `filter_seen`, `perceives` |

## 3. API de perception (pour le lot TAC-6)

```gdscript
var v := AssaultVision.current                     # null hors Assaut
v.sees(équipe, héros) ; v.visible_foes(équipe) ; v.seen_by(équipe, héros)   # qui le voit
v.last_seen(équipe)          # {id d'instance: {pos, t, who}} : dernière position connue (gardée 30 s)
v.heard_since(équipe, 3.0)   # [{pos, kind: steps|dodge|fight|plant|defuse, t, src, radius}]
v.los(a, b) ; v.can_see(observateur, cible) ; AssaultVision.blocks_shot(a, b)
v.noise(pos, "fight", équipe_source)                # un bruit de plus (utilitaires, leurre : lot TAC-5)
v.smokes.append({"pos": Vector2(x, z), "r": 5.0, "until": v.time + 10.0})   # brume (lot TAC-5)
v.spotted / v.lost / v.heard                         # signaux (équipe, héros / bruit)
```

## 4. Preuves et mesures

**`test_tac2`** (partie réelle sur le Bourg, héros posés à la main pendant un achat sans fin) : hors Assaut rien ne change ;
la halle cache un adversaire, la rue le montre (et dit qui le voit) ; au-delà de 22 m, caché, dernière position gardée et « ? »
affiché ; un muret laisse voir ; hautes herbes : caché à 9 m, vu à 2,4 m ; invisible caché à 9 m ; une brume coupe la vue, puis
plus ; polygone du voile (122 sommets) : derrière la halle voilé, la rue visible ; un coup en ligne d'un scripté arrêté par la
halle (PV inchangés) puis qui touche dans la rue, arrêté par un muret ; une zone posée derrière un mur sans effet ; ciblage
honnête (l'adversaire derrière le mur n'est pas visé ; au contact il se sent) ; zone et projectile du héros arrêtés par le mur,
zone qui touche dans la rue ; bruits : pas à 13 m entendus, à 20 m non, coup à 20 m entendu, pose sur toute la carte, jamais ses
propres bruits, arcs « Voir les sons », coup d'un scripté = bruit de combat ; fin de partie : plus de vision.

**Coût** (machine chargée : 50 Godot d'autres agents, processeur à 100 % sur 16 cœurs) :

| Mesure | Résultat |
|---|---|
| Un tour de vision (8 héros, Bourg, ~7 rayons de vue + 120 rayons de voile) | médiane **0,23 à 0,52 ms**, 90e 0,34 à 0,61 ms (10 tours par seconde : ~0,03 ms par image à 60 images/s) |
| Image en fenêtre 1600×900, voile compris, 8 héros qui se battent sur le Bourg (`--assault-perf`) | médiane **6,06 ms**, 90e 7,99 à 9,63 ms (3 370 images) : **dans le budget de 8 ms** |
| Sans fenêtre, même machine : Bourg (murs + vision) / arène d'essai (vision seule) | 9,09 ms / 9,26 ms de médiane : les murs et la perception ne se voient pas dans le temps d'image |
| Référence : Arène 3 contre 3 (6 héros, mode existant), même machine, sans fenêtre | 69 à 77 images par seconde (13 à 14 ms) |

Les temps « scripts » et « physique » des moniteurs de Godot sont faux sur une machine saturée (ils dépassent la durée de
l'image) : seule la durée réelle des images et le temps propre de la vision sont retenus. À refaire au calme :
`world.tscn -- --assault --autoplay --assault-perf --quit-at=60` (ligne `[assault] perf`).

**Captures regardées** (fenêtre 1600×900, `--shots`, et `--assault-veil-dump=N` qui enregistre la texture du voile) : premier
essai, le voile ne se dessinait pas (texture noire : un polygone « étoilé » à sommets presque confondus ne se triangule pas,
`Polygon2D` n'affichait rien, tout l'écran était voilé d'une trame légère) → éventail de triangles autour du héros ; ensuite,
derrière la halle la rue est voilée et tramée, le côté vu reste net, la face du mur qu'on voit n'est pas voilée. Les arcs
« Voir les sons » des adversaires déjà en vue encombraient le héros → seuls les bruits d'auteurs non vus (et la Charge) font un arc.

Suite de non-régression : voir § 6.

## 5. Pièges

1. Tout ajout de règle de vue ou de coup passe par `AssaultVision` et reste gardé par `AssaultVision.current` : hors Assaut,
   `blocks_*` rend faux, `filter_seen` rend la liste telle quelle, `perceives` vrai (contrôlé en tête de `test_tac2`).
2. Les rayons ne lisent que les couches `SIGHT` / `SHOT` (jamais le relief) ; une barricade (lot TAC-5) est un corps
   `SIGHT | SHOT | PHYS_WORLD`, une brume une entrée de `smokes` (2D), pas un corps.
3. Le voile n'existe qu'avec une fenêtre (SubViewport + quad) ; sans fenêtre (tests), `visibility_polygon` reste appelable.
4. `Node3D.visible = false` sur un héros caché : un outil qui compte les héros visibles doit lire `AssaultVision`, pas `visible`.
5. Un scripté sans cible en vue rejoint `goal` ; sans `goal` il attend : l'agent du lot TAC-6 doit toujours lui donner un poste.

## 6. Non-régression

Copie propre de HEAD 0.1.299 + TAC-2 (`run_tests.py --reuse -j 2`, machine saturée) : **14 verts sur 14** — test_tac2, test_tac0
(désormais avec la vision : l'arène d'essai n'a pas de murs, la portée de 22 m joue), test_tac1, test_mode0, test_pvp,
test_duel_modes, test_m7, test_royale, test_nav_screens, test_texts_fr, test_hud2 (HUD touché), test_siege et test_m2 (télégraphes
des boss et des scriptés : la garde `AssaultVision.current` ne change rien hors Assaut), test_br2 (projectiles). `check_scripts.py`
vert sur l'arbre du commit (HEAD 0.1.301 + TAC-2). Mesure du test : `[tac2] tour de vision : médiane 0.24 ms, 90e 0.39 ms, max 7.62 ms (86 tours, 619 rayons) ; image (process + physique) : médiane 55.07 ms, 90e 82.58 ms`.

## 7. Ce qui reste (lots suivants)

- **TAC-6** (IA d'équipe) : carte de croyance (dernières positions + bruits, étalés le long du maillage), aller voir un bruit,
  tenir les postes (`positions` des cartes) ; l'agent provisoire actuel ne fait que rejoindre son poste quand personne n'est en vue.
- **TAC-7** (HUD) : la colonne de gauche du HUD commun affiche encore le chrono et les sceaux de la Survie (« 10:00 », « Sceaux »)
  en mode d'équipes (piège 2 de R_MODE0) ; contour fraise « vu par … » des adversaires vus par un allié ; radar d'équipe.
- **TAC-4** : effets de sorts plein écran (captures : la mêlée cache les héros) — atténuation des effets des autres par défaut.
- Effets (EdenFx) et chiffres de dégâts d'un adversaire caché restent visibles : à couper pour un héros non vu (TAC-7).
- Marche silencieuse (Maj / clic du stick, 55 % de la vitesse) : le bruit des pas suit déjà la vitesse (sous 4,2 m/s, aucun
  bruit) ; la touche de marche viendra avec les réglages du mode (TAC-13).
