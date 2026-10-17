# Étude comparative : Battle royale (équipe BM-BR, 17/10/2026, jeu en 0.1.256)

Méthode : `conception/benchmark/METHODE.md`. DA de référence : `conception/art/BIBLE.md` v2 (« autocollant manga »).
Notre mode : `DESIGN.md` « Battle royale », rapports `conception/royale/R_BR1.md` à `R_BR5.md`, retours `RETOURS_JOUEUR.md`.
Maquettes maison : `conception/benchmark/battle_royale_maquettes/index.html` (6 écrans, formes CSS, aucun élément tiers).
Images de référence (hors dépôt) : `C:\AI\benchmark_refs\battle_royale\` (captures regardées dans le navigateur intégré) ; nos captures
de HEAD 0.1.256 : `C:\AI\benchmark_refs\battle_royale\eden_slash_0.1.256\` (copie propre, `shot_royale`, `shot_m1`, `shot_br2 map`,
`shot_br3`, `shot_br4`, 1600×900).

Légende : **vérifié** = vu sur une capture ou lu dans une source citée en fin de document ; **non vérifié** = connaissance générale
du genre, non confirmée pendant l'étude. Tailles : **S** ≤ ½ jour, **M** 1 à 2 jours, **L** 3 à 5 jours.

---

## 1. Résumé

Notre Battle royale a des **règles riches et originales** (montée de niveau, cartes du Survivant, réanimation des 2 premières
minutes, inspection de l'équipement, mise à prix, largage dirigé) mais une **présentation de prototype** : HUD et pages encore
dans l'ancienne DA (Cinzel, bleu nuit et or), informations tactiques absentes ou cachées dans du texte, carte sans lieux, mort
et bilan sans mise en scène. Les références gagnent sur la **lisibilité instantanée** (où est le danger, où aller, combien en
reste-t-il), sur la **boucle mort → spectateur → rejouer**, et sur la **variété d'une partie à l'autre**.

**Les 5 plus gros écarts**
1. **Lisibilité tactique du HUD** : ni arc de coup reçu, ni flèche vers la zone sûre, ni repère / ping, compteur de survivants
   dans une ligne de texte, fil des éliminations en petit texte gris ; grande carte sans position des héros ni lieux.
2. **Carte sans identité** : une prairie de 512 m presque uniforme (capture `br2_map_overview`), aucun lieu nommé ni couvert ;
   le choix « où atterrir » se réduit à « au-dessus d'un coffre ».
3. **Mort, spectateur, bilan** : aucun récapitulatif (qui, avec quoi, combien), spectateur figé sur le héros de plus haut niveau,
   bilan sans fête ni chronologie ; c'est le moment où les références donnent envie de rejouer.
4. **Butin au sol et cohérence** : 8 faisceaux superposés par dépouille (capture `br3_4_sol`), une seule invite pour la pièce la
   plus proche ; couleurs de coffres contraires au code de rareté (coffre « rare » rouge, rareté Rare = lagon) ; passifs qui
   parlent de « monstres » dans un mode sans monstre.
5. **Rejouabilité et méta** : pas de modificateur de partie, d'événement de carte, de saison ni de classement propre au mode, pas
   de premiers pas dédiés ; une partie ressemble beaucoup à la précédente.

---

## 2. Références

### 2.1 Fortnite (Epic) : la référence de lisibilité et de rythme
Vérifié (capture du HUD de combat, Wikipédia ; wiki Fortnite : « The Storm », « Battle Bus », « Victory Royale » ; guides) :
- **HUD** : boussole en haut au centre ; mini-carte en haut à droite et, dessous, une rangée d'icônes-chiffres : minuteur de la
  tempête, survivants, éliminations. Fil des éliminations en bas à gauche, PV et bouclier en deux barres en bas au centre,
  5 emplacements d'objets en bas à droite **colorés par rareté**.
- **Tempête** : la mini-carte trace une **ligne blanche** vers le prochain cercle et une **ligne bleue** vers la zone sûre quand on
  est dehors ; message « You are in the storm. RUN! » ; dégâts croissants, « Storm Sickness » (×3 si on y reste trop) et « Storm
  Surge » (dégâts aux joueurs qui n'ont pas fait assez de dégâts tant qu'il reste beaucoup de monde : anti-attentisme).
- **Largage** : bus en ligne droite tirée à chaque partie, klaxon à l'ouverture des portes, **largage forcé** en fin de trajet ;
  on peut « remercier le chauffeur » (ligne dans le fil) : un petit rituel social.
- **Victoire** : bandeau incliné « #1 Victory Royale », chiffre « #1 » massif, éclat lumineux, ralenti sur la dernière
  élimination ; la **Couronne de victoire** se porte dans la partie suivante.
- **Accessibilité** : « Visualiser les effets sonores » (anneaux autour du réticule : pas en blanc, coffres en or, tirs en rouge).
- Mode **Reload** : réapparition tant qu'un coéquipier vit, coupée en fin de partie (proche de notre réanimation des 2 min).
- Non vérifié : durée moyenne d'une partie (≈ 20 min), écran de récapitulatif de mort détaillé.

### 2.2 Apex Legends (Respawn) : la communication et le butin lisible
Vérifié (capture du HUD avec roue de ping, Wikipédia ; roue de ping, wiki Apex ; wiki « Death Box ») :
- **Ping** : un bouton = « allons ici » ; contextuel (objet, porte, coffre, ennemi) ; **roue** à 7 choix (Ennemi, Je pille,
  J'attaque, J'y vais, Je défends, Je surveille, Quelqu'un est passé ici) ; réponses (OK, Je prends) ; chaque ping a une **voix**
  du personnage. Respawn a testé le jeu **sans vocal** pour le mettre au point (Gamerevolution).
- **Dépouille** (« Death Box ») : un seul coffret par mort qui **luit de la couleur du meilleur objet** qu'il contient ; on y
  récupère tout dans une seule fenêtre.
- **Bannière** récupérable 90 s après la mort, à rapporter à une balise de réapparition.
- HUD : mini-carte en haut à gauche avec le minuteur de l'anneau dessous, « escouades restantes » et éliminations en haut à
  droite, compétences en bas au centre, arme et munitions en bas à droite.
- **Meneur d'éliminations** (« Kill Leader », dès 3 éliminations) et **Jumpmaster** (le meneur de saut de l'escouade).
- Non vérifié : chiffres de dégâts colorés selon le bouclier touché, console d'anneau, bouclier qui évolue en infligeant des
  dégâts.

### 2.3 Super Animal Royale (Pixile) : la 2D vue de dessus, la plus proche de notre caméra
Vérifié (2 captures du wiki, 3 captures Steam, Wikipédia, wiki « Super Skunk Gas ») :
- **Aigle géant** porteur, on saute avec un parapluie : même fantaisie que notre aigle.
- **Gaz** : couvre l'île entière en **6 min 30** ; « Cercle de vie » bleu sur la carte ; **hors du cercle, une flèche montre le
  cercle et une ligne bleue est tracée sur la carte** ; minuteur du prochain resserrement à l'écran ; dernier cercle ajouté pour
  éviter les « concours de soins ».
- **Annonces au centre en haut**, une à la fois, très grosses : « Le gaz avance », « 2 joueurs restants », compte à rebours
  rond « Rejoins le cercle de vie ».
- HUD minimal : petite mini-carte en haut à gauche, au-dessus d'elle trois compteurs (vivants, éliminations, temps) ; objets en
  bas à droite ; fil en bas à gauche ; **« Tu regardes X — clic gauche / droit pour changer »** au centre en bas en spectateur.
- Armure en 1 à 3 crans bleus au-dessus de la vie, réparable au ruban ; boules de hamster, émeus montables : **le monde est un
  jouet**. 64 joueurs, une vie, spectateur ou départ libre.

### 2.4 Spellbreak (Proletariat, serveurs officiels fermés le 10/01/2023) : la magie sans armes à feu
Vérifié (Wikipédia, critiques) :
- Gantelet de classe **fixe** + un gantelet trouvé ; sort principal à mana, « sorcellerie » à recharge ; **combos élémentaires**
  (feu + poison, vent + feu) : le point le plus salué.
- **La classe monte d'un niveau à chaque nouveau cercle** (nouvelles compétences) : l'anneau rythme la puissance, comme nos
  plafonds de niveau par anneau (`Royale.LEVEL_CAPS`).
- Runes de mobilité (vol, téléportation, invisibilité) et lévitation ; critiques : chaos à 6 lanceurs, ping faible.

### 2.5 Brawl Stars, Showdown (Supercell) : la partie courte et lisible sur mobile
Vérifié (wiki Brawl Stars « Solo Showdown ») :
- **10 joueurs**, chacun pour soi ; **cubes de puissance** dans des caisses et sur les éliminés (+400 PV, +10 % d'attaque par cube ;
  un éliminé lâche 1 + un tiers de ses cubes, 5 au plus) : progression visible sur le personnage.
- **Gaz** : 20 % des PV max par seconde, +5 % par tic après 5 s, soins réduits de moitié ; plus fort loin du centre.
- **Modificateurs** de carte (météores, champignons de soin, boissons d'énergie, brouillard « Sightless », « Showdown+ ») ;
  correctifs anti-alliances (météores attirés par les groupes).
- Trophées selon la place ; noms des adversaires cachés au-delà d'un certain niveau de trophées (pression sociale réduite).
- Non vérifié : durée d'une partie (2 à 3 min selon l'expérience courante), invulnérabilité au départ.

### 2.6 Realm Royale (Heroic Leap ; version Reforged, services fermés le 17/02/2025) : classes et artisanat
Vérifié (articles et fiche PlayStation) :
- Classes (Guerrier, Assassin, Mage, Chasseur, Ingénieur) ; **forges** sur la carte où l'on fabrique son équipement avec des
  éclats, au risque d'être attaqué pendant la fabrication ; **monture** pour fuir le brouillard.
- **Mode poulet** : à terre, on devient un poulet qui fuit quelques secondes ; s'il survit, il revient (seconde chance comique).

---

## 3. Comparaison écran par écran (nos captures 0.1.256 contre les références)

| Écran | Nous (capture) | Références | Écart |
|---|---|---|---|
| Page du mode | `royale_ui_2_page`, `m1_02` : bannière, 3 puces, 5 difficultés, stats en une ligne, bouton « Lancer » ; DA v1 (Cinzel, bleu nuit, filets dorés) | Fortnite / Brawl Stars : carte et modificateur du moment, rang de saison, défis du mode, bouton unique | pas de carte du jour, de modificateur, de saison ; DA ancienne |
| À bord de l'aigle | `br4_1` : aigle plein écran, aide « [Espace] Sauter · saut auto dans 11 s », mini-carte avec la ligne du vol | Fortnite : carte ouverte, trajet du bus, repère ; Apex : meneur de saut ; SAR : vue de l'aigle | **pas de carte de choix ni de repère** ; l'aigle cache la carte ; on ne sait pas où vont les autres |
| Chute / planeur | `br4_2`, `br4_3` : aide « Dirige ta chute · [Maj] Piqué · [Espace] Planeur », faisceaux des coffres | Fortnite : altimètre, repère visible au sol, distance | pas d'altitude ni de distance au repère |
| HUD de combat | `br4_4`, `br3_4` : cadre texte en haut à gauche (« Anneau 2/5 · se referme dans 45 s », « 7 / 8 en vie · 1 élimination ») ; mini-carte ronde ; orbes Vie / Niveau ; 4 emplacements de sorts vides affichés « — » ; libellé « ASSISTÉ » | Fortnite / Apex / SAR : compteurs en icônes sous la mini-carte, barres PV + bouclier, emplacements colorés | chiffres clés **noyés dans du texte** ; « — » contraire à la Bible (§ 10) ; pas de bouclier visible (protection du revenant) |
| Hors de l'anneau | `br3_4` : bandeau Cinzel « Hors de l'anneau ! (3 % des PV par seconde) » ; bord violet au sol | Fortnite : lignes blanche / bleue sur la carte ; SAR : flèche à l'écran + ligne + compte à rebours | **pas de direction** vers la zone sûre ; pourcentage dans le texte (interdit par la vision) |
| Dégâts reçus | chiffre au-dessus du héros seulement | genre : arc rouge au bord de l'écran dans la direction du coup ; flèches des adversaires hors champ | **aucun indicateur directionnel** (le code a `ArrivalMarker` pour la Survie, non branché ici) |
| Fil des éliminations | `m1_06`, `br4_5` : petites lignes de texte sous la mini-carte (≈ 13 px), 8 s | Fortnite / SAR : bas à gauche, icône d'arme ; Apex : idem + bannières | trop petit, pas d'icône de classe ni de couleur ; « tu reviendras » mêlé au fil |
| Mise à prix | `m1_06` : bandeau « X est mis à prix · Élimine-le : un niveau de plus », étoile sur la carte | Apex : Meneur d'éliminations annoncé, visible | équivalent, à garder ; à styliser |
| Grande carte | `m1_07` : carré, anneaux, coffres en carrés de couleur, légende qui **mange le coin de la carte** | Fortnite / Apex : lieux nommés, quadrillage, joueur, repère au clic, zoom | **pas de position du joueur**, ni lieux, ni repère, ni zoom |
| Coffre (pièce) | `m1_05` : 3 cartes du Survivant (rareté, jet, passif) + « Relancer (1) » ; le monde est en pause pendant le choix (`CardPicker`, solo contre l'IA : confort à garder) | Apex : on prend dans la caisse ; Fortnite : objet au sol | choix riche (point fort) ; textes de passif hors sujet (« Chaque monstre tué… ») |
| Coffre (amélioration) | `br3_3` : 3 améliorations comparées ▲ (+0 → +2, stats avant → après) | — | bon ; c'est notre profondeur propre |
| Butin au sol | `br3_4` : 8 pièces = 8 faisceaux de couleur qui se chevauchent, invite « [F] Prendre — Tête · Épique (▼ moins bien…) » | Apex : une dépouille, une lueur, une fenêtre | **illisible** à 8 pièces ; une pièce à la fois |
| Inspection | `br3_5` : fiche 9 emplacements, comparaison à ta pièce (▲ / ▼), « Arme : elle ne tombe pas » | — (rare dans le genre) | point fort ; pourcentages et DA v1 à reprendre |
| Mort | `br4_5` : « Tu es éliminé : retour dans 4 s » ; orbe Vie à 0 | Fortnite : caméra sur le tueur ; Apex : bannière, PV restants du tueur | **pas de récapitulatif** (tueur, sort, PV qui lui restaient, dégâts) |
| Spectateur | code : suit le scripté de plus haut niveau, [F] son équipement, Échap = bilan | SAR : « Tu regardes X, clic pour changer » ; Fortnite : suit le tueur | pas de changement de cible ni de suivi du tueur |
| Bilan | `royale_ui_3_bilan` : « TOP 3 », 5 tuiles, Gardé / Perdu, « Rejouer » / « Retour au lobby » ; fond noir | Fortnite : bandeau « #1 » incliné, ralenti ; Brawl Stars : trophées gagnés | **aucune fête**, pas de dégâts, pas de chronologie ; « lobby » (mot interdit côté joueur) |
| Menu pause | `m1_10` : « Compétences de la run (0 / 12) », « Cartes de build », « Arme secondaire : aucune » | — | vocabulaire et blocs de la Survie dans le Battle royale |
| Premiers pas | aucun dédié (aide F1 générale) | Fortnite / Apex : défis d'apprentissage, astuces au chargement | à créer (3 fiches courtes) |

**Ce que nous faisons mieux** : progression lisible de 1 à 40 en une partie (les cartes du Survivant donnent une vraie
construction en 10 min), **inspection** de l'équipement adverse (rare dans le genre), réanimation des 2 premières minutes
(pardonne un mauvais atterrissage sans casser la fin), **mode scellé** (équité), **personne ne frappe en l'air**, plafond de
niveau par anneau (idée de Spellbreak, en mieux bornée), 60 classes jouables, adversaires scriptés qui pillent et fuient.

**Bugs et incohérences relevés pendant l'étude**
- `tests/shot_m1.gd` est obsolète depuis BR4 : il force le combat pendant le vol, ses captures « spectateur » et « bilan » montrent
  le retour et le menu pause (vérifié sur `m1_09`, `m1_10`).
- Passifs liés aux monstres dans le tirage du Battle royale : seuls `volatile` et `magnet` sont bannis (`RoyaleLoot.NO_PASSIVES`) ;
  « Élan meurtrier » (`boons.gd`, « Chaque monstre tué… ») est proposé (capture `m1_05`) ; 8 passifs de `boons.gd` parlent de monstres.
- Couleurs de coffres (`ProcMap.ROYALE_LOOKS`, légende de `minimap.gd`) : commun blanc bleuté, **rare rouge**, doré or, alors que la
  Bible (§ 3) code Rare en lagon : le joueur apprend deux codes.
- Bandeaux avec pourcentage (« 3 % des PV par seconde ») et mots « run », « build », « lobby » à l'écran.

---

## 4. Profondeur du mode

| Sujet | Nous | Références | Recommandation |
|---|---|---|---|
| **Rythme** | 9 min 50 d'anneau (5 phases) + 15 à 22 s de vol ; anneau lancé au dernier atterrissage ; combats ≈ 14 s (BR1) | SAR : gaz complet en 6 min 30 ; Showdown : très court ; Fortnite / Apex : ≈ 20 min (non vérifié) | garder 9-10 min, mais **densifier le début** : 8 héros sur 512 m se croisent peu avant le 2e anneau ; essayer une carte de 384 m ou un 1er anneau à 150 m (mesure `--autoplay`) |
| **Risque / récompense** | coffres de 3 qualités + largages + mise à prix + pièces au sol | Apex : dépouilles riches ; Fortnite : coffres et largages ; Showdown : cubes sur les éliminés | ajouter des **lieux riches nommés** (plus de dorés, plus disputés) et un **événement** au milieu de partie (autel gardé, pluie de météores) |
| **Où atterrir** | au-dessus d'un coffre visible à 200 m | lieux nommés, trajet du bus, voir où sautent les autres | carte de choix pendant le vol, lieux nommés avec ★ de butin, nombre de héros qui visent chaque lieu |
| **Quand engager** | rapport de force caché ; plaque « nom · niv. N » | Apex : bouclier visible par couleur ; SAR : armure en crans | flèche ▲ / ▼ de force relative sur la plaque (niveau + note d'équipement), couleur de famille |
| **Retour en jeu** | réanimation < 2 min, prime +1 niveau, pièces au sol | Fortnite Reload ; Realm (poulet) ; Apex (bannière) | garder ; ajouter le **coffre de revanche** (le revenant voit l'endroit où sont tombées ses pièces) |
| **Classes** | 60 classes ; tournoi 1 contre 1 : les classes à distance gagnent presque tout en terrain nu (BR1) | Spellbreak : 6 éléments + combos ; Brawl Stars : rôles très marqués | **couvert** sur la carte (rochers, murets, buissons qui cachent) pour donner sa chance au contact ; mesurer par famille |
| **IA adverses** | trajet, pillage, fuite si dépassée, traque des affaiblis | — (adversaires humains) | rendre l'intention lisible : petite icône au-dessus du scripté (pille / chasse / fuit) en Facile et Normal |
| **Événements** | réapprovisionnement à chaque anneau, largages | Brawl Stars : modificateurs ; Fortnite : événements de saison | 1 modificateur tiré par partie (ou « du jour ») parmi 5-6 simples |

---

## 5. Détails de confort à reprendre (liste courte)
1. Ligne de trajet vers la zone sûre sur la mini-carte + **flèche au bord de l'écran** quand on est dehors (Fortnite, SAR).
2. **Arc rouge** de coup reçu au bord de l'écran ; flèches des héros proches hors champ (réutiliser `ArrivalMarker`).
3. **Repère personnel** (clic molette / R3 ou clic sur la grande carte) visible à l'écran avec la distance (Apex).
4. Carte ouverte **automatiquement** pendant le vol, saut au clic sur le repère ; altimètre en chute.
5. **Une dépouille = un sac** à la lueur de sa meilleure pièce, fenêtre de pile, « Tout le meilleur » en un appui (Apex).
6. **Récapitulatif de mort** de 3 lignes, spectateur sur le tueur, LB / RB pour changer (Fortnite, SAR).
7. **Bandeau de victoire** incliné, ralenti de 1 s sur la dernière élimination, confettis (Fortnite ; Bible § 8).
8. Annonces **une à la fois** au centre en haut (« 3 héros restants », « Largage ! ») plutôt que des bandeaux qui s'empilent (SAR).
9. Option d'accessibilité « **Voir les sons** » (pas, coffres ouverts, combats proches) en anneaux autour du héros (Fortnite).
10. « **Rejouer** » direct avec la même classe et la même difficulté, sans passer par le menu (déjà présent : le garder primaire).

---

## 6. Backlog priorisé

### P0 : sans ça, le mode fait « prototype »
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 1 | **HUD d'état v2** : 3 tuiles chiffrées (en vie, éliminations, niveau / plafond) et barre de l'anneau sous la mini-carte ; cadre du haut à gauche réduit à l'objectif ; emplacements vides tramés (pas de « — ») ; DA v2 | M | `ui/hud.gd`, `core/royale_director.gd` (`status_text`, `objective_lines`), `ui/ui_theme.gd` |
| 2 | **Direction de l'anneau** : ligne vers la zone sûre sur la mini-carte, flèche au bord de l'écran hors de l'anneau, bandeau sans pourcentage (« Hors de l'anneau ! ») | S | `ui/minimap.gd`, `ui/arrival_marker.gd`, `core/royale_director.gd` (`_ring_damage`) |
| 3 | **Coups reçus et menaces hors champ** : arc fraise dans la direction du coup (Duel, Arènes, Battle royale), flèche des héros à moins de 40 m hors de la vue | M | `ui/hud.gd`, `ui/arrival_marker.gd`, `player/player.gd` (signal de coup reçu avec la source) |
| 4 | **Repère personnel** : molette / R3 au sol ou clic sur la grande carte ; épingle lagon avec la distance à l'écran et sur les cartes | M | `ui/minimap.gd`, `core/royale_director.gd` (`markers`), `core/ui_nav.gd` (action), `core/settings.gd` |
| 5 | **Grande carte v2** : position du joueur et de la cible mise à prix, anneau actuel et suivant, trajet de l'aigle, lieux nommés, légende hors de la carte, zoom, clic = repère ; ouverte seule pendant le vol avec « Sauter » | M | `ui/minimap.gd`, `core/royale_drop.gd` |
| 6 | **Lieux nommés** : 6 à 8 points d'intérêt par carte (ruines, camp, temple) tirés de `_place_pois`, nom en français, richesse ★ à ★★★ (plus de coffres rares / dorés), annonce « Tu atterris aux Ruines du col » ; du couvert (murets, rochers) | L | `world/proc_map.gd` (`generate_royale`, `_build_chests`), `data/names_fr.json` |
| 7 | **Mort et spectateur** : récapitulatif (tueur, classe, niveau, sort du coup de grâce, PV qui lui restaient, dégâts donnés / reçus) ; spectateur sur le tueur, LB / RB pour changer ; « tu reviendras » hors du fil | M | `core/royale_director.gd` (`player_down`, `_update_spectator`, `_unhandled_input`), `ui/hud.gd`, compteur de dégâts dans `core/royale.gd` |
| 8 | **Butin au sol groupé** : un sac par dépouille, faisceau de la meilleure rareté, fenêtre de pile non bloquante (▲ / ▼, Prendre, Tout le meilleur) ; même fenêtre que l'inspection | M | `core/royale_director.gd` (`_fall`, `_scatter`, `_player_take`), `ui/royale_gear_sheet.gd` |
| 9 | **Bilan v2** : bandeau « N°1 · Victoire ! » / « Éliminé · 4e » incliné, rayons et confettis (victoire), 6 tuiles (+ dégâts), chronologie (saut, 1re élimination, largage, mise à prix, fin), Gagné / Record, « Rejouer » primaire, « Menu principal » | M | `ui/royale_results.gd`, `ui/results_panel.gd`, `core/royale.gd` (`last_report`) |
| 10 | **Cohérence** : coffres au code de rareté de la Bible (commun lilas, rare lagon, doré soleil + rayons, largage soleil) ; passifs « monstre » / « kill » retirés ou reformulés en Battle royale ; menu pause du mode sans « run », « build », arme secondaire ; `shot_m1` remis à jour (pose les héros, élimination définitive) | S | `world/proc_map.gd` (`ROYALE_LOOKS`), `ui/minimap.gd`, `core/royale_loot.gd` (`NO_PASSIVES`), `core/boons.gd`, `ui/pause_menu.gd`, `tests/shot_m1.gd` |

### P1 : ce qui fait la qualité
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 11 | **Page du mode v2** (DA v2) : vue du jeu en grand, carte du jour, modificateur, rang de saison, difficulté en pastilles, un bouton primaire | M | `ui/lobby.gd`, `ui/activities.gd` |
| 12 | **Modificateurs de partie** (1 tiré par partie, affiché à la page et au départ) : pluie de météores (zones télégraphiées), nuit (vue réduite), coffres dorés seulement, anneau rapide, fontaines de vie doublées, « tout le monde mis à prix » | L | `core/royale.gd`, `core/royale_director.gd`, `world/proc_map.gd` |
| 13 | **Événement de milieu de partie** : autel gardé (un élite) qui donne un coffre doré, annoncé au 2e anneau | M | `core/royale_director.gd`, `ai/` (élite existante) |
| 14 | **Ligue royale saisonnière** : points selon place et éliminations, rangs Bronze à Platine (réutiliser `League`), apparence de saison | M | `core/league.gd`, `core/royale.gd`, `ui/lobby.gd` |
| 15 | **Premiers pas du mode** : 3 fiches (`Tutorial.CARDS`, ≤ 125 signes) : saut, anneau, butin au sol ; astuce au chargement | S | `core/tutorial.gd`, `ui/hud.gd` |
| 16 | **Force relative lisible** : ▲ / ▼ sur la plaque des adversaires (niveau + note d'équipement), couleur de famille | S | `core/royale_director.gd` (`_refresh_tag`), `ui/` plaque |
| 17 | **Intention des scriptés** (Facile, Normal) : icône pille / chasse / fuit au-dessus de la tête | S | `core/royale_director.gd` (`_order`) |
| 18 | **Annonces centrales** une à la fois (« 3 héros restants », « Largage ! », « Mis à prix ») avec onomatopées Mochiy (Bible § 8) | S | `ui/hud.gd` (`message`) |
| 19 | **Retours de coups** : son et vibration par coup donné / reçu entre héros, « Critique ! » en onomatopée, éclat au dernier coup | M | `combat/sfx.gd`, `ui/hud.gd`, `UiFeel` |
| 20 | **Densité** : mesure 384 m contre 512 m et 1er anneau plus serré (`--royale --autoplay`, premier contact, médiane de durée) | M | `core/royale.gd` (`START_RADIUS`, `PHASES`), `world/proc_map.gd` |

### P2 : finitions et confort
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 21 | Option « Voir les sons » (pas, coffres, combats) en anneaux autour du héros | M | `ui/hud.gd`, `combat/sfx.gd`, `ui/settings_menu.gd` |
| 22 | **Apparences de planeur et de traînée** de chute (récompenses du mode, rôle « apparences ») ; couronne du vainqueur portée la partie suivante | M | `core/royale_drop.gd`, `core/rewards.gd` |
| 23 | Remercier l'aigle (emote à bord, ligne dans le fil), petite fête au saut | S | `core/royale_drop.gd` |
| 24 | Statistiques de carrière du mode (Carnet) : victoires par classe, meilleur nombre d'éliminations, dégâts | S | `ui/carnet_pages.gd`, `core/achievements.gd` |
| 25 | Défis du mode dans les quêtes (atterrir dans un lieu ★★★, gagner sans réanimation, éliminer le mis à prix) | S | `core/quest_pool.gd` |
| 26 | Partie personnalisée (graine, modificateur, nombre de scriptés) pour l'entraînement | S | `ui/lobby.gd`, `core/royale.gd` |

---

## 7. Spécification « version 2 » (dans notre DA)

**Déroulé d'une partie (≈ 10 min 30)**
1. **Page du mode** (maquette 6) : carte du jour et modificateur ; difficulté ; « Lancer ».
2. **Vol (15-22 s)** (maquette 2) : la grande carte s'ouvre seule ; trajet de l'aigle en pointillés, lieux nommés ★, nombre de
   héros qui visent chaque lieu (les scriptés choisissent déjà une cible : `RoyaleDrop`) ; un clic pose le repère ; « Sauter » (Y)
   ou saut auto. B ferme la carte (vue de l'aigle).
3. **Chute** : altimètre à droite, distance au repère, piqué (Maj), planeur (Espace) ; annonce du lieu à l'atterrissage.
4. **Pillage et combats** (maquette 1) : HUD v2 ; coffres au code de rareté ; dépouilles groupées (maquette 3) ; réanimation
   < 2 min avec son compte à rebours au centre.
5. **Anneaux** : barre et minuteur sous la mini-carte, ligne et flèche vers la zone sûre ; annonce centrale à chaque resserrement
   avec le nouveau plafond de niveau (« Niveau max 26 ! ») ; largage annoncé (« Largage ! » + étoile).
6. **Élimination** (maquette 4) : récapitulatif ; spectateur sur le tueur ; bilan à tout moment (B).
7. **Fin** (maquette 5) : ralenti de 1 s sur le dernier coup, bandeau incliné, confettis (victoire) ; bilan ; Rejouer.

**Écrans** (maquettes : `battle_royale_maquettes/index.html`)
- HUD : haut gauche = objectif court (1 ligne + 1 sous-ligne) ; haut droit = mini-carte ronde 270 px, 3 tuiles d'encre (en vie,
  éliminations, niveau / plafond), barre de l'anneau sur papier, fil en pastilles (carré de couleur de famille, ⚔, gain) ; bas
  centre = carte de vie papier (barre fraise deux tons, trace blanche des dégâts, bande lagon de protection, potions), 4 cases de
  sorts autocollantes avec recharge en camembert, case d'esquive pomme, orbe de niveau à anneau d'expérience pomme.
- Plaques : « Classe · niv. N ▲ » sur papier, barre de vie courte pour les adversaires touchés depuis moins de 5 s.
- Couleurs : anneau et dehors = améthyste (déjà le violet du jeu), repère = lagon, largage = soleil, danger = fraise ; jamais de
  texte blanc sans contour d'encre ; aucun pourcentage dans le texte permanent (infobulle seulement).
- Polices : Mochiy Pop One pour les bandeaux, titres et onomatopées ; M PLUS Rounded 1c 900 pour les chiffres (tabulaires).

**Retours** (Bible § 7-8) : coup donné = petit éclat + « tic » ; coup reçu = arc fraise 400 ms + vibration (0 ; 0,35 ; 0,09) ;
élimination = onomatopée « K.O. ! » 600 ms + pastille du fil qui glisse ; montée de niveau = « Niveau ! » + étoiles ; coffre
doré = rayons ; victoire = traits de vitesse, confettis des 5 bonbons, signature sonore de rareté.

**Règles inchangées** (décisions du joueur, à ne pas toucher sans lui) : vitesse et qualité d'équipement des scriptés (retour du
16/10), arme gardée toute la partie, améliorations une fois l'équipement complet, réanimation < 2 min, largage dirigé.

---

## 8. Questions ouvertes (avec recommandation)
1. **Taille de la carte pour 8 héros** (512 m) : la tester à 384 m ou serrer le 1er anneau ? *Reco : mesurer les deux au pilote
   (premier contact, part de la partie passée à marcher) avant de choisir ; ne rien changer sans mesure.*
2. **Repère utile en solo ?** *Reco : oui, comme point de passage personnel (carte, chute, retour) ; il préparera un mode à deux
   avec un allié IA (Arènes en ont déjà, `Duel.make_ally`).*
3. **Ligue royale saisonnière** (P1-14) : faut-il un classement propre ou rester sur les insignes plafonnés au jour ? *Reco :
   une ligue légère (points de place + éliminations, rangs de `League`), récompense = une apparence par saison.*
4. **Modificateurs** : un par partie au hasard, ou un « du jour » commun ? *Reco : « du jour » (comme le Défi du jour), avec une
   partie « classique » toujours disponible.*
5. **Intention des scriptés affichée** : utile en Facile / Normal, mais casse-t-elle l'illusion en Hardcore ? *Reco : seulement
   Facile et Normal.*
6. **Couvert** (murets, rochers) pour rééquilibrer distance contre contact : ajoute du décor alors que BR2 en a retiré (« trop de
   caisses inutiles »). *Reco : peu d'éléments, grands, non cassables, regroupés dans les lieux nommés (jamais d'objets à casser).*
7. **Mise à prix** : la garder telle quelle (visible de tous) ? *Reco : oui (équivalent du Meneur d'éliminations d'Apex), mais
   l'annoncer avec la tuile du HUD qui passe en fraise quand c'est toi.*

---

## 9. Sources (consultées le 17/10/2026)
- Wikipédia : « Fortnite Battle Royale » (capture du HUD de combat), « Apex Legends » (capture avec la roue de ping),
  « Spellbreak », « Super Animal Royale ».
- Wiki Fortnite (fandom) : « The Storm », « Battle Bus », « Victory Royale » (bandeaux de victoire) ; guides « Visualize Sound
  Effects » (afkgaming.com, esports.gg, ggrecon.com, sportskeeda.com) ; mode Reload (videogameschronicle.com, ggrecon.com,
  insider-gaming.com).
- Wiki Apex Legends (apexlegends.wiki.gg) : « Ping » (roue de ping), « Death Box » ; uxdesign.cc « Apex Legend's ping system —
  gaming UX done right » ; pcgamer.com ; gamerevolution.com (tests sans vocal).
- Wiki Super Animal Royale (animalroyale.fandom.com) : « Super Skunk Gas » (2 captures : spectateur, cercle de vie), « Armor » ;
  boutique Steam (app 843380, 6 captures) ; fiches PlayStation.
- Wiki Brawl Stars (brawlstars.fandom.com) : « Solo Showdown » ; toucharcade.com.
- Spellbreak : windowscentral.com, primagames.com, thegamer.com, inverse.com (talents, niveau de classe par cercle).
- Realm Royale : nintendolife.com, thexboxhub.com, fandom.com, fiche PlayStation « Realm Royale Reforged » (fermeture 17/02/2025).
- Boutique Steam Apex Legends (app 1172470, captures promotionnelles sans HUD).
