# Survivant : décisions du joueur (15/10/2026) — PRIMENT SUR `SPEC.md`

Le joueur a relu la spécification de S0 et a tranché. Là où ce fichier contredit `SPEC.md`, **ce fichier gagne**. Tout agent
qui code un lot S* lit d'abord ce fichier, puis `SPEC.md` (en corrigeant mentalement les passages contredits).

## 1. Les pièces : tous les sets de niveau 90, stats d'origine

- Le pool de pièces = **tous les sets de niveau 90** du catalogue d'Eden (déjà nombreux, avec de petites variantes visuelles : parfait).
  Fini « 3 panoplies tirées par run parmi les archétypes » de SPEC §pièces.
- **Pas de stats aléatoires.** On garde les **stats d'origine** de la pièce (celles du jeu actuel, `Items.stats`) : plus simple pour retenir
  quelle pièce sert à quelle classe, et ça rend chaque pièce unique. Les stats de la pièce « sans amélioration » sont celles d'aujourd'hui,
  **adaptées au niveau de la run** (`Items.power_level` : suit le niveau du héros, plafonné à 90).
- On garde le **système de pourcentage de 100 % à 120 %** (la qualité / le jet de la pièce, déjà dans le jeu : qualité de pièce). C'est la seule part
  aléatoire des stats. Le jet parfait = 120 %.

## 2. Passifs : un fixe par pièce, trois qui s'ajoutent à +6, +8, +10

- Le **premier passif**, « en dur », est **fixe** pour une pièce donnée (pas tiré au hasard à chaque run) et **différent pour chaque pièce d'un même
  set** (deux pièces du même set n'ont jamais le même passif de base). Source des effets : les effets des cartes communes actuelles (`Cards`) ; à
  définir comme une table pièce → passif, déterministe (par exemple par emplacement + indice du set), sans doublon dans un set.
- Une pièce **+10 finale porte 4 passifs** : le fixe + trois qui viennent des paliers **+6, +8 et +10**. Ces trois-là sont **aléatoires**, forcément
  **différents du passif fixe et différents entre eux**.
- **Quand la carte d'amélioration d'une pièce** (vers +6, +8 ou +10) est proposée, le passif du palier est **tiré à ce moment-là et affiché sur la
  carte** : le joueur le voit et peut **prendre la carte avec ce passif, prendre une autre carte, garder, bannir ou choisir** (relance / bannissement
  comme les autres cartes). Pas de passif subi à l'aveugle.
- Les bonus des cartes communes ne sont plus dans les cartes : ils viennent de ces passifs (comme dans SPEC).

## 3. Bonus de panoplie : +2, +3, +5 sur TOUS les sets

- Retravailler les bonus de set complets : **chaque set** donne des bonus à **2, 3 et 5 pièces** (au lieu des paliers actuels d'Eden).
  Valeurs courtes et lisibles, génériques par famille de set (à définir avec les profils de stats, sans réécrire 326 sets à la main : règle
  paramétrée par le type / l'archétype du set, plus quelques sets signature).
- **Avoir 5 pièces d'un même set doit être rare, mais exceptionnel** (récompense forte). Les propositions doivent donc mélanger les sets ; vérifier par
  simulation la fréquence d'un 5/5 (cible : de l'ordre de 1 run sur 20-30 pour un joueur qui cherche un set).

## 4. Départ et première carte

- On démarre **sans arme** (et sans équipement).
- **La première carte obligatoire donne soit une compétence, soit une arme** : le joueur choisit entre des cartes qui sont toutes de ces deux familles.
- **Deux relances offertes de base** (en plus de ce qui existe) : avec elles le joueur a de quoi choisir. Bannir / garder comme décrit en §2.

## 5. Aucun lien avec la progression du compte

- **Mode à part, « pour s'amuser » :** aucun lien avec la progression actuelle (pas d'équipement du hub, pas de pool lié à la collection, pas de
  maîtrise, pas d'insignes, pas de découvertes à l'Armurerie, pas de verrou « après une première Survie »).
- On y joue avec **les classes débloquées** et **les apparences débloquées** (l'apparence portée au hub s'affiche), rien d'autre.
- **Récompense de fin** : seulement des **coffres d'apparence** (par exemple selon l'avancée : atteinte du boss, victoire, difficulté), jamais de
  puissance ni de monnaie de progression. Les paliers / difficultés (SPEC S8) restent un contenu du mode, récompensés en apparences et titres.
- Le mode est **visible et jouable dès le départ** (plus de verrou ni de « mode dev seulement » une fois S6 fini ; pendant le développement :
  visible en mode dev).
- Le hub n'est jamais modifié (instantané / restauration, comme la Survie).

## 6. Ce qui ne change pas (rappel de SPEC)

Boucle de 20 minutes, géants gardiens à 5 / 10 / 15 min, boss à PV fixes démesurés à 20:00 avec rage du boss, 3 cartes à chaque niveau avec une carte
d'équipement et une carte de sort, emplacements d'équipement verrouillés à vie, arme fixée à vie, sorts de 1 à 10 avec effet cumulé, Menace, HUD et
panneau de build, lots S1 à S8 (avec les corrections ci-dessus dans S2 pièces et arme, S3 cartes, S6 récompenses).
