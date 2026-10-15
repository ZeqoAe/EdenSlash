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
  ×15, monstres ÷2, élites ×10, +200 en cas de victoire.
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
cupidité** (+50 % d'or et de butin, monstres +25 %), 2 **stèles du défi** (3 élites : coffre de récompense
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
| Tour | 1 / 1,5 / 2 / 2,5 par étage monté (Facile à Hardcore) | gemmes tous les 10 étages, forge tous les 50 (niveau de l'étage) |

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
- **Siège Normal** : aucune PE requise (Héroïque 65 %, Mythique 90 %).
- **Panoplie des Esprits universelle** : chaque pièce est un modèle fixe, légendaire de niveau d'Eden 70, quelle que soit la
  zone. Gagnée, elle s'ajoute à `seen_gear` (id `Pantheon.shop_id`) : l'Armurerie la revend (220 insignes) pour toutes
  les classes ; battre le Champion y ouvre l'arme des Esprits des 17 types. **Éveil** : avec 6 pièces éveillées portées
  (cerveau battu par les 5 familles), le palier 6 devient : +10 % dégâts, +5 % critique, esquive → hâte puis furie 4 s,
  recharge 4 s (au lieu de 3 s / 8 s).

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
run (dès 10 monstres tués) + 25 par carte atteinte, de quoi acheter une pièce de l'époque I (50 à 73) en 1 ou 2 runs, même perdues ;
les premiers niveaux de chaque run montent plus vite (XP ×2 au niveau 1, ×1 au niveau 10) et le début de chaque carte est plus doux
(monstres à 45 % puis 100 % sur 5 min). Mesures et plafonds : `conception/nuit_15_10/N1_survie_equipement.md`.

**Époques** : une run = 3 maps d'une même époque ; la puissance est normalisée (on repart du
niveau 1, la puissance d'une pièce suit le niveau du héros, plafonné à chaque map) ; l'époque
change les pièces d'Eden proposées (modèles, panoplies, raretés) et la difficulté des monstres.
Battre le boss final d'une époque débloque la suivante. **Ce qui compte dans une pièce** (la normalisation par le
niveau ne change pas) : sa rareté (×0,85 commune à ×1,32 légendaire sur les stats de base), son jet de qualité, son
+N du hub (+10 % des stats de base par niveau, ×2 à +10), ses gemmes (valeurs plates suivant le niveau du héros,
pleines au niveau 15), son enchantement, son passif d'arme et les bonus de panoplie (2 / 4 / 6 pièces).

| Époque | Maps (zones) | Armures | Armes | Raretés |
|---|---|---|---|---|
| I | Limestone, Rainbowfall, Beluga | 23, 33, 43 | 20, 30, 40 | mythique |
| II | Wetlands, Avila, Arid | 48, 53, 60 | 45, 50, 60 | mythique, mythique, légendaire |
| III | Delphi, Blackflame, Wetlands | 65, 70, 70 | 65, 70, 75 | légendaire, légendaire, éveillé |
| IV | Avila, Arid, Blackflame | 80, 85, 80 | 80, 85, 90 | légendaire, légendaire, éveillé |

Mythique = orange, légendaire = jaune, éveillé = jaune avec une aura sur l'icône (pièces
« Awaken » d'Eden, niveaux 70 et 80).

**Coffres d'emplacement** (les 30 coffres payants de la map) : arme, tête, torse, jambes, gants,
bottes, bijoux (bague, collier, boucles), trophée, carte de sort, carte de passif, carte de
certificat. Un coffre d'équipement propose **3 pièces au hasard** parmi toutes les pièces de son
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

## Déroulement d'une run (10 minutes + rage)

| Phase | Ce qui se passe |
|---|---|
| 0:00 → 10:00 | Exploration d'une map générée : farmer, ouvrir les **coffres** (or ou clé), capturer les **sanctuaires**, trouver les **marchands ambulants** et l'**entrée du donjon**. Monstres de la zone, élites ponctuelles (clés). |
| 10:00 → … | **Rage** : monstres plus forts, monstres de niveau supérieur, élites en masse. Plus d'XP et de butin. |
| N'importe quand | Si l'entrée du donjon est découverte **et 3 sceaux réunis** : entrer → **arène du boss**. |
| Boss | Combat direct dans une arène dédiée. Attaques annoncées par des **zones rouges au sol** (cercle, ligne, cône au corps à corps, projectiles à distance) + monstres invoqués autour. Être touché = **étourdi** 1 à 1,5 s. **Miroir** toutes les 12–17 s pendant 3 s : frapper le boss renvoie 60 % des dégâts. L'onde circulaire (bord jaune) se **saute**. |
| Fin | Victoire (boss vaincu) ou défaite → bilan → lobby. |

## Pression constante (easy to play, hard to master)

- **Tous les monstres de la map traquent le héros** : jamais besoin d'aller les chercher.
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
  anneau), Détente (attaque, sorts et enchaînements automatiques), Bot (+ déplacement et cartes).
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
