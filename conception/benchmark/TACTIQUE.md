# Étude comparative : mode tactique 4 contre 4 « L'Assaut » (équipe BM-TAC, 17/10/2026, jeu en 0.1.284)

Méthode : `conception/benchmark/METHODE.md`. DA de référence : `conception/art/BIBLE.md` v2 (« autocollant manga »).
Demande du joueur (17/10) : un mode 4 contre 4 par manches façon Counter-Strike / Valorant (poser et désamorcer une charge, attaque et
défense, achat entre les manches, une vie par manche) ou façon Overwatch (objectifs), avec des cartes conçues pour le mode, des équipes
IA scriptées qui jouent très bien (pas de cerveau neuronal), mode scellé, solo contre l'IA. **Le mode n'existe pas encore** : cette
étude compare les références à nos modules les plus proches (Arènes 2v2 / 3v3, Battle royale v2, Duel, Siège) puis spécifie le mode.
Croquis maison : `conception/benchmark/tactique_maquettes/` (4 croquis `v2_*.svg` + 3 plans masse `plan_*.svg`, ouvrir dans un navigateur).
Hors dépôt : `C:\AI\benchmark_refs\tactique\` (liste des pages lues `SOURCES.txt`, nos captures de HEAD 0.1.284 en 1600×900 :
`eden_slash_0.1.284\m7_*`, outil `tests/shot_m7.tscn` sur une copie propre). **Aucune image tierce n'a été téléchargée** (un
téléchargement demande l'accord du joueur) : les références sont analysées d'après des pages lues en ligne et la connaissance du genre.

Légende : **vérifié** = lu dans une source citée au § 12 (souvent un guide ou un wiki, pas l'éditeur : « source secondaire ») ;
**non vérifié** = connaissance générale du genre, non confirmée pendant l'étude. Tailles : **S** ≤ ½ jour, **M** 1 à 2 jours, **L** 3 à 5 jours
(jours d'agent).

---

## 1. Résumé

**Choix** : format principal **« L'Assaut »** (une Charge à poser sur l'un de deux sites, attaque / défense, une vie par manche, or et
achat entre les manches : la famille Counter-Strike / Valorant) ; format secondaire **« Le Sanctuaire »** (un point au centre, symétrique,
une vie par manche, sans économie : la famille Brawl Stars « Knockout » / Battlerite, servi en format court et en apprentissage).
L'escorte et les points à respawn d'Overwatch sont écartés (§ 7.1) : ils demandent des réapparitions, contraires à « une vie par manche ».

**Ce qui fait la qualité des références** (et que nous n'avons pas) : (1) **l'information** — on ne voit pas à travers les murs, on entend,
le radar partage ce que l'équipe voit, et chaque manche est une suite de paris sur ce qu'on ne sait pas ; (2) **l'économie** — perdre
coûte la manche suivante, ce qui crée des manches « à petit budget » et des retournements ; (3) **l'objectif** qui force le contact et
donne un rôle à chacun (porter, poser, tenir, reprendre, désamorcer) ; (4) **les utilitaires** (fumée, aveuglement, feu, reconnaissance)
qui transforment un duel de réflexes en jeu d'équipe ; (5) **la lisibilité** d'un écran où l'on sait toujours qui est vivant, combien de
temps il reste et où est la Charge.

**Ce que nous avons déjà et qu'ils n'ont pas** : 60 classes jouables avec de vrais sorts et une esquive, des adversaires scriptés qui
lisent les coups et esquivent (`ClassRival`, Hardcore à 0,06 s de réaction), des règles JcJ déjà bornées (pas de mort en un coup :
`hit_cap`, `burst_cap`), des alliés IA en équipe (Arènes), et presque tous les éléments du HUD du Battle royale v2 (repère, flèches hors
vue, arc de coup reçu, annonces, « Voir les sons », récapitulatif de mort, spectateur).

**Les 5 plus gros chantiers** (ce qui manque au moteur pour ce mode, par ordre de risque)
1. **Murs qui arrêtent la vue et les coups** : aujourd'hui les projectiles (`HeroBolt`) et les cônes ne testent pas le décor ; aucun
   brouillard ne cache un ennemi derrière une maison (la caméra de dessus voit tout). Sans ça, pas de mode tactique.
2. **IA d'équipe** : `ClassRival` est excellent en duel mais n'a ni plan de manche, ni rôle, ni mémoire de ce qu'il a vu ou entendu, ni
   économie. Il faut une couche « stratège d'équipe » au-dessus (§ 7.10).
3. **Rééquilibrage pour une vie** : contrôles enchaînables (insensibilité par type : renversé → terreur → gel), invisibilité jusqu'à
   plusieurs secondes, soins qui étirent les combats ; les manches d'Arène visent 30 à 90 s (85-104 s mesurés avant le réglage M7) quand il faut ici 7 à 10 s
   par combat.
4. **Cartes faites à la main** : `ProcMap` génère des prairies ; il faut un format de carte avec murs, murets, hauteurs, sites et
   positions nommées (+ données pour l'IA).
5. **Économie, achat, Charge** : rien n'existe (ni or de manche, ni objets utilitaires, ni objectif à poser).

---

## 2. Références

### 2.1 Counter-Strike 2 (Valve) : la règle d'or du genre
Vérifié (guides profilerr, gamertagmythras, csdb ; sources secondaires) :
- Format **MR12** : 24 manches au plus, premier à 13 ; à 12-12, **prolongation** en blocs de 6 manches (3 par côté) avec un or fixe
  (10 000 dans les guides) et rien d'acquis de la partie réglementaire.
- **Économie** : 800 au départ de chaque moitié ; **prime de défaite progressive** 1 400 → 1 900 → 2 400 → 2 900 → 3 400 (plafond à la
  5e défaite d'affilée). Les guides divergent sur les gains de victoire (3 250 / 3 500 selon la façon) et sur la prime de pose : non vérifié.
- **Wingman** (2 contre 2) : un seul site, cartes compactes réduites, premier à 9 en 16 manches au plus, changement de côté après 8,
  **pas de prolongation (8-8 = nul)**, manche de 1:30 (csdb, gamertagmythras). C'est le précédent le plus proche d'un « petit format ».
Non vérifié (connaissance du genre) : bombe 40 s, désamorçage 10 s (5 s avec le kit), phase d'achat ~20 s, radar qui montre ce que voient
les coéquipiers, armes qu'on laisse tomber pour un coéquipier, survivant qui garde son arme, reprise d'un bot allié après la mort en
partie occasionnelle, « callouts » (noms des lieux) affichés sous le radar.
**Ce qu'on en prend** : la prime de défaite progressive, l'or remis à la mi-temps, la prolongation à or fixe, le site unique du format
court, le radar d'équipe, « garder ce qu'on a si on survit », le relais d'un allié après la mort (en option).

### 2.2 Valorant (Riot) : la Charge, les compétences achetées, les rôles
Vérifié (oneesports, upcomer, Red Bull, Wikipédia ; secondaires) :
- **Crédits** : 800 au départ ; victoire 3 000 ; défaite 1 900, puis 2 400, puis 2 900 ; élimination 200 ; pose de la Spike +300 pour
  chaque attaquant ; désamorçage sans prime ; or remis à la mi-temps. Plafond 9 000 : non vérifié.
- **Spike** : pose 4 s, explosion 45 s après la pose, désamorçage 7 s avec un **point de sauvegarde à la moitié** (3,5 s) ; manche de 100 s ;
  à 12-12, **prolongation jusqu'à 2 manches d'écart** (Wikipédia).
- **Compétences** : 4 cases par agent — **une gratuite (signature), deux achetées à la phase d'achat, une ultime chargée par des points**
  (élimination, mort, pose, désamorçage, orbes ramassés sur la carte : 1 point chacun). Guides de 2020 : les valeurs ont pu changer.
Non vérifié : 4 rôles (Duelliste, Initiateur, Contrôleur, Sentinelle), roue de ping et pings contextuels, minimap qui montre les
ennemis vus par un allié, modes courts « Spike Rush » (premier à 4) et « Swiftplay » (premier à 5).
**Ce qu'on en prend** : **le modèle des 4 cases** (il colle à nos 4 sorts : § 7.5), la pose de 4 s / désamorçage 7 s à mi-parcours
sauvegardé, la prolongation « 2 d'écart », les orbes d'ultime sur la carte, les rôles d'équipe.

### 2.3 Overwatch 2 (Blizzard) : les objectifs à respawn
Vérifié (prosettings, guildorder, règlement start.gg ; secondaires) : **Contrôle** (un point, premier à 100 %, en 2 manches gagnantes),
**Escorte** (un convoi qui n'avance qu'avec des attaquants à côté, points de passage qui rallongent le temps), **Hybride** (point puis
escorte), **Poussée** (un robot que les deux équipes poussent), **Flashpoint** et **Clash** (points tournants / tir à la corde, peu
documentés) ; **prolongation** tant que l'objectif est disputé à la fin du temps.
Non vérifié : 5 contre 5 avec file par rôle (1 tank, 2 dégâts, 2 soutiens), passifs de rôle, changement de héros en cours de partie,
réapparition ~10 s.
**Ce qu'on en prend** : la **prolongation tant que c'est disputé** (Sanctuaire), les **passifs de rôle** (§ 7.6), la composition par rôles.
**Ce qu'on écarte** : tout ce qui suppose des réapparitions (escorte, poussée, point à 100 %).

### 2.4 Rainbow Six Siege (Ubisoft) : préparation et information
Vérifié (wiki Rainbow Six, guildorder) : mode **Bombe** seul en classé ; un attaquant porte le **désamorceur** (« Carrier ») ; pose 7 s
annulable. Les durées divergent selon les sources (préparation 30 ou 45 s, compteur après la pose) : non vérifié.
Non vérifié : phase de préparation où la défense renforce et les attaquants envoient des drones, destruction des murs, interdictions
d'opérateurs.
**Ce qu'on en prend** : un **porteur** visible de son équipe ; l'idée d'une **phase d'information** (P2 : « Œil de chouette » acheté et
lancé pendant l'achat).

### 2.5 Splatoon 3 (Nintendo) et Apex Legends (Respawn) : objectifs lisibles et couleurs franches
Vérifié (splatoonwiki) : **Tour** (l'équipe qui la tient la fait avancer ; 5 min ; prolongation tant que l'équipe menée la tient),
**Mégalodon / Rainmaker** (prolongation si l'équipe menée tient l'objet, ou 10 s pour le reprendre s'il vient d'être lâché), **Zones**
(capturées à 70 % d'encre, compte à rebours de 100), **Pluie de palourdes** (prolongation tant que l'équipe menée porte une palourde
géante). Apex (étude BM-BR, `BATTLE_ROYALE.md` § 2.2) : roue de ping contextuelle et réponses, testée sans vocal.
**Ce qu'on en prend** : des **règles de prolongation qui pardonnent à l'équipe menée** quand elle tient l'objectif, les **deux couleurs
d'équipe très contrastées** (chez nous : lagon et fraise, la bible les a déjà), le **ping comme langue** d'une équipe muette (nos alliés
sont des IA).

### 2.6 Brawl Stars (Supercell) : la lecture d'un 3 contre 3 vu de dessus
Vérifié (Wikipédia, clutchpoints, sportskeeda) : **Knockout** = 3 contre 3, **2 manches gagnantes, une vie par manche**, un gaz se
referme pendant la manche pour forcer le combat ; ancien départage au temps : le plus de survivants, puis le plus de dégâts (règle peut-être
périmée) ; une version 5 contre 5 existe.
Non vérifié : buissons qui cachent (sauf de près), zone de visée dessinée au sol pour chaque attaque, super chargée en touchant.
**Ce qu'on en prend** : la preuve qu'**une vie par manche marche en vue de dessus** avec des compétences ; les **hautes herbes**
(cachent au-delà de 3 m) ; le gaz / la fin de manche qui force le contact (Sanctuaire).

### 2.7 Paladins (Hi-Rez) et Smite : la boutique en partie
Vérifié (wiki Paladins « Siege: Beyond », gamersdecide) : boutique en partie payée en crédits, **4 catégories** (défense, utilitaire, soin,
attaque / dégâts : noms divergents), **3 rangs par objet** ; un objet de défense **réduit la durée des contrôles** (« Resilience ») ; un
objet très cité **réduit les soins de la cible** (« Cauterize »). Smite : non regardé pendant l'étude (non vérifié).
**Ce qu'on en prend** : des **réponses achetables aux deux problèmes d'une vie par manche** — contrôles (« Talisman de ténacité ») et soins
(« Enduit amer ») — plutôt que 60 retouches de classes.

### 2.8 Battlerite (Stunlock) : le plus proche de notre combat
Vérifié (Wikipédia, Destructoid, mein-mmo) : arène vue de dessus, 2 contre 2 ou 3 contre 3, **premier à 3 manches**, une vie par manche ;
manche d'environ 2 min puis **mort subite** (un mur qui resserre l'arène) ; **orbe au centre** qui rend vie et énergie à l'équipe qui la
casse. Choix d'une « battlerite » (amélioration) entre les manches : d'après un aperçu d'accès anticipé, non vérifié aujourd'hui.
**Ce qu'on en prend** : la preuve qu'un **jeu à compétences, à esquive et à visée** tient la formule « une vie par manche » ; l'**orbe**
disputée (nos orbes d'ultime) ; la mort subite du Sanctuaire.

---

## 3. Nos modules les plus proches (captures 0.1.284 contre les références)

Captures : `C:\AI\benchmark_refs\tactique\eden_slash_0.1.284\` (`shot_m7`, Arènes 3v3 et Gantelet, 1600×900, copie propre de HEAD).

| Écran / système | Nous (observé) | Références | Écart pour le mode tactique |
|---|---|---|---|
| Début de manche | `m7_20` : trois héros côte à côte, aucune barrière, **aucun compte à rebours ni HUD visibles à la capture** | CS / Valorant : barrières, minuteur d'achat, score | à vérifier en jeu (effet de l'outil ou régression du HUD des Arènes) ; il faut une phase d'achat |
| Combat | `m7_21` : effets de sorts plein écran qui cachent les héros ; **rien ne distingue un allié d'un adversaire** sauf l'anneau du joueur ; textes d'état (« Renversé », « Saignement ») au-dessus des têtes | Valorant / Brawl Stars : contour de couleur d'équipe, plaques courtes | couleur de camp **fixe** (lagon / fraise) sur l'anneau et la plaque ; réglage d'atténuation des effets des autres (existe : `Settings`, rang 1 des idées) activé par défaut ici |
| Barres d'équipe | `TeamBars` (code) : PV de chaque héros sous le titre, tableau entre les manches | Valorant / OW : portraits en haut au centre, vivant / mort, ultime | bandeau du score 4 + 4 en haut au centre (croquis 1) |
| Joueur tombé | `m7_23` montre le menu pause : l'outil de capture est périmé (comme `shot_m1` avant BR4) | CS / Valorant : spectateur des alliés | réutiliser `RoyaleRecap` (récapitulatif + spectateur) |
| Pause | `m7_22` : « Compétences de la partie (4 / 12) », « Arme secondaire : aucune », « 5 % coup porté » | — | vocabulaire de la Survie et pourcentages dans le texte permanent (interdits par la vision) |
| Bilan | `m7_25` : « Victoire ! », 5 tuiles (dont 2 en %), Gagné / Gardé, « Nouvelle équipe adverse » | CS : tableau des 10 joueurs ; Valorant : frise des manches | tableau des 8 héros + frise des manches (croquis 4) |
| File et draft | `DuelQueue` (code) : recherche, match trouvé, draft 60 s, récapitulatif 10 s avec préchargement | Valorant / OW : choix des héros en équipe | à réutiliser pour le **choix des héros** 4 + 4 et le préchargement des 8 kits |
| Carte | `ProcMap.generate_arena` : cuvette ronde de 96 m, piliers ; `generate_royale` : lieux nommés avec murets (`_add_box_collider`) | cartes à couloirs, sites, hauteurs | format de carte faite à la main (§ 7.9) |
| Vue | caméra de dessus à 52°, 15 m (`CameraRig`) : on voit ~30 m autour de soi, à travers tout | CS / Valorant : vue à la première personne ; Brawl Stars : buissons | **brouillard d'équipe** et voile de vue (§ 7.7) |
| Repère, flèches, sons | Battle royale v2 : `RoyalePing`, `RoyaleEdge`, `HitArc`, `RoyaleAnnounce`, `RoyaleCues` (« Voir les sons »), `RoyaleMap` | Apex / Valorant : pings, radar | presque tout est réutilisable ; manque la **roue de ping** à plusieurs sens et les ordres aux alliés |

**Ce que nous faisons mieux que les références (à garder)** : vrais sorts à zones annoncées au sol (`Telegraph`) et esquive avec
invulnérabilité — un duel se gagne aussi à la lecture, pas seulement à la visée ; plafonds anti-mort-instantanée déjà en place ; IA de
combat qui lit les coups ; 60 classes de 5 familles ; mode scellé (personne n'achète la victoire hors de la partie).

**Incohérences relevées pendant l'étude** : `tests/shot_m7.gd` capture la pause au lieu du « joueur tombé » (outil périmé) ; aucune capture
du lobby n'est sortie de `shot_m7` (partie « lobby ») ; `tests/shot_queue.tscn` ne s'est pas terminé en 15 min sans écrire de capture ; HUD absent sur les captures de combat des Arènes (à vérifier en jeu).

---

## 4. Profondeur : ce qui fait tenir une partie

| Sujet | Références | Nous aujourd'hui | Recommandation |
|---|---|---|---|
| **Information** | murs opaques, sons, radar d'équipe, reconnaissance achetée | tout se voit | brouillard d'équipe, bruits, dernière position, 2 utilitaires d'information |
| **Économie** | primes de défaite progressives, éco / achat forcé / achat complet | aucune | barème § 7.3, plan d'achat d'équipe annoncé par les IA |
| **Objectif** | Charge / Spike : pose, minuteur, désamorçage, porteur | aucun (Siège : cœur à emporter) | § 7.2 |
| **Rôles** | 4 rôles (Valorant), 3 (OW), passifs de rôle | 5 familles, 7 rôles d'autochess dans `data/autochess_units.json` | 5 rôles tactiques et passifs génériques (§ 7.6) |
| **Utilitaires** | fumée, aveuglement, feu, reconnaissance, pièges | potions seulement | 10 utilitaires génériques + sorts de classe (§ 7.4) |
| **Durée d'un combat** | ~1 s (tir), 5-15 s (Battlerite, non vérifié) | Arènes : manches visées 30-90 s (85-104 s avant M7, `mode_rules.gd`) | duel 1 contre 1 de 7 à 10 s, jamais moins de 3,5 s depuis la pleine vie |
| **Tempo** | MR12 ~35-45 min (non vérifié) ; Wingman 10-25 min | Arènes : 2 manches gagnantes | Assaut 16-20 min (premier à 7) ; Éclair 8-10 min (premier à 4) |
| **Retournements** | primes de défaite, prolongation | — | primes, orbes d'ultime, prolongation à or fixe |
| **Lisibilité** | couleurs d'équipe, contour, plaque courte | effets plein écran, pas de couleur de camp | lagon / fraise partout, effets des autres atténués par défaut |
| **Solitude du joueur** | équipiers humains + vocal | alliés IA qui ne parlent pas | bulles d'intention, roue d'ordres, carte tactique après la mort |

---

## 5. Détails de confort à reprendre
1. **Rachat** de la manche précédente en une touche, **achat conseillé** (A à la manette) par classe et par or (Valorant / CS : non vérifié).
2. **Offrir** un objet à un allié qui manque d'or (CS : arme laissée tomber ; non vérifié) — les IA le demandent dans la colonne d'équipe.
3. **Point de sauvegarde** à la moitié du désamorçage (Valorant, vérifié).
4. **Bips de la Charge** qui accélèrent + minuteur en grand pour tous après la pose ; direction du son de pose sur toute la carte.
5. **Dernière position** d'un ennemi perdu de vue (fantôme « ? » qui s'efface en 4 s) sur l'écran et le radar.
6. **Récapitulatif de mort** de 3 lignes et **spectateur des alliés** (déjà faits pour le Battle royale : `RoyaleRecap`).
7. **Carte tactique** après la mort, avec **ordres aux alliés IA** (spécifique au solo) et **relais** d'un allié vivant en Facile / Normal.
8. **Voir les sons** activé par défaut dans ce mode (`RoyaleCues`) : en vue de dessus, le son directionnel se lit mal.
9. **Pause vraie** (solo) et **reprise** d'une partie entre deux manches (comme L'Échiquier).
10. **Bandeau de fin de manche non bloquant** (5 s) puis achat ; rien n'attend de clic (leçon de l'étude AUTOCHESS).
11. Noms des lieux (« callouts ») sur le radar et dans les annonces (« Ennemi aperçu · Halle »).
12. Option daltonisme : alliés ronds, ennemis en losange sur le radar et les plaques (pas seulement la couleur).

---

## 6. Tableau d'écarts (synthèse)

| Thème | Ils font mieux | On fait mieux | Il manque (lot) |
|---|---|---|---|
| Vue et information | murs opaques, sons, radar | — | brouillard, voile, bruits, dernière position (TAC-2) |
| Objectif | Charge, porteur, minuteur | annonces au sol des zones | Charge complète (TAC-3) |
| Économie | primes, éco, forcé, plan d'équipe | — | barème, inventaire de manche, écran d'achat (TAC-5) |
| Combat | temps pour tuer court et lisible | esquive, zones annoncées, lecture des coups | profil `assault`, règles de contrôle / soins / invisibilité (TAC-4) |
| Rôles | passifs de rôle, compositions | 60 classes, 5 familles | 5 rôles tactiques, kit de 4 sorts par classe (TAC-4) |
| IA | (humains) | IA de combat très forte | stratège d'équipe, perception honnête (TAC-6, TAC-9) |
| Cartes | couloirs, sites, hauteurs, callouts | décor d'Eden, navmesh | format de carte, 3 cartes (TAC-1, TAC-10) |
| HUD | score 4 + 4, radar, ultime, Charge | modules du BR v2 | bandeau du score, radar d'équipe, cases achetées (TAC-7) |
| Mort | spectateur, relais (CS, non vérifié) | récapitulatif du BR | récapitulatif, spectateur (TAC-8) ; carte tactique, ordres, relais (TAC-11) |
| Fin | tableau, frise des manches | bilan commun `ResultsPanel` | tableau des 8, frise, récompenses scellées (TAC-8) |

---

## 7. Spécification « version 2 » du mode

### 7.1 Choix du format

| Critère | **Charge (Assaut)** | Point à respawn (OW Contrôle / Escorte) | Point par manches (Sanctuaire) |
|---|---|---|---|
| Demande du joueur (« poser la bombe », attaque / défense, achat, une vie) | oui, mot pour mot | non (respawn) | une vie oui, achat non |
| Une vie par manche | oui | **non** | oui |
| Lisible vue de dessus | oui (2 sites, 1 porteur) | oui | oui |
| IA scriptée qui « joue bien » | décisions discrètes : quel site, quand poser, reprendre, sauver | mêlée continue, peu de décisions | une seule décision : tenir ou disputer |
| Profondeur rejouable | très haute (économie, info, asymétrie) | moyenne | moyenne |
| Réutilise l'existant | Arènes, BR v2, Siège (cœur à porter) | Arènes | Arènes, Siège (anneau) |
| Coût | le plus élevé | moyen | faible une fois l'Assaut fait |

**Principal : la Charge (« L'Assaut »)** — c'est la demande, et c'est le format où une IA scriptée brille le plus (un arbre de décisions
clair) et où « une vie » a le plus de sens. **Secondaire : « Le Sanctuaire »** (point central par manches) — il réutilise les mêmes cartes
(point P des plans), sert de **format court** et d'**apprentissage** (pas d'économie, pas d'asymétrie), et donne la variante
Overwatch / Battlerite sans respawn. L'escorte reste une idée P2 (« convoi par manches », une vie : non spécifié ici).

### 7.2 Règles chiffrées de départ (Assaut)
Toutes les valeurs dans un profil `ModeRules.ASSAULT` (« assault ») pour être réglées sans code (dev_edits, modificateurs).

| Règle | Valeur | D'où |
|---|---|---|
| Équipes | 4 contre 4 : toi + 3 alliés IA contre 4 IA ; une classe au plus une fois par équipe | demande ; OW / Valorant (non vérifié) |
| Partie | 12 manches au plus, **premier à 7** ; mi-temps après 6 (changement de côté, or remis à 800) | MR12 réduit (Wingman : premier à 9 / 16) |
| Prolongation (6-6) | blocs de 2 manches (une par côté), **or fixe 4 000**, il faut **2 manches d'écart** ; après 3 blocs, **manche décisive** (côté tiré au sort, annoncé) | Valorant (2 d'écart), CS (or fixe) |
| Format court « Éclair » | premier à 4 (7 manches au plus, mi-temps après 3, la 7e est décisive), or de départ 1 200 | Spike Rush / Swiftplay (non vérifié) |
| Choix des héros | 30 s avant la partie (écran de `DuelQueue` étendu), les IA complètent les rôles manquants | Valorant / OW (non vérifié) |
| Achat | **20 s** (25 s à la 1re manche de chaque moitié) ; barrières d'encre (couleur du camp) jusqu'à la fin | CS / Valorant |
| Manche | **1:40** ; la Défense gagne au temps si rien n'est posé | Valorant (100 s) |
| Charge | portée par un attaquant (choisi au départ : l'Ouvreur ou le joueur s'il la prend), lâchée à sa mort, ramassée en passant ; un attaquant la voit toujours, la Défense seulement si elle est vue | R6 (porteur), CS |
| Pose | **4 s** immobile sur un site ; annulée par un déplacement, une attaque, un sort, une esquive ou un contrôle subi ; les dégâts seuls ne l'annulent pas | Valorant |
| Après la pose | **40 s** jusqu'à l'explosion (le minuteur de manche disparaît) ; bips qui accélèrent ; position connue de tous | CS (non vérifié), Valorant 45 s |
| Désamorçage | **7 s**, sauvegarde à **3,5 s** ; **4 s** avec les Pinces (sauvegarde à 2 s) ; annulé comme la pose | Valorant, CS (kit) |
| Fin de manche | toute une équipe à terre (si la Charge est posée, la manche continue jusqu'à l'explosion ou au désamorçage), explosion, désamorçage, temps | CS / Valorant |
| Vie | une vie, **aucune réanimation**, PV pleins à chaque manche, aucun tir ami | demande |
| Entre deux manches | bandeau de 5 s, puis achat | étude AUTOCHESS (rien de bloquant) |
| Durée visée | manche jouée 55-80 s (médiane) ; partie 16-20 min ; Éclair 8-10 min | à mesurer (TAC-9) |

**Le Sanctuaire (secondaire)** : mêmes cartes et équipes ; pas d'achat (paquetage fixe : arme +1, gilet, 1 brume, 1 fiole de soin,
sorts 2 et 3 offerts), **premier à 4 manches** ; le point P s'ouvre à 0:20 ; une équipe seule dessus le prend en **8 s** (plus vite à plusieurs,
×1,3 par héros en plus, au plus ×1,6) ; le prendre ou éliminer l'autre équipe gagne la manche ; à 1:20, **mort subite** : un anneau d'encre
se referme vers le point en 20 s (anneau du Siège, `SiegeDirector`) ; prolongation tant qu'un héros de l'équipe menée est sur le point.

### 7.3 Économie (or de manche)
| Gain | Valeur | Remarque |
|---|---|---|
| Départ de chaque moitié | 800 | prolongation : 4 000 fixes à chaque manche |
| Plafond | 7 000 | au-delà, l'or est perdu (affiché en infobulle) |
| Victoire de manche | 2 400 | pour toute l'équipe |
| Défaite | 1 500 → 1 900 → 2 300 → 2 700 | série de défaites ; **une victoire fait redescendre la série d'un cran** au lieu de la remettre à zéro (anti-effet boule de neige ; pratique de CS : non vérifié) |
| Élimination | 200 | aide (dégâts ≥ 30 % des PV de la cible) : 50 |
| Pose | +300 à chaque attaquant | même si la manche est perdue |
| Désamorçage | +200 au désamorceur | — |
| Attaquant vivant quand le temps s'écoule sans pose | **pas de prime de défaite** | contre l'attente stérile (CS, non vérifié) |
| Ce qu'on garde | arme, reste de l'armure, sorts achetés, utilitaires non lancés, si l'on **survit** | CS / Valorant |

Repères (à mesurer) : un **achat complet** coûte ≈ 3 400 (arme de maître 1 500, cuirasse 1 000, sorts 2 et 3 ≈ 550, 2 utilitaires ≈ 350) ;
une équipe qui gagne rachète tout ; une équipe qui perd deux fois de suite peut tout racheter à la 3e ; la 1re manche (800) offre un vrai
choix (sort 2 + gilet + un éclat, ou arme affûtée seule).

### 7.4 Objets achetables (31)
Prix en or ; limites : **2 cases d'utilitaires, 4 charges au total, 2 au plus du même** ; 1 fiole ; 1 outil. Effets génériques (aucun par
classe), télégraphiés au sol comme les sorts (`Telegraph`), jamais masqués par les réglages d'effets.

| # | Catégorie | Objet | Prix | Effet (valeurs de départ) |
|---|---|---|---|---|
| 1-5 | Sorts | Sort 2 et sort 3 de la classe | 200-350 | prix selon la nature du sort : mobilité 200, dégâts 250, contrôle 300, soin / bouclier 300, invisibilité 350 (`data/assault_kits.json`) ; gardé tant qu'on survit |
| 6 | Arme | Arme affûtée | 600 | dégâts de l'arme et des sorts ×1,15 |
| 7 | Arme | Arme de maître | 1 500 | ×1,30 et choix de la variante d'arme (2 variantes existent : `WeaponAttacks`) |
| 8 | Arme | Arme d'appoint | 400 | seconde arme d'un autre type (système N2, `Player.swap_weapon`) |
| 9 | Arme | Enduit amer | 300 | 3 coups : soins reçus par la cible −40 % pendant 4 s (réponse aux soigneurs, Paladins « Cauterize ») |
| 10 | Armure | Gilet | 400 | bouclier = 25 % des PV max (absorbe d'abord, ne se soigne pas) |
| 11 | Armure | Cuirasse | 1 000 | bouclier = 50 % des PV max |
| 12 | Armure | Réparer | au prorata | remet le bouclier gardé à plein |
| 13 | Utilitaire | Fiole de brume | 200 | nuage de 5 m, 10 s : coupe la vue (pas les coups) ; l'IA ne voit plus au travers |
| 14 | Utilitaire | Éclat aveuglant | 150 | éclate après 0,6 s ; tout héros qui le voit à moins de 12 m est **ébloui** 1,2 s (voile blanc ; l'IA perd sa cible) ; se détourner (dos à l'éclat) l'évite |
| 15 | Utilitaire | Pot de feu | 300 | zone de 4 m, 6 s, 6 % des PV max par seconde ; interdit un passage ou chasse d'un coin |
| 16 | Utilitaire | Bombe d'éclats | 300 | 0,8 s d'annonce, 5 m, 25 % des PV max (le bouclier encaisse d'abord) |
| 17 | Utilitaire | Œil de chouette | 250 | lancé, révèle les ennemis à 12 m pendant 3 s, même derrière un mur |
| 18 | Utilitaire | Clochette d'alarme | 150 | posée, 60 s : révèle le premier ennemi qui passe à 5 m (son + radar) |
| 19 | Utilitaire | Piège à ressort | 250 | posé, invisible à plus de 4 m : immobilise 0,8 s et révèle 2 s |
| 20 | Utilitaire | Barricade de glace | 300 | mur de 4 × 2 m, 12 s, 400 PV : bloque passage, vue et coups |
| 21 | Utilitaire | Leurre | 200 | double qui court 4 s tout droit en faisant du bruit (trompe joueurs et IA) |
| 22 | Utilitaire | Poudre de silence | 200 | 6 s : tes pas ne font aucun bruit même en courant |
| 23 | Fiole | Fiole de soin | 200 | rend 30 % des PV en 2 s ; annulée par un coup de plus de 5 % |
| 24 | Fiole | Fiole de hâte | 150 | +25 % de vitesse 6 s |
| 25 | Fiole | Fiole de garde | 250 | dégâts subis −25 % pendant 4 s |
| 26 | Fiole | Fiole de clarté | 200 | retire un contrôle en cours et rend insensible 2 s |
| 27 | Outil | Pinces d'acier (Défense) | 300 | désamorçage 4 s au lieu de 7 |
| 28 | Outil | Gants de sapeur (Attaque) | 300 | pose 3 s au lieu de 4 |
| 29 | Outil | Talisman de ténacité | 350 | durée des contrôles subis −30 % (Paladins « Resilience ») |
| 30 | Outil | Bottes feutrées | 300 | marche silencieuse à 75 % de la vitesse au lieu de 55 % |
| 31 | — | **Ultime** | ne s'achète pas | 7 points : élimination, mort, pose, désamorçage, **orbe d'ultime** (2 par carte, en zones disputées, ramassage 2 s immobile, réapparaît chaque manche) |

### 7.5 Le kit tactique : 4 sorts par classe, sans retouche une à une
Mode scellé : ni talents, ni certificats, ni équipement du compte (`Modes.SEALED` += « assault ») ; chaque héros joue une **fiche
tactique** normalisée (niveau 50, arme de la classe seule, comme le Duel à l'arme `duel_a`, PV et puissance égalisés par rôle).
Les 4 cases viennent d'un **outil** (`tools/assault_kits.py` → `data/assault_kits.json`, sur le modèle de `tools/autochess_units.py`) qui
applique des règles générales aux 14 à 20 sorts de chaque classe (`data/classes.json`), puis une table d'exceptions courte :
- **Case 1, signature (gratuite)** : le sort de dégâts de plus courte recharge (cône, zone, tourbillon, tir) ;
- **Case 2 (achetée)** : la **mobilité** si la classe en a une (45 sorts `dash` / `blink` dans les données), sinon un second sort de dégâts ;
- **Case 3 (achetée)** : l'**utilité** de la classe : contrôle, soin, bouclier, renfort ou invisibilité (ordre de préférence selon le rôle) ;
- **Case 4, ultime** : le sort au plus gros multiplicateur ou à la plus longue recharge, zone +30 %, une utilisation par charge de 7 points ;
- **pas d'enchaînements** (une action par case : lisibilité et contre-jeu) ; recharges des sorts ×1,0 (la manche est courte).

### 7.6 Rééquilibrage pour une vie par manche (règles génériques)
**Profil `assault` de `ModeRules`** (valeurs de départ, à mesurer par la sonde de TAC-4) :

| Clé | Valeur | Pourquoi |
|---|---|---|
| `dmg_scale` | 0,13 | Battle royale 0,055 → duels de 17-31 s (BR1) ; on vise **7 à 10 s** pour un 1 contre 1 de même rôle avec esquives |
| `basic_mult` | 0,8 | l'auto-attaque est « l'arme » du mode : un peu plus de poids qu'en duel (0,7) |
| `heal_mult` | 0,30 | + **plafond de soins reçus par manche : 60 % des PV max** (la jauge montre ce qui reste) |
| `hit_cap` / `burst_cap` / fenêtre | 0,25 / 0,55 sur 2 s / reste ×0,2 | **jamais mort en moins de ~3,5 s depuis la pleine vie**, même focalisé : le temps de réagir (esquive, fiole, repli) |
| acharnement | aucun (`pressure_start` 100 000) | le minuteur de manche et la Charge font pression |
| `pct_weight`, plafonds | 1,0 ; plafonds du duel à l'arme | pas d'équipement du compte |
| chute de portée | coups à distance −25 % au-delà de 16 m | les longues allées ne deviennent pas des stands de tir |

**Contrôles** (60+ sorts à renversement, 45 à ralentissement, terreur, sommeil, gel… dans `data/classes.json`) :
- durée **×0,5**, puis plafond : renversé, gelé, endormi **≤ 1,0 s** ; terreur, immobilisé **≤ 1,2 s** ; désarmé ≤ 1,5 s ; ralenti ≤ 2 s et 30 % au plus ;
- **ténacité commune** : après tout contrôle dur, insensible à **tous** les contrôles durs 2,5 s (aujourd'hui : par type, `Combatant.CC_TYPES`,
  3 s, ce qui permet renversé → terreur → gel à la suite) ;
- un contrôle **annule la pose et le désamorçage** : c'est leur rôle tactique.
**Invisibilité** (19 renforts `invisible`) : 2,5 s au plus ; se brise en attaquant ou en étant touché ; scintille à moins de 5 m ; impossible
en portant la Charge, en posant ou en désamorçant.
**Boucliers et réductions** : dégâts subis jamais sous ×0,6 tous effets cumulés (`barrier` ×0,6 → ×0,8, `titan` ×0,5 → ×0,7 dans ce mode).
**Mobilité** : les sauts et téléportations ne traversent aucun mur ; l'esquive est inchangée mais annule pose et désamorçage.
**Murs** : projectiles, rayons, cônes et tourbillons s'arrêtent aux murs pleins et aux murets ; une zone au sol exige la ligne de vue vers le
point visé ; depuis une hauteur de 2 m ou plus, on voit et on tire par-dessus les murets.

**5 rôles tactiques** (tirés des rôles de `data/autochess_units.json`, 60 classes) et passifs de rôle :

| Rôle | Classes | Passif (départ) | Couleur |
|---|---|---|---|
| **Rempart** (tank) | 9 | +20 % PV, contrôles subis −20 % | soleil |
| **Ouvreur** (assassin, combattant) | 18 | +1 charge d'esquive ; « prise à revers » : +20 % de dégâts sur une cible qui ne l'a pas vu depuis 3 s | mandarine |
| **Tireur** | 12 | chute de portée à 20 m au lieu de 16 ; une cible qu'il touche reste révélée 1,5 s à son équipe | pomme |
| **Contrôleur** (mage) | 9 | utilitaires −20 % de prix ; ses zones durent +15 % | améthyste |
| **Soutien** (soigneur, soutien) | 12 | voit les PV de son équipe ; ses soins ne comptent qu'à moitié dans le plafond de soins reçus | lagon |

Les IA composent leur équipe avec un Rempart ou un Ouvreur devant, un Tireur ou un Contrôleur, un Soutien, et un rôle libre ;
le joueur choisit librement, les alliés complètent. **Cibles de mesure** (TAC-9) : en 4 contre 4 IA contre IA, aucun rôle hors de
45-55 % de victoires ; aucune classe hors de 40-60 % dans son rôle ; Attaque 45-55 % par carte ; 1 contre 1 médian 7-10 s.

### 7.7 Vue, brouillard et bruits (le cœur du mode)
- **Vue d'équipe** : un ennemi est montré si un allié au moins le voit : à moins de **22 m**, ligne de vue non coupée par un mur plein, une
  barricade ou une brume ; dans les hautes herbes, seulement à moins de 3 m. Sinon **son modèle et sa plaque sont cachés** (pas grisés).
- **Voile** : ce que **ton** héros ne voit pas est assombri (encre-500 à 35 % + trame, bible § 3), calculé par un polygone de visibilité 2D
  (segments des murs de la carte) ; les ennemis vus par un allié apparaissent quand même, contour fraise « vu par Élouan ».
- **Dernière position** : 4 s, fantôme pointillé « ? » à l'écran et sur le radar.
- **Bruits** (émis par le jeu, lus par le joueur et par l'IA) : course 14 m ; **marche** (Maj / clic du stick : 55 % de la vitesse) silencieuse ;
  esquive 18 m ; sort lancé 24 m ; pose et désamorçage : toute la carte, avec la direction. « Voir les sons » (`RoyaleCues`) **activé par défaut**.
- **L'IA ne triche pas** : elle ne connaît que ce que son équipe voit et entend (carte de croyance, § 7.10). La difficulté joue sur la
  réaction, la discipline et la coordination, jamais sur la vue.

### 7.8 Écrans, HUD et retours (croquis `tactique_maquettes/`)
- **HUD de manche** (`v2_hud_manche.svg`) : en haut au centre, **bandeau du score** (4 + 4 portraits, ✕ tramé = à terre, points soleil =
  ultime), minuteur, « Manche 8 · Attaque », état de la Charge ; en haut à droite, **radar** (sites, alliés et leur cône de vue, ennemis vus,
  derniers vus, repères, noms des lieux) et fil des éliminations en pastilles ; en bas au centre, **carte de vie** (bouclier lagon en crans
  au-dessus de la vie fraise), **4 cases de sorts** (gratuit · acheté en recharge · non acheté tramé avec cadenas et prix · ultime à 7 points),
  esquive, **utilitaires** et fiole ; en bas à gauche, **or** et « prochaine manche : +1 500 au moins » ; invites contextuelles (« [F] Poser la
  charge · 4 s ») ; annonces une à la fois (`RoyaleAnnounce`) : « 2 contre 4 ! », « Charge posée en B ! », « Dernier debout ».
- **Achat** (`v2_achat.svg`) : 20 s, le monde reste visible ; onglets Sorts / Arme / Armure / Utilitaires / Fioles (LB / RB) ; cartes de sort
  (gratuit, gardé, à acheter avec la touche A, ultime à points) ; paquetage ; **Achat conseillé** (primaire), **Racheter [R]**, Tout revendre,
  Offrir… ; colonne de l'**équipe** : plan commun (« achat complet », « on économise », « on force »), or de chacun, « il lui manque 850 »,
  « Offrir la cuirasse à Daphné ».
- **Mort** (`v2_mort_ordres.svg`) : récapitulatif (qui, sort, dans le dos, PV restants, dégâts) ; spectateur d'un allié (LB / RB) ; **carte
  tactique** [Tab] avec **roue d'ordres** sur un allié (Va en A / B / au repère, Tiens, Reprends, Recule et garde ton équipement, Économisez) ;
  **Prendre le relais** (Facile, Normal) ; minuteur de la Charge en grand.
- **Fin** (`v2_bilan.svg`) : bandeau de fin de manche (5 s, or gagné et « Détail ») ; bilan : « Victoire ! », 7 contre 4, **frise des manches**
  (couleur = gagnant, symbole = élimination / charge / désamorçage / temps, mi-temps), **tableau des 8** (éliminations, morts, aides, dégâts,
  poses / désamorçages, MVP ★), récompenses scellées, **Rejouer**, Revoir les manches (P2), Menu principal.
- **Retours** (bible § 7-8) : coup donné = petit éclat ; coup reçu = arc fraise (`HitArc`) ; élimination = « K.O. ! » 600 ms ; **dernier en vie**
  = « À toi de jouer ! » + musique qui baisse ; Charge posée = bandeau fraise et bips ; désamorçage réussi à moins d'1 s = « Ouf ! » ; victoire de
  la partie = traits de vitesse, confettis des 5 bonbons. Couleurs : ton équipe **lagon**, l'autre **fraise**, la Charge et les sites **soleil**,
  sanctuaire **améthyste** ; jamais de texte blanc sans contour ; aucun pourcentage dans le texte permanent.
- **Ping et ordres** : roue (molette / R3 maintenus) : Ennemi ici, J'y vais, Tiens, Recule, Besoin d'aide, Charge ; ping rapide contextuel au clic
  molette (`RoyalePing` étendu à l'équipe) ; les alliés IA répondent par une bulle (« Je couvre B ! », « Pas pour l'instant : 1 contre 3 »).
- **Premiers pas** : 5 fiches `Tutorial.CARDS` (≤ 125 signes) : Achat, Charge, Vue et bruits, Une seule vie, Rôles ; **première partie guidée**
  sur le Bourg en Facile (acheter, poser, défendre / désamorcer) ; astuce de chargement par carte.

### 7.9 Les trois cartes (plans masse `tactique_maquettes/plan_*.svg`, temps à 6,5 m/s, vitesse `Player.BASE_SPEED`)
Règle de conception : la Défense arrive sur un site **6 à 9 s avant** l'Attaque ; le milieu est disputé à **1-2 s près** ; vues dégagées de
**24 m** au plus (les tirs portent à 13-20 m) ; chaque site a **3 entrées** dont une par l'arrière ; une hauteur par carte au moins ; un couvert
(muret) tous les 8-10 m sur les routes. Murs pleins = maisons et ruines d'Eden posées sur `_add_box_collider` ; murets = `ub201` (3,6 × 2,2 m
de collision, déjà utilisés par le Battle royale) ; hauteurs ≤ 4 m par rampes de 8 m.

| Carte | Taille | Idée | Att. → site | Déf. → site | Rotation Déf. A ↔ B | Particularités |
|---|---|---|---|---|---|---|
| **Le Bourg aux lanternes** (apprentissage) | 84 × 100 m | deux sites, une place, des maisons ; tous les rôles y ont leur coin | 11,3-14,0 s | 4,5 s | 8,1 s (allée du beffroi) | terrasse +3 m sur A, balcon +2,5 m vers B, jardin et saules en hautes herbes, passage sous la halle |
| **Le Pont des brumes** | 90 × 96 m | une rivière, 3 passages : passerelle étroite, grand pont à découvert, gué lent (×0,6) et bruyant dans la brume (vue 6 m) | 10,3-13,2 s | 4,5-5,0 s | 8,3 s | site A sur une terrasse +4 m qui voit les ponts ; rocher de guet +3 m pour l'Attaque |
| **Le Temple de cristal** | 80 × 88 m | intérieur serré, couloirs de 4 m, vues de 16 m au plus : le terrain des Ouvreurs et des Remparts | 10,1-12,1 s | 5,0-5,8 s | 10,4 s | crypte B en contrebas (−3 m) avec une **chute à sens unique** depuis la nef ; piliers autour du sanctuaire |

Chaque carte porte aussi ses **données d'IA** : positions nommées (angle à tenir + direction), couverts, points de lancer d'utilitaires
(« brume sur l'entrée de la ruelle depuis le jardin »), chemins d'exécution par site, et le point P du Sanctuaire. Format :
`data/assault_maps/<id>.json` (murs, murets, hauteurs, herbes, eau, sites, départs, lieux nommés, positions, lancers), lu par
`ProcMap.generate_assault(id)` (sol presque plat + rampes, décor d'Eden, navmesh, mini-carte) ; aperçu `tools/assault_map_shots.tscn`.

### 7.10 IA d'équipe (scriptée, sans cerveau neuronal)
**Trois couches** (le combat existant reste en bas) :
1. **Stratège d'équipe** (`AssaultBrain`, un par équipe, 2 fois par seconde) :
   - **économie** : achat complet si l'or moyen de l'équipe ≥ 3 400 ; **forcé** à la dernière manche d'une moitié, à la balle de match ou si
     l'adversaire est en éco ; sinon **éco** (sort 2 et un utilitaire au plus) ; le plus riche **offre** au plus pauvre ; annoncé à l'achat ;
   - **plan d'Attaque** : « par défaut » (prendre le milieu et de l'information, décider à 0:50), **exécution** sur un site (brume + éclat
     synchronisés puis entrée à deux), **séparée** (deux entrées d'un même site), **ruée** (tôt, à pleine vitesse), **feinte** (bruit sur A, pose en B ;
     Expert) ; choix pondéré par ce qui a marché et par les infos de la manche ; choix du **porteur** (jamais l'Ouvreur qui ouvre) ;
   - **plan de Défense** : 2-1-1, 1-2-1 ou empilement selon l'historique des sites attaqués ; **rotation** sur information (2 vus à B = 1 tourne) ;
     **reprise** après la pose (on se regroupe, utilitaires, entrée ensemble), **désamorçage** couvert (brume d'abord) ; **sauvegarde** quand c'est
     perdu (1 contre 3 avec moins de 15 s : on garde son équipement).
2. **Agent** (`AssaultAgent`, par héros IA, 5 fois par seconde) : va à sa position, **tient un angle** (direction de la carte), **échange**
   (suit l'ouvreur à 4-6 m pour venger une mort), lance ses utilitaires aux points prévus, marche en silence près des sites, chasse un bruit,
   se replie à faibles PV, pose / désamorce quand c'est sûr, ramasse la Charge.
3. **Combat** : `ClassRival` tel quel (esquive, lecture des coups, focus du plus faible, soutien des alliés) dans un **cadre** donné par
   l'agent (ne pas poursuivre au-delà de sa zone, ne pas quitter un couvert sans raison, priorité au porteur et au désamorceur).
**Perception honnête** : une **carte de croyance** par équipe (cases de 4 m, présence probable d'ennemis) nourrie par la vue, les bruits, les
morts et le temps écoulé (la probabilité s'étale le long du navmesh à la vitesse d'un héros). L'IA ne lit jamais la position réelle d'un ennemi
qu'elle ne voit pas.
**Difficultés** (sur `ClassRival.DIFF`) : **Facile** (réaction lente, peu d'utilitaires, rue souvent, ne tourne pas), **Normal**, **Difficile**
(exécutions coordonnées, échanges, rotations sur info), **Expert** (utilitaires parfaits, feintes, adapte sa défense aux habitudes du joueur
après 3 manches, « jeu du temps » en Défense). Équipes mixtes possibles (alliés plus faibles que les adversaires, ou l'inverse).
**Lisibilité** : bulles d'intention des alliés (« Je tiens la ruelle »), pings des alliés, ordres du joueur (§ 7.8) avec refus motivé.
**Banc de mesure** (TAC-9) : `tools/assault_games.tscn` (IA contre IA, une ligne JSON par manche) + `tools/assault_report.py` : victoires
d'Attaque par carte et par site, durée des manches, part gagnée par pose / élimination / temps, morts par rôle, or moyen, Expert contre
Difficile ≥ 70 %. Tout réglage d'IA ou de règle se mesure au banc avant d'être gardé (règle de l'Échiquier).

### 7.11 Activité, récompenses, mode scellé
- Rangée **Affrontements** : « L'Assaut » (`Activities.LIST`, image, page `Lobby._menu_assault` : format Assaut / Éclair / Sanctuaire, carte,
  difficulté des deux équipes, ta classe, Reprendre) ; `QuestPool.ACTS`, `ResourceHelp`, `gives` = apparences, titres.
- **Récompenses scellées** (comme l'Échiquier et le Survivant) : coffre d'apparence à la victoire (rare / épique / légendaire selon la
  difficulté adverse), plafonné par jour ; titres (« Démineur » : 10 désamorçages, « Dernier rempart » : gagner un 1 contre 3, « Sans une perte » :
  7 à 0) ; `Quests.end_run("assault")` ; aucune maîtrise, aucun insigne, aucun équipement.
- Ouverture : dès le départ (mode à part, avec sa partie guidée) — voir question Q3.

### 7.12 Performances
8 héros, cartes de 80-90 m sans herbe dense ni objets cassables (moins lourdes qu'une carte de Survie de 512 m) ; vue : 16 paires de
rayons 10 fois par seconde (~160 rayons/s, négligeable) ; voile : polygone de visibilité 2D sur ~300 segments (< 0,3 ms par image, à mesurer) ;
stratèges 2 Hz, agents 5 Hz, décalés d'une image ; effets de sorts des autres atténués par défaut ; préchargement des 8 kits pendant le choix
des héros (comme `DuelQueue`). Cible : 60 images/s en 1080p sur un PC moyen, mesurée par `tools/perf_ui.tscn` (`--only=assault`).

---

## 8. Backlog priorisé

### P0 : sans ça, le mode fait « prototype »
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 1 | Socle du mode : état, profil `assault`, phases (choix, achat, manche, fin, mi-temps, prolongation), lancement direct, mode scellé | L | `core/assault.gd`, `core/assault_director.gd` (nouveaux), `core/modes.gd`, `core/mode_rules.gd`, `core/world.gd` |
| 2 | Murs qui arrêtent coups et vue ; brouillard d'équipe ; voile ; bruits | L | `combat/hero_bolt.gd`, `combat/projectile.gd`, `player/player.gd` (cônes, zones), `ai/class_rival.gd`, `world/assault_vision.gd` (nouveau), `ui/royale_cues.gd` |
| 3 | Carte n° 1 (Bourg) au format de carte | L | `data/assault_maps/bourg.json`, `world/proc_map.gd` (`generate_assault`) |
| 4 | Charge : porteur, pose, minuteur, bips, désamorçage, interruptions | M | `core/assault_charge.gd` (nouveau), `combat/sfx.gd` |
| 5 | Rééquilibrage : kits de 4 sorts, règles de contrôle / invisibilité / soins / boucliers, rôles et passifs, fiche normalisée ; sonde 1 contre 1 | L | `tools/assault_kits.py`, `data/assault_kits.json`, `combat/combatant.gd` (ténacité commune selon le mode), `combat/pvp_caps.gd`, `tools/assault_duel_probe.tscn` |
| 6 | Économie et achat : barème, inventaire de manche, objets 6 à 31, écran d'achat | L | `core/assault_economy.gd`, `core/assault_items.gd`, `ui/assault_shop.gd` (nouveaux), `core/potions.gd` |
| 7 | IA d'équipe v1 : stratège + agent (défaut, exécution, 2-1-1, reprise, désamorçage, éco simple), perception honnête | L | `ai/assault_brain.gd`, `ai/assault_agent.gd` (nouveaux), `ai/class_rival.gd` (cadre de mission) |
| 8 | HUD du mode : bandeau du score, radar d'équipe, carte de vie + bouclier, cases achetées / ultime, utilitaires, invites, annonces | M | `ui/assault_hud.gd` (nouveau), `ui/hud_v2.gd`, `ui/royale_announce.gd`, `ui/hit_arc.gd`, `ui/minimap.gd` |
| 9 | Mort et spectateur (récapitulatif, alliés, LB / RB) | S | `ui/royale_recap.gd` généralisé |
| 10 | Fin de manche et bilan (frise, tableau des 8), activité, récompenses scellées | M | `ui/assault_results.gd`, `ui/results_panel.gd`, `core/assault_rewards.gd`, `ui/activities.gd`, `ui/lobby.gd`, `core/quest_pool.gd`, `tests/test_nav_screens` |

### P1 : ce qui fait la qualité
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 11 | Cartes 2 et 3 (Pont, Temple) avec données d'IA | L | `data/assault_maps/*.json` |
| 12 | IA v2 : utilitaires coordonnés, rotations sur info, feintes, sauvegarde, 4 difficultés ; banc de mesure et calibrage | L | `ai/assault_*.gd`, `tools/assault_games.tscn`, `tools/assault_report.py` |
| 13 | Carte tactique, roue d'ordres, relais (Facile / Normal) | M | `ui/assault_map.gd` (sur `RoyaleMap`), `ai/assault_brain.gd` |
| 14 | Achat conseillé, rachat, offrir, plan d'équipe annoncé | S | `ui/assault_shop.gd`, `ai/assault_brain.gd` |
| 15 | Format Sanctuaire + format Éclair | M | `core/assault.gd`, `core/assault_director.gd` |
| 16 | Premiers pas : 5 fiches, partie guidée, astuces de chargement | M | `core/tutorial.gd`, `ui/assault_hud.gd` |
| 17 | Moments et sons (bips, « À toi de jouer ! », « Ouf ! », victoire) ; vibration | M | `combat/sfx.gd`, `core/ui_feel.gd`, `ui/assault_hud.gd` |
| 18 | Pause et reprise entre deux manches ; réglages du mode (effets des autres, voir les sons, noms au-dessus) | S | `core/assault.gd`, `core/settings.gd` |

### P2 : finitions et confort
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| 19 | Revoir les manches (positions des 8 héros à 10 Hz, lecture sur la carte tactique) | M | `core/assault_replay.gd` |
| 20 | Parcours d'utilitaires (zone d'entraînement : lancers de chaque carte) | S | `core/training.gd` |
| 21 | Statistiques de carrière du mode (Carnet), échelle locale contre l'IA | S | `ui/carnet_pages.gd`, `core/achievements.gd` |
| 22 | Règle du jour (modificateur doux), graine du jour | S | `core/modifiers.gd`, `core/challenge.gd` |
| 23 | Apparences de la Charge et des barrières (récompenses du mode) | S | `core/assault_rewards.gd` |
| 24 | Convoi par manches (escorte sans respawn), à étudier | L | — |

---

## 9. Plan de lots d'implémentation (estimation honnête)

| Lot | Contenu | Dépend de | Taille |
|---|---|---|---|
| **TAC-0** | socle du mode (P0-1) + test `test_tac0` (partie IA contre IA en accéléré, sans carte faite : arène) | — | L |
| **TAC-1** | format de carte + Bourg (P0-3) + aperçu | TAC-0 | L |
| **TAC-2** | murs, vue, brouillard, voile, bruits (P0-2) | TAC-1 | L (risque n° 1) |
| **TAC-3** | Charge (P0-4) | TAC-1 | M |
| **TAC-4** | kits et rééquilibrage + sonde (P0-5) | TAC-0 | L |
| **TAC-5** | économie, objets, écran d'achat (P0-6) | TAC-4 | L |
| **TAC-6** | IA d'équipe v1 (P0-7) | TAC-2, TAC-3, TAC-5 | L (risque n° 2) |
| **TAC-7** | HUD du mode (P0-8) | TAC-2, TAC-3, TAC-5 | M |
| **TAC-8** | mort, spectateur, bilan, activité, récompenses (P0-9, P0-10) | TAC-7 | M |
| **TAC-9** | IA v2, difficultés, banc et calibrage (P1-12, P1-14) | TAC-6 | L |
| **TAC-10** | cartes 2 et 3 (P1-11) | TAC-1, TAC-9 | L |
| **TAC-11** | ordres, carte tactique, relais (P1-13) | TAC-6, TAC-8 | M |
| **TAC-12** | Sanctuaire et Éclair (P1-15) | TAC-6 | M |
| **TAC-13** | premiers pas, moments et sons, pause / reprise (P1-16 à 18) | TAC-8 | M |
| **TAC-14** | P2 au choix, perfs, captures regardées, revue DA | tout | M |

**Taille réelle** : ≈ 9 lots L (3-5 j) et 6 lots M (1-2 j) → **40 à 55 jours d'agent**. À une équipe : 8 à 11 semaines ; à deux équipes en
parallèle (combat / IA d'un côté, interface / cartes de l'autre) : 5 à 6 semaines. **Premier jalon jouable** (TAC-0 à TAC-4 + IA v1 réduite,
une carte, sans achat : paquetage fixe) : ≈ 3 semaines. Les deux risques : **TAC-2** (le moteur n'a jamais arrêté un coup sur un mur ni
caché un ennemi) et **TAC-6 / TAC-9** (faire jouer une équipe d'IA « très bien » sans tricher). Ce mode est plus gros que le Battle royale
(qui réutilisait la carte et les règles de la Survie) et proche de L'Échiquier en ampleur. Chaque lot : bible v2, `UiTheme` / `UiFeel`, tests,
captures regardées, `test_texts_fr`, `test_nav_screens`.

---

## 10. Questions ouvertes (recommandation par défaut)

| # | Question | Recommandation par défaut | Pourquoi |
|---|---|---|---|
| Q1 | Nom du mode et de l'objet : « L'Assaut » et « la Charge » ? | **Oui** ; secondaire « Le Sanctuaire » | mots du jeu, pas de « bombe » ni de « round » à l'écran |
| Q2 | Format principal Charge (bombe) plutôt qu'objectifs Overwatch ? | **Charge** ; Sanctuaire en secondaire ; pas d'escorte à respawn | une vie par manche, IA plus forte, demande du joueur (§ 7.1) |
| Q3 | Ouverture de l'activité | **Dès le départ** (mode scellé, partie guidée) ; mise en avant après la 1re Arène | comme le Survivant et l'Échiquier ; rien du compte n'y compte |
| Q4 | Le joueur choisit-il n'importe quelle classe, ou seulement ses classes débloquées ? | **Classes débloquées** (règle des modes scellés : classes et apparences débloquées permises) ; en Éclair, toutes | cohérence avec H2 |
| Q5 | Relais d'un allié après la mort ? | **Oui en Facile / Normal**, non en Difficile / Expert, réglable | confort solo ; ne fausse pas le défi des hauts niveaux |
| Q6 | Durée de partie : premier à 7 ou à 9 (Wingman) ? | **Premier à 7** (16-20 min) + Éclair premier à 4 | un soir de jeu ; 9 serait 25 min contre des IA |
| Q7 | Voir les sons activé par défaut dans ce mode ? | **Oui** | en vue de dessus le son directionnel se lit mal ; l'IA « entend » de toute façon |
| Q8 | Réanimation (une classe de Soutien qui relève) ? | **Non** en v1 | une vie par manche est la règle ; trop de cas pour l'IA |
| Q9 | Tir ami ? | **Non** | sorts à zones larges : le tir ami punirait surtout les IA alliées et le joueur qui joue avec elles |
| Q10 | Contrôles très réduits (×0,5 et plafonds) : trop sévère pour certaines classes ? | **Garder la règle générique**, mesurer par rôle (TAC-4), corriger par l'exception de kit plutôt que par la règle | 60 classes : une règle, des mesures, peu d'exceptions |

---

## 11. Ce que cette étude n'a pas pu confirmer
Durées exactes de CS2 (bombe, désamorçage, achat) et gains de victoire / prime de pose (sources contradictoires) ; plafond de crédits de
Valorant ; rôles et modes courts de Valorant ; file par rôle et passifs d'Overwatch 2 ; durées de préparation et du compteur de Rainbow Six
(30 ou 45 s selon les sources) ; buissons et départages actuels de Brawl Stars ; noms actuels des objets de Paladins ; règles actuelles des
« battlerites ». Aucune image de référence n'a été regardée (téléchargement non autorisé dans cette passe). Aucun élément du backlog ne dépend
d'un point non vérifié : les chiffres de départ sont les nôtres et seront mesurés (TAC-4, TAC-9).

## 12. Sources (consultées le 17/10/2026 ; liste aussi dans `C:\AI\benchmark_refs\tactique\SOURCES.txt`)
- Counter-Strike 2 : profilerr.net « Economy guide in Counter Strike 2 » ; gamertagmythras.com « CS2 Economy Guide » et « CS2 Wingman Mode
  Explained » ; csdb.gg « Economy guide » et « What is Wingman in CS2 ».
- Valorant : oneesports.gg « Valorant economy guide » ; upcomer.com « How does the Valorant economy system work » ; Wikipédia « Valorant » ;
  redbull.com « Valorant beginners tips guide ».
- Overwatch 2 : prosettings.net « Overwatch Gamemodes Explained » ; guildorder.com « Overwatch 2 Competitive Mode Rules » ; règlement start.gg.
- Rainbow Six Siege : rainbowsix.fandom.com « Bomb (Siege) » ; guildorder.com « Rainbow Six Siege Game Modes ».
- Brawl Stars : Wikipédia « Brawl Stars » ; clutchpoints.com (conseils par mode) ; sportskeeda.com (Knockout 5 contre 5).
- Splatoon 3 : splatoonwiki.org « Tower Control », « Rainmaker », « Splat Zones », « Clam Blitz ».
- Paladins : paladins.fandom.com « Siege: Beyond » ; gamersdecide.com « Paladins best items ».
- Battlerite : Wikipédia « Battlerite » ; mein-mmo.de (aperçu) ; destructoid.com (critique).
- Apex Legends : étude BM-BR, `conception/benchmark/BATTLE_ROYALE.md` § 2.2 et § 9.
- Pages refusées : liquipedia.net (403), valorant.fandom.com (402).
- Nous : `game/scripts/combat/pvp_caps.gd`, `core/mode_rules.gd`, `combat/combatant.gd` (contrôles), `ai/class_rival.gd`, `core/duel.gd`,
  `core/duel_director.gd`, `world/proc_map.gd`, `player/player.gd` (vitesse 6,5 m/s, esquive 6 m), `data/classes.json`, `data/autochess_units.json`,
  modules `ui/royale_*.gd`, `ui/hit_arc.gd`, `ui/team_bars.gd`, `ui/duel_queue.gd` ; captures `shot_m7` de HEAD 0.1.284.
