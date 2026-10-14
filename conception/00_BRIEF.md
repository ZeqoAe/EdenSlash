# Atelier de conception — brief commun des équipes (version du jeu 0.1.130, 14/10/2026)

Eden Slash est un fan game d'Eden Eternal en Godot 4.7 (`game/`), fait par un joueur (Nico) qui ne
connaît pas git et lit tout en **français**. Deux sessions Claude codent (locale avec le client
Eden, cloud sans). Lire `CLAUDE.md` à la racine pour le contexte technique.

## But de l'atelier

Le joueur trouve la boucle de **Survie** bonne et l'équilibrage correct pour l'instant (il a gagné
l'époque 1 « bien capé », il attaque l'époque 2). Il veut maintenant :
1. **faire le point** sur tous nos systèmes, leurs fonctions, ce qui se débloque et comment ;
2. faire travailler des **équipes** (une par domaine) qui proposent, puis **se concertent** pour que
   tout s'imbrique, et repartent améliorer le concept **jusqu'à une idée finale** ;
3. seulement ensuite, découper en **blocs de code**.

**Pendant l'atelier : aucun code.** On analyse, on mesure, on conçoit.

## Règles pour chaque équipe

- Écrire **uniquement** dans `conception/<ton_équipe>/` (fichiers Markdown, en français).
  Ne rien modifier ailleurs (pas de `game/`, `tools/`, docs racine), ne pas faire de commit ni de push.
- Tu peux lire tout le dépôt. Tu peux lancer Godot en mode headless pour **mesurer** (pas de
  `--import`, délai max 10 min par commande) :
  `C:/Users/Nico/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path game res://tests/<test>.tscn`
  (voir aussi les commandes d'essai de `CLAUDE.md`). Les tests utilisent leur propre sauvegarde.
- Les docs peuvent être **en retard sur le code** (ex. `DESIGN.md` parle encore de combos
  d'auto-attaque et de « builds exotiques », supprimés en 0.1.127-0.1.128) : **le code fait foi**.
  Signale les docs obsolètes.
- Cite les fichiers et fonctions (`game/scripts/core/run.gd:apply_card`), chiffre quand tu peux.
- Reste concret et réaliste pour un petit projet : chaque proposition dit son coût (S / M / L) et
  ce qu'elle touche. Pas de refonte totale gratuite : on garde ce qui marche.

## Les équipes

| Dossier | Équipe | Périmètre |
|---|---|---|
| `progression/` | Progression & déblocages | méta-progression entre les runs : expertise, talents, certificats, maîtrise des classes, déblocage des cartes, zones et époques, monnaies gardées (cristaux, insignes), Armurerie, coffres de récompense, Collection / archive, apparences, fin de jeu (cerveaux d'IA) |
| `equilibrage/` | Équilibrage | chiffres du combat et de l'économie : monstres, boss, époques, auto-attaques d'arme et leurs cartes, cartes de build, trophées, sorts, or / clés / prix, courbes d'expérience, duel (plafonds JcJ), Tour |
| `interface/` | Interface & menus | tous les écrans et menus : lobby, page Jouer (activités), écran Héros, inventaire, Collection, Coffres, Paramètres, HUD de run, menu pause, cartes de choix, écrans de fin, Tour, Duel ; clarté, cohérence, confort, ce qui manque ou est en double |
| `modes/` | Nouveaux modes | modes de jeu : Survie, Tour, Duel, entraînement existants ; Donjons, Arènes 2v2 / 3v3, Champ de bataille 10v10 annoncés « à venir » ; nouvelles idées ; place des cerveaux d'IA (adversaires, alliés) |
| `builds/` | Builds & identité de combat | 60 classes, sorts, passifs, armes (2 variantes chacune) et leurs améliorations, cartes de build, trophées (67 effets), effets déclenchés, certificats, presets : synergies, diversité des builds, identité des classes, « easy to play, hard to master » |

## Ce que l'on sait du joueur (à respecter)

- Il juge au **ressenti** : pression constante, combats lisibles et intenses, maniabilité impressionnante
  pour les experts (saut, esquive, annulation parfaite) ; « easy to play, hard to master ».
- Roguelite : la Survie part **sans équipement** ; l'équipement de run n'est pas gardé (il s'achète
  ensuite à l'Armurerie avec des insignes).
- Décisions récentes (14/10) : plus de combo d'auto-attaque, une auto-attaque par arme (2 variantes)
  qui grandit avec les cartes ; arme principale = arme de la classe ; arme secondaire trouvée en jeu ;
  cartes d'amélioration d'arme (rareté = plus d'effets) ; trophées = collection de la run (12 max,
  effets tous différents), plus de l'équipement.
- Fin de jeu voulue : battre les **cerveaux d'IA** en duel (défi ultime) débloquera leur équipement (à concevoir).
- Il aime le confort d'interface (actions groupées, Ctrl+clic, filtres).
- Ses notes laissées en jeu (dossier `feedback/`, à vérifier : certaines sont peut-être déjà faites) :
  - (0.1.122) Survie : gagner des ciseaux, parchemins d'amélioration, pierres d'amélioration ;
  - (0.1.122) Tour : gagner des gemmes, enchantements, pierres pour polir / réforger ;
  - (0.1.122) Donjons : pièces mythiques, légendaires, éveillées selon le niveau en battant les boss,
    et parfois un **plan de fabrication** pour fabriquer l'objet de Collection du plan (idée à développer) ;
  - (0.1.116-0.1.117) menu Coffres peu lisible (on ne voit pas ce qu'on choisit, coffres plus jolis,
    animation d'ouverture) ; coffres proportionnels au niveau ; monstres trop bloqués par le décor
    (perte de stress) ; écran de fin : ne pas proposer de garder un objet déjà possédé ;
    autel de récompense en pyramide (8 étages, quitte ou double).

## Ajout du joueur pendant le tour 1 (à traiter par toutes les équipes concernées)

1. **Tutoriel au début, passable** (« skip ») : il explique les features (auto-attaque et
   enchaînements, cartes, Survie, Tour, Donjons, forge…). → pilote : **interface** ; avis : modes, progression.
2. **Contenu débloqué au fur et à mesure** : la forge pas disponible tout de suite, la Tour et les
   Donjons non plus, etc. ; quoi, dans quel ordre, à quelle condition. → pilote : **progression** ;
   avis : interface (présentation, tutoriel), modes.
3. **Équilibrage distinct par mode** : en JcJ on ne veut ni les mêmes stats ni la même durée de
   combat qu'en Survie, ni forcément les mêmes en Donjon. → pilote : **équilibrage** ; avis : modes, builds.
4. **Beaucoup de mini-jeux / activités**, chacun avec son intérêt. → pilote : **modes**.
5. **But final : tout collectionner** — tout l'équipement, amélioré à fond ; tous les cosmétiques ;
   toutes les classes au maximum de maîtrise ; toutes les cartes et tous les passifs débloqués ; des
   **titres liés à des succès** (« achievements »). → pilote : **progression** ; avis : builds (cartes,
   passifs), interface (suivi de la collection, titres), modes (d'où vient chaque chose).

## Contraintes techniques à ne pas casser

- Arène d'IA : le nombre d'observations de `game/scripts/ml/ml_arena.gd` est figé (sinon les cerveaux
  entraînés deviennent inutilisables) ; l'ordre `ML_CLASSES` aussi.
- Les 60 classes sont générées depuis le client d'Eden (`tools/build_classes.py`, session locale).
- Numéro de version et CHANGELOG à chaque envoi (géré par la session principale, pas par vous).

## Déroulé

1. **Tour 1** — chaque équipe écrit `conception/<équipe>/rapport_1.md` :
   1. **État des lieux** de son domaine : systèmes, fichiers et fonctions clés, **ce qui se débloque
      et à quelle condition**, ce qui est fini / à moitié fait / mort / incohérent / doc obsolète ;
   2. **Problèmes et opportunités**, du plus important au moins important ;
   3. **Propositions** (le concept) : pour chacune, l'intérêt pour le joueur, les règles, ce qu'elle
      touche, son coût (S / M / L) et ses **dépendances vers les autres équipes** ;
   4. **Questions aux autres équipes** ;
   5. Questions au joueur (seulement l'indispensable).
2. **Concertation** — chaque équipe lit les rapports des autres et écrit
   `conception/<équipe>/concertation_2.md` : accords, conflits, imbrications, ce qu'elle ajuste ou abandonne.
3. **Synthèse** par la session principale (`conception/SYNTHESE_v1.md`), puis tour de raffinement
   jusqu'au **concept final** et au découpage en **blocs de code**, validés par le joueur.
