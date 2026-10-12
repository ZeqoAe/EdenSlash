# Eden Slash — conception d'une run

Direction artistique : celle d'Eden Eternal (textures de sol, arbres, rochers, maisons,
coffres, PNJ, monstres, armes et tenues du jeu d'origine). Les maps de combat sont
générées à chaque run, avec nos propres collisions simples.

## Roguelite : héritage

- Chaque run **repart de zéro** : pas d'or, pas de matériaux, pas de butin.
- On part avec son **équipement de départ**, choisi dans le lobby parmi l'**héritage**
  (katana commun au tout début).
- À la fin de la run (victoire, défaite ou abandon), on **garde 1 objet** au choix, avec son
  amélioration (+8 reste +8). Une pièce d'héritage portée pendant la run est mise à jour.
- Lobby : **Nouvelle partie** efface l'héritage et les statistiques (2 clics pour confirmer).
- Les 3 premières minutes, les monstres montent de 60 % à 100 % de leurs PV et dégâts.

## Déroulement d'une run (10 minutes + rage)

| Phase | Ce qui se passe |
|---|---|
| 0:00 → 10:00 | Exploration d'une map générée : farmer, trouver le **village**, l'**entrée du donjon**, les **coffres** et les **PNJ**. Monstres de la zone, élites ponctuelles. |
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
- Le village est du côté du départ, à ~200 m de l'entrée du donjon.

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
- Lieux placés aléatoirement à bonne distance : départ, village, entrée du donjon,
  8 à 12 coffres, PNJ, camps de monstres, camps d'élites.
- Décor Eden (arbres, rochers, buissons, ruines) dispersé hors des chemins et clairières.
  Collisions simples (cylindre / boîte), petits objets sans collision.
- Brouillard de guerre : la mini-carte se révèle en explorant ; les lieux découverts y restent.

## Village (dans la run)

- **Marchand** : vendre (or), désassembler (matériaux), améliorer (or + matériaux).
  Filtres par rareté et type de pièce, tri (rareté, niveau, type, valeur), sélection multiple
  (clic, Ctrl+clic, Maj+clic, Ctrl+A), sélection rapide (communs, jusqu'à magique), bouton
  « tout vendre / désassembler » sur le filtre (2 clics pour confirmer), comparaison avec la
  pièce portée et aperçu du gain d'une amélioration.
- **Boutique** : 6 offres aléatoires — compétences (tant que les 4 ne sont pas trouvées),
  améliorations de compétence, passifs, équipement de rareté supérieure de la zone.

## Équipement

- Chaque objet a un **type de base** (ex. katana : orienté physique) avec des stats de base.
- À la création (butin, achat, craft), un **jet de qualité entre 90 % et 120 %** des stats
  de base, plus des **affixes aléatoires** selon la rareté (valeurs tirées dans une fourchette).
- **Amélioration +1 → +10** : augmente les stats de base à chaque niveau ; aux paliers
  **+4, +6, +8, +10**, une stat aléatoire de l'objet est en plus augmentée (ou un affixe ajouté).
- **Désassemblage** → matériaux selon la rareté et le niveau, **+ 70 % des pierres** dépensées
  en améliorations. **Vente** → or **+ 70 % des pierres** d'amélioration.

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
