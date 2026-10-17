# Eden Slash — règles de jeu

Direction artistique : celle d'Eden Eternal (textures de sol, arbres, rochers, maisons,
coffres, PNJ, monstres, armes et tenues du jeu d'origine). Les maps de combat sont
générées à chaque run, avec nos propres collisions simples.

Comment lire ce fichier (passe P17, 16/10/2026, `conception/nuit_15_10/R_P17.md`) : une section par système, rangées en
parties. Quand deux passages se contredisent, **le plus récent (numéro de version ou passe la plus haute) prime** ; la partie F
garde les décisions remplacées pour mémoire. Les chiffres cités renvoient à une constante du code (nom entre accents graves) :
c'est le code qui fait foi. Points d'entrée du code et outils : `CLAUDE.md`, « État du jeu ». Règles opérationnelles du Duel
(échelles, plafonds, profils « opti ») : `CLAUDE.md`, « Duel (JcJ) ».

Chiffres clés vérifiés dans le code (16/10, 0.1.212 ; lot H4a) : Aventure au niveau de héros, monstres par carte `Epochs.BANDS`
(I-1 1-23 … IV-3 80-90) × `Epochs.MAP_MULT` (remplace `MONSTER_MULT`) ; boss de
la Survie `Epochs.BOSS_HP_MAP` 80 000 / 370 000 / 1 750 000 × `BOSS_HP_EPOCH` 1 / 2 / 4 / 5,5 au niveau de référence, × 1,1 par niveau du boss, rage du boss `BOSS_RAGE_AT`
2:30 / 3:00 / 4:00 ; rage de la carte `RunDirector.RAGE_TIERS` ×1,1 / 2 / 11 / 101 ; Menace +20 % de PV par cran, plafond 5
(`Menace.STEP`, `MAX`) ; verrous de PE `GearPower.DIFF_RATIO` 0 / 3,4 / 2,9 (lot H56), `Siege.POWER_RATIO` 0 / 4 / 3,4, `LEGEND_RATIO` 1,8 ;
insignes de participation `Run.INSIGNIA_BASE` 25 ; plus d'enclume en Survie (passe N2) ; boss hors Survie
`Dungeons.boss_hp` = 106 000 × 1,09^(niveau − 15) × [1 ; 3,4 ; 2,5] ; Survivant : paliers `Survivor.PALIERS` I à V,
`palier_mult` 1 / 1,45 / 1,7 / 1,75 / 2,1 (`ModeRules`), boss 6 000 000 PV (`Survivor.BOSS_HP`), dégâts ×1,4 (`BOSS_ATK`).

## Table des matières

- **Partie A — Héros et combat**
  - Toutes les classes d'Eden (60 jouables)
  - Classes réglées à la main (6)
  - Statistiques d'Eden
  - Sorts complets
  - Expertise, talents et certificats
  - Niveau de héros (lot H1)
  - Grimoire et infobulles
  - Auto-attaque des armes (refonte 0.1.127, demande du joueur du 14/10/2026)
  - Effets déclenchés (procs)
  - Maniabilité (hard to master)
  - Saut, une mécanique de build
  - Impact visuel
  - Cartes de build (roguelite)
  - Cartes de build (0.1.30)
- **Partie B — La Survie (mode principal)**
  - Boucle de jeu et Survie (refonte 0.1.123, décisions du joueur du 14/10/2026)
  - Déroulement d'une run (10 minutes + rage)
  - Pression constante (easy to play, hard to master)
  - Apparition des monstres et puissance (passe P15, retour du joueur du 15/10)
  - Pacte, géants et Menace (passe P12, 0.1.191, idée du joueur inspirée de Megabonk)
  - Boss : PV fixes et rage du boss (passe P11, retour du joueur du 15/10)
  - Zones et biomes (progression)
  - Monnaies, coffres et zones (refonte 0.1.25)
  - Sceaux du donjon
  - Map générée
  - Marchands ambulants (remplacent le village)
  - Extraction
  - Plafond de niveau par zone
- **Partie C — Les autres activités**
  - Survivant (mode à part, lots S1 à S8 de `conception/survivor/`, ouvert à tous depuis 0.1.210)
  - Bibliothèque de boss et donjons à la carte (passe M2, nuit du 15/10)
  - La Tour : types d'étage (passe M3, nuit du 15/10)
  - Ruée des boss et Siège sur la bibliothèque (passe M6, nuit du 15/10)
  - Battle royale (passe M1, 0.1.201 ; mode codé en 0.1.161, idée 9 de `conception/IDEES_EN_VRAC.md`)
  - L'Échiquier (autochess, `conception/autochess/SPEC.md` ; entrée et fin : lot AC-I)
  - Les Deux Voies (étude `conception/benchmark/MOBA.md`, en cours : lots MB-A à MB-K)
  - Le Colisée (étude `conception/benchmark/ARENA.md`, en cours : lots CO-A à CO-L)
  - L'Assaut (étude `conception/benchmark/TACTIQUE.md`, en cours : lots TAC-0 à TAC-14)
- **Partie D — Économie et progression**
  - Joaillerie et forge (comme dans Eden)
  - Équipement
  - Sets d'équipement (façon Eden)
  - Choix et coffres de récompense (lot U3 de la nuit du 15/10)
  - La quête commune se voit (passe P6, 0.1.186)
  - Quêtes (passe M5, retour du joueur : « le Défi de maîtrise ressemble à des quêtes journalières »)
- **Partie E — Textes**
  - Tout le jeu en français (passe P10, 0.1.190)
  - Curseurs et réticule de visée (lot K1)
- **Partie F — Archives : décisions remplacées (gardées pour mémoire, ne plus coder d'après elles)**
  - Combos d'auto-attaque (3 coups, le 3e = coup final)
  - Classe + arme (builds exotiques)
  - Roguelite : héritage
  - Étapes et sources (refonte 0.1.91, façon Megabonk)
  - Méta-progression des cartes et classes (0.1.33)
  - Équipement en run (0.1.34)
  - Ordre de réalisation

# Partie A — Héros et combat

## Toutes les classes d'Eden (60 jouables)

Les 6 classes ci-dessous sont réglées à la main ; les **54 autres** sont importées
automatiquement (`tools/auto_classes.py`, `tools/auto_spells.py`, noms français dans
`tools/eden_fr.py`) :

- **14 classes vertes** (classes de base d'Eden) : Barde, Chevalier, Ingénieur, Artiste martial,
  Illusionniste, Danseuse de lames, Chaman, Templier, Rôdeur, Démoniste, Sage, Chevalier dragon,
  Luminaire, Inquisiteur ;
- **40 classes orange** (ascensions : Berserker, Protecteur, Paladin, Kage, Asura…).
- Sorts partagés, **jouables d'emblée** (sans attendre la maîtrise) : une classe verte reçoit
  les 5 sorts de novice de sa famille d'Eden ; une classe orange garde **tous les sorts de sa
  classe d'origine** (comme dans Eden) et le certificat qu'elle partage avec elle (proposé en
  carte pendant la run). Les sorts propres se débloquent par la maîtrise (4 au départ).
- Déblocage : maîtrise de la classe de base de la famille (vertes, niveau 2 à 8 selon le niveau
  exigé par Eden) ou de la classe parente (orange, niveau 8). Les 5 classes de départ gardent
  leurs missions.
- Conversion d'un sort : cible, forme, portée, rayon, recharge (c_spell col. 32) et puissance
  (col. 35) d'Eden ; effets lus dans le texte anglais (renversement, gel, immobilisation,
  sommeil, terreur, poison, saignement, brûlure, vulnérabilité, affaiblissement, buffs…).
- 11 nouvelles armes avec leur combo : épée, rapière, espadon, marteau, bâton de métal,
  gantelets, canon, lance, guitare, grimoire, faux-fusil.
- Sélecteur de classe plein écran (5 familles en colonnes, vertes puis leurs orange en retrait).
- Modèles **modulaires** : un corps animé commun (`assets/player/body/body_m.glb`, toutes les
  postures et animations de sorts) habillé d'une tenue et de cheveux séparés
  (`assets/player/outfits`, `assets/player/hairs`) : changer de tenue = un skin.

## Classes réglées à la main (6)

Données : `tools/build_classes.py` (sorts, icônes et effets d'Eden, tenues, armes, postures).

| Classe | Arme (Eden) | Jeu | Points forts |
|---|---|---|---|
| Samouraï | Katana W213–216 | corps à corps, combos d'états | saignement → cicatrice → Marduk |
| Guerrier | Hache W201–204 | corps à corps lourd, PV ×1,25, +6 déf | renversements, provocation, Fureur, Barrière |
| Voleur | Dague W108–111 | rapide (+15 % vit. d'attaque, +10 % crit) | poison, embuscade (×2 sur empoisonné), pas de l'ombre (téléportation) |
| Chasseur | Arc W501–504 | **à distance** (tir de base 13 m) | flèches perçantes, volées en éventail, bombe flash |
| Clerc | Sceptre W301–304 | hybride, PV ×1,1 | zones sacrées, **soins**, régénération, barrière |
| Magicien | Bâton W601–604 | **à distance** (projectile 12 m), attaque ×1,15, PV ×0,8 | zones de feu/glace/foudre, téléportation |

Équilibre face aux boss de l'Aventure (lot CLS-1, `conception/progression/R_CLS1.md`) : `data/class_balance.json` relève, en Aventure
seulement, la base d'une classe au plancher de sa famille (Chasseur : PV 1,1, attaque 1, défense 3) ou multiplie ses dégâts / PV (Asura,
Rakshasa ×1,3 ; Conjurateur, Chasseur de démons, Luminaire ×1,2) ; le duel, la Tour et les modes scellés gardent `data/classes.json`.

Types de compétences du moteur : `dash`, `spin`, `cone`, `fan`, `flurry`, `line`, `buff`, et
`bolt` (projectile : volée, dispersion, perforation), `ground` (zone au sol à l'endroit visé),
`heal` (soin en % des PV), `blink` (téléportation sans traverser les murs).
Chaque classe : 9 compétences d'Eden adaptées, 2 passifs propres (icônes d'Eden) + passifs communs.

## Statistiques d'Eden

- **Attributs** : Force, Agilité, Intelligence, Sagesse, Chance. Base et croissance par niveau
  propres à chaque classe, + équipement (affixes d'attributs), × talents (+X % de Force…).
- Force → attaque physique, PV, défense, parade · Agilité → vitesse d'attaque et
  d'incantation, esquive (max 20 %) · Intelligence → attaque magique · Sagesse → PV, soins,
  critique magique · Chance → critique physique et magique, dégâts critiques.
- **Physique / magique** : les sorts physiques utilisent l'attaque et le critique physiques,
  les sorts magiques (Clerc, Magicien) l'attaque et le critique magiques ; la vitesse
  d'incantation accélère les sorts magiques.
- Armes : attaque physique ET magique selon le type (hache surtout physique, bâton surtout
  magique) + attribut principal ; anciennes sauvegardes converties automatiquement.

## Sorts complets

Chaque classe a tous ses sorts d'Eden (`c_class` colonnes 34-43 + 5 sorts novices) : 15 pour
Guerrier, Voleur, Chasseur, Clerc ; 14 Magicien ; 9 Samouraï. Nouveaux états : Mur du titan,
Instinct de survie, Puissance (+30 % Force), Célérité (+30 % Agilité), Grâce de sagesse,
Vitalité, Posture du chasseur, Désarmé (ne peut plus attaquer), Ange gardien (relève à 30 %).

## Expertise, talents et certificats

- **Expertise de classe** (40 niveaux), gagnée en fin de run avec la classe : niveau atteint
  ×15, monstres ÷2, élites ×10, +200 en cas de victoire (rattrapage, 1re victoire et part de l'arbre :
  voir « Insignes et maîtrise des 60 classes »).
- **Talents** : l'arbre « Class Talent » d'Eden (`c_talent` + `c_enchant`), 3 lignes × 8
  paliers, 18 talents par classe, prérequis et paliers de points (15/20/25/30/35) ; 2 points par
  niveau d'expertise. Effets : stats (défense, PV, force…, critique, vitesses, parade, soins)
  ou renfort d'une compétence (dégâts, recharge, durée). Propres à la classe jouée.
- **Certificats** : les 2 passifs de chaque classe (`c_class` col. 30-31), débloqués aux
  niveaux d'expertise 3 et 8, à équiper avant la run et utilisables par **toutes** les classes
  (1 emplacement, +1 tous les 10 niveaux d'expertise cumulés, 4 max). Ils ne sortent plus en
  cartes de niveau.
- Écran **Expertise** dans le lobby ; « Nouvelle partie » remet tout à zéro.

### Écran Héros (lot U4 de la nuit du 15/10, 0.1.175)

- **Équipement** : 5 préréglages par classe en haut de la page (lot GX-4 ; 3 avant, une vieille sauvegarde reçoit 2 préréglages
  vides ; un préréglage qui garde son nom d'origine ne montre que son numéro). « Gérer » : pour chaque autre préréglage « Copier
  ici » et « Comparer » (PE de chacun, emplacement par emplacement ce qui change, « Passer à »), noms d'usage en un clic (Survie,
  Donjons, Tour, Duel, Essai), **tenue liée** (clé `look` du préréglage : tenue, tête, dos, auras, couleurs reviennent quand on
  le reprend ; aucune stat). **Sur la page d'une activité** (lot GX-5, Q6) : Survie, Donjons, Ruée, Siège, Tour et Duel équipé
  ont une rangée « Équipement » épinglée au-dessus du bouton de lancement (les préréglages qui ont des pièces ; l'actif en
  mandarine ; ★ sur celui dont le nom d'usage va avec l'activité ; PE en infobulle) : un clic le rend actif et la page se refait
  (PE, estimation) (`ui/preset_pick.gd`). Rien en partie ni pour les modes scellés. Panoplie : la plus portée, même sans bonus (« 3 / 6 · bonus à 4 », paliers au survol). Manette : la
  barre d'aide dessine X (« Équiper » dans le sac, « Retirer » sur la poupée, meta `pad_x`). Avant GX-4 : un clic change, « Gérer » copie l'équipement
  porté vers un autre préréglage ou renomme ; `EquipmentPage.PresetBar.extra_actions` reçoit les actions
  ajoutées plus tard, ex. « Équiper le meilleur »). La fiche d'objet est cachée sans sélection ; une pièce
  choisie montre la pièce portée à côté (▲ / ▼ en %, puissance d'équipement). Pas de préréglages ni de Forge
  dans le menu pause de la Survie.
- **Classe** : maîtrise et parcours toujours visibles, puis trois sous-onglets Sorts (un clic ouvre le Grimoire
  sur le sort), Talents, Certificats (plateau, bonus, liste). **Talents v2** (lot GX-5) : les points libres se lisent depuis
  les trois sous-onglets (« 3 points libres · 14 placés », un clic ouvre l'arbre) ; l'arbre dit au-dessus de chaque colonne
  combien de points placés l'ouvrent (« 15 pts », cadenas tant qu'il en manque) et dessine ses prérequis (lien pomme quand il
  est tenu, gris sinon, le niveau demandé au milieu) ; bord lagon = un point peut aller ici. Infobulle : l'effet **maintenant** et
  **avec un point de plus** (« +4 % de défense » → « +5 % »), l'effet au niveau maximal, le prérequis et la colonne (✓ / ✗).
  **Réaffecter sans punition** : clic droit (X à la manette) = −1 point, gratuit, refusé seulement si un talent plus loin en
  a besoin (`Profile.remove_talent`, `talent_set_valid` : l'arbre doit pouvoir se rebâtir point par point) ; « Tout reprendre »
  rend tous les points (gratuit) et « Annuler » remet l'arbre d'avant tant qu'aucun point n'a été replacé. Recherche par nom
  ou effet (les autres cases pâlissent). Mode scellé (Survivant, Battle royale, Échiquier) : la page le dit, les talents n'y
  comptent toujours pas (`Modes.sealed()`, lot H2, inchangé).
- **Titres** (lot GX-5, étude BM-GEAR Q9) : une section de l'écran Héros (entre Apparence et Cartes) : le titre porté sous le
  nom du héros (en-tête de Héros, badge du lobby), « N'en porter aucun », tous les titres du jeu rangés par source (niveau de
  héros, succès, Survie, Donjons, Tour, Ruée, Siège, Duel et Arènes, Panthéon, Quêtes, Survivant, Battle royale, Échiquier) avec la
  phrase qui dit comment l'obtenir, filtres Obtenus / À obtenir et recherche (`core/titles.gd`, `ui/titles_page.gd`). Un titre ne
  donne aucune stat. Le Carnet > Succès garde sa rangée de titres.
- **Apparence** : « Débloqués uniquement » activé par défaut (compteur « 1 / 122 », « 121 à découvrir »).
- Plus aucune mention du jeu d'origine (« Eden Eternal : … » sur sorts et talents, niveaux d'Eden) ; la
  description d'un sort n'est plus répétée sous « Effets » ; LB / RB changent de section ; « ? » ouvre le Guide
  (Détails) : plus de page d'aide à part dans l'écran Héros.

### Création de personnage (lot C1, `core/hero_look.gd`, `ui/hero_creator.gd`)

- **Nom du héros** (`Profile.hero_name`) : 3 à 16 signes, lettres (accents compris), chiffres, espace, tiret, au moins une lettre,
  filtre de mots grossiers (mots entiers pour les plus courts : « Conan » passe), « Au hasard » propose un nom. Affiché : badge du
  lobby (avec le titre porté), titre de l'écran Héros, bilans (« Nom · Classe »), Ligue, plaques et file du Duel / des Arènes,
  fil de la Battle royale, résumé de la sauvegarde à l'écran titre. Les adversaires gardent le nom de leur classe.
- **Visage** (`Profile.hero_look`, vaut pour toutes les classes ; vide = celui de la classe) : 6 coiffures (variante grise de
  chaque coiffure, teinte), 12 couleurs de cheveux, 8 couleurs d'yeux (masque des iris, shader `use_eye`) ; « Aléatoire »,
  « Réinitialiser ». Une coiffure choisie avec la couleur « D'origine » garde la couleur de la classe (ou la plus proche).
  Les apparences débloquées (tenue, tête, dos, auras) restent réglées par classe dans Héros > Apparence : elles se portent
  avec le visage choisi. Pas de couleur de peau, de corps féminin ni d'autre visage : il n'existe qu'un corps et qu'un visage.
- **Quand** : une fois après l'accueil (compte neuf, juste après le choix de la classe, avant l'échauffement) ; une fois pour
  un ancien compte, pré-rempli, « Garder tel quel » ; ensuite Héros > « Personnage » (hors run), gratuit, petite confirmation.

### Équipement des 60 classes (lot E3 de la nuit du 15/10, `core/class_gear.gd`)

- **7 profils de stats** (`data/class_profiles.json`, généré par `tools/gen_class_profiles.py`, à relancer si une classe
  change) : type de dégâts réel (après `GameData._balance_damage_types`), défense de base 6 = classe de garde, sinon
  l'attribut de croissance le plus fort parmi ceux qui font ses dégâts. Puissance (force, 4 classes), Vivacité (agilité,
  9), Précision (chance, 9), Rempart (garde physique, 10), Croisé (garde magique, 4), Arcane (intelligence, 15), Esprit
  (sagesse, 9). Poids par stat de 0,3 à 1,5 ; type d'armure préféré (tissu / cuir / plates) = +0,5 de note.
- `Items.rating(pièce, profil)` : la note pondérée ne sert qu'aux choix automatiques ; **la PE affichée et les seuils
  d'activité restent la note commune** (sans profil, rien ne change).
- **Équiper le meilleur** (Héros > Équipement > Gérer, hors run) : pour chaque emplacement du préréglage actif, la pièce
  du coffre commun de plus grande valeur pour le profil (arme principale du type de la classe, arme secondaire libre),
  puis les panoplies essayées par paliers (2 / 4 / 6) et des échanges pièce par pièce. **Garder mes choix** : les pièces
  posées à la main (ni de départ, ni posées par le dernier « Équiper le meilleur ») restent.
- **Appliquer à la famille** : le préréglage actif copié dans le préréglage actif des classes du même profil ; chacune
  prend sa meilleure arme de son type, une classe sans arme de son type au coffre est sautée.
- La dernière de ces actions s'**annule** (« Annuler : … » dans Gérer) : rien n'écrase un préréglage sans retour.
- **Registre de l'équipement** (Carnet, dernier onglet) : par classe, PE du préréglage actif face à la PE attendue au
  meilleur niveau atteint, arme du bon type, pièces (celles de départ = « base », elles ne comptent pas), panoplie de
  donjon x / 6, Esprits x / 6, pièces à +10, gemmes, enchantements ; état (À commencer, À compléter, À renforcer,
  Équipée = 9 vraies pièces et PE ≥ 70 % de l'attendue, Optimale = panoplie 6, tout à +10, serti, enchanté) et une ligne
  « Il manque : … → activité » (arme / pièces / niveau → Survie puis Armurerie, panoplie → Donjons ou Panthéon, +10 →
  Forge, gemmes → la Tour, enchantements → le Siège). Moins équipées d'abord. Lobby : « N / 60 classes équipées » dans le pied
  de page (un clic ouvre le Registre). **Registre v2** (lot GX-5) : un clic sur une classe déplie sa fiche : son profil de
  stats (« Rempart · armure de plates · dégâts physiques » et les 5 stats qui comptent le plus, ★ dès un poids de 1,2,
  `ClassGear.top_stats`), **tout ce qui lui manque** dans l'ordre conseillé avec l'activité de chaque manque (`ClassGear.missing`),
  la **comparaison avec ses classes voisines** (celles de son arbre de déblocage, puis celles de son profil : PE, pièces, +10,
  gemmes, état ; « Le Paladin a 2 400 PE de plus, même profil : ses pièces t'iraient », `ClassGear.neighbours` / `compare_line`)
  et « Voir l'équipement ».

## Niveau de héros (lot H1, 0.1.230 ; conception `conception/progression/NIVEAU_HEROS.md`)

Un niveau **du compte**, de 1 à 90, partagé par les 60 classes ; il ne redescend jamais (`core/hero_level.gd`, `HeroLevel`).
- **Courbe** : passer du niveau L à L+1 demande `NEED_BASE` × `NEED_GROWTH`^L = 105 × 1,035^L XP (148 au niveau 10, 461 au 43,
  2 243 au 89 ; 63 229 pour le 90). État : `Profile.records["hero_xp"]` (XP totale, le niveau en est calculé).
- **Gain** : au kill, seulement en Survie, Donjons, Tour, Ruée et Siège (`HeroLevel.MODES` / `ACTS`) ; jamais en Survivant,
  Battle royale, Duel (toutes formes), entraînement, Défi du jour. Un monstre ordinaire vaut 1, une élite 4, un boss 8, × l'écart
  de niveau clamp(1,1^(niveau du monstre − niveau du héros), 0,1, 3) : 10 niveaux au-dessus ×2,6, 10 en dessous ×0,39. Seuls
  comptent les monstres abattus par le camp du héros. L'XP de la partie est **versée au bilan** (`Quests.end_run` →
  `HeroLevel.settle`), +20 % si la partie est gagnée ; une partie quittée sans bilan ne donne rien.
- **Affichage** : badge de classe du lobby (« Héros niv. 34 » + barre fine), en-tête de l'écran Héros (« Niv. 34 »), détail en
  infobulle ; bilan, bloc Gagné : « Niveau de héros 34 → 35 · +1 niveau » (ou « XP de héros · +N ») et l'annonce « Ton héros
  passe au niveau 35. ».
- **Jalons** (lot GX-5, étude BM-GEAR P1) : niveaux 10, 25, 50, 75 et 90, chacun un **titre et des coffres d'apparence, rien
  d'autre** (aucune stat, aucune ressource de puissance) : 10 « Aventurier » + coffre d'apparence rare, 25 « Baroudeur » + coffre
  d'aura rare, 50 « Héros aguerri » + coffre d'apparence mythique, 75 « Héros de renom » + coffre d'apparence légendaire, 90
  « Héros sans égal » + coffres d'apparence et d'aura légendaires (`HeroLevel.MILESTONES`, donnés une fois au passage du niveau,
  `records.hero_miles`, coffres au menu Coffres). La jauge de l'écran Héros montre le prochain (« ★ 75 », détail en infobulle) ;
  le Journal a un onglet « Niveau de héros » (les 5 jalons, obtenus ou « encore N niveaux ») ; le bilan dit « Jalon du niveau 25 :
  … » ; un compte déjà haut reçoit les siens au menu principal (une carte, une fois).
- **Comptes d'avant** (migration une fois, idempotente) : niveau de départ = max(barème des époques gagnées : aucune → meilleur
  niveau de run plafonné à 35, I → 43, II → 60, III → 75, IV → 85 + 1 par rang héroïque fini ; 90 avec un donjon Mythique fini ;
  niveau de la plus haute pièce portée dans le préréglage actif de chaque classe, pièces de départ exclues). Aucune pièce n'est
  déséquipée. Une carte au lobby, une fois : « Ton héros est niveau N. Il garde ce niveau dans toutes les classes. »
- **Port des pièces** (lot H3) : une pièce de niveau N ne s'équipe que si le niveau de héros ≥ N (`Items.required_level` = niveau
  affiché ; `HeroLevel.wear_block`). Vérifié au hub, d'où vient l'équipement de l'Aventure, des Donjons, de la Tour, de la Ruée,
  du Siège et du Duel équipé / Arènes / Gantelet : `Profile.equip` / `equip_offhand` refusent, « Équiper le meilleur » et l'arme
  par défaut ne prennent que des pièces portables, « Appliquer à la famille » ne copie pas une pièce trop haute (la classe garde
  la sienne). Jamais bloquées : pièces de départ, pièces du Survivant et du Battle royale, trophées. Depuis le lot H4a le port se
  vérifie aussi pendant la partie : les coffres de l'Aventure ne donnent jamais de pièce au-dessus du niveau de héros (voir
  « Aventure au niveau de héros »). Duel à l'arme, Ligue, Panthéon : inchangés.
  - Refus : « Niveau 60 requis · tu es niveau 34 » (bouton de la fiche, message de l'inventaire, carte de l'objet) ; case d'objet
    à fond rouge sombre, icône éteinte, niveau requis en rouge (inventaire, poupée, Fabriquer, coffres).
  - Pièce déjà portée au-dessus du niveau (compte d'avant) : **reste portée**, signalée (« Déjà portée : elle reste »), comptée au
    Registre ; la retirer demande une confirmation (« Tu ne pourras la remettre qu'au niveau 60. »).
  - Fabriquer : permis au-dessus du niveau (préparer la suite), « À porter au niveau 53 · tu es niveau 34 » ; filtre « Portables ».
- **Aventure** (lot H4a) : le héros s'y bat à son niveau de héros, les cartes ont des bandes de niveau (voir « Aventure au niveau
  de héros », partie B). Talents et certificats restent à la maîtrise de la classe.
- **Activités** (lot H5, `R_H56.md`) : Donjons, Tour, Ruée et Siège gardent leur niveau (monstres, boss, butin, PE requise) ; le
  héros s'y bat au niveau de l'activité s'il l'a atteint, sinon à son niveau de héros (`HeroLevel.combat_level` : jamais remonté,
  jamais ramené plus bas ; au-delà de 90, la Tour garde son niveau pour un héros 90). La page dit « Niveau 46 · ton héros est
  niveau 38 : il s'y bat à son niveau » (`DifficultyPanel`), la Tour l'annonce au départ ; leurs trouvailles en partie suivent ce
  niveau de combat (`Items.generate`). Héros au niveau de l'activité : rien ne change.
- **Rythme de l'équipement** (lot H56) : les coffres de forge tombés en Survie donnent 1 cristal de plus par 3 niveaux au-dessus
  du niveau 50 (`Rewards.forge_crystals` : 17-18 au niveau 90 au lieu de 4-5 ; coffres des activités inchangés) et les verrous
  Héroïque / Mythique passent à 3,4 / 2,9 (PE conseillée inchangée) : équipement 80-90 correct vers 32-36 h (voir `R_H56.md`).
- **Bilan de la Survie** (lot H6) : « Ce qui t'a battu » après une défaite (`HitLog`, comme les Donjons et le Survivant) ; succès
  « Aguerri », « Légende vivante » et « Héros accompli » aux niveaux de héros 25 / 50 / 90 ; fiche « Deux niveaux » (Guide >
  Équipement) ; la boussole nomme la carte où trouver une pièce portable (« → Survie, carte II-2 »).
- **Modes scellés** (lot H2, `Modes.sealed()`) : en **Survivant** et en **Battle royale**, le héros ne joue qu'avec sa partie
  (niveau, cartes et pièces de la run). Rien du compte ne s'applique en combat : ni talents (stats et sorts), ni certificats
  (plateau et ses liens, insensibilité aux renversements, cartes de certificat), ni archive, ni aura ; tout le kit de la classe et
  toutes les cartes communes sont proposés, sans la maîtrise ni les déblocages du compte. Restent permis : classes et apparences
  débloquées ; les gains de fin (maîtrise, insignes plafonnés du Battle royale) sont gardés. Mesure (`hl_probe --sealed`, kit
  2.3.5.3 au niveau 60, compte opti / compte neuf) : Battle royale ×2,19-2,64 avant, ×1,00 après ; Aventure ×2,39-2,99. Duel
  équipé, Arènes et Gantelet gardent talents et certificats ; Duel à l'arme, Ligue et Panthéon inchangés (règle JcJ : lot H5).

## Grimoire et infobulles

- **Grimoire** (lobby et menu pause) : par classe, statistiques de base, passifs, combo coup par
  coup, 9 compétences avec infobulle détaillée générée depuis les vraies valeurs (type de dégâts
  physique / magique, % de l'attaque et valeur chiffrée, bonus de critique, cibles, effets et
  durées, combos d'états) et tableau des rangs 1 → 5 (+20 % de dégâts, -8 % de recharge par rang).
- **Cartes d'objet** : icône d'Eden, nom à la couleur de la rareté, qualité, stats du type de base
  avec le bonus (qualité, amélioration) entre parenthèses, affixes en bleu, bonus de set.

## Auto-attaque des armes (refonte 0.1.127, demande du joueur du 14/10/2026)

- **Plus de combo** (ni coup final, saut, étourdissement ou attraction) : chaque type d'arme a
  **une seule auto-attaque**, répétée, volontairement **faible en début de run**. Sa force vient
  des **cartes** : chaque arme a une forme qui réagit à certaines statistiques (« Grandit avec »
  dans le grimoire). Catalogue : `scripts/combat/weapon_attacks.gd` (`WeaponAttacks.SPECS`).
- Formes : **taille** en arc (katana, hache, épée, espadon, faux, cestes, dagues), **estoc** en
  ligne (rapière, lance : longueur × portée), **impact** au sol (marteau), **onde** autour du
  héros (guitare), **projectiles** (arc, dagues de lancer, baguette, canon, grimoire, boule de
  feu) et **incantation** (sceptre, bâton : zone au point visé après un délai réglé par la
  **vitesse d'incantation**).
- Cartes : **Projectile supplémentaire** (+1 flèche à l'arc, +1 zone à l'incantation, +1 frappe
  pour la mêlée), **Perforation**, **Ricochet** (rebond vers un ennemi à 8 m), **Cadence**
  (vitesse d'attaque), **Incantation vive** (vitesse d'incantation), **Main lourde** (dégâts de
  l'auto-attaque), Lame large (zone), Allonge (portée), **Onde de choc** (chance à l'impact),
  évolution **Tempête d'acier** (Main lourde + Projectile supplémentaire). Les effets « coup final »
  des sets et trophées passent sur « impact d'une auto-attaque » (avec une chance).
- **Deux variantes par arme** (0.1.128), aux synergies différentes : katana Iaï (critique) /
  Lame du vent (projectile perçant) ; hache Taille large / Hache de jet (rebonds, saignement) ;
  dagues Lacération / Dagues de lancer ; arc Flèche / Pluie de flèches (zones) ; sceptre Éclat
  sacré / Orbe de lumière (rebonds, soin) ; bâton Météore / Boule de feu ; épée Taille /
  Tourbillon ; rapière Estoc / Rafale d'estocs (3 frappes) ; espadon Taille lourde / Onde
  tranchante (traverse tout) ; marteau Impact / Onde sismique ; baguette Trait d'ombre /
  Malédiction (poison) ; cestes Directs / Poing de chi ; canon Obus / Mitraille (4 plombs) ;
  lance Estoc / Lance de jet ; guitare Onde sonore / Notes vagabondes ; grimoire Pages / Glyphe
  (ralentit) ; faux Faux / Salve. L'arme (son modèle d'Eden) décide de la variante. Le choix entre les deux
  variantes au départ de la Survie n'existe plus depuis 0.1.170 (on part avec l'arme du hub) ; `RunDirector.start_weapon_cards`
  ne sert plus qu'au Battle royale.
- **Arme principale = arme de la classe**, toujours (la case n'accepte que ce type). Une arme
  d'un autre type ne peut être que l'**arme secondaire**.
- **Deux armes, « Changer d'arme » (passe N2, 0.1.229, tous les modes)** : l'arme secondaire **ne frappe jamais seule**
  et ne donne **aucune stat** au héros. L'action « Changer d'arme » (clavier : la touche sous la main gauche, W en AZERTY,
  Z en QWERTY ; manette : R3 ; réassignables, `Settings` `swap_weapon`) la **met en main** instantanément, en plein combat,
  puis remet l'arme principale. En main, la secondaire donne **son type d'auto-attaque** (sa variante, ses améliorations de
  run « offhand », son modèle) et **ses attaques physique / magique, pour les auto-attaques seulement** (`Player.basic_atk`) ;
  les **compétences gardent toujours les stats de l'arme principale** (celle de la classe) : elles ne lisent jamais la
  secondaire. Les panoplies et passifs d'objet comptent l'arme principale, quelle que soit l'arme en main. Recharge
  `WeaponAttacks.SWAP_CD` 1 s (`SWAP_CD_PVP` 4 s entre héros : Duel, Arènes, Battle royale), pas d'auto-attaque pendant
  `SWAP_LOCK` 0,35 s, l'auto-attaque en cours s'arrête ; impossible pendant un sort ou étourdi. Sans arme secondaire (Duel à
  l'arme, Survivant, Battle royale pour l'instant) l'action ne fait rien et la case du HUD est cachée. Le pilote automatique
  et les héros ennemis ne changent jamais d'arme. En Survie, l'arme secondaire se **trouve en jeu** : le boss en
  lâche toujours une, une élite parfois (40 % sans arme secondaire, 12 % avec) ; ramassée, elle
  propose 3 armes d'autres types (variante au hasard, une relance) qui vont **dans le sac** (voir « Coffres d'emplacement »).
  Les coffres d'arme ne donnent que l'arme de la classe. HUD : petite case ronde au-dessus de l'esquive (arme rangée,
  touche, recharge).
- **Améliorations d'arme** (cartes de niveau « weapon_up », 8 niveaux par emplacement, l'arme
  principale souvent, la secondaire si elle est portée) : **commune** = dégâts (+15 %) ; **rare** =
  dégâts + un bonus mineur (critique +5 %, cadence +8 %, zone +10 %, portée +12 %, durée des
  effets +1 s, soin, délai d'incantation -12 % ; chaque arme a ses bonus de prédilection, le
  critique pour l'arc) ; **épique** = + un bonus majeur (+1 projectile ou frappe, +1 perforation,
  +1 rebond, +25 % de zone, explosion plus large) ; **légendaire** = + l'**effet légendaire** de la
  variante (« tous les N coups » renforcé, état infligé à chaque coup, explosion ou foudre à
  l'impact), puis deux bonus mineurs et un majeur. Les améliorations restent sur l'emplacement
  quand l'arme change (`Run.weapon_ups`).
- **Trophées** (0.1.130, demande du joueur) : ils ne sont **plus de l'équipement** (ni case, ni
  trophée de départ, ni butin, coffres de récompense ou marchand). C'est une **collection de la
  run** (`Run.trophies`) : jusqu'à **12 trophées, tous d'effets différents, tous actifs**, perdus
  en fin de run. **67 effets** (`Trophies.KINDS`), chacun porté par 5 trophées d'Eden ou plus
  (`tools/rework_trophies.py`) ; un coffre de trophée propose 3 effets que la collection n'a pas
  encore, chacun avec le trophée d'Eden du niveau le plus proche de la map (variantes de niveau :
  `Trophies.level_mult`, plus forts aux dernières époques). Sources : 4 coffres de trophée par map
  en Survie, sanctuaires des trophées ; collection pleine : des cartes à la place. Effet unique :
  pas d'amélioration (`Items.is_unique`). Menu pause, page Run : la collection.
- Duel : l'auto-attaque entre héros garde × `PvpCaps.BASIC_MULT`. L'adversaire scripté répète
  l'auto-attaque de son arme (pause plus longue tous les 3 coups).

## Effets déclenchés (procs)

Un proc = déclencheur + chance + recharge interne + effet (`scripts/combat/procs.gd`).
- Déclencheurs : impact, impact d'une compétence, critique, monstre tué, impact d'une auto-attaque,
  esquive, annulation parfaite, dégâts subis, passage sous 30 % de PV.
- Effets : foudre en chaîne, gel (immobilise, annule l'attaque annoncée ; le boss résiste),
  ralenti, brûlure, électrocution (+15 % de dégâts subis), explosion, nova de givre, buffs
  temporaires (Frénésie, Œil acéré, Hâte, Barrière, Fureur), soin, recharges réduites, Écho.
- Réactions en chaîne limitées à 2 niveaux (une explosion qui tue peut en déclencher une autre).

## Maniabilité (hard to master)

- Saut **nerveux** par défaut : ~2 m, 0,5 s en l'air, chute plus rapide que la montée.
  Relâcher Espace tôt = petit saut (~1,2 m). Saut encore possible juste après un rebord,
  et un saut demandé juste avant l'atterrissage part tout seul.
- Saut et esquive s'enchaînent **sans délai** :
  - esquive → saut : garde l'élan (saut-esquive ~12 m) ;
  - saut → **esquive aérienne** (une par saut, invulnérable, à l'horizontale) ;
  - saut et esquive annulent l'attaque de base à tout moment, une compétence après son 1er impact.
- Recharge de l'esquive au sol : 0,45 s (l'esquive aérienne n'en a pas).
- **Compétences en l'air** : le héros reste suspendu pendant le sort (+10 % de dégâts).
  Esquive → sort possible dès la moitié de l'esquive.
- **Annulation parfaite** : esquiver dans les 0,28 s après l'impact d'une compétence →
  « PARFAIT ! », esquive plus longue et gratuite (même en l'air), images rémanentes,
  -25 % sur la recharge restante, et **Fluidité** +10 % de dégâts par palier (4 max, 3 s).
  Enchaînement type : saut → sort → esquive parfaite → sort…
  Esquiver avant l'impact annule la compétence, dont la recharge est rendue (« Sort rendu »).
  Un anneau bleu bref annonce le moment à chaque impact de sort (jamais en Duel).
- **Mémoire des touches** (0.1.133, joueur seulement, `Player._queue_*`) : jusqu'à 3 appuis de sorts
  gardés et joués dans l'ordre ; plus de « Trop tôt » ; l'enchaînement part dès que la barre est
  ouverte et que le dernier coup du sort en cours est porté ; un appui qui n'a pas pu partir s'efface
  après 1,2 s ; un sort en recharge n'est gardé que s'il lui reste 0,3 s au plus ; esquive, saut et
  étourdissement vident la file. Tenir la touche d'une case enchaîne toute la chaîne. Une zone au sol
  visée à moins de 3 m d'un monstre se pose sur lui.
- **Aide au combat** (0.1.134, `Settings.ASSIST`) : Manuel, Assisté (défaut : mémoire, maintien,
  anneau), Détente (attaque, sorts et enchaînements automatiques), Bot (+ déplacement et cartes ; depuis
  0.1.193 aussi l'équipement, l'arme secondaire, l'enclume et les trophées : `CardPicker.auto_pick`, meilleure rareté puis
  note pondérée par le profil de la classe). Un choix de carte ouvert tient la pause, même au bout d'un fondu (arène du boss).
  L'automatique ne fait plus d'annulation parfaite : c'est le geste du joueur. Étiquette au HUD,
  ligne au bilan ; coupée dans les duels de la Tour et en Duel.

## Saut, une mécanique de build

Passifs (cartes de niveau) : **Saut aérien** (+1 saut en l'air, ×2), **Bond puissant**
(+20 % de hauteur, ×2), **Frappe plongeante** (attaquer en l'air → plongeon : dégâts de zone
+ étourdissement, ×3), **Apesanteur** (saut flottant : -25 % de gravité, ×2 ; pour les builds
aériens / mages), **Pas aérien** (+1 esquive en l'air, ×2).

## Impact visuel

Arcs de lame épais et lumineux (cœur blanc, bloom), ondes de choc au sol avec poussière,
éclairs d'impact sur les coups de compétence et les critiques, effets d'Eden 1,5× plus opaques.
Salto du Samouraï : bond de ~4 m avec rotation complète, onde de choc à la retombée.
Toupie du Guerrier : 3 tours réels du modèle, un coup par tour, annulable par esquive ou saut.

## Cartes de build (roguelite)

- En plus des passifs de classe, des cartes communes à toutes les classes (`scripts/core/boons.gd`)
  avec une **rareté** (commune, rare, épique, légendaire) qui règle leur fréquence et leur couleur.
- Stats de build : zone d'effet, portée, dégâts, dégâts contre élites, coup final, effets sur la
  durée, exécution des monstres faibles, relances.
- **Évolutions** (légendaires) : n'apparaissent qu'avec leurs cartes prérequises
  (Lame statique → Seigneur de la tempête, Fil de givre → Éclat glacial, Braise + Cadavres
  explosifs → Lame du phénix, Coup de grâce → Tempête d'acier).
- **Relance** des cartes proposées : 1 par run, +1 par carte « Bonne étoile ».
- Pistes suivantes : bannir une carte, cartes « malédiction » à fort bonus, reliques d'élite,
  projectiles (lames fantômes), invocations, synergies entre classes.

## Cartes de build (0.1.30)

- Chaque carte proposée a une **rareté tirée** (commune ×1, rare ×1,5, épique ×2,2,
  légendaire ×3, poids 60 / 27 / 10 / 3) qui multiplie ce qu'elle apporte ; un passif se
  prend jusqu'à **10 fois** ; la carte affiche le total avant → après.
- **Améliorations de sort** : dégâts (sorts d'attaque), soins (sorts de soin) ou durée des
  effets (buffs), moins de recharge, et à partir de rare un bonus d'attribut au lancement.
- **Orbes d'expérience** : l'expérience tombe sous le monstre ; zone de collecte (carte
  Aimant), Rappel (tout revient), Érudit (+XP), Venin tenace (effets sur la durée).
- Tout se règle dans le mode dev, page **Cartes** (Cards, Boons, DevCards ;
  data/dev_edits.json -> cards, card_rules).

# Partie B — La Survie (mode principal)

## Boucle de jeu et Survie (refonte 0.1.123, décisions du joueur du 14/10/2026)

**Ce qui se débloque avec le temps (méta)** : les classes suivantes, les sorts des classes, les
certificats et passifs, les points de maîtrise (maîtrise de classe, déjà en place) ; les
cosmétiques ; l'équipement **pour la collection et le JcJ non normalisé** (achat au hub).

**En Survie, on part avec l'équipement du hub (0.1.170, lot N1 ; numéroté « 0.1.164 » dans les rapports, numéro jamais publié ; décision du joueur du 15/10 : elle remplace celle de
0.1.123 « on part sans équipement »)** : le préréglage actif de la classe (pièces, +N, gemmes, enchantements,
panoplies, arme secondaire) est porté dès la première seconde ; toute l'optimisation (Armurerie, Atelier :
forge, gemmes, enchantements) sert donc la Survie et la progression entre les runs est réelle. La run travaille
sur des **copies** : les trouvailles des coffres d'emplacement remplacent un emplacement le temps de la run
seulement, et à la fin (victoire, défaite, abandon, extraction) ou à la reprise après une fermeture du jeu en
pleine run, le hub retrouve exactement son équipement d'avant (`Profile.begin_run` prend un instantané,
`Profile.end_run_survival` le restaure si quelque chose a bougé). Les pièces choisies en coffre restent
achetables à l'Armurerie. **Compte neuf** : `StarterGear` donne à chaque classe, une fois, 8 pièces d'Eden
communes, spéciales ou rares (la plus rare possible) du palier 10-30, le plus proche de 20 (arme du type de la classe, tête, torse,
jambes, gants, bottes, bague, collier), à +0 : le hub n'est jamais vide. **Boucle d'amorçage** : 25 insignes de participation par
run (dès 10 monstres tués) + 25 pour la 1re carte, 35 par carte suivante et 15 par boss de carte (lot A5), de quoi acheter une pièce de l'époque I (50 à 73) en 1 ou 2 runs, même perdues
(passe E6 : sur la 1re carte, ces 50 sont au prorata des 10 minutes avant la rage, voir « Équilibrage global ») ;
les premiers niveaux de chaque run montent plus vite (XP ×2 au niveau 1, ×1 au niveau 10) et le début de chaque carte est plus doux
(monstres à 45 % puis 100 % sur 5 min). Mesures et plafonds : `conception/nuit_15_10/N1_survie_equipement.md`.

**Époques** : une run = 3 maps d'une même époque ; l'époque change les pièces d'Eden proposées (modèles, panoplies,
raretés) et la difficulté des monstres. Battre le boss final d'une époque débloque la suivante. Depuis le lot H4a, plus de
puissance normalisée ni de plafond 15 / 25 / 35 : voir « Aventure au niveau de héros » ci-dessous. **Ce qui compte dans une
pièce** : son niveau (×1,08 par niveau, jusqu'à 90), sa rareté (×0,85 commune à ×1,32 légendaire sur les stats de base), son jet de qualité, son
+N du hub (+10 % des stats de base par niveau, ×2 à +10), ses gemmes (valeurs plates suivant le niveau du héros comme
les pièces : × 0,09 × 1,08^(niveau − 1), passe E6), son enchantement, son passif d'arme et les bonus de panoplie (2 / 4 / 6 pièces).

### Aventure au niveau de héros (lot H4a, conception `conception/progression/NIVEAU_HEROS.md` §1.4, rapport `R_H4a.md`)

- **Deux niveaux** : le héros se bat à son **niveau de héros** (compte, 1 à 90 ; fixé au départ de la partie, `Run.hero_level` :
  stats de base, puissance des pièces à leur niveau, gemmes) ; le **niveau de run** (`Player.level`, repart de 1, sans plafond
  par carte) ne donne que des cartes (HUD : orbe « RUN » ; or et prix de la partie le suivent comme avant). Un monstre rapporte
  au niveau de run ce que vaut un monstre de ce niveau de run (élite ×4, boss ×8), quel que soit son niveau de carte.
- **Bandes de niveau** (`Epochs.BANDS`) : monstres au niveau de héros (−1 au début de la carte, −0,5 à la rage) borné par la
  bande de la carte, + palier du camp, +3 en rage ; boss = niveau de la carte pour le héros + 1. Un héros sous la bande affronte
  le bas de la bande ; au-dessus, il écrase la carte (pas de synchronisation en Aventure).

  | Carte | I-1 | I-2 | I-3 | II-1 | II-2 | II-3 | III-1 | III-2 | III-3 | IV-1 | IV-2 | IV-3 |
  |---|---|---|---|---|---|---|---|---|---|---|---|---|
  | Bande | 1-23 | 18-33 | 28-43 | 38-48 | 43-53 | 48-60 | 55-65 | 60-70 | 65-75 | 70-80 | 75-85 | 80-90 |

- **Force des monstres** : PV × `Epochs.MAP_MULT` de la carte (M′, remplace l'ancien multiplicateur par époque), dégâts ×
  `MAP_ATK` (monstres) ou `BOSS_ATK` (boss), × montée dans le temps de la carte (`Epochs.TIME_RAMP` 2 % par minute, au plus
  `TIME_RAMP_MAX` ; pas pour le boss). Défense des monstres plafonnée à celle du niveau `DEF_LEVEL` (18 / 28 / 38) : au-delà, ×1,1
  par niveau annulait les coups du héros. Les dégâts sur la durée (zones, poisons) ne passent pas par la défense du héros : à haut
  niveau ils dominent, d'où `BOSS_ATK` bas aux époques III-IV. Miroir du boss : un coup renvoyé retire au plus 12 % des PV max du
  héros (`Monster.REFLECT_CAP` ; au niveau 90 un coup du héros vaut plusieurs fois ses PV). Valeurs et mesures : `R_H4a.md`. `Epochs.OLD_CAPS` / `OLD_MONSTER_MULT` (modèle
  d'avant) restent pour les outils seulement.
- **Boss** : PV fixes (voir « Boss : PV fixes ») au niveau du boss : `Epochs.boss_hp(époque, carte, niveau)` = PV de référence
  (`BOSS_HP_MAP` × `BOSS_HP_EPOCH` × `BOSS_HP_ADJ` × M′ / ancien multiplicateur) × 1,1^(niveau − plafond d'avant − 1). Un compte
  neuf (niveau 1) trouve sur I-1 un boss de niveau 2.
- **Équilibre mesuré** (lot H4b, `R_H4b.md`) : à la sensation d'un joueur (aide « Bot » du jeu, coups évités 0,5 ; sonde
  `tools/boss_ttk.py` et parties entières `tools/sim_survie.py --bot`), un héros au haut de la bande avec les pièces de la carte à
  +5 bat le boss 60 à 75 % du temps ; 10 niveaux d'avance : 80-100 % ; 10 niveaux de retard d'équipement : 40-55 % à l'époque I (les
  stats du héros y pèsent plus que les pièces), ≈ 25 % à l'époque II, 0-20 % aux époques III-IV. Compte neuf sur I-1 : 55 % pour un
  débutant, 75 % pour un bon joueur (boss d'I-1 : PV et dégâts ×1,5 sur ses monstres). Leviers par carte : `BOSS_HP_ADJ` (PV du boss)
  et `BOSS_ATK` (ses dégâts), `MAP_ATK` (monstres et renforts). Le simulateur de progression lit son propre M′ (`HERO_GAME_MULT`,
  recalé sur ces chances), jamais `Epochs.MAP_MULT`.
- **Coffres de la partie** : une pièce n'est **jamais au-dessus du niveau de héros** (`SlotChests.run_piece`) : sous le palier de
  la carte, la pièce du palier est ramenée au niveau du héros (même modèle, « niveau 12 · mythique » au titre du coffre ; la
  vraie pièce reste à l'Armurerie à son niveau). Le port se vérifie donc aussi en partie (`HeroLevel.wear_block`). Butin des
  autels et coffres de récompense : au plus le niveau de la carte pour le héros (`RunDirector.loot_level`) ; rang des gemmes :
  l'échelle d'avant (`Epochs.GEM_SCALE`, selon la place du héros dans la bande).
- **Page de la Survie** : sous l'époque choisie, ses trois cartes avec leur bande (« Niv. 18-33 ») et la **PE conseillée** pour
  le héros (`Epochs.advised_power` : la PE des pièces de la carte à +5 au niveau de la carte, l'équipement de départ pour I-1),
  colorée selon la PE du héros (estimation de `DifficultyPanel`), détail en infobulle.

| Époque | Maps (zones) | Armures | Armes | Raretés |
|---|---|---|---|---|
| I | Limestone, Rainbowfall, Beluga | 23, 33, 43 | 20, 30, 40 | mythique |
| II | Wetlands, Avila, Arid | 48, 53, 60 | 45, 50, 60 | mythique, mythique, légendaire |
| III | Delphi, Blackflame, Wetlands | 65, 70, 70 | 65, 70, 75 | légendaire, légendaire, éveillé |
| IV | Avila, Arid, Blackflame | 80, 85, 80 | 80, 85, 90 | légendaire, légendaire, éveillé |

Mythique = orange, légendaire = jaune, éveillé = jaune avec une aura sur l'icône (pièces
« Awaken » d'Eden, niveaux 70 et 80).

**Coffres d'emplacement** (les 30 coffres payants de la map) : arme, tête, torse, jambes, gants,
bottes, cape (2 coffres depuis 0.1.179, pris aux gants et aux bottes : les 9 emplacements de la PE se trouvent tous
en Survie ; une cape pèse ≈ 1/9 de la PE), bijoux (bague, collier, boucles), trophée, carte de sort, carte de passif, carte de
certificat. Un coffre d'équipement propose **3 pièces au hasard** parmi toutes les pièces de son
emplacement au palier et à la rareté de la map (au palier 23 : 6 panoplies), avec **une relance
par coffre**. Le coffre d'arme propose l'arme principale, toujours du type de la classe (`SlotChests.offer`, `Profile.main_weapon_type`) ;
les autres types viennent en arme secondaire (voir « Auto-attaque des armes »).
**Une arme trouvée va dans le sac de la run** (passe N2 : coffre d'arme et arme secondaire, jamais équipée d'office) ;
le HUD l'annonce 8 s et [G] « Équiper la trouvaille » la porte (principale si elle est du type de la classe, sinon
secondaire), sinon menu pause > Héros (comparaison ▲ / ▼ avec l'arme du même rôle). Comme toute trouvaille, elle
n'est pas gardée en fin de run (achetable à l'Armurerie). Sac plein : l'arme est perdue. Les pièces d'armure
restent portées tout de suite.
Départ : l'arme du hub (plus de choix d'arme au départ depuis 0.1.170). Les monstres ne lâchent plus
d'équipement (or, expérience, fournitures, clés).

**Plus d'enclume en Survie** (passe N2, 0.1.229, demande du joueur : on part avec son équipement et on rentre avec,
l'améliorer en run serait de la triche) : aucune enclume sur les cartes de la Survie (`ProcMap` n'en pose que pour le
Survivant, qui garde la sienne), plus de bonus de +N en run ; le +N est celui que le joueur a monté au hub. Le défi
d'époque IV « Utiliser l'enclume sur les 3 cartes » devient « Ouvrir 45 coffres » (`Epochs.CHEST_CHALLENGE`) ; le défi
de l'époque III devient « Finir sans changer d'arme ». Les cartes d'amélioration d'arme restent plafonnées (niveau 8 par arme, `WeaponAttacks.MAX_RANK`) ;
les cartes de sort ont leur propre plafond de rang ; elles s'ajoutent aux stats de l'équipement sans le remplacer.

**Cartes** : la montée de niveau propose toujours des cartes ; les coffres de cartes (sort,
passif, certificat) permettent de viser un type.

**Hub, collection** : une pièce choisie au moins une fois dans un coffre de Survie devient
achetable au hub (Atelier > Armurerie : collection, JcJ), avec des insignes gagnés en run (`Economy.survival_insignia`).

**Les 17 types d'arme (0.1.179, lot E4)** : l'arme principale est du type de la classe, l'arme secondaire est libre.
Décision : **une arme choisie en Survie** (coffre d'arme ou arme secondaire) fait **découvrir les armes de tous les
types** au palier et à la rareté de la carte (`SlotChests.weapon_family`, `Run.seen_family` → `Profile.seen_gear` en fin
de run). L'Armurerie vend donc l'épée, l'arc, le bâton… de chaque palier vu, quelle que soit la classe jouée : une classe
d'épée peut s'équiper d'une épée trouvée en jouant un Guerrier, et toute classe d'une arme secondaire de n'importe quel type.
Pourquoi : la Survie reste le seul lieu de découverte (rôle unique), aucun nouveau coffre ni nouvelle monnaie, et la quête
« l'arme de chaque type » ne demande pas de jouer une classe de chaque type. Une pièce n'est découverte qu'à 20 niveaux au
plus du palier de la carte (`SlotChests.POOL_WINDOW`) : un type sans pièce proche n'en donne pas (époque I : 15 types sur 17).
Le même écart vaut pour les coffres : plus de légendaire de niveau 1 proposée au palier 60. L'arme secondaire trouvée en jeu
est tirée comme un coffre d'arme de son type.

**Coffre de plans des boss de carte (lot A4 de la refonte Aventure)** : à la mort du boss de chaque carte, après l'amélioration
d'arme, le joueur choisit **1 pièce parmi 3 non découvertes** du palier de la carte (`Run.plan_offer`, `SlotChests.plan_candidates` :
tous les coffres de pièce sauf les trophées, arme du type de la classe ; jamais une pièce déjà dans `Profile.seen_gear`, choisie
dans un coffre de la run ou portée). Pas de relance. Le plan est **acquis tout de suite** (`Profile.seen_gear`, sauvegardé) : gardé
même si la run est perdue ou abandonnée ensuite ; une arme fait aussi découvrir ses sœurs des autres types (lot E4). Palier entièrement
découvert : **30 insignes** à la place (`Run.PLAN_INSIGNIA`, ligne de l'infobulle des insignes). Bilan : « Plan trouvé : <pièce> ».
Pourquoi : une carte gagnée donne au moins un plan, au choix (le joueur vise son manque) ; aucune nouvelle monnaie. Fiche
`boss_plans`. Mesure (`progression_sim --bossplans`) : voir `conception/progression/R_A4.md`.

**Fournitures de la Survie (0.1.179, lot E4)** : les parchemins de fortification, les formules d'enchantement (autel du
scribe, marchands, objets à casser) et les coffres de forge sont au niveau **des pièces de la carte d'époque** (le plus haut
de l'armure et de l'arme : parchemins Lv 30 / 40 / 50 en époque I, 50 / 60 / 60 en II, 70 / 70 / 80 en III, 80 / 90 / 90 en IV ;
formules plafonnées par époque depuis la passe E6 : Lv 2 / 4 / 6 / 7, les Lv 8-9 sont au Siège), et non plus plafonnés au niveau 35 : une pièce de l'Armurerie se monte avec ce
que donne la Survie de son époque. Les **gemmes** (et les coffres du joaillier) gardent le niveau du moment, **plus un rang
par époque** (`RunDirector.GEM_EPOCH_LEVELS`) : rang = niveau / 8, donc des royales dès la fin de la 3e carte de l'époque I et
partout à l'époque IV (mesure E6 ; leur poids en Survie est réglé par `Craft.GEM_RUN_SHARE`, pas par leur rareté). La
difficulté n'en dépend pas : la forge est fermée pendant la Survie, les fournitures ne servent qu'au hub (gardées sur
victoire ou extraction ; les coffres de forge et du joaillier sont toujours gardés).

**Équilibrage global (passe E6, 0.1.182)** — mesures et modèle dans `conception/nuit_15_10/R_E6.md`, simulation
`res://tools/progression_sim.tscn` (compte neuf de bout en bout avec les vraies formules ; `--probe` : puissance des
équipements types ; `--mult=…` : essai d'autres écarts d'époque), bornes vérifiées par `tests/test_e6`.
- **Écart d'époque** (remplacé au lot H4a par `Epochs.MAP_MULT`, une valeur par carte, voir « Aventure au niveau de héros » ;
  `Epochs.OLD_MONSTER_MULT` garde l'ancienne table pour les outils) : **×0,85 / ×1,7 / ×3,4 / ×7** (avant ×1 / 1,35 / 1,75 / 2,2 ;
  époque I adoucie de ×1 à ×0,85 par la passe P5 : un joueur moyen au compte neuf atteint le boss de la carte 1 une run sur deux,
  1re victoire en 5-6 runs).
  En Survie la puissance d'une pièce suit le niveau du héros, mais son +N (×2 à +10), sa rareté, ses gemmes et son
  enchantement multiplient la puissance du héros par ≈ 6 à 7 entre des pièces +0 de l'époque I et un équipement complet
  d'époque IV. Avec l'ancien écart, un compte simulé gagnait l'époque IV ≈ 10 h après son premier lancement. Maintenant :
  II demande les pièces de l'époque I montées (+5, quelques gemmes), III les pièces de l'époque II à +10, IV un
  équipement complet (+10 partout, gemmes, enchantements). Les rangs héroïques s'ajoutent par-dessus (défi de prestige).
- **Gemmes en Survie** : × `Craft.GEM_RUN_SHARE` (0,09) × 1,08^(niveau − 1), comme les pièces : une gemme royale de PV vaut
  ≈ 40 % d'un torse +0 du même niveau (avant : ×1 au niveau 15, deux royales par pièce triplaient la puissance en carte 1).
  Hors Survie (Tour, Donjons, duels) : pleine valeur, inchangé.
- **Insignes d'une run arrêtée sur la 1re carte** : participation et 25 de la 1re carte au prorata des 10 minutes avant la
  rage (`Economy.ENTRY_MINUTES`, temps de jeu lu dans le journal de run). Abandonner au bout d'une minute ne paie plus
  ≈ 2 000 insignes à l'heure (240 maintenant) ; une défaite de débutant de 5 min paie toujours une pièce en 2 runs.
- **Monstres comptés** pour la maîtrise et les insignes : au plus 1 500 par carte atteinte (`Run.KILL_CAP_PER_MAP` ; une
  carte normale en compte 700 à 1 000). Rester en rage sur la 1re carte n'est plus une ferme.
- **Lâchers des monstres ordinaires** en Survie : au plus 6 coffres de récompense et 60 fournitures par carte
  (`RunDirector.FARM_CAP`) ; élites, boss, défis, objets cassés et coffres de la carte ne sont pas plafonnés.
- **Démontage** : une pièce rachetable à l'Armurerie (découverte) ne rend que la part de ses améliorations (+N / 3) ;
  avant, acheter une pièce d'un palier entamé (15 % du prix, 8 insignes au plus bas) puis la démonter (3 cristaux) changeait
  les insignes en cristaux sans limite. Les insignes servent à acquérir, les cristaux à optimiser : aucun pont entre les deux.
- **Formules d'enchantement** en Survie : niveau 2 / 4 / 6 / 7 au plus selon l'époque (`Craft.SURVIVAL_SCROLL_MAX`) ; les
  niveaux 8-9 viennent du Siège (rôle « formules hautes ») et des coffres du joaillier de niveau 70 ou plus.
- Inchangés après vérification : enclume (+12 au plus : une pièce +10 n'y gagne que +2 sur 3 emplacements), capes (≈ 1/9
  de la puissance), cartes d'amélioration (plafonnées), barème d'E5 (la Survie reste la 1re source d'insignes à l'heure,
  le JcJ plafonné au jour), cristaux d'E1 (Donjon Mythique ≈ 1 000 / h, Ruée ≈ 900, Siège ≈ 860).

**Verrous de PE (passe P5, 0.1.184)** — mesures dans `conception/nuit_15_10/R_P5.md`. PE requise = rapport × PE attendue
du niveau de l'activité (`GearPower.required`). La PE réelle d'un compte dépasse vite l'« attendue » (pièces +10, gemmes,
enchantements, panoplies ; simulation, joueur moyen : ≈ 6 000 à l'époque I gagnée, 13 000 à la II, 25-30 000 à la III,
53-55 000 à la IV, 61-64 000 équipement complet) : les anciens rapports (0,55 / 0,8) ouvraient tout le Mythique dès
l'époque II avec un équipement d'époque I à +10.
- **Donjons** (`GearPower.DIFF_RATIO`) : Normal 0, **Héroïque ×3,6** (1re zone ≈ 25 300, s'ouvre vers l'époque III, puis
  zone après zone jusqu'à ≈ 55 000), **Mythique ×3,1** (niveau 90 : 55 800, après l'époque IV, équipement amélioré). La Ruée
  se juge au niveau de son 4e boss (Héroïque ≈ 41 500). Lot A2 : le Normal s'ouvre dès l'époque I gagnée (zone par zone) ;
  Héroïque reste plus loin (un kit de l'époque I à +10 et gemmes ≈ 15 800, sous les 25 300 de la 1re zone). PE **conseillée**
  (`Dungeons.ADVISED` 1,3 / 3,8 / 3,3 × la PE attendue, jamais sous la requise) affichée avec l'estimation (`DifficultyPanel`).
- **Siège** (`Siege.POWER_RATIO`) : Normal 0, Héroïque ×4, Mythique ×3,4 (61 200 : ≈ équipement complet).
- **Butin légendaire des coffres** (`GearPower.LEGEND_RATIO`) : ×1,8 (coffre de niveau 40 : ≈ 16 200, vers l'époque II ;
  niveau 90 : 32 400, vers l'époque III gagnée).
- Pages Donjon, Siège et Ruée : jauge « PE requise · la tienne » sous la difficulté (verte quand elle suffit), le bouton
  fermé dit seulement « Puissance d'équipement insuffisante ».
- Bilan de la Survie : l'infobulle des insignes lit `Run.insignia_parts` (participation au prorata d'une run courte, cartes
  suivantes, monstres et élites plafonnés, victoire, bonus du défi / du rang héroïque, autel) ; les lignes font le total.
- **Tour** : 3 / 4 / 5 / 6 cristaux par étage (avant 1 à 2,5, `ActivityLoot.TOWER_PER_FLOOR`) : ≈ 120 / h en Normal, sous un
  Donjon Normal (30 par donjon de ≈ 6 min, ≈ 200-300 / h) ; depuis le lot A2 les deux s'ouvrent ensemble, à l'époque I gagnée.

## Déroulement d'une run (10 minutes + rage)

| Phase | Ce qui se passe |
|---|---|
| 0:00 → 10:00 | Exploration d'une map générée : farmer, ouvrir les **coffres** (or ou clé), capturer les **sanctuaires**, trouver les **marchands ambulants** et l'**entrée du donjon**. Monstres de la zone, élites ponctuelles (clés). |
| 10:00 → … | **Rage** : monstres plus forts, monstres de niveau supérieur, élites en masse. Plus d'XP et de butin. **Escalade** (passe P9, idée du joueur) : chaque minute de rage, PV et dégâts des monstres de la carte ×1,1 (10:00), ×2 (11:00), ×11 (12:00), puis ×101 (13:00 et après) ; le boss n'est pas concerné (l'arène arrête le chronomètre). Le HUD affiche « RAGE ×2 · 0:42 » (multiplicateur, temps avant le palier suivant). La rage est un chronomètre : vers 12 min il faut être au boss ou s'extraire. |
| N'importe quand | Si l'entrée du donjon est découverte **et 3 sceaux réunis** : entrer → **arène du boss**. |
| Boss | Combat direct dans une arène dédiée. Attaques annoncées par des **zones rouges au sol** (cercle, ligne, cône au corps à corps, projectiles à distance) + monstres invoqués autour. Être touché = **étourdi** 1 à 1,5 s. **Miroir** toutes les 12–17 s pendant 3 s : frapper le boss renvoie 60 % des dégâts. L'onde circulaire (bord jaune) se **saute**. PV fixes par carte et par époque, **rage du boss** après 2:30 / 3:00 / 4:00 (passe P11, voir « Boss : PV fixes et rage du boss »). |
| Fin | Victoire (boss vaincu) ou défaite → bilan → lobby. Le bilan (même composant dans tous les modes) sépare **Gagné** (maîtrise, étoiles, déblocages), **Gardé** (insignes dont 25 de participation, pièces découvertes, coffres, fournitures d'une run réussie) et **Perdu** (or, clés, fournitures d'une run perdue). |

## Pression constante (easy to play, hard to master)

- **Tous les monstres de la map traquent le héros** : jamais besoin d'aller les chercher.
  Ils suivent le maillage de navigation point par point (passe P9 : ils faisaient demi-tour vers le départ de leur
  chemin et n'avançaient qu'au tiers de leur vitesse ; maintenant 95 %, la horde reste à ~18 m d'un héros qui court, `tests/test_pursuit`).
- Flux continu d'escouades mélangées (budget 4 → 9, toutes les 6 → 3,5 s ; en rage 8–12 toutes les 2 s), de tous les
  côtés (passe P15, voir « Apparition des monstres et puissance »).
- **Vagues alternées** toutes les 45 s (30 s en rage) : un événement dur (*encerclement* annoncé ou *élite escortée*) puis un
  léger (*ruée d'essaim* ou *tenaille*).
- Chaque attaque de monstre est **annoncée au sol** selon son modèle : cône au corps à corps,
  ligne de charge (le monstre fonce), cercle d'écrasement, trait de tir. Sortir de la zone,
  esquiver (Maj) ou **sauter** au bon moment évite le coup.
- Les monstres ont ~2,4× leurs PV d'Eden et frappent fort : l'auto-attaque seule ne suffit
  pas, il faut kiter et placer ses compétences. 1 seule résurrection par run.

## Apparition des monstres et puissance (passe P15, retour du joueur du 15/10)

Retour : « des entités DIFFÉRENTES plutôt qu'un pack de 10 champignons qui viennent du même côté ; de tous les côtés, espacés ;
un niveau corrélé au nôtre, et des PV et des dégâts quand on commence à être stuffé ». Code : `core/spawn_director.gd`
(composant réutilisable : zone, temps de la carte, niveau du héros ; interface du Survivant, qui garde son rythme
`spawn_plan(t)` : `tick(delta)`, `pack(budget, niveau)`, `wave(dur, minutes)`, `pace`), `core/monster_scaling.gd`,
`ui/arrival_marker.gd` ; crochets d'une ligne dans `RunDirector` (`spawner`), `Monster.kind_override`. Boss : rien ne change.

- **Rôles** (`SpawnDirector.ROLES`, d'après le modèle d'Eden ou l'identifiant) : essaim léger (PV ×0,5, dégâts ×0,45, rapide,
  petit), mêlée rapide (vitesse ×1,08), chargeur (attaque en charge, dégâts ×0,9), tireur (attaque à distance, garde ses
  distances, dégâts ×0,65), tank lent (PV ×2,4, dégâts ×1,3, vitesse ×0,72, plus grand), soigneur (lueur verte, rend 6 % des PV
  aux monstres blessés à 9 m toutes les 6 s). PV par point de budget ≈ 1 pour chaque rôle ; l'expérience suit le coût.
  Vivants au plus : 6 tireurs, 6 chargeurs, 6 tanks, 3 soigneurs. Chaque zone a 4 rôles au moins, Limestone les 6.
- **Escouades** (flux continu, même rythme que l'ancien pack, budget ×0,7 (`PACE`) de 4 + minutes, 8-12 en rage ; un groupe
  mélangé venu de tous les côtés est plus dangereux qu'un pack d'une espèce, mesuré : ×1 donnait 1,5 à 1,8 fois plus de dégâts
  subis) : meute, essaim,
  chargeurs, tireurs (1 min), mixte (30 s), rempart (2 min), soutien (3 min 30) ; au-delà de 7 points, deux escouades de deux côtés.
  Jamais plus de 3 fois la même espèce dans un groupe (sauf l'essaim). Tout le bestiaire de la zone dès le début.
- **Événements** (45 s, 30 s en rage ; un dur puis un léger) : *encerclement* (6 à 8 groupes mélangés à 20 m, annoncés 1,1 s
  avant par des cercles orange qui se remplissent, une élite), *élite escortée* (tank, soigneur, mêlée, tireur), *ruée d'essaim*
  (3 groupes à 90° au moins), *tenaille* (deux escouades opposées). En rage, élites enragées toutes les 22 s.
- **Direction** : anneau de 24 à 31 m (hors de la vue), angle d'or (137,5°) d'un groupe au suivant, 8 secteurs qui « chauffent »
  (demi-vie 12 s), 60° au moins entre deux groupes d'un événement ; le dos du héros (sens de marche) une fois sur deux, et alors
  signalé ; devant lui 4 fois sur 10 (sinon les groupes barrent sa route : boss atteint 13-33 % au pilote au lieu de 60 %). Point refusé hors de la carte (marge 6 m) ou en pente ; glissé sur le maillage de navigation le plus proche (4 m au
  plus : jamais dans un arbre ou un rocher) ; refusé derrière un mur (chemin > 1,7 × la ligne droite + 8 m). Jamais de famine :
  maillage pas encore calculé (asynchrone) → le sol suffit ; 8 points refusés → sans le test du chemin ; puis l'ancien tirage.
- **Signal d'arrivée** : flèche au bord de l'écran (rouge : élite ; jaune : groupe dans le dos), chevron au-dessus du point
  quand il est dans la vue, 2,6 s, sous les cadres du haut et au-dessus de la barre de sorts.
- **Niveau** : Aventure (lot H4a) : niveau de héros + décalage, borné par la bande de la carte (`Epochs.BANDS`), + palier, +3 en
  rage ; ailleurs : max(courbe du temps, niveau du héros + décalage) + palier, plafonné par la zone ;
  décalage −1 au début de la carte → −0,5 à l'heure de la rage (avant : −1 tout le temps).
- **Puissance** (`MonsterScaling`, Survie) : indice d'équipement = PE de l'équipement porté (trouvailles de la carte
  comprises) / PE attendue au niveau du héros (départ 0,68, pièces de la carte à +0 0,94, époque I à +3 1,2, époque I optimisée
  1,9, époque II optimisée 2,4). Bande neutre par époque (`EPOCH_BAND` : I 0,6-0,95, II 1-1,35, III 1,9-2,45, IV 2,2-2,7) ;
  au-dessus, PV × (1 + 0,6 ln(indice / haut)) et dégâts × (1 + 0,35 ln(…)), en dessous de même ; bornes PV ×0,9-1,6, dégâts
  ×0,9-1,4 ; lissé (45 s), seulement pour les monstres qui apparaissent. Cartes, trophées et améliorations d'arme n'y comptent pas.
- **Empilement** (PV d'un monstre normal) : niveau × carte (`MAP_MULT`) × temps (`Epochs.time_ramp`) × rangs héroïques × montée
  du début × rôle × [puissance × Menace × pacte ≤ ×2,6] × rage ; dégâts : niveau × zone × carte × temps × rangs × montée × rôle × [puissance × pacte ≤ ×1,6]
  × rage. La puissance cède sa place sous ces plafonds, jamais en dessous de ×1 ; la rage (chronomètre) reste hors plafond.
- **Mesures** : ligne `[spawn]` toutes les 30 s au pilote automatique (`--auto-quit`, `--trace`), résumée par `tools/sim_survie.py` ;
  `--spawn=legacy` rejoue l'ancien spawn ; journal de run : `spawn_species`, `spawn_spread`, `power_hp`, `gear_index`…
  Indices d'équipement : `res://tools/power_probe.tscn`. Tests : `tests/test_p15.tscn` ; captures : `tests/shot_p15.tscn`.

## Pacte, géants et Menace (passe P12, 0.1.191, idée du joueur inspirée de Megabonk)

But : faire sentir qu'une run se prépare avant le boss, en offrant des risques choisis qui paient. Code : `core/menace.gd`,
`world/giant_altar.gd`, `ai/giant_monster.gd`, `ui/menace_badge.gd` ; crochets d'une ligne dans `RunDirector` et `Run.finish`.

- **Pacte** (autel de cupidité, 1 par carte, existait déjà) : jusqu'à la fin de la carte, monstres +25 % (PV et dégâts, ceux déjà
  là compris), or et butin ×1,5 ; nouveau : les **insignes** de fin de run +50 % au prorata des cartes jouées sous pacte.
- **Autel du géant** (2 par carte, gratuits, une fois chacun, pas en rage) : un **géant** surgit, le monstre ordinaire le plus fort
  du moment agrandi ≈ ×2,8 (×3,5 avec le drapeau d'élite) : PV de 8 élites de la zone au même niveau, coup de 1,6 élite, plafonné
  à 30 % des PV max du héros (jamais tué d'un coup), lent (×0,72). Une attaque sur deux est une grande zone au sol : écrasement
  (cercle de 5,5 m sous le héros, 1,25 s), onde (anneau 2,6-12 m, à sauter, 1,4 s), balayage (éventail de 160°, 9 m, 1,1 s).
  Vaincu : une **carte au choix parmi 3** (une relance), 60 + 15 × niveau d'or, ses récompenses d'élite (clé…), expérience
  bornée à 3 élites ; **Menace +1**.
- **Menace** : chaque cran, PV des monstres vivants de la carte, de tous les monstres suivants **et des boss suivants** +20 %
  (cumul additif : ×1,2, ×1,4… ; plafond **5 = ×2**, un géant de plus ne la monte plus) ; dégâts inchangés. Le boss garde ses PV
  fixes (P11) multipliés par la Menace (appliquée à la fin de l'image, après son réglage). Remise à zéro au début de chaque run.
  Récompense : insignes de fin de run **+10 % par cran** (au plus +50 %), plus le pacte (au plus ×2 en tout).
- **Bornes** : 2 géants par carte au plus (6 par run) : 2 cartes de plus par carte, contre ≈ 10 aux sanctuaires ; pas de géant en
  rage (les paliers de rage en feraient un mur, et une ferme à rage est fermée par P9). La rage ne change pas ; en JcJ, à la Tour et
  au Battle royale, ni géant ni pacte (Menace 0).
- **HUD** : pastille sous les objectifs, « ☠ Menace ×1,2 » et « ⚖ Pacte » ; le détail chiffré est dans l'infobulle. Bilan : ligne
  « Menace ×1,4 et pacte » dans le détail des insignes. Journal de run : `menace`, `giants_summoned`, `giants_killed`, `pact`,
  `pact_maps` et compteurs `giant_kills`, `giant_ttk_sum`, or « geants ». Fiche de découverte « Géants et Menace ».
- **Mesures** : `--giants=N` fait invoquer N géants par carte au pilote automatique (2:00 puis 4:30). Test : `tests/test_p12.tscn` ;
  captures : `tests/shot_p12.tscn`.

## Boss : PV fixes et rage du boss (passe P11, retour du joueur du 15/10)

Retour du joueur (compte neuf, 0.1.189) : « nos dégâts scalent à l'infini (c'est le but), mais le boss de la 3e carte a des PV
ridicules ». Mesure (journal réel et sonde) : boss des cartes 1 / 2 / 3 de l'époque I tués en 53 / 17 / 9 s ; leurs PV venaient
du niveau d'Eden de chaque boss (≈ 40 000 à 120 000 partout) pendant que les dégâts du héros sont ×13 entre la carte 1 et la 3.
Décision du joueur : **PV FIXES par carte et par époque, démesurés, jamais calculés d'après le niveau ou la PE du héros** (sinon
il suffirait de foncer au boss) ; il faut avoir fait **une bonne run** (niveau, cartes, trophées, enclume, trouvailles) pour le battre.

- **Survie** : PV = `Epochs.BOSS_HP_MAP[carte]` × `Epochs.BOSS_HP_EPOCH[époque]` × rangs héroïques × Menace (P12, ×1 à ×2).
  **Lot H4a** : la table ci-dessous est la référence d'avant ; les PV suivent maintenant le niveau du boss (niveau de la carte pour
  le héros + 1, fixe pendant la partie, jamais la PE ni le niveau de run) : voir « Aventure au niveau de héros ».

  | | Carte 1 | Carte 2 | Carte 3 |
  |---|---|---|---|
  | Époque I | 80 000 | 370 000 | 1 750 000 |
  | Époque II (×2) | 160 000 | 740 000 | 3 500 000 |
  | Époque III (×4) | 320 000 | 1 480 000 | 7 000 000 |
  | Époque IV (×5,5) | 440 000 | 2 035 000 | 9 625 000 |

- **Rage du boss** (Survie) : après **2:30 / 3:00 / 4:00** dans l'arène (`Epochs.BOSS_RAGE_AT`, ≈ 2 fois le temps d'une bonne
  run), ses dégâts suivent les paliers de la rage de la carte (`RunDirector.RAGE_TIERS`, une minute par palier : ×1,1, ×2, ×11, ×101) ;
  ses PV ne bougent pas. HUD : « BOSS · 2:30 » dans le cadre de la zone (rouge à 30 s), puis « RAGE ×2 · 0:42 » ; la ligne
  d'objectif et le panneau d'objectifs disent la même chose ; bandeau à chaque palier. La barre du boss porte deux encoches dorées
  à mi-vie (2e phase : il entre en fureur).
- **Ce qu'il faut pour le battre** (sonde `tools/boss_ttk.py`, aide « Bot », héros invincible, médiane de 5 classes) : run
  *rushée* (boss atteint tôt : carte 1 niveau 8, 7 cartes) 4 à 8 min, donc jamais avant sa rage ; run *moyenne* 1 min 20 à 5 min
  (passe aux cartes 1-2, souvent pas à la 3e) ; *bonne* run 1 min à 2 min 40 ; run *dorée* (bonne run + équipement du hub optimisé)
  30 s à 1 min 50, jamais en quelques secondes. L'équipement du hub raccourcit toujours le combat. Avec des coups encaissés
  (`--human 0.5`), les runs rushées perdent toutes (20 / 20).
- **Donjons, Ruée, Siège** : PV fixes par niveau et difficulté, plus d'après les données d'Eden de chaque boss (elles donnaient
  un boss Mythique de Limestone à 990 millions de PV, jamais tué, et un Héroïque de Blackflame tué en 15 s) :
  PV = 106 000 × 1,09^(niveau − 15) × [1 ; 3,4 ; 2,5] (Normal, Héroïque, Mythique) (`Dungeons.boss_hp`, ×1,09 par niveau comme les
  dégâts d'un héros synchronisé), × (1 + 0,5 par allié) ; Ruée × 0,6 par boss (8 boss d'affilée) ; Siège × 3,2 (trois héros,
  fureur à 6 min inchangée). Mesuré avec l'équipement attendu : 1 min 30 à 2 min 50 dans la plupart des cas.
- **Inchangés** : monstres normaux, élites, géants, rage de la carte (la survie est bonne d'après le joueur) ; duels et Tour.
- **Progression** (`tools/progression_sim`, terme `C_BOSS` : un boss de carte 2-3 tombe ≈ 3 fois sur 4 pour un compte neuf, 9 sur 10
  avec des pièces mythiques) : époques gagnées à 2,4 / 8,5 / 17,6 / 30,5 h (avant 1,9 / 6,9 / 14,5 / 24,0), 1re victoire en 7 runs.

## Zones et biomes (progression)

> État 16/10 : en Survie, les zones sont celles des époques (`Epochs.LIST`), le héros joue à son niveau de héros, chaque carte a
> sa bande de niveau (`Epochs.BANDS`, lot H4a) et une époque gagnée ouvre la suivante ; la table des zones et des boss d'origine reste juste.

Données : `tools/build_biomes.py` lit une map d'Eden par biome (textures du sol, décors les plus
fréquents, monstres des camps, élites, boss) ; le terrain reste généré.

| Zone | Map d'Eden | Héros au départ | Ambiance |
|---|---|---|---|
| Limestone Mtn. | s002 | niv. 1 | prairies, roches calcaires |
| Rainbowfall Forest | s004 | niv. 4 | forêt luxuriante, brume verte |
| Beluga Bay | s006 | niv. 7 | côte, palmiers, sable |
| Wetlands | s007 | niv. 10 | marais sombre, brouillard |
| Avila Volcano | s009 | niv. 13 | roche noire, arbres morts, ciel rougeâtre |
| Arid Wilds | s011 | niv. 16 | désert de sable |
| Delphi Forest | s012 | niv. 19 | forêt volcanique, lys, griffons, foreuses de Pross |
| Blackflame Peak | s013 | niv. 22 | pic de roche noire, lave, culte de Mara |

### Salles de boss (un vrai boss nommé d'Eden par zone)

| Zone | Boss | Salle | Mécaniques |
|---|---|---|---|
| Limestone | Mori, roi des champignons | piliers | renforts à 75/50/25 %, flaques de poison |
| Rainbowfall | Angela, sorcière du marais noir | marais (mares de poison) | se dédouble (illusions), flaques d'ombre, rayons en croix |
| Beluga | Ulicul, ogre sauvage | givre | 3 ondes de choc à sauter, renforts |
| Wetlands | Doubledoor, hôte de la magie | cristaux (piliers, foudre) | bouclier : 3 totems à détruire, rayons, poison |
| Avila | Miller, bête de flammes géante | lave | pluie de météores (laisse de la lave), ondes de choc |
| Arid | Abby, reine des insectes | piliers | renforts, tourbillon qui attire, poison |
| Delphi | Pross, le savant fou (+ Expérience 627) | cristaux | compagnon, rayons, renforts, météores |
| Blackflame | Wushu, roi sorcier (+ Jiku) | lave | compagnon, météores, illusions, tourbillon |

Données : `tools/build_biomes.py` (DUNGEONS) ; mécaniques : `scripts/ai/boss_brain.gd`
(bibliothèque : adds, puddles, meteors, stomp, clones, totems, lasers, pet, vortex, reflect),
dangers au sol : `scripts/combat/hazard.gd` ; agencements : `ProcMap.generate_arena`.
Les costumes d'Eden tombent sur les boss (1 chance sur 4, 1 sur 2 s'il est enragé).

- Une zone se **débloque en battant le boss de la précédente** (choix dans le lobby).
- Le héros commence la run au niveau de la zone ; les monstres d'Eden sont ramenés au niveau
  de la run (dans les deux sens), +½ niveau par palier de zone ; butin plafonné plus haut.
- Le roster de la zone se dévoile avec la progression (monstres les plus forts en fin de run).
- « Nouvelle partie » reverrouille les zones.

## Monnaies, coffres et zones (refonte 0.1.25)

> État 16/10 : la description de la carte (0.1.90) reste juste. Périmé dans la table : les trophées ne sont plus de l'équipement
> (0.1.130, collection de la run) et le coffre de trophées n'existe plus (E1) ; les mythiques / légendaires de la Survie viennent des
> coffres d'emplacement ; la Forge est fermée pendant la Survie (Atelier hors run) ; insignes et cristaux : partie D.

Deux boucles : les **monstres** donnent les ressources d'équipement (objets au sol, or,
coffres de récompense) ; les **coffres de la carte, sanctuaires, élites et marchands**
donnent les **cartes d'amélioration de la run** (on repart toujours niveau 1 : l'équipement,
les trophées et les sorts se combinent aux cartes de la run, c'est la boucle rejouable).

| Monnaie / ressource | Où l'obtenir | À quoi elle sert | Fin de run |
|---|---|---|---|
| **Or** (pièces) | monstres, vente d'objets aux marchands, sanctuaires des clés | coffres de la carte (prix qui monte à chaque coffre), marchands ambulants, amélioration +1 → +10 (seulement de l'or), fusion de gemmes, fabrication | **perdu** |
| **Clés** | élites (1 chacune), sanctuaires des clés (2), marchands | ouvrir un coffre de la carte sans payer (utilisée en priorité) | **perdues** |
| **Cristaux** | démonter un objet (selon la rareté) | réforger une stat bonus, polir la qualité ; fabrication | **gardés** |
| **Fournitures** (gemmes, parchemins, ciseaux, pierres de chance / protection) | butin, coffres de la carte, marchands, coffres de forge et du joaillier | forge : sertir, enchanter, améliorer sans risque | réserve gardée (victoire, extraction), perdues si le héros tombe |
| **Cartes d'amélioration** | passage de niveau, coffres de la carte, sanctuaires des cartes, gardiens d'élite, marchands | build de la run (sorts, améliorations, passifs) | la run seulement |
| **Choix de trophée** (3 au choix) | sanctuaires des trophées, coffres de trophées | un trophée (buff sous condition) qui rejoint le sac / le coffre | gardé comme tout objet |
| **Coffres de récompense** | boss du donjon (100 %), élites (20 %), monstres (0,5 %) | menu **Coffres** hors run : équipement (mythique / légendaire), forge, joaillier, set au choix, trophée au choix ; **seule source des mythiques et légendaires** | **jamais perdus** (rangés dès qu'on les ramasse) |
| **Points d'expertise** | fin de run | maîtrise de la classe (talents, sorts, certificats) | gardés |
| **Archive et trésors de collection** | mythiques / légendaires archivés, boss | bonus permanents, apparences | gardés |

**Sur la carte** (512 × 512 m, refonte 0.1.90 façon Megabonk) : plus de **1 000 objets à casser**
(jarres, caisses, tonneaux : or, un peu d'XP, parfois des soins, une fourniture ou une clé ; tas d'or
ramassés en passant ; cristaux à briser en 3 coups : des gemmes), **24 lieux de décor** (ruines, tours de
guet, arches, ossements, mines, campements, marchés), **8 plateaux** (et cuvettes) avec un trésor en haut,
un réseau de sentiers ; **30 coffres** payants (or ou clé, +18 % à chaque coffre ouvert) en 3 qualités qui
proposent **une pièce d'équipement au choix parmi 3** : coffre (spécial → épique), coffre ouvragé (rare →
mythique, ×2,5), coffre doré (épique → légendaire, ×6, pilier de lumière) ; des **lieux à usage unique**
(pilier de lumière) : 2 **autels du scribe** (parchemin
d'enchantement au choix), 3 **fontaines de vie**, 2 **pierres d'aimant** (toute l'XP et le butin), 1 **autel de
cupidité** (pacte : +50 % d'or, de butin et d'insignes, monstres +25 % jusqu'à la fin de la carte), 2 **autels du géant**
(un géant à vaincre : une carte, mais la Menace monte, voir « Pacte, géants et Menace »), 2 **stèles du défi** (3 élites : coffre de récompense
mythique / légendaire et fournitures), 1 **autel de la fortune** (idée du joueur : pyramide de 8 étages,
étages 1 à 7 de 8 à 2 cases dont une piégée ; encaisser ou monter, la case piégée fait tout perdre ; gains :
or, clés, puis coffres de forge, joaillier, équipement, set, trophées ; sommet (1 chance sur 8) : une
apparence dorée de la collection, `core/fortune.gd`). Ancien fonctionnement : 10 coffres à prix doublé, choix de cartes ; 10 **sanctuaires** à capturer (rester 14 s dans
le cercle pendant que les monstres affluent ; hors du cercle la capture redescend) : cartes,
trophées ou clés ; 3 **marchands ambulants** qui se promènent (cartes, clé, fournitures,
équipement, rachat du butin, fabrication) ; les **élites** donnent une clé, les gardiens des
camps un choix de cartes en plus de leur sceau. Le village n'existe plus (décor du menu
seulement). La **Forge** (fiche d'un objet, Échap > Héros) : améliorer à l'or, réforger et
polir aux cristaux, percer, sertir, enchanter, fusionner des gemmes.

## Sceaux du donjon

- L'entrée du donjon est **scellée** : il faut **3 sceaux**.
- Chaque camp d'élite a un **gardien** (élite + 4 gardes) qui porte un sceau ; les autres
  élites ont 30 % de chances d'en lâcher un.
- La clairière de l'ancien village (un marchand ambulant y démarre) est du côté du départ.

## Map générée

- Terrain ~512 × 512 m, relief doux, bordure de falaises, chemins qui relient les lieux.
- Lieux placés aléatoirement à bonne distance : départ, entrée du donjon, 10 coffres payants (30 depuis 0.1.90, voir « Monnaies, coffres et zones »),
  10 sanctuaires, 3 marchands ambulants, camps de monstres, camps d'élites.
- Décor Eden (arbres, rochers, buissons, ruines) dispersé hors des chemins et clairières.
  Collisions simples (cylindre / boîte), petits objets sans collision.
- Brouillard de guerre : la mini-carte se révèle en explorant ; les lieux découverts y restent.

## Marchands ambulants (remplacent le village)

- 3 par carte, ils se promènent autour de leur place et s'arrêtent face au héros.
- Un seul écran par marchand : **Boutique** (3 cartes, 1 clé, fournitures, équipement rare ou
  épique, parfois un trophée ; offres tirées pour ce marchand), **Vendre** (filtres, sélection
  multiple, sélections rapides), **Fabriquer** (mythiques de la zone, or + cristaux).

## Extraction

> État 16/10 : l'extraction existe toujours (+60 de maîtrise, fournitures gardées, `Run.finish`) mais l'« héritage » n'existe
> plus : en Survie le hub est restauré comme à toute fin de run (`Profile.end_run_survival` ; `Profile.end_run_extract` n'est plus appelé).

- Touche **X** (modifiable) ou menu pause : **10 s à survivre**, une vague encercle aussitôt le
  héros. Mourir annule l'extraction.
- Réussite : **tout l'équipement et l'inventaire rejoignent l'héritage** (améliorations,
  gemmes, enchantements compris), l'équipement porté devient l'équipement de départ ;
  +60 d'expertise. L'or, les matériaux et les fournitures restent perdus, et aucune zone n'est
  débloquée (il faut battre le boss pour ça).
- Victoire contre le boss : 1 objet gardé au choix (inchangé) ; défaite ou abandon : idem.

## Plafond de niveau par zone

> État 16/10 : en Survie, bande de niveau par carte (`Epochs.BANDS`, lot H4a, plus de plafond) ; `RunDirector.ZONE_MAX_LEVEL` ne concerne plus que l'ancienne run.

- Limestone (map 1) : butin au niveau 15 maximum, monstres plafonnés au niveau 15 (18 en rage
  et pour le boss). Les maps suivantes prendront le relais (`RunDirector.ZONE_MAX_LEVEL`).

# Partie C — Les autres activités

## Survivant (mode à part, lots S1 à S8 de `conception/survivor/`, ouvert à tous depuis 0.1.210)

Spécification : `conception/survivor/SPEC.md` (sa tête « Décisions finales » prime sur `DECISIONS_JOUEUR.md` et sur le corps). Une run pure façon Vampire
Survivors : 20 minutes sur une seule carte, boss à 20:00, tout le build (arme, pièces, sorts) se gagne aux cartes de niveau.
Mode « pour s'amuser » : **aucun lien avec la progression du compte** (ni équipement du hub, ni maîtrise, ni insignes, ni
découvertes, ni verrou) ; seules les classes et les apparences débloquées comptent ; récompense de fin : des coffres
d'apparence (lot S6). Socle (S1, 0.1.194) :
- Lancement (`Survivor.start`) : héros niveau 1 sans arme ni pièce (seulement les potions de départ), zone au choix parmi
  les 8 décors de la Survie (aucune n'est plus dure), époque I carte 1 pour les règles communes ; `Run.survival` reste vrai
  (socle de la Survie), `Run.survivor` et `Survivor.active` disent le mode (`Modes.current() == "survivor"`).
- **Le hub n'est jamais modifié** : équipement copié puis remis (comme la Survie), réserve de fournitures laissée au hub, et
  toute la progression du compte (`Survivor.HUB_KEYS`) photographiée au départ, écrite telle quelle par les sauvegardes faites
  en pleine run, remise à la fin (avant les récompenses du mode).
- Déjà propre au mode : pas de rage de carte, une seule carte (le boss vaincu termine la run), ni autel du scribe ni autel de
  la fortune, sanctuaires « trophée » changés en cartes, marchand sans fournitures, ni archive ni auras dans les stats,
  expérience ×2 au niveau 1 → ×1,15 au niveau 10, puissance des pièces « Survivant » = niveau du héros (90 au plus).
- Règles chiffrées : profil `survivor` de `ModeRules` (modifiable en mode dev). **Visible et jouable par tous dès le départ**
  (`Survivor.READY`, lot S8) : activité de la rangée Aventure (2e, illustration provisoire `assets/ui/activities/survivor.jpg`),
  quêtes du Survivant tirables, nouveauté « Survivant » et entrée au Guide (chapitre Modes).
- **Horde et lisibilité** (lot SVX-1, `conception/survivor/R_SVX1.md`) : 30 → 230 monstres vivants (290 à la horde finale de 19:00),
  plus petits (× 0,6, jamais plus hauts que 0,8 × le héros), arrivées à l'écran annoncées par une croix au sol 0,8 s avant ; le héros
  traverse les monstres ordinaires ; chacun porte une part des PV (× 0,45), des dégâts (× 0,6), de l'expérience (× 0,33) et de l'or
  (× 0,25) ; 2 → 12 monstres frappent en même temps au plus ; gardien en vie = horde calmée (pas de vague) ; gardiens 50 000 /
  440 000 / 1 400 000. Lisibilité : un nombre de dégâts par cible (30 à l'écran au plus), sorts du héros à 40 % d'opacité au plus,
  héros contouré, décor tramé dans 4 m autour du héros, barre de cible pour les élites, géants et boss seulement.
- **Faveurs, malédictions, boutique, confort** (lot SVX-4, `conception/survivor/R_SVX4.md`) : une **faveur de départ** au choix à la page du mode
  (une règle et sa contrepartie : Horde affamée, Canon de verre, Chasse au trésor, Course folle, Bonne étoile, Érudit ; deux ouvertes d'office,
  les autres par les défis du mode ; jamais les gardiens ni le boss) ; une pièce sur 15 **maudite** (jet parfait, gros bonus et contrepartie
  écrite, jamais l'arme) ; **boutique du gardien** après chaque gardien (4 cartes, Garder gratuit, relance × 1,5, chaque achat + 15 %),
  coffres plus chers avec le temps, « Passer » moins payé quand l'or déborde ; **partie du jour** (même zone, classe, carte et tirages pour
  tous, tableau des 5 meilleures) ; **prolongations** après le boss (horde sans fin, record seulement, la partie reste gagnée) ; **choix
  regroupés** (option) ; **Sauver et quitter** / **Reprendre** (une sauvegarde, effacée à la reprise) ; fiches d'arme et de sort au Codex ;
  accessibilité : taille des nombres, effets et secousses réduits, sous-titres des alertes, horde contrastée, vitesse du jeu × 0,8 / 1 / 1,2
  (hors records), forme de la rareté sur chaque carte. Coup du boss final plafonné à 35 % des PV max du héros.
- **Pièces et arme** (S2, `core/survivor_pool.gd`, `core/survivor_gear.gd`) : pool = les 13 sets d'Eden de niveau 90 (tête,
  torse, jambes, gants, bottes ; 5 en plates, 5 en cuir, 3 en tissu), plus les pièces de niveau 90 hors set pour la cape, le
  collier et la bague ; armes des 17 types (modèles de niveau 90). Stats d'origine de la pièce, puissance = niveau du héros (90
  au plus) ; seule part aléatoire : la qualité, 100 à 120 % (jet parfait = 120 %). Chaque pièce a un **passif fixe** (effet
  d'une carte commune, `Cards.PASSIVE_EFFECTS`, table déterministe, jamais deux fois le même dans un set) et gagne à +6, +8 et
  +10 un passif tiré **quand la carte d'amélioration est proposée** (affiché, différent des siens) : 4 passifs distincts à +10,
  cumulés dans la run (`Run.passive_power`), plafonnés par effet. Emplacements et arme **verrouillés à vie** (aucun retrait ni
  remplacement, même au menu pause). **Panoplies** à 2 / 3 / 5 pièces, en Survivant seulement : 2 = stat de la famille du set
  (attribut dominant : Assaut +6 % d'attaque, Vivacité +8 % de vitesse d'attaque, Sortilège +8 % d'attaque magique, Grâce +8 %
  de PV) ; 3 = les deux stats propres au set ; 5 = bonus fort + effet de la famille (explosion d'auto-attaque, foudre sur
  critique, écho de compétence, barrière et soin) + stat du type d'armure. Propositions : type d'armure de la classe ×2,
  jamais deux pièces du même set dans une offre, set déjà porté à 3 pièces ×0,14 (S3, mesuré avec le vrai tirage des cartes) :
  un 5/5 ≈ 1 run sur 25 pour un joueur qui le cherche (`tools/sv_cards_sim.tscn`), jamais sans le chercher.
- **Cartes** (S3, `core/survivor_cards.gd`) : à chaque montée de niveau, 3 cartes sur des cibles différentes : une carte
  d'**équipement** (une arme tant qu'aucune n'est portée, sinon nouvelle pièce d'un emplacement libre ou amélioration +2 d'une
  pièce ou de l'arme, +4 en légendaire, jusqu'à +10 ; à +6 / +8 / +10 le passif gagné est écrit sur la carte), une carte de
  **sort** (nouveau sort du kit entier de la classe, **12 au plus** depuis S9 : la grille entière, 4 cases × le sort et ses 2
  enchaînements ; au-delà de 6 sorts les améliorations de sort se partagent le poids de 6, `spell_up_norm`), ou amélioration de niveau 1 à 10 : effet de `Cards.skill_upgrade`
  cumulé, niveau 5 au moins épique, niveau 10 légendaire ; un nouveau sort tant que le héros en a moins de 2), une carte libre au
  poids (profil `survivor` : `w_*`, pitié ×2 après 6 choix, évolution légendaire quand ses passifs sont portés) ; au plus 2
  nouvelles pièces ; cartes de repli (or, soin, relance) seulement s'il manque des cartes. Plus de carte commune.
  **Premier choix** : seulement des armes (types différents) et des compétences, obligatoire. **Relancer** 2 fois par run (+
  passifs « relances ») : une amélioration relancée tire un autre passif ; **bannir** 3 fois (un sort, un type d'arme, un set,
  le passif d'une amélioration, une évolution ; pas l'amélioration de sort) ; **garder** (la carte revient telle quelle) ;
  **Passer** : 15 + 3 × niveau d'or, jamais au premier choix. Coffres (`chest_cards`) : emplacement libre = 3 pièces de cet
  emplacement, pris = son amélioration d'abord ; arme = 3 améliorations de raretés différentes ; sort ; doré (rareté +) ;
  gardien (pièces d'emplacements libres) ; enclume (+2 sur les pièces les plus proches d'un passif). **Rien du compte** : ni
  talents, ni certificats, ni plateau, ni sorts fermés par la maîtrise (le kit entier est ouvert), ni cartes débloquées.
- **Déroulé** (S4, `core/survivor_director.gd`) : chronologie fixe (`SurvivorDirector.timeline`) : gardien à 5:00, 10:00 et
  15:00 (annoncé 10 s avant, un géant de P12 à 18 m du héros, PV fixes 50 000 / 220 000 / 700 000 × palier × Menace, coups
  plafonnés à 30 % des PV du héros ; vaincu : coffre du gardien et or, la Menace ne monte pas) ; portail du boss ouvert à
  15:00 (sans sceau, entrée en avance comptée pour l'« Audace » de S6) ; « le boss arrive dans 1:00 » et horde finale à 19:00 ;
  entrée forcée dans l'arène à 20:00 (attend un héros debout). Boss : PV fixes 6 000 000 × palier × Menace (jamais d'après le
  héros), rage du boss après 4:00 (paliers de P11). Boss vaincu = victoire ; seconde chute = défaite ; abandon au menu pause ;
  pas d'extraction.
- **Monstres** : `SurvivorDirector.spawn_plan(t)` donne la composition par minute : vivants 18 → 110, meutes toutes les
  6 → 1,8 s de 3 → 12, vagues alternées toutes les 45 → 25 s, élites dès 8:00 (40 s, puis 20 s par deux après 15:00), niveau
  1 + 1,8 par minute (90 au plus ; sans le plancher « héros − 1 » qui emballait la run), PV × 0,5 × 1,12^min, dégâts × 0,5 × 1,07^min, × palier. Le
  composant de spawn de P15 (`RunDirector.spawner`) prend les meutes et les vagues quand il est là (`--spawn=legacy` : celui du
  Survivant). Plus de plafond de niveau du héros par carte (90).
- **Ce qui reste / disparaît** : or (monstres, objets cassés, défis, gardiens ; coffres et marchands), clés, XP, potions (3 % /
  30 %), fontaine, aimant, sanctuaires, camps d'élite (clé + carte), pacte et autels du géant (P12 inchangé) **restent** ; 30
  coffres du Survivant (2 par emplacement d'armure et de bijou, 2 d'arme, 6 de sort ouvragés, 6 dorés) dont le contenu vient
  de `SurvivorCards.chest_cards` ; l'enclume donne +2 sur une pièce portée ; la stèle du défi donne un coffre doré ; plus de
  butin d'équipement, de coffre de récompense, de fourniture, de gemme, d'arme secondaire ni de sceau.
- **Interface** (S5, `ui/survivor_cards_view.gd`, `ui/survivor_build_page.gd`, `ui/survivor_hud.gd`) : cartes rendues par famille
  (pièce : statistique principale en gros, 4 lignes, barre du jet 100 → 120 et ★ au jet parfait, set x / 5 et son prochain
  bonus, passif fixe, « Gardée à vie » ; amélioration : « +4 → +6 », jauge des paliers, passif tiré encadré d'or, avant → après
  ▲ ; sort : niveau n → n + 1 sur 10, « Ce niveau » puis « Total ») ; Bannir / Garder épinglés en bas de chaque carte, Relancer
  et Passer sous la rangée (manette : LB relance, RB passe). Trois fiches à la 1re rencontre, dans le choix lui-même (première
  carte, pièce à vie, paliers). Pause : page **Build** d'abord (emplacements verrouillés, sorts x / 10, passifs cumulés, sets
  2 / 3 / 5, statistiques), pas de page d'inventaire. HUD : frise des 20 minutes (gardiens, portail, boss) puis jauge de la
  rage du boss, « Équipement x / 9 · Sorts x / 12 », niveau de chaque sort en chiffre sur sa case.
- **Orbes d'expérience** (S9, `world/xp_orbs.gd`, toutes les runs) : 300 orbes au sol au plus ; au-delà, la nouvelle orbe apparaît
  sous le monstre et reprend la valeur de l'orbe oubliée la plus loin du héros (jamais perdue, toujours visible là où il se bat).
- **Fin de run et récompenses** (S6, `core/survivor_rewards.gd`) : **seulement des coffres d'apparence** (jamais d'insignes, de maîtrise,
  de cristaux, de découvertes ni de puissance). Trois paliers d'avancée : tenir 10 minutes (temps de carte, pauses exclues) → coffre
  commun ; trois gardiens vaincus → rare ; boss vaincu → mythique (**légendaire dès le palier II**) et un titre de victoire par
  palier (Survivant, endurci, implacable, légendaire, Maître des survivants). Chaque palier d'avancée paie **une fois par palier de
  difficulté** ; ensuite, au plus **un coffre commun (10 minutes) et un rare (boss vaincu) par jour** : le total est borné (15 coffres
  « première fois » en tout), aucun farm cosmétique. Même une défaite ou un abandon paient ce qui a été atteint ; pas de titre hors
  victoire. Plafonds dans `Profile.records["sv_rewards"]` (rien à migrer). Bilan (`ResultsScreen.survivor_spec`) : six tuiles (niveau,
  durée, monstres, élites, gardiens x / 3, boss), titre gagné, bloc Gardé (les coffres, raison au survol), bloc **Ton build** (arme,
  pièces x / 8, panoplie, pièces à +10, jets parfaits, sorts), ligne « Ta quête », boutons Rejouer (même classe, zone, palier), Changer
  de classe (page du mode et choix de classe ouverts) et Retour au lobby ; rien de « Perdu » ni de maîtrise. Les quêtes reçoivent le
  temps de carte. Page du lobby : trois lignes de récompenses (✔ une fois gagnées). L'apparence du hub (tenue, accessoires, aura,
  skin d'arme du type) s'affiche pendant la run. Le hub reste intact (hors coffres d'apparence, titres et plafonds).
- **Équilibrage** (S7, `conception/survivor/R_S7.md`, réglages en tête de `core/survivor.gd`) : expérience ×2 → ×1,15 (niveau 10)
  → ×0,35 (niveau 35) : niveau 40 à 20:00 (53 avant) ; ouverture douce (dégâts ×0,3 et PV ×0,6 à 0:00, ×1 à 3:00 ; 1re vague à
  1:15 ; ni vague avec élite avant 4:00 ni camp d'élite avant 3:00) ; spawn de P15 (escouades, événements, anneau espacé) piloté
  par `spawn_plan` ; puissance des monstres ordinaires selon l'équipement DE LA RUN comparé à la bande attendue par minute (PV
  ×0,9-1,3, dégâts ×0,9-1,15) ; dégâts du boss ×1 (pas la courbe des monstres ; ×1,4 depuis S8, `Survivor.BOSS_ATK`) ; plafonds du héros : critique 75 % (surplus en
  dégâts critiques), dégâts critiques +250 %, vitesses ×2,5 ; pitié de l'offre (3 choix sans carte forte → améliorations au moins
  épiques) ; set à 3 pièces portées ×0,17 (5/5 ≈ 1 run sur 23 pour qui le cherche). Mesuré (30 runs au pilote) : victoire 40 % au
  joueur moyen, aucune mort avant 3:00, boss en 2:10, gardiens en 30-60 s ; sonde de 312 builds : le meilleur type de build bat le
  boss 1,1 fois plus souvent que le médian. `tests/test_sv7` lit `tests/sv7_mesures.json` (à refaire si un réglage change).
- **Paliers I à V** (S8, `Survivor.PALIERS`, `conception/survivor/R_S8.md`) : chaque palier garde les règles du précédent et en
  ajoute une, écrite en une phrase sur la page du mode (détail au survol) : **I Normal** ; **II Endurci** : monstres plus rapides
  (×1,15) ; **III Implacable** : soins reçus divisés par deux (modificateur `heal_half`, retiré en fin de run) ; **IV Cauchemar** :
  Menace 2 dès le départ et une mécanique de boss en plus (`EXTRA_BRICKS`, d'une famille que le boss n'a pas, annoncée à l'entrée) ;
  **V Légende** : deux gardiens à 15:00, deux mécaniques de boss en plus, rage du boss après 3:00, monstres ×1,2. PV et dégâts des
  monstres, gardiens et boss × `palier_mult` (1 / 1,45 / 1,7 / 1,75 / 2,1), installé sur les monstres ordinaires pendant les 5
  premières minutes (le héros part nu), entier pour gardiens et boss. **Un palier s'ouvre en gagnant le précédent dans ce mode**
  (`Profile.records["sv_rewards"].wins` ; jamais par la progression du compte ; mode dev : tous) ; bilan « Palier II ouvert ! ».
  Récompenses : celles de S6 par palier (boss vaincu = coffre légendaire dès le II, titre du palier). Page du mode : cinq boutons
  I à V (le choisi en or, les fermés « 🔒 » grisés avec leur condition), le palier par défaut est celui de la run qui vient de finir,
  sinon le plus haut gagné. Dégâts du boss ×1,4 (S8 : le pilote dépense son or, voir R_S8).

## Bibliothèque de boss et donjons à la carte (passe M2, nuit du 15/10)

Vision du joueur : « farmer des donjons DE SON CHOIX pour affronter les boss qui donnent les pièces dont on a besoin ; un ÉNORME
pool de boss aux mécaniques différentes, réutilisables partout (Tour, Ruée, Siège, Survie, Survivant) ».

- **Bibliothèque** (`core/boss_library.gd`, données `data/bosses.json`) : **48 boss**, 6 par zone (le boss d'origine de la zone
  + 5 élites nommées d'Eden promues boss). Un boss = un monstre (modèle, animations), un nom et un titre, **2 à 4 briques** de
  mécaniques, un jeu d'attaques de base (`kit`), des PV × `hp` sur les PV fixes du palier (passe P11 : `Dungeons.boss_hp`,
  jamais d'après le héros), une zone (décor, niveau, monstres des salles) et un **thème de butin** (panoplie + 2 emplacements).
- **Briques** (`ai/boss_bricks.gd`, `BossBricks.DEFS`) : une mécanique = une fonction + des paramètres, **aucun code propre à un
  boss**. 29 briques en 10 familles : zones au sol (flaques, météores, rayons, damier, balayage), invocations (renforts,
  compagnon, illusions, nuée, tourelles), fureur (rage à 30 %, impatience au fil du temps), boucliers (totems, barrière à briser
  sinon il se soigne, cristaux de soin), charges (ruée, bond), projectiles (spirale, couronne d'orbes, éventail), arène qui se
  resserre, placement (cercle sûr, tourbillon, bourrasque, regard : passer dans son dos, marque qui suit puis se fige, saut
  d'ombre), riposte (miroir), ondes à sauter. Sortes : périodique (`every`, × 0,7 en 2e phase), seuil de PV (`at`), à
  l'apparition (`start`), autonome (`passive`). Les 9 mécaniques des boss de zone d'avant sont ces briques avec leurs paramètres
  d'origine : la Survie ne change pas.
- **Lisibilité, jamais de mort en un coup** : toute attaque est annoncée au sol (zone rouge qui se remplit, cercle sûr vert, mur
  rouge de l'arène, orbes visibles) ; un coup d'un boss de la bibliothèque retire au plus **40 %** des PV max du héros
  (`BossLibrary.HIT_CAP`), une zone persistante au plus le tiers par seconde. Annonces courtes au centre de l'écran.
- **Paliers** : Normal / Héroïque / Mythique = PV fixes de la difficulté, mécaniques plus fréquentes (× 1 / 0,85 / 0,72) ; en
  Mythique l'Impatience s'ajoute à tout boss qui ne l'a pas.
- **Donjons à la carte** : un donjon par boss (`Dungeons.catalog`), dans sa zone (mêmes niveaux, difficultés, PE requise et
  ouverture que le donjon de la zone). **Ouverture (lot A2)** : époque I gagnée (`Unlocks` « dungeons »), puis chaque zone quand
  son boss est battu en Survie (les zones d'une époque gagnée d'office) ; jamais de reverrouillage. La Ruée (entrée « rush ») et le
  Siège gardent l'époque II. **Trois salles, aucune de monstres seuls (lot A2)** : 1) **élites à mécanique**, une à la fois avec
  2 monstres d'escorte, la suivante quand elle tombe (`Dungeons.ELITES` 3 + difficulté, une brique de `Tower.ELITE_BRICKS`
  chacune, tirée par donjon, PV × `ELITE_ROOM_HP` 2) ; 2) le **lieutenant** seul (un autre boss de la zone, une seule mécanique,
  25 % × `LIEUTENANT_HP` 3 des PV du boss) ; 3) le **boss**. Durée au pilote (`tools/dungeon_run`, `R_A2.md`) : Normal 3:15 à
  8:30, médiane ≈ 5:50 ; Héroïque et Mythique 3:45 à 9:15, médiane ≈ 4:45. **Farmable à volonté**. Butin : le coffre de set propose **3 pièces de ses 2 emplacements** (le 1er,
  le 2e, puis le 1er), à **sa panoplie**, mythiques ou légendaires (selon la PE, comme avant), et en Mythique une pièce d'armure
  sur quatre est **éveillée** quand le modèle existe ; jamais une pièce déjà possédée. Cristaux et coffres de matières
  (lot E1) inchangés. Chaque panoplie s'obtient aux **9 emplacements** sur ses 6 donjons ; record par boss (`dgb_<boss>_<diff>`).
- **Plans de donjon par boss** (lot A1 de la refonte Aventure) : **48 plans**, un par boss (`plan_<boss>` dans `Profile.plans`),
  **garanti à la 1re victoire contre ce boss** (toute difficulté), jamais en double (`Dungeons.reward` ; sans boss choisi : celui
  d'origine de la zone). Le plan fabrique à l'Atelier (onglet « Plans de donjon », `ui/fabrication_page.gd`) une pièce d'un des
  **2 emplacements du boss**, à **sa panoplie** (arme du type de la classe choisie), **en insignes** (plus en cristaux : les cristaux
  servent la Forge) ; il n'est pas consommé. Niveau = donjon du boss à la **meilleure difficulté finie contre lui**
  (`Dungeons.plan_diff`), mythique, **légendaire après une victoire en Mythique** ; prix = `Economy.base_price` d'une pièce de ce
  niveau et de cette rareté (le prix plein de l'Armurerie : mythique 30 + niveau, légendaire 80 + 2 × niveau ; Normal de Monts
  Calcaires 44, Mythique 260). Page : compteur « x / 48 plans », plans trouvés (emplacement, « Fabriquer · N insignes », ce qui
  manque en rouge), plans des donjons ouverts (« Il tombe en battant <boss> »), les autres en une ligne. **Migration** sans perte,
  paresseuse et idempotente (`Dungeons.migrate_plans`, appelée par la page et par `reward`) : un ancien `plan_<zone>` devient le plan
  du boss d'origine de la zone (`BossLibrary.zone_boss`), qui garde la meilleure difficulté finie dans la zone (record
  `plan_diff_<boss>`) ; un plan inconnu reste tel quel.
- **Page Donjons** (`ui/dungeon_page.gd`) : en haut le donjon choisi (boss, mécaniques avec leur conseil en infobulle, pièces,
  victoires) et sa difficulté (PE requise ou conseillée, estimation, récompenses : cristaux, 3 pièces, son plan à la 1re
  victoire ; lot A2) ; dessous « Je cherche » : filtres **pièce**, **panoplie**, **mécanique**, puis la liste
  (ouverts d'abord, fermés grisés avec leur condition) ; alliés IA ; « Entrer : <donjon> » épinglé. « Rejouer » relance le même boss.
- **État (16/10)** : la Tour (M3), la Ruée et le Siège (M6) passent par la bibliothèque. **Pas encore** : la Survie et le Survivant
  gardent leurs boss (le Survivant leur ajoute des briques aux paliers IV-V, `Survivor.EXTRA_BRICKS`) ; ils passeront par
  `BossLibrary.spawn(id, palier, {director, pos, level, …})` (API dans `conception/nuit_15_10/R_M2.md`). La Tour (M3), la Ruée et
  le Siège (M6) y passent.

## La Tour : types d'étage (passe M3, nuit du 15/10)

Retour du joueur : « les petites vagues de monstres étaient ennuyeuses : des élites au minimum à chaque étage, des étages
de boss, des étages d'"ombres" (une IA qui joue une classe) ».

- **Plan par bloc de 10 étages** (le palier de reprise), fixe pour un bloc donné (`Tower.block_plan`, graine 2026) : place 9
  **halte**, place 10 **boss** ; bloc 1 : **duellistes** aux étages 1, 4 et 7 (ils ouvrent le Duel libre puis la Ligue,
  inchangé) et élites au 5 ; blocs suivants : **2 ombres** (une par moitié, jamais côte à côte), **1 étage d'élites**, **1 étage
  maudit** à partir du bloc 3, le reste en **monstres**. Sur 200 étages : 81 de monstres, 20 d'élites, 18 maudits, 38 ombres,
  3 duellistes, 20 haltes, 20 boss. La page des étages et la fiche montrent le type (icône, légende avec ce qu'il donne).
- **Monstres** : 3 espèces de la zone (4 dès l'étage 40) de rôles différents (`Tower.floor_species` ; rôles et leurs stats du
  composant de P15, `SpawnDirector.role_of` / `apply_role` : tireur,
  chargeur, colosse, essaim, soigneur, mêlée), apparues à tour de rôle en groupes du même côté ; **au moins une élite** à chaque étage
  (une de plus tous les 70 étages), avec **une mécanique propre** : une brique de `BossBricks` (11 au choix : flaques, météores,
  bond, ruée, éventail, couronne d'orbes, ondes, marque, barrière, rage, saut d'ombre), annoncée au sol, coups plafonnés à
  25 % des PV, nom « Yack · Bond », escorte de 2 monstres ; les élites d'un étage lancent leur mécanique à 3,5 s d'écart.
  20 + 0,3 × étage monstres (70 au plus), 10 à 24 en même temps.
- **Élites** : 3 élites à mécanique (une de plus tous les 50 étages), moitié moins de monstres. **Maudit** : Menace (PV × 1,6),
  Rage (monstres enragés) ou Horde (× 1,8 monstres) ; coffre rare au moins et 4 cristaux × (difficulté + 1) en plus.
- **Ombres** (`ClassRival`, le moteur des duellistes) : une classe de la liste (les 60, celles de base d'abord) ; **une sur
  quatre est « ton ombre »** (ta classe, les sorts de ton préréglage, ton équipement) ; en Hardcore dès l'étage 100 (Difficile
  dès le 150), une sur deux est **éveillée** : un cerveau d'IA figé (`pantheon_<palier>.json`) dans un héros équipé comme l'ombre
  scriptée de l'étage (PV × 0,5 des siens, soins moitié moins : il esquive et se soigne mieux), repli sur l'IA scriptée s'il
  manque. IA un cran plus dure aux étages 80 et 150 ; PV × 3 et dégâts × 1,8 de ceux d'un duelliste (dont les PV doublent : 0,9,
  ils tombaient en 8 s au pilote). Nom « Ombre · Mage »,
  barre de vie, coups annoncés au sol, aide limitée à « Assisté » comme en duel.
- **Boss** (`Tower.boss_id`) : un des 6 boss de la zone de l'étage (bibliothèque M2), jamais le même deux fois dans la zone ;
  le dernier boss de chaque zone est son **gardien** (le boss d'origine). PV **fixes** (P11) : boss de donjon Normal de son
  niveau × 0,8 × `BOSS_CURVE` (1 jusqu'à l'étage 50, 5 au 70, 5,5 au 100, 9 au 130, 7 au 200 : l'équipement attendu monte)
  × difficulté ; palier des mécaniques 0 / 1 / 2 selon l'étage (± 1 en Facile / Hardcore). Pas de renforts génériques.
  Monstres, élites et ombres des étages hauts : PV × √courbe, dégâts × courbe^0,6.
- **Halte** : 60 % des PV rendus, une carte, puis le coffre ; aucun combat. Entre deux étages : 50 % des PV rendus (avant 35 %).
- Inchangés : une seule vie, reprise par paliers de 10 (kit complet + cartes), 4 difficultés, cristaux 3 à 6 par étage, gemmes
  tous les 10, forge tous les 50, apparences aux étages 50 / 100 / 150 / 200, maîtrise. Bilan : héros battus, boss vaincus,
  cristaux des étages maudits. Mesures : `tools/tower_run.tscn` (rapport `conception/nuit_15_10/R_M3.md`).
- **Équilibre entre classes (passe M8, `R_M8.md`)** : la Tour se joue seul ; les classes dont le kit soigne, protège ou
  renforce y tuaient un boss deux à trois fois moins vite qu'un mage. **Dégâts × un facteur par classe** dans la Tour
  seulement (`TowerBalance.solo_mult`, `data/tower_solo.json`, jamais en Donjon, Ruée ou Siège) : temps pour tuer mesuré des
  60 classes (boss des étages 30, 50 et 100, sans mécaniques, équipement attendu), à son pire boss, ramené à 1,1 fois la
  médiane ; jamais de baisse, au plus × 1,8 (33 classes aidées, Barde × 1,54). Régénérer : `tools/m8_matrix.py solo`.
  **Coups de boss plafonnés à 25 % des PV max** dans la Tour (`Tower.BOSS_HIT_CAP`, 40 % ailleurs) : une seule vie, seul,
  et le corps à corps passe le combat dans les zones du boss. `BOSS_FLOOR_ADJ` : étage 100 × 0,7 (médiane 2 min 47 au
  pilote, deux fois les boss voisins), étage 150 × 2,5 (13 s à 2 min 20 avec l'équipement de l'époque IV, médiane 43 s).
  Un boss sorti de la salle (il tombait sans fin, intouchable) revient au centre (`TowerDirector._rescue_boss`, aussi en
  Donjon, Ruée et Siège). Bornes vérifiées par `test_m8` (écart max / min ≤ 2,5 aux boss de référence).

## Ruée des boss et Siège sur la bibliothèque (passe M6, nuit du 15/10)

Retour du joueur : le Siège Normal fait, un Mythique tenté « vraiment dur, logique : je n'avais pas la puissance ». La difficulté
doit se lire avant de lancer ; la Ruée et le Siège puisent dans la bibliothèque de boss.

- **Ruée** (`core/rush.gd`, `core/rush_director.gd`) : **8 boss tirés** dans la bibliothèque, un par zone dans l'ordre des zones
  (niveau croissant en Normal et Héroïque ; en Mythique, tous niveau 90, PV × 0,8 → × 1,2 du 1er au 8e). Le tirage varie les
  mécaniques (deux boss qui se suivent ne partagent pas de famille quand la zone le permet ; les boss du tirage précédent sont évités)
  et se fait à partir d'une **graine affichée** (« tirage n° 4821 ») : il reste le même tant que la Ruée n'est pas vaincue (on
  réessaie les mêmes boss), « Nouveau tirage » en donne un autre, une Ruée vaincue aussi. PV fixes du palier (P11, × 0,6), sans
  renforts génériques ; carte et 50 % des PV entre deux boss. HUD : « Boss 3/8 », sous-ligne « Ensuite : Buster ».
- **Modificateurs de la Ruée** (au choix, gardés) : *Sans répit* (aucun soin entre deux boss, cristaux +30 %), *Boss enragés*
  (dégâts × 1,25, mécaniques × 0,85 d'intervalle, +40 %), *À l'aveugle* (boss à venir cachés sur la page et au HUD, +15 %).
  Récompenses inchangées sinon (lot E1 : cristaux, parchemins, pierres et gemmes du niveau du dernier boss, coffre d'équipement,
  apparence la 1re fois, titre), cristaux × (1 + bonus). Bilan : les boss vaincus et les modificateurs.
- **Siège** : le **boss du jour** de la zone (un des 6 boss de la bibliothèque, change chaque jour, PV × 3,2 d'un boss de donjon)
  et un **lieutenant** par vague d'élites (vagues 3 et 5 : un autre boss de la zone, une mécanique, 0,4 × les PV d'un boss de
  donjon). Vagues en **escouades par rôle** (composant de P15 : compositions débloquées vague après vague, jamais plus de 3 fois la
  même espèce, tireurs et soigneurs en retrait) qui arrivent du bord de l'arène à l'angle d'or, arrivée dans le dos signalée ; un
  **événement annoncé** par vague (tenaille, encerclement aux cercles orange, ruée d'essaim, élite escortée, tenaille : les vagues
  d'élites ont un événement léger, leur lieutenant fait le pic).
  Alliés IA en comportement d'équipe (M7 : ils lisent les zones rouges, se replient sous 30 % de PV) — aussi en Donjon et Ruée.
- **Objectifs du Siège** (une étoile chacun, retenues par zone et difficulté) : *Le boss tombe*, *Personne ne tombe* (aucun allié
  à terre avant la chute du boss ; sous-ligne du HUD « alliés 2/2 »), *Avant sa fureur* ; les deux derniers ajoutent chacun
  +25 % de cristaux au siège.
- **Lisibilité de la difficulté** (`ui/difficulty_panel.gd`, pages Ruée et Siège) : « PE requise · la tienne » (ou « PE
  conseillée » en Normal) sur une jauge, une **estimation** — *Facile* (≥ 1,35 × la PE conseillée), *Équilibré* (≥ 0,95),
  *Difficile* (≥ 0,7), *Hors de portée* —, les **récompenses** de la difficulté et, si elle est trop haute, un avertissement d'une
  phrase. La difficulté reste permise (mode dev compris). PE conseillée = `ADVISED` × PE attendue du niveau (au moins la requise),
  mesurée au pilote (`tools/m6_run.tscn`, `R_M6.md`) : Ruée [1,3 ; 3,7 ; 3,4], Siège [1,3 ; 4,1 ; 3,6] — « Équilibré » avec
  l'équipement de l'époque II gagnée en Normal, au verrou de PE en Héroïque, avec l'équipement complet optimisé en Mythique (le
  verrou seul y est « Difficile »). Verrous et PV inchangés (le Normal passe à l'ouverture, l'Héroïque au verrou). Ruée au pilote :
  10 à 15 min en « Équilibré », 5 min en « Facile », 30 à 40 min en « Hors de portée ».

## Battle royale (passe M1, 0.1.201 ; mode codé en 0.1.161, idée 9 de `conception/IDEES_EN_VRAC.md`)

- 8 héros nus au niveau 1, chacun pour soi, dernier debout. **9 min 50** d'anneau en 5 resserrements (`Royale.PHASES` :
  rayons 190 / 130 / 80 / 42 / 14 m, dégâts hors anneau 2 → 20 % des PV par seconde), puis 30 s de mort subite.
- **Mode scellé** (lot H2) : aucun talent, certificat, archive ni aura du compte ; le kit entier et toutes les cartes (voir « Niveau de héros »).
- Niveaux : coffres (0,55 / 0,85 / 1,3 / largage 2 niveaux), cristaux (0,1 ; une vingtaine sur la carte : plus aucune jarre, caisse ni tas d'or, passe BR2), élimination (25 % des PV
  et de l'expérience selon l'écart de niveau, lot BR1 : 1 niveau entre égaux, ± 0,15 par niveau d'écart avec la victime, de
  0,2 à 2 ; `Royale.kill_xp`). Les héros scriptés gagnent exactement la même chose que le joueur, y compris quand ils
  éliminent le joueur (avant BR1 : rien).
- **Niveau maximal par anneau (lot BR1)** : 14 / 20 / 26 / 32 / 36 puis 40 (`Royale.LEVEL_CAPS`, annoncé à chaque nouvel
  anneau, « niveau 12 / 14 » dans les objectifs) ; l'expérience au-delà est perdue. Mesure avant (6 parties au pilote) :
  scriptés jusqu'au niveau 21-23 et pilote jusqu'à 25 avant le 2e resserrement ; un scripté à 23 puis 29 en éliminant
  deux héros 12 et 16 niveaux plus faibles. Après : 20 au plus avant 285 s, vainqueurs au niveau 17-32 (19-40 avant).
- **Réapprovisionnement** : 3 coffres par héros en vie (22 au plus) tombent dans l'anneau à 50 s puis à chaque resserrement et à chaque nouvel anneau,
  plus souvent dorés à chaque vague. **Largage** : à chaque resserrement sauf le dernier, un coffre de 4e qualité (rareté 4-5,
  carte sûre) tombe 15 s plus tard dans le prochain anneau (pilier doré, étoile sur la carte, visible de partout).
- **Mis à prix** : le héros qui compte le plus d'éliminations (3 au moins) est visible de tous sur la carte ; l'éliminer
  rapporte un niveau de plus (en plus de l'élimination) et une potion.
- Héros scriptés (`RoyaleDirector.BRAIN`, par difficulté) : trajet à la vitesse d'un joueur qui esquive (Hardcore ≈ 11 m/s),
  coffres choisis par valeur / trajet, attaque seulement avec l'avantage (rapport PV × frappe, exigence qui baisse à chaque
  anneau), fuite s'il est dépassé et a de quoi boire, traque des affaiblis à partir du 3e anneau.
- Duel entre héros (lot BR1, retour du joueur : « deux niveau 9, 2 000 PV, coups de 10 à 50 : interminable ») : échelle
  des dégâts 0,055 (0,04 avant) et plafonds du duel équipé (critiques ×2 au plus, dégâts +100 %), `ModeRules.ROYALE` ; les
  autres modes gardent leurs profils. Deux scriptés de même niveau (`tools/royale_duel_probe`, 8 paires, Hardcore, niveaux
  1 / 9 / 20 / 40, nus à légendaires +10) : médianes 17-41 s → 17-31 s ; combats entre héros d'écart ≤ 2 niveaux en partie :
  médiane 22 s (4 à 58 s) → 14 s (4 à 30 s).
- Tirage des sept héros scriptés : jamais la Lame noire ni la Lame de lumière (`Royale.AI_EXCLUDED`, retour du joueur).
- **Largage (lot BR4, 0.1.217, retour du joueur : « plus de spawn fixe, comme Fortnite »)** : `core/royale_drop.gd`. Plus de
  point d'apparition ni de compte à rebours : les 8 héros sont à bord d'un aigle géant qui traverse la carte en ligne droite
  d'un bord à l'autre (direction et décalage tirés à la graine, 95 m au-dessus du point le plus haut, 30 m/s : 15 à 22 s de
  vol ; ligne en pointillés et aigle sur la mini-carte, vue large pendant le vol, coffres visibles à 200 m). Portes ouvertes
  après `Royale.COUNTDOWN` (3 s) ; [Sauter] saute, saut automatique en fin de vol. Chute libre dirigée (17 m/s à
  l'horizontale, 16 m/s de chute, [Esquive] maintenue : piqué à 34 m/s) ; le planeur s'ouvre seul à 26 m du sol ([Sauter]
  l'ouvre plus tôt : 6 m/s de chute, 12 m/s à l'horizontale) ; l'atterrissage rend la main. **Personne n'attaque ni n'est
  attaquable en l'air** (hors du chacun pour soi jusqu'au sol) ; rien ne s'ouvre ni ne se casse sous un héros en l'air.
  Les héros scriptés et le pilote automatique visent chacun un coffre à portée de chute (55 m au moins entre deux
  cibles, les dorés d'abord), leurs sauts répartis sur le vol (tôt, au milieu, tard). Ceux qui ont atterri pillent et se
  battent déjà ; **l'anneau et le temps de combat (`elapsed`) ne partent qu'à l'atterrissage du dernier** (au plus tard 20 s
  après la fin du vol : les retardataires sont posés). Les coups et le fil des éliminations suivent l'horloge totale (`clock`).
- **Réanimation (lot BR4)** : un héros éliminé dans les **2 premières minutes de combat** (`Royale.REVIVE_WINDOW` 120 s)
  revient une fois, 5 s plus tard (« Tu es éliminé : retour dans N s »), planeur ouvert au-dessus d'un point de l'anneau
  (le prochain s'il se resserre) le plus loin possible des héros en vie, PV pleins, **invulnérable 4 s** après l'atterrissage.
  Il garde son niveau, son arme, ses sorts et ses cartes ; ses pièces sont tombées au sol à sa chute (il repart avec l'arme
  seule). Il n'a pas de place tant qu'il doit revenir (compté en vie). Chaque héros ne compte qu'**une fois** au compteur
  d'éliminations (sa première chute) ; l'expérience et les PV de l'élimination sont donnés à chaque fois. Même règle pour
  les héros scriptés. Après 2 min, ou à la 2e chute : mort définitive.
- Éliminé : on regarde la fin (spectateur) ou on ouvre le bilan ; la place est fixée à la mort. **Lot BR-I2** : un
  récapitulatif s'affiche (qui t'a éliminé, classe et niveau, coup de grâce et ses dégâts, PV qui lui restaient, tes dégâts
  donnés / reçus, temps survécu ; « Regarder » / « Bilan ») ; le spectateur suit le tueur, LB / RB (◀ ▶ au clavier) change
  de héros, [F] son équipement. Tombé avant 2 min : le récapitulatif dit « Retour dans N s » (plus de ligne dans le fil).
- **Lieux nommés (lot BR-I2)** : 6 à 8 par carte (`ProcMap.places`, `RoyaleDirector.places()`), chacun autour d'un décor
  (ruines, tour, arche, ossements, mine, campement, marché) avec un nom français (« Ruines du col », « Mine d'éclats »…),
  une richesse ★ / ★★ / ★★★ (un ★★★, trois ★★, le reste ★) et ses coffres en couronne (lot BR-R1 : ★ : 4 dont 1 rare ; ★★ : 6 dont
  2 rares et 1 doré ; ★★★ : 9 dont 3 rares et 2 dorés), **pris sur les 64 coffres de la carte : mêmes totaux** (38 / 18 / 8).
  Du **couvert** dans chaque lieu : deux murets et un gros rocher (deux rochers au large des ruines), jamais cassables.
  Atterrir dans un lieu l'annonce (« Tu atterris aux Ruines du col »).
- **Équipement (lot BR3, 0.1.216, retour du joueur : « je ne veux pas qu'elles changent », « finir avec 5 arcs »)** :
  `core/royale_loot.gd`. L'arme de départ (une des deux variantes de l'arme de la classe) est **gardée toute la partie** :
  aucun coffre ne propose d'arme. Un coffre propose d'abord **une pièce par emplacement vide** (3 au plus, emplacements
  différents, de la qualité du coffre) ; une pièce posée reste. Tant que l'équipement est incomplet, une pièce pour un
  emplacement pris n'apparaît que si elle est **nettement meilleure** (note de classe × 1,3 et + 0,6). **Équipement complet**
  (les 9 emplacements, cape comprise) : le coffre ne propose plus que des **améliorations de pièces portées**.
- Pièces et améliorations = **celles du Survivant** (mêmes cartes, même rendu) : une pièce de coffre devient une pièce du
  Survivant (`SurvivorGear.adopt` : jet 100-120 %, passif fixe de son modèle, puissance au niveau du héros) ; amélioration
  +2 (+4 en légendaire) jusqu'à +10, passif tiré et montré aux paliers +6 / +8 / +10, jet relevé dès rare ; l'amélioration
  de l'arme porte aussi celle de l'auto-attaque. Rareté des améliorations par coffre : bois / argent / or / largage =
  chance 0 / 0,3 / 0,6 / 1,2, au moins commune / commune / rare / épique. Passifs sans objet ici (Cadavres explosifs,
  Aimant ; lot BR-I2 : tous ceux qui parlent de monstres ou d'élimination, Élan meurtrier, Œil du chasseur, Exécuteur,
  Lame statique, Éclat glacial, Lame du phénix) bannis d'office, en pièce comme en carte de niveau. Relance : une par coffre ; ni « Passer », ni bannir, ni garder (propres au Survivant).
- Montées de niveau : sorts et bonus seulement (aucune carte d'arme ni de pièce, plus de technique d'arme : elle vient de
  l'amélioration de l'arme) ; l'amélioration de sort est celle du Survivant (niveau 1 à 10, niveau 5 au moins épique, 10
  légendaire).
- Héros scriptés : même remplissage (un emplacement vide par coffre), puis améliorations internes (mise à niveau, rareté,
  forge +N : leurs pièces ne suivent pas leur niveau), l'option au plus grand gain de note ; jamais deux armes ni une pièce
  moins bonne. Lot BR1 : leurs pièces comptent en entier (`Royale.AI_GEAR_SCALE` 0,62 → 1)
  et leurs PV et leur attaque prennent +5 % par niveau au-delà du 3e (+25 % au plus, `Royale.ai_level_factor`), l'équivalent
  des cartes de montée de niveau qu'ils ne tirent pas : au même niveau, leur force √(PV × frappe) face au joueur au pilote
  revient à celle de 0.1.214 (Hardcore 1,1 / 1,2 / 1,1 aux niveaux 1-5 / 6-10 / 11-15 ; Normal 0,7 / 0,7 / 0,7), elle
  était tombée à 1,0 / 0,9 / 0,8 et 0,6 / 0,5 / 0,5 avec les cartes du Survivant (lot BR3).
- **À la mort** (joueur compris) : toutes les pièces **sauf l'arme** restent dans la **dépouille** du héros (lot BR-I2 : un
  seul sac, un seul faisceau à la couleur de sa meilleure pièce, au lieu d'une colonne par pièce). [F] « Fouiller » ouvre la
  **fenêtre de pile** : ses 9 emplacements, ▲ / ▼ face à ta pièce, « Prendre » (la pièce est portée, la tienne rejoint la
  dépouille : au plus une pièce par emplacement) et « Tout le meilleur » (X, [G] : toutes celles qui battent les tiennes).
  Un héros scripté s'arrête pour une pièce meilleure que la sienne dans une dépouille à moins de 35 m dans l'anneau.
- **Inspection** : la même fenêtre sert de fiche (dépouille vide, héros suivi en spectateur : 9 emplacements, carte de chaque
  pièce comparée à la tienne, « dans sa dépouille » / « déjà prise » / arme gardée). Jeu en pause pendant la fenêtre (partie
  solo, comme le choix de carte) ; B / Échap la ferme.
- **Bilan v2 (lot BR-I2)** : bandeau incliné « N°1 · Victoire ! » ou « Place N », confettis à la victoire, tuiles (place,
  éliminations, dégâts, niveau, coffres, durée), chronologie de la partie (saut, 1re élimination, largage, mise à prix,
  retour, fin : `Royale.stats`), Gagné / Gardé (dont le coffre d'apparence), « Rejouer » et « Menu principal ».
- **Couleurs (lot BR-I2)** : coffres au code de rareté de la Bible (commun lilas-gris, rare lagon, doré soleil, largage soleil
  clair), les mêmes sur la mini-carte ; plaques des scriptés en PV (plus de pourcentage).
- **Page du mode v2 (lot BR-R1, `ui/royale_page.gd`)** : la partie (Classique, Du jour, Personnalisée) et une carte qui dit le
  modificateur en une phrase, les adversaires en pastilles, les règles en quatre lignes (détail en infobulle), la Ligue royale de la
  saison, la carrière (parties, victoires, podiums, meilleure place, éliminations, record, dégâts, gardiens, classe la plus gagnante),
  les apparences du mode ; « Lancer » épinglé. Tient dans 1280×720 et 1600×900 (la page défile).
- **Modificateurs (lot BR-R1, `core/royale_mods.gd`)** : un « du jour » qui tourne chaque jour (jamais deux fois de suite), la partie
  classique toujours là. Pluie de météores (2 zones fraise toutes les 9 s près de héros tirés au hasard, 1,8 s d'annonce, 12 % des PV
  max, l'esquive passe), Ruée vers l'or (chaque coffre monte d'une qualité), Anneau pressé (attente × 0,55, resserrement × 0,8 :
  6 min 08), Sources de vie (12 fontaines au lieu de 4), Chasse ouverte (tous les héros sur la carte, +0,5 niveau par élimination,
  traque dès le 2e anneau). Les scriptés sortent des zones (selon la difficulté), vont boire blessés, traquent plus tôt. Annoncé au
  départ, sur la carte du vol et dans l'objectif. Aucun réglage de combat ne change.
- **Autel du gardien (lot BR-R1, `core/royale_event.gd`, événement de milieu de partie)** : au 2e anneau, un autel s'éveille dans la
  zone qui restera sûre jusqu'au 4e (pilier mandarine, losange sur les cartes, annonce). Un gardien (héros scripté plus grand,
  niveau médian des vivants + 3, PV × 3,2, attaque × 0,55) ne quitte jamais l'autel (13 m, cercle au sol) et se remet quand personne
  n'est là : l'ignorer ne coûte rien. L'achever : un niveau et le trésor de l'autel (coffre de largage) posé sur place, que tout le
  monde peut venir prendre. Au resserrement du 4e anneau, s'il tient encore, il s'en va et laisse le trésor. Les scriptés y vont
  s'ils sont en forme et de taille (le Facile seulement s'il passe à côté). Hors du compteur des héros ; « Gardien » dans la chronologie.
- **Ligue royale (lot BR-R1, `core/royale_league.gd`)** : une saison par mois, des points à chaque partie classée (place + 2 par
  élimination, 5 au plus, × 0,5 / 0,75 / 1 / 1,25 selon la difficulté ; jamais perdus, aucune connexion demandée), Bronze, Argent
  (30), Or (80), Platine (150). Chaque rang atteint dans la saison : un coffre d'apparence (rare, épique, légendaire), une fois par
  saison ; la 1re fois : un titre (« Voltigeur d'argent / d'or / de platine »). Les parties personnalisées ne comptent pas.
- **Apparences du mode (lot BR-R1, `core/royale_looks.gd`)** : 8 voiles de planeur et 4 traînées de chute gagnées en jouant (parties,
  podium, éliminations, victoires, rangs de la Ligue), choisies à la page du mode ; la **couronne** du vainqueur se porte pendant la
  partie qui suit une victoire. Rien ne change le combat.
- **Remercier l'aigle** : à bord, [Interagir] (LB sur la carte du vol) : « Merci l'aigle ! », une ligne au fil ; des scriptés le font
  aussi ; petite fête au saut (« Hop ! »).
- **Partie personnalisée** : modificateur et graine au choix (même graine : même carte, mêmes adversaires, même anneau), sans ligue,
  ni insignes, ni maîtrise, ni quête, ni record. **Défis du mode** dans les quêtes : atterrir dans un lieu ★★★, éliminer le mis à prix,
  vaincre le gardien, gagner sans réanimation.
- **Densité mesurée (lot BR-R1, `tools/royale_games.py`)** : voir `conception/royale/R_BRR1.md`.

## L'Échiquier (autochess, `conception/autochess/SPEC.md` ; entrée et fin : lot AC-I, rapport `conception/autochess/R_AC_I.md`)

Les règles de la partie (8 stratèges, boutique, étoiles, traits, atouts, objets, combats) sont celles de la SPEC et des
rapports `R_AC_*` ; ici, ce que le mode est dans le jeu.
- **Activité** « L'Échiquier » (`Activities.LIST`, rangée Affrontements, **en tête** : seule activité de la rangée ouverte sur
  un compte neuf). Ouverte dès le départ, **scellée** (`Modes.sealed()` pendant la partie) : rien du compte n'y change la
  force, et rien de la partie ne touche au compte. Pastilles : apparences, titres.
- **Page du lobby** : le mode en trois lignes, la difficulté des sept stratèges IA (Recrue, Vétéran ouvertes ; Champion
  après un top 4 en Vétéran ; Légende après une victoire en Champion ; mode dev : tout), les coffres de la difficulté
  (✔ gagnés), les exploits (au survol), les records (parties, top 4, victoires, meilleure place), une graine facultative
  (même graine : mêmes boutiques, mêmes adversaires), Lancer ; **Reprendre la partie** quand une partie est gardée
  (`user://autochess_save.json`, écrite au début de chaque préparation) ; « Nouvelle partie » demande alors confirmation.
- **Fin de partie** : le bilan commun (`ResultsPanel`) : place, manches, dégâts de tes héros, meilleure unité, durée ; « Gagné »
  (coffres, titres) ; Rejouer (même difficulté), Statistiques (bilan détaillé de la partie), Retour au lobby.
- **Récompenses** (`core/autochess_rewards.gd`, seulement des apparences et des titres) : top 4 -> coffre d'apparence commun,
  top 2 -> rare, 1re place -> mythique (légendaire en Champion et Légende) + titre de victoire (Stratège, Tacticien,
  Grand tacticien, Maître de l'Échiquier), **une fois par difficulté** ; ensuite au plus un commun (top 4) et un rare (top 2)
  par jour, toutes difficultés. Titres d'exploit, une fois : Trois étoiles (unité de coût 4-5 à ★3), Pur sang (trait de
  famille à 9), Invaincu (victoire à 70 PV ou plus), Frugal (victoire sans actualiser la boutique). Abandon : la place du
  moment, comptée seulement à partir de l'étape 4 (sinon ni coffre ni quête). Élimination : la partie gardée est effacée.
  Ni insignes, ni maîtrise, ni matières, ni XP de héros.
- **Hub intact** : instantané de la progression du compte au lancement (`Survivor.HUB_KEYS`), remis avant d'écrire les
  récompenses (comme le Survivant).
- **Quêtes** : `ac_top4` (finir dans les 4 premiers), `ac_rounds` (manches gagnées), `ac_win` (hebdomadaire) ; récompense
  d'apparence seulement (`Quests._roll_reward`, comme le Survivant).
- **Fiches** (à la 1re rencontre, dans l'écran du mode) : « Achète et place » (boutique, intérêts), « Trois copies, une
  étoile », « Traits et atouts » ; rangées au Guide, chapitre Modes, sous L'Échiquier.

## Les Deux Voies (étude `conception/benchmark/MOBA.md`, en cours : lots MB-A à MB-K)

Mode scellé, 4 contre 4 joué seul contre des IA scriptées, sur une carte à deux voies et une jungle : détruire le Cœur adverse.
Les règles complètes sont celles de l'étude (§ 7) ; ici, ce qui est codé (le mode reste « Bientôt » tant qu'il n'est pas jouable
de bout en bout).
- **Règles** (lot MB-A, `R_MB_A.md`, `core/moba_data.gd`) : niveaux de partie 1 à 12 (fiche d'un héros de la classe au niveau 30 à
  85) ; XP 120 à 520 par niveau ; or de départ 500 puis 2 par seconde ; réapparition 7 à 29 s (plus longue dès 15:00, encore plus
  à la Marée de 18:00) ; vagues toutes les 30 s dès 0:40 ; Gardien 3:00, Colosse 9:00, fin au temps 25:00. Les sbires et les tours
  suivent la partie : leur force est une part de celle d'un héros au niveau attendu à cet instant. 40 objets en boutique (une phrase
  par objet, les chiffres en infobulle).
- **Kits** : chaque classe joue 3 sorts + un ultime tirés de ses propres sorts (un déplacement, un contrôle et, pour la Ferveur, un
  soin quand la classe en a), avec leurs enchaînements ; l'ultime recharge en 60 à 90 s et frappe plus fort.
- **Carte** (lot MB-B, `R_MB_B.md`) : aire de 200 × 120 m fermée par des coteaux boisés ; bases aux deux bouts (sol et liseré aux
  couleurs de l'équipe) ; Voie du Soleil en haut, Voie des Brumes en bas (30 s de Cœur à Cœur en courant) ; jungle de rochers, arbres
  et buissons ; rivière au gué partout praticable, avec la fosse du Colosse côté Soleil et celle du Gardien côté Brumes ; 4 camps par
  moitié. La carte est la même à chaque partie, en miroir : chaque équipe a la Voie du Soleil en haut.

- **Tours, Cœur et sbires** (lot MB-C, `R_MB_C.md`) : toutes les 30 s, chaque voie reçoit 3 sbires mêlée et 2 tireurs (un bélier
  une vague sur 3, puis sur 2 dès 12:00 ; un géant de plus quand la T2 d'en face est tombée). Une tour tire sur les sbires d'abord,
  puis sur les héros, et sur le héros qui frappe un de ses héros ; ses tirs de suite sur un même héros font de plus en plus mal. Sans
  sbire ennemi près d'elle, une structure ne prend qu'un tiers des dégâts ; une T1 prend moitié moins avant 4:00 ; la T2 ne peut pas
  être touchée tant que la T1 de sa voie tient, ni le Cœur tant que ses deux T2 tiennent. Hors combat, une structure se répare
  doucement jusqu'au haut du tiers de PV où elle est : une poussée tenue gagne des tiers pour de bon, un sbire égaré ne l'use pas.
  Des vagues égales ne font tomber aucune tour en 20 min ; des sbires 20 % plus forts font tomber la première tour vers 9 min.
  Détruire le Cœur gagne ; à 25:00, le plus de structures détruites l'emporte.
- **Héros en partie et boutique** (lot MB-D, `R_MB_D.md`) : chaque héros monte du niveau 1 à 12 avec l'XP des sbires proches, des
  éliminations et du temps ; aux niveaux 2-4 puis 6-8 il choisit (sans que le jeu s'arrête) quelle case reçoit un enchaînement ;
  l'ultime arrive au niveau 5. L'or vient du temps, des sbires (tout au dernier coup, une bonne part aux alliés proches), des
  éliminations (prime plus grosse sur une série), des aides et des tours. La boutique ouvre à la fontaine et pendant la mort :
  6 places, une paire de bottes, les recettes ne coûtent que la différence, un achat s'annule tant qu'on reste à la base, une vente
  rend 70 %. Les objets valent pour le joueur comme pour les IA. Rappel : 6 s sans bouger ni être touché.
- **Jungle et objectifs** (lot MB-F, `R_MB_F.md`) : dès 1:30, 4 camps par moitié (Source, Braise, 2 petits) ; un camp ne frappe
  que ceux qui l'ont frappé et revient à son point, PV pleins, si on l'entraîne trop loin. Source : recharges plus rapides 90 s ;
  Braise : les coups brûlent et ralentissent 90 s ; éliminer un héros qui les porte les lui prend. Gardien (3:00, revient 3 min après)
  et Colosse (9:00, revient 4 min après) : boss de la bibliothèque avec leurs mécaniques, tirés à chaque partie ; le Gardien donne un
  Sceau à l'équipe (un peu plus de dégâts et de PV pour toute la partie, 3 au plus), le Colosse la Bannière (150 s : les sbires
  proches des porteurs grandissent et frappent plus fort, rappel en 3 s) ; le Colosse s'impatiente si le combat dure. Marée finale à
  18:00 : un géant de plus par vague, les Cœurs deviennent vulnérables. À 25:00 : structures détruites, puis Cœur le moins entamé,
  puis objectifs pris, puis or.
## Le Colisée (étude `conception/benchmark/ARENA.md`, en cours : lots CO-A à CO-L)

Mode scellé, joué seul contre des IA scriptées : 6 trios (Classique ; Éclair 4 trios ; Grand tournoi 8 trios si la sonde de
performances le permet), une seule couronne. Les règles complètes sont celles de l'étude (§ 6) ; ici, ce qui est codé.
- **Partie** (lot CO-A, `R_CO_A.md`) : 100 PV par équipe ; une manche perdue coûte 20 (manches 1-3), 25 (4-6), 35 (7-9), 50 (10-11),
  puis 100 (mort subite à la manche 12 : la partie finit au plus tard là) ; Éclair 25 / 35 / 50 / 100 dès la manche 7. On ne revoit
  pas une équipe avant d'avoir vu toutes les autres encore en lice (sauf quand les éliminations le rendent impossible : le moins
  possible). Nombre impair : une équipe exempte, jamais deux fois de suite. Égalité au temps (85 s) : l'équipe qui garde la plus
  grande part de ses PV gagne ; égalité exacte : les deux perdent la moitié. Places 1 à 3 = victoire. Partie médiane simulée :
  18,9 min (Classique), 11,8 min (Éclair).
- **Trios** : trois familles différentes, aucune classe deux fois dans la partie ; héros à la fiche « à l'arme » niveau 60 ; ton
  équipement, ton or et ton sac sont mis de côté pendant la partie (rien du compte n'y change la force).
- **Arènes** (lot CO-B, `R_CO_B.md`) : une par combat, cuvettes plates de 24 m de rayon séparées par des falaises ; 4 piliers pour
  s'abriter des tirs, 1 ou 2 **fleurs de vie** (15 % des PV et une barrière de 4 s au premier qui passe, repousse en 20 s). **Anneau de
  feu** : 22 m, puis 16 m à 25 s, 11 m à 40 s, 6 m à 55 s, 3 m à 70 s ; chaque resserrement est annoncé 4 s avant (prochain anneau en
  pointillés) ; dehors on perd 5 % de ses PV par seconde, un peu plus à chaque seconde, et les soins reçus sont divisés par deux.
- **Combats** (lot CO-C, `R_CO_C.md`) : à chaque manche, tous les combats se jouent en même temps, chacun dans son arène ; on regarde
  le sien (les autres se jouent pour de vrai, sans rien montrer). Un combat finit quand un trio est à terre, ou à 85 s. Si tu tombes,
  tes alliés continuent et la caméra les suit ; ton combat fini, elle passe à un combat encore en cours. Le **Grand tournoi** (8 trios)
  est ouvert : la mesure de performances le permet (24 héros aussi fluides que 18).
- **Atouts** (lot CO-E, `R_CO_E.md`) : 32, en trois raretés (Argent, Or, Éclat) ; offres aux manches 1, 4, 7 et 10 : trois cartes de la
  même rareté, aux thèmes différents, choisies parmi les mieux notées pour ta classe (jamais une carte faite pour un autre rôle) ;
  3 relances pour la partie (une carte à la fois), 6 atouts au plus ; au temps écoulé, la mieux notée. Braise, Givre et Foudre fusionnent
  en **Tempête** (leurs effets × 1,5, deux places libérées). Garde-fous : bonus de dégâts cumulés × 1,6 au plus, dégâts reçus × 0,75 au
  moins, PV en plus + 70 % au plus, et les plafonds du coup (15 %) et de la rafale (35 % sur 2 s) après. Relève éclair attend la relève.
- **Or, enclumes, sorts** (lot CO-F, `R_CO_F.md`) : 10 or par manche, +3 pour une victoire, +2 par K.O. (3 au plus) ; enclume de stat (6),
  de pièce (12 : un emplacement vide d'abord, jamais d'arme), de panoplie (20, offerte à la manche 3), d'éclat (offerte à la manche 9 :
  pièces légendaires) : on garde une option parmi trois. Revente au prix payé pendant la préparation, à moitié ensuite ; un bonus
  de stat s'annule pendant la préparation. Un sort de plus aux manches 3 et 6 (un parmi trois de ta classe, en enchaînement d'une touche).

## L'Assaut (étude `conception/benchmark/TACTIQUE.md`, en cours : lots TAC-0 à TAC-14)

Mode scellé, 4 contre 4 (toi et 3 alliés IA contre 4 IA) : l'Attaque pose une Charge sur l'un de deux sites, la Défense l'en
empêche ou la désamorce ; une vie par manche, or entre les manches. Ce qui est codé (lot TAC-0, `R_TAC_0.md`) :
- **Partie** : premier à 7 en 12 manches, mi-temps après 6 (on change de côté, 800 d'or chacun) ; à 6-6, prolongation par blocs
  de 2 manches à 4 000 d'or fixes jusqu'à 2 manches d'écart, puis une manche décisive. Format Éclair : premier à 4 en 7 manches.
- **Manche** : 20 s d'achat (25 à la 1re de chaque moitié), 1:40 de manche ; pose 4 s immobile dans un site, mèche de 40 s,
  désamorçage 7 s avec un point de sauvegarde à la moitié. Une équipe à terre perd (après la pose, l'Attaque à terre laisse
  encore la Défense désamorcer) ; au temps, la Défense gagne.
- **Or** : victoire 2 400 ; défaite 1 500, 1 900, 2 300 puis 2 700 (une victoire fait redescendre la série d'un cran) ;
  élimination 200, aide 50 ; pose +300 à chaque attaquant ; désamorçage +200 ; un attaquant vivant quand le temps s'écoule sans
  pose n'a pas de prime ; plafond 7 000.
- **Héros** : niveau 50, l'arme de la classe, aucune pièce ni talent ; 4 sorts (kit provisoire, kits tactiques au lot TAC-4).
- **Carte « Le Bourg aux lanternes »** (lot TAC-1) : 84 × 100 m, deux sites (A au nord-ouest avec la terrasse du beffroi à +3 m,
  B au nord-est sous le balcon à +2,5 m), une place à fontaine, une halle et son passage, des maisons qui coupent la vue,
  des murets (on voit par-dessus, les coups au sol s'y arrêtent ; depuis une terrasse on tire par-dessus), deux carrés de
  hautes herbes. Trajets : l'Attaque met 12 à 13 s pour un site, la Défense 5 à 6 s (7 s d'avance).
- **Vue et bruits** (lot TAC-2) : un adversaire n'est montré que si ton équipe le voit (22 m, pas à travers un mur plein ni une
  brume ; dans les hautes herbes à 3 m seulement) ; sinon il disparaît (modèle, carte, barre), et un « ? » marque 4 s l'endroit
  où il a été vu. Ce que ton héros ne voit pas est assombri. Murs et murets arrêtent les coups, les zones au sol demandent de
  voir le point visé. On entend les pas (course) à 14 m, les esquives à 18 m, les coups et les sorts à 24 m, la pose et le
  désamorçage partout : « Voir les sons » est activé dans ce mode. L'IA ne sait que ce que son équipe voit et entend.
- **La Charge** (lot TAC-3) : un attaquant la porte (toi quand tu attaques ; sinon un allié qui n'ouvre pas), on la voit sur son
  dos ; à sa mort elle tombe à ses pieds et un attaquant la ramasse en passant ([G] pour la lâcher toi-même). L'Attaque sait
  toujours où elle est ; la Défense seulement si elle voit l'endroit, ou une fois posée. Pose 4 s et désamorçage 7 s (repris à
  la moitié si on l'a dépassée) annulés par un pas, un coup, un sort, une esquive ou un contrôle subi. Après la pose : 40 s de
  bips qui accélèrent, « 10 secondes ! », puis l'explosion emporte tout héros à moins de 9 m. « Ouf ! » si l'on désamorce à
  moins d'une seconde.
- **Kits et rôles** (lot TAC-4) : chaque classe joue 4 sorts tirés de ses sorts par des règles (le sort de dégâts le plus
  rapide, gratuit ; la mobilité ou un second sort de dégâts ; l'utilité de la classe selon son rôle ; un ultime chargé en
  jouant, à la zone plus large), sans enchaînement, et l'un des 5 rôles : Rempart (plus de vie, contrôles plus courts),
  Ouvreur (une esquive de plus, plus fort sur qui ne l'a pas vu venir), Tireur (porte plus loin, révèle sa cible), Contrôleur
  (utilitaires moins chers), Soutien (ses soins pèsent moins dans la limite).
- **Une vie par manche** (lot TAC-4) : un duel dure une dizaine de secondes, personne ne tombe en moins de quatre secondes
  même pris à trois ; contrôles deux fois plus courts et plafonnés, puis insensible à tout contrôle dur un moment ; invisibilité
  brève, brisée par un coup, interdite à qui porte, pose ou désamorce la Charge ; boucliers moins forts ; soins limités à un peu
  plus de la moitié de la vie par manche ; les coups de très loin portent moins.
- **Achat** (lot TAC-5) : 20 s au début de chaque manche, le monde reste visible. Le sort 1 est gratuit ; les sorts 2 et 3 de
  ta classe s'achètent (200 à 350 selon leur nature) ; l'ultime se charge en jouant (7 points : élimination, chute, pose,
  désamorçage). Arme affûtée ou de maître, arme d'appoint, enduit amer ; gilet ou cuirasse (un bouclier qui encaisse avant
  la vie, réparable) ; 10 utilitaires (2 sortes, 4 charges, 2 du même au plus : brume, éclat aveuglant, pot de feu, bombe
  d'éclats, œil de chouette, clochette, piège, barricade de glace, leurre, poudre de silence) ; une fiole (soin, hâte, garde,
  clarté) ; un outil (Pinces en Défense, Gants en Attaque, Talisman, Bottes feutrées). Ce qu'on achète se revend au même prix
  pendant la phase ; on le garde si l'on survit, on perd tout en tombant. « Achat conseillé », « Racheter », et la colonne de
  l'équipe : le plan des alliés (achat complet, on économise, on force) et ce qui leur manque.
- **HUD** (lot TAC-7) : en haut, le bandeau du score (les 4 + 4 héros, une croix quand ils sont à terre, la jauge d'ultime
  de tes alliés, le score sur la couleur et le blason de chaque équipe, le minuteur, puis la mèche de la Charge en rouge) et
  la ligne de la Charge (qui la porte, où elle est, la pose et le désamorçage avec leur avancée) ; en bas, l'or et ce que
  rapportera une défaite, les sorts 2 et 3 cadenassés avec leur prix tant qu'ils ne sont pas achetés, l'ultime et ses 7
  crans, la fiole, les utilitaires et l'outil, le bouclier au-dessus de la vie ; sur la mini-carte, ce que voit ton équipe,
  les « ? » des derniers vus et les bruits ; dessous, le lieu où tu es et les éliminations. Annonces une à la fois
  (« 2 contre 4 ! », « À toi de jouer ! »), repère au clic molette, barrières d'encre aux départs pendant l'achat.

# Partie D — Économie et progression

## Joaillerie et forge (comme dans Eden)

- **Emplacements de gemmes** : 2 max par objet, percés aux **ciseaux de sertissage**
  (1er sûr, 2e à 70 % ; en cas d'échec les ciseaux se brisent, l'objet est intact).
- **Gemmes** : Rubis (Force), Émeraude (Agilité), Saphir (Intelligence), Perle (Sagesse),
  Topaze (Chance), Grenat (PV), Onyx (Défense), Améthyste (Critique) ; 5 qualités
  (brut, taillé, pur, parfait, royal : ×1 / 2 / 3,5 / 5,5 / 8). Lot GX-4 : sertir dans un emplacement
  occupé **renvoie l'ancienne gemme au sac** (plus rien n'est détruit) ; « Retirer » est gratuit (`Craft.remove_gem`) ; chaque
  bouton dit ce que la gemme donne sur la pièce (`Craft.gem_value_text`) ; « Tout fusionner » (`Forge.fuse_all`) fusionne les
  plus petites tailles d'abord, en cascade, tant que le prix suit.
- **Parchemins d'enchantement** (noms d'Eden) : Chant rapide, Violence, Optimisation,
  Explosion musculaire (armes et gants) ; Légèreté, Compréhension, Rééducation, Récupération
  (armures). Lv1 à Lv5 selon le niveau du butin, objet de niveau (Lv-1)×10 minimum ;
  un enchantement par objet (le nouveau remplace l'ancien).
- **Forge sans punition** (lot GX-2 ; étude `conception/benchmark/HEROS_EQUIPEMENT_PROGRESSION.md` §4, Q1) : réussite
  assurée jusqu'à +2 à +5 selon le parchemin, puis 95 / 90 / 80 / 70 / 60 / 50 / 40 / 30 %. Chaque réussite : stats de base +10 %
  et, aux paliers +4, +6, +8, +10, **une stat bonus** au hasard. **Un échec ne coûte que l'essai** (parchemin, or ou cristaux) :
  **plus jamais de niveau perdu**. Il remplit la **persévérance** de la pièce (`item.pity` : + (1 − chance) × 0,5, au moins 0,25 : au pire 5 essais par cran) et monte la
  chance de 10 % de la base (`item.pity_n`, plafond × 1,5) ; jauge pleine = réussite assurée ; tout repart de zéro à la réussite
  (au pire 5 essais pour un cran à 40 %, 4 pour +10). Les pierres d'Eden sont des **pierres de chance** (+5 à +100 %, une par
  essai, même icône). Le parchemin béni : un essai gratuit. **Viser +N** : coût attendu et au pire (`Craft.plan_upgrade`, sans
  pierre, persévérance comprise), puis « Fortifier jusqu'à +N » enchaîne les essais et s'arrête à chaque palier à stat bonus.
  La piste des 10 crans montre les paliers d'avance ; chance, persévérance et conséquence d'un échec sont écrites avant l'appui.
- **Tout monter à +5** (lot GX-4, levier proposé par H56) : à la Forge (établi Améliorer), un bouton monte les 9 pièces portées du
  préréglage actif (ni trophée, ni arme secondaire) jusqu'à +5 (‹ › : +1 à +10), **la moins montée d'abord** (`Forge.even_step`),
  avec les mêmes règles qu'un essai à la main (persévérance, aucune rétrogradation, un parchemin et le prix par essai). Avant :
  une confirmation avec les pièces, le coût **attendu et au pire** en cristaux et en parchemins, et ce qu'on a (`Forge.plan_even`) ;
  pierres de chance en option (les plus petites d'abord). Pendant : la barre de forge par essai (« Cran 7 / 22 »), « Arrêter »
  (après l'essai en cours). Faute de cristaux ou de parchemin, la séance s'arrête proprement (ce qui est monté le reste) ; une
  pièce sans parchemin est sautée, les autres continuent. Le coût de la Forge ne change pas.
- **Reporter le +N** (lot GX-5, étude BM-GEAR Q2 « oui, à −2 crans ») : 7e établi de la Forge. La pièce choisie (la neuve) prend le
  +N d'une autre pièce du même emplacement (armes entre elles), de niveau égal ou plus bas, **moins 2 crans** (+7 → +5), avec les
  stats bonus des paliers gardés (+4, +6, +8) ; l'ancienne revient à +0 (persévérance et jets en attente effacés des deux).
  **Prix** : les cristaux des crans reçus comme si chaque essai réussissait (`Forge.report_cost` = `upgrade_crystals`), sans
  parchemin, sans échec. Refusé : en partie, pièce gardée (verrou), source sous +3, rien à gagner, pièce de niveau plus bas.
  Confirmation avec ce que devient chaque pièce, le prix et les préréglages qui utilisent l'ancienne. Mesure (`progression_sim
  --report-cost=…`, 12 comptes, 50 h, 2 graines) : gratuit, l'équipement 80-90 correct venait à 28,4-28,6 h (sous la cible de
  30 h) ; au prix des crans sans échec, 30,9-31,9 h (sans Reporter : 30,4-32,2 h).
- **Réajuster** (Atelier et marchand) : le nouveau jet d'une stat bonus est posé à côté de l'ancien (`item.reroll`) ; le joueur
  garde **l'ancien ou le nouveau** (`Forge.reforge_choose`), au même prix ; tant qu'il n'a pas choisi, la pièce garde l'ancien.
- Les fournitures tombent des monstres (4 %, 7 % en rage), des élites (35 %), des boss (3),
  des coffres (1, meilleur en rage) et se vendent chez les marchands ambulants. Tout se fait
  dans la **Forge** (fiche d'un objet pendant la run).

### Matières et cristaux des activités (0.1.165, lot E1 de la nuit du 15/10)

Un parchemin de fortification doit avoir un niveau au moins égal à celui de la pièce, et la Survie plafonnait ses
fournitures au niveau 35 (jusqu'au lot E4, 0.1.179 : elles suivent maintenant les pièces de la carte) : sans autre source, aucune pièce de niveau 40 à 100 ne pouvait passer +1. Les activités
hors Survie donnent donc des **coffres de forge et du joaillier au niveau de l'activité** (`core/activity_loot.gd`),
chacune avec son rôle :

| Activité | Cristaux (Normal / Héroïque / Mythique) | Coffres de matières |
|---|---|---|
| Donjon | 30 / 90 / 170 | forge ×1 ; + joaillier en Héroïque ; forge ×2 + joaillier en Mythique (niveau du donjon : 14-60, 29-75, 90) |
| Ruée des boss | 8 / 18 / 34 par boss (64 / 144 / 272 pour huit) | à 4 boss : forge ×1 ; à 8 : parchemins (×1 en Normal, ×2 sinon), pierres rares, gemmes (niveau du dernier boss : 60 / 75 / 90) |
| Siège | 4 / 10 / 18 par vague + 10 / 40 / 110 boss tombé (30 / 90 / 200) | boss tombé : formules d'enchantement ×1 / 2 / 3, + forge en Héroïque et Mythique |
| Tour | 3 / 4 / 5 / 6 par étage monté (Facile à Hardcore ; passe E6, avant 1 à 2,5) | gemmes tous les 10 étages, forge tous les 50 (niveau de l'étage) |

- Un coffre porte une spécialité (`focus`) : « parchemins » (2-3 puissance, 2-4 garde), « pierres » (4 pierres rares
  en plus), « gemmes » (3 gemmes d'un rang de plus), « formules » (3 formules au niveau le plus haut, 1 gemme).
- **Cristaux = optimiser** : hors run, `Forge.GOLD_PER_CRYSTAL` passe de 25 à 125, puis **108** au lot GX-2 (Forge sans
  punition : le coût **attendu** reste celui d'avant). Une pièce de niveau 85 à +10 coûte ≈ 870 cristaux si chaque tentative
  réussit, **≈ 1 610 en moyenne** (avant : ≈ 1 615 avec des pierres de protection), au pire ≈ 3 830 : **6 à 8 clears
  Mythiques**. Un donjon Normal (30 cristaux) paie un +3 sur une pièce de niveau 30. Mesures : `conception/progression/R_GX2.md`.
- Le démontage rend 1 à 3 cristaux (avant : 1 à 8) et un coffre de forge 2 à 3 au niveau 30 (avant : 3 à 9) : un
  cristal vaut 5 fois plus d'or, ils restent un complément. Le coffre de trophées n'existe plus.

### Maîtrise et insignes du JcJ, plans, panoplie des Esprits (lot E2 de la nuit du 15/10)

- **Maîtrise partout** : formule commune `League.mastery_for(manches, palier, part)` = (40 + 20 × palier + 150 × manche
  gagnée) × part. Ligue : inchangée (palier = rang visé, part 1). Panthéon : palier = rang du cerveau (1-6), part 1, à chaque
  victoire. Duel libre, Arènes, Gantelet : palier = difficulté + 1, part 0,5 × difficulté (Facile 0,5 … Hardcore 1) ;
  Gantelet +25 % par adversaire en plus ; duel libre contre un adversaire affaibli (préparation PV / dégâts < 1, adversaire
  de l'éditeur) : rien. Battle royale : « manches » 2 pour la victoire, 1 pour le podium, palier = éliminations (4 au plus).
  Les modes classés ignorent la préparation de l'adversaire du duel libre.
- **Insignes du JcJ contre l'IA plafonnés au jour** (`League.win_insignia`, `royale_insignia`) : 1re victoire du jour de
  chaque mode 50 (Arènes 2v2) / 75 (3v3) / 60 (Gantelet 1v2) / 90 (1v3), puis 10 ; Battle royale : la meilleure place
  du jour paie la différence avec la précédente (110 / 70 / 45 / 28 / 18 / 11 / 7 / 4), + 3 par élimination. Une heure
  de JcJ rapporte ≈ 180-190 insignes (première heure du jour ≈ 300-450 si on gagne tout), contre ≈ 540 (époque I) à
  850 (époque IV) pour une heure de Survie gagnée (barème du lot A5, victoire de ≈ 2 000 monstres).
- **Arènes, Gantelet, Ligue (passe M7)** : la difficulté des héros IA se choisit (Facile à Hardcore, Difficile par défaut) ;
  la 1re victoire du jour paie ses insignes × la difficulté rapportée à Difficile (Facile ≈ 60 %, Hardcore ≈ 118 %). Les alliés
  ont la fiche d'un héros de leur classe × la difficulté, comme les adversaires (avant : PV d'entraînement × 3 à × 8) et la
  même difficulté qu'eux ; les équipes sont de familles différentes ; les adversaires soignent et renforcent leur camp
  comme les alliés (Arènes et Gantelet). Arènes : niveau au choix (10 par défaut), échelle 0,026 (2v2) / 0,024 (3v3),
  acharnement dès 25 s / 20 s. **Arène piégée** (option) : passé 10 s, toutes les 8 s, une zone de feu par paire de héros
  debout (rayon 3,2 m, 1,4 s d'annonce) retire 12 % des PV max à tout héros dedans, tous camps, esquive possible.
  **Promotion de Ligue** : + 40 × rang insignes et un coffre d'apparence (Bronze et Argent rare, Or mythique, Platine légendaire),
  une seule fois puisque le rang est gardé à vie. **Mort subite** (duel à l'arme et équipé, Arènes, Gantelet) : passé 90 s de
  manche, l'acharnement double en plus toutes les 5 s (les duels avec un soigneur duraient 95 à 120 s).
- **Plans** (remplacé par le lot A1 : un plan par boss, en insignes, voir « Bibliothèque de boss ») : le plan d'une zone tombait au
  1er donjon terminé de chaque difficulté, sinon une fois sur dix. **Fabrication** : modèle d'Eden du niveau du donjon (et non de la
  zone choisie au lobby), arme du type de la classe choisie.
- **Siège Normal** : aucune PE requise (Héroïque et Mythique : voir « Verrous de PE (passe P5) »).
- **Panoplie des Esprits universelle** : chaque pièce est un modèle fixe, légendaire de niveau d'Eden 70, quelle que soit la
  zone. Gagnée, elle s'ajoute à `seen_gear` (id `Pantheon.shop_id`) : l'Armurerie la revend (220 insignes) pour toutes
  les classes ; battre le Champion y ouvre l'arme des Esprits des 17 types. **Éveil** : avec 6 pièces éveillées portées
  (cerveau battu par les 5 familles), le palier 6 devient : +10 % dégâts, +5 % critique, esquive → hâte puis furie 4 s,
  recharge 4 s (au lieu de 3 s / 8 s).

### Insignes et maîtrise des 60 classes (lot E5 de la nuit du 15/10, `core/economy.gd`)

- **Barème unique** (`Economy.INSIGNIA_PER_HOUR`, contrôlé par `test_e5`) : la Survie est la référence (≈ 540 insignes / h
  gagnée en époque I, 850 en époque IV pour une victoire réelle de ≈ 2 000 monstres et 20 élites, formule
  `Economy.survival_insignia`) ; le JcJ contre l'IA reste en dessous (≈ 400 la 1re heure du jour, puis ≈ 60) ; Donjons, Ruée,
  Siège, Tour et Quêtes ne donnent pas d'insignes.
- **Survie sans « bash » (lot A5 de la refonte Aventure)** : participation 25 (dès 10 monstres) + 25 pour la 1re carte (les deux
  au prorata du temps sur la 1re carte, passe E6), **35 par carte suivante atteinte**, **monstres / 40** (au lieu de / 20),
  élites × 2, **15 par boss de carte vaincu** (un par carte finie), victoire 60 × époque (`Economy.survival_insignia_parts`,
  ligne « Boss de carte vaincu » au bilan). Une victoire rapporte à l'heure 0 à +7 % d'avant (1 800 à 2 500 monstres) ; une
  défaite express (1, 3, 5 min), une défaite en carte 2 ou une rage farmée en carte 1 jamais plus qu'avant (`test_e5`). La 1re
  carte reste à 25 pour qu'un abandon express ne paie pas plus.
- **Armurerie à paliers** (`Economy.armory_price`) : la 1re pièce d'un palier (même emplacement, type d'arme, niveau, rareté,
  éveil) coûte le prix plein, les autres pièces de ce palier (autres panoplies ou attributs, utiles à d'autres classes)
  15 %. Pièces des Esprits : jamais de remise. Kit d'une classe : 1,8 h (époque I) à 3,3-3,9 h ; collection d'une époque :
  16 h (I), 28 h (II), ≈ 58 h (III-IV ; ≈ 33 h au rang héroïque 5) au lieu de 44 / 84 / 230 h
  (`GearShopPage.price` = `Economy.armory_price`).
- **Puits sobres** : coffres d'apparence et d'auras achetés avec des insignes (`Economy.SHOP_CHESTS` : rare 150 ×3,
  mythique 300 ×2, légendaire 600 ×1, aura rare 400 ×1, aura légendaire 900 ×1 par semaine ; fermés quand la collection
  de la rareté est complète) ; **leçon de maîtrise** : 200 insignes → 300 points pour une classe en retard, 3 par jour.
  Boutons (passe P1) : Coffres > « Boutique » (une ligne par coffre, solde, restants de la semaine, « Reviens lundi » ou
  « Collection complète » quand fermé) ; Héros > Classe : « Leçon · 200 insignes · 3 restantes » à droite de la barre de
  maîtrise, visible seulement pour une classe en retard et hors run.
- **Maîtrise des 60 classes** : rattrapage ×1,5 en Survie pour une classe à 3 niveaux ou plus sous la meilleure du compte
  (jusqu'au niveau 20) ; 1re victoire de la classe à chaque époque : +600 / 900 / 1 200 / 1 500 ; **part de l'arbre** : 10 %
  de toute maîtrise gagnée va aux voisines de l'arbre (classe d'origine et classes qui en descendent) débloquées et plus
  basses (`Profile.add_expertise`, `last_shared`) ; le Défi de maîtrise propose de préférence des classes en retard. Une classe
  jouée après la première monte au niveau 20 en ≈ 3,6 Survies gagnées au lieu de 6,6 (contrats compris).

### Atelier (lot U5 de la nuit du 15/10 ; textes du lot A3 de la refonte Aventure : Fabriquer, Plans de donjon, Forge)

- **Bourse commune** (`ui/workshop_purse.gd`) dans l'en-tête de l'Atelier : insignes (fabriquer) et cristaux (optimiser).
- **Fabriquer** (ex-Armurerie, `ui/gear_shop_page.gd`) : une pièce découverte en Survie (`Profile.seen_gear`) est son **plan** ; elle se
  **fabrique** en insignes, aux mêmes prix qu'avant (`Economy.armory_price`) : le mot « acheter » ne désigne plus une pièce. Tout le
  catalogue des coffres d'emplacement (`Completion.armory_ids()` : pièce → première époque qui la propose ; `Completion.plan_place(id)` :
  « Époque I · Monts Calcaires », la première carte), compteur « N / total plans découverts ». Statuts : **À fabriquer** (défaut),
  **Fabriquées** (✓), **Plans à découvrir** (case « ? » avec emplacement et niveau, « Plan à trouver : époque · carte » dans le détail :
  jamais le nom), **Tous**. Bouton « Fabriquer · N insignes ». Une pièce dont le plan est trouvé dit « Plan trouvé : époque · carte ».
  Filtres : emplacement, époque, classe (les armes de son type seulement). 72 pièces par page. Le détail compare avec la pièce portée :
  verdict, PE et trois écarts au plus. Après une fabrication, la pièce reste choisie (un double clic ne fabrique pas deux fois).
  Carnet : la catégorie « Plans » compte les plans découverts.
- **Plans de donjon** (ex-Fabrication, `ui/fabrication_page.gd`, lot A1) : un plan par boss (48, compteur « x / 48 plans ») ; avec le
  plan : l'un des 2 emplacements du boss + « Fabriquer · N insignes » (ce qu'il manque en rouge) ; sans plan, donjon ouvert : « Il tombe
  en battant <boss> » ; donjons fermés : une ligne ; sans aucun plan : bandeau d'état vide. Lot GX-2 : les 2 emplacements en onglets ;
  **la pièce se voit avant d'être fabriquée** (case, rareté, emplacement, niveau, verdict « Meilleure pour <classe> » + écart de PE,
  3 stats ; Maj sur la case : la carte complète) et c'est elle qui est fabriquée (`FabricationPage.preview`) ; **« Fabriquer et
  porter »** (grisé, raison écrite, si le niveau de héros est trop bas) ; « Il te manque N insignes ≈ X cartes de Survie ».
- **Fabriquer v2** (lot GX-2) : vue par défaut **par paliers** : colonne des 12 cartes (« II-2 Volcan d'Avila », jauge x / 9 du kit
  fabriqué, « ta bande » en lagon), **poupée du kit du palier** pour la classe (9 cases : pleine = fabriquée, voilée = plan connu avec
  son prix, « ? » = plan à trouver avec la carte ; pour chaque emplacement, la meilleure pièce du palier pour le profil de la classe),
  **« Fabriquer les N plans connus · total »** (carte de confirmation du coût ; « il en manque N ≈ X cartes de Survie » sinon), fiche
  avec « Fabriquer et porter » (ou « Porter » une pièce déjà fabriquée). Une carte de Survie ≈ le tiers d'une victoire type de
  l'époque ouverte (`Economy.insignia_per_map`). Le catalogue filtrable reste derrière « Catalogue complet ».
- **Forge** (`ui/forge_bench.gd`) : un panneau, six établis en haut, la pièce et son tableau **avant → après** (stats principales, qualité,
  cristaux), le coût en cristaux (rouge s'il en manque), la barre de verdict compacte et l'action principale en bas. Prix en mots
  (`MerchantPages.price_words`). La fusion de gemmes garde l'ancien taux (`Forge.FUSE_GOLD_PER_CRYSTAL` 25, `Forge.fuse_price` : 2 à 7
  cristaux hors run) : le taux de 125 la rendait presque gratuite.
- **Marchand de run** : plus de phrases d'aide (une ligne sur l'or perdu en fin de run), plus de page de fabrication de mythiques.

## Équipement

- Chaque objet a un **type de base** (ex. katana : orienté physique) avec des stats de base.
- **Objets d'Eden** (`data/eden_catalog.json`) : chaque objet du jeu est un vrai objet d'Eden
  (nom, icône, stats connues, set, passif). Son niveau affiché est son niveau d'Eden ; chaque
  zone couvre une tranche d'Eden (de son niveau de carte à celui de la zone suivante, la
  dernière jusqu'à 100) parcourue au fil de la run : pas d'objet d'une zone plus avancée. Sa
  puissance (« plevel ») est le niveau de run où il est tombé : stats = référence du jeu ×
  rapport de l'objet dans Eden × rareté. Au-delà du niveau 40 d'Eden (où les objets courants
  s'arrêtent), le butin courant prend un modèle courant du bon niveau.
- **Puissance et niveau de héros** (lots H3, H4a) : une pièce se porte si son niveau ≤ niveau de héros, et en Aventure elle compte
  à son niveau (`Items.power_level` = min(niveau de héros, niveau de la pièce), jusqu'à 90 : plus de plafond 15 / 25 / 35). Une
  pièce sous le niveau du héros pèse donc moins d'elle-même (retard d'équipement) ; les pièces de départ valent min(niveau de
  héros, leur niveau). Les coffres de l'Aventure ne donnent rien au-dessus du niveau de héros (voir « Aventure au niveau de héros »).
- **6 raretés** : commun, spécial, rare, épique (jets aléatoires : qualité 70-90 %, 75-95 %,
  80-100 %, 85-100 %), **mythique** (toujours 100 %) et **légendaire** (101-120 %). Mythiques et
  légendaires : seulement sur les boss (garanti, 30 % de légendaire, 50 % si enragé) ou par
  fabrication (mythiques) [avant 0.1.123 ; en Survie ils viennent maintenant des coffres d'emplacement, à la rareté de la carte
  d'époque (`Epochs.LIST`), et les monstres ne lâchent plus d'équipement] ; ils portent le passif d'arme et les effets de set d'Eden.
- **Amélioration +1 → +10** : augmente les stats de base à chaque niveau ; aux paliers
  **+4, +6, +8, +10**, une stat aléatoire de l'objet est en plus augmentée (ou un affixe ajouté).
- **Désassemblage** → des **cristaux** selon la rareté (gardés entre les runs). **Vente** → or
  **+ la moitié de l'or** investi dans les améliorations.

## Sets d'équipement (façon Eden)

> État 16/10 : les pièces portent les panoplies d'Eden (bonus 2 / 4 / 6) ; `Items.SETS` = les 6 archétypes ci-dessous + `salvo`,
> `rampart` (panoplies de donjon, `Dungeons.ARCHETYPES`) + `pantheon` (Esprits). Le Survivant a ses propres paliers 2 / 3 / 5.

- 30 % des objets rares et épiques sont des **pièces de set** (nom et cadre verts).
- 6 sets, bonus à **2 / 4 / 6 pièces** : Tempête (foudre), Givre éternel (gel), Lame sanglante
  (Frénésie sur critique), Œil du faucon (critique, portée), Phénix (survie, brûlure),
  Vent céleste (esquive → Hâte + Fureur).
- Infobulle : bonus du set, ceux actifs en vert ; fiche du personnage : bonus de set actifs.
- **Carte d'objet** (0.1.172, `Items.describe`, `ItemWidgets.item_card`) : icône et nom à la couleur de la rareté, ligne
  « rareté · emplacement · niveau », puissance de la pièce (PE) et qualité, **statistique principale en gros** (attaque pour les
  armes, gants et bagues, défense puis PV pour les armures, capes et bottes, PV pour les colliers), cinq lignes secondaires au plus
  (les plus lourdes), passif, gemmes, enchantement, panoplie « x / N » (et panoplie de donjon) avec le prochain palier, puis la
  comparaison avec la pièce portée (verdict, écart de PE, une ligne ▲ vert / ▼ rouge par différence). **Maj** déplie : tous les
  paliers, bonus d'amélioration, chance de la prochaine amélioration (hors run), niveau de puissance. Les pages qui affichent
  une fiche à demeure (Atelier, marchand, Équipement) montrent toujours la carte complète. Une statistique plate et son
  pourcentage du même nom (Défense 231 et Défense 4 %) tiennent sur une seule ligne. En Survie, la pièce portée s'affiche et se
  compare telle quelle ; une arme d'un autre type que la classe se compare à l'arme secondaire. Rien ne parle du jeu d'origine.

## Choix et coffres de récompense (lot U3 de la nuit du 15/10)

- **Choix de carte en un geste** : un clic sur une carte (ou 1, 2, 3, ou A à la manette) la choisit, plus de bouton
  « Valider ». Pendant les 0,3 premières secondes les cartes sont voilées et ignorent tout (anti-rafale). Une pièce
  d'équipement montre 4 statistiques au plus ; les lignes communes à toutes les cartes (« Emplacement libre », les mêmes
  statistiques des deux variantes d'une arme) sont dites une fois sous la rangée.
- **Coffres** (menu Coffres) : une ligne par genre, c'est-à-dire par type et par spécialité (« Coffre de forge »,
  « Coffre de forge · parchemins », « Coffre de joaillier · formules »…), une pastille d'icône par type en plus de la
  couleur, « Ouvrir tout (N) », une phrase sans chiffre par genre (le détail du contenu est dans l'infobulle). **« Ouvrir
  tout »** (lot GX-5) : d'abord une carte qui dit ce qui va s'ouvrir (un genre par ligne, « ×N »), que les coffres à choix
  restent à ouvrir un par un et que rien n'est vendu ni démonté ; puis un récapitulatif : les raretés obtenues (la plus haute
  d'abord), « ▲ N pièces meilleures pour <classe> », les nouvelles apparences et les fournitures ; les cases apparaissent par
  rareté montante (la plus rare en dernier, révélation de 2,4 s au plus). Un seul coffre : ouvert sans carte.
- **Roulette** : chaque case promet l'apparence qu'elle donnera (`Wheel.board`, tirée à chaque lancer, gardée dans la
  sauvegarde, jamais deux fois la même, remplacée si le joueur l'a obtenue entre-temps), visible dans la roue et dans la
  liste « Gains ». Le lancer donne l'apparence de la case désignée, pitié comprise ; le gain s'affiche en grand 3 s.

## La quête commune se voit (passe P6, 0.1.186)

Toutes les activités servent une quête : l'équipement optimal de toutes les classes, les titres, les apparences. Le moteur
est dans les rapports `conception/nuit_15_10/R_E*.md` ; la passe P6 le rend lisible (rapport `R_P6.md`).

- **Gains en pastilles** : chaque activité de la page Jouer porte, en icônes, ce qu'elle seule donne (`Activities.LIST`,
  clé `gives`, `ui/gain_chips.gd`) : Survie = pièces, maîtrise, insignes, étoiles ; Donjons = panoplies, plans, cristaux,
  parchemins ; Tour = cristaux, gemmes, apparences ; Ruée = parchemins, pierres, cristaux, titres ; Siège = formules,
  cristaux, apparences ; Duel = rangs, titres, maîtrise, Esprits ; etc. La page de l'activité les répète avec leur nom.
- **Chaque ressource dit où l'obtenir et où la dépenser** (`core/resource_help.gd`, une table) : infobulle des icônes,
  du pied du lobby, de la bourse de l'Atelier, des fournitures (`Craft.describe_key`), des lignes de bilan, de la Forge sans cristaux.
- **Boussole** (`core/compass.gd`, ligne cliquable en haut du lobby) : un seul conseil, recalculé à chaque affichage pour la
  classe choisie. Ordre : première Survie ; pièce du coffre commun que « Équiper le meilleur » poserait ; pièce achetable avec
  les insignes ; coffres à ouvrir ; ce qui manque à la classe (emplacement vide, niveau, panoplie de donjon ou Esprits, +10,
  gemmes, enchantements) avec l'activité qui le donne ; échelon suivant du fil d'éveil ; classe suivante du Registre.
  Jamais en partie. Une activité fermée est remplacée par son échelon (« Gagne l'époque I : Forge, Tour et Donjons s'ouvrent »).
- **Bilans** : une ligne « Ta quête » (`spec.quest`, `Compass.after(mode, gains)`) dit ce que le gain change (« plan obtenu »,
  « panoplie Tempête 2 / 6 : un coffre de set donne +1 pièce », « 170 cristaux pour la Forge », « Esprits 1 / 6 »…), puis la suite.
- **Pages Donjon, Siège, Ruée** : sous la difficulté choisie, la jauge de la première difficulté plus dure encore fermée par la PE.
- Parcours de la première heure : Survie, bilan, boussole « une pièce est achetable », Armurerie, « À équiper : Héros >
  Équipement » (le dernier pas après un achat), boussole suivante. Test : `tests/test_compass.tscn`.
- **Option** (P10) : Paramètres > Caméra et interface > « Afficher la boussole d'objectif » (`Settings.show_compass()`, activée
  par défaut) ; désactivée, la pastille disparaît du lobby (la ligne « Ta quête » des bilans reste).

## Quêtes (passe M5, retour du joueur : « le Défi de maîtrise ressemble à des quêtes journalières »)

Le Défi de maîtrise n'est plus une page à part : c'est la quête « Défi du jour » d'un système de quêtes (`core/quests.gd`, pool
`core/quest_pool.gd`, page `ui/quests_page.gd`). Ouvert par le même verrou qu'avant (3 Survies, entrée `daily` du fil d'éveil).

- **Où** : Jouer > rangée Défis > « Quêtes » (une page d'activité comme les autres, manette comprise) ; l'étiquette dit « 1 sur 3
  aujourd'hui ». Rien dans le Carnet : les quêtes se lancent, elles ne se consultent pas.
- **Du jour (3)** : le Défi du jour (la Survie de l'époque I, deux contraintes, maîtrise ×2, +600 la 1re victoire, insignes ×1,5 : règles de
  `core/challenge.gd`, inchangées, avec ses trois classes proposées) puis deux quêtes d'autres activités tirées du pool (≈ 40 quêtes :
  Survie, Survivant (ouvert à tous depuis 0.1.210), Donjons, Tour, Ruée, Siège, Duel, Arènes, Gantelet, Battle royale, coffres du menu, variété). Tirage
  déterministe par date (`Quests.draw`), figé dans `Profile.records.quests` ; les quêtes dont l'activité est fermée ne sont pas tirées.
  Budget : ≈ 22 min pour le Défi du jour (la Survie qu'on jouerait de toute façon) + 2 quêtes de 11 min au plus ≈ 40 min au total ; une
  même Survie fait avancer plusieurs quêtes de Survie.
- **De la semaine (2)** : deux grandes quêtes d'activités différentes (cibles × 5 à 8 de celles du jour).
- **Défis de classe** : les contrats de `core/contracts.gd`, inchangés, listés sous les quêtes pour la classe choisie.
- **Une quête n'est jamais obligatoire**, rien ne se perd en les ratant. **Relance** : une quête du jour non faite se change une fois par
  jour (le Défi du jour aussi).
- **Récompenses** (lot A5 : « pas de quêtes obligatoires » ; jamais d'insignes, de cristaux, de fournitures ni d'équipement) : du
  jour, une seule au tirage : maîtrise 150 / 250 / 350 pour la classe la plus en retard (`Quests.laggard`, 7 tirages sur 10), sinon un
  coffre d'apparence (commun, rare pour les grandes quêtes) ; le Défi du jour garde ses gains propres. De la semaine : 600 de maîtrise
  + un coffre d'apparence rare, ou un coffre d'apparence épique. Sans classe en retard, la maîtrise devient un coffre d'apparence.
  Une quête tirée avant A5 garde sa récompense figée (insignes, cristaux, coffre de parchemins), payée telle quelle. Les quêtes du
  Survivant (aucun lien avec le compte) ne donnent que des coffres d'apparence.
- **Série** : une quête du jour accomplie par jour prolonge la série (`Quests.series_n`). Un jour manqué est pardonné ; au-delà, la
  série retombe à son dernier palier gagné (jamais à zéro). Paliers cosmétiques à 3, 7, 14, 30, 60 et 100 jours (coffres d'apparence et
  d'aura, titres « Régulier » et « Inlassable »), chacun donné une seule fois.
- **Suivi** : un bus unique `Quests.event` / `Quests.end_run(activité, gagné, extra)`, appelé en fin de Survie, Survivant, Donjon, Ruée,
  Siège, Tour, Duel / Arènes / Gantelet et Battle royale (après le rechargement de la sauvegarde), plus `zone_hit` (télégraphes) et
  `chest_open` (menu Coffres). Les compteurs de la partie sont lus dans `Run` à la fin ; rien n'est écrit en cours de partie.
  Une partie de moins de 30 s ne compte pas. HUD : `ui/quest_badge.gd` (la quête la plus avancée de l'activité jouée, une petite carte
  `InfoCard` « Quête accomplie » à l'accomplissement) ; bilans : ligne « Ta quête » (`Compass.after`) ; boussole : quête presque faite
  ou, à défaut, la plus avancée. Succès « Aventurier appliqué » et « Constance ».
- Test : `tests/test_quests.tscn`.

# Partie E — Textes

## Tout le jeu en français (passe P10, 0.1.190)

Aucun texte lisible ne doit rester en anglais. Les noms d'Eden passent par une seule table (`data/names_fr.json`, `NamesFr.apply`,
générée par `tools/names_fr_build.py`, ids inchangés, nom d'origine dans `name_en`) : équipement, panoplies, monstres, zones,
apparences, collection et, depuis P10, **talents** (section `talents`, lexique à la main dans `tools/names_fr_talents.py`).
- **Passif d'une pièce d'Eden** : seul l'effet est écrit (« ✶ Passif : à l'impact, 10 % de chances : Puissance »). Son nom d'origine
  était un libellé anglais sans intérêt (souvent le nom de la pièce) ; le passif d'un trophée de la run garde son nom français.
- **Test** : `tests/test_texts_fr.tscn` parcourt les cartes des 5 947 pièces, panoplies, trophées, boons, cartes de classe, succès, titres,
  sorts, certificats, talents, monstres, zones et toutes les constantes de texte des scripts, et signale les mots anglais courants
  (liste de contrôle `ENGLISH`). Un nouveau texte d'Eden à afficher : le passer par la table, relancer ce test.

## Curseurs et réticule de visée (lot K1, `ui/cursor_sets.gd`, `ui/aim_reticle.gd`, rapport `R_K1.md`)

- **Curseur au choix** (Paramètres > Caméra & interface > « Curseur et visée ») : Classique (système) et neuf jeux dessinés au script
  (`tools/make_cursors.py` : Gantelet, Lame, Cristal, Orbe, Plume, Flamme, Rune, Étoile, Ombre), chacun avec flèche, main (boutons), texte
  et poing (glisser), en 32 px (48 px quand l'interface est à 125 % ou plus). Aperçu direct dans les Paramètres ; aucun effet sur le jeu.
- **Réticule de visée** en jeu seulement avec la visée « Curseur » ou le mode Action (jamais en pause ni à la manette) : point (défaut),
  croix, cercle ou aucun, taille et couleur au choix ; cerné de sombre, ne bloque aucun clic.

# Partie F — Archives : décisions remplacées (gardées pour mémoire, ne plus coder d'après elles)

## Combos d'auto-attaque (3 coups, le 3e = coup final)

> Archive : remplacé en 0.1.127 par « Auto-attaque des armes » (plus de combo, deux variantes par type d'arme).

| Classe | Coup 1 | Coup 2 | Coup 3 |
|---|---|---|---|
| Samouraï | taille ascendante 100 % | taille descendante 115 % | salto avant 220 %, impact à la retombée, renverse 1 s |
| Guerrier | hache 130 %, 3 cibles max | crochet 100 % : attire de 3 m, renverse 1 s | tour complet 180 % (4,2 m) |
| Voleur | tourbillon 80 % | ruée de 4 m + tourbillon 100 % | bond de 5 m + fumigène 140 % : invisible 2 s, Évasion 4 s (40 % d'esquive) |
| Chasseur | flèche 100 % | 3 flèches 70 % | pluie de flèches 150 % (zone 4 m à 12 m) |
| Clerc | éclat sacré 90 % (zone 2,5 m) | marteau céleste 130 %, renverse 1 s | prière : soin 6 % + Régénération 3 s |
| Magicien | explosion arcanique 100 % | puits gravitationnel 80 % : aspire vers le centre, ralentit | pas éthéré : repli de 6 m + invisible 2,5 s |

Invisibilité : les monstres perdent ta trace ; attaquer ou lancer un sort la rompt.

## Classe + arme (builds exotiques)

> Archive : depuis 0.1.127 l'arme principale est toujours du type de la classe ; une arme d'un autre type n'est que l'arme
> secondaire (« Auto-attaque des armes ») ; 17 types d'arme (« Boucle de jeu et Survie », lot E4).

- On choisit **une classe** (sorts, passifs, talents, attributs) puis **une arme**, au choix
  parmi 6 types : katana, hache, dague, arc, sceptre, bâton (lobby, ou l'arme équipée).
- **Le combo d'auto-attaque, la posture, la portée et le type de dégâts du combo suivent
  l'arme** (hache = combo du Guerrier, bâton = combo magique du Magicien…) ; les sorts restent
  ceux de la classe : magicien à la hache, guerrier au bâton, voleur à l'arc…
- Les stats de base de l'arme dépendent de son type (hache surtout physique, bâton surtout
  magique) : un build exotique doit composer avec ses attributs.
- Le butin d'armes suit l'arme en main ; choisir un type dans le lobby équipe la meilleure arme
  de ce type de l'héritage (ou une arme commune neuve).

## Roguelite : héritage

> Archive : remplacé par la Survie avec l'équipement du hub (0.1.170, N1) : plus d'objet gardé au choix, le hub est restauré en
> fin de run (`Profile.end_run_survival`) ; début de carte doux = `RunDirector.EARLY_EASE` 0,45 → 1 sur `EARLY_RAMP` 300 s.

- Chaque run **repart de zéro** : pas d'or, pas de matériaux, pas de butin.
- On part avec son **équipement de départ**, choisi dans le lobby parmi l'**héritage**
  (katana commun au tout début).
- À la fin de la run (victoire, défaite ou abandon), on **garde 1 objet** au choix, avec son
  amélioration (+8 reste +8). Une pièce d'héritage portée pendant la run est mise à jour.
- Lobby : **Nouvelle partie** efface l'héritage et les statistiques (2 clics pour confirmer).
- Les 3 premières minutes, les monstres montent de 60 % à 100 % de leurs PV et dégâts.

## Étapes et sources (refonte 0.1.91, façon Megabonk)

> Archive partielle : depuis 0.1.123 une run = les 3 cartes d'une époque (zones fixes, `Epochs.LIST`) ; les monstres ne lâchent
> plus d'équipement (lignes « Équipement » de la table périmées) ; les fournitures suivent « Fournitures de la Survie » (E4).

- **Une run = 3 étapes** : la zone choisie, puis une zone à la hauteur du héros (au moins la suivante :
  niveau 17 en fin d'étape 1 → Avila 13-30 ; sinon monstres et butin, plafonnés au niveau de la zone,
  resteraient sous le sien ; les zones franchies se débloquent). Le boss d'une étape vaincu, un
  **portail** apparaît dans sa salle : il mène à la carte de la zone suivante (minuterie, sceaux et coffres
  remis à zéro ; niveau, cartes, équipement, or et clés gardés ; la zone suivante est aussi débloquée).
  Victoire après le boss de la 3e étape (ou de la dernière zone). +120 d'expertise par étape franchie.
- **Où trouver quoi** :

| Ce qu'on cherche | Où |
|---|---|
| Or | jarres, caisses, tas d'or (ramassés en passant), monstres, défis |
| Parchemins de fortification (chaque +1) | caisses et tonneaux surtout, coffres simples, élites |
| Gemmes | cristaux (3 coups), jarres, coffres du joaillier |
| Parchemins d'enchantement | autels du scribe (au choix), coffres ouvragés et dorés, marchands |
| Pierres de sûreté, parchemin béni | coffres ouvragés et dorés, stèles du défi, élites |
| Équipement commun → épique | monstres (5 %), coffres simples (choix de 3), marchands |
| Équipement rare → mythique | coffres ouvragés (mythique 7 % par proposition) |
| Équipement épique → légendaire | coffres dorés (légendaire 15 %, mythique 22 % par proposition) |
| Mythique / légendaire garantis, sets | coffres de récompense : boss d'étape (100 %), stèles du défi (100 %), élites (20 %) |

## Méta-progression des cartes et classes (0.1.33)

> Archive : prix des coffres de la carte +18 % par coffre ouvert depuis 0.1.90 ; fil d'éveil des activités : `core/unlocks.gd`.

- **Classes** : règles par famille (Progression.UNLOCKS) — voir AUDIT.md partie 1.
- **Cartes** : 12 disponibles d'emblée, 18 à débloquer par exploits cumulés (Cards.UNLOCK) ;
  Bannir / Garder 3 fois chacun par run ; page Héros > Cartes.
- **Coffres de la carte** : prix doublé à chaque ouverture.

## Équipement en run (0.1.34)

> Archive partielle : la puissance d'une pièce suit toujours le niveau du héros ; l'état actuel (hub, enclume, Forge fermée pendant
> la Survie, Atelier hors run) est dans « Boucle de jeu et Survie » et « Atelier ».

- Puissance d'un objet = niveau du héros de la run, plafonnée au niveau de l'objet
  (Items.power_cap) ; hors run : la puissance maximale. Améliorations, gemmes, enchantements
  gardés entre les runs.
- Stats fixes, jet de qualité seulement ; stat bonus aléatoire aux paliers +4 / +6 / +8 / +10
  (Craft._upgrade_roll), réforgeable aux cristaux.
- Comparateur (Items.rating, Items.compare_to_equipped) : ▲ / ▼, % sur la fiche, alerte en
  run et touche G (quick_equip).

## Ordre de réalisation

> Archive : ordre du prototype (0.1.0 à 0.1.30), fait.

1. Générateur de map (DA Eden) + run de 10 min + rage + lieux à découvrir.
2. Équipement à jets, matériaux, marchand (vendre / désassembler / améliorer), boutique.
3. Arène du boss, attaques annoncées, invocations.
4. Performance pour des vagues de centaines de monstres.
