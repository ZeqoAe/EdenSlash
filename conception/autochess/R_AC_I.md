# R_AC_I — L'Échiquier, lot AC-I : entrée et fin (17/10/2026)

## Fait
- **Activité** « L'Échiquier » (`ui/activities.gd`) : rangée Affrontements, **en tête** (la SPEC la plaçait après Battle royale ;
  sur un compte neuf c'est la seule activité ouverte de la rangée, elle ne doit pas être cachée sous trois cartes verrouillées),
  ouverte dès le départ, scellée, étiquette « Stratégie », pastilles apparences + titres. **Image provisoire**
  `assets/ui/activities/autochess.jpg` : un vrai combat du mode dans l'arène, capturé sans interface (vue de côté, deux
  escouades et leurs sorts) ; une illustration dédiée reste à faire (session locale).
- **Page du lobby** (`Lobby._menu_autochess`) : le mode en 3 lignes, la difficulté (Recrue, Vétéran, Champion, Légende ;
  fermées : 🔒 + condition en infobulle ; une phrase sur la difficulté choisie), les 3 coffres de la difficulté (✔ gagnés,
  titre de victoire), les exploits (n / 4, détail au survol), les records (parties, top 4, victoires, meilleure place), une
  graine facultative (LineEdit, vide = au hasard), **Lancer** épinglé ; partie gardée : **Reprendre la partie** (infobulle :
  difficulté, manche, PV) + « Nouvelle partie » (confirmation `InfoCard.ask`). `_start_autochess(resume, extra)` remplit
  `AutochessScreen.config` (diff, resume, seed) et change de scène.
- **Écran** (`ui/autochess_screen.gd`, retouches) : `config.diff` (ou `--ac-diff=N`) -> 7 stratèges `AutochessAi.lineup` au
  mélange de la difficulté ; sans diff (tests, outils) : stratèges au hasard comme avant, sans récompense. Difficulté, exploits
  et durée jouée dans `players[0].meta.aci` (sauvegardés avec la partie) ; reprise : `AutochessAi.restore`, le joueur reste
  humain. Pilote automatique : Vétéran (`AutochessAi.make(1)`) contre des IA. `--auto-quit` (ligne `[autochess] fin`).
  Fiches de découverte `ac_shop` / `ac_stars` / `ac_traits` à la 1re rencontre (petite carte, « Compris » / « Guide »).
- **Bilan** `ui/autochess_results.gd` (`AutochessResults extends ResultsPanel`) : VICTOIRE ! / TOP n / PLACE n, difficulté et
  place, 5 tuiles (place, manches, dégâts de tes héros, meilleure unité, durée), « Gagné » (coffres, titres « nouveau »),
  ligne « Ta quête » (`Compass.after("autochess")`), boutons **Rejouer** (même difficulté) / **Statistiques** (bilan détaillé
  d'AC-V, le bilan revient à sa fermeture) / **Retour au lobby**. Le cadre de fin provisoire d'AC-G n'est plus montré.
- **Récompenses** `core/autochess_rewards.gd` (`AutochessRewards`) : top 4 commun, top 2 rare, 1re place mythique (légendaire en
  Champion / Légende) + titre de victoire, une fois par difficulté ; ensuite au plus un commun et un rare par jour. 4 titres de
  victoire + 4 d'exploit (SPEC §7.2). Ouverture des difficultés (`diff_open`). État `Profile.records["ac_rewards"]` (clé neuve :
  rien à migrer, tout se lit avec des défauts). **Hub intact** : instantané `Survivor.HUB_KEYS` au lancement, remis avant
  d'écrire les récompenses (`finish`), et à la sortie en pleine partie. Rien d'autre : ni insignes, ni maîtrise, ni matières,
  ni XP de héros (`HeroLevel.settle` ignore l'activité).
- **Quêtes** : `ac_top4`, `ac_rounds`, `ac_win` (hebdomadaire) dans `QuestPool`, `ACTS.autochess` (boussole -> page), récompense
  d'apparence seulement (`Quests._roll_reward` comme le Survivant) ; `Quests.end_run("autochess", top 4, extra)` sans rien de
  `Run` (classe vide, durée de la partie). `ResourceHelp` (apparences, titres), `Compass.after`.
- **Guide** : rôle du mode au chapitre Modes, ses 3 fiches juste dessous.

## Décisions
- **Abandon** : la place du moment ne compte qu'à partir de l'étape 4 ; avant, ni coffre ni quête (on abandonnerait à 1-2 pour
  le coffre du jour). Le bilan le dit en une ligne.
- Élimination avant la fin des autres : la sauvegarde est effacée (sinon « Reprendre » rejouerait le combat perdu).
- Difficulté par défaut de la page : celle de la dernière partie, sinon la plus haute ouverte par les parties.
- Exploits de plateau (Trois étoiles, Pur sang) relevés après chaque combat et à la fin ; Invaincu / Frugal à la victoire.
- Fiches : 3 au lieu des 4 de la SPEC (les intérêts sont dans « Achète et place »).

## Chiffres
- Partie complète au pilote, durées réduites (Recrue) : ≈ 30 s de calcul, 33 manches, 1re place (test) ; lobby -> partie ->
  bilan -> Rejouer -> bilan -> lobby (`test_p4_activities -- autochess+r`) : ≈ 56 s.

## Tests
`test_ac_rewards` (nouveau : plafonds premier / jour, difficultés, exploits, abandon, quêtes d'apparence seule, partie complète :
mode scellé, hub intact, bilan, Statistiques, Rejouer ; reprise : même manche, même boutique, même difficulté),
`test_p4_activities -- autochess+r`, `test_nav_screens` (page du lobby, bilan de fin), `test_pages` (page), `test_quests`,
`test_texts_fr`, `test_ac_ui` (fin par le bilan commun), `test_lot9` (fiches), `test_sv6` (retouche : son « hub identique » ignore
aussi les compteurs de quêtes `quests_done` / `quest_series_best` ; le pool de quêtes plus grand change le tirage et une quête
du Survivant s'y accomplit, ce qui est permis). Suite complète sur une copie propre : 106 / 109 verts ; `test_ac_fight`
(budget d'image, machine chargée par 3 tests en parallèle) et `test_ideas` (« établi Polir » : qualité tirée au hasard,
4 / 4 verts relancé) sans lien avec le lot ; `test_sv6` corrigé puis vert. Captures 1280×720 et 1600×900 (Jouer, page, page
Champion, fiche, bilan, bilan de victoire) regardées.

## Reste
- Illustration dédiée de l'activité (session locale).
- Spectateur après élimination (SPEC §2.3) : non fait, le bilan s'ouvre à l'élimination.
- Le cadre de fin provisoire d'AC-G (`AutochessHud.show_end`) n'est plus appelé (gardé pour ne pas toucher au HUD).

## Pièges
- `AutochessScreen.config` est statique : le lobby le remplit à chaque lancement, les tests le vident après eux.
- `ResultsPanel` met l'arbre en pause : « Statistiques » cache le bilan et relance l'arbre, la fermeture du bilan détaillé remet tout.
