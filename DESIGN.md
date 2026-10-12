# Eden Slash — conception d'une run

Direction artistique : celle d'Eden Eternal (textures de sol, arbres, rochers, maisons,
coffres, PNJ, monstres, armes et tenues du jeu d'origine). Les maps de combat sont
générées à chaque run, avec nos propres collisions simples.

## Déroulement d'une run (10 minutes + rage)

| Phase | Ce qui se passe |
|---|---|
| 0:00 → 10:00 | Exploration d'une map générée : farmer, trouver le **village**, l'**entrée du donjon**, les **coffres** et les **PNJ**. Monstres de la zone, élites ponctuelles. |
| 10:00 → … | **Rage** : monstres plus forts, monstres de niveau supérieur, élites en masse. Plus d'XP et de butin. |
| N'importe quand | Si l'entrée du donjon est découverte : entrer → **arène du boss**. |
| Boss | Combat direct dans une arène dédiée. Attaques annoncées par des **zones rouges au sol** (cercle, ligne, cône au corps à corps, projectiles à distance) + monstres invoqués autour. |
| Fin | Victoire (boss vaincu) ou défaite → bilan → lobby. |

## Map générée

- Terrain ~512 × 512 m, relief doux, bordure de falaises, chemins qui relient les lieux.
- Lieux placés aléatoirement à bonne distance : départ, village, entrée du donjon,
  8 à 12 coffres, PNJ, camps de monstres, camps d'élites.
- Décor Eden (arbres, rochers, buissons, ruines) dispersé hors des chemins et clairières.
  Collisions simples (cylindre / boîte), petits objets sans collision.
- Brouillard de guerre : la mini-carte se révèle en explorant ; les lieux découverts y restent.

## Village (dans la run)

- **Marchand** : vendre (or), désassembler (matériaux), améliorer (or + matériaux).
- **Boutique** : 6 offres aléatoires — compétences (tant que les 4 ne sont pas trouvées),
  améliorations de compétence, passifs, équipement de rareté supérieure de la zone.

## Équipement

- Chaque objet a un **type de base** (ex. katana : orienté physique) avec des stats de base.
- À la création (butin, achat, craft), un **jet de qualité entre 90 % et 120 %** des stats
  de base, plus des **affixes aléatoires** selon la rareté (valeurs tirées dans une fourchette).
- **Amélioration +1 → +10** : augmente les stats de base à chaque niveau ; aux paliers
  **+4, +6, +8, +10**, une stat aléatoire de l'objet est en plus augmentée (ou un affixe ajouté).
- **Désassemblage** → matériaux (quantité et type selon la rareté et le niveau d'amélioration).

## Ordre de réalisation

1. Générateur de map (DA Eden) + run de 10 min + rage + lieux à découvrir.
2. Équipement à jets, matériaux, marchand (vendre / désassembler / améliorer), boutique.
3. Arène du boss, attaques annoncées, invocations.
4. Performance pour des vagues de centaines de monstres.
