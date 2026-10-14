# Idées en vrac du joueur (15/10/2026) : reformulées, améliorées, classées

Source : le mémo du joueur (12 idées). Chaque idée est reprise ici avec ce qu'on en fait concrètement,
puis classée par **priorité** (apport au jeu) et **facilité** (travail et risque). Le rang = ordre de mise en
œuvre. État mis à jour dans la dernière colonne et dans `CHANGELOG.md`.

## Classement

| Rang | Idée | Priorité | Facilité | Pourquoi ce rang | État |
|---|---|---|---|---|---|
| 1 | Options de lisibilité : masquer effets de sorts / auras de skin, pour soi ou pour tous | Haute | Très facile | Aide le JcJ, les PC modestes ; ne touche à aucune règle de jeu | **Fait (0.1.153)** |
| 2 | Roulette quotidienne de skins (3 tirages par jour, case « perdu ») | Moyenne | Facile | Boucle de rétention simple, réutilise coffres d'apparence et titres | **Fait (0.1.153)** |
| 3 | Puissance d'équipement (PE) et déblocages | Haute | Moyenne | Donne un repère unique du niveau de l'équipement ; sert de verrou aux activités avancées | **Fait (0.1.154)** |
| 4 | Potions | Moyenne | Moyenne | Brique indispensable au Battle royale et au Trio ; utile en Survie et en donjon | **Fait (0.1.155)** : 4 potions, touches C / V (au lieu de 2 emplacements équipés) |
| 5 | Forge unifiée (améliorer, démonter, enchanter, gemmes, polir, réforger) avec animations | Haute | Moyenne | La logique existe déjà (`Craft`, `Forge`) : il manque la page unique et le ressenti | À faire |
| 6 | File d'attente du Duel (recherche, match trouvé, draft 60 s, récap 10 s) | Haute | Moyenne | Beaucoup d'écrans mais peu de règles nouvelles ; prépare le chargement et un vrai en ligne | À faire |
| 7 | Lisibilité des sorts : texture = zone = effet | Très haute | Difficile (itératif, à l'œil) | Le plus gros gain pour le JcJ, mais demande des captures et des allers-retours | Audit outillé + premier lot ; la suite demande ton œil |
| 8 | Trio PvE puis PvP (5 vagues, boss sac à PV, zone qui bascule en JcJ) | Haute | Difficile | Réutilise donjons, alliés IA et ciblage par camp ; nouveaux : vagues, boss long, bascule | Conçu, à coder (après 1 à 7) |
| 9 | Battle royale (spawn aléatoire, coffres de loot, potions) | Haute | Difficile | Besoin de la PE, des potions et d'adversaires IA nombreux ; carte à zone réduite | Conçu, à coder |
| 10 | MOBA 4v4 | Moyenne | Très difficile | Voies, tours, sbires, objectifs : un jeu à part entière | Conçu, très long terme |

L'ordre suit le rapport valeur / effort, avec une contrainte de dépendance : les potions (4) et la PE (3)
précèdent le Battle royale (9) et le Trio (8) qui s'en servent.

---

## 1. Options de lisibilité (rang 1)
**Idée du joueur** : pouvoir désactiver les textures d'attaque, l'aura des skins, les auras, pour la lisibilité ou les
performances, et choisir si c'est pour soi seul ou pour tout le monde.

**Retravaillée** :
- Trois réglages dans Paramètres > Caméra & interface > « Effets visuels » :
  1. *Effets de sorts et d'impacts des héros* ;
  2. *Auras de skin* ;
  3. *Étincelles, poussière et éclairs d'impact* (Tous / Réduits / Aucun).
- Les deux premiers ont cinq valeurs : **Tout afficher**, **Atténuer ceux des autres héros** (35 % d'opacité),
  **Masquer ceux des autres héros**, **Masquer les miens**, **Tout masquer**. C'est le « pour toi ou pour tout le
  monde » du mémo : le cas utile en duel est « atténuer / masquer ceux de l'adversaire » (on lit ses vrais
  signaux), le cas performance est « tout masquer ».
- **Règle de sécurité** : les zones d'attaque (`Telegraph`, cercles et rectangles au sol, avertissements des boss)
  ne sont **jamais** masquées. Seuls les décors lumineux le sont, sinon on cacherait de l'information de jeu.
- Les aperçus (lobby, équipement) ne sont jamais masqués.
- Le réglage d'une aura déjà posée se met à jour pendant la partie (vérification toutes les 0,5 s).
- Plus tard (en ligne) : une case « imposer à tous » côté salon n'aurait de sens que pour les effets dont les autres
  joueurs sont propriétaires : le réglage local suffit tant que le jeu est solo.

## 2. Roulette quotidienne (rang 2)
**Idée du joueur** : roulette de skins plus ou moins rares à débloquer, avec une case « perdu », 3 lancers par jour.

**Retravaillée** :
- Une **roue de 12 cases** (couleur par rareté) : perdu ×3, commun ×3, rare ×3, épique ×1, légendaire ×1, jackpot (apparence
  dorée) ×1. Le jackpot ne tombe qu'une fois les apparences possibles épuisées ou remplacé par un coffre légendaire.
- **3 lancers par jour** (jour local) ; les non-utilisés ne se cumulent pas. Un lancer supplémentaire s'obtient en
  insignes (coût croissant, 2 par jour au plus) : c'est un puits à insignes, pas un levier de puissance.
- **Pitié** : après 6 « perdu » d'affilée, le lancer suivant est au moins « commun ». Après 25 lancers sans rare ou
  mieux : rare garanti. Le compteur est visible.
- Le gain est **cosmétique uniquement** (coffres d'apparence/auras, apparences, titres, insignes en lot de consolation) :
  jamais de puissance, conformément à l'autel de la fortune (0.1.139).
- Animation : roue qui tourne, ralentit, aiguille qui claque ; la case gagnante s'illumine.
- Accès : Coffres > Roulette (et pastille « 3 lancers » au lobby).

## 3. Puissance d'équipement, PE (rang 3)
**Idée du joueur** : un « gear force » qui calcule la puissance d'une classe d'après ses stats ; selon lui, des objets
de butin et certaines activités se débloquent.

**Retravaillée** :
- `core/gear_power.gd` : PE d'une pièce = sa note (`Items.rating`, qui compare chaque stat à la valeur habituelle de son
  emplacement) × une échelle linéaire du niveau de puissance de la pièce ; PE du héros = somme des 9 emplacements,
  de l'arme secondaire (30 %) et des paliers de set actifs (+6 % par palier).
- **PE attendue** par niveau (`expected(niveau)`) : la valeur d'un équipement correct de ce niveau. On affiche toujours
  « PE / attendue » : une barre qui se remplit, avec un palier de couleur (Faible, Correct, Solide, Redoutable).
- **Où on la voit** : page Équipement, pied du lobby, fiche de chaque activité (« PE recommandée »), comparaison d'une
  pièce (variation de PE si on l'équipe).
- **Ce qu'elle débloque** (jamais caché, grisé avec la condition) :
  - Donjon Héroïque : 70 % de la PE attendue du niveau du donjon ; Mythique : 90 % ;
  - Gantelet et Ruée des boss (Héroïque et Mythique) : mêmes seuils ;
  - Les coffres de butin « Mythique et Légendaire » des donjons ne proposent des pièces qu'à PE suffisante (sinon on
    reçoit des pièces d'un cran en dessous), pour ne pas faire tomber de l'équipement inutilisable.
- Le mode dev ouvre tout. Les duels (équilibrés à l'arme ou équipé normalisé) ne dépendent pas de la PE.

## 4. Potions (rang 4)
**Idée du joueur** : introduire les potions dans le jeu.

**Retravaillée** :
- Quatre potions seulement, lisibles : **Soin** (rend 40 % des PV en 2 s, annulée par un coup reçu à 50 %), **Mana/Énergie
  de sort** (ramène deux recharges de sorts à zéro), **Élan** (+25 % vitesse 8 s), **Ruse** (+25 % dégâts 8 s).
- **Raccourci** unique (touche 1-4 : à la manette, croix directionnelle) ; **2 emplacements** de potion équipés en
  début de partie ; recharge commune de 20 s : une potion n'est pas un bouton « invincible ».
- Sources : coffres de la carte, marchands ambulants, butin des élites. Fabrication de base à l'Atelier (cristaux).
- **Règles par mode** : Survie et donjons : permises ; Duel : jamais (équilibre) ; Battle royale et Trio : centrales
  (la rareté fait le jeu).
- Elles arrivent par `core/potions.gd` (définitions, effets, stock) pour que les modes à venir les réutilisent.

## 5. Forge unifiée (rang 5)
**Idée du joueur** : tout au même endroit (forge, démontage, enchantements, gemmes, polissage, réajustement d'une
stat) avec barre de progression, résultat réussi en vert ou échec en rouge ; grosse page et sous-menus.

**Retravaillée** :
- Une page **Atelier > Forge** unique : à gauche l'objet (inventaire + équipé, filtres), au centre sa fiche, à droite
  les **six établis** en onglets : *Améliorer* (+1 à +10), *Enchanter*, *Sertir* (gemmes, fusion de 3), *Polir*
  (qualité), *Réforger* (relancer une stat bonus), *Démonter* (cristaux).
- Chaque action passe par une **barre de forge** (0,8 à 1,6 s selon l'action) : chauffe, frappe, puis verdict
  **vert** (« Réussi » avec la stat qui bouge) ou **rouge** (« Raté » / « Pas mieux »). Le verdict est calculé avant
  l'animation (aucun changement de règles de hasard) : l'animation est un habillage.
- Sans bruit inutile : le son est celui existant (`Sfx`), le tremblement de caméra des paramètres s'applique.
- L'ancienne fiche d'objet (Forge de la run) pointe vers cette page ; la logique n'est pas dupliquée.

## 6. File d'attente du Duel (rang 6)
**Idée du joueur** : lancement du matchmaking → écran avec temps de recherche, « match trouvé » à confirmer façon LoL,
phase de draft d'une minute (12 sorts, classe, maîtrise, certificats), validation, puis récapitulatif de 10 s avec les
sorts des deux joueurs, puis le combat. Ça permet de charger les textures.

**Retravaillée** (étapes) :
1. **Recherche** : écran avec chronomètre ; adversaire tiré dans l'échelle de la Ligue (cerveau ou scripté) ; durée
   simulée 3 à 9 s (annulable). Le même écran servira à un vrai en ligne.
2. **Match trouvé** : fenêtre « Accepter » avec décompte 10 s, deux pastilles (toi / adversaire) ; refuser ou laisser
   expirer renvoie à la file. L'adversaire IA accepte après 1 à 4 s.
3. **Draft de 60 s** : l'écran de préparation existant (`duel_prep.gd`) avec décompte : classe, 12 sorts, maîtrise,
   certificats ; bouton « Valider » ; quand les deux ont validé le jeu démarre aussitôt. À 0 s : la sélection actuelle
   est validée d'office.
4. **Récapitulatif de 10 s** : les deux héros (classe, 12 sorts, certificats, panoplie), « Prêt » ; pendant ce temps,
   préchargement de la carte, des effets et des textures des deux kits (`ResourceLoader.load_threaded_request`).
5. **Arène**.
- Dans les modes à règles fixes (Duel à l'arme), la partie draft se limite à classe + sorts.
- Le classement/rang de Ligue reste géré par `League`.

## 7. Lisibilité des sorts : texture, zone et effet (rang 7)
**Idée du joueur** : les animations doivent correspondre à la zone d'attaque (certaines grosses animations pour une petite
zone), les textures sont trop transparentes, l'impact d'un sort ne se sent pas assez ; recréer des textures, ou revoir
l'effet pour qu'il colle à l'animation ; exemple : le coup de lame du samouraï en trois explosions en ligne qui projettent
les ennemis en l'air.

**Retravaillée** :
- **Règle de conception** : *ce que tu vois = ce que tu touches*. L'effet visuel d'un sort est mis à l'échelle de sa zone
  réelle (rayon, longueur, largeur), avec une marge de 10 % au plus. Sinon, soit on change l'échelle, soit on change la
  zone.
- **Outil d'audit** : `tools/fx_audit.tscn` mesure, pour chaque sort de chaque classe, la taille de la boîte de l'effet
  (maillages d'Eden) contre sa zone de dégâts, et sort la liste classée par écart. On corrige d'abord les pires.
- **Impact** : trois leviers globaux, mesurés avant/après sur la même vue (`bench_gfx`) : opacité de départ plus haute,
  cœur lumineux court à l'impact, micro-arrêt sur image (déjà dans les paramètres). On ne retouche pas texture par
  texture avant d'avoir regardé l'effet global.
- **Recréations ciblées** : motifs construits en code (`Vfx`) pour les sorts qui n'ont pas d'effet d'Eden fidèle. L'exemple
  du joueur : « Triple lame » : trois explosions alignées devant le héros (0,7 m, 2,2 m, 3,8 m), 0,12 s entre chaque,
  chacune une zone de dégâts réelle qui projette en l'air ; la zone de l'ensemble est un couloir, affiché comme tel.
- Chaque correction passe sur capture : la session locale peut les prendre (elle a le client), pas la session cloud.

## 8. Trio : PvE puis PvP (rang 8)
**Idée du joueur** : mode PvE/PvP à 3 joueurs, 5 vagues de monstres nombreux et résistants, un boss de donjon sac à PV
difficile ; une fois vaincu, la zone devient un JcJ à trois, le survivant gagne un coffre de skin légendaire.

**Retravaillée** :
- *Le Siège* : joueur + 2 alliés IA scriptés (`ClassRival.ally`) aujourd'hui ; 3 vrais joueurs plus tard (le code ne
  suppose pas que les alliés sont des IA).
- **5 vagues** (monstres ×2 en nombre, PV ×2), soin partiel entre vagues, potions aux coffres de salle.
- **Boss** à phases (réutilise ceux des donjons) avec PV très hauts et une *enrage* à 6 min : il ne se bat pas lentement
  mais mal : il faut jouer ses phases.
- **Bascule** : la mort du boss ferme la zone (anneau rétréci en 20 s) ; son *cœur* tombe au milieu ; **chacun pour soi**,
  les alliés deviennent hostiles ; dernier debout : coffre d'apparence **légendaire**. Un joueur peut aussi emporter le
  cœur hors de l'anneau pour *quitter le duel* avec une récompense moindre (choix de risque).
- Effets de ciblage : groupes `heroes` et `hostile_targets` (lot 12) ; Trio ajoute un 3e camp.

## 9. Battle royale (rang 9)
**Idée du joueur** : spawn aléatoire sur la carte, plein de coffres de loot différent, intro des potions.

**Retravaillée** :
- 8 héros (joueur + 7 IA scriptées/cerveaux), carte de Survie agrandie (`proc_map`), spawn aléatoire distinct.
- Tout le monde part nu, niveau 1 ; coffres à 3 qualités avec loot d'équipement synchronisé, potions, cartes. Le niveau
  monte par coffres et éliminations.
- **Anneau** qui se referme en 4 phases (3 min 30 au total), dégâts hors anneau croissants ; dernier debout gagne.
- Récompenses : insignes selon le rang, coffre d'apparence au top 3, titre à la 1re victoire.
- Dépend de : potions (4), PE (pour le plafond d'équipement des coffres), ciblage multi-camps (Trio).

## 10. MOBA 4v4 (rang 10)
**Idée du joueur** : un mode MOBA 4v4.

**Retravaillée** : trois voies (haut, milieu, bas) ou une voie unique pour commencer ; 4 héros par camp (1 joueur + 3 IA),
sbires par vagues, 2 tours par voie, un nexus ; niveau de partie (PX communs), or des sbires pour acheter 6 objets dans
une boutique de base ; l'IA de camp joue des rôles (assassin, soutien…). C'est un projet d'au moins dix lots : on ne le
code qu'une fois 8 et 9 en place (ils fournissent les camps multiples, les vagues et le ciblage).
