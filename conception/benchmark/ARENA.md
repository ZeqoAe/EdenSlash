# Le Colisée (mode « Arena ») face aux meilleurs du genre : étude et spécification v2 (BM-ARENA, 17/10/2026)

Mandat du joueur : un mode « Arena » façon League of Legends adapté à Eden Slash : équipes, manches courtes d'affrontement,
atouts entre les manches, élimination progressive, plusieurs équipes en même temps ; idée de départ « 8 équipes de 3 ». Mode
**scellé** (aucun lien avec le compte, comme le Battle royale et l'Échiquier), **IA scriptée qui joue très bien** (aucun cerveau
neuronal), DA « autocollant manga ». Méthode : `METHODE.md`. DA : `art/BIBLE.md` v2. Étude de format : `AUTOCHESS.md`.
Croquis maison : `arena_maquettes/` (5 SVG 1600 × 900 : page du lobby, préparation, choix d'atout, HUD de combat, bilan). Captures de nos écrans (HEAD 0.1.284, copie propre) et notes : **hors dépôt**,
`C:\AI\benchmark_refs\arena\`. Aucune image, aucun son ni texte tiers dans le dépôt : on décrit des mécanismes, avec nos mots.

Nom de travail : **« Le Colisée »** (le mot « Arènes » est déjà pris par le 2 contre 2 / 3 contre 3 du Duel, qui garde son rôle ; voir Q2).

**Verdict en une phrase** : nous avons déjà presque toutes les briques d'un Arena (combat d'équipe IA mesuré à 74-88 s par manche,
plateaux simultanés cachés de l'Échiquier, atouts à 3 raretés avec relance, butin scellé du Battle royale, anneau qui tue, réanimation,
bilan commun) ; ce qui manque est le **liant** (une machine de partie à plusieurs équipes, des PV d'équipe, un appariement tournant,
un anneau de feu de manche), un **jeu d'atouts propre aux héros** (pas aux unités de l'Échiquier), une **IA d'équipe** (chef qui choisit
la cible, la formation, la relève) et un **cadre lisible** (classement des équipes, vignettes des autres combats, choix d'atout v2).
Format recommandé : **6 équipes de 3** (18 héros, 3 combats en même temps, ≈ 19 min) ; « 8 équipes de 3 » reste possible en option
« Grand tournoi » **après** une mesure de performances (§5).

---

## 1. Sources et ce qui a été vérifié

| Référence | Ce qu'on a lu (sources écrites, consultées le 17/10/2026) | Statut |
|---|---|---|
| **LoL Arena** (Riot, 2023 → 2026) | wiki officiel LoL « Arena » (règles, manches, PV d'équipe, atouts, enclumes, anneau, relève, invités d'honneur, historique) ; page d'aide Riot « What is Arena? » ; notes de patch 26.11 (Arena à trois) ; articles gamewave.fr (05/05/2026, équipes de 3), esports.gg et riftfeed (refonte 2024, 16 joueurs) ; loltheory (durée) | vérifié par écrit ; aucune partie jouée, aucune vidéo regardée |
| **Overwatch 2 « Stadium »** (Blizzard, 2025) | notes de la saison 16, Icy Veins, Sportskeeda (règles : 5 contre 5, première équipe à 4 manches, Armurerie entre les manches, Pouvoirs aux manches 1, 3, 5, 7, rattrapage) | vérifié par écrit (règles du lancement) |
| **TFT Double Up** (Riot) | wiki LoL « TFT:Double Up », aide Riot, billet « Double Up upgraded » (PV partagés, renforts, canon d'équipe, armurerie d'aide) | vérifié ; versions qui se contredisent sur le « dernier PV » |
| **Battlerite** (Stunlock, 2017) | Destructoid, gamepressure, TechRaptor, fandom (manches de 2 min, 3 manches gagnantes, brume qui resserre, orbe central, « battlerites » choisis entre les manches puis préréglés) | vérifié (sources 2016-2017) |
| **Brawl Stars « Knockout »** (Supercell) | Wikipédia, noff.gg (3 contre 3, 2 manches gagnantes, pas de réapparition, nuage de poison) | vérifié ; règle d'égalité **non vérifiée** (sources divergentes) |
| **Hearthstone « Duels »** (Blizzard, 2020) | billet officiel « Dev Insights : Treasure Pools & Smart Loot Buckets » (17/11/2020) : trésors par réservoirs de puissance, paquets « intelligents » notés selon le deck | vérifié ; fin du mode en 2024 **non vérifiée** |
| Dota 2 « Overthrow 3.0 » (carte d'arcade) | esports.ru, journal Steam (mêlée à objectif de K.O., modes Duos / Quintet / Octet) | vérifié en surface |
| Smash, Brawlhalla (équipes), Rocket League | connaissance générale du genre (lisibilité des équipes, rangs) | **non vérifié** pendant l'étude, cité pour mémoire |
| **Eden Slash** (0.1.284, HEAD propre) | captures `tests/shot_m7.tscn` (Arènes 3v3, Gantelet, pages du Duel, 1600 × 900) ; code `core/duel*.gd`, `ai/class_rival.gd`, `core/autochess_director.gd`, `core/royale*.gd`, `core/mode_rules.gd`, `combat/combatant.gd` ; rapports `R_M7`, `R_AC_E`, `R_AC_J`, `R_BR1`, `R_BRI1-3` | lu et capturé |

Limites : aucune référence jouée (pas de client, pas de compte) ; aucune image tierce téléchargée pendant cette étude (le dossier
`C:\AI\benchmark_refs\arena\` contient nos captures et un fichier `SOURCES.txt` avec les liens). Ce qui n'a pas pu être confirmé est
marqué **non vérifié** et repris au §11. Les durées de partie de LoL Arena sont des **estimations publiques** (20 à 35 min ; cible
annoncée de Riot ≈ 30 min en 2024), pas des mesures.

---

## 2. Ce qui fait la qualité de chaque référence

### 2.1 LoL Arena : le modèle (rythme, atouts, élimination)
- **Format** (vérifié, historique du wiki) : 4 équipes de 2 au lancement (07/2023) ; **8 équipes de 2** (16 joueurs) depuis 05/2024 pour
  la variété (« ne pas revoir les mêmes paires », propos de Riot rapporté par esports.gg) ; **6 équipes de 3** (18 joueurs) en 2026
  (patch 26.10-26.12 selon la presse, 26.11 parle d'« Arena à trois ») ; « Swift Arena » à 4 équipes de 2 (rapporté, **non vérifié**
  dans une source officielle). Riot n'a donc **jamais** fait 8 × 3 = 24 joueurs : au passage à 3, il a réduit le nombre d'équipes.
- **Manche** (vérifié) : préparation 45 s (6 s quand tout le monde a choisi ; mannequin d'essai à 5 s) puis combat ; appariement
  **tournant** : pas deux fois la même équipe avant d'avoir vu toutes les autres ; équipe en trop **exempte** ; après son combat on
  peut regarder les autres arènes.
- **PV d'équipe** (vérifié) : 100 ; perte par manche perdue 15 (manches 1-4), 20 (5-8), 30 (9-12), 35 (13-16), 100 (17) : la fin est
  garantie. Places 1-4 sur 8 = « victoire ». Abandon à deux voix dès la manche 4.
- **Anneau de feu** (vérifié) : part à 30 s de combat, se ferme par à-coups de 5 s, dégâts vrais croissants hors de l'anneau (6 % des PV
  par seconde au départ) ; manche nulle si personne ne gagne 15 s après la fermeture. **Six arènes** à particularités : fleurs qui
  soignent / protègent, champignons qui repoussent, portails, pont qui s'ouvre, piliers qui tombent.
- **Relève** (vérifié) : premier coup mortel = à terre ; l'allié se tient dans la zone ≈ 3 s (moins avec ses soins) ; une relève par
  équipe et par manche ; le relevé revient avec peu de PV, invulnérable et rapide un instant.
- **Atouts** (vérifié) : 3 raretés (Argent, Or, Prisme), choix à 3 cartes aux manches 1, 5, 8, 11, **6 atouts au plus**, **4 relances
  pour toute la partie**, choix au hasard si le temps manque ; atouts interdits à certains champions ; **recettes** (trois atouts
  d'une même famille fusionnent en un quatrième) ; atouts qui grandissent avec le nombre d'atouts « colorés » tenus.
- **Boutique** (vérifié) : or fixe par manche (calendrier : 500, 500, enclume Prisme offerte à la 3, 2 500…) ; **enclumes** à choisir
  1 parmi 3 (stats, objet de classe, objet Prisme) : le hasard contrôlé remplace la recherche dans un catalogue.
- **Invités d'honneur** (vérifié) : aux manches 2 et 8, vote de 25 s ; une **règle pour toute la partie** (ex. « la 1re élimination
  laisse l'équipe à 1 PV », « tout le monde reçoit le même atout »).
- **Champions** : sélection avec bannissements ; bouton « au hasard » récompensé (« Bravoure »), favoris du public (**vérifié** sur le wiki).
- **Progression** : « Renommée » (paliers 1-12, médaillons, atouts débloqués) à la place d'un classement (2025, vérifié).

### 2.2 Overwatch 2 « Stadium » : la profondeur de construction entre les manches
- 5 contre 5, première équipe à **4 manches**, héros fixé pour la partie (vérifié). **Armurerie** à chaque manche : monnaie gagnée en
  jouant, 6 objets au plus en 3 familles (arme, capacité, survie), revente au prix d'achat ; **Pouvoirs** gratuits aux manches 1, 3,
  5, 7 qui changent la façon de jouer le héros (vérifié). **Rattrapage** : une équipe très en retard gagne plus à la manche suivante ;
  prime sur le meilleur joueur (vérifié).
- À retenir : **revente au prix d'achat** (aucune peur de se tromper), **pouvoirs** à des manches fixes et connues d'avance.

### 2.3 TFT Double Up : l'équipe à deux avant tout
- PV **partagés** par le duo ; **renforts** : qui finit son combat 3 s avant l'autre envoie ses survivants aider le partenaire ;
  **canon d'équipe** pour donner une unité ; armurerie d'aide (objets, or) (vérifié, versions variables).
- À retenir : le partenaire **compte** pendant le combat de l'autre, et un geste de don simple.

### 2.4 Battlerite : l'arène à compétences vue de dessus (le plus proche de notre combat)
- 2 contre 2 ou 3 contre 3, manches de **2 min**, 3 manches gagnantes ; une **brume** couvre l'arène à la fin du temps ; un **orbe** au
  centre donne énergie et PV à l'équipe qui le casse ; bonus (« battlerites ») choisis **avant chaque manche** au lancement, puis
  **préréglés** avant la partie (vérifié, sources 2016-2017).
- À retenir : un **objectif central** qui force le contact, et la leçon du préréglage (choisir 5 fois par partie lassait une partie des joueurs).

### 2.5 Brawl Stars « Knockout » : la lisibilité mobile
- 3 contre 3, 2 manches gagnantes, **pas de réapparition** dans la manche, **poison** qui avance des bords (vérifié). Arènes petites,
  couverts nombreux, tout le monde visible à l'écran.

### 2.6 Hearthstone « Duels » : des choix qui ont du sens
- Trésors en **réservoirs de puissance** (1 : simples ; 2 : forts, avec un sous-ensemble ultra-rare à 1 %) offerts à des manches fixes ;
  **paquets « intelligents »** : les trios proposés sont notés selon la classe et le deck du joueur, puis tirés au sort selon la note
  (plus probables, jamais garantis) ; pénalité de doublon (billet du 17/11/2020, vérifié).
- À retenir pour nous : **proposer des atouts qui vont avec la classe et le trio** (jamais « Soins + » à un héros sans soin).

### 2.7 Dota « Overthrow » (pour mémoire)
- Mêlée de plusieurs équipes sur **une seule** carte, premier au nombre de K.O. (vérifié en surface). C'est l'autre lecture de « plusieurs
  équipes en même temps sur une arène » : nous la gardons en option de fin de partie (§6.12, « Mêlée finale », P2).

---

## 3. Ce que nous avons déjà (captures 0.1.284 et code)

| Brique | Où | Ce qu'elle donne au Colisée | Limite constatée |
|---|---|---|---|
| **Arènes 2v2 / 3v3** du Duel | `core/duel_director.gd`, `core/duel.gd` (`make_ally`, `team_classes`, `hazards`), `ui/team_bars.gd`, profils `arena2` / `arena3` de `ModeRules` | combat d'équipe IA complet : alliés à la fiche d'un héros, familles différentes, compte à rebours, tableau de manche (dégâts, K.O.), mort subite à 90 s, arène piégée ; manches **74 s (2v2) et 88 s (3v3)** mesurées (R_M7) | une seule rencontre à la fois, 2 manches gagnantes, état **statique** dans `Duel` / `PvpCaps` ; HUD et bilan dans l'ancienne DA sur nos captures (texte de manche au centre, pas de classement) |
| **IA de héros** | `ai/class_rival.gd` (4 difficultés : réaction 0,45 → 0,06 s, lecture des coups 12 → 95 %) | cible le plus faible, esquive les zones rouges de tous les camps, retraite sous 30 % vers un équipier, soins et renforts d'équipe | `_teammates()` rend **[soi seul]** en chacun pour soi ; `_threat` ne lit que le **joueur** ; pas de chef d'équipe (pas de cible commune, pas de formation, pas de relève) |
| **Combats simultanés cachés** | `core/autochess_director.gd` (plateaux à 300 m, `watch(i)`, rendu du seul plateau regardé, repli `fallback_ms`, `data_fight`) | le patron exact pour 3 ou 4 combats en même temps ; mesuré : **80 unités** (dérivées de `ClassRival`) sur 4 plateaux, image physique médiane **6 ms**, p95 20-80 ms aux apparitions (R_AC_E) | unités plus légères qu'un héros complet (sorts du jeu, effets d'Eden) : à remesurer avec 18-24 héros |
| **Atouts** | `core/autochess_data.gd` (`AUGMENTS` : 30, raretés Argent / Or / Éclat, `AUGMENT_REROLLS`, `icon` du jeu), `ui/autochess_augments.gd` | raretés, relance, cartes d'atout v2 (lot ACX-2), icônes `Boons.ICONS` | effets **d'unités** (plateau, or de l'Échiquier) : à peine 6 sur 30 ont un sens pour un héros |
| **Chacun pour soi** | `Combatant.ffa_id` / `set_ffa` / `ffa_foes` | un `ffa_id` **par équipe** suffit à rendre hostiles les autres équipes et amis ses équipiers | `ffa_foes` parcourt tout le groupe « ffa » : un héros d'une arène voit ceux des autres arènes (300 m) |
| **Butin scellé** | `core/royale_loot.gd` (`offer(tier, niveau, classe, équipement)`, `best`), `core/survivor_gear.gd` (`adopt`, 13 panoplies niv. 90) | les **enclumes** (1 pièce parmi 3, emplacements vides d'abord, panoplies 2 / 4) sans rien inventer | — |
| **Anneau, réanimation, bilan du BR** | `core/royale.gd` (`PHASES`, dégâts hors anneau), `RoyaleDirector._revive_*`, `ui/royale_results.gd`, HUD BRI1-3 | anneau qui se resserre, flèche de bord, fil des éliminations, bilan à chronologie | anneau de 512 m en minutes ; ici 22 m en secondes |
| **Règles par mode** | `core/mode_rules.gd` (profils), `core/modifiers.gd` (`heal_half`…), `Modes.sealed()` | profil « colisee » et **décrets** (règles de partie) par la table des modificateurs | `profile_name()` passe par `Duel.mode` : ajouter le mode |
| **Fin et récompenses scellées** | `core/autochess_rewards.gd` (`finish`), `ui/results_panel.gd` v2, `Quests.end_run` | coffres d'apparence plafonnés, titres, quêtes, bilan commun | — |
| **Choix de carte v2** | `ui/card_picker.gd` (rareté, relance, carte qui s'envole) | base du choix d'atout | **tient la pause** (`PAUSE_GROUP`) : en Colisée la préparation a un minuteur et 17 autres héros choisissent en même temps |

Captures regardées (`C:\AI\benchmark_refs\arena\eden_slash_0.1.284\`, 24 images `m7_*`, 1600 × 900, copie propre de HEAD) :
- **Page Arènes** (`m7_10`) : déjà sur papier v2 (panneau crème, image d'amphithéâtre peinte, « Lancer l'arène » soleil), mais boutons de
  choix en puits d'encre serrés, pastilles « Donne » à carrés noirs, rubrique « Premier adversaire » vide au-dessus du bouton.
- **Combat 3v3** (`m7_21`) : HUD de run dans l'ancienne DA (panneaux bleu nuit à filet doré) ; équipes = **liste de 6 noms** en haut à
  gauche (bleu / rouge, barres fines, sans portrait) ; en haut au centre la barre de boss réemployée pour l'adversaire visé
  (« Chevalier · difficile ») ; mini-carte ronde ; **les télégraphes violets et les sorts couvrent un tiers de l'écran**, chiffres de
  dégâts très gros (« 381 »), statut « Cicatrice » écrit en rose au-dessus d'un héros : dans la mêlée on ne distingue plus son trio.
- **Fin de manche** (`m7_24`) : bandeau « Manche gagnée ! 1 - 0 » lisible ; la liste des équipes devient « Dégâts de la manche » (bon
  réemploi) ; le joueur mort à « VIE 0 » alors que son équipe gagne (cohérent mais aucune mise en scène de la victoire d'équipe).
- **Bilan** (`m7_25`) : `ResultsPanel` v2 papier, « VICTOIRE ! » soleil, 5 tuiles d'encre dont **« 4 % plus gros coup »** et **« 3 % plus
  gros coup reçu »** (pourcentage dans le texte permanent : contraire à la BIBLE §12), Gagné / Gardé, « Nouvelle équipe adverse » primaire.
- File d'attente du Duel (`m7_13`-`16`) : recherche, match trouvé, draft, récapitulatif. Le **draft** (`m7_15` : minuteur 60 s en grand
  chiffre + barre, préréglage de sorts reconnu « 4 / 4 cases », état de l'adversaire « …prépare son héros ») est le meilleur patron existant
  pour la préparation chronométrée du Colisée, mais il est encore dans l'ancienne DA (fenêtre bleu nuit) et garde le mot « Draft ».

---

## 4. Écarts

### 4.1 Écran par écran (nos Arènes / Échiquier / BR contre les références)

| Écran | Nous (observé) | Elles font mieux | On fait mieux | Écart pour le Colisée |
|---|---|---|---|---|
| **Entrée** | page Arènes : 2v2 ou 3v3, difficulté, niveau ; conditions du Duel | LoL : sélection avec bannissements, « au hasard » récompensé | équipes IA réglables, familles différentes | P0 : page Colisée (format, difficulté, classe, alliés proposés) |
| **Préparation** | aucune (Arènes : 4 s de tableau puis manche suivante) ; Échiquier : préparation complète mais propre aux unités | LoL : 45 s, mannequin, tout se fait sur la carte ; Stadium : Armurerie à onglets, revente | — | **P0** : écran de préparation (or, enclumes, atout, sorts, Prêt), ≤ 30 % de l'écran |
| **Classement** | aucun en Arènes ; Échiquier : colonne des 8 stratèges (PV, frise des 6 manches) | LoL : PV des équipes, prochain adversaire | frise des manches de l'Échiquier (réutilisable) | **P0** : colonne des 6 équipes (blason, PV, prochain) |
| **Combat : cadre** | Arènes (`m7_21`) : liste de 6 noms à barres fines en haut à gauche (ancienne DA), barre de boss réemployée pour l'adversaire visé, mini-carte | LoL / Knockout : peu d'éléments, anneau très visible ; LoL : vignettes des autres arènes après son combat | tableau de manche dégâts / reçus / K.O. (M7) | P0 : barres d'équipe en haut, anneau de feu lisible, « Feu · 4 s » ; P1 : vignettes « Ailleurs » |
| **Combat : héros** | noms au-dessus des héros (« Cicatrice », « Saignement » en rouge = statuts) et chiffres très gros (« 35 ! ») sur un sol orange saturé : on perd sa propre équipe dans la mêlée | BR / Échiquier v2 : barres courtes pomme / fraise, noms au survol | vrais sorts du jeu, esquives lues par l'IA | **P0** : barres pomme (toi + alliés) / fraise (adversaires), noms au survol, statuts en icônes |
| **Héros à terre** | caméra sur un allié debout, message « Tu es tombé : tes alliés se battent encore ! » | LoL : relève par l'allié (zone qui se remplit) | caméra qui suit un allié (M7) | P1 : relève (cercle pomme qui se remplit) |
| **Fin de manche** | message 2 s + tableau 4 s | LoL : résultat, puis on regarde les autres combats | MVP / tableau | P0 : bandeau non bloquant « Manche gagnée · Fraises −25 » + PV des équipes qui bougent |
| **Atout** | Échiquier : 3 cartes v2 à rareté, relance 1 / choix | LoL : relances communes à la partie, choix au hasard en fin de temps ; Duels : offres cohérentes avec la classe | icônes du jeu, phrase sans pourcentage | **P0** : atouts de héros (30), offres notées selon la classe et le trio |
| **Élimination** | Arènes : « DÉFAITE… » puis bilan ; BR : bilan à chronologie | LoL : on reste regarder ou on part | — | P0 : annonce « Mandarines éliminés · 6e » ; P1 : spectateur |
| **Fin de partie** | `ResultsPanel` v2 commun (`m7_25`) ; tuiles « 4 % plus gros coup » (pourcentage permanent, à corriger aussi dans les Arènes) | LoL : places, « victoire » si moitié haute | coffres révélés, « Ce qui t'a battu » (Survie) | P0 : place sur 6, classement, ton trio et ses atouts, coffres, titres |

### 4.2 Mécanismes

| Mécanisme | Nous | Références | À faire |
|---|---|---|---|
| Plusieurs équipes, appariement tournant, exempt | non (Échiquier : appariement de 8 stratèges, fantôme si impair) | LoL | machine de partie `Colisee` (P0) ; l'exempt combat des **Spectres** (copie d'une équipe éliminée) sans enjeu de PV, pour l'or (P1, idée TFT) |
| PV d'équipe et barème croissant | non (Arènes : 2 manches gagnantes) | LoL : 100 PV, 15 → 100 | barème court (§6.3), fin garantie à la manche 12 |
| Anneau de feu de manche | mort subite par dégâts croissants (`PvpCaps`) ; anneau du BR (minutes) | LoL (30 s), Knockout (poison), Battlerite (brume) | anneau 22 → 6 m en 4 à-coups (P0) |
| Atouts de héros | Échiquier (unités) ; cartes du Survivant (sorts, pièces) ; `Boons` (150 cartes de build) | LoL, Stadium (pouvoirs) | 30 atouts propres (§6.6), effets bâtis sur `Boons` / statuts / procs existants |
| Équipement de partie | BR : `RoyaleLoot`, cartes du Survivant | LoL : or + enclumes 1 parmi 3 ; Stadium : revente | enclumes (§6.7) sur `RoyaleLoot.offer` |
| Règle de partie votée | `Modifiers` (rangs héroïques, défi du jour) | LoL : invités d'honneur | décrets (P1, §6.8) |
| Relève | BR : retour automatique dans les 2 premières minutes | LoL : relève par l'allié, une par manche | P1 |
| Spectateur | caméra sur un allié | LoL : autres arènes | P1 (vignettes + clic) |
| IA d'équipe | `ClassRival` par héros | (humains chez elles) | **chef d'équipe** (P0) : cible commune, formation, anneau ; P1 : relève, protection du soigneur, combos |
| Durée | Arènes : 3 à 5 min ; Échiquier : 22,7-29,6 min | LoL : 20-35 min (estimations), cible 30 min | **≈ 19 min** (Classique), 12-14 min (Éclair) |
| Récompenses | Échiquier : coffres d'apparence, titres, quêtes | LoL : Renommée, médaillons | même patron que l'Échiquier ; rôle propre : titres et apparences de gladiateur (Q8) |

Ce qu'on fait **mieux** qu'elles et qu'il faut garder : IA à 4 difficultés réglable (aucune référence n'a un solo sérieux), pause
possible (jeu solo), vrais sorts d'Eden aux télégraphes lisibles, arène piégée déjà mesurée, tableau de manche à 3 colonnes, jeu entier
à la manette.

---

## 5. Le format : « 8 équipes de 3 » contre des formats plus petits

### 5.1 Durée estimée (simulation Monte-Carlo maison, 3 000 parties par case)
Modèle : force d'équipe tirée au hasard (écart-type 0,8, victoire logistique), appariement tournant sans revanche, exempt si impair,
PV d'équipe 100, préparation 30 s, transitions 8 s, **une manche dure autant que le plus long de ses combats simultanés** (on attend
les autres). Durée d'un combat : « mesurée » = R_M7 (74 s à 2, 88 s à 3, coupée à 140 s) ; « cible v2 » = anneau de feu dès 25 s
(50 s à 2, 60 s à 3, fin forcée à 85 s). Barème « court » = 20 / 25 / 35 / 50 / 100 (§6.3). Script : hors dépôt (`arena_formats.py`
dans le dossier de travail de la session ; à reprendre en vrai outil au lot CO-J).

| Format | Héros | Combats en même temps | Manches (méd. / p90) | Partie, combats mesurés (méd.) | **Partie, combats v2 (méd., p10-p90)** | Attente par manche | Joueur moyen : temps joué (méd.) | 1re place d'une équipe moyenne |
|---|---|---|---|---|---|---|---|---|
| 4 × 3 | 12 | 2 | 9 / 10 | 21,2 min | **16,2 (13,9-18,2)** | 5 s | 14,3 min | 18 % |
| 6 × 2 | 12 | 3 | 10 / 11 | 21,8 | 16,8 (15,3-18,6) | 7 s | 13,4 | 7 % |
| **6 × 3** | **18** | **3** | **10 / 11** | 24,5 | **18,6 (16,9-20,4)** | 8 s | 14,8 | 7 % |
| 8 × 2 | 16 | 4 | 11 / 12 | 23,8 | 18,3 (16,7-19,9) | 9 s | 13,6 | 4 % |
| 8 × 3 | 24 | 4 | 11 / 12 | 26,8 | 20,2 (18,4-21,9) | 10 s | 15,0 | 4 % |

Avec le barème de LoL (15 → 100 en 17 manches) : 6 × 3 = 23,3 min, 8 × 3 = 25,1 min (combats v2) ; 30,6 et 33,2 min avec les combats
d'aujourd'hui. **Ce qui fait la durée, c'est la longueur d'un combat, pas le nombre d'équipes** : passer de 6 à 8 équipes coûte une
manche et ≈ 1,6 min ; raccourcir un combat de 88 à 60 s en gagne 6.

### 5.2 Ce que 8 × 3 coûte vraiment
1. **Performances** : 24 héros complets (modèle, tenue, arme, sorts d'Eden, télégraphes), dont 18 hors de vue. Référence la plus proche :
   80 unités dérivées de `ClassRival` à 6 ms d'image physique médiane (R_AC_E), mais avec des effets simplifiés ; un héros du Colisée
   lance les vrais sorts. **Non mesuré.** Chargement : 18-48 ms par modèle (R_AC_E) → jusqu'à 1,2 s pour 24 héros (à précharger).
2. **Lisibilité** : 8 lignes d'équipe × 3 portraits = 24 visages dans la colonne de droite, 4 vignettes « Ailleurs » ; à 6 équipes, la
   colonne tient en 430 px à 1600 × 900 (croquis `v2_preparation.svg`).
3. **Identité des équipes** : la BIBLE a **six** bonbons (soleil, mandarine, pomme, lagon, améthyste, fraise) ; 8 équipes demandent
   2 couleurs hors palette ou des motifs. 6 équipes = une couleur de bonbon chacune.
4. **Poids du joueur** : il est 1 héros sur 24 ; une équipe moyenne finit 1re 4 fois sur 100 (contre 7 à 6 équipes, 18 à 4) ; la
   « victoire » (moitié haute) reste à 50 % dans tous les formats.
5. **Ce que Riot a fait** : 8 × 2 puis, en passant aux trios, **6 × 3** (18 joueurs). Pas de 8 × 3 connu (vérifié : historique du wiki,
   presse 2026).

### 5.3 Recommandation
- **Classique = 6 équipes de 3** (défaut) : ≈ 19 min, 3 combats simultanés, une couleur par équipe, trios tank / dégâts / soutien que
  `Duel.team_classes` sait déjà composer.
- **Éclair = 4 équipes de 3** : 12-16 min, pour une soirée courte (même jeu, barème plus raide : 25 / 35 / 50 / 100).
- **Grand tournoi = 8 équipes de 3** : **gardé**, mais seulement après la sonde de performances du lot CO-C (critères : image médiane
  ≤ 8 ms et p95 ≤ 16 ms avec 24 héros en Hardcore, chargement < 1,5 s, sur le PC du joueur) ; sinon, il reste caché.
- Duos (6 × 2 ou 8 × 2) : P2, une fois le trio réglé (tout le code est le même, seul `TEAM_SIZE` change).

---

## 6. Spécification « version 2 » du Colisée

### 6.1 Identité
Activité **« Le Colisée »** dans la rangée Affrontements, ouverte **dès le départ** (mode scellé, comme l'Échiquier et le Survivant) ;
étiquette « Équipes », sous-titre « 6 trios, une seule couronne », gains « Apparences, titres ». Rôle unique (`gives`) : **titres et
apparences de gladiateur** (une collection propre au Colisée, voir Q8). Mode scellé : `Modes.sealed()` vrai (ni talents, ni certificats,
ni auras du compte) ; classes et apparences débloquées permises ; aucune sauvegarde du profil pendant la partie (comme le Battle royale).

### 6.2 Déroulé d'une partie Classique (≈ 19 min)
1. **Page du lobby** (`Lobby._menu_colisee`) : format (Classique / Éclair / Grand tournoi verrouillé « après mesure »), difficulté
   (Facile, Normal, Difficile, Hardcore, Mélange), ta classe (classes débloquées), tes alliés (**3 trios proposés** de familles
   complémentaires, ou « Au hasard »), Lancer. Bouton « Reprendre » : P2 (pas de sauvegarde en v1).
2. **Présentation** (8 s, pendant le préchargement des modèles) : les 6 blasons, ton trio, le décret de départ s'il y en a un.
3. **Manche n** :
   - **Préparation** 30 s (passe à 3 s quand les 3 héros de ton trio sont prêts ; les IA décident en 2-6 s) : or, enclumes, atout (manches
     1, 4, 7, 10), sorts (une place de plus aux manches 3 et 6), décret (vote aux manches 2 et 7). Le tirage de la manche est **connu dès
     le début** de la préparation (« prochain » en fraise dans le classement).
   - **Combat** : 3 s de compte à rebours (code du Duel), puis 3 contre 3 sur l'une des 6 arènes ; les autres combats se jouent en même
     temps, cachés (§6.10). Fin quand un trio est entièrement hors de combat (à terre non relevé compte comme hors de combat).
   - **Résultat** (bandeau 2,5 s, non bloquant) : « Manche gagnée · Fraises −25 » ; PV des équipes qui descendent dans le classement ;
     puis vignettes des combats encore en cours (cliquer = regarder, ×2 possible) jusqu'à la fin du plus long (85 s au plus).
4. **Éliminations** : annonce « Mandarines éliminés · 6e » (portrait qui se grise et tombe) ; quand il reste un nombre impair d'équipes,
   l'exempt affronte les **Spectres** (copie IA d'une équipe éliminée, sans perte de PV, or de victoire seulement) ; P1 (en P0 : exempt
   simple, la manche est regardée).
5. **Finale** quand 2 équipes restent (bannière « Finale ! ») ; la partie finit à la dernière équipe debout.
6. **Bilan** : place sur 6 ; **places 1 à 3 = « Victoire »** (moitié haute, comme LoL), 1re = confettis ; classement, ton trio et ses
   atouts, tuiles (manches gagnées-perdues, K.O., meilleur atout, « Battus par »), coffres révélés un à un, titres, Rejouer · Manche par
   manche · Menu principal (`arena_maquettes/v2_bilan.svg`).

### 6.3 Règles chiffrées (valeurs de départ, à mesurer au lot CO-J)
| Règle | Classique 6 × 3 | Éclair 4 × 3 | Source |
|---|---|---|---|
| PV d'équipe | 100 | 100 | LoL |
| Perte par manche perdue | 20 (manches 1-3), 25 (4-6), 35 (7-9), 50 (10-11), 100 (12+) | 25 (1-2), 35 (3-4), 50 (5-6), 100 (7+) | simulation §5.1 |
| Manches attendues | 10 (p90 : 11) | 8 | idem |
| Préparation | 30 s (3 s quand tout le trio est prêt) | 25 s | LoL (45 s pour 16 humains) |
| Combat | anneau dès 25 s, fin forcée 85 s | idem | LoL 30 s, Knockout |
| Égalité (85 s) | l'équipe qui garde le plus de PV en part gagne ; égalité exacte : les deux perdent la moitié du barème | idem | évite les nulles de LoL, lisible |
| Relève | 1 par équipe et par manche : à terre 10 s, l'allié se tient 3 s dans le cercle, retour à 30 % des PV, 1 s d'invulnérabilité | idem | LoL |
| Niveau des héros | fiche « à l'arme » niveau 60 (`duel_a`) + ce que donnent enclumes et atouts | idem | Duel A (manches 66-81 s à tout niveau) |
| Sorts | 4 au départ (préréglage de la classe ou automatique), 5e à la manche 3, 6e à la manche 6 (1 parmi 3 sorts de la classe) | 5e à la manche 2 | « Pouvoirs » de Stadium à manches fixes |
| Profil `ModeRules` « colisee » | `dmg_scale` ≈ 0,030 (à mesurer), soins × 0,5, `hit_cap` 0,15, `burst_cap` 0,35, pas d'acharnement (l'anneau le remplace), `pct_weight` 0,75 | idem | `PVP_A3`, `ROYALE` |

**Anneau de feu** : rayon 22 m (arène plate de 26 m du Duel) → 16 m à 25 s → 11 m à 40 s → 6 m à 55 s → 3 m à 70 s ; chaque
resserrement annoncé 4 s avant (« Feu · 4 s », prochain anneau en pointillés) et fait en 2 s ; hors de l'anneau : 5 % des PV max par
seconde, +2 % par seconde passée dehors (remis à zéro en rentrant), soins reçus divisés par deux. Dessin : bord net blanc 3 px + orange
mandarine, intérieur ≤ 35 % (BIBLE §10).

### 6.4 Arènes (6, une par combat ; `ProcMap.generate_colisee`)
Sol plat de 26 m de rayon (comme `generate_arena`), 4 piliers (couvert contre les tirs), 1 ou 2 **fleurs de vie** (soignent 15 % et
donnent un bouclier à qui marche dessus, repoussent en 20 s), une **particularité** chacune : Prairie (rien : l'arène d'apprentissage),
Ruines (deux piliers tombent à 45 s : zone rouge 1,5 s puis coup), Désert (bourrasques qui repoussent, télégraphe de ligne), Glace
(deux plaques glissantes), Volcan (geysers à télégraphe), Bosquet (deux buissons qui cachent les héros à distance ; P2 : demande une
règle de visibilité). Biomes et décors : ceux des zones du jeu (`GameData.zone(...).biome`), jamais de décor tiers. Les 6 arènes sont dans
le même monde à 300 m d'écart (comme les plateaux de l'Échiquier, `BOARD_SPACING`).

### 6.5 Économie de partie (scellée, remise à zéro à chaque partie)
- **Or** : 10 par manche, +3 si victoire, +2 par K.O. (6 au plus), +5 à l'exempt qui bat les Spectres ; **enclume Panoplie offerte**
  à la manche 3 et **enclume Éclat offerte** à la manche 9 (rythme des cadeaux de LoL).
- **Revente** d'une pièce au prix payé pendant la préparation où elle a été prise (Stadium), à moitié ensuite.
- Pas d'intérêts, pas de série : l'économie sert à **construire**, pas à épargner (l'Échiquier fait déjà l'économie fine).

### 6.6 Atouts (32 dont 1 de recette ; 3 raretés de l'Échiquier : Argent, Or, Éclat)
Offres aux manches 1 (Argent, ou Or 1 fois sur 3), 4 (Or), 7 (Or, ou Éclat 2 fois sur 5), 10 (Éclat) ; les **3 cartes d'une offre ont
la même rareté** (on choisit un style, pas une puissance) ; **3 relances pour la partie**, une relance change **une** carte ; 6 atouts au
plus (4 choix + recette + décret « Même atout pour tous ») ; si le temps manque : la carte la mieux notée pour ta classe (pas au hasard).
Offres **notées** comme les paquets de Duels : chaque atout a des étiquettes (`melee`, `ranged`, `healer`, `tank`, `sorts`, `equipe`)
et une note par rôle de classe ; on tire 3 atouts parmi les mieux notés, sans doublon de thème, avec du hasard. Effets bâtis sur ce qui
existe (`Boons` : stats `dmg_pct`, `area`, `reach`, `cdr`, `crit`… ; statuts ; procs ; boucliers de `Combatant`) ; textes : **une
phrase sans chiffre**, le détail chiffré en infobulle (`tip`), comme `AutochessData.AUGMENTS`.

| # | Nom | Rareté | Thème | Phrase (carte) | Détail (infobulle, valeurs de départ) |
|---|---|---|---|---|---|
| 1 | Lame affûtée | Argent | coups | Tes auto-attaques frappent plus fort. | +20 % de dégâts d'auto-attaque |
| 2 | Peau de chêne | Argent | survie | Tu as plus de PV. | +15 % de PV max |
| 3 | Pas léger | Argent | mobilité | Tu cours plus vite. | +12 % de vitesse de course |
| 4 | Concentration | Argent | sorts | Tes sorts reviennent plus vite. | −12 % de recharge |
| 5 | Première frappe | Argent | coups | Ton premier coup de la manche fait très mal. | 1er coup : +80 % |
| 6 | Sangsue | Argent | survie | Tes coups te soignent un peu. | vol de vie 6 % (plafond `lifesteal` du profil) |
| 7 | Bouclier d'entrée | Argent | survie | Tu commences chaque combat protégé. | bouclier de 15 % des PV pendant 6 s |
| 8 | Esquive agile | Argent | mobilité | Ton esquive revient plus vite. | recharge d'esquive −25 % |
| 9 | Tirelire | Argent | or | Plus d'or à chaque manche. | +4 or par manche |
| 10 | Main verte | Argent | arène | Les fleurs de vie te donnent plus. | fleurs : soin et bouclier ×2 pour toi |
| 11 | Écho | Or | sorts | Ton sort le plus long part deux fois. | 2e lancer 0,6 s après, à 50 % ; sorts de recharge ≥ 10 s |
| 12 | Serment | Or | équipe | Quand un allié tombe, tu es protégé. | bouclier de 25 % des PV, 5 s |
| 13 | Garde rapprochée | Or | équipe | Tes alliés proches prennent moins de coups. | alliés à 6 m : −10 % de dégâts reçus |
| 14 | Relève éclair | Or | équipe | Tu relèves un allié bien plus vite. | relève 3 s → 1,2 s, relevé à 50 % des PV |
| 15 | Chasseur de têtes | Or | coups | Mettre un héros K.O. recharge tes sorts. | K.O. ou aide : −50 % de la recharge restante |
| 16 | Coup de grâce | Or | coups | Tes coups achèvent les héros presque à terre. | cible sous 10 % des PV : K.O. (pas les boucliers) |
| 17 | Contre-coup | Or | mobilité | Esquiver un coup lance une riposte. | esquive réussie : frappe de 60 % de l'auto-attaque |
| 18 | Ronces | Or | survie | Qui te frappe au corps à corps se blesse. | renvoie 15 % des dégâts de mêlée reçus |
| 19 | Marque du chasseur | Or | équipe | Ta cible prend plus de coups de tes alliés. | ta cible : +12 % de dégâts reçus de ton trio, 4 s |
| 20 | Ancre | Or | survie | Plus personne ne te pousse ni ne t'attire. | insensible aux repoussements et attractions |
| 21 | Braise | Or | recette | Tes coups brûlent. | brûlure 3 s ; 1/3 de « Tempête » |
| 22 | Givre | Or | recette | Tes coups ralentissent. | ralenti 25 %, 1,5 s ; 1/3 de « Tempête » |
| 23 | Foudre | Or | recette | Tes coups sautent sur un voisin. | rebond à 40 % sur un héros à 4 m ; 1/3 de « Tempête » |
| 24 | Mise | Or | or | Gagne la manche : beaucoup d'or. Perds-la : rien. | victoire +15 or, défaite 0 or de manche |
| 25 | Tempête | Éclat | recette | Braise, Givre et Foudre fusionnent. | remplace les trois ; tous leurs effets ×1,5, libère 2 places |
| 26 | Deuxième souffle | Éclat | survie | Une fois par manche, tu survis à un coup mortel. | reste à 1 PV, invulnérable 1 s |
| 27 | Colosse | Éclat | survie | Tu deviens immense et très solide, mais plus lent. | +40 % PV, taille ×1,3, −10 % de vitesse |
| 28 | Maître des sorts | Éclat | sorts | Une place de sort de plus. | 7e sort au choix parmi 3 |
| 29 | Ombre jumelle | Éclat | coups | Un double de toi se bat au début du combat. | double à 40 % de tes PV et dégâts, 10 s |
| 30 | Trio parfait | Éclat | équipe | Trois familles différentes : tout le trio s'en trouve plus fort. | +10 % de dégâts et PV à ton trio si 3 familles |
| 31 | Roi de l'arène | Éclat | arène | Tenir le centre te rend plus fort peu à peu. | à 5 m du centre : +3 % de dégâts par seconde, 30 % au plus |
| 32 | Pacte de sang | Éclat | risque | Ton équipe perd des PV, tu frappes beaucoup plus fort. | −15 PV d'équipe tout de suite ; +25 % de dégâts |

Garde-fous : aucun atout ne touche aux plafonds du profil (`caps` de `PvpCaps`) au-delà de ce qu'ils permettent ; « Coup de grâce » et
« Deuxième souffle » ne se cumulent pas sur une même cible dans la même seconde ; « Pacte de sang » interdit sous 30 PV d'équipe.
Mesure (CO-J) : chaque atout entre 40 et 60 % de « moitié haute » relative, comme le contrôle d'AC-J.

### 6.7 Enclumes (1 pièce parmi 3)
| Enclume | Prix | Ce qu'elle propose | Code réutilisé |
|---|---|---|---|
| Stat | 6 or | 3 bonus de stat (PV, attaque, vitesse d'attaque, recharge, critique, défense) tirés selon la classe | `Boons` (stats), `ClassGear` (profil de stats de la classe) |
| Pièce | 12 or | 3 pièces pour un **emplacement vide d'abord**, sinon une amélioration | `RoyaleLoot.offer(tier, niveau, classe, équipement)` |
| Panoplie | 20 or | 3 pièces d'une panoplie que tu portes déjà (bonus 2 / 4) | `SurvivorGear` (13 panoplies niveau 90), `Items.SETS` |
| Éclat (offerte manche 9) | — | 3 pièces légendaires de ta classe | `RoyaleLoot.offer` palier 3 |
Les IA achètent par `RoyaleLoot.best` (déjà mesuré pour le Battle royale, BR3) avec une préférence de rôle.

### 6.8 Décrets (vote aux manches 2 et 7 ; table `Modifiers` étendue)
Trois décrets proposés, 15 s de vote (chaque héros vote ; les IA selon leur rôle : un soigneur ne vote pas « Soins rares ») ; un votant
tiré au sort décide (règle de LoL). Liste de départ (10) : **Fleurs de vie** (deux fois plus de fleurs), **Pluie d'or** (+5 or par
manche pour tous), **Arène piégée** (zones de feu violettes, `DuelDirector._hazard_tick`), **Seconde chance** (la 1re élimination de
chaque équipe la laisse à 1 PV), **Même atout pour tous** (un atout tiré au sort donné à chacun), **Vent du large** (bourrasques dans
toutes les arènes), **Feu précoce** (anneau 10 s plus tôt), **Enclumes bénies** (enclumes −30 %), **Soins rares** (`heal_half`),
**Champions** (le MVP de chaque manche gagne +1 or par manche, cumulable). Bannière manga 1 s à l'adoption, rappel en pied de la frise.

### 6.9 IA : « joue très bien », scriptée, 4 difficultés
Deux étages :
1. **Héros** = `ClassRival` en équipe (déjà : cible le plus faible, esquive des zones rouges de tous, retraite, soutien), généralisé :
   équipiers par `ffa_id` d'équipe (aujourd'hui `_teammates()` rend « soi seul » en chacun pour soi), cibles **de son arène seulement**,
   lecture des coups de tous les héros ennemis (aujourd'hui `_threat` ne lit que le joueur ; les zones rouges des autres sont déjà lues).
2. **Chef d'équipe** (`ai/colisee_team_brain.gd`, nouveau, une décision toutes les 0,25 s) : **cible commune** (soigneur > tireur > mêlée
   isolée, PV effectifs, distance ; garde la cible tant qu'elle est prenable), **formation** (le tank devant, tireurs et soigneur 5-7 m
   derrière, regroupement 2 s au départ), **anneau** (se recentre 3 s avant chaque resserrement), **couvert** (le soigneur se met derrière un
   pilier face à un tireur), **protection** (si le soigneur est attaqué, la mêlée change de cible), **relève** (si aucun ennemi à 6 m ou
   s'il reste plus de PV à l'équipe), **combos** (Hardcore : contrôle d'un allié → toute l'équipe frappe la cible contrôlée), **fleurs**
   (le plus bas en PV y va si la voie est libre).
3. **Choix** : atouts (note par rôle + synergie du trio + bruit selon la difficulté), enclumes (`RoyaleLoot.best`), sorts de manche 3 / 6,
   votes.

| Difficulté | Héros (`ClassRival.DIFF`) | Chef d'équipe | Choix | But mesuré (CO-J) |
|---|---|---|---|---|
| Facile | Facile | aucun (chacun le plus proche) | au hasard parmi les 3 | joueur moyen 1er ≥ 40 % |
| Normal | Normal | cible commune | note simple | 1er ≈ 20 % |
| Difficile | Difficile | tout sauf combos | note + synergie | 1er ≈ 12 % |
| Hardcore | Hardcore | tout | note + synergie, sans bruit | trio Hardcore contre trio Normal : ≥ 85 % de manches gagnées |
| Mélange | difficultés mêlées par équipe (`Royale.MIX`) | selon l'équipe | selon l'équipe | — |
Les alliés du joueur ont la difficulté choisie (comme les Arènes, R_M7) ; le joueur garde la main sur ses propres choix.

### 6.10 Combats simultanés et spectateur
Patron de `AutochessDirector` : tous les combats de la manche sont **joués pour de vrai** (même code, mêmes IA), seul celui du joueur est
rendu ; les autres : modèles cachés, animations arrêtées, ni effets, ni chiffres, ni sons, télégraphes logiques sans dessin. Repli si une
image dépasse 20 ms pendant 1 s : décisions des IA cachées toutes les 3 images, puis, en dernier recours, **résolution au tableau** du combat
caché (PV restants et `Royale.power_ratio`), notée dans le journal de partie. Spectateur : après ton combat (ou K.O. de ton trio), les
vignettes « Ailleurs » deviennent cliquables (et LB / RB à la manette) ; le combat regardé est rendu, les autres repassent cachés ;
vitesse ×2 possible quand ton trio n'est plus en jeu.

### 6.11 Écrans (DA v2 ; croquis `arena_maquettes/`)
- **Page du lobby** (`v2_page_lobby.svg`) : image du jeu en tête, « Le Colisée » + étiquette « 6 trios · 1 couronne », pastilles Donne,
  Format (Classique / Éclair / Grand tournoi verrouillé), Adversaires (5 difficultés), Ton héros (classe, préréglage de sorts), Tes alliés
  (2 trios proposés + Au hasard), bouton primaire « Entrer au Colisée ».
- **Préparation** (`v2_preparation.svg`) : le monde reste visible (ta plateforme au bord de ton arène, mannequin d'essai) ; à gauche
  « Ton trio » (portrait, classe, famille, atouts en pastilles, état « choisit… / ✔ prêt ») ; en haut au centre la **frise de partie**
  (pictos : ● combat gagné / perdu, ★ atout, ◆ décret ; « Manche 4 · Préparation » ; minuteur) ; à droite **6 équipes** (blason bonbon,
  nom, barre de PV d'équipe épaisse, « prochain » en tampon fraise, éliminés tramés avec leur place) ; en bas le **pied** (or en
  autocollant soleil, 3 enclumes à prix en pastille, barre de sorts avec la place qui s'ouvre, **Prêt** primaire soleil). Survol d'une
  équipe : trio, atouts, deux derniers combats.
- **Choix d'atout** (`v2_choix_atout.svg`) : fond flou (UIK2), titre Mochiy incliné, 3 cartes 320 × 420 à bandeau de rareté, icône du
  jeu 100 px, nom, **une phrase**, ligne « Va bien avec : … » ; survol : la carte monte, détail chiffré ; Relancer · n (X), Voir mon
  trio (Y) ; bandeau des choix des alliés IA (« Chevalier a pris … »). **Ne tient pas la pause** (17 autres héros choisissent).
- **Combat** (`v2_combat_hud.svg`) : en haut barres d'équipe (toi à gauche, adversaire à droite, chrono, « Feu · 4 s ») ; à gauche les
  atouts tenus ; à droite « Ailleurs » (vignettes des autres combats) ; en bas la barre de sorts existante ; au-dessus des héros des
  barres courtes **pomme** (toi et tes alliés) / **fraise** (adversaires), **aucun nom** (survol : bulle) ; anneau de feu blanc net +
  orange, prochain anneau en pointillés ; relève = cercle pomme qui se remplit ; onomatopées sur événement (« Double K.O. ! »).
- **Bilan** (`v2_bilan.svg`) : `ResultsPanel` v2 ; « 2e · Victoire ! » en Mochiy 56 sur rayons ; classement des 6 avec les trios ;
  « Ton trio » (héros, atouts, MVP) ; tuiles ; coffres révélés un à un ; titre gagné en autocollant ; Rejouer (primaire) · Manche par
  manche · Menu principal.
- Moments (son + mouvement, BIBLE §7-8) : bannière « Manche 4 » et « Combat ! », « Finale ! », élimination d'une équipe (portrait qui
  tombe, son sourd), atout pris (carte qui file vers la colonne du trio), recette « Tempête » (éclat améthyste), victoire de manche
  (pomme) / défaite (fraise douce), relève (carillon montant).

### 6.12 Confort (liste de contrôle)
1. **Pause** à tout moment (jeu solo : tous les combats s'arrêtent) ; vitesse ×2 du spectateur.
2. Préparation qui **finit seule** quand le trio est prêt ; réglage « Préparation sans minuteur » (comme l'Échiquier, P1).
3. **Revente** au prix payé pendant la préparation ; aucun achat définitif par erreur.
4. Sorts du départ = **préréglage** de la classe (`SpellPresets`) ou automatique ; atout au temps écoulé = le mieux noté (jamais au hasard).
5. Tirage connu d'avance, survol des équipes, **« Battus par »** au bilan, **« Manche par manche »** (frise détaillée).
6. Les IA alliées montrent leurs choix ; P2 : « Lui conseiller » un atout / une pièce.
7. Manette partout (`UiNav` : un écran fait de boutons est navigable seul) ; touches dessinées en pastilles ; textes ≥ 15 px ; aucun
   pourcentage dans le texte permanent.
8. Premiers pas : 3 fiches (`co_trio` « Ton trio », `co_atouts` « Les atouts », `co_feu` « L'anneau de feu »), une à la fois.
9. Option P2 **« Mêlée finale »** : à 3 équipes restantes, une manche chacun-pour-soi-par-équipe sur une grande arène (la lecture « Overthrow »
   de « plusieurs équipes sur une arène ») ; à n'essayer qu'une fois le reste mesuré.

### 6.13 Récompenses (cosmétiques seulement)
Fin : `ColiseeRewards.finish` sur le patron d'`AutochessRewards.finish` (hub remis comme le Survivant) : **coffres d'apparence plafonnés**
(1re place : 2 coffres dont un rare ou mieux ; 2e-3e : 1 coffre ; 1re partie du jour : +1 commun), **titres** (« Gladiateur » : 1re
moitié haute ; « Champion du Colisée » : 1re place ; « Sans faute » : 1re place sans manche perdue ; « Trio de choc » : 1re place en
Hardcore ; « Maître des tempêtes » : 5 recettes réussies), `Quests.end_run("colisee", gagné, {place, format, difficulté})`. Rien
d'autre : ni insignes, ni maîtrise, ni équipement, ni niveau de héros.

### 6.14 Réutilisation du code (ce qui existe → ce qu'on en fait)
| Existant | Usage |
|---|---|
| `DuelDirector` (`_spawn_team`, compte à rebours, `_hazard_tick`, `_note_ko`, `_follow_ally`) | patron du combat d'une arène ; l'arène piégée devient un décret |
| `Duel.make_ally` / `make_extra` / `team_classes` / `rival_sheet` | création des 17 héros IA à la fiche d'un héros, trios de familles différentes |
| `ClassRival` (équipe M7) | héros IA (généralisé, §6.9) |
| `AutochessDirector` (`BOARD_SPACING`, `watch`, `fallback_ms`, `prepare`) | combats simultanés cachés, préchargement |
| `Autochess` (machine d'étapes sans scène, appariement) | patron de `core/colisee.gd` (testable sans rendu) |
| `AutochessData.AUGMENTS` (format), `ui/autochess_augments.gd`, `CardPicker` v2 | format des atouts, cartes à rareté |
| `RoyaleLoot`, `SurvivorGear`, `Items.SETS` | enclumes et panoplies |
| `Royale.PHASES` (dégâts hors anneau), mur `RoyaleDirector._wall` | anneau de feu de manche |
| `Royale.power_ratio`, `AutochessDirector.data_fight` | repli « au tableau » |
| `Combatant.ffa_id` / `set_ffa` | hostilité par équipe (un id par trio) |
| `Modifiers` | décrets |
| `ModeRules` | profil « colisee » |
| `TeamBars`, frise des stratèges de l'Échiquier, `ResultsPanel`, `AutochessRewards`, `Quests.end_run` | HUD, classement, bilan, récompenses |

### 6.15 Pièges techniques (à lire avant le premier lot)
1. **État statique partagé** : `Duel` (≈ 30 variables statiques) et `PvpCaps` (`elapsed`, `board`) supposent un seul combat. Le Colisée a
   son propre état (`Colisee`) et **ne met jamais `Duel.active`** ; `PvpCaps.elapsed` global reste juste **parce que tous les combats
   d'une manche partent ensemble**, à condition de ne jamais lancer une arène en retard.
2. **Drapeaux de mode éparpillés** : 40 lectures de `Duel.active` et 69 de `Royale.active` dans `game/scripts` (HUD, pause, journal,
   chiffres de dégâts, objets, `Player`…). Ajouter `Colisee.active` à `Modes.current()`, `Modes.is_pvp()`, `Modes.sealed()`,
   `ModeRules.profile_name()` puis **auditer chaque lecture** (lot CO-A : liste dans le rapport).
3. **Cibles hors de l'arène** : `Combatant.ffa_foes` parcourt tout le groupe « ffa » ; à 300 m, `pick_target` finit par viser un héros
   d'une autre arène quand la sienne est vide. Filtre d'arène obligatoire (groupe par arène ou méta `co_arena`), idem pour `_read_zones`
   (télégraphes) et les sorts de zone.
4. **Équipiers** : `ClassRival._teammates()` rend `[self]` si `ffa_id >= 0` ; `_team_mode()` lit `Duel.team_mode()`. À généraliser
   sans changer le Battle royale (test `test_royale`, `test_br*`).
5. **Lecture des coups** : `ClassRival._threat` ne lit que le `Player` ; entre IA, seules les zones rouges sont lues. Suffisant pour les
   combats cachés, mais l'écart de niveau entre « combat du joueur » et « combats cachés » doit être mesuré (CO-J).
6. **Combats cachés** : couper effets (`EdenFx`), chiffres (`DamageNumber`), sons, secousses, alertes du HUD et vibrations pour les arènes
   non regardées (même liste qu'AC-E) ; sinon le joueur entend les 3 combats.
7. **Choix de carte et pause** : `CardPicker` tient la pause (`PAUSE_GROUP`) ; en préparation chronométrée il faut un mode qui ne la tient pas.
8. **Chargement** : 18-24 modèles (corps, tenue, arme) : 18-48 ms chacun (R_AC_E) → précharger pendant la présentation
   (`ResourceLoader.load_threaded_request`), comme `AutochessDirector.prepare`.
9. **Carte** : un `ProcMap` lance la navigation sur un fil du moteur : un test qui génère le Colisée attend `navigation_mesh != null`
   avant `quit()` (piège T1 de CLAUDE.md).
10. **Mort du joueur** : `world.gd` route la mort vers le directeur du mode (`player_down`) ; « à terre » (relève) est un nouvel état
    qui ne doit pas déclencher le bilan ; la caméra suit un allié (`_follow_ally`).
11. **Couleurs** : 6 équipes = 6 bonbons, mais pomme / fraise ont un sens (gain / danger) : les **barres** restent pomme (amis) / fraise
    (ennemis) quelle que soit la couleur d'équipe ; la couleur d'équipe ne sert qu'au blason et au classement.
12. **Textes** : ni « lobby » ni « % » dans le texte permanent (`test_texts_fr`) ; noms d'atouts nouveaux dans les tables françaises si besoin.

### 6.16 Performances (budget et mesure)
| Poste | Estimation | Comment le tenir |
|---|---|---|
| IA de 18 héros (24 en Grand tournoi) | `ClassRival` complet : non mesuré à ce nombre ; 80 unités dérivées = 6 ms médian (R_AC_E) | IA cachées : décision toutes les 3 images ; filtres d'arène (moins de cibles à trier) |
| Rendu | 6 héros visibles (comme un 3v3 d'Arènes aujourd'hui) | arènes cachées : `visible = false`, animations arrêtées |
| Effets / chiffres / sons | ceux d'un seul combat | coupés hors du combat regardé |
| Chargement | 18-48 ms par modèle | préchargement pendant présentation + préparation |
| Mémoire | 18-24 classes différentes chargées | trios tirés parmi les classes déjà en cache d'abord (option) |
Sonde (lot CO-C) : `tools/colisee_probe.tscn` (`--teams=6|8 --size=3 --diff=3 --seconds=90`), lignes `[colisee] image` (médiane, p95,
max par poste) ; critères : médiane ≤ 8 ms, p95 ≤ 16 ms, chargement < 1,5 s ; résultats dans le rapport du lot et dans `tests/co_mesures.json`.

---

## 7. Backlog priorisé

Tailles : **S** ≤ 1 jour d'agent, **M** 2-3, **L** 4 et plus (même échelle qu'`AUTOCHESS.md`). Fichiers sous `game/scripts/`.
Chaque lot : BIBLE v2 + `UiTheme` / `UiFeel`, captures regardées, `test_nav_screens`, `test_texts_fr`, `python tools/check_scripts.py`.

| # | P | Élément | Taille | Fichiers | Acceptation |
|---|---|---|---|---|---|
| 1 | P0 | **Socle du mode** : `Colisee` (état statique, formats, barème, appariement tournant, exempt, élimination, places), `Modes` / `ModeRules` (profil « colisee ») / `sealed` / `is_pvp`, audit des 109 lectures de `Duel.active` / `Royale.active` | L | `core/colisee.gd` (nouveau), `core/modes.gd`, `core/mode_rules.gd`, `combat/pvp_caps.gd`, sites audités | `test_co_rules` : 1 000 parties « au tableau » sans scène, fin ≤ manche 12, places uniques, pas deux fois le même adversaire avant d'avoir vu tous les autres |
| 2 | P0 | **Carte du Colisée** : 6 arènes à 300 m, piliers, fleurs de vie, anneau de feu de manche | M | `world/proc_map.gd` (`generate_colisee`), `world/colisee_ring.gd` (nouveau), `core/world.gd` | `test_co_map` (attend la navigation) ; captures des 6 arènes |
| 3 | P0 | **Directeur de combat** : 3 combats simultanés, `ffa_id` par trio, filtre d'arène, combats cachés (patron AC-E), compte à rebours, égalité à 85 s, mort du joueur → caméra sur un allié | L | `core/colisee_director.gd` (nouveau), `combat/combatant.gd` (filtre), `ai/class_rival.gd` (`_teammates`, `_team_mode`), `core/world.gd` | `test_co_fight` : 3 combats finissent, aucun coup entre arènes ; `test_royale`, `test_m7` toujours verts |
| 4 | P0 | **Sonde de performances** 18 et 24 héros | S | `tools/colisee_probe.tscn` | mesures dans le rapport ; décision Grand tournoi |
| 5 | P0 | **Chef d'équipe** (cible commune, formation, anneau) + choix IA simples | L | `ai/colisee_team_brain.gd` (nouveau), `ai/class_rival.gd` | banc `tools/colisee_ai_bench.tscn` : trio Difficile avec chef contre sans chef ≥ 70 % |
| 6 | P0 | **Atouts de héros** : 32 (données, effets, offres notées, relances, 6 au plus) | L | `core/colisee_data.gd` (réglages + `AUGMENTS`), `core/colisee_augments.gd` (effets sur `Boons` / statuts / boucliers) | `test_co_augments` : chaque effet vérifié sur un mannequin ; aucune offre incohérente (soin à un non-soigneur) |
| 7 | P0 | **Enclumes et or** (Stat, Pièce, Panoplie, Éclat offerte), revente | M | `core/colisee_shop.gd` (nouveau, sur `RoyaleLoot` / `SurvivorGear`) | test : emplacements vides d'abord, revente au prix payé |
| 8 | P0 | **Interface** : page du lobby, préparation (trio, frise, 6 équipes, pied), choix d'atout v2 sans pause, HUD de combat (barres d'équipe, anneau, « Feu · n s »), barres pomme / fraise sans nom, bandeau de résultat, annonces d'élimination | L | `ui/colisee_screen.gd`, `ui/colisee_prep.gd`, `ui/colisee_teams.gd`, `ui/colisee_augments.gd`, `ui/lobby.gd`, `ui/activities.gd` (+ image), `ui/card_picker.gd` (mode sans pause) | `shot_co.tscn` 1280 × 720 et 1600 × 900 sans débord ; `test_co_ui` |
| 9 | P0 | **Fin et récompenses** : bilan `ResultsPanel` v2, `ColiseeRewards.finish`, titres, quêtes, `QuestPool.ACTS`, `ResourceHelp`, `Compass` (rien : scellé) | M | `ui/colisee_results.gd`, `core/colisee_rewards.gd`, `core/quests.gd`, `core/quest_pool.gd` | `test_co_rewards` ; hub intact après la partie (comme `test_ac_rewards`) |
| 10 | P0 | **Mesure et calibrage** : parties entre IA, durée, barème, `dmg_scale`, équilibre des atouts et des classes | M | `tools/colisee_games.tscn`, `tools/colisee_report.py`, `tests/co_mesures.json` | médiane 17-21 min (Classique) ; manche médiane 50-65 s ; atouts 40-60 % de moitié haute ; aucune classe > 2 × sa part de 1res places |
| 11 | P1 | **Relève** (à terre, cercle, une par manche ; IA qui relève) | M | `core/colisee_director.gd`, `player/player.gd`, `ai/colisee_team_brain.gd` | test : relève puis K.O. = manche perdue au 2e K.O. |
| 12 | P1 | **Spectateur** : vignettes « Ailleurs », clic / LB-RB, ×2 | M | `ui/colisee_screen.gd`, `core/colisee_director.gd` (`watch`) | test nav ; un seul combat rendu à la fois |
| 13 | P1 | **Décrets** (vote, 10 décrets) | M | `core/modifiers.gd` (clés), `core/colisee.gd`, `ui/colisee_vote.gd` | test : chaque décret change la clé visée |
| 14 | P1 | **Spectres** pour l'exempt | S | `core/colisee.gd`, `core/colisee_director.gd` | test : aucune perte de PV, or versé |
| 15 | P1 | Chef d'équipe Hardcore : protection du soigneur, couvert, combos de contrôle, fleurs | M | `ai/colisee_team_brain.gd` | banc : Hardcore contre Normal ≥ 85 % |
| 16 | P1 | **Moments manga et sons** (bannières, élimination, recette, relève, finale), vibrations | M | `ui/colisee_screen.gd`, `core/ui_feel.gd`, `combat/sfx.gd` | « Réduire les animations » respecté |
| 17 | P1 | Premiers pas (3 fiches), Guide F1, « Manche par manche » au bilan | S | `core/tutorial.gd`, `ui/guide.gd`, `ui/colisee_results.gd` | `test_lot9` ; Guide F1 regardé en capture |
| 18 | P1 | Format **Éclair** (4 × 3) | S | `core/colisee_data.gd`, `ui/lobby.gd` | mesure : médiane 12-16 min |
| 19 | P2 | **Grand tournoi** 8 × 3 (si la sonde passe) | M | `core/colisee_data.gd`, `ui/colisee_teams.gd` (colonne compacte), couleurs à motifs | critères §6.16 sur le PC du joueur |
| 20 | P2 | Particularités d'arène (Ruines, Désert, Glace, Volcan, Bosquet) | M | `world/proc_map.gd`, `world/colisee_*.gd` | captures ; IA qui les évite (test) |
| 21 | P2 | « Lui conseiller » (choix des alliés IA), graine du jour + record, duos, « Mêlée finale », reprise de partie | M chacun | `ui/colisee_*.gd`, `core/colisee.gd`, `core/challenge.gd` | — |

---

## 8. Plan de lots d'implémentation

Préfixe **CO** (Colisée). Estimation honnête : **≈ 28 à 38 jours d'agent** pour P0 + P1 (dont ≈ 18-24 pour P0), plus ≈ 8-12 pour le P2.
C'est l'ordre de grandeur de l'Échiquier (AC-A à AC-J), un peu moins grâce aux combats déjà faits (Arènes) et aux plateaux cachés (AC-E).

| Lot | Contenu (backlog n°) | Dépend de | Taille | Rapport |
|---|---|---|---|---|
| **CO-A** | Socle : `Colisee`, formats, barème, appariement, simulation « au tableau » sans scène, `Modes` / `ModeRules` / `sealed`, audit des drapeaux (1) | — | L | `R_CO_A.md` |
| **CO-B** | Carte : 6 arènes, piliers, fleurs, anneau de feu (2) | CO-A | M | `R_CO_B.md` |
| **CO-C** | Directeur de combat : 3 combats, filtre d'arène, combats cachés, mort du joueur ; **sonde de performances 18 / 24 héros** (3, 4) | CO-A, CO-B | L | `R_CO_C.md` (décision Grand tournoi) |
| **CO-D** | IA d'équipe : `ClassRival` généralisé + chef d'équipe (5), banc | CO-C | L | `R_CO_D.md` |
| **CO-E** | Atouts : données, effets, offres notées, IA de choix (6) | CO-A (effets testés sur mannequin), CO-C pour l'essai en combat | L | `R_CO_E.md` |
| **CO-F** | Enclumes, or, revente, sorts des manches 3 / 6 (7) | CO-A | M | `R_CO_F.md` |
| **CO-G** | Interface : lobby, préparation, choix d'atout sans pause, HUD, résultat, éliminations (8) | CO-C, CO-E, CO-F | L | `R_CO_G.md` (captures) |
| **CO-H** | Fin, récompenses, quêtes, activité, verrous, fiches (9, 17) | CO-G | M | `R_CO_H.md` |
| **CO-I** | Mesure et calibrage : parties entre IA, rapport, réglages (10, 18) | CO-D, CO-E, CO-F | M | `R_CO_I.md` + `tests/co_mesures.json` |
| **CO-J** | Relève, spectateur, décrets, Spectres (11-14) | CO-G | L | `R_CO_J.md` |
| **CO-K** | IA Hardcore, moments manga et sons (15, 16) | CO-D, CO-G | M | `R_CO_K.md` |
| **CO-L** | P2 : Grand tournoi (si la sonde passe), particularités d'arène, options (19-21) | CO-I, CO-C | L | `R_CO_L.md` |

Parallélisme possible : CO-B ∥ CO-E ∥ CO-F après CO-A ; CO-D ∥ CO-G après CO-C. Le premier jalon jouable (une partie complète, sans
relève ni décret) arrive après CO-A → CO-H (≈ 18-24 jours).

---

## 9. Questions ouvertes (recommandation par défaut)

| # | Question | Recommandation par défaut | Pourquoi |
|---|---|---|---|
| Q1 | Format par défaut : 8 × 3 (idée du joueur) ou 6 × 3 ? | **6 × 3 « Classique »** ; 8 × 3 en « Grand tournoi » si la sonde CO-C passe | durée presque égale (§5.1) mais 24 héros non mesurés, 6 couleurs de bonbon, choix de Riot pour les trios |
| Q2 | Nom du mode ? | **« Le Colisée »** (autres : « Le Tournoi », « Arena ») | « Arènes » est déjà le 2v2 / 3v3 du Duel ; « Arena » est un mot anglais (test_texts_fr) |
| Q3 | Fusionner avec les Arènes 2v2 / 3v3 ? | **Non** : les Arènes restent le JcJ du compte (insignes, maîtrise, Ligue) ; le Colisée est scellé | rôles uniques par activité (CLAUDE.md) |
| Q4 | Le joueur choisit-il pour ses alliés IA ? | **Non en v1** (ils choisissent seuls et le montrent) ; P2 « Lui conseiller » | rythme de la préparation de 30 s |
| Q5 | Équipe exempte ? | **Spectres** (P1), exempt simple en P0 | 70 s d'attente sans jouer est le pire moment d'un Arena |
| Q6 | Relève ? | **Oui**, une par trio et par manche (P1) | la plus belle idée d'équipe de LoL ; prolonge un peu les manches (à mesurer) |
| Q7 | Qu'est-ce qu'une « victoire » ? | **Places 1 à 3** sur 6 (moitié haute) ; titres et coffres pour la 1re | LoL (1-4 sur 8) ; une équipe moyenne finit 1re 7 fois sur 100 |
| Q8 | Rôle unique (`gives`) ? | **Titres et apparences « de gladiateur »** (une collection propre au Colisée), comme l'Échiquier a les siennes | règle « une activité = un rôle unique » |
| Q9 | Choix du héros : toutes les classes ? | **Classes débloquées du compte** (règle des modes scellés) | `Modes.sealed` permet classes et apparences débloquées |
| Q10 | Pause ? | **Oui**, partout (jeu solo) | confort ; aucune triche possible contre des IA |
| Q11 | Rafale de choix (Battlerite a fini par préréger les bonus) ? | **4 atouts choisis en partie**, pas de préréglage ; mais sorts préréglés et choix automatique au temps écoulé | garder le cœur « atouts entre les manches » demandé par le joueur |
| Q12 | « Plusieurs équipes en même temps sur une arène » ? | **Combats séparés et simultanés** (comme LoL) ; « Mêlée finale » à 3 équipes en P2 | lisibilité d'un 3 contre 3 ; la mêlée à 9 héros est à essayer après mesure |

---

## 10. Ce qui n'a pas pu être vérifié
Durée moyenne mesurée d'une partie de LoL Arena (seules des estimations et une cible de 30 min publiées) ; règles exactes de « Swift Arena » ;
rareté identique ou non des 3 cartes d'une offre d'atouts dans LoL ; relance d'une carte ou des trois ; règle d'égalité au temps de Brawl
Stars Knockout ; fin de Hearthstone Duels ; écrans de LoL Arena (HUD, classement) vus en vidéo. Aucun élément du backlog ne repose sur un
point non vérifié : chaque choix est justifié par une source vérifiée, par notre code ou par la simulation du §5.

## 11. Sources (liens)
- LoL Arena : wiki.leagueoflegends.com/en-us/Arena ; wiki.leagueoflegends.com/en-us/Arena/Augments ;
  support.riotgames.com/en-us/league-of-legends/gameplay/league-of-legends-arena-game-mode ;
  leagueoflegends.com/en-au/news/game-updates/league-of-legends-patch-26-11-notes ; gamewave.fr/lol/lol-ce-que-nous-savons-sur-le-patch-26-10/ ;
  esports.gg/news/league-of-legends/the-lol-arena-mode-is-coming-back-with-16-players ; riftfeed.gg (patch 14.9) ; blog.loltheory.gg/what-is-arena/
- Overwatch 2 Stadium : notes de la saison 16 (dexerto, siege.gg, sportskeeda), blog.playstation.com (annonce du 22/04/2025), icy-veins
- TFT Double Up : wiki.leagueoflegends.com/en-us/TFT:Double_Up ; support.riotgames.com (TFT Double Up) ; teamfighttactics.leagueoflegends.com (« Double Up upgraded »)
- Battlerite : destructoid.com, gamepressure.com/battlerite/guide, techraptor.net (critique), fandom.com (article « A Year Later »)
- Brawl Stars : en.wikipedia.org/wiki/Brawl_Stars ; noff.gg
- Hearthstone Duels : hearthstone.blizzard.com/en-us/news/23558960 (Dev Insights, 17/11/2020) ; hearthstone.wiki.gg/wiki/Duels
- Dota Overthrow 3.0 : esports.ru ; steamcommunity.com (journal de la carte 2760533777)
