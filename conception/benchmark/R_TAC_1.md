# R_TAC_1 : format de carte de L'Assaut et « Le Bourg aux lanternes » (lot TAC-1, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.9 et plan masse `tactique_maquettes/plan_bourg.svg`. Socle : `R_TAC_0.md`.

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Format de carte | `game/data/assault_maps/<id>.json` | carte faite à la main en mètres du plan : murs pleins (`walls`, maisons à toit ou murs), bords (`edges`), murets (`low`), décor qui arrête les coups (`props` : fontaine), terrasses et leur rampe (`heights`), hautes herbes (`grass`), sites (`sites` : rectangle + point de pose), départs (`spawns`), point du Sanctuaire (`sanctuary`), noms des lieux (`places`), postes de l'IA (`positions` : point, angle à tenir, côté, site), trajets de référence du plan (`routes`) |
| Le Bourg | `game/data/assault_maps/bourg.json` | relevé du plan masse (7,6 px par mètre) : 12 murs pleins + une statue, 10 murets, fontaine, terrasse du beffroi (+3 m) et balcon (+2,5 m) avec rampes de 8 m, jardin et saules en hautes herbes, sites A et B, 16 lieux nommés, 11 postes d'IA |
| Construction | `game/scripts/world/assault_map.gd` (`AssaultMap`) | carré du monde (aire de jeu centrée, falaises autour), sol plat, rues pavées, sites en terre battue ; maisons (pierre + toit à deux pans aux couleurs bonbon adoucies), murets, terrasses, rampes (prisme exact), fontaine, herbes, lanternes ; collisions sur des couches dédiées (`SIGHT` 512 = arrête la vue, `SHOT` 1024 = arrête les coups ; murs : les deux, murets et fontaine : coups seulement, terrasses : déplacement seul) ; mini-carte avec murs, murets, terrasses et sites ; navigation cuite ; `floor_at` (sol praticable sur les terrasses et rampes), `place_name` (lieu le plus proche), `to_world` / `to_plan` |
| ProcMap | `game/scripts/world/proc_map.gd` | `generate_assault(id)`, `assault` (description pour le directeur), `floor_at` |
| Directeur | `game/scripts/core/assault_director.gd` | carte `bourg` (`--assault-map=bourg` ; option `map` de la partie) : sites en rectangle (`site_at`), repères au sol à la forme du site (livré avec TAC-0) |
| Aperçu | `game/tools/assault_map_shots.tscn` | `godot --path game res://tools/assault_map_shots.tscn -- bourg --res=1600x900` : mini-carte (aussi sans fenêtre), vue d'ensemble de dessus, vues à l'angle de la caméra de jeu (départs, sites, lieux), sites / départs / lieux posés au sol |
| Test | `game/tests/test_tac1.tscn` | données, construction, couches de physique, hauteurs, navigation cuite avant la fin, trajets contre le plan, lieux et postes atteignables, mini-carte, partie réelle sur le Bourg |

## 2. Mesures (test_tac1, maillage de navigation, 6,5 m/s)

| Trajet | Mesuré | Plan | Écart |
|---|---|---|---|
| Attaque → A (point de pose) | 11,9 s | 12,5 s | −5 % |
| Attaque → B | 13,6 s | 11,3 s | +20 % (la statue de la fontaine fait faire un pas de côté) |
| Défense → A | 4,7 s | 4,5 s | +5 % |
| Défense → B | 6,1 s | 4,5 s | +35 % (le point de pose de B est au fond du site, derrière le muret du quai) |
| Rotation A ↔ B (allée du beffroi) | 8,9 s | 8,1 s | +9 % |
| Avance de la Défense sur l'Attaque | A : 7,2 s ; B : 7,5 s | règle 6 à 9 s | dans la règle |

- Terrasse du beffroi atteinte par sa rampe (fin du trajet à 3,5 m : le haut de la terrasse) ; tous les lieux nommés et les
  postes de l'IA atteignables depuis le départ de l'Attaque.
- Couches : un mur plein arrête la vue et les coups ; un muret laisse passer la vue et arrête un coup au sol ; depuis 3 m de
  haut on tire par-dessus un muret ; la fontaine arrête les coups, pas la vue ; le relief n'arrête rien (couches à part).
- Construction de la carte : 0,7 à 0,8 s (navigation cuite ensuite sur un fil).
- **Plus longue vue dégagée relevée : 96 m**, l'axe nord-sud qui passe sous la halle (le plan annonçait 24 m au plus : sa
  ruelle ouest ; le passage sous la halle, 4 m de large, ouvre un axe d'un départ à l'autre). Une statue au centre de la
  fontaine (1,2 m, mur plein) coupe l'axe exact (contrôlé par le test) ; les lignes de biais restent ouvertes (96 m relevés
  encore). **À reprendre au lot TAC-10** (révision des cartes avec les
  données de l'IA) : soit une porte de halle fermée qui coupe la vue mais pas le passage (barricade permanente), soit un étal
  sur la place ; décision après les premières parties mesurées (TAC-9), où l'on verra si l'axe sert de « stand de tir ».

## 3. Captures regardées (1600×900, `assault_map_shots`)

Vue d'ensemble : les deux sites, la halle et son passage, la place et sa fontaine, les deux maisons longues, le jardin et les
saules, les quatre maisons d'angle, les départs (lagon au nord, mandarine au sud). Corrections faites en regardant : toits
invisibles (sens des faces : Godot tient la face avant en sens horaire) puis trop vifs (aplats d'interface) → tuiles teintées
de la couleur bonbon adoucie vers la terre cuite ; rampes vues des deux côtés. Reste pour le lot TAC-14 (revue DA) : maisons
encore en pavés (pas de façades ni de portes), rues un peu nues, lanternes discrètes, terrasse en marbre clair.

## 4. Pièges

1. Les terrasses et rampes sont des **corps** (pas du relief) : `ProcMap.height_at` ne les voit pas ; passer par
   `floor_at(x, z)` (directeur : `_ground`).
2. Navigation : cuite sur un fil comme toute ProcMap (piège T1) — attendre `map._region.navigation_mesh` avant `quit()` ; les
   rampes passent (pente 21° < 40°), les bords de terrasse non (3 m > montée 0,75 m).
3. Un rayon de vue ou de tir ne lit que sa couche (`AssaultMap.SIGHT` / `SHOT`), jamais `PHYS_WORLD` (sinon le relief et les
   corps des héros comptent).
4. Les nombres du JSON sont des flottants (`[84, 100]` relu vaut `[84.0, 100.0]`) : comparer avec `int()`.
5. Un lieu nommé doit être hors des murs (le test le vérifie) : la « Halle » est au pied de la halle, le « Passage » dessous.

## 5. Non-régression

Copie propre de HEAD 0.1.298 + TAC-1 (`run_tests.py --reuse -j 2`) : **test_tac1, test_tac0, test_mode0, test_co_b (cartes du
Colisée, même ProcMap), test_royale, test_texts_fr : 6 verts**. `check_scripts.py` vert sur l'arbre du commit.
