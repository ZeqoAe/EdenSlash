# Étude comparative : le Survivant face aux meilleurs du genre (BM-SURV, 17/10/2026)

Méthode : `METHODE.md`. Règles du mode : `conception/survivor/SPEC.md` (tête « Décisions finales »), `DECISIONS_JOUEUR.md`, `R_S1` à `R_S9`.
DA cible : `conception/art/BIBLE.md` v2 (« autocollant manga »). Mandat du joueur : un clone des jeux du genre qui tire parti de ce qui se
fait de mieux, adapté à nous, comparé écran par écran pour voir nos points faibles (HUD, UI / UX, profondeur, confort), dans la nouvelle DA.

**Images** : captures publiques (pages Steam des 9 jeux, wikis communautaires, un article) rangées **hors du dépôt** dans
`C:\AI\benchmark_refs\survivant\<jeu>\` (sources dans chaque `_SOURCE.txt`, planches 2 × 2 dans `_planches\`) ; nos captures (copie propre de
HEAD 0.1.256, 1600 × 900 : `shot_sv3`, `shot_sv5 tout`, `shot_sv6`, `shot_sv8`, plus une vraie partie au pilote `--survivor --autoplay`)
dans `C:\AI\benchmark_refs\survivant\_nous\`. Rien de tiers dans le dépôt : ce document décrit, il ne copie pas. Les maquettes de
`survivant_maquettes/` sont des dessins maison (SVG).

**Degré de preuve** : **[vu]** = constaté sur une capture regardée ; **[source]** = page citée ; **[non vérifié]** = connaissance générale du
genre, non confirmée pendant l'étude (à vérifier avant de s'en servir comme argument).

---

## 1. Résumé en une page

Notre Survivant a **une profondeur de build au-dessus de la moyenne du genre** (pièces à vie sur 9 emplacements, passif tiré écrit sur la carte,
jet 100-120, panoplies 2 / 3 / 5, sorts 1-10 en grille de 12, paliers I-V qui ajoutent chacun une règle) et **un écran de pause « Build » au niveau
de Megabonk et Halls of Torment**. Il perd la comparaison sur **ce qui se voit dans les 10 premières secondes** :

1. **Pas de horde** : dans la vraie partie au pilote, **aucun monstre à l'écran à 0:45**, 4 à 2:30, aucun près du héros à 5:00 **[vu]** ; les références remplissent l'écran
   de dizaines à centaines d'ennemis dès la 1re minute **[vu]** (VS, Brotato, DRG Survivor, Halls of Torment, 20 MTD). Plafond chez nous : 110 vivants
   sur toute la carte (`Survivor.ALIVE`), monstres gros et caméra proche.
2. **Le chaos n'est pas lisible** : nombres de dégâts empilés en tas illisibles (« EXÉCUTÉ » sur « 151 ! » sur « 250 ! »), héros caché derrière des
   monstres de sa taille et derrière le boss **[vu]** ; à 7:00 les **effets de nos propres sorts** (disques magenta opaques, flammes) et une plante
   de premier plan couvrent la moitié de l'écran : ni héros ni monstre visibles ; à 10:00, voile orange sur tout l'écran et cinq mots ou nombres
   superposés au même endroit **[vu]** ; barre de cible d'un monstre ordinaire en haut de
   l'écran (inutile face à une horde). Les références gardent les effets du joueur pâles ou d'un seul ton (20 MTD) et le danger d'une autre couleur.
3. **HUD et cartes hors de la nouvelle DA et hors des codes du genre** : pas de barre d'expérience pleine largeur (VS, 20 MTD, DRG Survivor,
   Soulstone et Megabonk la mettent en haut ou en bas sur toute la largeur, Halls of Torment sur toute la hauteur, Brotato sous la vie **[vu]**) mais un rond « 0 % » ; panneau sombre or / bleu nuit de l'ancienne DA ; choix de carte sur fond noir, 6 à 10 lignes par carte, 8 boutons.
4. **Peu de « moments de découverte »** : 4 évolutions seulement dans tout le jeu (contre une quarantaine chez VS **[non vérifié]**), aucune
   indication de synergie sur la carte (VS écrit « evo: » à côté de l'objet **[vu]**, 20 MTD montre l'arbre que la carte débloque **[vu]**).
5. **La fin de partie ne raconte rien** : notre bilan donne 6 tuiles et une liste ; Halls of Torment donne les dégâts et le DPS **par source** **[vu]**.
   Aucun record (meilleur temps, meilleure classe), aucune collection du mode, aucune graine ou défi propres au mode.

Le backlog P0 (§6) traite ces cinq points ; la spécification « version 2 » (§7) les assemble dans la DA, avec trois maquettes.

---

## 2. Références retenues et ce qu'on en garde

| Jeu (sortie) | Pourquoi | Ce qu'on garde (mécanisme, pas l'asset) |
|---|---|---|
| **Vampire Survivors** (2022) | référence du genre, rythme, collection | barre d'XP pleine largeur ; chrono au centre ; écran de montée de niveau **avec toutes les stats du héros à côté** et l'indice « evo » **[vu]** ; Relancer / Passer / Bannir avec compteurs **[vu]** ; collection « 124 / 127 » à cases « ? » **[vu]** ; sélection d'étape avec modificateurs (Hyper, Hurry, Arcanes, Limit Break) **[vu]** |
| **Brotato** (2023) | builds, boutique entre vagues | télégraphe d'apparition (croix rouges au sol avant qu'un monstre arrive) **[vu]** ; montées de niveau en attente affichées en haut à droite **[vu]** ; boutique : 4 offres, **Verrouiller** gratuit par offre, relance à prix croissant, panneau de stats permanent **[vu, source]** ; armes identiques fusionnées **[source]** |
| **Halls of Torment** (2024) | ARPG-survivor, équipement par emplacements | pause = équipement en croix + tableau « Max DPS / dégâts totaux » **par arme** **[vu]** ; bilan : dégâts et DPS par source, score, quêtes accomplies **[vu]** ; quête suivie en haut à gauche pendant la partie **[vu]** ; niveau de difficulté « Agony » affiché **[vu]** |
| **Megabonk** (2025) | 3D, le plus proche de nous (caméra 3D, carte ouverte, coffres) | objectif en case à cocher (« trouver le boss ») **[vu]** ; mini-carte avec coffres **[vu]** ; chrono décroissant **[vu]** ; écran « Upgrade Options » : rareté, nom, niveau, **stat avant → après**, colonnes **Stats** et **Inventaire** (armes, tomes, objets ×N) à droite, Passer / Rafraîchir / Bannir avec compteurs **[vu, article]** ; sanctuaires à effets (aimant, charge de stat, cupidité) **[source, non vérifié en jeu]** ; réglage « passer l'animation des coffres » **[source]** |
| **Risk of Rain 2** (2019, 3D) | objets empilables, difficulté qui monte avec le temps | objets qui s'empilent sans plafond ; jauge de difficulté horaire ; imprimantes / recycleur ; objets lunaires à contrepartie ; Logbook **[non vérifié pendant l'étude : les captures Steam ne montrent pas le HUD]** |
| **Hades** (2020) | lisibilité des cartes (bienfaits) | colonne de bienfaits à gauche avec « Lv. » et « +8 » au-delà de la place **[vu]** ; écran de choix : dieu, rareté, valeur en gras, prérequis des bienfaits doubles **[non vérifié : pas de capture du choix]** ; Codex **[non vérifié]** |
| **Deep Rock Galactic : Survivor** (2025) | HUD de mission très clair, 3D vue de dessus | **frise de mission en haut avec crânes aux événements** (élite, boss) **[vu]** ; objectif courant en une ligne sous la frise **[vu]** ; objectif secondaire « x / 12 » à droite **[vu]** ; armes en bas avec niveau et barre de recharge, **cases fermées « niv. 15 / 25 »** **[vu]** ; montée de niveau : 3 cartes, **bandeau de rareté coloré**, une ligne d'effet, « Tout relancer » avec coût, aide manette en bas à droite, jeu flouté derrière **[vu]** |
| **20 Minutes Till Dawn** (2023) | lisibilité par palette, arbres d'améliorations | **palette à 3 tons** : monstres sombres, tirs du joueur crème, danger rouge **[vu]** ; le choix montre **l'arbre que l'amélioration débloque** **[vu]** ; runes de méta-progression à paliers **[vu]** |
| **Soulstone Survivors** (2025) | ARPG coloré, grands nombres de choix | **Relancer 8 · Bannir 5 · Verrouiller 10** avec touches R / F / C, cartes numérotées 1-2-3, « Plus de détails Q » **[vu]** ; **points de compétence en attente** (2) **[vu]** ; **étiquettes de type** sur les sorts (« 2 types ») **[vu]** ; objectifs empilés en haut à droite (« 316 / 400 ») **[vu]** ; barre de boss à graduations **[vu]** |

Sources : pages Steam (`store.steampowered.com/app/1794680`, `/1942280`, `/2218750`, `/3405340`, `/632360`, `/1145360`, `/2321470`, `/1966900`,
`/2066020`, relevées le 17/10/2026) ; `vampire.survivors.wiki/w/Level_up` et `/w/Options` ; `brotato.wiki.spellsandguns.com/Shop` ;
`gfinityesports.com/article/megabonk-guide-weapon-scaling-explained` ; guides Megabonk (keengamer, dexerto, dtgre : bannir / passer / rafraîchir,
sanctuaires, quêtes, réglages) ; patch Megabonk de décembre 2025 (gamingonlinux).

---

## 3. Nos écrans, un à un, contre les références

| Écran (notre capture) | Ce qu'on fait bien | Ce qui manque ou gêne | Meilleure référence |
|---|---|---|---|
| **Lobby du mode** (`sv8_page_paliers`) | une phrase, 3 idées en pastilles, sélecteur de palier I-V avec cadenas et règle du palier, coffres du palier, Lancer épinglé | ancienne DA ; aucun record (meilleur temps, classes gagnées) ; zone choisie hors écran (défile) ; illustration provisoire ; « JcE » est du jargon | VS (sélection d'étape + modificateurs + carte de collection), Halls of Torment (Agony) |
| **Premier choix** (`sv5_premier_choix`) | règle du joueur respectée (arme ou sort), fiche « 1re carte » dans le choix | fond **noir plein** (le jeu disparaît : interdit par la BIBLE §2) ; Bannir + Garder sur **chaque** carte (6 boutons) + Relancer = 7 boutons pour 3 cartes ; la carte de sort est à moitié vide | DRG Survivor (jeu flouté derrière, une barre d'actions) |
| **Montée de niveau** (`sv5_amelioration`, `sv5_piece_fiche`) | **passif tiré écrit sur la carte** (mieux que tout le genre : personne n'écrit l'aléa à l'avance) ; avant → après ▲ ; jauge +6 +8 +10 ; set « 1 / 5 » | 7 à 10 lignes par carte ; textes coupés (« Couronne du Festin du Fan… », « recharge 1,5… ») ; aucune vue des **stats du héros** ni de **l'inventaire** pendant le choix ; aucun indice de **synergie** (évolution, set qui s'active) ; nombres en pourcentages dans le texte principal | Megabonk (avant → après + Stats + Inventaire), VS (« evo: »), Soulstone (touches, compteurs, détails sur une touche) |
| **HUD en partie** (`sv5_hud_*`, `run_auto__shot_*`) | frise des 20 minutes avec gardiens (bonne idée, rare dans le genre) ; objectifs cochés ; niveau des sorts sur les cases ; Menace visible | **pas de barre d'XP pleine largeur** (rond « 0 % » en bas à droite) ; frise cachée dans un encadré en haut à gauche ; barre de cible d'un monstre ordinaire au centre haut ; **compteur « Dégâts cumulés / record »** sur le côté droit (bruit) ; 4 cases de sorts alors que « Sorts 6 / 12 » ; aucune trace des pièces / passifs portés à l'écran ; ancienne DA | DRG Survivor (frise + objectif), VS (XP), Hades (colonne de bienfaits) |
| **Horde** (`run_auto__shot_45` à `_600`) | monstres 3D variés, rôles d'escouade (P15), télégraphes rouges | **4 monstres à l'écran à 2:30, 0 à 5:00 près du héros** ; à 7:00 l'écran est **noyé** par nos effets de sorts (magenta et orange opaques) : héros invisible ; monstres de la taille du héros qui le cachent ; feuillage de premier plan qui masque le centre ; nombres empilés illisibles | VS / DRG Survivor / HoT (densité), 20 MTD (palette de lisibilité), Brotato (télégraphe d'apparition) |
| **Boss** (`sv5_hud_boss`, `sv8_arene_palier_iv`) | PV fixes affichés, rage à graduations, mécanique ajoutée annoncée (« Palier IV · le boss gagne : Marque ») | le héros **disparaît dans le modèle du boss** ; pas de graduations de phase sur la barre | Soulstone (barre à graduations), RoR2 (contours des personnages) |
| **Pause « Build »** (`sv5_build`) | **le meilleur écran du mode** : arme, 8 cases avec +N et éveil, héros, 12 sorts avec niveau et effet cumulé, passifs actifs avec total, sets | vocabulaire (« Build », « Run », « Sets » : la BIBLE §12 demande partie / panoplie) ; aucun **DPS par source** ; « Impact profond » deux fois dans l'état de test (à vérifier) | Halls of Torment (DPS par arme), Megabonk (Stats + Inventaire) |
| **Bilan** (`sv6_bilan_victoire`) | Rejouer en un clic, titre et palier annoncés, coffres listés, « Ton build » | liste plate ; pas de dégâts par source, pas de courbe de la partie, pas de record, coffres qui ne s'ouvrent pas à l'écran ; « Retour au lobby » | Halls of Torment (stats par source + quêtes), VS (coffre qui s'ouvre) |

---

## 4. Profondeur du mode

| Axe | Nous | Références | Écart |
|---|---|---|---|
| Combinaisons arme / sort / passif | 17 types d'arme × 2 variantes, kit de la classe (14-20 sorts), ≈ 40 passifs, **4 évolutions** (`Boons` à `requires`) | VS : évolutions arme + passif, unions, arcanes **[non vérifié : nombre exact]** ; 20 MTD : arbres d'améliorations visibles **[vu]** ; DRGS : surcadençages d'arme **[non vérifié]** | **Gros** : pas assez de « recettes » à découvrir ; aucune n'est suggérée à l'écran |
| Objets uniques | pièces des 13 sets de niveau 90 avec passif fixe + 3 passifs tirés | Brotato : objets à contrepartie (« +10 chance, −1 élémentaire ») **[vu]** ; RoR2 : lunaires **[non vérifié]** | Moyen : nos pièces n'ont **jamais de contrepartie** : pas de choix risqué dans l'équipement |
| Économie de la partie | or des monstres → coffres, marchands, Passer | Brotato : boutique à chaque vague, verrou, relance à prix croissant **[vu, source]** | **Moyen** : l'or s'accumule sans usage (5 560 or à 10:00 dans la vraie partie **[vu]**, ≈ 48 000 en fin de partie au pilote, `R_S8`) |
| Risque / récompense | Menace (autels du géant, pacte), Audace (entrer tôt), Passer = or | Megabonk : sanctuaire de cupidité **[source]** ; VS : malédiction **[non vérifié]** ; Brotato : danger 0-5 **[non vérifié]** | Faible : la Menace existe mais ne se voit qu'en pastille ; aucun choix risqué **pendant** une montée de niveau |
| Variété de cartes | 9 familles, rareté, pitié, filet de sort, 2 garanties | Soulstone : étiquettes de type **[vu]** ; Hades : bienfaits doubles **[non vérifié]** | Bon côté règles, faible côté **lisibilité de la synergie** |
| Ennemis | rôles d'escouade (P15), élites dès 8:00, 3 gardiens, 48 boss à briques, paliers qui ajoutent des mécaniques | DRGS : élites nommées avec objectif « Fais sortir l'élite » **[vu]** ; Soulstone : seigneurs à invoquer en tuant 400 monstres **[vu]** | Moyen : nos élites ne se distinguent pas assez à l'œil ; la **masse** manque |
| Rejouabilité | 60 classes, 5 paliers, 15 coffres « première fois », titres | VS : collection, arcanes, modes d'étape **[vu]** ; HoT : 500 quêtes **[vu]** ; Megabonk : quêtes qui débloquent armes / tomes **[source]** | **Gros** : aucun objectif propre au mode après les 15 coffres (pas de collection, pas de défis, pas de records) |
| Équilibre | mesuré (S7-S9 : pilote, sonde, 5/5 ≈ 1 run sur 23) | — | Avance réelle : peu de jeux du genre publient leurs mesures |

---

## 5. Tableau d'écarts

| # | Sujet | Ils font mieux | On fait mieux | Manque chez nous | Prio |
|---|---|---|---|---|---|
| 1 | Densité de la horde | écran plein dès 1:00 | rôles d'escouade, monstres 3D variés | 200 à 400 monstres visibles, petits, qui convergent | P0 |
| 2 | Lisibilité du chaos | palette à 3 tons (20 MTD), nombres sobres (VS), croix d'apparition (Brotato) | télégraphes au bord net (BIBLE §10) | nombres fusionnés par cible, héros toujours contouré, monstres plus petits que le héros, feuillage translucide près du héros | P0 |
| 3 | Barre d'XP / rythme visible | pleine largeur chez presque tous ; frise à crânes (DRGS) | frise des 20 min | XP pleine largeur ; frise au centre haut ; montées en attente | P0 |
| 4 | Choix de carte | stats + inventaire à côté (VS, Megabonk), une barre d'actions (DRGS, Soulstone) | passif tiré écrit, jet, jauge +6/+8/+10 | ≤ 4 lignes, détail sur Maj, jeu visible derrière, synergie écrite, actions groupées | P0 |
| 5 | DA | — | — | HUD, cartes, pause, bilan dans la BIBLE v2 (papier, encre, bonbons) | P0 |
| 6 | Synergies / évolutions | « evo: » (VS), arbre (20 MTD), types (Soulstone) | — | 12 à 20 évolutions, indice sur la carte, page Build qui montre « il manque… » | P0 |
| 7 | Bilan | dégâts par source (HoT) | Rejouer en un clic | dégâts par source, courbe, record, coffres qui s'ouvrent | P0 |
| 8 | Vocabulaire | — | tout en français | « Build », « Run », « Sets », « lobby », « JcE » encore visibles | P0 |
| 9 | Collection / objectifs du mode | collection « ? » (VS), quêtes (HoT, Megabonk) | coffres d'apparence par palier | Codex du Survivant (armes, passifs, évolutions, panoplies vus), défis du mode | P1 |
| 10 | Records | score, temps (HoT) | — | meilleur temps par classe et palier, 60 classes « gagnées » | P1 |
| 11 | Modificateurs de partie | Arcanes, Hyper, Hurry (VS) | paliers à règles | 1 « faveur » choisie au départ (3 au choix) ; vitesse du jeu | P1 |
| 12 | Élites et événements | élite nommée + objectif (DRGS), seigneurs (Soulstone) | gardiens à heure fixe, mécaniques de palier | élites à modificateur lisible (icône + couleur), un événement à 7:30 et 12:30 | P1 |
| 13 | Risque dans l'équipement | contreparties (Brotato) | jet parfait | quelques pièces « maudites » (gros bonus + malus écrit) | P1 |
| 14 | Coffres | ouverture spectaculaire (VS) | coffres ciblés par emplacement | ouverture en 520 ms (BIBLE §7), option « passer l'animation » (Megabonk) | P1 |
| 15 | Accessibilité | flash, sang, tremblement (VS) | nombres de dégâts réglables, intensité des effets, mode Bot / Détente | mode daltonien (raretés : forme + couleur), taille des nombres, « réduire les animations » (BIBLE §7) | P1 |
| 16 | Défi du jour du mode | graine (non vérifié chez les références : RoR2 avait des épreuves à graine) | Défi du jour du compte | graine du jour Survivant, classement local | P2 |
| 17 | Prolongations | mode sans fin (VS, HoT) | boss à PV fixes | « continuer après le boss » jusqu'à la mort (records seulement) | P2 |
| 18 | Or de la partie | boutique utile à chaque vague (Brotato) | coffres ciblés par emplacement | un usage à l'or dès 5:00 (boutique du gardien) | P1 |
| 19 | Montées regroupées | points en attente (Soulstone, Brotato) | pause immédiate | option « regrouper les choix » (on choisit quand on veut) | P2 |

---

## 6. Backlog

Tailles : S ≤ un envoi, M = quelques fichiers, L = nouveau système (1 session). Fichiers relatifs à `game/scripts/`. Chaque lot : tests verts,
captures 1600 × 900 et 1280 × 720 **regardées**, `UiTheme` v2 / `UiFeel` (BIBLE §5-7).

### P0 — sans ça le mode fait « prototype »
| Lot | Contenu | Taille | Fichiers |
|---|---|---|---|
| **SV-H1 Horde** | densité 40 → 250 vivants à l'écran (mesure P2 d'abord) ; monstres ordinaires du Survivant à l'échelle 0,6-0,75 du héros ; meutes qui **convergent** sur le héros (rayon d'apparition 14-20 m au lieu de 20-28) ; rendu instancié ou imposteurs au-delà de 25 m si la mesure l'exige ; croix d'apparition 0,8 s | L | `core/survivor_director.gd` (`ALIVE`, `PACK_*`), `core/spawn_director.gd`, `ai/monster.gd`, `world/` (rendu), `tools/perf_ui` |
| **SV-H2 Lisibilité** | nombres de dégâts **fusionnés par cible** (un nombre qui grossit, 1 par 150 ms au plus), « Exécuté » en icône, plafond de 30 nombres à l'écran ; **effets des sorts du joueur plafonnés** en opacité (≤ 40 %, bord net, jamais au-dessus des télégraphes ennemis) et adoucis à mesure qu'ils s'empilent ; **contour du héros** visible à travers monstres, boss, effets et décor ; feuillage translucide dans 4 m autour du héros ; pas de barre de cible pour un monstre ordinaire en Survivant | M-L | `ui/hud.gd` (nombres), `combat/eden_fx.gd`, `shaders/` (contour, effets), `world/gfx.gd`, `core/survivor.gd` |
| **SV-H3 HUD v2** | maquette `v2_hud.svg` : XP pleine largeur + niveau, chrono et frise au centre haut, collection de la partie à gauche (arme, 8 cases, passifs), mini-carte avec coffres et autels, vie en jauge, sorts avec points d'enchaînement ; compteur « dégâts cumulés » retiré en Survivant | M | `ui/survivor_hud.gd`, `ui/hud.gd`, `ui/hud_widgets.gd`, `ui/ui_theme.gd` |
| **SV-C1 Choix de carte v2** | maquette `v2_choix_carte.svg` : jeu flouté derrière, cartes papier à bandeau de rareté, ≤ 4 lignes + Maj, panneau « Ton équipement » avec stats avant → après de la carte survolée, une barre d'actions (Relancer X, Bannir… Y, Garder… LB, Passer B), mode visée pour bannir / garder, touches 1-2-3, montées en attente | L | `ui/card_picker.gd`, `ui/survivor_cards_view.gd`, `core/survivor_cards.gd` (rien des règles), `test_sv5` |
| **SV-P1 Évolutions** | 12 à 16 recettes nouvelles (arme + passif éveillé, sort niveau 10 + passif) ; carte : pastille « ◆ Évolution : + X → Y » ; page Build : « Évolutions possibles : il manque… » ; carte d'évolution offerte par le coffre du gardien si prête | L | `core/boons.gd` (données), `core/survivor_cards.gd`, `ui/survivor_build_page.gd`, `test_sv3` |
| **SV-B1 Bilan v2** | maquette `v2_bilan.svg` : dégâts par source (arme, sorts, passifs, évolutions), courbe niveau / force des monstres par minute, équipement final en cases, coffres qui s'ouvrent, « Nouveau record ! » | M | `core/survivor_rewards.gd`, `combat/` (attribution des dégâts par source), `ui/results_panel.gd`, `ui/results_screen.gd` |
| **SV-T1 Mots** | « Build » → « Équipement », « Run » → « Partie », « Sets » → « Panoplies », « Retour au lobby » → « Menu principal », « JcE » retiré ; `test_texts_fr` étendu à ces mots | S | `ui/survivor_build_page.gd`, `ui/pause_menu.gd`, `ui/results_screen.gd`, `ui/lobby.gd`, `tests/test_texts_fr.gd` |

### P1 — ce qui fait la qualité
| Lot | Contenu | Taille | Fichiers |
|---|---|---|---|
| **SV-M1 Codex du Survivant** | collection propre au mode : 17 types d'arme × 2 variantes, passifs éveillés à +10, évolutions, panoplies 5/5, jets parfaits ; cases « ? » tant que non vues ; page au Carnet | M | `core/survivor_rewards.gd`, `ui/carnet_pages.gd` (onglet en fin), `core/completion.gd` |
| **SV-M2 Records** | meilleur temps de victoire par classe et palier, plus haut niveau, classes gagnées (grille des 60 au lobby du mode), « Nouveau record » au bilan | S-M | `core/survivor_rewards.gd`, `ui/lobby.gd` |
| **SV-M3 Défis du mode** | 30 défis internes au Survivant (« Gagne avec une seule panoplie », « 3 évolutions dans une partie »), récompense : apparences et titres (jamais de puissance) | M | `core/survivor_rewards.gd`, `core/quests.gd` (bus existant) |
| **SV-R1 Faveurs** | au départ, 1 faveur parmi 3 (modificateur lisible : « monstres ×2, or ×2 », « une carte de plus à chaque choix mais pas de relance »…), ouvertes par les défis | M | `core/survivor.gd`, `core/survivor_cards.gd`, `ui/lobby.gd` |
| **SV-E1 Élites lisibles** | modificateurs d'élite (rapide, bouclier, explosif, invocateur) : icône au-dessus, couleur de contour, une ligne au HUD ; deux événements nommés (7:30, 12:30 : « Nuée », « Chasseur ») | M | `core/survivor_director.gd`, `ai/`, `ui/survivor_hud.gd` |
| **SV-R2 Pièces maudites** | ≈ 1 pièce sur 15 : gros bonus + contrepartie écrite en fraise (« +40 attaque · soins reçus ÷ 2 ») | M | `core/survivor_pool.gd`, `core/survivor_gear.gd`, `ui/survivor_cards_view.gd` |
| **SV-R3 Or utile** | après chaque gardien, **boutique du gardien** (4 cartes du mode, verrou gratuit, relance à prix croissant, comme Brotato) ; prix des coffres qui montent avec le temps ; « Passer » rapporte moins si l'or déborde | M | `core/survivor_director.gd`, `ui/merchant_ui.gd`, `core/survivor_cards.gd` |
| **SV-F1 Coffres et ressenti** | ouverture de coffre 520 ms à rayons (BIBLE §7), onomatopée « Niveau ! » et onde qui repousse les monstres à la montée de niveau, aimant d'orbes visible ; réglage « passer l'animation des coffres » | M | `ui/card_picker.gd`, `ui/hud.gd`, `world/`, `core/settings.gd` |
| **SV-A1 Accessibilité** | raretés et familles doublées d'une **forme** (pastille ronde, carrée, losange…) ; mode daltonien (deutéranopie, protanopie : palette des télégraphes et raretés) ; taille des nombres (3 crans) ; « Réduire les animations » ; vitesse du jeu ×0,8 / ×1 / ×1,2 hors records | M | `core/settings.gd`, `ui/settings_menu.gd`, `ui/ui_theme.gd`, `ui/hud.gd` |

### P2 — finitions et confort
| Lot | Contenu | Taille |
|---|---|---|
| SV-Q1 Graine du jour Survivant | même carte, mêmes tirages pour tous ce jour-là, tableau local des 5 meilleures parties | M |
| SV-Q2 Prolongations | après le boss, « Continuer » : horde sans fin, records seulement, aucune récompense | M |
| SV-Q3 Choix regroupés | option : les montées s'accumulent (pastilles en haut à gauche), on ouvre quand on veut (touche Tab / Vue) | M |
| SV-Q4 Reprise | sauvegarde de la partie en quittant (une seule, effacée à la reprise) | L |
| SV-Q5 Statistiques du mode | page : parties, victoires par palier, armes les plus jouées, évolution préférée | S |
| SV-Q6 Fiche d'arme et de sort | au Codex, vidéo courte ou planche de l'effet (comme l'aide F1) | M |

---

## 7. Spécification « version 2 » du Survivant (dans la BIBLE v2)

Les règles de `SPEC.md` et `DECISIONS_JOUEUR.md` restent (20 minutes, pièces à vie, passif tiré écrit sur la carte, gardiens, boss à PV fixes,
paliers, récompenses d'apparence). La v2 change **la présentation, la densité et la profondeur visible**.

### 7.1 Déroulé et rythme
| Temps | v1 (mesuré) | v2 |
|---|---|---|
| 0:00 | choix arme ou sort, monstres rares | même choix ; **première meute visible à 0:10**, 15-25 petits monstres à l'écran dès 0:45 |
| 0:00-5:00 | montée douce (`OPENING`), vagues dès 1:15 | 1re vague à 1:00 ; **XP au sol abondante** (la horde « nourrit » le héros) ; premier coffre à < 25 m du départ |
| 5:00 / 10:00 / 15:00 | gardiens annoncés 10 s avant | idem + la frise centrale clignote ; le coffre du gardien peut offrir une **évolution prête** |
| 7:30 / 12:30 | — | **événement nommé** (Nuée, Chasseur d'élite) annoncé à la frise |
| 15:00-20:00 | portail ouvert, horde finale à 19:00 | idem ; 200+ monstres à l'écran au pic |
| Arène | boss, rage à 4:00 | barre de boss à **graduations de phase**, héros contouré, nombres fusionnés |

### 7.2 Écrans
1. **HUD** (`survivant_maquettes/v2_hud.svg`) : barre d'XP pleine largeur (pomme, contour d'encre, niveau en pastille soleil à gauche) ; au
   centre haut un panneau papier avec le **chrono** en Mochiy 34 et la **frise** (gardiens : rond vert coché / fraise « ! » à l'annonce, boss
   améthyste) ; bandeau d'annonce fraise sous la frise (4 s) ; à gauche une ligne or / clés / monstres puis la **collection de la partie**
   (arme, 8 cases, éveil en points soleil, panoplie « 3 / 5 ») et les passifs actifs en ronds avec ×N ; à droite la mini-carte (coffres, autels,
   gardien) et la Menace en pastille inclinée ; en bas la vie en **jauge large** (trace claire des dégâts) et les sorts (niveau sur la case, points
   d'enchaînement). Héros toujours contouré. Rien d'autre de permanent.
2. **Choix de carte** (`v2_choix_carte.svg`) : jeu visible derrière (flou + voile d'encre 35 → 75 %), titre « Niveau 14 ! » incliné −3°, « 2 autres
   en attente » en points. Trois cartes papier (rayon 18, contour 3, ombre dure 7), **bandeau de rareté** 2 tons en haut, étiquette autocollante
   de famille (PIÈCE, ARME, SORT, ÉVOLUTION), icône du jeu dans sa case, gros chiffre de la décision (« +4 → +6 », « Niv. 1 / 10 »), **un encadré
   pour l'aléa** (passif tiré sur soleil clair, effet ★ sur lagon clair), 2 lignes de stats au plus, **pastille verte de synergie**, pied « Maj : tout
   le détail · 🔒 gardée à vie ». À droite le panneau d'encre **« Ton équipement »** : grille, case visée en pointillés, stats du héros
   avant → après la carte survolée, panoplies. En bas **une seule barre** : Relancer (X), Bannir… (Y), Garder… (LB), Passer +or (B) ; Bannir et
   Garder passent en **mode visée**. Ressenti : BIBLE §7, ligne « Choix de carte ».
3. **Pause « Équipement »** : la page Build actuelle, renommée, dans la DA, avec une 4e colonne repliable **« Qui fait le travail »** (DPS par source
   sur les 30 dernières secondes) et la ligne « Évolutions possibles : il manque… ».
4. **Bilan** (`v2_bilan.svg`) : « Victoire ! » à traits de vitesse, sous-titre classe · palier · zone · durée, « Nouveau record ! » ; 4 tuiles ;
   courbe minute par minute (niveau contre force des monstres, gardiens en points) ; **dégâts par source** ; équipement final en cases ;
   découvertes du Codex ; coffres d'apparence qui s'ouvrent l'un après l'autre ; Rejouer (primaire), Changer de classe, Menu principal.
5. **Page du mode** : la page actuelle dans la DA + une carte de **records** (meilleur temps au palier choisi, classes gagnées x / 60) et l'accès
   au **Codex du Survivant**.

### 7.3 Retours (son, mouvement, particules)
- Montée de niveau : onomatopée « Niveau ! » 600 ms au-dessus du héros, onde blanche qui repousse les monstres proches de 2 m, « shing » −10 dB.
- Orbes : tintement à hauteur croissante quand on en ramasse plusieurs en 0,5 s (le genre le fait **[non vérifié]**, le mesurer en jeu).
- Évolution prise : traits de vitesse, nom de l'évolution en Mochiy 44, confettis des 5 bonbons (1,2 s).
- Élite tuée : éclat soleil + coffre ou clé qui saute en arc.
- Gardien annoncé : la frise tremble (±3 px), son grave ; jamais de vibration pendant un télégraphe (BIBLE §7).

### 7.4 Règles nouvelles (à valider par le joueur, §8)
Évolutions élargies (SV-P1), faveurs de départ (SV-R1), pièces maudites (SV-R2), événements à 7:30 et 12:30 (SV-E1), défis et Codex du mode
(SV-M1, SV-M3). Aucune ne touche la progression du compte ; toutes récompensent en apparences, titres et nouveautés **du mode**.

---

## 8. Questions ouvertes (avec recommandation)

| # | Question | Recommandation |
|---|---|---|
| 1 | Monter la horde à 200-400 monstres visibles, quitte à réduire leur taille et leur détail ? | **Oui.** C'est la promesse du genre ; d'abord une mesure de performance (`perf_ui`, 1280 × 720, qualité moyenne) avec 250 monstres ; imposteurs si besoin. |
| 2 | Évolutions secrètes (VS) ou affichées (20 MTD, Hades) ? | **Affichées après la 1re rencontre** : « ? » au Codex, recette visible une fois l'un des ingrédients pris ; la carte écrit « ◆ Évolution : + X → Y ». |
| 3 | Le mode ne donne que des apparences : faut-il des déblocages internes au mode (faveurs, nouvelles évolutions) comme VS / Megabonk ? | **Oui, internes au mode seulement** (jamais de puissance du compte) : c'est ce qui fait revenir dans le genre ; à confirmer par le joueur, qui a voulu « aucun lien avec le compte ». |
| 4 | Pause immédiate ou choix regroupés ? | **Pause immédiate par défaut** (règle actuelle, P13) ; « regrouper » en option (P2). |
| 5 | Vitesse du jeu réglable ? | **Oui, hors records** (×0,8 / ×1 / ×1,2) : confort et accessibilité. |
| 6 | Caméra plus haute en Survivant ? | **Oui** : distance par défaut +20 % en Survivant (la horde doit se voir à 15 m autour), réglable comme aujourd'hui. |
| 7 | Garder Bannir et Garder sur chaque carte ? | **Non** : une barre, mode visée (moins de boutons, même puissance). |
| 8 | Pourcentages dans le texte des cartes ? | **Garder les nombres sur la carte** (c'est un choix de puissance) mais en gros et sans phrase ; le détail en pourcentages sur Maj. Exception assumée à la règle « aucun pourcentage permanent ». |

---

## 9. Non vérifié pendant l'étude
- Nombre exact d'évolutions de VS, détails des surcadençages de DRG Survivor, objets lunaires et jauge horaire de RoR2 (captures Steam sans HUD),
  écran de choix de bienfaits de Hades (pas de capture), sanctuaires de Megabonk vus en jeu (guides seulement), épreuves à graine des références.
- Nos captures « HUD » de `shot_sv5` sont des états montés (sans monstres) ; la densité vient de la vraie partie au pilote (`run_auto`, pilote
  « moyen », palier I), qui va chercher les coffres : un joueur qui reste au milieu verra plus de monstres. **Mesurer** la densité réelle
  (monstres à moins de 15 m, par minute) avant SV-H1.
- « Impact profond » deux fois dans la page Build de `shot_sv5` : vient peut-être de l'état de test (`rich_state`) ; à vérifier.
