# R_SVX1 — Survivant : la horde (SV-H1) et la lisibilité du chaos (SV-H2) (17/10/2026)

Lu : `CLAUDE.md`, `PLAN_NUIT.md` (règles communes), `conception/benchmark/SURVIVANT.md` (§1, §5, §6 P0, §7, §8), `SPEC.md` (tête),
`DECISIONS_JOUEUR.md`, `R_S1` à `R_S9`, `conception/art/BIBLE.md` (§3, §10). Mesures sur des copies propres de HEAD + ce lot
(`tools/run_tests.preparer_copie`), machine partagée avec d'autres sessions (charge forte : les temps absolus sont gonflés,
les comparaisons sont faites deux à deux dans les mêmes conditions).

## 0. Mesure d'avant (HEAD 0.1.256-0.1.259)
Densité réelle (nouvelle ligne `[sv-dens]` de `SurvivorDirector` : chaque seconde, monstres à moins de 15 m, à l'écran, vivants ;
moyenne / maximum par minute), pilote moyen avec la vraie zone de collecte (`--human-magnet`), 5 classes, palier I :

| minute | 1:00 | 2:00 | 3:00 | 5:00 | 10:00 | 15:00 | 19:00 | 20:00 |
|---|---|---|---|---|---|---|---|---|
| à moins de 15 m (moy. / max) | 3 / 16 | 5 / 21 | 6 / 29 | 8 / 31 | 11 / 40 | 22 / 50 | 30 / 57 | 37 / 56 |
| vivants sur la carte (moy.) | 8 | 14 | 16 | 25 | 37 | 44 | 60 | 63 |

L'étude avait raison : pas de horde. Causes trouvées dans le code : `RunDirector.MAX_ALIVE` (80 en exploration) bornait le Survivant
sous son propre plafond (110) ; les plafonds par rôle de `SpawnDirector.ROLES` (81 monstres en tout) ; arrivées à 24-31 m, hors de la
vue ; meutes de 3 toutes les 6 s au départ.

Coût (banc `tools/svx1_bench.tscn`, 250 monstres serrés autour d'un héros immobile) : l'**écartement** entre monstres
(`Monster._separation`) coûtait 20 ms par image physique dans une foule dense (chaque monstre regardait ~200 voisins),
l'**animation** 10 ms, `move_and_slide` l'essentiel du reste.

## 1. Horde (SV-H1)
- **Densité** (`core/survivor.gd`, profil `survivor` de `ModeRules`) : vivants 30 → 230 sur 20 min, **290 pendant la horde finale**
  (19:00) ; meutes toutes les 2,5 → 0,8 s de 6 → 16 ; vagues 40 → 22 s, budget × 1 → 2 ; plafond du directeur = plan + 40
  (`SurvivorDirector.hard_cap`, crochet d'une ligne dans `RunDirector._hard_cap`) ; plafonds par rôle × 3,5 (`SpawnDirector.role_cap_mult`).
- **Plus petits** : monstres ordinaires × 0,6, élites × 0,85, et jamais plus hauts que 0,8 × le héros (`Monster.lite_height`, mesuré
  sur l'os le plus haut du squelette : les boîtes des maillages d'Eden sont couchées) ; caméra × 1,2 en Survivant (molette libre).
- **Qui convergent, annoncés** : escouades à 13-19 m (à l'écran) au lieu de 24-31 m ; chaque monstre est annoncé par une **croix
  mandarine contourée d'encre** au sol 0,8 s avant (`world/spawn_mark.gd`, `SpawnDirector.mark_time` ; mandarine = arrivée, la fraise
  reste aux attaques).
- **Coût** : monstres ordinaires « lite » (`Monster.lite`) : sans `move_and_slide` (position intégrée, posée sur le relief), écartement
  borné à 8 voisins une image sur 2, animation avancée à la main une image physique sur 2 (4, 8 au loin) ; niveaux de détail
  (`Monster.lod`) : les 40 plus proches à moins de 6 m réfléchissent à chaque image, une sur 2 jusqu'à 18 m, une sur 4 au-delà ;
  ombres coupées au-delà de 16 m. Aucune instanciation par lots ni imposteur : la mesure ne l'a pas exigé (§3).
- **Le héros traverse la horde** (`SurvivorDirector._soft_body`) : un monstre ordinaire ne bloque plus le héros (il est repoussé hors de
  son corps) ; élites, géants et boss le bloquent toujours. Sans ça, dans une foule de 60 monstres, le pilote ne rejoignait plus les coffres.
- **Gardien en vie** : la horde se calme (plafond × 0,5, moitié moins de meutes, pas de vague) ; le pilote de mesure va combattre le
  gardien (`pilot_target`) : sans ça il frappait la horde qui l'entoure (gardiens en 120-300 s au lieu de 30-90).
- **Compensation** (la courbe par minute, la puissance selon l'équipement, les paliers et le boss ne changent pas) : part de
  chaque monstre ordinaire PV × 0,45, dégâts × 0,6, expérience × 0,33, or et potions × 0,25 (`HORDE_SHARE`) et **places d'attaque** :
  au plus 2 (0:00) → 12 (20:00) monstres frappent en même temps, les autres attendent au contact (`Monster.attack_slots`).
  La horde nourrit le héros (niveau 12 à 5:00 au lieu de 10) : **gardiens 2 et 3 × 2** (440 000 / 1 400 000 ; battus en 10-30 s sinon),
  le gardien 1 reste à 50 000 (× 2, il tuait le joueur moyen vers 6:00). Ouverture : 1re meute à 3 s, 1re vague à 1:00.

## 2. Lisibilité (SV-H2)
- **Nombres** (`combat/damage_number.gd`, Survivant seulement) : un seul nombre par cible, qui additionne les coups et grossit (texte
  remis à jour toutes les 0,15 s au plus), s'efface 0,7 s après le dernier coup ; 30 à l'écran au plus ; pas de nombre nouveau sur la
  place d'écran d'un autre (78 × 34 px) ; « EXÉCUTÉ » devient une croix fraise ; les dégâts subis par le héros, fusionnés aussi, en
  fraise, à gauche et au-dessus de la mêlée.
- **Effets des sorts du héros** à 40 % d'opacité au plus (`EdenFx.opacity`, paramètre `opacity` du shader, alpha prémultiplié : la forme
  ne change pas), 12 % de moins par effet du héros déjà à l'écran, × 0,6 avec « Réduire les effets » (étincelles réduites ou coupées,
  animations réduites) ; dessinés sous les télégraphes ennemis ; arcs et ondes (`Vfx`) du héros au même plafond. Télégraphes
  ennemis jamais touchés (BIBLE §10).
- **Héros toujours contouré** (`world/hero_outline.gd`, `shaders/hero_outline*.gdshader`) : passe de gabarit (stencil) sur la
  silhouette puis liseré lagon clair de 2,5 px à l'écran, par-dessus monstres, boss, effets et décor.
- **Décor tramé autour du héros** : dans 4 m, au-dessus de ses pieds, le décor (`eden_object.gdshader`, paramètre global `hero_fade`,
  0 hors Survivant) est tramé à moitié.
- **Barre de cible** : seulement pour les élites, géants, gardiens et boss (`SurvivorDirector.shows_target_bar`, une ligne dans `ui/hud.gd`).

## 3. Mesures après
**Coût** (banc `svx1_bench`, `--headless --fixed-fps 60` : temps CPU d'une image de jeu, mêmes conditions, machine chargée) :

| cas | ms par image |
|---|---|
| Survie, 110 monstres serrés (héros immobile) — la référence | 31,5 |
| Survie, 110 monstres, héros qui se bat (morts et apparitions) | 39,6 |
| Survivant avant le lot, 250 monstres serrés | 64,3 |
| **Survivant après, 250 monstres serrés** | **28,9** |
| Survivant après, partie à 19:00 (horde finale) | 27,9 |
Rendu (fenêtre 1600 × 900, qualité haute) : GPU 2-5 ms à 250 monstres contre 3-7 ms pour la Survie à 110 ; 1 600 à 2 800 appels de dessin.
Le budget d'image reste sous celui de la Survie.

**Densité** (30 runs au pilote, palier I, `--pilot-fight 2`, moyenne / maximum de monstres à moins de 15 m du héros) :

| minute | 1:00 | 2:00 | 3:00 | 5:00 | 10:00 | 15:00 | 19:00 | 20:00 |
|---|---|---|---|---|---|---|---|---|
| avant (S9) | 3 / 16 | 5 / 21 | 6 / 29 | 8 / 31 | 11 / 40 | 22 / 50 | 30 / 57 | 37 / 56 |
| **après** | **11 / 24** | **28 / 49** | **32 / 58** | **38 / 70** | **39 / 81** | **45 / 98** | **69 / 99** | **84 / 199** |
Vivants sur la carte au pic : 290 (horde finale) ; le pilote, qui tue vite, en garde 100-200 près de lui à 20:00 (« à l'écran » : la
moitié en `--headless`, fenêtre factice ; en fenêtre, 95 % des monstres à moins de 15 m sont à l'écran avec la caméra × 1,2).

**Équilibre** (`tests/sv7_mesures.json` refait : 30 runs au pilote, 5 classes × 2 graines × 3 profils, et 10 runs du pilote moyen avec
la vraie collecte) :

| | S9 (avant) | **SVX-1** | cible |
|---|---|---|---|
| victoire débutant / moyen / bon | 30 / 55 / 45 % | **0 / 40 / 30 %** | 10 / 35-50 / 65 |
| niveau à 20:00 · durée d'une victoire | 40 · 21:54 | **40 · 21:25** | 38 ± 4 · ≤ 24:00 |
| gardiens (médiane) · boss (pilote) | 58 s · 108 s | **33 s · 79 s** | 30-90 · 90-180 |
| morts avant 3:00 (moyen) | 1 / 20 | **0 / 10** | ≤ 1 / 20 |
| vraie collecte : niveau à 10 / 15 / 18 / 20 min · ramassé | 18 / 28 / 35 / 39 · 98 % | **20 / 29 / 34 / 39 · 95 %** | montée régulière |
Le bon joueur sous le moyen et le débutant à 0 % : bruit de 10 runs par profil (lots intermédiaires : 20 / 50 / 60 %, 20 / 40 / 30 %) ;
les morts du débutant tombent autour du gardien 1 (5:00-7:30). Avant ce lot final, huit lots de réglage de 15 à 30 runs (densité de
l'ouverture, places d'attaque, part d'expérience, pilote qui se bat à 2 m, calme et PV des gardiens).

Captures regardées (vraie partie au pilote, 1600 × 900, `SVX1_SHOTS`) : 0:45 ≈ 12 monstres autour du héros (avant : 0), 2:30 ≈ 24-35
(avant : 4), 5:00 ≈ 34 (gardien : la horde se calme), 10:00 ≈ 70 ; nombres lisibles (un par cible, jamais l'un sur l'autre), sorts du
héros pâles, héros contouré, croix d'arrivée visibles, arbre près du héros tramé.

## 4. Tests
`test_svx1` (nouveau : plan de la minute, compensation, rien hors du Survivant, nombres fusionnés et plafonnés, croix, opacité, barre
de cible, vraie carte à 10:00 : densité, croix, places d'attaque, collisions, taille, niveaux de détail, ombres, contour, décor) ;
`test_sv4`, `test_sv7` lisent désormais les constantes de la horde ; `sv7_mesures.json` porte les réglages de la horde (`constants`). Verts (copie propre de HEAD + ce lot) : test_svx1, test_sv1 à
test_sv9, test_p15, test_p9, test_farm, test_hud, test_m3, test_royale, test_build, test_cards.

## 5. Reste / pièges
- Débutant 0 % et bon 30 % (cibles 10 et 65 %) : à lire au journal réel avant de retoucher ; leviers prêts (profil `survivor` de
  `ModeRules`, mode dev) : `horde_share`, `attack_slots`, `guardian_hp`, `GUARDIAN_CALM`.
- Monstres « lite » : ils traversent le décor si le chemin de navigation se trompe (rare) ; les élites, géants et boss restent physiques.
- Le banc et les copies de mesure : l'index git réel est souvent en retard sur HEAD (sessions qui commitent par un index temporaire) ;
  `run_tests.preparer_copie` retire alors des fichiers de HEAD pris pour « non suivis » : vérifier qu'une copie a bien tout HEAD.
- Le pilote se bat seulement à moins de 2 m (`sim_survivor.py --pilot-fight`, 4 avant) : à 4 m, dans une horde, il ne quittait plus
  la mêlée pour les coffres (5 pièces au lieu de 9 à 5:00).
- Les nombres « à l'écran » (`[sv-dens]`) sont faux en `--headless` (fenêtre factice) : seule la colonne « à moins de 15 m » vaut.
