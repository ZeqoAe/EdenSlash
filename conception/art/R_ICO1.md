# R_ICO1 : pictogrammes d'interface maison (département Icônes, 17/10/2026)

Décision du joueur (`ORGANISATION.md` règle 3) : les icônes et assets du jeu de base (sorts, objets, classes, statuts d'Eden,
illustrations) sont **gardés**. Ce lot ne crée que ce qui **manquait** : tout pictogramme d'interface remplacé par un texte, un emoji,
un symbole Unicode, un pictogramme blanc générique ou une forme dessinée par code. Planche : `conception/art/ico/planche.jpg`
(176 pictogrammes, chacun à 64 px sur papier puis à 24 et 16 px sur puits d'encre). Test : `tests/test_ico1.tscn`.

## 1. Audit (ce qui manquait)
Relevé fait sur `game/scripts/` (symboles hors police du jeu dans les chaînes : 15 signes ≥ 10 occurrences) et sur les tables de données.

| Manque constaté | Où | Remplacé par |
|---|---|---|
| Coche `✔` (47), croix `✘ ✕ ✗` (19) en texte | listes de conditions (duel, Héros prêt), rangées d'objectifs, boutons de difficulté | `check`, `cross`, `quest_done` / `quest_todo` |
| Cadenas `🔒` (33, **emoji hors police : repli sur la police du système**) | boutons verrouillés (Jouer, Donjons, Survivant, classes), infobulles BBCode, cartes de talents | `lock`, `unlock` |
| Étoile `★ ☆` (106) pour succès, objectifs, étoiles d'époque, rangs d'unités | Carnet, bilans, Donjons, Échiquier | `star`, `star_empty`, `goal` (fanion d'objectif suivi), `res_star` |
| Losanges `◆ ◇` (49) pour étapes de quête, sceaux, gardiens, panoplies | Aujourd'hui, Journal, HUD | `quest_done`, `quest_todo`, `gem`, `gem_empty` |
| `▲ ▼` (43) mieux / moins bien, `⚔ ☠ ⚖ ⏳ ⚠ ✝ ♛ ✶ ✦ ● ○ ▶` | fiche d'objet, HUD, Menace, Pacte, chute, record | `cmp_up`, `cmp_down`, `swords`, `skull`, `scales`, `hourglass`, `alert`, `grave`, `crown`, `spark` |
| « ! » nouveau, `i`, `?`, `+`, `⇄`, `↻`, signet « suivre », flèches `→ ›` ▾ | pastilles, aide, boutons | `new`, `info`, `help`, `plus`, `swap`, `refresh`, `follow`, `arrow_right`, `chevron_right`, `chevron_down` |
| Ressources et monnaies : **pictogrammes blancs génériques** (insignes = flèche, plans = « equipment », pièces = « armor », panoplies = coffre, Esprits = silhouette de classe, maîtrise, apparences, titres = personnage, rangs = courbes, étoiles = « new », cartes = grimoire) | `ResourceHelp` : pastilles de gains, bourse, infobulles, bilans | `res_insignia`, `res_plan`, `res_piece`, `res_panoply`, `res_spirit`, `res_mastery`, `res_look`, `res_title`, `res_rank`, `res_star`, `res_card`, `res_level`, `res_pe`, `coin`, `heart`, `mana` |
| Activités sans pictogramme (cartes illustrées seulement) | Journal, boussole, bilans, listes | 15 `act_*` : Survie, Survivant, Donjons, Tour, Quêtes, Ruée, Siège, Duel, Arènes, Battle royale, Échiquier, Entraînement, Ligue, Panthéon, Gantelet |
| Rangs de la Ligue, difficultés N / H / M, médailles | rangées de la Tour (`heart`, `defense`, `attack`, `power` génériques), Donjons, Panthéon | `rank_0..4` (Non classé, Bronze, Argent, Or, Platine), `diff_normal` / `diff_heroic` / `diff_mythic` |
| Familles de classes : seulement des couleurs | sélecteur, Échiquier | `fam_rempart`, `fam_ombre`, `fam_traque`, `fam_ferveur`, `fam_arcane` |
| Résultats : titres seuls | bilans | `res_win`, `res_lose`, `res_draw`, `res_record`, `res_flee` ; quêtes : `quest_daily`, `quest_contract`, `quest_achv` |
| **Mécaniques de boss** : la barre de boss, la frise « À venir », le journal rendent les 29 briques de `ai/boss_bricks.gd` avec 10 icônes d'état **partagées** (`shock` pour Rayons et Balayage, `haste` pour Ruée, Bond et Charge, `keen` pour Tourelles, Éventail, Marque et Tir, `stun` pour Damier, Ondes et Frappes…) : deux mécaniques différentes ne se distinguaient pas | `BossBar.icon_of` (barre, pastilles, annonces, « Ce qui t'a battu », page Donjons) | 36 `boss_*` : les 29 briques + `slams`, `charge`, `cleave`, `barrage`, `nova`, `phase2` (fureur) + `boss_hit` (coup sans nom) |
| Statuts **sans aucune icône** quand ni le jeu ni une classe n'en fournit (`StatusDb.icon` rendait `null`) | HUD : pastilles de buffs et debuffs | `st_root`, `st_sleep`, `st_fear`, `st_disarm`, `st_thorns`, `st_titan`, `st_survival`, `st_might`, `st_swift`, `st_grace`, `st_vitality`, `st_hunter_stance`, `st_angel`, `st_resolve`, `st_bleed` (en dernier recours seulement : une icône d'Eden garde la priorité) |
| Touches de manette dessinées **par code** (disques de couleur + lettre, ronds / croix / carrés dessinés au trait) | barre d'aide de `UiNav` | `pad_a/b/x/y`, `pad_cross/circle/square/triangle` ; en réserve : `pad_lb/rb/lt/rt`, `pad_l1/r1/l2/r2`, `pad_stick`, `pad_dpad`, `pad_menu`, `key_cap`, `key_wide`, `key_mouse_l/r/wheel` |
| Silhouettes d'emplacements : une pièce d'objet au hasard à 35 % dans les cases vides | poupée de l'inventaire | `slot_weapon`, `head`, `chest`, `legs`, `gloves`, `boots`, `back`, `necklace`, `ring`, `trophy`, `offhand` |
| Raretés : couleur seule | filtres, listes | `rar_0..5` (gemmes de la couleur de chaque rareté, Légendaire étincelant) |
| Mode scellé : texte seul | Survivant, Battle royale, Échiquier | `mode_sealed` (sceau de cire) |

Ce qui existait déjà et **n'est pas refait** : icônes de sorts, de talents, de classes, d'objets, de potions, d'états (15), de
trophées (`make_trophy_icons.py`), matériaux de forge (cristaux, parchemins, gemmes, formules, pierres), curseurs.

## 2. Style (bible § 1, 5, 9)
Autocollant d'encre et de bonbon, comme les icônes d'état du jeu : contour d'encre `#221A3A` (3,5 px à 64 px), deux tons nets du
bonbon (`bonbon.*.base` / `fonce`, dégradé à bord franc), reflet blanc, ombre dure décalée de (4, 5) sur 128. Trois familles :
- **tile** (65) : tuile arrondie bonbon + symbole blanc contouré d'encre (activités, ressources, rangs, familles, résultats, statuts) ;
- **glyph** (64) : forme libre qui se pose en ligne dans un texte (coche, cadenas, étoile, touches, raretés) ;
- **sym** (47) : symbole blanc contouré d'encre sans tuile, ombre dure : la pastille de la barre de boss lui donne la couleur de sa
  famille (`BossBar.chip`) ; les silhouettes d'emplacements se teintent à l'usage.
Rien n'est repeint ni copié depuis une image tierce : formes calculées (polygones, courbes, arcs, étoiles) dans `tools/art/`.

## 3. Fabrication (reproductible)
```
python tools/art/ico_gen.py                  # tout : SVG, PNG 128 et 64, manifeste, planche
python tools/art/ico_gen.py --only check,lock --no-sheet
```
`ico_core.py` (jetons de `tokens.json`, géométrie, dessin SVG, registre) · `ico_kit.py` (autocollant, symboles, épée, cœur, écu,
flamme, gemme) · `ico_defs_a.py` (signes), `ico_defs_b.py` (tuiles), `ico_defs_c.py` (boss, emplacements, touches, raretés) ·
`ico_render.gd` (rasterisation par le moteur, ThorVG : aucune bibliothèque de plus, aucune police) · `ico_sheet.py` (planche).
Sorties : `conception/art/ico/svg/ico_<id>.svg`, `game/assets/ui/icons/ico_<id>.png` (128 px) et `ico_<id>_64.png` (64 px),
`ico_manifest.json` (id, famille, description). Les `.import` sont ignorés par git dans ce dossier (`.gitignore`) : un `--import` les crée.
**Ajouter un pictogramme** : une fonction `@icon("id", "tile"|"glyph"|"sym", "bonbon", "Groupe", "description")` dans un `ico_defs_*.py`,
relancer `ico_gen.py` puis `Godot --headless --path game --import`, ajouter l'id à `test_ico1` s'il est indispensable.

## 4. Branché dans le jeu (éditions minces, aucune logique changée)
API : `ui/ico.gd` (`Ico.tex(id, px)` : version 64 px sous 48 px d'affichage, `Ico.rect`, `Ico.mark`, `Ico.lock` / `Ico.state` pour un bouton,
`Ico.of_boss`, `rank`, `difficulty`, `rarity`, `slot`, `Ico.LOCK_BB` pour le BBCode ; id inconnu : `null`, l'appelant garde son texte).

| Où | Quoi |
|---|---|
| `ResourceHelp` (pastilles de gains, bourse, bilans, boussole, Donjons, Fabriquer) | 11 ressources : pictogrammes `res_*` en couleurs (`icon: "ico:res_…"`) à la place des blancs génériques |
| `BossBar.icon_of` | un pictogramme par mécanique (barre, frise, journal, page Donjons) ; repli : l'ancienne icône d'état |
| `StatusDb.icon` | dernier recours `st_<effet>` : plus aucun effet d'état sans icône |
| Aujourd'hui, Journal des quêtes (2 pages), cartes de série, coffres d'apparence de l'Échiquier et du Survivant | `quest_done` / `quest_todo` à la place de `◆ ◇ ✔` |
| Conditions du duel (Héros prêt, file) | `check` / `cross` à la place de `✔ ✘` |
| Lobby (difficultés de l'Échiquier, onglets du Duel, paliers du Survivant, Donjons, Siège, Ruée), page Donjons, sélecteur de classes | cadenas (et coche « fait ») en icône de bouton à la place de l'emoji `🔒` |
| Infobulles BBCode : classe, grimoire, Guide, cartes, talents ; cartes de talents | cadenas par `[img]` ; `Ico.rect` sur la case |
| Carnet > Succès | `star` / `star_empty` |
| Tour (choix de la difficulté) | médailles Bronze à Platine (`rank_1..4`) à la place de 4 pictogrammes génériques |
| Poupée de l'inventaire | silhouette d'emplacement dans les cases vides (les armes gardent l'arme de la classe) |
| `UiNav` (barre d'aide manette) | touches A B X Y et croix / rond / carré / triangle en pictogrammes (les pastilles LB / RB restent du texte) |

## 5. Créé, pas branché (à prendre par les équipes d'écran)
Pour ne pas toucher des écrans en chantier ou en équipe (HUD, Survivant, Battle royale, Échiquier, Fiche d'objet) :
- `act_*` (activités), `fam_*` (familles), `rank_0`, `diff_*` dans les listes de Donjons, `res_win` / `res_lose` / `res_record` dans les bilans,
  `rar_*` dans le filtre de rareté, `pad_lb` à `pad_menu` et `key_*` dans la barre d'aide et le panneau « Touches ».
- Symboles restés **dans le texte** (lignes, BBCode, étiquettes en `draw_string`) : `★ Objectif`, `✔ Héros prêt`, `◆ ◇` des listes du HUD et du
  Survivant, `▲ ▼` de la fiche d'objet, `⚔ ☠ ⚖ ⏳ ⚠ ✝ ♛` du HUD (Menace, Pacte, chrono, Donjon, Siège) : ils s'affichent avec les signes
  de la police du jeu, sauf `⚔ 🔒 ⏳ ☠ ⚖ ⚠` qui tombent sur la police du système. Un `Label` ne porte pas d'image : il faut une rangée
  `Ico.mark` + `Label` (comme fait ici) ; `RichTextLabel` : `[img=16]`.
- `ItemSlot` dessine encore par code le cadenas, l'étoile d'objectif et « neuf » : `Ico.tex("lock" | "goal" | "new")` se pose avec `draw_texture_rect`.
- Cartes du Survivant et du Battle royale (`survivor_cards.gd`, `survivor_build_page.gd`, `royale_page.gd`) : leurs `🔒` (en cours de refonte par
  d'autres équipes) sont à passer à `Ico.lock` / `Ico.LOCK_BB`.

## 6. Contrôle
`test_ico1` : chaque pictogramme du manifeste existe en 128 et 64 px, à la bonne taille, importé, coin transparent, non vide ; les 29
briques de boss et les 6 attaques de base ont leur pictogramme ; aucune ressource sans icône en couleurs ; aucun statut de `Combatant.STATUS_INFO`
sans icône ; API `Ico` ; touches de manette ; aucun `🔒` dans les écrans branchés. Aussi verts : `test_nav_screens`, `test_pages`,
`test_texts_fr`, `test_uik0`, `check_scripts`.

## Reste
- Relecture par le joueur de la planche : en particulier `refresh`, `boss_turrets`, `boss_leap`, `act_rush` (le plus « dessiné à la main »).
- Un deuxième passage par un illustrateur pourrait doubler la finesse (reflets, matières) ; le style est volontairement simple et net
  pour rester lisible à 16 px.
