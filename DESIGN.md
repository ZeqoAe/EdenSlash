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
mythique / légendaire et fournitures). Ancien fonctionnement : 10 coffres à prix doublé, choix de cartes ; 10 **sanctuaires** à capturer (rester 14 s dans
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
  Esquiver avant l'impact annule la compétence (perdue).

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

## Combo d'auto-attaque

- 3 coups enchaînés (le suivant doit partir moins de 0,6 s après la fin du précédent) :
  coup de sabre dans un sens, dans l'autre (+15 %), puis **coup final** : saut automatique,
  frappe en zone à 360° (220 %), renverse 0,4 s. Indicateur « Combo ◆◆◇ » sur la barre.
- Défini par classe dans `classes.json` (`combo` : animation, multiplicateur, arc, rayon,
  saut, élan, effets) : chaque future classe aura son propre enchaînement.
- Cartes liées : Enchaînement fluide (fenêtre plus longue), Coup de grâce (+40 % au coup
  final), Onde de choc, évolution Tempête d'acier (le coup final frappe deux fois en tourbillon).

## Effets déclenchés (procs)

Un proc = déclencheur + chance + recharge interne + effet (`scripts/combat/procs.gd`).
- Déclencheurs : impact, impact d'une compétence, critique, monstre tué, coup final du combo,
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
