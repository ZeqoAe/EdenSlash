# Hub, HUD et quêtes face aux MMORPG : étude comparative (BM-HUB, 17/10/2026)

Mandat du joueur : « s'inspirer des MMORPG ; reprendre des images des concurrents pour analyser et comparer avec le nôtre ; HUD,
UI / UX, profondeur, détails de confort ; le tout dans notre nouvelle DA ». Méthode : `METHODE.md` (précision du 17/10 : les MMORPG
**sans la corvée**, ni quête obligatoire ni bash de monstres inutile). DA : `art/BIBLE.md` v2 (autocollant manga), audit `art/AUDIT_UI.md`.
Périmètre : (A) menu principal et navigation, (B) HUD en partie (Aventure / Survie), (C) quêtes et méta-progression.
Croquis maison : `hub_maquettes/` (HTML, ouvrir `index.html` dans un navigateur). Images de référence et nos captures : **hors dépôt**,
`C:\AI\benchmark_refs\hub\` (`wow`, `ffxiv`, `gw2`, `lost_ark`, `genshin`, `hades`, `maplestory`, `persona5`, `black_desert`, `eso`,
`hsr`, `brawl_stars`, `eden_slash_nous`, planches `_planches\`, rendus des croquis `_maquettes_rendu\`). Aucun texte, image ou son tiers
n'est repris ici : on décrit.

**Verdict en une phrase** : la structure est saine et souvent plus honnête que les MMORPG (un conseil unique et cliquable, une ligne
« Ta quête » dans chaque bilan, des quêtes jamais obligatoires avec série pardonnante, des récompenses créditées seules, une
navigation manette complète) ; ce qui fait encore « prototype », c'est que **tout cela est caché** : une seule pastille de nouveauté
dans tout le menu, la boussole tient en une pilule de texte, les quêtes sont rangées comme une activité au fond de Jouer, le HUD
empile des messages concurrents sans réglage, et la méta-progression (succès, titres, collection) n'a ni piste de cadeaux ni « presque
fini ». Les MMORPG gagnent sur la **mise en avant** (quoi faire, quoi de neuf, ce qui est presque fini), pas sur la quantité de systèmes.

---

## 1. Sources et ce qui a été vérifié

| Référence | Images regardées (hors dépôt) | Sources écrites |
|---|---|---|
| World of Warcraft (Blizzard) | wiki.gg : mode Édition du HUD (11.0), Guide de l'aventurier « contenu suggéré » (Dragonflight), Grande Chambre forte (11.0.2), suivi d'objectifs, recherche de donjon, renom de faction | warcraft.wiki.gg (Edit Mode, HUD Edit Mode) ; annonce Blizzard « Dragonflight HUD and UI Revamp » |
| Final Fantasy XIV (Square Enix) | 9 captures Steam (sans interface) ; wiki consolegameswiki : HUD annoté, réglage d'élément, Duty Finder et roulette, liste des devoirs, Journal avec recherche, Wondrous Tails ; **guide officiel de l'interface** (6 images : HUD clavier / manette, menu Système, disposition du HUD 1-4, taille et transparence) | na.finalfantasyxiv.com/uiguide (« HUD Layout ») |
| Guild Wars 2 (ArenaNet) | 16 captures Steam (une avec HUD) ; wiki officiel : panneau des succès (résumé, « récemment obtenus », « presque finis », liste de suivi, points vers le prochain coffre), garde-robe, maîtrises, suivi d'événement | wiki.guildwars2.com (Wizard's Vault, Astral Acclaim) ; annonce officielle du Wizard's Vault |
| Lost Ark (Smilegate / Amazon) | 9 captures Steam (sans interface) ; **guide officiel** : journal des quêtes (recherche par nom / zone), tâches d'Una quotidiennes et hebdomadaires (favoris, filtres, bonus de repos, mission du roster par paliers, « Localiser ») | playlostark.com (quests guide, notes de lancement : boussole de Procyon) ; Icy Veins, Maxroll |
| Genshin Impact (HoYoverse) | wiki Fandom : Manuel de l'aventurier (commissions 2 / 4 + bonus, chapitres « Expérience » avec liste de tâches et récompenses, Guide), succès par catégories, menu des quêtes (« Naviguer »), menu Paimon (grille de 20 entrées) | genshin-impact.fandom.com |
| Honkai: Star Rail | 10 images App Store FR (marketing, interface illisible) | wiki Fandom et guides (Entraînement quotidien : 500 points par jour, tâches interchangeables de 100 à 500 points) — **interface non vérifiée par image** |
| MapleStory (Nexon) | 11 captures Steam (villes, combats) | MapleSEA (notificateurs sous la mini-carte : étoile = limité, ampoule = permanent) ; wiki Maple Guide (contenus conseillés par niveau) — **interface du guide non vérifiée par image** |
| Hades (Supergiant) | 10 captures Steam FR (HUD, dialogues) ; wiki : Maison d'Hadès, Liste des prophéties (objet du hub), Codex, Miroir de la nuit, « ! » au-dessus d'un service | wiki Fandom Hades |
| Persona 5 Royal (Atlus) | 8 captures Steam (calendrier, dialogues, combat) | — (le menu principal n'est pas dans les captures : **non vérifié**) |
| Black Desert, Elder Scrolls Online | 7 et 5 captures Steam, **aucune interface visible** | — : non étudiés dans le détail |
| Brawl Stars (Supercell) | 12 images App Store FR (marketing) | critique de design Pratt Institute (2025) : le bouton Jouer jaune est l'élément le plus visible de l'accueil — **accueil non vérifié par image** |
| **Eden Slash** (0.1.256, copie propre de HEAD) | 13 captures de l'audit DA réutilisées (`art/audit/`, 1600×900) + nouvelles : `shot_m5` (page Quêtes), `shot_p6` état avancé (menu principal, 9 pages d'activité, boussole, 3 bilans) ; captures du 15/10 (accueil, HUD Survie, grande carte, pause) | code lu : `ui/lobby.gd`, `core/compass.gd`, `core/quests.gd`, `ui/quest_badge.gd`, `ui/hud.gd`, `ui/hud_widgets.gd`, `core/achievements.gd`, `ui/carnet_pages.gd`, `core/settings.gd` |

Limites : aucune partie jouée des références (pas de client ni de compte) ; on décrit ce que montrent les captures et ce que disent les
guides. Certaines images de wiki datent de plusieurs extensions (indiqué quand c'est le cas). Le HUD en partie de nos captures date de
0.1.256 (audit) et du 15/10 (même structure).

---

## 2. Ce que fait chaque référence (et ce qu'on en retient)

### World of Warcraft : le confort à force d'années
- **Suivi d'objectifs** (capture wiki) : colonne à droite, quêtes groupées (Campagne, Quêtes, Journal du voyageur), chaque ligne =
  icône d'état + titre + compteur « 465 / 1000 » ; en-têtes repliables (−). Une quête suivie se lit sans ouvrir de menu.
- **Mode Édition** (10.0, vérifié) : tout le HUD se déplace et se redimensionne ; dispositions nommées « Moderne » et « Classique »,
  dispositions personnelles sauvegardées, copiées, partagées ; grille d'aimantation. Montré : éléments en surbrillance bleue + panneau
  d'options. **À retenir** : des profils prêts à l'emploi plutôt qu'un réglage par élément au départ.
- **Guide de l'aventurier › Contenu suggéré** (capture Dragonflight) : 3 cartes sur parchemin (un événement, un mode JcJ, une fête),
  chacune avec récompense et bouton « Commencer la quête ». **À retenir** : le guidage propose **plusieurs** choix, chacun avec un bouton.
- **Grande Chambre forte** (11.0.2) : 3 rangées (Raids, Donjons, Monde) × 3 cases qui se débloquent à 1 / 4 / 8 activités ; une fois
  par semaine on choisit **une** récompense parmi celles débloquées. Récompense de régularité sans obligation précise.
- **Recherche de donjon** (capture) : rôles cochés, type « au hasard », encadré « Récompense : tu peux encore la recevoir 1 fois
  aujourd'hui ». **À retenir** : dire ce qui reste à gagner aujourd'hui.

### Final Fantasy XIV : un HUD modulable et un fil qui guide
- **HUD annoté** (guide officiel et wiki) : en haut à gauche le **guide du scénario principal** (la quête principale, toujours visible,
  cliquable), en dessous le groupe ; à droite la mini-carte puis la **liste des devoirs** (3 à 5 quêtes, l'étape suivante en bleu,
  coche verte quand faite) ; en bas la barre de paramètres (PV, PM, expérience) et les barres d'action numérotées ; en bas à droite le
  menu principal en 7 icônes rondes et la monnaie.
- **Disposition du HUD** (guide officiel, vérifié) : **4 dispositions** numérotées, catégories (Système, Barres, Devoir), élément choisi
  surligné, déplacement à la souris ou au stick droit, **taille** par paliers (Ctrl+Début ou clic du stick droit), **transparence**,
  masquer un élément (son nom passe en violet). Barres d'action 12×1 à 1×12.
- **Manette** (guide officiel, capture « hud 1 ») : barre croisée LT / RT (deux jeux de 8 actions) ; tout le menu est jouable au pad.
- **Duty Finder et roulettes** (capture wiki) : liste à cocher par type de contenu, fiche détaillée à droite (illustration, récompense,
  description) ; la « roulette » tire un contenu au hasard avec un bonus quotidien. **À retenir** : une option « au hasard, avec bonus ».
- **Journal** (capture wiki) : recherche, filtres par type (icônes), compteurs « Quêtes 6 / 30 · Mandats 7 / 16 ».
- **Wondrous Tails** (wiki) : carnet de la semaine à 16 cases, des lignes complètes = récompenses ; on choisit l'ordre. (Mécanique
  hebdomadaire optionnelle, décrite d'après l'image.)

### Guild Wars 2 : des succès qui récompensent la curiosité
- **Panneau des succès** (2 captures wiki, interface d'avant 2023) : en haut une **piste « points jusqu'au prochain cadeau »** (5 coffres
  avec leur seuil : 33 000, 33 500…) ; à gauche les catégories avec recherche, **liste de suivi**, pastilles colorées de nouveauté par
  catégorie ; au centre « Récemment obtenus » et **« Presque finis »** (24 / 25, 90 / 100) ; en bas les récompenses débloquées et les
  bonus de compte. **À retenir presque tel quel** (sans les bonus de statistiques).
- **Garde-robe** (wiki) : le héros au centre, emplacements à gauche, collection en grille avec recherche, **essai d'une apparence
  avant de l'appliquer** (coût affiché).
- **Wizard's Vault** (2023, wiki officiel, vérifié) : quêtes quotidiennes (4 + connexion), hebdomadaires (8, bonus à 6), spéciales de
  saison ; **le joueur coche les modes dont il veut des objectifs** (PvE, PvP, McM) ; les points gagnés s'**échangent librement** contre
  des récompenses d'une boutique tournante ; les récompenses sorties de la rotation passent dans un onglet « héritage ». Plafond de
  points stockés, points gardés d'une saison à l'autre. **C'est le modèle « sans corvée » le plus abouti du panel.**

### Lost Ark : la densité assumée
- **Tâches d'Una** (guide officiel, vérifié) : tableau dense (quête, récompenses en icônes, lieu, réputation, progression, Accepter),
  favoris (étoile), filtres et recherche, **bonus de repos** (20) en haut, **mission du roster** à gauche (70 points, paliers 25 / 35 /
  45 / 55 / 70 avec cadeaux), bouton **« Localiser »**, rappel de l'heure de remise à zéro. Trop dense pour nous, mais 3 idées : bonus
  de repos (rattrapage), paliers de points, « Localiser ».
- **Journal des quêtes** : onglets En cours / Terminées / Guide / Recherche ; recherche par nom ou par zone ; quêtes « [Guide] » en violet
  qui enseignent les systèmes.
- **Boussole de Procyon** (notes de lancement) : un widget liste les contenus à horaire du jour, un calendrier en haut à gauche.

### Genshin Impact : le guidage de chapitre en chapitre
- **Manuel de l'aventurier** (captures wiki) : livre ouvert, onglets à gauche (Expérience, Commissions, Domaines, Ennemis, Guide).
  **Commissions** : « 2 / 4 », bonus quand les 4 sont faites, une ligne par commission avec ses récompenses et un bouton de lieu.
  **Expérience** : un **chapitre** = 5 à 8 tâches concrètes (« Monte un personnage au niveau 80 1 / 1 ») avec récompenses par tâche
  et récompense de chapitre, coches vertes. **C'est le meilleur guide de progression du panel** : une liste courte et finie, pas un
  conseil unique.
- **Menu des quêtes** : liste à gauche, fiche à droite (lieu, étape, récompenses de la chaîne), bouton **« Naviguer »** (pose un repère).
- **Succès** : catégories à gauche avec avancement, liste à droite, récompense en gemmes par succès (Genshin affiche des pourcentages :
  à ne pas reprendre, règle du jeu).
- **Menu principal (Paimon)** : grille de 20 grosses tuiles icône + mot. Lisible, mais 20 entrées de même poids : contre-exemple
  pour nous (la bible veut une hiérarchie, un seul primaire).

### Honkai: Star Rail, MapleStory (non vérifiés par image)
- HSR (guides) : **Entraînement quotidien** : 500 points par jour, tâches de 100 à 500 points **interchangeables** (on choisit celles
  qu'on aime). Même idée que le Wizard's Vault : un quota de points, pas une liste imposée.
- MapleStory (MapleSEA) : **notificateurs sous la mini-carte** (étoile = événements limités, ampoule = quêtes permanentes) ; **Maple
  Guide** : contenus conseillés pour le niveau du héros (zones, boss), avec cadeaux de palier.

### Hades : le hub qui vit
- **Maison d'Hadès** (captures) : le hub est une salle où chaque service est un **lieu avec un personnage** (contrat de rénovation,
  Miroir, Codex, Liste des prophéties) ; un **« ! » en étoile** au-dessus du service qui a du nouveau ; des dialogues en bulles avec
  portrait. La **Liste des prophéties** est un parchemin physique : des objectifs longs et optionnels avec récompense.
- **HUD** (captures Steam FR) : presque vide : vie en bas à gauche, faveurs (pouvoirs) en colonne à gauche, monnaie en bas à droite,
  nom du boss en haut. Le jeu se lit sans le HUD.

### Persona 5 Royal, Brawl Stars : le style et le gros bouton
- Persona 5 (captures) : **le style porte l'information** : date en grand en haut à gauche, bulles de dialogue découpées et inclinées,
  noms en étiquettes, rouge / noir / blanc. Pour nous : l'inclinaison, la découpe, les étiquettes (déjà dans la bible : titres à −3°).
- Brawl Stars (critique de design, non vérifié par image) : accueil = le personnage choisi au centre, **un gros bouton Jouer jaune** qui
  lance le dernier mode, tout le reste en boutons autour. Pour nous : le **« Continuer »** en un clic.

---

## 3. Nos écrans un à un : tableau d'écarts

Légende : ✔ ce qu'on fait mieux · ✖ ce qui manque · ↗ ce que la référence fait mieux.

| Écran (capture) | Référence la plus proche | ↗ Ils font mieux | ✔ On fait mieux | ✖ Ce qui manque chez nous | P |
|---|---|---|---|---|---|
| Écran titre (`audit_01`) | Hades, Genshin | — | scène 3D vivante, 3 boutons | logo et primaire dans la DA (chantier 1 de `R_DA.md`) | P1 |
| Accueil (`nuit_welcome_1`) | FFXIV (Hall of the Novice optionnel) | — | **3 entrées au choix** (découvrir, s'échauffer, je connais) : rien d'imposé | rien de majeur | — |
| Menu principal (`audit_02`, `p6_00_lobby`) | Brawl Stars, FFXIV | gros bouton qui relance le dernier mode ; menu en icônes avec pastilles | héros posé dans la zone, peu d'entrées | **Continuer** (dernière activité) ; **pastilles** sur Héros, Atelier, Carnet, Jouer (seul Coffres en a) ; quêtes du jour et série **invisibles** ; « Jouer » pèse autant que « Quitter » | **P0** |
| Boussole « Ta quête » (`p6_00`, pilule en haut) | FFXIV guide du scénario, Genshin Expérience, WoW contenu suggéré | visible et stable, liste de chapitre finie, plusieurs choix avec bouton | **un seul conseil calculé** depuis l'équipement de la classe, cliquable, repris dans chaque bilan : plus précis que tout le panel | le **pourquoi** (seulement en infobulle), d'**autres choix**, le lien avec Jouer (la carte conseillée n'est pas marquée), absent en partie | **P0** |
| Badge du héros (haut droite) | FFXIV, GW2 | — | classe, maîtrise, niveau, clic = changer de classe | titre porté et puissance (PE) d'un coup d'œil ; « 6 / 9 pièces » de la quête commune | P1 |
| Menu Jouer (`audit_03`) | WoW Recherche de donjon, FFXIV roulette | « encore 1 fois aujourd'hui », « au hasard avec bonus » | vraies images du jeu, 3 rangées par rôle, verrous avec condition | marque « Conseillé » sur la carte de la boussole ; « Quêtes » est une carte d'activité alors que c'est une couche au-dessus de toutes | **P0** |
| Page d'activité (`audit_05`, `p6_01_*`) | FFXIV Duty Finder (fiche à droite) | ce qu'on peut encore gagner aujourd'hui | « Donne » en pastilles, bouton épinglé, PE conseillée | ligne « quêtes du jour ici : 1 » (quelles quêtes avancent dans cette activité) | P1 |
| Quêtes (`m5_02_quetes`) | Genshin Commissions, Lost Ark Una, GW2 Wizard's Vault, HSR | accessibles de partout (raccourci, HUD), « Localiser / Naviguer », quota de points au choix | **jamais obligatoires**, relance, **série pardonnante** (un jour de grâce, retombe au palier, pas à zéro), récompenses créditées seules, Défi du jour | **Journal** ouvrable partout (touche, pause, bilan) ; **quête suivie choisie** ; « Y aller » par quête ; piste de la série illustrée ; heure de renouvellement | **P0** |
| Coffres (`p6_03_apres_clic_boussole`) | GW2 garde-robe, FFXIV essayage | essayer une apparence avant de l'avoir | **« Ouvrir tout »** existe | aperçu sur le héros des apparences possibles d'un coffre (cabine d'essayage) | P1 |
| Carnet › Vue d'ensemble (`audit_15`) | GW2 Résumé | « presque finis », « récemment obtenus », piste de cadeaux | 10 catégories cliquables, rien d'obligatoire | **« 7 % » en titre** (règle : pas de % permanent), 10 barres vides de même poids | P1 |
| Carnet › Succès | GW2, Genshin, WoW | catégories, points, coffres de palier, suivi, secrets | succès rétroactifs (lus dans les records), titres | catégories, points, piste cosmétique, « presque finis », suivre, succès secrets avec indice ; 44 succès dont une majorité de compteurs (« vaincre 50 000 monstres ») | P1 |
| Registre (`audit_16`) | FFXIV Journal (compteurs) | filtres par icône | **la quête commune des 60 classes en un tableau** : rien d'équivalent ailleurs | « à commencer » × 60 : trier par « le plus proche de fini » | P2 |
| Paramètres (`audit_17`) | FFXIV, WoW | réglages du HUD (dispositions, taille, transparence) | modes prêts à l'emploi, infobulle fixe, interrupteurs | onglet **Interface en partie** : profil, taille et opacité du HUD (aujourd'hui seulement `ui_scale` global) ; « RTS / MOBA », « Bot » | **P0** (taille / opacité) |
| Guide F1 (`audit_18`) | FFXIV Active Help, Genshin tutoriels | recherche, captures | très lisible, 6 onglets, fiches de découverte qu'on peut couper | touches dessinées (déjà dans la DA), recherche | P2 |
| HUD Survie (`audit_19`, `nuit_hud_survie_2`) | FFXIV, GW2, Hades | quête suivie stable, une info par coin, barres numérotées, presque rien au repos (Hades) | objectifs repliables (Tab), **flèche vers l'objectif**, mini-carte, cible avec effets, lueur de sort prêt, barre d'enchaînement, **comparaison ▲ et touche G pour équiper** | globe « RUN 1 / 44 % » obscur ; cases vides « — » ; touches peu lisibles ; bandeau + fil + cartes + Premiers pas qui se superposent ; aucune personnalisation | **P0** |
| Grande carte (`nuit_hud_grande_carte`) | FFXIV, WoW | filtres, repère posé | légende complète, tous les sites | filtre de la légende, repère « Ta quête » | P2 |
| Pause (`nuit_pause_run`) | FFXIV menu | — | onglets Partie / Héros / Aide, « S'extraire » | « Abandonner : retour au lobby » (anglicisme) ; Journal accessible depuis la pause | P1 |
| Bilans (`audit_24`, `p6_bilan_*`) | GW2, Genshin | célébration des gains | **ligne « Ta quête »** après chaque partie, Gagné / Gardé / Perdu | primaire soleil, « Retour au menu », quête accomplie montrée en grand (DA, chantier 5) | P1 |

---

## 4. « Quoi faire maintenant » sans corvée

### Ce que font les meilleurs
| Système | Forme | Ce qui évite la corvée |
|---|---|---|
| FFXIV guide du scénario | une quête principale toujours affichée, cliquable | une seule chose, jamais un mur de quêtes |
| Genshin Manuel › Expérience | chapitres de 5-8 tâches concrètes, cadeau par tâche et par chapitre | liste **finie**, chaque tâche est une vraie étape de progression |
| WoW Contenu suggéré | 3 cartes avec bouton « Commencer » | **le choix** entre trois envies |
| GW2 Wizard's Vault, HSR Entraînement | quota de points, tâches interchangeables, boutique libre | on choisit ses modes et ses récompenses |
| WoW Grande Chambre forte | 1 / 4 / 8 activités → choisir 1 récompense par semaine | régularité récompensée, sans liste imposée |
| Lost Ark bonus de repos | ce qu'on n'a pas fait s'accumule en bonus | **rattrapage** au lieu de punition |
| Hades Liste des prophéties | objectifs longs, optionnels, physiques dans le hub | curiosité, pas obligation |

### Notre boussole face à eux
`Compass.advice()` choisit **un** conseil parmi ~15 règles (première Survie, pièce dans le coffre, pièce achetable, coffres à ouvrir,
quête presque finie, emplacement vide → Survie, panoplie → donjon précis, +10 → Forge, gemmes → Tour, enchantements → Siège, fil d'éveil,
classe suivante du Registre). C'est **plus pertinent** que les guides des MMORPG (il lit l'équipement réel de la classe et nomme le
donjon qui donne la panoplie) et il ne crée aucune obligation. Ses faiblesses sont de présentation : une pilule de 360 px en haut
de l'écran, le pourquoi caché dans une infobulle, un seul choix, rien dans Jouer, rien en partie, aucune étape « finie » à cocher.

### Proposition « Boussole v2 » (croquis `hub_maquettes/lobby.html`)
1. **Bulle « Ta quête »** (une seule bulle par écran, bible § 8) en bas du menu principal : icône, titre avec compteur (« Panoplie
   Rocheuse 2 / 6 »), **une phrase de pourquoi**, bouton **« Y aller »** (Y à la manette), puis **« Ou bien : »** deux autres conseils
   en pastilles. `Compass.advice()` devient `Compass.advices(3)` (les 3 premières règles qui s'appliquent, de familles différentes).
2. **Carte conseillée marquée** dans Jouer : étiquette autocollante « Conseillé » sur l'activité de la bulle.
3. **En partie** : rien de nouveau (la quête suivie suffit) ; au bilan, la ligne « Ta quête » existe déjà.
4. **Chapitres d'éveil** (P1, Genshin) : le fil d'éveil (`Unlocks`, `Compass.LADDER`) présenté en chapitres de 4-6 étapes cochées dans
   le Journal (« Chapitre II : la Forge » : gagner l'époque I, monter une pièce à +3, ouvrir un coffre de set…), cadeau cosmétique par
   chapitre. Aucune étape n'est exigée par autre chose que ce que le jeu verrouille déjà.

### Hub vivant
Notre menu principal pose déjà le héros dans la zone choisie (scène 3D, caméra libre) : c'est plus vivant que la grille de Genshin
ou le menu plein écran d'un MMORPG. Hades montre l'étape suivante : des **services incarnés** avec un « ! » quand ils ont du nouveau.
Recommandation : garder le menu à boutons (rapide, manette), et en P2 poser 2 ou 3 personnages du jeu dans la scène (forgeron pour
l'Atelier, coffre pour les Coffres, panneau pour le Journal) avec la même pastille que le bouton ; un clic sur eux = le bouton.
Écran de départ : l'**accueil à 3 choix** est déjà meilleur que les tutoriels imposés des MMORPG ; ajouter en P1 une **carte de
retour** (« Depuis ta dernière visite : série 5 jours, 3 coffres, une quête presque finie ») à la première ouverture du jour.

---

## 5. Détails de confort (liste de contrôle)

| Détail | Référence | Chez nous (0.1.256) | Recommandation | P |
|---|---|---|---|---|
| Pastilles de nouveauté (vu / non vu) | Genshin, GW2, Hades | une seule (Coffres : nombre + ★ roulette) | service commun : « ! » mandarine (nouveau), compteur fraise, coche pomme (action possible) ; s'éteint quand vu | P0 |
| Relancer la dernière activité | Brawl Stars, FFXIV (file) | non | « Continuer : Survie · Époque II » sous Jouer | P0 |
| Quête suivie choisie | WoW, FFXIV, GW2 (suivi) | la plus avancée de l'activité, choisie par le jeu | épingle dans le Journal, sinon automatique | P0 |
| « Y aller » depuis une quête | Genshin Naviguer, Lost Ark Localiser | la boussole le fait, pas les quêtes | bouton par quête | P0 |
| Tout réclamer | GW2, Genshin | **récompenses créditées seules** ; « Ouvrir tout » des coffres | garder (mieux que le panel) ; ajouter la petite fête de gain | ✔ |
| Heure de renouvellement | Lost Ark, WoW | non affichée | « Nouvelles quêtes dans 6 h 12 » | P1 |
| Rattrapage | Lost Ark repos, série | un jour de grâce, retombe au palier | garder ; montrer la règle sur la piste | ✔ |
| Taille et opacité du HUD | FFXIV, WoW | `ui_scale` global seulement | taille du HUD séparée, opacité des panneaux | P0 |
| Profils de HUD | WoW (Moderne / Classique), FFXIV (4) | non | Complet, Épuré, Télé / manette | P1 |
| Une notification à la fois | WoW toasts, Hades | bandeau, fil de butin, cartes, quête, Premiers pas peuvent se superposer | file unique à priorité (danger > quête > nouveauté > butin) | P0 |
| Barre d'action lisible | FFXIV, GW2 | recharge circulaire, éclat à la disponibilité (bien) ; cases vides « — » | touche dessinée sous la case, case vide tramée, chiffre de recharge | P0 |
| Prochaine attaque de la cible | FFXIV (incantation nommée) | effets de la cible | nom de l'attaque qui arme | P1 |
| Fil de butin avec comparaison | Diablo, WoW | **▲ + touche G pour équiper** (bien) | même style pour tout le butin, rareté = couleur de case | P1 |
| Cabine d'essayage | GW2, FFXIV | apparences visibles une fois gagnées | aperçu sur le héros avant ouverture / achat | P1 |
| Succès « presque finis » et suivis | GW2 | non | Résumé du Carnet | P1 |
| Recherche (Carnet, Guide) | FFXIV Journal, GW2, Lost Ark | non | champ de recherche | P2 |
| Raccourcis vers les pages | FFXIV, WoW (H, J, L…) | F1 Guide, Tab objectifs, Échap | J Journal, H Héros, K Carnet ; affichés dans le Guide | P1 |
| Manette | FFXIV barre croisée | `UiNav` complet, LB / RB, aide en 3 icônes (**rare et bien fait**) | Y = « Ta quête » au menu, X = Journal ; en partie, pastille de touche manette sous les cases | P1 |
| Lisibilité à distance (télé) | FFXIV console | vie et chiffres corrects, textes 14 px dans le HUD | profil « Télé » : HUD × 1,25, textes ≥ 18 px | P1 |
| Daltonisme | — | rouge / vert seuls portent la PE conseillée | doubler par forme (coche / croix) ; télégraphes bordés (bible § 10) | P1 |

---

## 6. Backlog

Tailles : S ≈ ½ journée, M ≈ 1-2 jours, L ≈ 3-5 jours (une équipe). Tout dans la DA v2 (`UiTheme` v2, `UiFeel`), avec captures
regardées (`shot_p1`, `shot_m5`, `shot_p6`, `shot_hud`) et `test_nav_screens` pour chaque écran nouveau.

### P0 : sans ça, le hub fait « prototype »
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| P0-1 | **Pastilles de nouveauté** : service `NewsDots` (clé → vu / non vu, compteur), posé sur les boutons du menu, les onglets de `PageScreen` et les cartes de Jouer ; sources : activité ouverte, carte / apparence / titre gagnés, succès, quête accomplie, pièce achetable | M | nouveau `core/news_dots.gd`, `ui/menu_widgets.gd` (`SideButton.set_badge`), `ui/page_screen.gd`, `ui/activities.gd`, `ui/lobby.gd`, `core/profile.gd` (clés vues) |
| P0-2 | **Continuer** : la dernière activité et ses réglages en un clic sous Jouer | S | `ui/lobby.gd`, `Profile.records` (`last_activity`) |
| P0-3 | **Boussole v2** : bulle « Ta quête » (pourquoi, « Y aller », 2 autres choix) + étiquette « Conseillé » dans Jouer | M | `core/compass.gd` (`advices(n)`), `ui/lobby.gd` (`_build_compass`), `ui/activities.gd` |
| P0-4 | **« Aujourd'hui »** au menu principal : 3 quêtes du jour, série, bouton Journal | S | `ui/lobby.gd`, `core/quests.gd` (lecture seule) |
| P0-5 | **Journal des quêtes** : écran `PageScreen` (Aujourd'hui, Semaine, Classes, Série, Terminées), ouvrable par J, le menu, la pause et le bilan ; « Y aller » et **épingle** par quête | M | `ui/quests_page.gd` → `PageScreen`, `ui/pause_menu.gd`, `ui/results_panel.gd`, `core/settings.gd` (touche J), `test_nav_screens` |
| P0-6 | **HUD : quête suivie** sous les objectifs (l'épinglée, sinon la plus avancée), lisible | S | `ui/quest_badge.gd`, `ui/hud.gd` |
| P0-7 | **HUD : une seule file de notifications** à priorité, jamais deux bandeaux superposés | M | `ui/hud.gd` (`show_message`, `feed`), `ui/info_card.gd`, `ui/quest_badge.gd` |
| P0-8 | **HUD : barre d'action et niveau lisibles** : barre de niveau au lieu du globe « RUN % », cases vides tramées, touche sous chaque case (avec le chantier 6 de `R_DA.md`) | M | `ui/hud.gd` (`_build_action_bar`), `ui/hud_widgets.gd` (`Orb`, `SkillSlot`) |
| P0-9 | **Taille et opacité du HUD** séparées de l'interface | S | `core/settings.gd`, `ui/settings_menu.gd`, `ui/hud.gd` |
| P0-10 | **Mots du jeu** côté joueur : « run », « lobby », « Abandonner : retour au lobby », « RTS / MOBA », « Bot » | S | `ui/results_panel.gd`, `ui/pause_menu.gd`, `ui/settings_menu.gd`, `ui/lobby.gd`, `test_texts_fr` |

### P1 : ce qui fait la qualité
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| P1-1 | **Succès v2** : catégories, points de succès et **piste de cadeaux cosmétiques**, « Presque finis », « Derniers obtenus », suivre (vers « Aujourd'hui » et le HUD), succès secrets avec indice ; Vue d'ensemble sans « 7 % » | L | `core/achievements.gd`, `ui/carnet_pages.gd`, `core/completion.gd`, `core/rewards.gd` |
| P1-2 | **Chapitres d'éveil** dans le Journal (le fil `Unlocks` en étapes cochées, cadeau par chapitre) | M | `core/unlocks.gd`, `core/compass.gd`, `ui/quests_page.gd` |
| P1-3 | **Profils de HUD** (Complet, Épuré, Télé / manette) : taille, opacité, compteur de dégâts masquable, mini-carte | M | `core/settings.gd`, `ui/settings_menu.gd`, `ui/hud.gd` |
| P1-4 | **Cabine d'essayage** : aperçu sur le héros des apparences d'un coffre ou de l'Armurerie | M | `ui/chests_page.gd`, `ui/hero_pages.gd`, `ui/gear_shop_page.gd` |
| P1-5 | **Carte de retour** du jour (« depuis ta dernière visite ») | S | `ui/lobby.gd`, `ui/info_card.gd` |
| P1-6 | Badge du héros : titre porté, PE, « 6 / 9 pièces » | S | `ui/lobby.gd` (badge) |
| P1-7 | Cible : prochaine attaque nommée ; fil de butin unifié (rareté = case) | M | `ui/hud.gd` (`_update_target`, `feed`), `ai/boss_brain.gd` (nom lu) |
| P1-8 | Page d'activité : « encore à gagner aujourd'hui », quêtes qui avancent ici ; heure de renouvellement des quêtes | S | `ui/lobby.gd` (`_show_menu`), `core/quests.gd` |
| P1-9 | Raccourcis J / H / K et Y / X au menu (manette) ; pastille de touche manette dans le HUD ; profil « Télé » | S | `core/settings.gd`, `core/ui_nav.gd`, `ui/hud.gd` |
| P1-10 | Daltonisme : PE conseillée et gains doublés par une forme | S | `ui/difficulty_panel.gd`, `ui/results_panel.gd` |

### P2 : finitions et confort
- Hub vivant : 2-3 personnages-services dans la scène avec pastilles (M ; `ui/lobby.gd`, `ui/map_backdrop.gd`).
- **Choix de la semaine** (Grande Chambre forte) : 2 quêtes hebdomadaires faites → choisir 1 apparence parmi 3 (M ; `core/quests.gd`, `core/rewards.gd`).
- Recherche dans le Carnet et le Guide (S ; `ui/carnet_pages.gd`, `ui/guide.gd`) ; Registre trié par « le plus proche de fini » (S ; `ui/registry_page.gd`).
- Grande carte : filtres de la légende, repère de la quête suivie (M ; `ui/hud.gd`).
- Édition libre du HUD (déplacer les blocs, WoW / FFXIV) si les profils ne suffisent pas (L).

---

## 7. Spécification « version 2 » (dans notre DA)

### Menu principal (croquis `lobby.html`)
- **Gauche** : rail de boutons autocollants. **Jouer** = seul primaire soleil (64 px, Entrée). Dessous, **Continuer** (lagon, 46 px) :
  « ↻ Continuer : <activité> · <réglage> ». Puis Héros, Coffres, Atelier, Carnet (52 px) avec pastilles (§ 5), et Paramètres / Quitter
  en petit sur une ligne.
- **Haut droite** : carte du héros (classe en tuile de famille, nom + titre porté en pastille améthyste, maîtrise, « Équipement 6 / 9 »
  + PE). Clic = changer de classe (comme aujourd'hui).
- **Droite** : panneau papier tramé **« Aujourd'hui »** : série (flamme, piste vers le prochain cadeau), puits d'encre avec les 3 quêtes
  (coche pomme, compteur), « Rien d'obligatoire », bouton Journal (J).
- **Bas centre** : **bulle « Ta quête »** (queue vers un personnage guide, facultatif) : icône du jeu, titre + compteur, une phrase,
  « Y aller » (Y), « Ou bien : » + 2 pastilles. Recalculée à chaque retour au menu (comme `_refresh_compass`).
- **Haut centre** : une seule bulle de nouveauté à la fois (mandarine, « ! » fraise), « Voir » ; les autres attendent (déjà
  `NEWS_CARDS` = 3 cartes : passer à 1 bulle + pastilles).
- **Bas** : zone du menu (vignette), bourse sur plaque papier, aide manette en icônes, version sur plaque (contraste ≥ 4,5:1).
- Clic : bible § 7 (écrasement, ressort, son, vibration). Focus manette : anneau lagon foncé + liseré blanc.

### HUD en partie (croquis `hud.html`)
- **Haut gauche** : puits d'encre translucide (encre-500 à 88 %, contour 3 px) : zone + minuteur en grand, carte et sceaux, or et clés ;
  séparateur ; **quête suivie** (pastille soleil ★, texte, compteur, jauge fine). Tab déplie tous les objectifs (existant).
- **Haut centre** : cible : nom + rang (pastille « élite »), jauge fraise avec **trace claire des dégâts**, effets avec durée, prochaine
  attaque nommée.
- **Haut droite** : mini-carte ronde contourée d'encre, repères en pastilles (objectif soleil, danger fraise), N ; « M carte, + / − zoom ».
- **Gauche, sous les objectifs** : **file de notifications** : une carte à la fois (quête accomplie pomme, nouveauté mandarine,
  danger fraise), 4 s, la suivante attend ; Premiers pas entre dans la même file.
- **Droite** : fil de butin : 3 lignes au plus, case de rareté, « ▲ meilleures » + touche d'équipement sur la ligne utile, s'efface en 6 s.
- **Bas centre** : effets positifs à gauche (bord pomme) et négatifs à droite (bord fraise) avec durée ; **barre de vie large** (contour,
  chiffre contouré) ; barre d'action : potion, 4 sorts, esquive en cases autocollantes 64 px, touche sous chaque case, recharge en
  camembert + chiffre, **éclat soleil** quand prête (existe), case vide tramée ; **barre de niveau** (lagon) + mode d'aide (« Assisté »).
- **Au centre** : rien de permanent ; onomatopées une à la fois (bible § 8), télégraphes bordés clairs.
- Profils (Paramètres › Interface en partie) : **Complet** (tout), **Épuré** (sans compteur de dégâts ni fil de butin, objectifs repliés),
  **Télé / manette** (× 1,25, textes ≥ 18 px, touches manette).

### Journal des quêtes (croquis `journal.html`)
- `PageScreen` « Journal », onglets **Aujourd'hui** (pastille du nombre à faire), Cette semaine, Classes (contrats), Série, Terminées
  (LB / RB). Fermer (B).
- **Gauche** : Défi du jour en carte soleil ; puits d'encre des quêtes (coche, icône d'activité, compteur, récompense en case, « suivie ») ;
  contrat de classe avec jauge ; « Nouvelles quêtes dans 6 h 12 · une relance par jour · une quête ratée revient demain ».
- **Droite** : fiche : titre contouré, « Où : Jouer › Duel », durée estimée (les quêtes ont déjà une estimation, `DAILY_MAX_MIN`),
  une phrase, jauge, récompense (puits), boutons **Y aller** (Y), **Suivie dans le HUD** (X), Relancer (1).
- **Bas** : piste de la série (3, 7, 14, 30, 60, 100 jours, cadeaux et titres en cases), règle du jour de grâce écrite.
- Récompenses créditées seules (comme aujourd'hui) avec la petite fête « gagné » (bible : 6 notes, confettis réduits).

### Carnet › Succès (croquis `succes.html`)
- En haut, **piste des points de succès** (papier tramé) : cadeaux cosmétiques aux paliers, « prochain cadeau à 500 : coffre d'aura rare ».
- Gauche : catégories en puits (Résumé, Suivis, Survie et époques, Donjons et Tour, Affrontements, Survivant, Collection, Secrets)
  avec « 9 / 16 » et pastilles ; recherche.
- Centre (Résumé) : **Presque finis** (cartes avec jauge, compteur, titre gagné, points, « suivi »), **Derniers obtenus** (avec date),
  un **secret** avec indice. Boutons « Voir la catégorie » (A), « Suivre » (X).
- Droite : **Titres** : aperçu du nom avec le titre porté, titres gagnés (Porter), titres à gagner avec leur condition.
- Jamais de pourcentage ; points et titres rétroactifs (les succès sont déjà évalués d'après les records).

---

## 8. Questions ouvertes (avec recommandation)

1. **Les Quêtes restent-elles une carte du menu Jouer ?** Aujourd'hui « Quêtes » est une activité (`Activities.LIST`, déblocage après
   3 Survies). **Reco** : en faire le **Journal** (couche au-dessus de toutes les activités : touche J, « Aujourd'hui » au menu) et
   retirer la carte de Jouer, ou la garder comme simple raccourci. Le déblocage après 3 Survies reste.
2. **Un personnage guide porte-t-il la bulle « Ta quête » ?** **Reco** : oui si on prend un personnage **déjà dans le jeu** (pas de
   création d'asset) ; sinon la bulle seule, avec sa queue vers le héros.
3. **Points de succès et piste de cadeaux ?** **Reco** : oui, cosmétique seulement, rétroactif ; aucun bonus de statistique (contrairement
   aux bonus de compte de GW2).
4. **Passe de saison ?** **Reco** : **non** (calendrier imposé = corvée, à l'opposé de la décision du 16/10). À la place, en P2, un
   **Choix de la semaine** (GW2 / WoW) facultatif, et la série existante.
5. **Personnalisation du HUD : profils ou édition libre ?** **Reco** : 3 profils + taille / opacité d'abord (P0-9, P1-3) ; l'édition libre
   seulement si des joueurs la demandent par les notes Alt + clic droit.
6. **Hub en scène (Hades) ou menu à boutons ?** **Reco** : garder les boutons (vitesse, manette, 1280×720), ajouter des
   personnages-services décoratifs et cliquables en P2.
7. **Bulle de nouveauté unique ou 3 cartes ?** **Reco** : une bulle + pastilles (une seule bulle par écran, bible § 8) ; la liste complète
   reste dans le Guide › Nouveautés.

---

## Sources
- Blizzard, « World of Warcraft: Dragonflight HUD and UI Revamp » : https://worldofwarcraft.com/news/23841481 ; warcraft.wiki.gg :
  https://warcraft.wiki.gg/wiki/Edit_Mode , https://warcraft.wiki.gg/wiki/HUD_Edit_Mode (images : Edit_Mode_11000, Adventure_Guide_Df,
  Great_Vault_interface_1102, Objective_Tracker, Dungeon_Finder_1027, Dragon_Isles_Summary).
- Square Enix, guide de l'interface FFXIV : https://na.finalfantasyxiv.com/uiguide/know/know-hud/hud-layout.html ; consolegameswiki :
  https://ffxiv.consolegameswiki.com (HUD_1, HUD_2, Adjust_HUD, Duty_finder_duty_roulette, Duty_list_full, Journal_Search_Function).
- ArenaNet, Wizard's Vault : https://www.guildwars2.com/news/discover-the-wonders-within-the-wizards-vault-in-guild-wars-2-secrets-of-the-obscure ;
  https://wiki.guildwars2.com/wiki/Wizard%27s_Vault ; images Achievements_interface, Hero_panel_achievements, Fashion_wardrobe, Hero_panel_mastery.
- Lost Ark : https://www.playlostark.com/en-us/game/guide/quests-guide ; https://www.playlostark.com/en-us/news/articles/launch-release-notes ;
  https://www.icy-veins.com/lost-ark/guide-to-unas-tasks ; https://maxroll.gg/lost-ark/resources/procyons-eye-compass-daily-events
- Genshin Impact, wiki Fandom : https://genshin-impact.fandom.com (Adventurer_Handbook_Commissions, _Experience, _Guide, Achievements,
  Quest_Menu_Story_Tab, Paimon_Menu_Version_3.2).
- Honkai: Star Rail : https://honkai-star-rail.fandom.com/wiki/Interastral_Peace_Guide/Daily_Training ; https://www.icy-veins.com/honkai-star-rail/daily-training
- MapleStory : https://www.maplesea.com/guide/user_interface/ ; https://maplestorywiki.net/w/Maple_Guide
- Hades, wiki Fandom : https://hades.fandom.com (House_of_Hades_1, Fated_List_II, MirrorInterface, CodexScreen, House_Contractor).
- Brawl Stars : https://ixd.prattsi.org/2025/02/design-critique-brawl-stars/ ; fiche App Store FR (id 1229016807).
- Captures Steam (fiches de boutique, 17/10/2026) : FFXIV 39210, Lost Ark 1599340, GW2 1284210, MapleStory 216150, Black Desert 582660,
  Hades 1145360, Persona 5 Royal 1687950, ESO 306130.
