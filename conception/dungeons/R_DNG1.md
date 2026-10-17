# Lot DNG-1 : après-combat des Donjons, de la Tour, de la Ruée et du Siège (17/10/2026)

Mandat : sous-ensemble du backlog P0 de l'étude BM-DNG (`conception/benchmark/DONJONS_TOUR_RUEE_SIEGE.md`, recommandations validées par
le joueur) qui ne dépend **pas** du socle d'interface UIK-0 : P0-5 (« Ce qui t'a battu »), P0-6 (temps et records), P0-7 (bilan v2,
côté données + affichage simple), P0-9 (journal des rencontres, couche données), P0-10 (corrections visibles). Rien n'a été fait sur la
barre de boss v2, la frise « À venir », les annonces à 3 niveaux, les télégraphes v2 ni la page Donjons v2 (ils attendent UIK-0) ;
`ui/ui_theme.gd`, `ui/menu_widgets.gd`, `ui/page_screen.gd` n'ont pas été touchés.

## 1. Ce qui est fait

### « Ce qui t'a battu » (P0-5) : `core/hit_log.gd` (`HitLog`, sans interface)
- `Combatant.take_damage` appelle `HitLog.note(victime, dégâts, source, dot)` ; seul le héros du joueur compte (ni héros ennemi, ni
  entraînement). Chaque coup : instant, part des PV max (le coup de grâce est borné aux PV qui restaient), source en français sans
  étiquette (« Latif », « Gobelin » pour une élite « Gobelin · Flaques »), mécanique, boss.
- Attribution d'un coup de boss : `BossBrain.note_cast(type)` (appelé par `BossBricks.run` pour les 29 briques et par les 5 attaques de
  base `slams`, `charge`, `cleave`, `barrage`, `nova`), puis `BossBrain.blame(dot)` = la dernière mécanique lancée dont la fenêtre
  (`HitLog.WINDOWS`, 2 à 16 s selon la brique) couvre l'instant du coup ; les dégâts continus vont d'abord aux briques qui laissent une
  zone (`puddles`, `meteors`, `shrink`). Une invocation porte la brique qui l'a appelée (meta `boss_brick` posée par `BossBrain._summon`).
  Coup d'un monstre sans mécanique : « Coups au contact » ; source inconnue : « Effets et pièges ».
- `HitLog.report()` : les coups des 8 dernières secondes avant la chute, regroupés par source et mécanique, 3 lignes au plus (la plus
  lourde d'abord, le coup final toujours visible), la mécanique fautive (celle qui a pris le plus de PV) et **son conseil**
  (`HitLog.TIPS` : une phrase courte par brique et par attaque de base, 34 textes, ≤ 95 signes ; distincte du conseil d'entrée
  `BossBricks.DEFS.hint`, qui dit ce que fait la mécanique). `HitLog.died()` : le bloc n'apparaît qu'après une vraie chute.
- Remis à zéro au début de chaque partie de la Tour, des Donjons, de la Ruée et du Siège (`Tower.start`).

### Temps et records (P0-6) : `core/best_times.gd` (`BestTimes`)
- Clé neuve `Profile.records.best_times` = {clé -> secondes} : `boss:<activité>:<boss>:<diff>` (Donjons, Ruée, Tour), `dungeon:<boss>:<diff>`
  (donjon complet, jamais pour une reprise au boss), `tower:<diff>:<tranche>` (10 étages montés d'une traite), `rush:<graine>:<diff>`
  (tirage complet). Aucune clé existante renommée ; une vieille sauvegarde n'a rien à migrer ; une clé abîmée se lit comme vide.
- Horloge `BestTimes.clock` = temps de jeu de la partie (avancée par `TowerDirector.update` et `SiegeDirector.update` : rien ne compte
  pendant une pause ou un choix de carte). Le temps d'un boss part de son apparition (`Encounters.met`, depuis `BossLibrary.spawn`) et
  s'arrête à sa mort.
- **Piège évité** : `Tower.finish` recharge la sauvegarde (`Profile.reload_keep_records`), qui ne garde pas les dictionnaires modifiés
  en partie. Les temps et les rencontres sont donc mis de côté pendant la partie et écrits par `BestTimes.commit()` /
  `Encounters.commit()` **après** ce rechargement, avant la sauvegarde (Tour et donjons).
- Bilan : tuile « temps » contre le record (« 4:12 · temps · Record ! », infobulle « Ancien record : 4:31 »), tuile « boss » au Donjon,
  annonces « Record ! Latif en 1:58 (ancien 2:20) » (2 au plus, les autres comptées).

### Bilan v2 côté données (P0-7) : `ResultsPanel` (même composant pour tous les bilans)
Nouvelles clés de la description (`show_spec`), toutes facultatives :
- `loot` : butin en cases ({name, sub, rarity, tip, item}) ; `ResultsPanel.loot_entry(objet)` pour un vrai objet (pièce, emplacement,
  niveau, rareté, infobulle `Items.describe`). Donjon : le coffre de panoplie (« Tête ou Gants · Phénix · Nv 46 · légendaire possible »),
  le coffre d'équipement en Mythique, le plan ; Tour : les objets des coffres de l'ascension, les meilleurs d'abord.
- `missing` : les emplacements du boss qui manquent encore à sa panoplie (`Encounters.missing_slots`, d'après les objets possédés
  portant son `archetype`) : « Il te manque encore ici : Gants (seul emplacement de Latif qui te manque) ».
- `stars` : objectifs ★ / ☆ (le Siège : ses 3 étoiles, « nouvelle » sur celles gagnées à cette partie).
- `defeat` (+ `defeat_note`) : le bloc « Ce qui t'a battu » (3 lignes, part des PV, coup final, conseil en or ; note « Ton meilleur sur
  Latif : il lui restait 41 % (aujourd'hui 22 %) »).
- **Réessayer le boss** (étude : défaite → « Réessayer le boss (depuis la salle 3) ») : bouton principal après une chute dans la salle du
  boss d'un donjon ; `Tower.start_dungeon(…, from_room)` reprend à la salle 3, une carte tirée par salle sautée, butin normal à la
  victoire (le temps de donjon complet n'est pas enregistré).
- **Reprendre (étage N)** à la Tour : voir P0-10.
- Fenêtre basse : la place de la liste des blocs est maintenant **mesurée** (`_fit`), et un bilan trop riche se resserre par étapes
  (`_compact` : titre 36 sans ornement, note de bas de page, cases du butin — qui restent dans « Gardé » —, note de meilleur pourcentage,
  annonces réduites à une). Vérifié : rien hors de l'écran en 1280×720 ni en 1600×900.
- « S'entraîner » (maquette) n'est pas fait : il dépend de P1-4 (salle d'essai).

### Journal des rencontres, couche données (P0-9) : `core/encounters.gd` (`Encounters`)
- Clé neuve `Profile.records.encounters` = {boss -> {met, won: {activité -> n}, seen: {brique -> n}, in: {activité -> n}, low}} ;
  alimentée par toutes les parties de la Tour, des Donjons (lieutenants compris : activité « lieutenant »), de la Ruée et du Siège
  (`BossLibrary.spawn` -> `Encounters.met` ; `BossBrain.note_cast` -> `Encounters.saw` ; mort du boss -> victoire + temps).
- Lecture pour le futur onglet du Carnet : `Encounters.card(id)` (nom caché « ??? » tant que la zone n'est pas ouverte et le boss
  jamais vu, état won / met / unknown, victoires par activité, où il a été vu, mécaniques avec nom, famille, conseil d'entrée, conseil
  après chute et compteur de vues — **jamais cachées**, records par difficulté des Donjons : victoires `dgb_*`, meilleur temps du boss et
  du donjon complet, emplacements et panoplie, emplacements qui manquent, meilleure part de PV laissée sans le battre),
  `Encounters.all()` (48 fiches, 6 par zone), `Encounters.counts()`.
- **L'onglet « Rencontres » du Carnet n'est pas fait** : il viendra avec la DA v2 (maquette `donjons_maquettes/v2_journal_rencontres.svg`),
  ajouté **à la fin** de `CarnetPages.tabs()`.

### Corrections visibles (P0-10)
- **« Doubledoor » en anglais** (intro du boss de zone des Marais, `data/zones.json` et `data/bosses.json`) : `NamesFr.fr_text` remplace
  le nom anglais du boss (et de son compagnon) par son nom français dans les intros, à l'application des noms (`NamesFr.apply`) et dans
  `BossLibrary.intro` ; « Miller » (Meunier) était dans le même cas. Les fichiers générés ne sont pas retouchés (une régénération
  remettrait l'anglais). Test : aucune intro ne contient le nom anglais de son boss.
- **Bandeau d'annonce qui débordait sur la mini-carte** : `reset_size()` gardait le bord gauche, le bandeau grandissait vers la droite ;
  il est maintenant recentré (`Hud._center_banner`) et sa largeur bornée à l'espace entre les deux bords moins la mini-carte
  (`BANNER_SIDE` 270, `BANNER_MAX` 1000) : un titre trop long passe à la ligne (`Hud._fit_banner`).
- **« Dégâts cumulés » hors écran** : le compteur grandit maintenant vers la gauche (`grow_horizontal` BEGIN).
- **`tests/shot_m2.gd`** : `begin(Dungeons.ROOMS.size())` (salle 3/3 au lieu de « Salle 4/3 »).
- **« Rejouer (étage 1) » après une chute à l'étage 12** : vérifié en partie réelle (test `test_dng1` : ascension partie de l'étage 1,
  chute à l'étage 12) : le bouton reprenait bien l'étage de départ de l'ascension, jamais le palier atteint. Corrigé : après une chute ou
  un arrêt, « **Reprendre (étage 11)** » (palier de reprise `Tower.checkpoint`, s'il est plus haut que l'étage de départ et ouvert) passe
  en bouton principal, puis « Rejouer (étage 1, Normal) » et « Retour au lobby » (`TowerResults.resume_floor`).
- **Test anti-débordement du HUD de boss** en 1280×720 et 1600×900 (`test_dng1`) : barre du boss, bandeau d'annonce (intro très longue),
  compteur de dégâts dans l'écran, bandeau à l'écart de la mini-carte.

## 2. Mesures et vérifications
Tous les tests ont tourné sur une **copie propre de HEAD + ce lot** (`run_tests.py --snap … --reuse` : le travail en cours des autres
sessions ne s'y mêle pas), d'abord sur HEAD 0.1.259 puis sur HEAD 0.1.260.
- `test_dng1` (nouveau, 72 contrôles) : attribution, regroupement et conseil (`HitLog`), records (premier temps, record battu, plus lent,
  clé abîmée), fiches du journal (48, vieilles victoires `dgb_*`, emplacements qui manquent), intros sans nom anglais ; **parties réelles** :
  donjon repris à la salle du boss puis gagné (temps du boss mesuré, fiche « vaincu », records écrits après le rechargement du profil,
  butin en cases), chute devant le boss (bloc, « Réessayer le boss » en premier, coup final « Pluie de météores · Mori Mori », part de PV
  laissée au boss = 0,72), chute à l'étage 12 de la Tour partie de l'étage 1 (« Reprendre (étage 11) » puis « Rejouer (étage 1, Normal) ») ;
  HUD de boss et bilans dans l'écran en 1280×720 et 1600×900.
- Verts aussi : test_m2, test_m3, test_m6, test_m7, test_m8, test_a1, test_a2, test_results, test_nav_screens, test_pages, test_hud,
  test_texts_fr, test_names_fr, test_siege, test_tower, test_p11, test_p13, test_royale, test_bri2, test_uik0, test_lot13, test_lot13b,
  test_p4_flow, test_p4_migration, test_p4_activities (toutes les activités jouées jusqu'au bilan et Rejouer), test_ac_rewards,
  test_quests, test_compass, test_journal.
- Pilote automatique (`tools/dungeon_run`, compte neuf, copie de l'outil qui imprime `HitLog.report()`) : trois chutes réelles, toutes
  attribuées : Latif (Guerrier) tombe en salle 1 en 13 s, 19 coups, 74 % des PV à la Pluie de météores de l'élite « Wells » ; Mori
  (Magicien) 28 s, 37 coups, 90 % aux météores de l'élite « Appacka » (zones au sol comprises) ; Argus Héroïque (Guerrier) 12 s,
  7 coups au contact (Lanka 64 %). Le conseil affiché est celui de la brique fautive (« Ne t'arrête pas sous les météores : chaque
  impact laisse une flaque. »).
- Captures (hors dépôt) : `tests/shot_dng1.tscn` -> `user://shots/dng1_<cas>_<largeur>.png` (victoire de donjon avec records et butin,
  chute devant le boss, chute dans la Tour, Siège avec ses étoiles ; 1600×900 puis 1280×720 : le bilan de la Tour se resserre et tient).

## 3. Ce qui reste (à faire par d'autres lots)
- Onglet « Rencontres » du Carnet (P0-9, interface) ; étoiles de donjon au chrono (P1-1, les tuiles et `stars` sont prêts) ;
  « S'entraîner » (P1-4) ; Ruée : fil des temps par boss pendant la partie, graine copiable (P1-10 ; les temps par boss de la Ruée sont
  déjà enregistrés : `boss:rush:<boss>:<diff>`).
- Le Siège n'enregistre pas encore de temps record (boss du jour × chacun pour soi : à décider avec P1-9) ; il a le bloc « Ce qui t'a
  battu », ses étoiles et l'horloge de partie.
- La Survie n'affiche pas « Ce qui t'a battu » (hors mandat ; `HitLog` y note déjà tous les coups : il suffit d'ajouter `defeat` au spec
  de `ResultsScreen`).
- Attribution par fenêtre de temps : une flaque posée par une mécanique et touchée après une autre attaque peut être comptée à cette
  dernière (les dégâts continus vont d'abord aux briques à zone) ; une attribution exacte demanderait d'étiqueter chaque `Telegraph`.

## 4. Sorties pour le futur lot d'interface (DA v2)
| Donnée | Où la lire | Pour |
|---|---|---|
| Coups des 8 dernières s, mécanique fautive, conseil | `HitLog.report()`, `HitLog.died()`, `ResultsPanel.defeat_lines(rep)` | bloc « Ce qui t'a battu » v2 ; plus tard « Coups reçus » au HUD (P2) |
| Conseil après chute par brique | `HitLog.TIPS`, `HitLog.tip_for(type)`, `HitLog.mech_name(type)` | bilan, journal, première rencontre (P1-5) |
| Temps de la partie, ancien record, « Record ! » | `BestTimes.session`, `BestTimes.entry(clé)`, `BestTimes.tile(e)`, `BestTimes.record_notes()`, `BestTimes.fmt` | tuiles du bilan v2, pastille mandarine « Record ! » |
| Meilleurs temps stockés | `BestTimes.best(BestTimes.boss_key / dungeon_key / tower_key / rush_key(...))` | page Donjons v2 (record et étoiles), page Tour (record par tranche), Ruée (meilleur tirage) |
| Fiches des 48 boss | `Encounters.card(id)`, `Encounters.all()`, `Encounters.counts()` | onglet Carnet > Rencontres (maquette `v2_journal_rencontres.svg`) |
| Emplacements qui manquent | `Encounters.missing_slots(id)`, `DungeonResults.missing_text(id)` | « Prochaine victoire ici : les Gants » (bilan), cases cochées de la page Donjons v2 |
| Meilleure part de PV laissée | `Encounters.best_low(id)`, `Encounters.last_low` | « Ton meilleur sur Latif : 41 % » |
| Butin en cases | spec `loot` (`ResultsPanel.loot_entry`, `DungeonResults.loot_of`, `TowerResults.loot_of`) | cases du bilan v2 (avec gain de puissance quand le coffre de set s'ouvrira au bilan) |
| Reprises | `Tower.start_dungeon(…, from_room)`, `TowerResults.resume_floor(result)` | boutons « Réessayer le boss », « Reprendre (étage N) » |

Aucun texte ni image de jeu tiers dans ce lot.
