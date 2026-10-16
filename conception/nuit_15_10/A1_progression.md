# A1 — Audit et plan de la « quête commune » de progression (jeu 0.1.163, nuit du 15/10/2026)

Audit **en lecture seule** (aucun fichier du jeu modifié). Chaque fait cite `fichier:ligne` (chemins relatifs à
`game/scripts/`). Les chiffres marqués **(calc.)** sont recalculés à partir des formules du code, ceux marqués
**(est.)** sont des estimations de durée ou de rythme, à mesurer avec le journal de run. Ce qui n'existe pas dans le
code est dit « absent » ; la section 5 propose, elle, des choses nouvelles et le dit.

---

## 0. En dix lignes

1. **L'équipement est déjà partagé entre classes** : un coffre commun (`Profile.vault`) et 3 préréglages par classe qui
   ne contiennent que des références (`uid`) (`core/profile.gd:33-35, 377-395, 468-475`). Seule l'arme principale est
   liée à la classe (son type, `profile.gd:398-415`) : 17 types d'arme pour 60 classes.
2. **Mur n°1 — l'optimisation « meilleur équipement » est inatteignable** : tout ce qui sert à monter une pièce vient de
   la Survie, et le butin de la Survie est plafonné au niveau 35 (`core/epochs.gd:21`, `core/run_director.gd:407-415`).
   Un parchemin de fortification doit avoir un niveau ≥ celui de la pièce (`core/craft.gd:382-384`) et le plus haut qui
   tombe est Lv 40 : **aucune pièce d'époque II à IV (niveau 48-90), ni même l'armure de la carte 3 de l'époque I
   (niveau 43), ne peut passer +1.** Les formules d'enchantement tombent au plus en Lv 2 (sur 9).
3. **Mur n°2 — les cristaux** : monter une pièce niveau 85 à +10 coûte ≈ 3 750 cristaux **(calc.)** ; la source la plus
   généreuse (Ruée Mythique complète) en donne 360.
4. **Aucune activité hors Survie ne donne de matière d'optimisation** (parchemins, gemmes, pierres) : Donjons, Ruée,
   Siège, Tour, Ligue, Panthéon, Royale, Arènes, Gantelet donnent de l'équipement brut, des cosmétiques, des insignes
   ou des cristaux, jamais de quoi le monter.
5. **Les insignes** (la monnaie d'achat) ne servent qu'à l'Armurerie et à la Roulette, et se gagnent ≈ 4 à 10 fois plus
   vite en JcJ contre l'IA (Arènes, Gantelet, Royale) qu'en Survie **(calc./est.)**.
6. **Le Panthéon** donne 6 pièces uniques dont la 6e (arme) n'est valable que pour le type d'arme de la classe qui bat le
   Champion ; l'« éveil » est cosmétique ; les promesses « achetable par toutes les classes » ne sont pas codées.
7. **Pas de capes** : aucun coffre de la Survie ne propose l'emplacement « dos » (`core/slot_chests.gd:11-28`) alors que
   la PE compte 9 emplacements.
8. **Pour 60 classes** : il n'existe aucun « meilleur équipement » automatique, aucune copie de préréglage entre classes,
   aucune vue « quelle classe est sous-équipée ». 1 620 affectations à la main.
9. **Maîtrise** : Arènes, Gantelet, Panthéon, Royale et Duel libre n'en donnent aucune ; seule la Ligue le fait
   (`core/league.gd:39-40`), alors que la conception (`conception/progression/raffinement_3.md` §3.2) le prévoyait.
10. **Proposition** : deux monnaies existantes (insignes = acquérir, cristaux = optimiser) + un **Registre de
    l'équipement** dans le Carnet qui dit, pour chaque classe, ce qui manque et quelle activité le donne ; 12 lots,
    dont 6 d'équilibrage simple (section 5).

---

## 1. Matrices

### 1.1 Activités × récompenses

Légende : ✔ donne · ✗ ne donne pas · (n) détail. « Maîtrise » = expertise de la classe jouée (`Profile.add_expertise`,
`profile.gd:795`). Il n'y a pas d'XP de compte : les niveaux de run repartent à 1.

| Activité | Maîtrise | Insignes | Cristaux | Fournitures (parchemins, gemmes, pierres) | Plans | Coffre d'équipement | Coffre d'apparence / aura | Titre | Pièces « découvertes » (Armurerie) | Autre |
|---|---|---|---|---|---|---|---|---|---|---|
| **Survie** | ✔ `max_level×15 + kills/2 + élites×10 + 200 (victoire) + 120×(étape−1)` (`run.gd:168`) | ✔ `25×étape + kills/25 + 2×élites + 60×époque (victoire)`, ×1,5 Défi, ×(1+0,15×rang) héroïque (`run.gd:183-188`) | ✗ (seulement en démontant) | ✔ monstres, caisses, coffres de carte, marchands ; **niveau ≤ 35** (`run_director.gd:414-415, 747`) ; gardées seulement si victoire / extraction (`profile.gd:526-533`) | ✗ | ✗ en Survie les coffres de monstres sont forcés en « forge » ou « joaillier » (`run_director.gd:716-722`) | ✔ boss de chaque carte (qualité = époque−1 + carte 3 + 20 %) (`run_director.gd:886-891`) ; rangs héroïques 3/6/9 (`run.gd:215-217`) ; Autel de la fortune (`fortune.gd:21-23`) | rang héroïque 10 (`run.gd:218-221`), succès | ✔ toute pièce **choisie** dans un coffre d'emplacement (`run.gd:178-182`, `apply_card` `run.gd:768-775`) | étoiles d'époque (`run.gd:201-207`), cartes à débloquer, classes (par maîtrise) |
| **Défi de maîtrise** (Survie E.I) | ✔ ×2, +600 la 1re fois du jour (`challenge.gd:80-90`) | ✔ ×1,5 | ✗ | comme Survie | ✗ | ✗ | ✗ | succès « Assidu » | ✔ | contrats de classe |
| **Contrats de classe** | ✔ 400-800 par contrat (`contracts.gd:8-15, 44-59`) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | succès | ✗ | rattrape les classes faibles |
| **Roulette** (Coffres) | ✗ | consolation 20-300 si collection du rang complète (`wheel.gd:30, 147-150`) ; **puits** : lancers en plus 50 / 100 (`wheel.gd:11-13`) | ✗ | ✗ | ✗ | ✗ | ✔ apparence (jamais de puissance) | ✗ | ✗ | 3 lancers / jour |
| **La Tour** | ✔ `(étages×12 + kills/3) × [0,75-1,6]` (`tower.gd:470-472`) | ✗ | ✗ (contre le texte `ui/activities.gd:17` « Joaillerie, cristaux ») | ✗ | ✗ | ✔ **1 pièce aléatoire par étage**, niveau de l'étage jusqu'à 100, légendaire 25 %+f/400 aux boss (`tower.gd:383-390`, `tower_director.gd:238-252`) | ✔ aux étages 50/100/150/200, une fois par difficulté (`tower.gd:21-24, 462-469`) | succès | ✗ | débloque Duel libre / Ligue (duellistes battus) |
| **Donjons** (Normal / Héroïque / Mythique) | ✔ `(salles×40 + 150 si victoire) × (1+diff)` (`tower.gd:502`) | ✗ | ✔ 20 × (diff+1) (`dungeons.gd:166, 177`) | ✗ | ✔ 10 % ; **certain** au 1er clear Héroïque / Mythique (`dungeons.gd:178-182`) | ✔ coffre de set (3 pièces mythiques / légendaires au choix, portant l'**archétype** du donjon) ; +1 coffre d'équipement en Mythique (`dungeons.gd:168-176`) | ✗ | ✗ | ✗ | `records.dungeon_*` |
| **Ruée des boss** | idem Donjons | ✗ | ✔ 15 × boss × (diff+1) (max 360) (`dungeons.gd:52`) | ✗ | ✗ | ✔ 1 coffre d'équipement si les 8 boss tombent (`dungeons.gd:56-60`) | ✔ 1er clear de chaque difficulté (`dungeons.gd:61-64`) | ✔ 3 titres (`dungeons.gd:34, 66-67`) | ✗ | |
| **Le Siège** | idem Donjons | ✗ | ✔ `12×min(vagues,5)×(diff+1) + 40×(diff+1)` si boss (`siege.gd:126`) | ✗ | ✗ | ✔ coffre d'équipement si le boss tombe (`siege.gd:132-135`) | ✔ dernier debout = légendaire, cœur emporté = mythique (`siege.gd:136-148`) | ✔ « Maître du Siège » | ✗ | |
| **Duel libre** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | succès | ✗ | `Duel.settle` renvoie `{}` hors modes classés (`duel.gd:229`) |
| **Ligue** (à l'arme, niv. 10) | ✔ `40 + 20×rang + 150×manches` par duel gagné (`league.gd:39-40`) | ✔ à chaque rang : `40 × rang` (`league.gd:45`) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ succès Bronze / Or / Platine | ✗ | débloque Royale (Argent), Gantelet + Arènes (Or), Panthéon (Platine) |
| **Panthéon** (6 cerveaux) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ **1 pièce de la panoplie des Esprits** à la 1re victoire (`pantheon.gd:101-105`) | ✔ coffre d'apparence + coffre d'auras ; nouvelle classe : coffre d'apparence de moins (`pantheon.gd:106-124`) | ✔ 6 titres + « Maître des Esprits » + « Panthéon des cinq » | ✗ | « éveil » = drapeau cosmétique (`pantheon.gd:127-138`) |
| **Arènes 2v2 / 3v3** | ✗ | ✔ `50 × (alliés+1)` **à chaque victoire, sans limite** (`duel.gd:219-221`) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ 1re victoire | ✗ | |
| **Gantelet** (équipé) | ✗ | ✔ `60 × (adversaires)` à chaque victoire (`duel.gd:219-221`) | ✗ | ✗ | ✗ | ✗ | ✗ | ✔ « Gantelet », « Gantelet complet » | ✗ | seule activité JcJ où l'équipement du hub compte (`duel.gd:238-239`) |
| **Battle royale** | ✗ | ✔ `[220…8] selon la place + 15/élimination` (`royale.gd:218-224`) | ✗ | ✗ | ✗ | ✗ (le butin de la partie est perdu : `royale.gd:9-10`) | ✔ top 3 : légendaire / mythique / rare (`royale.gd:237-241`) | ✔ « Dernier debout » (1re victoire) | ✗ | |
| **Rangs héroïques** | (Survie) | ×(1+0,15×rang) | ✗ | | ✗ | ✗ | rangs 3 / 6 / 9 | rang 10 | ✔ | |

### 1.2 Activités × prérequis

PE = puissance d'équipement (`core/gear_power.gd`). `Unlocks` : `core/unlocks.gd:11-30` (conditions `:34-69`). Le mode dev ouvre tout.

| Activité | Verrou (fil d'éveil) | PE exigée | Autre condition |
|---|---|---|---|
| Survie | aucun | aucune | époque N+1 = époque N gagnée (`epochs.gd:135-146`) |
| Défi de maîtrise | 3 Survies terminées (`unlocks.gd:49-50`) | aucune | Survie époque I seulement (`challenge.gd:65-70`) |
| Armurerie | 1 pièce découverte (`unlocks.gd:42-43`) | — | achat en insignes |
| Forge + Réserve | époque I gagnée (`unlocks.gd:51-52`) | — | |
| Plateau des certificats | maîtrise 3 d'une classe | — | |
| La Tour | époque I gagnée | aucune | une seule vie |
| Duel libre / Ligue | 1 / 3 duellistes de la Tour (floors 1, 4, 7 : `tower.gd:176-183, 417-423`) ou victoires | aucune (duels normalisés) | |
| Donjons | époque II gagnée (`unlocks.gd:57-58`) | Normal 0 · Héroïque 55 % · Mythique 80 % de la PE attendue du niveau (`gear_power.gd:17`, `dungeons.gd:113-126`) | boss de **la zone** battu en Survie (`dungeons.gd:98-108`) |
| Ruée des boss | Donjons | idem, jugée à l'étage du milieu (`dungeons.gd:113-116`) | |
| Le Siège | Donjons (`unlocks.gd:61-62`) | **35 % / 65 % / 90 %** (plus dur qu'un donjon, même Normal) (`siege.gd:31, 79-96`) | donjon de la zone ouvert |
| Battle royale | Ligue Argent ou 6 victoires de duel (`unlocks.gd:59-60`) | aucune (tout le monde part nu) | |
| Arènes, Gantelet | Ligue Or (`unlocks.gd:63-64`) | aucune (code) — la conception prévoyait un seuil de PE pour le Gantelet | |
| Panthéon | Ligue Platine (`unlocks.gd:65-66`) | aucune | cerveaux dans l'ordre (`pantheon.gd:58-60`) |
| Rangs héroïques | époque IV gagnée | aucune | rang précédent terminé |
| Butin légendaire des coffres de récompense | — | PE ≥ 50 % de l'attendue du coffre, sinon mythique (`rewards.gd:87-92`, `gear_power.gd:19`) | |
| Roulette / Coffres | 1 Survie terminée (`unlocks.gd:15`) | — | |

---

## 2. Où se trouve le « meilleur équipement » et par quelle activité

### 2.1 Catalogue des catégories

| Catégorie | Contenu réel dans le code | Où on l'obtient | Où on le monte / l'utilise |
|---|---|---|---|
| **Panoplies d'Eden par époque** | pièces mythiques (E.I-II) puis légendaires (E.II carte 3 → E.IV), « éveillées » = pièces `Awaken` niveau 70 / 80 (têtes, torses, jambes, gants, bottes seulement) (`epochs.gd:10-19`, `slot_chests.gd:54-58`) | **Choisies** dans un coffre d'emplacement de la Survie → `seen_gear` → **achetées en insignes** à l'Armurerie : mythique `30+niv`, légendaire `80+2×niv`, éveillé 250 (`gear_shop_page.gd:16-21`) ; aussi coffres de set / d'équipement des Donjons, Ruée, Siège, et pièces aléatoires de la Tour | Hub (Forge, Fabrication). **Pas de pièce « dos »** en Survie (`slot_chests.gd:26-28`) : capes seulement Tour / Donjons / Ruée / Siège / fabrication |
| **Archétypes de donjon** (8 panoplies : Tempête, Givre, Lame sanglante, Faucon, Phénix, Vent, Salve, Rempart) | un bonus 2 / 4 / 6 pièces **qui s'ajoute** à celui du set d'Eden (`items.gd:102-143, 432-441`) | coffre de set d'un donjon (3 pièces portant `archetype`) ; **fabrication** : un plan + `60×(meilleure difficulté+1)` cristaux → une pièce mythique (légendaire si fini en Mythique) à head / chest / legs / gloves / boots / back **seulement** (`fabrication_page.gd:8-9, 40-57`) | Plan trouvé à 10 % par clear (`dungeons.gd:178`) |
| **Panoplie des Esprits (Panthéon)** | `Items.SETS.pantheon` : effets de geste (annulation parfaite, esquive), pas de stats (`items.gd:124-129`) ; 6 pièces, une par cerveau, légendaires (`pantheon.gd:76-84`) | Panthéon, 1re victoire contre chaque cerveau | Tour, Donjons, Duel équipé, Gantelet |
| **Pièces « éveillées »** | Eden `Awaken …` : des légendaires d'Eden comme les autres, avec une aura (`slot_chests.gd:89-90`) ; côté Panthéon, drapeau `awakened` **sans effet** (seulement affichage : `items.gd:698`, `ui/item_widgets.gd:237, 284`) | E.III carte 3 et E.IV carte 3 (Survie) → Armurerie 250 | — |
| **Améliorations +1…+10** | chances `[1,1,.95,.9,.8,.7,.6,.5,.4,.3]`, perte de niveau dès +6 (`craft.gd:75-76`) ; coût hub en cristaux = `ceil(or/25)` avec `or = 30×(n)^1,6×(1+niveau/5)` (`items.gd:619-622`, `forge.gd:95-107`) | parchemin de fortification (« power » arme / « guard » armure) du **niveau ≥ celui de la pièce** (`craft.gd:58, 382-384`) | Forge du hub (`ui/forge_bench.gd`) |
| **Gemmes** | 8 types × 5 qualités, 2 emplacements, ciseaux (`craft.gd:16-29`) | caisses / jarres / cristaux à casser / coffres du joaillier de la Survie : qualité `niveau/8` jusqu'à royale (`craft.gd:516, 561`) ; fusion 3→1 (`forge.gd:78-120`) | Forge |
| **Enchantements** | 4 formules d'arme + 4 d'armure, Lv 1-9, objet de niveau ≥ [25…70] (`craft.gd:34-51, 336-359`) | autel du scribe, coffres ouvragés / dorés, marchands : **toujours Lv ≤ 2** (`scroll_level_for(≤35)`, `craft.gd:324-329`, `run_director.gd:1333`) | Forge |
| **Archive** | 8 paliers (10 → 1 500 pièces) : +8 % PV, +10 % dégâts… (`archive.gd:37-48`) ; **archiver retire la pièce du coffre** (`profile.gd:1283`) ; sans effet en duel à l'arme (`player/player.gd:266`) | tout mythique / légendaire | concurrence l'équipement des classes |
| **Trophées** | collection **de la run**, plus de l'équipement (`run.gd:76-79`) | Survie seulement | — |
| **Titres / apparences / auras** | pur cosmétique | 9 sources (voir 1.1) | Héros > Apparence |

### 2.2 Impasses, doublons, ressources sans puits, puits sans source, objectifs inatteignables

| # | Constat | Preuve | Gravité |
|---|---|---|---|
| **I1** | **+1…+10 impossible sur toute pièce de niveau > 40.** Les fournitures de la Survie sont tirées au niveau `loot_level` = `min(niveau, cap de la carte)` avec caps 15 / 25 / 35 ; `fortify_level_at` donne alors 20 / 30 / 40 au plus ; la pièce d'époque II à IV a 48-90. Même l'armure de la carte 3 de l'époque I (43) exige un Lv 50. Les marchands, l'autel du scribe et les coffres « forge » passent par la même fonction. | `epochs.gd:21` ; `run_director.gd:407-415, 747, 1333` ; `rewards.gd:270, 285` ; `ui/merchant_ui.gd:174` ; `craft.gd:58, 367-372, 382-384, 492-496` ; `profile.gd:1207-1209` | **Bloquante** |
| **I2** | **Enchantements Lv 3-9 jamais obtenables** (même mécanisme). Les 9 niveaux n'existent que dans les tables. | `craft.gd:50-51, 324-329` | Bloquante pour « enchantés » |
| **I3** | **Cristaux : puits énorme, sources minuscules.** +10 d'une pièce niveau 40 ≈ 1 870 cristaux, niveau 85 ≈ 3 750 **(calc.)**, la dernière marche seule ≈ 860. Sources : démontage mythique 7 / légendaire 8 (`items.gd:647-649`), Donjon 20-60, Ruée ≤ 360, Siège Mythique ≈ 300 (`dungeons.gd:52, 166`, `siege.gd:126`), coffre de forge 3-10 (`rewards.gd:280`). Il faudrait ≈ 10 Ruées Mythiques complètes **par pièce**. | `items.gd:619-622`, `forge.gd:95-107` | Bloquante |
| **I4** | **Aucune matière d'optimisation hors Survie.** Donjons / Ruée / Siège ne génèrent ni coffre « forge » ni « joaillier » alors que `Rewards.open` sait les faire au niveau du coffre (`rewards.gd:268-287`). Le Tour annonce « Joaillerie, cristaux » (`ui/activities.gd:17`) mais ne donne que des pièces (`tower.gd:383-390`) et des apparences. | `dungeons.gd:164-184`, `siege.gd:123-150`, `tower.gd:443-475` | Haute |
| **I5** | **Insignes : un seul puits sérieux** (Armurerie, 154 pièces au plus : `completion.gd:45` code en dur 154) + Roulette (50 / 100 par jour). Une fois la collection achetée, ressource **sans puits**. | `gear_shop_page.gd`, `wheel.gd:11-13` | Moyenne (long terme) |
| **I6** | **Insignes : déséquilibre de rythme.** Survie ≈ 180 (E.I) à 360 (E.IV) par victoire de ~35 min **(est.)** ; Arènes 3v3 : 150 par victoire, Gantelet 1v3 : 180, Royale 1re place : 220 + 15/kill — sans plafond, contre l'IA. Soit ≈ 4 à 10 fois plus vite à l'heure (≈ 2 250 à 2 600 insignes/h en JcJ contre ≈ 300 à 600 en Survie, est.). Or l'Armurerie ne vend que ce qu'on a **déjà choisi en Survie** : le JcJ ne fait que remplir un portefeuille que la Survie vide. | `duel.gd:214-228`, `royale.gd:218-224`, `run.gd:183` | Haute (équilibrage) |
| **I7** | **Mur d'armes** : la Survie ne propose en coffre d'arme que le type de la classe jouée (`slot_chests.gd:55-57`) ; l'arme secondaire (3 autres types tirés au sort, élite / boss) est l'autre voie (`slot_chests.gd:126-152`). Donc, pour posséder la meilleure arme des **17 types**, il faut avoir joué une classe de chaque type jusqu'au bon palier **ou** chanceux sur l'arme secondaire. Types : épée 6, bâton 6, arc 6, marteau 4, axe 2, 12 autres types × 3 classes. | `data/classes.json` (`weapon_type`), `profile.gd:398-415` | Haute |
| **I8** | **Panthéon : 3 écarts avec la conception.** (a) la pièce est ajoutée au coffre commun en un exemplaire, **pas à `seen_gear`** (aucun achat pour d'autres classes) ; (b) le Champion donne **l'arme du type de la classe gagnante** — les autres types n'y ont pas droit, donc le bonus 6 pièces n'est atteignable que pour un type d'arme (`pantheon.gd:78, 101-105`) ; (c) l'éveil ne renforce rien. De plus le niveau de la pièce vient de `max(best_level, 10)` et de la **zone sélectionnée au lobby** (`pantheon.gd:77`, `items.gd:278-292`) : une pièce « légendaire » de niveau modeste. | voir lignes | Haute |
| **I9** | **Maîtrise absente** des Arènes, du Gantelet, du Panthéon, de la Royale, du Duel libre (seule la Ligue l'accorde). Or c'est la maîtrise (17 480 points pour le niveau 20, 11 400 pour 16) qui limite « toutes les classes bien optimisées » plus que l'équipement. | `league.gd:39-40` ; `profile.gd:767-791` | Haute |
| **I10** | **Doublon : 9 sources de coffres d'apparence** pour un même stock (collection filtrée, jamais de doublon), alors que la progression d'**équipement** n'a que 3 sources fiables (Survie→Armurerie, Donjons, Tour). Les cosmétiques dominent les textes de récompense. | `rewards.gd:45-54` | Basse |
| **I11** | **Doublon : Donjon Normal** donne un coffre de set niveau ~20-40 que l'Armurerie vend déjà ; son seul intérêt est l'archétype et le plan (10 %). | `dungeons.gd:94-96, 168` | Moyenne |
| **I12** | **Siège plus verrouillé que les Donjons** : PE 35 % dès le Normal contre 0 % (`siege.gd:31` vs `gear_power.gd:17`) ; le Siège est un mode d'équipe vendu comme accessible. | | Basse |
| **I13** | **Fabrication limitée** : pas d'arme, pas de bijou ; pièce tirée au hasard dans l'Eden du niveau du donjon, pas ciblée ; coût 60-180 cristaux (donc **bon marché** par rapport à I3). | `fabrication_page.gd:8-9, 40-57` | Moyenne |
| **I14** | **Coffre « trophée » mort** : type encore dans `Rewards.TYPES` / `ORDER` et dans les aperçus, branche `if false` (`rewards.gd:19, 30, 130-131`). | | Basse |
| **I15** | **Autels / loteries sans lien avec l'équipement** (Roulette, Autel de la fortune, apparence dorée) : voulu (« le hasard ne donne jamais de puissance », `CONCEPT_FINAL.md` §1.5), mais ils ne participent pas non plus à la quête. | `wheel.gd`, `fortune.gd` | Voulu |
| **I16** | **Pièces mythiques de l'Armurerie « à +0 » sans moyen de les monter** (I1) : l'Armurerie ne vend donc que du « brut », et la Survie (bientôt avec équipement du hub, session N1) mesure sa puissance sur du +0. | | Conséquence de I1 |

---

## 3. « Toutes les classes bien optimisées »

### 3.1 Ce qui existe

- **Partage** : `Profile.vault` (tous les objets) + `presets[classe].sets[i].slots = {emplacement → uid}` ×3 par classe
  (`profile.gd:33-35, 377-395`). Une pièce peut figurer dans les préréglages de plusieurs classes ; `item_users(uid)` la
  liste (`profile.gd:468-475`). Monter, sertir ou enchanter la pièce profite à toutes les classes qui la portent.
- **Contraintes réelles** : l'arme principale doit être du type de la classe (`profile.gd:398-415`) → 17 armes à posséder ;
  l'arme secondaire est libre (60 % des dégâts, 50 % des stats : `DESIGN.md` §Auto-attaque).
- **Les pièces ne sont pas neutres** : chaque pièce d'Eden a ses ratios d'attributs (`r: {agi, int, lck…}`) et un type
  d'armure (tissu / cuir / plates) (`data/eden_items.json`, ex. « Awaken Meteor Storm Boots » = tissu, agi 1,6 / int 0,9).
  Mais `Items.rating` et `GearPower.hero_power` sont **indifférents à la classe** (`items.gd:516-534`,
  `gear_power.gd:24-42`) : une pièce de force vaut autant pour un Magicien que pour un Guerrier.
- **Copie de préréglage** : seulement entre les 3 préréglages **d'une même classe** (`profile.gd:457-465`,
  `ui/equipment_page.gd:238-247`). Aucun « appliquer à d'autres classes », aucun « équiper le meilleur » (le seul
  comparateur est la touche G en run : `ui/hud.gd:878-883`, `world.gd:439-440`).
- **Aucune vue d'ensemble** : ni la PE par classe, ni « cette classe n'a pas d'arme », ni « cette pièce servirait à
  telles classes ». L'Armurerie ne dit pas pour qui acheter.
- **Hors équipement, par classe et non partagés** : talents (2 points par niveau de maîtrise), sorts (4 au départ, 11
  autres de la maîtrise 2 à 16), préréglage de sorts (`SpellPresets`), maîtrise ; **partagés** : certificats équipés
  (`Profile.certificates`) et plateau (`Profile.cert_board`).

### 3.2 Chiffres de l'échelle

| Quantité | Valeur |
|---|---|
| Classes | 60 (20 vertes + 40 orange) |
| Emplacements d'équipement | 9 (weapon, head, chest, legs, gloves, boots, back, necklace, ring) + arme secondaire (`items.gd:20`, `gear_power.gd:46-48`) |
| Affectations à la main (60 classes × 3 préréglages × 9) | 1 620 |
| Types d'arme à posséder | 17 |
| Maîtrise 16 / 20 / 40 | 11 400 / 17 480 / 67 080 points **(calc.** `(L−1)(120+40L)`**)** |
| Gain d'une Survie | ≈ 300 (défaite carte 1) à ≈ 1 300 (victoire, 30 niveaux, 600 kills, 10 élites) **(est.)** |
| Survies victorieuses pour la maîtrise 20 d'**une** classe | ≈ 13 ; pour 60 classes ≈ 800 **(est.)**, avant Défi ×2, contrats et Ligue |

### 3.3 Ce qui manque (dans l'ordre d'impact)

1. **Une notion de profil de stats par classe** (attribut principal, physique ou magique, armure préférée) — absente du
   code ; il faut un tableau `classe → poids` (les 60 classes se rangent en quelques profils, ~5 à 8 ; à définir).
2. **Équiper le meilleur automatiquement** pour une classe (pièce du coffre commun maximisant la note pondérée), par
   emplacement, avec option « garder mes choix ».
3. **Copier / appliquer un préréglage à d'autres classes** (même profil de stats) et **« équiper la famille »**.
4. **Un indicateur « équipement optimal par classe »** (PE, arme du bon type, archétype x/6, nombre de +10, gemmes,
   enchantement) = le Registre proposé en 5.3.
5. **Les 17 armes** (I7) et **les capes** (I1/I7 de 2.2).
6. **Les matières d'optimisation** (I1-I4) — sans elles, 3-5 restent des coquilles vides.

---

## 4. Les cinq premières heures d'un compte neuf

Hypothèses : le joueur suit la voie la plus rapide ; un tour de Survie = 3 cartes de 10 min d'horloge avant la rage
(`run_director.gd:21`) + boss + portail, soit ≈ 30-40 min **(est.)** ; un duel de Ligue ≈ 4-5 min avec file d'attente
et brouillon (manches de 66-81 s : `CLAUDE.md` « Duel »). Gains en maîtrise et insignes : voir 1.1.

| Fenêtre (est.) | Ce que fait le joueur | Ce qu'il gagne | Déverrou / hameçon | Creux ou mur |
|---|---|---|---|---|
| 0:00-0:10 | Accueil : parcours guidé, 1 des 5 classes, contrôles, niveau d'aide (`ui/welcome.gd`) ; **Premiers pas** dans la vraie Survie (arme, kills, saut, esquive, carte, sort, enchaînement, coffre, sceau, boss : `tutorial.gd:11-22`) | — | — | — |
| 0:10-0:45 | **Survie 1** (E.I). Probable abandon / défaite en carte 1-2 (voulu : « 1re run punitive ») | maîtrise ≈ 300-600 ; insignes ≈ 50-100 ; coffre d'apparence du boss vaincu (qualité 0) ; pièces choisies → `seen_gear` | **Carnet, Coffres (+ Roulette), Armurerie** s'ouvrent (`unlocks.gd:14-16`) ; fiche « Ce que tu gardes » (`tutorial.gd:53-54`) | **C1** : l'Armurerie vend des pièces +0 qui ne servent **à rien en Survie** (départ sans équipement : `run.gd:155-156`) — pas d'usage avant la Tour (session N1 en cours sur ce point) |
| 0:45-2:00 | **Survies 2-3** ; Armurerie : 1re pièce (mythique niveau 23 = 53 insignes : `gear_shop_page.gd:20-21`) ; Roulette quotidienne | maîtrise de la classe → niveau 3 (480 points) ; certificats ; classes **Chevalier, Barde, Inquisiteur** (maîtrise 3 d'une classe de base : `progression.gd:17-20`) | **Défi de maîtrise** après 3 Survies (`unlocks.gd:49-50`) ; **Plateau des certificats** à la maîtrise 3 | **C2** : le joueur a des insignes mais rien à acheter hors pièces +0 inutilisables ; il change de classe pour débloquer les verts → la maîtrise se disperse |
| 2:00-3:00 | **Survies 4-6** jusqu'à la 1re victoire d'époque I (le joueur a déjà « bien capé » l'E.I : `CLAUDE.md`) | maîtrise ≈ 1 300 ; insignes ≈ 180 ; coffre d'apparence qualité 1 ; **étoiles** | **Époque I gagnée = trois portes d'un coup** : Époque II, **Forge + Réserve**, **La Tour** (`unlocks.gd:19-20`) | **C3** : la Forge s'ouvre sans cristaux (seule source : démonter) ; le premier +1 coûte déjà quelques cristaux ; les fournitures de la Survie ne sont gardées que sur victoire / extraction (`profile.gd:526-533`) |
| 3:00-3:40 | **Tour étages 1-7** : l'étage 1 est un duel (`default_type` : `f%3==1`) → **Duel libre** ; les étages 4 et 7 → 3 duellistes → **Ligue** (`unlocks.gd:53-56`) ; premiers coffres de la Tour : **le seul endroit où l'équipement du hub sert** | pièces aléatoires de la Tour (mises dans le coffre commun) ; maîtrise (étages×12) | Duel libre, Ligue | **C4** : Duel libre ne donne rien (`duel.gd:229`) |
| 3:40-5:00 | **Ligue** : Bronze puis Argent = 6 victoires d'affilée minimum ≈ 30-40 min si aucune défaite (`league.gd:41-49`) ; ou **Époque II** | insignes 40 / 80 ; maîtrise (40 + 20×rang + 150/manche) | **Royale** à l'Argent (`unlocks.gd:59-60`) | **M1** : l'Époque II (monstres ×1,35 : `epochs.gd:25`) coïncide avec l'attente des **Donjons**, qui exigent l'époque II **gagnée** + le boss de la zone + PE ; **C5** : la Royale s'ouvre sans lien avec l'équipement et paie ≈ 4 à 10× la Survie en insignes |
| **> 5:00** | Or → Gantelet + Arènes ; Platine → Panthéon ; E.II gagnée → Donjons (Normal) ; E.IV → rangs héroïques | | | **M2** : Donjons Héroïque / Mythique (PE 55 % / 80 %) demandent des pièces niveau 60-90, atteintes seulement en époque III-IV (Armurerie) |

**Creux** : C1-C5 ci-dessus ; **murs** : M1 (marche d'époque II), M2 (PE), et le mur silencieux I1-I3 (aucune activité ne
laisse monter l'équipement) qui n'apparaît qu'au moment où le joueur voudrait « finir » une pièce.

**Hameçons existants qui fonctionnent** : l'époque I gagnée ouvre trois voies à la fois ; les cascades Ligue (Argent → Or →
Platine) donnent un objectif court terme visible (`ui/activities.gd` : cartes grisées avec leur condition).

---

## 5. Proposition

### 5.1 La quête commune, en une phrase

> **Forger, pour chacune des 60 classes, la meilleure panoplie possible — pièces d'époque, archétype de donjon,
> panoplie des Esprits, montées à +10, serties et enchantées — en jouant chaque activité pour la seule chose qu'elle
> apporte.**

### 5.2 La monnaie qui relie tout (aucune nouvelle monnaie)

- **Insignes = acquérir** (Armurerie : débloquer les pièces découvertes ; Roulette). Source principale : Survie ; JcJ
  en complément **plafonné** (lot A3).
- **Cristaux = optimiser** (Forge : +1…+10, polir, réforger ; Fabrication). Source principale : **Donjons / Ruée / Siège /
  Tour** (nouveau), plus le démontage.
- **Fournitures** (parchemins Lv 20-100, gemmes, formules Lv 1-9, pierres) : un seul pipeline de **coffres de matières**
  générés **au niveau de l'activité** (`Rewards.make("forge"/"jewel", niveau)`, déjà capable de `Lv` élevés :
  `rewards.gd:268-287`).
- **Le Registre de l'équipement** (lot B2) est la surface commune : pour chaque classe, la liste de ce qui manque et,
  en face de chaque ligne, **l'activité qui le donne**. C'est lui qui rend la quête lisible.

### 5.3 Rôle unique de chaque activité

| Activité | Ce qu'elle seule donne (proposé) | État actuel |
|---|---|---|
| **Survie** | **Découverte** des pièces d'époque (→ Armurerie), maîtrise de classe (source principale), cartes / trophées de run, étoiles, rangs héroïques | déjà le cas, sauf matières (I1) |
| **Armurerie / Atelier** | Le **puits** d'insignes (acheter) et de cristaux (monter) ; pas de source | déjà le cas |
| **Donjons** | **Archétypes de donjon** (panoplie 2/4/6), **plans** et fabrication ; **pièces ciblées** par set à haut niveau (Mythique = 90) | déjà le cas, mais Normal est un doublon (I11) |
| **Ruée des boss** | **Matières de haut niveau** : parchemins Lv 60-100, gemmes parfaites / royales, pierres halcyon (réponse à I1) ; titres | donne des cristaux + 1 coffre d'équipement |
| **La Tour** | **Cristaux et gemmes** (comme annoncé dans `activities.gd:17`) et **pièces de rattrapage** (cape, bijoux, armes de n'importe quel type via son tirage) ; paliers cosmétiques | donne des pièces aléatoires + apparences |
| **Le Siège** | **Formules d'enchantement hautes** (Lv 5-9) et coffre d'équipement (coop) | donne gear + apparence + cristaux |
| **Ligue** | **Rangs** + maîtrise + clé d'accès au JcJ | déjà le cas |
| **Panthéon** | La **panoplie des Esprits**, accessible à toutes les classes, et les auras | pièce unique non partagée (I8) |
| **Arènes, Gantelet** | **Titres** et maîtrise d'équipe ; équipement du hub **mis à l'épreuve** (Gantelet) | insignes sans plafond (I6), pas de maîtrise |
| **Battle royale** | **Cosmétiques de prestige** (top 3) et titre ; insignes modestes | insignes très généreux (I6) |
| **Défi de maîtrise + contrats** | **Rattrapage de la maîtrise** des classes faibles (×2, +600, contrats 400-800) | déjà le cas |
| **Roulette, Autel de la fortune** | **Cosmétiques** uniquement (le hasard ne donne jamais de puissance) | déjà le cas |

### 5.4 Lots de travail, dans l'ordre

Taille : S ≤ 1 envoi simple, M = quelques fichiers, L = nouveau système. « Conflit N1 » = touche la Survie que la
session N1 modifie en parallèle (`run.gd`, `run_director.gd`, `slot_chests.gd`, `epochs.gd`, `profile.gd` en `begin_run` /
`start_survival`, `loot_level`).

**A — Équilibrage / corrections simples (pas de conception nouvelle)**

| Lot | Objectif | Fichiers | Taille | Dépend de | Conflit |
|---|---|---|---|---|---|
| **A1** | **Débloquer l'optimisation (I1, I2, I4)** : (a) coffres « forge » + « joaillier » ajoutés au butin de Donjons / Ruée / Siège / Tour au **niveau de l'activité** (`Rewards.make("forge", lv)` : le contenu suit déjà `lv`) ; (b) en Survie, tirer les fournitures au niveau de la **carte d'époque** (`Epochs.map_def(...).armor`) et non au cap 35 | `core/dungeons.gd` (`reward`, `rush_reward`), `core/siege.gd` (`settle`), `core/tower.gd` (`finish`, `_finish_dungeon`), `core/run_director.gd:747`, `ui/merchant_ui.gd:174` | S-M | — | (a) aucun ; (b) **conflit N1** (`run_director`) → faire (a) d'abord |
| **A2** | **Recaler les cristaux (I3)** : `Forge.GOLD_PER_CRYSTAL` (25 → 100-150 pour que +10 niveau 85 ≈ 600-900) **et** les sources (Donjon / Ruée / Siège ×3-5, démontage) ; objectif : un clear Mythique ≈ 150-200 cristaux, une pièce à +10 ≈ 4-5 clears | `core/forge.gd:95`, `core/dungeons.gd:52, 166`, `core/siege.gd:126`, `core/items.gd:647-649` | S | A1 | aucun |
| **A3** | **Maîtrise partout et insignes JcJ plafonnés (I6, I9)** : maîtrise pour Arènes / Gantelet / Panthéon / Royale (formule type Ligue) ; insignes des Arènes / Gantelet / Royale **première victoire par rang / par jour** ou plafond quotidien | `core/duel.gd:214-228`, `core/pantheon.gd:89`, `core/royale.gd:218`, `core/league.gd` (formule commune) | S | — | aucun |
| **A4** | **Textes et compteurs faux** : gains de la Tour (`ui/activities.gd:17`), Donjons, fiche « Ce que tu gardes », `Completion` « Équipement » (154 en dur : `completion.gd:45`), coffre « trophée » mort (I14) | `ui/activities.gd`, `core/tutorial.gd:53`, `core/completion.gd`, `core/rewards.gd` | S | — | aucun |
| **A5** | **Plans et PE sans friction (I12, I13)** : plan garanti au 1er clear de chaque difficulté (aujourd'hui seulement H et M) ; fabrication de l'arme et des bijoux ; Siège Normal à 0 % de PE | `core/dungeons.gd:178`, `ui/fabrication_page.gd:8`, `core/siege.gd:31` | S | — | aucun |
| **A6** | **Capes (I-dos)** : ajouter le coffre « dos » (`back`) aux coffres d'emplacement ou, au minimum, à l'Armurerie | `core/slot_chests.gd:11-28`, `core/epochs.gd` (`awakened`), `ui/gear_shop_page.gd` | S | — | **conflit N1** (`slot_chests`) |

**B — À concevoir (décisions de fond, avant le code)**

| Lot | Objectif | Fichiers | Taille | Dépend de | Conflit |
|---|---|---|---|---|---|
| **B1** | **Profil de stats par classe + meilleur équipement automatique + copie entre classes** : tableau `classe → profil` (5-8 profils), note pondérée `Items.rating(item, profil)`, bouton « Équiper le meilleur », « Appliquer à la famille » | `core/items.gd` (rating), `core/profile.gd` (presets), `ui/equipment_page.gd`, `data/classes.json` ou nouveau `data/class_profiles.json` | M-L | décision de conception (poids) | léger si N1 touche `Profile.equipped` |
| **B2** | **Registre de l'équipement** (Carnet) : par classe, PE vs attendue, arme du bon type, archétype x/6, panoplie des Esprits x/6, nombre de +10, gemmes, enchantement ; ligne « il manque → activité X » ; bandeau dans le lobby | `core/completion.gd`, `ui/carnet_pages.gd`, `core/gear_power.gd` (PE cible par classe), `core/unlocks.gd` (texte du fil) | M | B1 (cibles par classe), A1 | aucun |
| **B3** | **Les 17 armes (I7)** : au choix — (i) un coffre « arme de type au choix » en Ruée / Siège ; (ii) quand une pièce est vue, marquer les armes de même palier des autres types comme « découvertes » (une ligne dans la boucle de `run.gd:178-182`, **conflit N1**) ; (iii) tirer une arme de type au choix dans la Tour | `core/rewards.gd`, `core/dungeons.gd`, `ui/gear_shop_page.gd` ou `core/run.gd` | M | décision | (ii) conflit N1 |
| **B4** | **Panoplie des Esprits universelle (I8)** : pièces dans `seen_gear` (achat par toutes les classes), arme du Champion de n'importe quel type, éveil qui renforce vraiment le bonus 6 pièces, niveau de pièce fixe | `core/pantheon.gd`, `core/items.gd:124-129`, `ui/gear_shop_page.gd` | M | A3 | aucun |
| **B5** | **Rythme des insignes** : un barème unique par activité (insignes / heure visés), Armurerie à paliers, puits supplémentaires quand la collection est complète (I5) | `core/run.gd:183`, `core/duel.gd`, `core/royale.gd`, `ui/gear_shop_page.gd` | M | A3 | `run.gd` : conflit N1 |
| **B6** | **Pont vers la maîtrise des 60 classes** : « Défi de maîtrise » par classe sous 16, séries, ou maîtrise partagée à 10 % entre classes d'une famille | `core/challenge.gd`, `core/contracts.gd`, `core/profile.gd` | M-L | A3 | aucun |

**Ordre conseillé** : A4 → A1(a) → A2 → A3 → A5 → B1 → B2 → A6 → B3 → B4 → A1(b) → B5 → B6. A1(a)+A2+A3 suffisent à rendre
la quête **possible** ; B1+B2 la rendent **lisible** pour 60 classes.

### 5.5 Questions de conception laissées ouvertes (pour le retour du joueur)

1. Combien de profils de stats pour les 60 classes, et qui les définit (le joueur ou une règle sur `dmg_type` + attribut
   de croissance le plus fort) ?
2. Faut-il que les Donjons Normal gardent un coffre de set (doublon avec l'Armurerie) ou deviennent le lieu de la
   « matière » (forge / joaillier) ?
3. Les armes de type au choix : en Ruée, en Siège, ou par « découverte automatique » en Survie ?
4. Le JcJ doit-il rapporter des insignes (rythme actuel) ou seulement des titres et de la maîtrise ?
5. Un parchemin de fortification de niveau 100 doit-il être un objectif en soi (rareté) ou un simple palier de matière ?

### 5.6 Vérifications à faire avant de coder (non faites ici, lecture seule)

- Mesurer au journal de run la part réelle des fournitures par niveau de butin (`core/run_journal.gd`).
- Compter exactement les pièces des 4 époques disponibles à l'Armurerie (la valeur 154 de `completion.gd:45` est en dur).
- Vérifier le niveau réel des pièces du Panthéon et de la Tour selon `Items.zone_band()` (dépend de `Run.zone_id` /
  `Profile.selected_zone`, `items.gd:278-292`).
- Confirmer avec N1 ce que devient `Profile.equipped` en Survie (départ avec équipement du hub) : le lot A1(b) et le
  choix de l'enclume (`Run.slot_bonus`) en dépendent.

---

## 6. Addendum — état du dépôt en cours d'audit (modifications non commitées de la session N1, « 0.1.164 »)

Relevé à la fin de l'audit (`git diff`, `game/scripts/core/starter_gear.gd` non suivi) ; **les citations de ce document
décrivent le dépôt de la 0.1.163**, sauf mention contraire.

- **Survie avec l'équipement du hub** (`run.gd`, `run_director.gd`, `profile.gd`) : le message de départ devient « Tu pars avec
  ton équipement du hub : les coffres de la carte le remplacent le temps de la run ». Cela **résout en partie C1** (les pièces
  de l'Armurerie servent enfin en Survie) mais **ne change ni I1 ni I3** : les fournitures de la Survie restent plafonnées
  au niveau de carte (35) ; au contraire, une pièce du hub à +0 niveau 60-90 y devient la référence de puissance.
- **`StarterGear`** (`core/starter_gear.gd`, nouveau) : 8 pièces d'Eden communes à rares de niveau 10-20 par classe (+ remise
  une seule fois, `Profile.starter_done`). Elles sont fortifiables avec les parchemins Lv 20-30 de la Survie : c'est le
  **seul** niveau de pièce que les fournitures actuelles savent monter. Bon pour le départ de 60 classes (réponse partielle à
  la section 3 : l'équipement de **départ** est automatique), sans lien avec le « meilleur équipement ».
- **Gemmes** (`craft.gd`, `gem_run_factor`) : en Survie, les valeurs plates des gemmes suivent le niveau du héros (×0,35 à ×2,
  pleines au niveau 15) ; le hub reste à pleine valeur. Cela rend la **royale** moins disproportionnée en début de run mais
  creuse l'écart « puissance au hub / en Survie » — à garder en tête pour A1(b) et le Registre (B2).
- **Conséquences sur les lots** : A1(b) et A6 (Survie, `slot_chests.gd`) restent à coordonner avec N1 ; le Registre (B2) devra
  compter les 8 pièces de départ comme « équipement de base » et non comme « optimal » ; la section 4 (fenêtre 0:10-0:45, C1)
  change : le compte neuf n'est plus nu.
