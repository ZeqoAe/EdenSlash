# Eden Slash — conception d'une run

Direction artistique : celle d'Eden Eternal (textures de sol, arbres, rochers, maisons,
coffres, PNJ, monstres, armes et tenues du jeu d'origine). Les maps de combat sont
générées à chaque run, avec nos propres collisions simples.

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

Types de compétences du moteur : `dash`, `spin`, `cone`, `fan`, `flurry`, `line`, `buff`, et
`bolt` (projectile : volée, dispersion, perforation), `ground` (zone au sol à l'endroit visé),
`heal` (soin en % des PV), `blink` (téléportation sans traverser les murs).
Chaque classe : 9 compétences d'Eden adaptées, 2 passifs propres (icônes d'Eden) + passifs communs.

## Combos d'auto-attaque (3 coups, le 3e = coup final)

| Classe | Coup 1 | Coup 2 | Coup 3 |
|---|---|---|---|
| Samouraï | taille ascendante 100 % | taille descendante 115 % | salto avant 220 %, impact à la retombée, renverse 1 s |
| Guerrier | hache 130 %, 3 cibles max | crochet 100 % : attire de 3 m, renverse 1 s | tour complet 180 % (4,2 m) |
| Voleur | tourbillon 80 % | ruée de 4 m + tourbillon 100 % | bond de 5 m + fumigène 140 % : invisible 2 s, Évasion 4 s (40 % d'esquive) |
| Chasseur | flèche 100 % | 3 flèches 70 % | pluie de flèches 150 % (zone 4 m à 12 m) |
| Clerc | éclat sacré 90 % (zone 2,5 m) | marteau céleste 130 %, renverse 1 s | prière : soin 6 % + Régénération 3 s |
| Magicien | explosion arcanique 100 % | puits gravitationnel 80 % : aspire vers le centre, ralentit | pas éthéré : repli de 6 m + invisible 2,5 s |

Invisibilité : les monstres perdent ta trace ; attaquer ou lancer un sort la rompt.

## Grimoire et infobulles

- **Grimoire** (lobby et menu pause) : par classe, statistiques de base, passifs, combo coup par
  coup, 9 compétences avec infobulle détaillée générée depuis les vraies valeurs (type de dégâts
  physique / magique, % de l'attaque et valeur chiffrée, bonus de critique, cibles, effets et
  durées, combos d'états) et tableau des rangs 1 → 5 (+20 % de dégâts, -8 % de recharge par rang).
- **Cartes d'objet** : icône d'Eden, nom à la couleur de la rareté, qualité, stats du type de base
  avec le bonus (qualité, amélioration) entre parenthèses, affixes en bleu, bonus de set.

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

- **Équipement** : 3 préréglages par classe en haut de la page (un clic change, « Gérer » copie l'équipement
  porté vers un autre préréglage ou renomme ; `EquipmentPage.PresetBar.extra_actions` reçoit les actions
  ajoutées plus tard, ex. « Équiper le meilleur »). La fiche d'objet est cachée sans sélection ; une pièce
  choisie montre la pièce portée à côté (▲ / ▼ en %, puissance d'équipement). Pas de préréglages ni de Forge
  dans le menu pause de la Survie.
- **Classe** : maîtrise et parcours toujours visibles, puis trois sous-onglets Sorts (un clic ouvre le Grimoire
  sur le sort), Talents (points et « Réinitialiser » seulement ici), Certificats (plateau, bonus, liste).
- **Apparence** : « Débloqués uniquement » activé par défaut (compteur « 1 / 122 », « 121 à découvrir »).
- Plus aucune mention du jeu d'origine (« Eden Eternal : … » sur sorts et talents, niveaux d'Eden) ; la
  description d'un sort n'est plus répétée sous « Effets » ; LB / RB changent de section ; « ? » ouvre le Guide
  (Détails) : plus de page d'aide à part dans l'écran Héros.

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
  Forge, gemmes → la Tour, enchantements → le Siège). Moins équipées d'abord ; un clic ouvre l'équipement de la classe.
  Lobby : « N / 60 classes équipées » dans le pied de page (un clic ouvre le Registre).

## Impact visuel

Arcs de lame épais et lumineux (cœur blanc, bloom), ondes de choc au sol avec poussière,
éclairs d'impact sur les coups de compétence et les critiques, effets d'Eden 1,5× plus opaques.
Salto du Samouraï : bond de ~4 m avec rotation complète, onde de choc à la retombée.
Toupie du Guerrier : 3 tours réels du modèle, un coup par tour, annulable par esquive ou saut.

## Monnaies, coffres et zones (refonte 0.1.25)

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
(pilier de lumière) : 3 **enclumes** (+1 garanti sur une pièce portée), 2 **autels du scribe** (parchemin
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

## Joaillerie et forge (comme dans Eden)

- **Emplacements de gemmes** : 2 max par objet, percés aux **ciseaux de sertissage**
  (1er sûr, 2e à 70 % ; en cas d'échec les ciseaux se brisent, l'objet est intact).
- **Gemmes** : Rubis (Force), Émeraude (Agilité), Saphir (Intelligence), Perle (Sagesse),
  Topaze (Chance), Grenat (PV), Onyx (Défense), Améthyste (Critique) ; 5 qualités
  (brut, taillé, pur, parfait, royal : ×1 / 2 / 3,5 / 5,5 / 8). Sertir dans un emplacement
  occupé détruit l'ancienne gemme.
- **Parchemins d'enchantement** (noms d'Eden) : Chant rapide, Violence, Optimisation,
  Explosion musculaire (armes et gants) ; Légèreté, Compréhension, Rééducation, Récupération
  (armures). Lv1 à Lv5 selon le niveau du butin, objet de niveau (Lv-1)×10 minimum ;
  un enchantement par objet (le nouveau remplace l'ancien).
- **Amélioration à risque** : réussite 100 % jusqu'à +3, puis 90 / 80 / 70 / 60 / 50 / 40 /
  30 % jusqu'à +10. Chaque réussite : stats de base +10 % et **une stat aléatoire** (doublée
  aux paliers +4, +6, +8, +10). Échec : matériaux perdus ; vers +6 et au-delà, l'objet perd un
  niveau (et sa dernière stat aléatoire). **Pierre de chance** : +10 % (3 max par essai).
  **Pierre de protection** : pas de perte de niveau. Coût : **de l'or seulement**.
- Les fournitures tombent des monstres (4 %, 7 % en rage), des élites (35 %), des boss (3),
  des coffres (1, meilleur en rage) et se vendent chez les marchands ambulants. Tout se fait
  dans la **Forge** (fiche d'un objet pendant la run).

### Matières et cristaux des activités (0.1.165, lot E1 de la nuit du 15/10)

Un parchemin de fortification doit avoir un niveau au moins égal à celui de la pièce, et la Survie plafonne ses
fournitures au niveau 35 : sans autre source, aucune pièce de niveau 40 à 100 ne pouvait passer +1. Les activités
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
- **Cristaux = optimiser** : hors run, `Forge.GOLD_PER_CRYSTAL` passe de 25 à **125** (1 cristal pour 125 or). Une
  pièce de niveau 85 à +10 coûte ≈ 750 cristaux si chaque tentative réussit, ≈ 1 300 avec des pierres de
  protection : **4 à 5 clears Mythiques**. Un donjon Normal (30 cristaux) paie un +3 ou +4 sur une pièce de niveau 30.
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
  de JcJ rapporte ≈ 180-190 insignes (première heure du jour ≈ 300-450 si on gagne tout), contre ≈ 360 (époque I) à
  670 (époque IV) pour une heure de Survie gagnée.
- **Plans** : le plan d'une zone tombe à coup sûr au 1er donjon terminé de chaque difficulté (Normal compris), sinon une
  fois sur dix. **Fabrication** : les 9 emplacements (arme du type de la classe choisie, collier, anneau compris), modèle
  d'Eden du niveau du donjon (et non plus de la zone choisie au lobby).
- **Siège Normal** : aucune PE requise (Héroïque et Mythique : voir « Verrous de PE (passe P5) »).
- **Panoplie des Esprits universelle** : chaque pièce est un modèle fixe, légendaire de niveau d'Eden 70, quelle que soit la
  zone. Gagnée, elle s'ajoute à `seen_gear` (id `Pantheon.shop_id`) : l'Armurerie la revend (220 insignes) pour toutes
  les classes ; battre le Champion y ouvre l'arme des Esprits des 17 types. **Éveil** : avec 6 pièces éveillées portées
  (cerveau battu par les 5 familles), le palier 6 devient : +10 % dégâts, +5 % critique, esquive → hâte puis furie 4 s,
  recharge 4 s (au lieu de 3 s / 8 s).

### Insignes et maîtrise des 60 classes (lot E5 de la nuit du 15/10, `core/economy.gd`)

- **Barème unique** (`Economy.INSIGNIA_PER_HOUR`, contrôlé par `test_e5`) : la Survie est la référence (≈ 360 insignes / h
  gagnée en époque I, 670 en époque IV, formule `Economy.survival_insignia`) ; le JcJ contre l'IA reste en dessous (≈ 400
  la 1re heure du jour, puis ≈ 60) ; Donjons, Ruée, Siège et Tour ne donnent pas d'insignes (cristaux et matières).
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

### Atelier (lot U5 de la nuit du 15/10 : Armurerie, Fabrication, Forge)

- **Bourse commune** (`ui/workshop_purse.gd`) dans l'en-tête de l'Atelier : insignes (acquérir) et cristaux (optimiser).
- **Armurerie** (`ui/gear_shop_page.gd`) : tout le catalogue des coffres d'emplacement (`Completion.armory_ids()` : pièce → première
  époque qui la propose), compteur « découvertes / total ». Statuts : à acheter (défaut), possédées (✓), à découvrir (case « ? » avec
  emplacement et niveau, époque où la trouver dans le détail : jamais le nom), toutes. Filtres : emplacement, époque, classe (les armes de
  son type seulement). 72 pièces par page. Le détail compare avec la pièce portée : verdict, PE et trois écarts au plus. Après un achat,
  la pièce reste choisie (un double clic n'achète pas deux fois).
- **Fabrication** (`ui/fabrication_page.gd`) : une carte par donjon ; avec le plan : emplacement + « Fabriquer · N cristaux » (ce qu'il
  manque en rouge) ; sans plan : « Il tombe en terminant ce donjon » ou la condition d'ouverture ; sans aucun plan : bandeau d'état vide.
- **Forge** (`ui/forge_bench.gd`) : un panneau, six établis en haut, la pièce et son tableau **avant → après** (stats principales, qualité,
  cristaux), le coût en cristaux (rouge s'il en manque), la barre de verdict compacte et l'action principale en bas. Prix en mots
  (`MerchantPages.price_words`). La fusion de gemmes garde l'ancien taux (`Forge.FUSE_GOLD_PER_CRYSTAL` 25, `Forge.fuse_price` : 2 à 7
  cristaux hors run) : le taux de 125 la rendait presque gratuite.
- **Marchand de run** : plus de phrases d'aide (une ligne sur l'or perdu en fin de run), plus de page de fabrication de mythiques.

## Classe + arme (builds exotiques)

- On choisit **une classe** (sorts, passifs, talents, attributs) puis **une arme**, au choix
  parmi 6 types : katana, hache, dague, arc, sceptre, bâton (lobby, ou l'arme équipée).
- **Le combo d'auto-attaque, la posture, la portée et le type de dégâts du combo suivent
  l'arme** (hache = combo du Guerrier, bâton = combo magique du Magicien…) ; les sorts restent
  ceux de la classe : magicien à la hache, guerrier au bâton, voleur à l'arc…
- Les stats de base de l'arme dépendent de son type (hache surtout physique, bâton surtout
  magique) : un build exotique doit composer avec ses attributs.
- Le butin d'armes suit l'arme en main ; choisir un type dans le lobby équipe la meilleure arme
  de ce type de l'héritage (ou une arme commune neuve).

## Extraction

- Touche **X** (modifiable) ou menu pause : **10 s à survivre**, une vague encercle aussitôt le
  héros. Mourir annule l'extraction.
- Réussite : **tout l'équipement et l'inventaire rejoignent l'héritage** (améliorations,
  gemmes, enchantements compris), l'équipement porté devient l'équipement de départ ;
  +60 d'expertise. L'or, les matériaux et les fournitures restent perdus, et aucune zone n'est
  débloquée (il faut battre le boss pour ça).
- Victoire contre le boss : 1 objet gardé au choix (inchangé) ; défaite ou abandon : idem.

## Zones et biomes (progression)

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

## Roguelite : héritage

- Chaque run **repart de zéro** : pas d'or, pas de matériaux, pas de butin.
- On part avec son **équipement de départ**, choisi dans le lobby parmi l'**héritage**
  (katana commun au tout début).
- À la fin de la run (victoire, défaite ou abandon), on **garde 1 objet** au choix, avec son
  amélioration (+8 reste +8). Une pièce d'héritage portée pendant la run est mise à jour.
- Lobby : **Nouvelle partie** efface l'héritage et les statistiques (2 clics pour confirmer).
- Les 3 premières minutes, les monstres montent de 60 % à 100 % de leurs PV et dégâts.

## Boucle de jeu et Survie (refonte 0.1.123, décisions du joueur du 14/10/2026)

**Ce qui se débloque avec le temps (méta)** : les classes suivantes, les sorts des classes, les
certificats et passifs, les points de maîtrise (maîtrise de classe, déjà en place) ; les
cosmétiques ; l'équipement **pour la collection et le JcJ non normalisé** (achat au hub).

**En Survie, on part avec l'équipement du hub (0.1.164, décision du joueur du 15/10 : elle remplace celle de
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
run (dès 10 monstres tués) + 25 par carte atteinte, de quoi acheter une pièce de l'époque I (50 à 73) en 1 ou 2 runs, même perdues
(passe E6 : sur la 1re carte, ces 50 sont au prorata des 10 minutes avant la rage, voir « Équilibrage global ») ;
les premiers niveaux de chaque run montent plus vite (XP ×2 au niveau 1, ×1 au niveau 10) et le début de chaque carte est plus doux
(monstres à 45 % puis 100 % sur 5 min). Mesures et plafonds : `conception/nuit_15_10/N1_survie_equipement.md`.

**Époques** : une run = 3 maps d'une même époque ; la puissance est normalisée (on repart du
niveau 1, la puissance d'une pièce suit le niveau du héros, plafonné à chaque map) ; l'époque
change les pièces d'Eden proposées (modèles, panoplies, raretés) et la difficulté des monstres.
Battre le boss final d'une époque débloque la suivante. **Ce qui compte dans une pièce** (la normalisation par le
niveau ne change pas) : sa rareté (×0,85 commune à ×1,32 légendaire sur les stats de base), son jet de qualité, son
+N du hub (+10 % des stats de base par niveau, ×2 à +10), ses gemmes (valeurs plates suivant le niveau du héros comme
les pièces : × 0,09 × 1,08^(niveau − 1), passe E6), son enchantement, son passif d'arme et les bonus de panoplie (2 / 4 / 6 pièces).

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
certificat. L'enclume vise aussi la cape. Un coffre d'équipement propose **3 pièces au hasard** parmi toutes les pièces de son
emplacement au palier et à la rareté de la map (au palier 23 : 6 panoplies), avec **une relance
par coffre**. Les armes sont de tous les types : changer d'arme change le combo d'auto-attaque.
Départ : l'arme du hub (plus de choix d'arme au départ depuis 0.1.164). Les monstres ne lâchent plus
d'équipement (or, expérience, fournitures, clés).

**Enclume, une fois par map** (remaniée en 0.1.164) : on choisit un emplacement, il reçoit un tirage pondéré de
+0 à +7 (le plus souvent +2 à +4, moyenne ≈ +3,2), **ajouté au +N de la pièce portée** dans cet emplacement (celui du
hub), quelle qu'elle soit, pour toute la run ; **le total est plafonné à +12** (`Run.UPGRADE_CAP`, ×2,2 sur les
stats de base). Elle rattrape donc surtout les pièces peu améliorées (une pièce +10 gagne au plus +2), sans faire
exploser les stats ; plus de tirages négatifs (le hub compte maintenant). Un nouveau tirage sur le même emplacement
remplace l'ancien. Les cartes d'amélioration d'arme restent plafonnées (niveau 8 par arme, `WeaponAttacks.MAX_RANK`) ;
les cartes de sort ont leur propre plafond de rang ; elles s'ajoutent aux stats de l'équipement sans le remplacer.

**Cartes** : la montée de niveau propose toujours des cartes ; les coffres de cartes (sort,
passif, certificat) permettent de viser un type.

**Hub, collection** : une pièce choisie au moins une fois dans un coffre de Survie devient
achetable au hub (collection, JcJ), avec une monnaie gagnée en run selon la distance parcourue.

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
- **Écart d'époque** (`Epochs.MONSTER_MULT`, PV et dégâts des monstres) : **×0,85 / ×1,7 / ×3,4 / ×7** (avant ×1 / 1,35 / 1,75 / 2,2 ;
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
  se juge au niveau de son 4e boss (Héroïque ≈ 41 500).
- **Siège** (`Siege.POWER_RATIO`) : Normal 0, Héroïque ×4, Mythique ×3,4 (61 200 : ≈ équipement complet).
- **Butin légendaire des coffres** (`GearPower.LEGEND_RATIO`) : ×1,8 (coffre de niveau 40 : ≈ 16 200, vers l'époque II ;
  niveau 90 : 32 400, vers l'époque III gagnée).
- Pages Donjon, Siège et Ruée : jauge « PE requise · la tienne » sous la difficulté (verte quand elle suffit), le bouton
  fermé dit seulement « Puissance d'équipement insuffisante ».
- Bilan de la Survie : l'infobulle des insignes lit `Run.insignia_parts` (participation au prorata d'une run courte, cartes
  suivantes, monstres et élites plafonnés, victoire, bonus du défi / du rang héroïque, autel) ; les lignes font le total.
- **Tour** : 3 / 4 / 5 / 6 cristaux par étage (avant 1 à 2,5, `ActivityLoot.TOWER_PER_FLOOR`) : entre l'époque I gagnée et les
  Donjons (époque II), c'est la seule source de cristaux (≈ 120 / h en Normal, sous un Donjon Normal à 180).

## Étapes et sources (refonte 0.1.91, façon Megabonk)

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
| +1 sans risque | enclumes (3 par carte) |
| Équipement commun → épique | monstres (5 %), coffres simples (choix de 3), marchands |
| Équipement rare → mythique | coffres ouvragés (mythique 7 % par proposition) |
| Équipement épique → légendaire | coffres dorés (légendaire 15 %, mythique 22 % par proposition) |
| Mythique / légendaire garantis, sets | coffres de récompense : boss d'étape (100 %), stèles du défi (100 %), élites (20 %) |

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
- Flux continu de meutes (4 → 9 monstres, toutes les 6 → 3,5 s ; en rage 8–12 toutes les 2 s).
- **Vagues alternées** toutes les 45 s (30 s en rage) : *encerclement* (anneau de monstres
  + une élite, difficile) puis *horde* (beaucoup de monstres plus faibles, facile).
- Chaque attaque de monstre est **annoncée au sol** selon son modèle : cône au corps à corps,
  ligne de charge (le monstre fonce), cercle d'écrasement, trait de tir. Sortir de la zone,
  esquiver (Maj) ou **sauter** au bon moment évite le coup.
- Les monstres ont ~2,4× leurs PV d'Eden et frappent fort : l'auto-attaque seule ne suffit
  pas, il faut kiter et placer ses compétences. 1 seule résurrection par run.

## Sceaux du donjon

- L'entrée du donjon est **scellée** : il faut **3 sceaux**.
- Chaque camp d'élite a un **gardien** (élite + 4 gardes) qui porte un sceau ; les autres
  élites ont 30 % de chances d'en lâcher un.
- La clairière de l'ancien village (un marchand ambulant y démarre) est du côté du départ.

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

## Map générée

- Terrain ~512 × 512 m, relief doux, bordure de falaises, chemins qui relient les lieux.
- Lieux placés aléatoirement à bonne distance : départ, entrée du donjon, 10 coffres payants,
  10 sanctuaires, 3 marchands ambulants, camps de monstres, camps d'élites.
- Décor Eden (arbres, rochers, buissons, ruines) dispersé hors des chemins et clairières.
  Collisions simples (cylindre / boîte), petits objets sans collision.
- Brouillard de guerre : la mini-carte se révèle en explorant ; les lieux découverts y restent.

## Marchands ambulants (remplacent le village)

- 3 par carte, ils se promènent autour de leur place et s'arrêtent face au héros.
- Un seul écran par marchand : **Boutique** (3 cartes, 1 clé, fournitures, équipement rare ou
  épique, parfois un trophée ; offres tirées pour ce marchand), **Vendre** (filtres, sélection
  multiple, sélections rapides), **Fabriquer** (mythiques de la zone, or + cristaux).

## Équipement

- Chaque objet a un **type de base** (ex. katana : orienté physique) avec des stats de base.
- **Objets d'Eden** (`data/eden_catalog.json`) : chaque objet du jeu est un vrai objet d'Eden
  (nom, icône, stats connues, set, passif). Son niveau affiché est son niveau d'Eden ; chaque
  zone couvre une tranche d'Eden (de son niveau de carte à celui de la zone suivante, la
  dernière jusqu'à 100) parcourue au fil de la run : pas d'objet d'une zone plus avancée. Sa
  puissance (« plevel ») est le niveau de run où il est tombé : stats = référence du jeu ×
  rapport de l'objet dans Eden × rareté. Au-delà du niveau 40 d'Eden (où les objets courants
  s'arrêtent), le butin courant prend un modèle courant du bon niveau.
- **6 raretés** : commun, spécial, rare, épique (jets aléatoires : qualité 70-90 %, 75-95 %,
  80-100 %, 85-100 %), **mythique** (toujours 100 %) et **légendaire** (101-120 %). Mythiques et
  légendaires : seulement sur les boss (garanti, 30 % de légendaire, 50 % si enragé) ou par
  fabrication (mythiques) ; ils portent le passif d'arme et les effets de set d'Eden.
- **Amélioration +1 → +10** : augmente les stats de base à chaque niveau ; aux paliers
  **+4, +6, +8, +10**, une stat aléatoire de l'objet est en plus augmentée (ou un affixe ajouté).
- **Désassemblage** → des **cristaux** selon la rareté (gardés entre les runs). **Vente** → or
  **+ la moitié de l'or** investi dans les améliorations.

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
  (ralentit) ; faux Faux / Salve. L'arme (son modèle d'Eden) décide de la variante ; au départ de
  la Survie, le joueur choisit entre les deux variantes de l'arme de sa classe.
- **Arme principale = arme de la classe**, toujours (la case n'accepte que ce type). Une arme
  d'un autre type ne peut être que l'**arme secondaire** : son auto-attaque part **seule**, sans
  animation, vers l'ennemi le plus proche, à **60 % des dégâts** et avec **50 % de ses stats
  d'objet** ; elle ne compte pas pour les sets. En Survie, elle se **trouve en jeu** : le boss en
  lâche toujours une, une élite parfois (40 % sans arme secondaire, 12 % avec) ; ramassée, elle
  propose 3 armes d'autres types (variante au hasard, une relance). Les coffres d'arme ne donnent
  que l'arme de la classe.
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

## Sets d'équipement (façon Eden)

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
  compare avec le bonus d'enclume de son emplacement. Rien ne parle du jeu d'origine.

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

## Choix et coffres de récompense (lot U3 de la nuit du 15/10)

- **Choix de carte en un geste** : un clic sur une carte (ou 1, 2, 3, ou A à la manette) la choisit, plus de bouton
  « Valider ». Pendant les 0,3 premières secondes les cartes sont voilées et ignorent tout (anti-rafale). Une pièce
  d'équipement montre 4 statistiques au plus ; les lignes communes à toutes les cartes (« Emplacement libre », les mêmes
  statistiques des deux variantes d'une arme) sont dites une fois sous la rangée.
- **Coffres** (menu Coffres) : une ligne par genre, c'est-à-dire par type et par spécialité (« Coffre de forge »,
  « Coffre de forge · parchemins », « Coffre de joaillier · formules »…), une pastille d'icône par type en plus de la
  couleur, « Ouvrir tout (N) », une phrase sans chiffre par genre (le détail du contenu est dans l'infobulle).
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
  Jamais en partie. Une activité fermée est remplacée par son échelon (« Gagne l'époque II : les Donjons s'ouvrent »).
- **Bilans** : une ligne « Ta quête » (`spec.quest`, `Compass.after(mode, gains)`) dit ce que le gain change (« plan obtenu »,
  « panoplie Tempête 2 / 6 : un coffre de set donne +1 pièce », « 170 cristaux pour la Forge », « Esprits 1 / 6 »…), puis la suite.
- **Pages Donjon, Siège, Ruée** : sous la difficulté choisie, la jauge de la première difficulté plus dure encore fermée par la PE.
- Parcours de la première heure : Survie, bilan, boussole « une pièce est achetable », Armurerie, « À équiper : Héros >
  Équipement » (le dernier pas après un achat), boussole suivante. Test : `tests/test_compass.tscn`.
- **Option** (P10) : Paramètres > Caméra et interface > « Afficher la boussole d'objectif » (`Settings.show_compass()`, activée
  par défaut) ; désactivée, la pastille disparaît du lobby (la ligne « Ta quête » des bilans reste).

## Tout le jeu en français (passe P10, 0.1.190)

Aucun texte lisible ne doit rester en anglais. Les noms d'Eden passent par une seule table (`data/names_fr.json`, `NamesFr.apply`,
générée par `tools/names_fr_build.py`, ids inchangés, nom d'origine dans `name_en`) : équipement, panoplies, monstres, zones,
apparences, collection et, depuis P10, **talents** (section `talents`, lexique à la main dans `tools/names_fr_talents.py`).
- **Passif d'une pièce d'Eden** : seul l'effet est écrit (« ✶ Passif : à l'impact, 10 % de chances : Puissance »). Son nom d'origine
  était un libellé anglais sans intérêt (souvent le nom de la pièce) ; le passif d'un trophée de la run garde son nom français.
- **Test** : `tests/test_texts_fr.tscn` parcourt les cartes des 5 947 pièces, panoplies, trophées, boons, cartes de classe, succès, titres,
  sorts, certificats, talents, monstres, zones et toutes les constantes de texte des scripts, et signale les mots anglais courants
  (liste de contrôle `ENGLISH`). Un nouveau texte d'Eden à afficher : le passer par la table, relancer ce test.

## Plafond de niveau par zone

- Limestone (map 1) : butin au niveau 15 maximum, monstres plafonnés au niveau 15 (18 en rage
  et pour le boss). Les maps suivantes prendront le relais (`RunDirector.ZONE_MAX_LEVEL`).

## Ordre de réalisation

1. Générateur de map (DA Eden) + run de 10 min + rage + lieux à découvrir.
2. Équipement à jets, matériaux, marchand (vendre / désassembler / améliorer), boutique.
3. Arène du boss, attaques annoncées, invocations.
4. Performance pour des vagues de centaines de monstres.

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

## Méta-progression des cartes et classes (0.1.33)

- **Classes** : règles par famille (Progression.UNLOCKS) — voir AUDIT.md partie 1.
- **Cartes** : 12 disponibles d'emblée, 18 à débloquer par exploits cumulés (Cards.UNLOCK) ;
  Bannir / Garder 3 fois chacun par run ; page Héros > Cartes.
- **Coffres de la carte** : prix doublé à chaque ouverture.

## Équipement en run (0.1.34)

- Puissance d'un objet = niveau du héros de la run, plafonnée au niveau de l'objet
  (Items.power_cap) ; hors run : la puissance maximale. Améliorations, gemmes, enchantements
  gardés entre les runs.
- Stats fixes, jet de qualité seulement ; stat bonus aléatoire aux paliers +4 / +6 / +8 / +10
  (Craft._upgrade_roll), réforgeable aux cristaux.
- Comparateur (Items.rating, Items.compare_to_equipped) : ▲ / ▼, % sur la fiche, alerte en
  run et touche G (quick_equip).
