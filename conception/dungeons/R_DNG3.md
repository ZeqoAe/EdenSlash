# Lot DNG-3 : le P1 de confort des modes de boss (Donjons, Tour, Ruée, Siège) (17/10/2026)

Mandat : le P1 restant de l'étude BM-DNG (`conception/benchmark/DONJONS_TOUR_RUEE_SIEGE.md`, recommandations validées) sur les
lots DNG-1 / DNG-2 : étoiles de donjon (P1-1), relève (P1-3), « S'entraîner » (P1-4), Siège lisible (P1-9), Ruée chronométrée
(P1-10), palette réglable des télégraphes (P1-11, accessibilité), « Autre boss » au bilan, mur d'arène mandarine ; puis le P2 selon
le temps (classement local par graine de Ruée). **Aucun réglage d'équilibre** (l'équipe H56 règle l'échelle des activités et le rythme) :
`Dungeons.boss_hp`, `Epochs`, `GearPower`, butin, cristaux, plans et verrous n'ont pas bougé. **Aucune économie nouvelle** : une étoile
ne donne qu'une médaille ; seuls des paliers d'étoiles donnent un titre ou un coffre d'apparence (cosmétique).

## 1. Ce qui est fait

### Étoiles de donjon (P1-1) : `core/dungeon_stars.gd` (`DungeonStars`, nouveau)
- Trois objectifs facultatifs par donjon (un par boss de la bibliothèque) et par difficulté, comme le Siège :
  **★ Le boss tombe** (une reprise au boss compte), **★ Sous 7:30** (le donjon d'une traite, sans reprise, sous le temps **écrit à
  l'avance** sur la page), **★ Personne ne tombe** (ni toi — aucune relève — ni un allié IA).
- Temps affiché (`DungeonStars.par`) : médiane du pilote × 1,3 comme le recommande l'étude (R_A2 : 5:48 en Normal, ≈ 4:45 en Héroïque
  et Mythique, héros invincible) → **7:30 / 6:15 / 6:15** ; + 45 s pour un boss à objets à casser (totems, cristaux, tourelles : le pilote
  les ignore, R_A2) ; au quart de minute. Les PV des boss ne sont pas touchés.
- Stockage : `Profile.records["dgs_<boss>_<diff>"]` = bits (clé neuve, rien à migrer), écrit **après** le rechargement du profil
  (`Tower._finish_dungeon`, comme le butin).
- Paliers (donjons à trois étoiles) : 1 → titre « Étoilé » ; 12 → « Constellation » + un coffre d'apparence ; 48 en Mythique →
  « Firmament » + un coffre d'apparence. Rien d'autre (vérifié par `test_dng3` : ni cristal, ni coffre hors apparence).
- Page Donjons : section « Objectifs ★☆★ » (trois autocollants : soleil si tenu, papier sinon, le temps écrit), le prochain palier
  (« Encore 11 donjons à trois étoiles : titre « Constellation » et un coffre d'apparence »). Bilan : les trois objectifs (« nouvelle »
  sur celles gagnées), les titres et coffres de palier dans Gagné / Gardé.

### Relève (P1-3) : `core/relief.gd` (`Relief`, nouveau)
- Un coup fatal ne finit pas la partie : le héros se relève sur place (moitié des PV, 2,5 s intouchable) ; « Relève ! Prêtre te remet
  debout » s'il a un allié debout. **Une au départ, rendue à chaque boss** (`BossLibrary.spawn`, jamais un lieutenant), jamais deux d'avance.
- Donjons et Ruée : Normal et Héroïque ; **aucune en Mythique**. La Tour : Facile à Difficile ; **aucune en Hardcore**. Le Siège (une
  seule vie, chacun pour soi), la Survie et les autres modes : aucune. L'entraînement : sans objet (on s'y relève toujours).
- Pastille **« Relève 1 »** collée aux PV (pomme ; « Relève 0 » grise une fois prise). Une relève prise coûte l'étoile « Personne ne tombe » ;
  le bilan le dit (« Relève utilisée : 1 fois »).
- **Mesures d'équilibre préservées** : le pilote automatique des outils (`Player.autoplay` : dungeon_run, tower_run, m6_run, boss_ttk)
  n'a jamais de relève, ses mesures restent comparables à celles d'avant ; `Relief.enabled = false` pour un test qui mesure une chute.
- « Réessayer proprement » : après une chute devant le boss, le bilan propose **Réessayer le boss · S'entraîner · Retour au menu** ;
  « Autre boss » rouvre la page Donjons (changer de difficulté, d'alliés ou de boss sans repasser par le menu Jouer).

### « S'entraîner » (P1-4) : `core/boss_practice.gd` (`BossPractice`, nouveau)
- La salle du boss d'un donjon (moteur des Donjons, reprise à la salle 3), **sans rien gagner ni perdre** : à la sortie la sauvegarde
  est rechargée telle qu'avant (ni butin, ni maîtrise, ni niveau de héros, ni records, ni étoiles, ni rencontres ; vérifié octet pour
  octet par `test_dng3`). K.O. : on se relève aussitôt ; boss vaincu : il revient à pleine vie.
- Panneau dans la pile de gauche du HUD (F3 pour le replier) : **Héros invincible** (par défaut : il prend les coups et les chiffres,
  ses PV ne baissent pas), **« Rejouer : <mécanique> »** pour chaque brique du boss (une périodique part tout de suite ; une à seuil est
  lancée ; « vue 3 » compte les passages), **Boss à pleine vie**, **Quitter l'entraînement** (retour à la page Donjons sur ce boss).
- Entrées : page Donjons (« S'entraîner contre Mori », lagon, sous les objectifs) et bilan d'une chute (le boss du donjon, ou le boss
  qui t'a battu dans la Ruée).

### « Autre boss » au bilan
- `DungeonPage.lobby_request` (comme `Survivor.lobby_request`) : le bilan d'un donjon gagné (ou d'une chute avant le boss) propose
  **Rejouer · Autre boss · Retour au menu** ; « Autre boss » rouvre le menu principal directement sur la page Donjons (le boss du bilan
  sélectionné, la liste dessous). La fin d'un entraînement fait de même.

### Siège lisible (P1-9) : `core/siege_score.gd` (`SiegeScore`, nouveau), `core/siege_director.gd`
- **Tableau des trois** (pile de gauche) : toi et tes deux alliés, dégâts au boss et aux lieutenants (le coup de grâce borné aux PV qui
  restaient), chutes (✝), dernier coup au boss (⚔), ♛ devant celui qui mène ; noms de classe en français.
- **Objectifs en direct** sous le tableau : ★ tenu, ☆ encore possible, ✗ manqué ; « Avant sa fureur » avec son compte à rebours.
- **Horloge** qui dit ce qu'elle compte : « Vague 2/5 · 1:23 » (temps de la partie), « Boss · fureur dans 5:53 », « Boss · en fureur »
  (avant : « Boss 5:53 », qui ressemblait à un temps de combat) ; la barre de boss porte la pastille **« Fureur 5:53 »** comme l'Impatience.
- **Annonces** : « Fureur dans 1 minute ! » et **« Trêve : il est en fureur ! »** passent en alerte critique sous la barre (28 signes) ;
  « évite les zones hachurées » (plus « rouges »).
- **Zones** : l'anneau du chacun pour soi passe en mandarine, **bas** (4 m au lieu de 26 : vu du dehors il teintait tout l'écran) avec un
  **liseré au sol** qui suit son rayon.
- Bilan : « Dégâts au boss : Prêtre en tête (48 %) · dernier coup : toi » ; tuile du temps contre le **record du boss du Siège** (clé
  neuve `siege:<zone>:<diff>` de `BestTimes`).

### Ruée chronométrée (P1-10 + P2 « classement local ») : `core/rush_board.gd` (`RushBoard`, nouveau), `core/rush_director.gd`
- **Fil des temps** pendant la Ruée (pile de gauche) : « Ruée · 4:12 (record 12:04) », puis les huit boss — vaincus avec leur temps (★ si
  record, sinon le record entre parenthèses), celui en cours qui tourne (mandarine, « / record »), les suivants (« ??? » à l'aveugle).
- **Classement local** par tirage et difficulté (`records.rush_board` : 5 meilleurs temps, jour, modificateurs) ; bilan : « Meilleur temps
  sur le tirage n° 6073 (ancien 12:11) » ou « 2e temps sur 3 ».
- **« Ce tirage encore »** au bilan d'une Ruée gagnée (qui tirait un nouveau tirage) et **« Rejouer ce tirage »** sur la page Ruée
  (« Tes temps » : le classement du tirage proposé, tes tirages les plus rapides) : la graine **et** les boss de la Ruée d'avant sont
  remis (le tirage en dépend, `Rush.lineup_for`), donc les mêmes huit boss dans le même ordre (vérifié).
- Corrigé au passage : le bilan de la Ruée ne recevait jamais sa graine (`Rush.reset()` passait avant), la tuile du temps ne pouvait pas
  dire « Record ! » du tirage.
- Non fait : une graine **à taper** pour partager un tirage (le tirage dépend aussi de la Ruée d'avant de chacun : partager demanderait de
  changer `Rush.lineup_for`, donc les tirages actuels).

### Palette des télégraphes (P1-11) : `combat/telegraph.gd`, Paramètres > Caméra & interface > Accessibilité
- **Couleur des zones de danger** : Auto (fraise ; mandarine si « Couleurs pour daltoniens » est coché), Fraise, Mandarine, Améthyste
  (couleurs des jetons de la bible). **Intensité des zones de danger** : 60 à 150 % (voile, hachures, cœur ; le cœur ne dépasse jamais 50 %).
- Les formes ne changent jamais : hachures = danger, pointillés + « SÛR » = sûr (pomme, quelle que soit la palette). Une couleur imposée
  par une mécanique reste la sienne.

### Barre de boss : plus de pourcentage permanent (demande de la coordination, signalé par HUD-2)
- Le centre de la jauge disait « 62 % » (texte permanent, contraire à la règle « aucun pourcentage dans le texte permanent ») : il dit
  maintenant les **PV qui restent en valeur lisible** (`BossBar.hp_text` : « 1,24 M PV », « 845 k PV », « 920 PV ») ; les seuils réels restent
  dessinés par les encoches. `test_dng2` le contrôle (aucun « % », valeur = `hp_text`).
- Reste à arbitrer : la frise « À venir » écrit encore « à 35 % » pour une mécanique à seuil (c'est la seule façon de dire quand elle
  tombe ; on pourrait écrire « au tiers » / « à mi-vie »).

### Mur d'arène mandarine
- `BossBricks.ArenaWall` (brique « Arène qui se resserre ») : bande et liseré en mandarine (jetons `bonbon.mandarine.base` / `clair`) ;
  **seule la couleur** a changé dans `boss_bricks.gd` (rayons, délais, dégâts intacts).

## 2. Fichiers
Nouveaux : `core/dungeon_stars.gd`, `core/relief.gd`, `core/boss_practice.gd`, `core/rush_board.gd`, `core/siege_score.gd`,
`ui/dng_hud.gd` (`DngHud` : pastille de relève, fil des temps, tableau du Siège, panneau d'entraînement ; posé par `BossBar.attach`),
`tests/test_dng3.gd`, `tests/shot_dng3.gd`. Retouchés (blocs ciblés) : `core/tower.gd` (remises à zéro, relève du départ, étoiles,
classement, temps du Siège, graine au bilan), `core/world.gd` (relève, K.O. et sortie de l'entraînement), `core/tower_director.gd`
(allié tombé, boss qui revient à l'entraînement), `core/siege_director.gd`, `core/rush_director.gd`, `core/boss_library.gd` (relève
rendue au boss), `core/best_times.gd` (`siege_key`), `ui/dungeon_results.gd` (boutons, étoiles, notes), `ui/dungeon_page.gd`,
`ui/lobby.gd` (`lobby_request`, `_start_practice`, bloc « Tes temps »), `ui/boss_bar.gd` (fureur du Siège), `combat/telegraph.gd`,
`ai/boss_bricks.gd` (couleur), `ui/boss_bar.gd` (PV en valeur, `hp_text`), `core/settings.gd`, `ui/settings_menu.gd`, `tests/test_dng1.gd` (relève coupée dans ses chutes ; boutons
de défaite : Réessayer le boss · S'entraîner · Retour).

## 3. Vérifications
Sur une copie propre de HEAD + ce lot (le travail en cours des autres sessions n'y entre pas).
- `test_dng3` (nouveau, ≈ 90 contrôles) : étoiles (temps affiché, reprise, relève, allié tombé, une seule fois, paliers et titres, aucune
  économie nouvelle), règles de la relève (Normal / Mythique / Tour Hardcore / Difficile / Siège, lieutenant, jamais deux), classement de
  la Ruée (tri, 5 au plus, hors classement, « Rejouer ce tirage » = mêmes huit boss), tableau du Siège (dégâts, chute, dernier coup,
  allié remplacé), palette et intensité, mur mandarine ; **parties réelles** : relève devant le boss (relevé à 50 %, intouchable, pastille
  « Relève 0 », 2e chute = bilan avec Réessayer · S'entraîner · Retour), victoire (étoiles écrites après le rechargement, PV fixes du boss
  inchangés, boutons Rejouer · Autre boss · Retour, bilan dans 1280×720), entraînement (panneau, un « Rejouer » par mécanique,
  invincible, K.O. sans bilan, boss qui revient, **profil identique à la sortie**), Ruée (fil des temps), Siège (tableau, horloge, pastille
  de fureur, trêve en alerte, objectif manqué à la fureur) ; pages (« Autre boss » rouvre la page Donjons, objectifs, « S'entraîner »,
  « Tes temps ») ; tout dans l'écran en 1280×720 et 1600×900.
- Captures **regardées** (`tests/shot_dng3.tscn` -> `user://shots/dng3_<cas>_<largeur>.png`, hors dépôt ; `DNG3_RES=1280x720` pour une
  seule taille — jamais un argument « -- » : le menu principal le prend pour un lancement de partie et la capture se bloque ; sur cette
  machine la fenêtre reste en 1600×900, la tenue en 1280×720 est contrôlée par les tests headless) : page Donjons (objectifs,
  S'entraîner), page Ruée (Tes temps), bilans (victoire avec étoiles et « nouvelle », chute avec S'entraîner), combat avec zones améthyste et
  pastille « Relève 1 », mur mandarine, salle d'entraînement, fil des temps, tableau du Siège (avant et après la chute du boss).
- Régressions vertes sur la copie propre (HEAD + ce lot) : test_dng1, test_dng2 (mis à jour : intensité réglable, PV sans pourcentage),
  test_m2, test_m3, test_m6, test_m7, test_siege, test_tower, test_nav_screens, test_pages, test_texts_fr, test_results (mis à jour : 3 boutons
  au bilan de donjon), test_a2, test_hud, test_p11, test_p4_activities (toutes les activités jusqu'au bilan et Rejouer).

## 4. Ce qui reste
- P1 de l'étude non demandés ici : défi de la semaine (P1-2), première rencontre d'une mécanique (P1-5), coups signatures (P1-6),
  faveurs de la Tour (P1-7), Ombres mises en scène (P1-8), « Aide douce » après 3 échecs (P1-11, proposée, jamais imposée), deux barres
  quand lieutenant et boss se battent ensemble au Siège.
- P2 : compteur de dégâts par sort au bilan, vue 3D du boss dans le journal, ligne « Coups reçus », photo de victoire, Mythique « + ».
- Le panneau d'entraînement se joue à la souris (F3 pour le replier) ; à la manette, on en sort par la pause (« Abandonner »).
- Les temps affichés des étoiles viennent du pilote invincible (R_A2) : à revoir au journal réel quand il aura des donjons.

Aucun texte ni image tiers dans ce lot (icônes du jeu et pictogrammes maison ; textes écrits pour le jeu).
