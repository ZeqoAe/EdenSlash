# R_SVX2 — Survivant, interface v2 (17/10/2026)

Lot SVX-2 de l'étude `conception/benchmark/SURVIVANT.md` (recommandations validées) : partie **interface** de la spec v2
(§ 7.2, § 7.3) et des lots P0 SV-H3 (HUD), SV-C1 (choix de carte), SV-P1 (côté lecture des évolutions), SV-B1 (bilan),
SV-T1 (mots). Socle UIK-0 (UiTheme v2, StickerBox / StickerPanel, UiFeel, Mochiy Pop One + M PLUS Rounded 1c). Aucune règle
de jeu ni aucun réglage changé (horde, lisibilité du monde : SVX-1). Mode scellé : rien n'est lu ni écrit dans le compte.

Captures regardées (1600 × 900 et 1280 × 720) : `svx2/planche_1600x900.jpg`, `svx2/planche_1280x720.jpg` (+ 3 en grand).
Outil : `godot --path game res://tests/shot_svx2.tscn -- [cartes|hud|pause|bilan|tout]` (`SVX2_RES=1280x720`).

## Ce qui est en place
| Sujet | Fichiers | Contenu |
|---|---|---|
| HUD v2 | `ui/survivor_hud.gd` (réécrit), `ui/hud.gd` (pose en fin de `_build`), `ui/hud_widgets.gd` | barre d'expérience **pleine largeur** et niveau en pastille soleil ; chrono « 5:46 avant le boss » + **frise** dans un panneau papier au centre haut (gardiens : gris à venir, fraise « ! » à l'annonce, pomme ✓ vaincus ; portail à 15:00 ; boss en case améthyste à couronne) ; la frise **tremble** et gronde à l'annonce d'un gardien ; arène : temps avant la rage et jauge à graduations ; **collection de la partie** sous les objectifs (arme +N, 8 cases rareté / +N / éveil en points soleil / ★ jet parfait, monstres vaincus, « ◆ Évolution prête » ou panoplie « 3 / 5 », passifs en ronds ×N ; survol : la carte de la pièce) ; **vie en jauge large** avec trace claire ; cases de sorts en **grille 4 × 3** (enchaînements libres tramés) et **touches dessinées** en pastilles ; « Sorts n / 12 » ; orbes, horloge des objectifs et compteur « dégâts cumulés » retirés en Survivant. Barre de boss v2 (DNG-2) : le chrono lui laisse la place (lu par `hud.get("_boss_bar")`, sans dépendance). |
| Moments manga | `ui/survivor_moments.gd` | « Niveau ! » (600 ms, Mochiy contourée, −3°) au-dessus du héros ; évolution : traits de vitesse, « Évolution ! » + nom en Mochiy 44 sur bande d'encre, confettis ; boss : « Le boss ! » ; gardien vaincu, jet parfait : onomatopée. Son (`Sfx.ui`) + vibration (réglage « Vibration manette » de UiFeel) ; « Réduire les animations » : texte, son et vibration seulement. |
| Choix de carte v2 | `ui/survivor_picker.gd` (`SurvivorPicker extends CardPicker`, créé par `World` en Survivant), `ui/survivor_cards_view.gd` (`build_v2`, `tones_of`, `family_label`, `band_text`, `synergy`, `evo_hint`, `evo_paths`, `hero_preview`) | jeu **flouté** derrière (shader de lecture d'écran + voile d'encre, jamais de noir plein) ; titre en deux temps (« Niveau 14 ! » −3° en ressort, « Choisis une carte · 2 autres en attente » ; « Ta première carte ! » ; « Coffre du gardien ») ; cartes **papier** : bandeau de rareté deux tons avec la touche 1-2-3 et l'étiquette de famille inclinée (PIÈCE, ARME, SORT, ÉVOLUTION, « GARDÉE »), icône du jeu dans sa case, **le chiffre de la décision** (« +4 → +6 », « Niv. 1 / 10 », stat principale), **l'aléa encadré** (passif tiré sur soleil, effet ★ / sort sur lagon), 2 lignes au plus, **pastille verte de synergie** (« ◆ Évolution : + Braise → Lame du phénix », « ◆ Pillard mystique 2 / 5 : bonus ! »), pied « Maj : tout le détail · 🔒 gardée à vie » ; **Maj tenue (ou RB)** : la carte complète d'avant dans un puits d'encre ; panneau d'encre **« Ton équipement »** (9 cases, case visée en pointillés lagon, héros **avant → après** la carte survolée, panoplies, « Sorts n / 12 · Évolution prête ») ; **une seule barre** : Relancer (X / R), Bannir (Y / F), Garder (LB / C), Passer +or (B / P), pastilles des touches (X lagon, Y soleil, B fraise) ; Bannir et Garder en **mode visée** (éligibles soulignées lagon, autres grisées ; même bouton, B ou Échap annule) ; étincelles au choix. Tient dans 1280 × 720 avec la fiche de découverte (hauteur calculée, panneau resserré). |
| Évolutions lisibles | `survivor_cards_view.gd`, `survivor_build_page.gd`, `survivor_hud.gd` | indice sur la carte (ingrédient d'une évolution), « ◆ X : il manque Y » / « Évolution prête » en tête des passifs de la pause, pastille du HUD, moment manga et journal quand elle est prise. Aucune recette ajoutée (règles : lot à part, SV-P1). |
| Pause « Équipement » | `ui/survivor_build_page.gd`, `ui/pause_menu.gd` | onglet « Équipement » (plus « Build »), « Panoplies », 4e colonne **« Qui fait le travail »** (dégâts par seconde de chaque source sur 30 s, barres), repliable, repliée d'office sous 1500 px. |
| Dégâts par source | `core/survivor_log.gd` (`SurvivorLog`), `combat/combatant.gd`, `combat/procs.gd`, `player/player.gd` | étiquette posée par le coup (`Player._hit_monster` : arme / sort ; `Procs.run` : passif, évolution, panoplie), comptée par `Combatant.take_damage` (Survivant seulement) ; effets sur la durée à part ; moments marquants (12 au plus). |
| Bilan v2 | `ui/survivor_bilan.gd` (`SurvivorBilan.decorate`), `ui/results_screen.gd` | « Classe · Survivant · palier · zone · durée », **4 tuiles** (niveau, monstres, gardiens, boss), « Ce qui t'a battu » après une chute, **Qui a fait le travail** (barres, totaux, part au survol), **Ton équipement final** en cases + panoplie, jets parfaits, sorts, évolutions, **courbe minute par minute** (écran haut, données du directeur), **Moments marquants** en pastilles horodatées, confettis à la victoire ; **Rejouer** (principal), Changer de classe, **Menu principal**. Tient dans 1280 × 720. |
| Mots | `survivor_cards.gd`, `survivor_gear.gd`, `survivor.gd` | « pendant la run » → « de la partie », « Bannir le set » → « Bannir la panoplie », « Set … » → « Panoplie … », « Gardée toute la partie », « La partie de base », « +1 relance pour la partie ». |

## Tests
- `test_svx2` (nouveau) : journal (sources, parts, fenêtre, étiquettes d'effets, moments, rien hors du Survivant) ; choix v2
  (titres, barre, bandeau, panneau et aperçu du héros, Maj, bannir / garder en visée, clavier R / P, manette Y / B / X / B, mots) ;
  120 états tirés au hasard à 1280 × 720 et 1600 × 900, cartes courtes **et** complètes : rien ne déborde, l'écran tient (aussi avec
  la fiche de découverte) ; HUD v2 en jeu, frise, moments, dégâts comptés en vrai ; pause « Équipement » ; bilan v2 aux deux tailles.
- Mis à jour : `test_sv3` (« Bannir la panoplie »), `test_sv5` (SurvivorPicker, X relance, B passe, hauteur `needed_height`),
  `test_sv6` (4 tuiles, durée au sous-titre, « gear », « Menu principal », blocs v2 à l'écran), `test_nav_screens` (SurvivorPicker),
  `test_pages` (page Équipement et choix v2 dans 1280 × 720), `test_texts_fr` (mots du Survivant).
- Verts sur copie propre de HEAD + lot : test_svx2, test_sv1 à test_sv9, test_hud, test_cards, test_results, test_uik0, test_h2,
  test_br3, test_bri1, test_bri2, test_hub1, test_dng1, test_quests, test_pages, test_nav_screens, test_texts_fr ;
  `check_scripts` vert (464 scripts). `test_sv7` relit ses mesures : aucun réglage changé.

## Écarts et restes
- Pas de nouvelles recettes d'évolution (SV-P1 côté règles), ni records / « Nouveau record ! » (SV-M2), ni coffres qui s'ouvrent un
  à un (SV-F1), ni Codex (SV-M1) : lots P1 à venir ; le bilan et la pause sont prêts à les recevoir.
- Le choix de carte de la Survie et du Battle royale garde l'ancien rendu (CardPicker) : seul le Survivant passe en v2.
- Le cadre commun du bilan (`ResultsPanel` : fond, tuiles) et le panneau des objectifs restent ceux du chantier UI commun.
- La courbe minute par minute n'apparaît qu'en écran haut (≥ 860 px) : à 1280 × 720 le bilan garde la place des coffres.
- Capture : au tout début d'une partie, le fondu d'arrivée peut encore couvrir l'écran (outil `shot_svx2` : il attend sa fin).
