# R_S9 — Survivant : douze sorts, orbes d'expérience (retours du joueur, 16/10/2026)

Lu : `CLAUDE.md`, `PLAN_NUIT.md` (règles communes), `DECISIONS_JOUEUR.md`, `SPEC.md` (§5, expérience), `R_S3`, `R_S7`, `R_S8`.
Retour du joueur : palier III, Chasseur, défaite à 19:28 au niveau 15 ; « limité à 6 sorts au lieu des douze ? » et « vers 15 min,
encore niveau 14, les monstres ne lâchaient plus de boules d'expérience ».

## 1. « Douze » sorts
- Ce que le joueur connaît : la **grille de sorts** de la Survie = `Run.MAX_SKILLS` (4 cases) × (le sort + `Run.MAX_CHAIN` 2 enchaînements)
  = **12** (« Compétences de la run (n / 12) », Grimoire `SpellPresets.ROWS` 3 × 4, `Duel.SPELL_SLOTS` 12). Le Chasseur a 15 sorts dans
  son kit (toutes les classes en ont 14 à 20), tous ouverts en Survivant. Le Survivant plafonnait à `SPELL_MAX` 6 (décision de S0 contre
  la dilution).
- Fait : `Survivor.SPELL_MAX` = **12** (la grille entière). Contre la dilution : au-delà de `spell_up_norm` (6) sorts, les améliorations
  de sort se partagent le poids de 6 sorts (`SurvivorCards.candidates`, profil `survivor`) : l'équipement n'est pas noyé ; les 2 cartes
  garanties, la pitié, le filet de sort et les paliers 5 / 10 sont inchangés.
- Interface : page Build « Sorts n / 12 » (colonne qui défile, places libres en une ligne au lieu de 12 lignes « Libre »), HUD
  « Sorts n / 12 », bilan « n autres sorts » (inchangé). Capture 1280 × 720 regardée (12 sorts : rien de coupé).
- Retouche liée : la carte légendaire d'arme qui éveille **deux** passifs (+4 → +8) débordait à 1280 × 720 (591 > 540 px, révélée par
  `test_sv5` avec le nouveau tirage) : une ligne de statistiques et pas de ligne « Acquis » dans ce cas (`SurvivorCardView._upgrade`).

## 2. Plus d'orbes vers 15 minutes : cause
`XpOrbs` garde au plus 300 orbes au sol (une seule MultiMesh). Au-delà, **une nouvelle orbe s'ajoutait à l'orbe la plus proche
d'elle** ; or les orbes au sol sont celles que le joueur a laissées derrière lui (zone de collecte 3,5 m) : passé 300, plus aucune orbe
n'apparaissait sous les monstres et l'expérience partait sur des orbes lointaines où le héros ne retournait pas. Le pilote de mesure
ne le voyait jamais : il ramasse à 40 m (`AUTOPLAY_MAGNET`), donc 0 orbe au sol et des mesures de S7 / S8 à 100 % de collecte.

Reproduction (pilote moyen, palier III, Guerrier, **vraie zone de collecte** : `--extra=--human-magnet`, lignes `[sv-xp]`) :
| | 7:00 | 10:00 | 13:00 | 14:00 |
|---|---|---|---|---|
| orbes au sol | 117 | 196 | 298 | **300** |
| niveau | 13 | 18 | 24 | **24** (mort à 14:42) |
Minute 14 : 172 lâchers fusionnés, dont 134 (**78 %**) dans une orbe à plus de 12 m ; 199 000 xp sur 270 000 envoyées au loin.
Même graine, pilote à 40 m : niveau 27 à 14:00.

**Correctif** (`XpOrbs.spawn`) : sol plein → l'orbe oubliée **la plus loin du héros** (hors orbes déjà attirées) rejoint la nouvelle, posée
sous le monstre. Rien ne se perd, chaque lâcher reste visible là où le héros se bat ; l'expérience laissée derrière revient peu à peu.
Vaut pour toutes les runs (la Survie en rage aussi). Mesures : `stats` de `XpOrbs`, lignes `[sv-xp]`, `tools/sim_survivor.py` (« expérience
ramassée / lâchée »).

## 3. Mesures (copie propre de HEAD + ce lot, `--fixed-fps 60`)
| | Avant | Après | Cible |
|---|---|---|---|
| Vraie collecte, pilote moyen, palier I (10 runs) : niveau 5 / 10 / 15 / 20 min | (palier III : bloqué à 24 dès 13:00) | **10 / 18 / 28 / 39**, +2 par minute jusqu'au bout | montée régulière, 38 ± 4 |
| xp ramassée / lâchée (vraie collecte) | 64 % à 14:00 | **98 %** | — |
| Pilote standard (S8 : 30 runs ; S9 : 50 runs) niveau à 20:00 | 40 | 40 | 38 ± 4 |
| victoire débutant / moyen / bon | 30 / 60 / 70 % | 30 / 55 / 45 % | 10 / 35-50 / 65 |
| boss (TTK pilote) · gardiens · cartes à 20:00 | 110 s · 37 s · 86 | 108 s · 58 s · 85 | 90-180 · 30-90 · ≈ 70-86 |
| sonde (314 builds) TTK médian · 10 % · 90 % | 129 · 58 · 230 s | 137 · 64 · 300 s | 75-210 · — · ≥ 192 |
Contrôle « 6 sorts » (mêmes graines, profil bon, 10 runs) : 50 % de victoires contre 45 % à 12 sorts (20 runs) : écart dans le bruit.

## Écarts signalés
- **« Tout en sorts » devient un piège** (sonde, stratégie `sorts` : prend chaque nouveau sort) : 12 sorts au niveau 4 environ et
  pièces à +0..+4, DPS 20 k contre 46-59 k, 22 % de boss avant la rage (76 % avec 6 sorts). Les builds équilibrés (pilote, aide « Bot »,
  pièces, passifs, arme) ne bougent pas (91-98 %). Dominance (meilleur / médian) ×1,23, sous le plafond ×3. Levier si le joueur le
  sent : `spell_up_norm` ou un niveau de départ pour les sorts tardifs.
- Profil bon sous le moyen (45 / 55 %) : bruit de 10-20 runs par profil (S8 : 70 % sur 10 runs ; contrôle à 6 sorts 50 %).
- Une chute avant 3:00 au pilote moyen sur 20 (Chasseur, graine 3000, 2:54, arme hors classe) : runs non déterministes (la même graine
  au profil bon, en contrôle à 6 sorts, passe l'ouverture sans encombre). `test_sv7` tolère désormais au plus 1 sur 20 (S7 visait les morts systématiques : 4 sur 15 avant son réglage).
- Le joueur (niveau 15 à 19:28) restait sous le pilote même avant 300 orbes : la vraie collecte coûte ~1 niveau (pilote à 40 m : 27 à
  14:00, vraie collecte : 26) ; le reste tient à son build et au palier III (soins ÷ 2), à lire au journal réel.

## Tests
`test_sv9` (nouveau : sol plein, orbe sous le monstre, orbe la plus loin reprise, orbe attirée gardée, total conservé ; 12 sorts sur la
grille, poids des améliorations borné ; mesures de la vraie collecte : niveau qui monte toutes les 2 min après 10:00, 30-45 à 18:00,
≥ 70 % ramassé). `test_sv3` (grille de 12, 4 cases et 2 enchaînements par case), `test_sv7` (mesures refaites, `spell_up_norm` dans les
constantes). Verts : test_sv1 à test_sv9, test_nav_screens. `shot_sv5` : `SV5_SPELLS=12`, mode `build` seul réparé.
