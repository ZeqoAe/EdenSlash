# R_M5 : le Défi de maîtrise devient un système de quêtes (passe M5, version 0.1.196)

Retour du joueur : « Défi de maîtrise, ça ressemble plutôt à des quêtes journalières ». Règles dans `DESIGN.md`, « Quêtes ».
Test : `tests/test_quests.tscn` (120 vérifications). Captures regardées : `tests/shot_m5.tscn` (page Quêtes et étiquette de Jouer, 1600×900 et
1280×720), HUD en Survie, bilan de Survie (`shot_p6`).

## Fait
- `core/quests.gd` (`Quests`) + `core/quest_pool.gd` : 40 quêtes couvrant Survie, Survivant (tirées seulement quand le mode est visible, donc en
  mode dev), Donjons, Tour, Ruée, Siège, Duel, Arènes, Gantelet, Battle royale, coffres du menu et variété (activités / classes différentes). 3 du jour
  (le Défi du jour, puis 2 d'autres activités), 2 de la semaine (activités différentes). Tirage déterministe par date (`Quests.draw`), figé dans
  `Profile.records.quests` : aucune clé de sauvegarde nouvelle, rien à migrer (contrats `Profile.contracts` et `records.challenge_day` lus tels quels ;
  un Défi du jour déjà réussi aujourd'hui est marqué fait).
- Le Défi du jour = la quête `daily_challenge` : règles de `core/challenge.gd` inchangées (2 modificateurs, maîtrise ×2, +600, insignes ×1,5, 3 classes
  proposées) ; il se lance depuis la ligne de la quête. `Challenge.today()` lit `Quests.today()` (date imposable en test).
- Défis de classe : `Contracts` inchangé, présenté par `Quests.class_challenges` dans la même liste (sous les quêtes, pour la classe choisie).
- Récompenses sobres, jamais d'équipement : jour : insignes 40/70/100 (≤ 300/jour), cristaux 20/35/50, maîtrise 150/250/350 pour la classe la plus en
  retard, ou coffre de parchemins ; semaine : 350 insignes + coffre d'apparence rare, ou 150 cristaux + coffre de parchemins ; Survivant : coffres
  d'apparence seulement (aucun lien avec le compte).
- Série (`series_n`) : une quête du jour par jour ; un jour manqué est pardonné ; au-delà elle retombe au dernier palier gagné (jamais à zéro) ;
  paliers 3/7/14/30/60/100 : coffres d'apparence et d'aura, titres « Régulier » et « Inlassable », chacun donné une fois. Relance : une quête du jour
  non faite, une fois par jour.
- Bus unique : `Quests.end_run(activité, gagné, extra)` appelé en fin de Survie, Survivant (après la remise du hub), Tour, Donjon / Ruée / Siège, Duel /
  Arènes / Gantelet, Battle royale (après le rechargement de la sauvegarde) ; `Quests.event("zone_hit")` (télégraphes, quête « sans dégât de zone ») et
  `"chest_open"` (`Rewards.open` / `choose`). Les compteurs sont lus dans `Run` en fin de partie, rien n'est écrit en cours de partie. Partie < 30 s : ignorée.
- Interface : page Jouer > Défis > « Quêtes » (`ui/quests_page.gd` : série, trois blocs, jauge fine, pastilles de récompense, ↻ relance), étiquette
  « 1 sur 3 aujourd'hui » ; HUD `ui/quest_badge.gd` (une ligne discrète sous les objectifs + `InfoCard` « Quête accomplie ») ; ligne « Ta quête » des
  bilans (`Compass.after`) ; boussole (quête presque faite, sinon la plus avancée en fin de chaîne) ; carte « Quêtes » dans le Guide ; succès « Aventurier
  appliqué » et « Constance ». « Défi de maîtrise » renommé « Défi du jour » partout (bilan, infobulle des insignes, succès).

## Décisions
- Page dans Jouer > Défis et non dans le Carnet : les quêtes se lancent (Défi du jour) et se renvoient à une activité ; même cadre que les autres pages.
- Le Défi du jour est toujours la 1re quête du jour (il garde le rattrapage de maîtrise quotidien) ; il peut être relancé comme les autres.
- Récompense au moment de l'accomplissement en fin de partie (aucun bouton « récupérer ») ; la carte du HUD annonce l'accomplissement, le bilan donne le gain.
- Budget : Défi du jour 22 min (la Survie qu'on jouerait de toute façon) + 2 quêtes de 11 min au plus : mesuré sur 90 jours, 40 min en moyenne (max 43).
- Coffre ouvert au menu : pas d'annonce (la page montre ✔) ; à ajouter si le joueur la veut.

## Reste / pièges
- Image de la carte Quêtes : réutilise `training.jpg` (illustration dédiée à demander à la session locale).
- Les cibles « fixes » (400 monstres, 8 élites…) sont des estimations : à recaler au journal de run avec E6 quand il y aura des parties.
- `Quests.end_run` doit être appelé APRÈS `Profile.reload_keep_records()` (sinon l'état est rechargé du disque) ; une nouvelle activité : l'ajouter à
  `QuestPool.ACTS`, appeler `end_run` dans son bilan et écrire des quêtes.
- Partage du dépôt : fichiers partagés retouchés (crochets d'une ligne) : `run.gd`, `tower.gd`, `duel.gd`, `royale.gd`, `rewards.gd`, `telegraph.gd`,
  `hud.gd`, `lobby.gd`, `activities.gd`, `compass.gd`, `tutorial.gd`, `unlocks.gd`, `guide.gd`, `resource_help.gd`, `achievements.gd`, `results_screen.gd`.
  Commit par versions HEAD + mes remplacements, car d'autres sessions avaient des modifications non commitées dans les mêmes fichiers.
