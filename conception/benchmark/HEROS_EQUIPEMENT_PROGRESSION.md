# Héros, équipement, Atelier et progression face aux MMORPG : étude comparative (BM-GEAR, 17/10/2026)

Mandat du joueur : « s'inspirer des MMORPG ; reprendre des images des concurrents pour analyser et comparer avec le nôtre, nos points
faibles ; HUD, UI / UX, profondeur, confort ; dans notre nouvelle DA ; vision : quête du niveau 90, stuff full optimisé, plans + insignes
+ donjons, côté RPG où l'on veut devenir plus fort **sans corvée** ». Méthode : `METHODE.md`. DA : `art/BIBLE.md` v2. Notre conception :
`progression/REFONTE_AVENTURE.md`, `progression/NIVEAU_HEROS.md`, rapports `R_H1`-`R_H4a`, `R_A1`-`R_A5`, DESIGN « Économie et
progression ». Croquis maison (SVG, ouvrir dans un navigateur) : `equipement_maquettes/` (`v2_heros`, `v2_infobulle`, `v2_atelier`,
`v2_forge`). Images de référence et nos captures : **hors dépôt**, `C:\AI\benchmark_refs\equipement\` (`wow`, `ffxiv`, `lostark`,
`maplestory`, `gw2`, `diablo4`, `monsterhunter`, `eden_slash_nous`, rendus des maquettes `maquette_*.png`). Aucun texte, image ou son
tiers n'est repris ici : on décrit.

**Verdict en une phrase** : nos **systèmes** sont déjà au niveau d'un MMORPG solo sérieux (deux niveaux de progression, plans découverts
puis fabriqués, plans de donjon par boss, Forge à 6 établis avec chances affichées, panoplies 2 / 4 / 6, profils de stats des 60 classes,
Registre, boussole, « Équiper le meilleur » annulable, sac illimité) ; ce qui nous fait encore « prototype » est **la lecture de la
décision** (une infobulle qui empile des écarts en % au lieu de dire « meilleure pour ta classe »), **l'absence de cible** (rien ne dit
« voici la pièce que je veux, voici ce qui me manque »), **une Forge qui punit sans filet** (rétrogradation dès +6, aucune jauge de
persévérance), **les outils de tri du sac** (ni verrou, ni « neuf », ni démontage en masse au hub) et **l'ancienne DA** (bleu nuit et
filet doré, listes déroulantes).

---

## 0. Les 5 plus gros écarts

| # | Écart | Ce que font les meilleurs | Chez nous (0.1.256, HEAD) |
|---|---|---|---|
| 1 | **Pas de « je vise cette pièce »** | Monster Hunter Wilds : liste de souhaits, coche quand tout est réuni, « forger depuis la liste » ; Lost Ark : favoris et « fabricables seulement » à l'artisanat | ni objectif, ni favori ; la boussole choisit pour le joueur ; le bilan dit « 3 pièces découvertes » sans les nommer |
| 2 | **Infobulle qui ne tranche pas** | GW2 et WoW : la pièce portée **à côté**, mêmes lignes ; Diablo IV : gains verts / pertes rouges en option ; FFXIV : « Équipement recommandé » d'après les attributs du métier | verdict « Meilleur +24 % » (pourcentage permanent, interdit par la vision), 6-8 lignes ▲ / ▼ en vrac, pas de repère des stats qui comptent pour la classe, rien sur la provenance hors Atelier |
| 3 | **Forge : risque sans pitié** | Lost Ark : chaque échec remplit une **énergie d'artisan** (100 % = réussite assurée) et monte la chance ; Black Desert : échecs cumulés ; MapleStory : protection payante, chances affichées (réussite / échec / destruction) ; WoW : amélioration **sans échec**, « Améliorer jusqu'à 2/8 » avec coût total | chances affichées (bien), mais un échec vers +6 et au-delà **fait perdre un niveau et sa stat bonus** sans pierre ; aucune jauge ; pas de « viser +N » ni de coût attendu |
| 4 | **Sac sans outils de tri** | Genshin : verrou et **verrou automatique par règle** ; WoW / GW2 : recherche et filtres ; MH : boîte d'équipement filtrée | recherche, 7 onglets, 5 tris, filtre par case de poupée (bien) ; **aucun verrou**, aucun repère « neuf », démontage pièce par pièce au hub (en masse seulement chez le marchand de partie) |
| 5 | **Fabriquer = catalogue, pas progression** | Lost Ark : liste à favoris et « fabricables » ; MH : arbre de forge par arme ; WoW : piste d'amélioration lisible (« 1/8 ») | grille de 1 811 plans filtrée par 4 listes déroulantes ; le **kit d'un palier** (9 emplacements) ne se voit pas ; Plans de donjon : on fabrique **sans voir la pièce** (seulement l'emplacement) |

Ce qu'on fait **mieux** qu'eux : chances et conséquence d'échec écrites avant l'appui (Forge) ; « Équiper le meilleur » + « Appliquer à la
famille » + **Annuler** ; un plan sert toutes les variantes d'un palier à 15 % (l'équivalent de la remise « alts » de WoW, mais pour 60
classes) ; sac illimité ; Registre des 60 classes avec « Il manque : … → activité » ; aucun plafond hebdomadaire.

---

## 1. Sources et ce qui a été vérifié

| Référence | Ce qu'on a regardé (images hors dépôt) | Sources écrites |
|---|---|---|
| World of Warcraft | fenêtre du personnage (poupée 2 colonnes, niveau d'objet en grand, attributs), gestionnaire d'ensembles (Équiper / Enregistrer, flèches de choix par case), fenêtre d'amélioration (actuel / amélioré côte à côte, « Améliorer jusqu'à 2/8 », coût total), fenêtre des titres | warcraft.wiki.gg : Character window, Item upgrade (pistes Explorateur → Mythe, remise de 50 % pour les autres personnages du compte sur un emplacement déjà monté) ; résumés Icy Veins / Wowhead (crêtes) |
| Final Fantasy XIV | « Équipement recommandé » (liste actuel → recommandé, Équiper / Annuler), fenêtre du personnage (numéro d'ensemble et niveau moyen dans l'en-tête) | consolegameswiki : Recommended Gear (bouton de la fenêtre du personnage, d'après les attributs du métier), Materia (taux de surcharge par cran, échec rejouable depuis 3.2, retrait de matérias 100 / 80 / 40 %) |
| Lost Ark | fenêtre de renforcement (niveau 15 ⋙ 16, barre de chance 45 % / 65 %, énergie d'artisan 86,51 % (+13,49 %), matériaux d'appoint au curseur « jusqu'à +20 % », coût / solde), transfert, artisanat 2026 (favoris, « fabricables », matériaux 0/100 en rouge, quantité au curseur) | Maxroll « Gear Honing System » (jauge à 100 % = réussite assurée, bonus de chance par échec, transfert) |
| MapleStory | fenêtre de Star Force (piste d'étoiles, 18 ⋙ 19, gains de stats, réussite / échec / destruction, coût, protection, interrupteur « animations ») | maplestorywiki : Star Force Enhancement (destruction dès 15★, protection 15-17★ à +200 % du coût, « Chance Time » réservé aux objets supérieurs) |
| Guild Wars 2 | panneau Héros > Équipement (liste filtrable à gauche, infobulle survolée + « actuellement équipé » côte à côte, onglets de modèles 1 / 2 + onglets fermés) | wiki officiel : Legendary Armory (déblocage pour le compte, attributs par modèle), Template (modèles d'équipement et de compétences) |
| Diablo IV | forgeron > trempe (catégories, coût, « Tremper ») | résumés Icy Veins, Windows Central, d2runewizard (Maj pour comparer, « comparaison détaillée » en option, 2 trempes par objet ; maîtrise rangs 4 / 8 / 12) — **partiellement vérifié** (pages 403) |
| Monster Hunter Wilds | menu de la forge (onglets LB / RB, « depuis la liste de souhaits »), forge d'armes artian (pièces / boîte / fiche) | monsterhunterwiki (Smithy), Destructoid (liste de souhaits), Prima (arbre, marteaux bleu / violet) |
| Black Desert, Genshin, Path of Exile | pas d'image (pages bloquées : 403, 402, anti-robot) | résumés de recherche : Black Desert (échecs cumulés, conseils de Valks, anneau de Naderr pour garder ses échecs) ; Genshin 4.3 (verrou automatique par règle sur stat principale / secondaires, 15 objets choisis à la fois) — **non vérifié** sur page ; Path of Exile : filtres de butin — **non vérifié** ici |
| **Eden Slash** (0.1.256, HEAD propre) | 53 captures : `shot_hero` (équipement, comparaison, Gérer, Classe, Apparence, Grimoire), `shot_atelier` (Fabriquer, Plans de donjon, 6 établis de la Forge, verdict), `shot_h3` (1280×720, niveau requis), `shot_registry`, `shot_tips` (infobulles par rareté) + `art/audit/` (bilan, coffres, choix de pièce) | code `ui/equipment_page.gd`, `inventory_page.gd`, `item_widgets.gd`, `gear_shop_page.gd`, `fabrication_page.gd`, `forge_bench.gd`, `core/craft.gd`, `profile.gd` |

Limites : aucune référence jouée (pas de client) ; les comportements fins viennent des wikis, guides et captures. Les dates des captures
de référence varient (WoW Dragonflight / 10.x, Lost Ark 2022-2026) : on retient la **structure**, pas les chiffres du jour.

---

## 2. Ce qui fait la qualité de chaque référence (pour nous)

- **WoW** — *la poupée lisible et l'amélioration sans échec.* Poupée en deux colonnes autour du héros, armes dessous, **un seul nombre
  en grand** (niveau d'objet moyen), attributs puis « améliorations » en %. Chaque case a une **petite flèche** qui ouvre les pièces de cet
  emplacement (vu sur l'image). L'amélioration ne rate jamais : on choisit **jusqu'où** (« 2/8 ») et on lit le coût total ; la carte
  actuelle et la carte améliorée sont côte à côte, les écarts en vert. La remise de compte (emplacement déjà monté par un autre
  personnage) tue la corvée des personnages secondaires (vérifié). Ensembles d'équipement nommés, avec icône.
- **FFXIV** — *« on te propose, tu valides ».* Le bouton « Équipement recommandé » montre la liste **actuel → recommandé** puis
  Équiper / Annuler (vérifié). Le numéro d'ensemble et le niveau moyen sont dans l'en-tête de la fenêtre du personnage. Matérias :
  taux affichés par cran, un échec ne coûte que la matéria, le retrait en rend une partie (vérifié) — risque **doux**.
- **Lost Ark** — *la pitié visible.* La fenêtre de renforcement met en scène **deux jauges** : la chance (base + bonus d'échecs) et
  l'énergie d'artisan avec, entre parenthèses, **ce que le prochain échec ajoutera** (vérifié sur l'image). Les matériaux d'appoint se
  règlent au curseur avec leur plafond écrit. Coût et solde sont alignés (rouge s'il manque). Le **transfert** d'un renforcement vers une
  pièce plus haute existe (vérifié). L'artisanat a favoris, « fabricables seulement » et quantité (vérifié, 2026). Défaut : écran dense,
  « cliquer 200 fois » est une corvée assumée — à ne pas copier.
- **MapleStory** — *la piste d'étoiles.* Chaque cran est une étoile ; on voit où l'on est et où l'on va. Réussite, échec **et
  destruction** sont écrits ; la protection est un interrupteur au coût explicite ; un interrupteur coupe les animations (vérifié).
  Défaut : la destruction et les coûts exponentiels sont la frustration type du genre.
- **Guild Wars 2** — *comparer côte à côte et changer de modèle.* L'infobulle survolée et « actuellement équipé » s'affichent l'une à côté
  de l'autre, mêmes lignes. Les modèles (onglets 1, 2…) changent tout l'équipement d'un clic ; l'armurerie légendaire débloque une pièce
  pour **tout le compte** et ses attributs se choisissent par modèle (vérifié) : la longue traîne « toutes les classes » sans refaire.
- **Diablo IV** — *Maj pour comparer, gains verts / pertes rouges* (option « comparaison détaillée », non vérifié sur image). La trempe
  choisit une famille d'affixe avant le tirage (choix guidé). Maîtrise à rangs 4 / 8 / 12 « critiques » (comme nos paliers +4/6/8/10).
- **Monster Hunter** — *le désir avant le butin.* On met une pièce dans la **liste de souhaits** ; la forge la propose avec une coche quand
  tout est réuni ; l'arbre montre ce qui vient après (marteau bleu : fabricable, violet : il faut la précédente). Menus de forge en onglets
  LB / RB, pied de touches dessinées (vu).
- **Genshin** — *le verrou par règle* : « garde automatiquement les pièces qui ont telle stat principale » (non vérifié sur page).
- **Path of Exile** — *le filtre de butin* (couleurs, sons, masquer) : pertinent pour nos coffres et nos bilans, pas pour le sac
  (non vérifié ici).

---

## 3. Nos écrans un à un

### 3.1 Héros > Équipement (`hero_2`, `hero_3`, `hero_6`, `e3_3`, `h3_2`)

| Point | Nous | Meilleure référence | Écart |
|---|---|---|---|
| Hiérarchie | « Puissance d'équipement 2 580 » en grand sous la poupée, PV / Attaque / Défense / Vitesse / Agilité en bas | WoW (niveau d'objet en tête), FFXIV (en-tête) | bien ; il manque **à quoi sert ce chiffre** (« Héroïque à 7 200 ») : il n'est que dans les pages d'activité |
| Poupée | 10 cases, 3D, niveau sur la case, couleur de rareté ; clic = le sac filtre l'emplacement | WoW (flèche par case) | bien ; pas de repère **sur la case** quand le sac a mieux (le ▲ n'est que dans le sac) |
| Préréglages | 3 par classe, onglets en haut, Gérer (copier, Équiper le meilleur, famille, renommer, annuler) | GW2 (modèles), WoW (ensembles nommés + icône), FFXIV (ensembles numérotés) | bien ; 3 c'est peu pour Aventure / Donjon / Duel équipé / essai ; « Équiper le meilleur » applique **sans aperçu** (annulable) — FFXIV montre d'abord la liste |
| Fiche sous le sac | nom, rareté, niveau, stats avec écarts entre parenthèses, « Pièce portée » réduite avec « ▲ +148 % · Puissance +496 », panoplie, Équiper / Forge / Démonter | GW2 (deux cartes alignées) | le verdict est un **pourcentage** ; les écarts sont entre parenthèses illisibles à distance ; « Démonter » à côté d'« Équiper » sans garde (il y a une confirmation dans la Forge, à vérifier ici) |
| Stats du héros | fixes | WoW / GW2 : au survol, rien non plus ; Diablo IV : la comparaison donne l'effet sur le héros | **à faire mieux qu'eux** : écart PV / Attaque / Défense au survol |
| Panoplies | une ligne « Aucune panoplie active » + bouton | WoW (bonus dans l'infobulle) | une ligne vide qui prend une rangée entière |
| 1280×720 | `h3_2` : le panneau du sac déborde à droite (onglets, tri, boutons coupés) | — | **à confirmer** : l'outil redimensionne la fenêtre après construction ; refaire avec `shot_p1` (`[débord]`) |

### 3.2 Infobulle d'objet (`infobulles/hub_*`, `ItemWidgets.item_card`)

Forces : nom à la couleur de rareté, « rareté · emplacement · niveau », PE et qualité, **stat principale en grand**, gemmes, enchantement,
panoplie x / N et palier suivant, comparaison avec la pièce portée, **Maj** déplie (paliers, chance d'amélioration, niveau de puissance).
Écarts : (1) verdict « Meilleur +107 % · PE +1 301 » : un pourcentage permanent et une comparaison **à la PE commune**, pas au profil de la
classe (`Items.rating` existe et ne sert qu'aux choix automatiques) ; (2) jusqu'à 8 lignes ▲ / ▼ puis « + 5 autres différences » : la
liste est plus longue que la carte ; (3) la pièce portée n'est qu'un nom (« Porté : Peau du Tigre crochu ») ; (4) aucune ligne
« d'où vient-elle / comment la refaire » hors de l'Atelier ; (5) la carte de choix en partie (`22_choix_equipement`) dit « ▲ +3 % sur ta
pièce » mais **pas si la pièce est un plan neuf** — or choisir une pièce, c'est découvrir son plan.

### 3.3 Sac et inventaire

| Fonction | Nous | Références | Écart |
|---|---|---|---|
| Recherche, onglets, tri | oui (7 onglets, 5 tris : rareté, niveau, nom, type, amélioration) | toutes | tri « pour ma classe » manquant (le ▲ existe, pas le tri) |
| Verrou | **non** (seules les pièces portées sont protégées ; la Forge cite les préréglages qui l'utilisent) | Genshin (verrou + règles), GW2, WoW (non vérifié) | **P0** |
| « Neuf » | non | Diablo IV, Genshin, la plupart des jeux mobiles (non vérifié) | P0 (avec le verrou) |
| Masse | sélection multiple (clic, Ctrl, Maj, Ctrl+A) ; démonter / vendre en masse **chez le marchand de partie** seulement ; au hub, Forge > Démonter une pièce à la fois (second clic dans les 3 s) | Genshin (15 à la fois), Lost Ark | **P0** : démontage en masse au hub, avec annulation |
| Place | illimitée (`INVENTORY_MAX` 100 000) | MMORPG : sacs limités | **on fait mieux** ; il faut seulement « Inutiles » pour faire le ménage |

### 3.4 Héros > Classe : maîtrise, talents, certificats (`hero_8_*`, `09_heros_classe_avance`)

Maîtrise : barre + parcours niveau par niveau (+2 talents, sort, certificat) : clair, proche du « tableau de récompenses » des passes.
Talents : 18 icônes en grille avec « 0 / 20 », points 2 / 2, Réinitialiser ; **ni liens de prérequis, ni paliers de points (15 / 20 / 25 / 30
/ 35) dessinés, ni effet chiffré au survol en tête, ni chargement (« loadout ») ni build conseillé** — WoW a des chargements de talents et un
build de départ (non vérifié ici). Certificats : plateau à liens, bonus de placement — riche, mais le texte des liens est un pavé de % (à
mettre en infobulle, vision « aucun % permanent »).

### 3.5 Apparence, titres, création de personnage (`hero_9_*`, `10_heros_apparence`, `shot_c1`)

Apparence : 5 cases (tenue, tête, dos, aura, arme), « Débloqués uniquement », « 0 / 122 · butin des boss », héros 3D tournant. Il manque
l'**aperçu au survol** (essayer sans équiper), des **tenues enregistrées** par préréglage (FFXIV : plaques de mirage, vérifié) et la
provenance de chaque apparence verrouillée. Titres : dans le Carnet, pas dans Héros (WoW : onglet de la fenêtre du personnage, vérifié).
Création : nom, 6 coiffures, 12 couleurs de cheveux, 8 d'yeux, « Au hasard » : suffisant pour le genre (un seul corps, pas de comparaison
utile avec les MMORPG).

### 3.6 Atelier > Fabriquer et Plans de donjon (`atelier_avance_0*`, `_1`, `h3_6`)

| Point | Nous | Références | Écart |
|---|---|---|---|
| Rangement | grille de plans, 4 listes déroulantes (statut, emplacement, époque, classe), « 48 / 1 811 plans découverts » | MH (arbre par arme), Lost Ark (liste + favoris + fabricables) | le **kit d'un palier** ne se lit pas ; 1 811 cases n'aident pas à décider |
| Case | niveau en haut à gauche (rouge si trop haut), prix en bas | Lost Ark (matériaux x / y rouge) | deux nombres sur une case de 64 px |
| Fiche | carte complète + comparaison + « Plan trouvé : Époque I · Monts Calcaires » + « À porter au niveau 33 · tu es niveau 1 » + « Fabriquer · 9 insignes » | WoW (avant / après) | bien ; bruit : « Prochaine amélioration : 100 % de réussite », « Niveau de puissance 33 » dans une fiche d'achat |
| Manque | bouton grisé | Lost Ark (solde vs coût), MH (coche de la liste de souhaits) | pas de « il en manque 37 ≈ 1 carte d'Aventure » |
| Après | la pièce va au sac, reste choisie | — | pas de « Fabriquer et porter » ; pas d'animation vers la poupée |
| Plans de donjon | carte par boss : nom, panoplie, liste déroulante d'emplacement, « Fabriquer · 44 insignes », « Pièce mythique, niveau 14 » | WoW, Lost Ark (aperçu du résultat) | **on fabrique sans voir la pièce** (stats, comparaison) ; 3 / 48 sans vue des 45 autres (une ligne « donjons fermés ») |
| État vide | « Aucun plan trouvé pour l'instant. En Survie, chaque coffre d'emplacement en révèle trois. » | BIBLE § 6 : image + phrase + action | pas d'image ni de bouton « Lancer une Aventure » ; mot « Survie » (renommage A9 en attente) |

### 3.7 Atelier > Forge (`atelier_avance_2_*`, `14_atelier_forge`)

Forces (au niveau de MapleStory et Lost Ark) : 6 établis en onglets, tableau **avant → après**, coût en cristaux « (tu en as 420) »,
parchemin utilisé et « Réussite assurée jusqu'à +3 », pierres de sûreté en tuiles avec leur bonus, barre « Réussite : 90 % », **« Échec :
l'objet reste à +3 »**, bandeau de verdict « RÉUSSI » avec la stat bonus tirée. Écarts :

| Point | Nous | Références | Écart |
|---|---|---|---|
| Pitié | aucune (`Craft.upgrade` : tirage pur) | Lost Ark (énergie d'artisan, bonus par échec), Black Desert (échecs cumulés) | **P0** |
| Rétrogradation | dès +6 sans pierre (`DOWNGRADE_FROM` 6) : −1 niveau **et** perte de la stat bonus du palier | WoW (aucun échec), FFXIV (échec = matéria perdue) | contraire de « sans corvée » : remonter +6 → +7 sur 20 pièces × 60 classes |
| Cible | une tentative à la fois | WoW « jusqu'à 2/8 » + coût total | **P0** : viser +N, coût attendu et au pire |
| Piste | « +3 → +4 » en texte | MapleStory (piste d'étoiles) | paliers +4/+6/+8/+10 (stat bonus) invisibles d'avance |
| Gemmes | « Percer un emplacement (sûr) · ciseaux ×2 », « Sertir Rubis brut ×5 », fusion « Rubis brut ×5 → Rubis taillé · 2 cristaux » | FFXIV (retrait de matéria), Lost Ark | **la stat que donne la gemme sur cette pièce n'est pas écrite** ; sertir sur une gemme la détruit (DESIGN) ; 2e emplacement à 70 % |
| Retours | barre qui se remplit, bandeau vert / rouge | MapleStory, Lost Ark (mise en scène, sons) | ni son, ni étincelle, ni piste qui s'allume ; l'échec a la même couleur rouge qu'une erreur |
| Liste | grille par rareté / type, « porté » en légende sur la case | — | « porté » cache le +N ; pas de « tout porté à +5 » |

### 3.8 Coffres, roulette, bilans, Registre (`11`, `12`, `24_bilan_victoire`, `16_registre`, `e3_*`)

Coffres : une ligne par genre, « Ouvrir tout (5) », grand coffre 3D ; l'ouverture en masse ne met pas en scène les raretés (BIBLE § 7
« Récompense » à appliquer). Bilan : Gagné / Gardé / Perdu clairs ; « Pièces découvertes 3 » **sans les nommer** ; la ligne « Ta quête »
dit encore « 3 pièces à l'Armurerie » (onglet renommé « Fabriquer », lot A3) et le bouton « Retour au lobby » (mot interdit, BIBLE § 12).
Registre : la meilleure idée du lot (état par classe, « Il manque : … → activité »), mais 9 colonnes de « 0 / 9 » identiques sur un compte
neuf : il faudrait **une jauge par classe** et la colonne « ce qui manque » en premier.

### 3.9 Progression de l'Aventure (niveau 1-90, bandes, PE, rythme)

| Point | Nous | MMORPG | Lecture |
|---|---|---|---|
| Niveau de héros | 1 → 90 en ≈ 29 h (M), barre « Niv. 34 » au lobby et à Héros, bilan « 34 → 35 » | WoW / FFXIV : niveau + barre d'XP permanente, récompense à chaque niveau | la barre n'a ni chiffre ni « prochain déblocage » (H3 : pièces niveau N) ; aucun moment « Niveau ! » hors bilan |
| Bandes de cartes | I-1 1-23 … IV-3 80-90, affichées sur la page de l'Aventure (H4a) | FFXIV : niveau de donjon / niveau synchronisé | bien ; il manque « ta bande » mise en avant (où je progresse le mieux) |
| PE conseillée | Donjons, Ruée, Siège : PE conseillée / requise, estimation (Facile → Hors de portée) | WoW : niveau d'objet requis par difficulté | bien ; pas reprise à l'écran Héros |
| Butin de l'Aventure | coffres d'emplacement (3 au choix), coffre de plans du boss de carte (A4), insignes au bilan | WoW : coffre hebdomadaire au choix ; Lost Ark : quotidiens | **on fait mieux** (choix, pas de quotidien) ; il manque le marquage « nouveau plan » sur les cartes |
| Rythme 30 h | époque I 3 h, Donjons 3 h, Héroïque ≈ 18 h, niveau 90 ≈ 29 h, équipement 80-90 correct ≈ 31-37 h (M, A4 / PR2) | MMORPG : saisons, plafonds hebdomadaires | pas de plafond = pas de corvée ; risque : un milieu (15-30 h) sans **jalon visible** entre deux époques |
| Longue traîne | 7 profils × 17 armes, maîtrise 60 classes, collection 1 811 plans, 48 plans de donjon ≈ 250-350 h (E) | GW2 (armurerie de compte), WoW (remise de compte) | nos remises (15 %, plans communs) sont bonnes ; le **+N non transférable** reste le seul « remonter de zéro » (REFONTE Q8) |

---

## 4. Profondeur : reprendre les systèmes d'amélioration sans la frustration

| Système de référence | Ce qui plaît | Ce qui frustre | Notre version |
|---|---|---|---|
| Énergie d'artisan (Lost Ark), échecs cumulés (Black Desert) | l'échec **avance** ; on sait que ça finira | l'échelle (des centaines d'essais), le magasin | **Persévérance** : jauge propre à la pièce, + (100 % − chance) × 0,5 par échec, réussite assurée à 100 % ; chance +10 % de la base par échec (plafond : chance de base × 1,5) ; gardée jusqu'à la réussite. Au pire 5 essais par cran (base 40 %), 4 à +10 (base 30 %) |
| Rétrogradation (Black Desert), destruction (MapleStory) | le frisson | perdre des heures | **supprimée** : un échec ne coûte que le parchemin et les cristaux de l'essai. Les pierres deviennent des **pierres de chance** (même icône, +5 à +100 %) |
| « Jusqu'à 2/8 » (WoW) | une décision, pas 8 clics | — | **Viser +N** : coût attendu et coût au pire (calculables grâce à la jauge), « maintenir A » enchaîne et s'arrête à chaque palier à stat bonus |
| Transfert (Lost Ark), remise de compte (WoW) | la pièce suivante ne repart pas de zéro | — | **Reporter** : une pièce neuve du même emplacement prend le +N de l'ancienne moins 2, gratuit (REFONTE Q8 à rouvrir, mesurer par `progression_sim`) |
| Matérias : retrait (FFXIV) | l'erreur se répare | les taux de surcharge | **Désertir** gratuit (la gemme revient au sac) au lieu de la détruire ; le 2e emplacement reste à 70 % mais les ciseaux brisés comptent dans la jauge |
| Trempe guidée (Diablo IV), potentiel (MapleStory) | viser une stat | relancer à l'infini | **Réajuster** (existe) : afficher la fourchette de la stat avant / après ; « garder l'ancien » si le nouveau jet est moins bon (comme Polir) — à trancher (Q3) |
| Panoplies 2 / 4 / 6 | objectifs de collection | — | gardées ; montrer en pastilles ce que la pièce **ajoute** au palier |

Garde-fous communs : chances, coût attendu et conséquence écrits avant l'appui (déjà fait) ; aucune pièce verrouillée ou portée ne se
démonte ; « Réduire les animations » abrège la mise en scène ; rien ne coûte d'argent réel (pas de boutique) : la pitié n'a pas besoin
d'être rare.

---

## 5. La boucle « je vois ce que je veux → je sais comment l'obtenir »

| Étape | Aujourd'hui | Trou | Correctif |
|---|---|---|---|
| Je vois une pièce | coffre en partie, sac, Fabriquer, Registre | la carte de choix ne dit pas « nouveau plan » | badge **Nouveau plan** / **Plan connu** sur la carte (P0-7) |
| Je veux cette pièce | — | aucun moyen de le dire | **★ Objectif** (une pièce épinglée, 5 suivies) depuis l'infobulle, Fabriquer, Plans de donjon, Registre (P0-6) |
| Je sais ce qui manque | boussole (un conseil, choisi par le jeu), Registre (« Il manque … → activité ») | dispersé ; insignes sans conversion en temps | la barre d'objectif dit : plan ✓ / à trouver (où), insignes x / y (≈ N cartes d'Aventure), niveau 34 / 53, panoplie ; la boussole met l'objectif **en premier** |
| Je vais le chercher | page de l'activité | la page ne rappelle pas l'objectif | pastille « ★ ton objectif tombe ici » sur la carte d'activité et la carte de l'Aventure concernée |
| Je l'ai | bilan « 3 pièces découvertes » | anonyme | bilan : « ★ Objectif : plan trouvé » en tête de Gardé, noms des plans, « Fabriquer » en un clic |

---

## 6. Détails de confort (liste de contrôle)

| Confort | État | Note |
|---|---|---|
| Comparer avant / après (Forge, Fabriquer) | ✓ | tableau avant → après, verdict |
| Annuler « Équiper le meilleur » / famille | ✓ | dans Gérer |
| Annuler un démontage | ✗ | P0-2 (séance) |
| Verrou d'objet, verrou par règle | ✗ | P0-2, P2 (règles) |
| Recommandation pour la classe | partiel | ▲ du sac et « Équiper le meilleur » au profil ; infobulle à la PE commune |
| Indicateur de pièce idéale (« meilleure pour 12 classes ») | ✗ | P2 (infobulle : « Idéale pour : profil Puissance ») |
| Sac plein | ✓ | sans limite |
| Vendre / démonter en masse | partiel | marchand de partie seulement |
| Fabriquer en masse | ✗ | P1 (kit du palier) |
| Probabilités affichées | ✓ | Forge, 2e emplacement « sûr » écrit |
| Coût attendu / au pire | ✗ | P0-3 |
| Retours (son, particules, piste) | ✗ | P1 (BIBLE § 7) |
| Manette | ✓ | `UiNav` partout ; à ajouter : maintien A (Forge), Y = détails, X = équiper |
| Accessibilité couleur | partiel | rareté = couleur seule ; ajouter lettre / forme de coin (P2) |
| 1280×720 | à vérifier | `h3_2` déborde (artefact possible de l'outil) |

---

## 7. Backlog

Taille : S ≤ ½ journée, M ≈ 1-2 jours, L ≈ 3-5 jours (une session). Chaque lot : tests, captures 1600×900 et 1280×720 regardées,
`test_nav_screens`, `test_pages`, `test_texts_fr`, DA v2 (`UiTheme` v2 / `UiFeel` s'ils existent ; sinon la structure seule, la peau
suivra le lot DA).

### P0 — sans ça, l'équipement fait « prototype »

| # | Lot | Taille | Fichiers |
|---|---|---|---|
| P0-1 | **Infobulle v2** : verdict « Meilleure / Équivalente / Moins bonne pour <classe> » au profil (`Items.rating`), écart de PE seul chiffre, % derrière Maj ; stat principale + 3 stats triées par poids du profil (★) ; carte portée **côte à côte** (alignée) ; panoplie en pastilles ; ligne « Plan ✓ · époque · carte · prix » / « Donjon de <boss> » ; ce qu'on perd en retirant ; pied de touches | M | `ui/item_widgets.gd`, `core/items.gd` (`describe`), `core/class_gear.gd`, `core/completion.gd` (`plan_place`), `tests/test_tooltips` |
| P0-2 | **Verrou + « neuf » + démontage en masse au hub** : clé `locked` / `new` dans le dictionnaire de l'objet (aucun champ de `Profile`), L au clavier, X à la manette ; filtres « Gardées », « Nouveautés », « Inutiles » (plus faibles partout pour le profil) ; Forge > Démonter multiple, maintien 0,6 s, annulation pendant la séance ; les verrouillées et portées sont exclues de tout | M | `core/profile.gd` (`disassemble` : refus si verrou), `ui/inventory_page.gd`, `ui/forge_bench.gd`, `ui/merchant_pages.gd`, `ui/item_widgets.gd` |
| P0-3 | **Forge sans punition** : jauge de persévérance par pièce (`item.pity`), bonus de chance par échec, suppression de la rétrogradation, pierres = chance ; « Viser +N » avec coût attendu / au pire ; maintien pour enchaîner, arrêt aux paliers à stat bonus ; piste des 10 crans | M | `core/craft.gd` (`success_chance`, `upgrade`, `failure_text`), `ui/merchant_pages.gd` (`_upgrade`), `ui/forge_bench.gd`, `tests/test_progress`, `test_build` + nouveau `test_g3` ; `progression_sim` (cristaux) |
| P0-4 | **Plans de donjon : voir avant de fabriquer** : carte de la pièce (stats au niveau du plan, comparaison) pour l'emplacement choisi, « Fabriquer et porter » | S | `ui/fabrication_page.gd` |
| P0-5 | **Fabriquer v2** : colonne des paliers (époque · carte · niveau, x / 9, « ta bande »), poupée du palier (fabriquée / plan connu / à trouver + où), pastilles « Ma classe / Abordables / Portables / Objectifs », « il en manque N ≈ X cartes d'Aventure », « Fabriquer et porter », « Fabriquer les N plans connus du palier » ; état vide avec action | L | `ui/gear_shop_page.gd`, `core/completion.gd`, `core/economy.gd` (insignes ↔ temps : `INSIGNIA_PER_HOUR`) |
| P0-6 | **★ Objectif** : 1 pièce épinglée + 5 suivies (`records.goals`, ids de plans ou `plan_<boss>:slot`) ; barre en bas de Héros et de l'Atelier, première ligne de la boussole, pastille sur la page d'activité, ligne de bilan | M | nouveau `core/goals.gd`, `core/compass.gd`, `ui/equipment_page.gd`, `ui/lobby.gd`, `ui/results_panel.gd`, `ui/activities.gd` |
| P0-7 | **« Nouveau plan »** sur les cartes de coffre d'emplacement et du coffre de plans ; bilan qui **nomme** les plans découverts (3 au plus, « + N ») | S | `core/run_director.gd` (carte), `ui/card_picker.gd`, `ui/results_screen.gd` |
| P0-8 | **« Le meilleur ▲N »** : le bouton sort de « Gérer », dit combien de pièces il change, montre la liste avant / après (FFXIV), puis Appliquer ; ▲ sur la case de la poupée quand le sac a mieux | S | `ui/equipment_page.gd`, `ui/inventory_page.gd`, `core/class_gear.gd` |
| P0-9 | **Stats du héros au survol** : écart PV / Attaque / Défense de la pièce survolée ; PE « vers Héroïque · −1 240 » dans l'en-tête | S | `ui/equipment_page.gd`, `core/gear_power.gd` |
| P0-10 | **Textes** : « Armurerie » → « Fabriquer » dans `Compass.after` et partout (A3 restant), « Retour au lobby » → « Menu principal », « Pièces découvertes » → « Plans découverts » ; vérifier Héros à 1280×720 (`shot_p1`) | S | `core/compass.gd`, `ui/results_panel.gd`, `ui/results_screen.gd` |

### P1 — ce qui fait la qualité

| Lot | Taille | Fichiers |
|---|---|---|
| **Reporter le +N** (pièce neuve du même emplacement : +N − 2, gratuit) après décision Q2 et mesure `progression_sim` | M | `core/forge.gd`, `core/craft.gd`, `ui/forge_bench.gd`, `tools/progression_sim.gd` |
| **Retours de la Forge et de l'équipement** (BIBLE § 7) : marteau, piste qui s'allume, « Réussi ! », jauge qui se remplit à l'échec (lagon, pas fraise), +10 en fête ; pièce qui saute dans sa case ; « clac » par matière | M | `ui/forge_bench.gd`, `ui/item_widgets.gd`, `UiFeel` |
| **Sertir lisible** : valeur de chaque gemme **sur cette pièce**, désertir gratuit, « tout fusionner » | S | `core/craft.gd`, `ui/merchant_pages.gd` |
| **Préréglages 3 → 5**, nommés par usage, icône ; choix du préréglage sur la page de l'activité avant Lancer | M | `core/profile.gd` (`PRESETS_PER_CLASS`, migration sans perte), `ui/equipment_page.gd`, `ui/lobby.gd` |
| **Talents v2** : liens de prérequis, paliers de points dessinés, effet chiffré en tête d'infobulle, 2 chargements par classe, « build conseillé » (profil opti existant) | M | `ui/talents_page.gd`, `core/rival_builds.gd` / `data/build_profiles.json` |
| **Tout l'équipement à +N** (porté, coût total, arrêt si manque) | S | `ui/forge_bench.gd` |
| **Titres dans Héros** (onglet), titre porté sous le nom | S | `ui/hero_screen.gd`, `ui/carnet_pages.gd` |
| **Registre v2** : jauge par classe, « il manque » en premier, bouton « ★ suivre » | S | `ui/registry_page.gd` |
| **Ouvrir tout** des coffres avec révélation par rareté (BIBLE « Récompense ») | S | `ui/chests_page.gd`, `ui/chest_stage.gd` |
| **Jalons du niveau de héros** : la barre dit « niv. 53 : Casque du Bouclier antique portable » ; onomatopée « Niveau ! » en partie | S | `ui/hero_level_gauge.gd`, `core/hero_level.gd`, `ui/hud.gd` |

### P2 — finitions et confort

Verrou automatique par règle (« garder les légendaires de ma classe », Genshin) · indicateur « Idéale pour : profil Puissance (13 classes) »
· comparer avec un autre préréglage ou une classe de la famille (LB / RB dans l'infobulle) · apparence : essai au survol, tenue enregistrée
par préréglage, provenance des apparences verrouillées · rareté lisible sans couleur (lettre C / S / R / É / M / L dans le coin, forme du
cadre) · détail « pourquoi cette PE » (part de chaque pièce) · Réajuster « garder l'ancien jet » (Q3) · filtre de butin des coffres de
partie (masquer ce qui est plus faible partout, à la Path of Exile) · plans de donjon : vue des 48 en silhouettes par zone.

---

## 8. Spécification « version 2 » (DA autocollant manga)

Maquettes : `equipement_maquettes/v2_heros.svg`, `v2_infobulle.svg`, `v2_atelier.svg`, `v2_forge.svg` (tailles à 1600×900, × 0,8 à 1280×720).

**Héros > Équipement** (`v2_heros`). En-tête : « Héros » Mochiy incliné ; pastille d'encre « Niv. 34 » + barre pomme ; carte papier
« Puissance 5 960 » avec la jauge **vers la difficulté suivante** (soleil) et l'écart (« −1 240 ») ; carte de classe soleil (icône, nom,
profil, maîtrise, titre). Navigation verticale : Équipement, Classe, Apparence, **Titres** (onglet actif mandarine, pastille fraise =
nouveauté). Panneau papier : préréglages en vrais onglets (actif mandarine qui dépasse), bouton lagon « Le meilleur ▲3 » ; poupée 10 cases
autocollantes (rareté en deux tons, +N dans une pastille d'encre, ▲ pomme si le sac a mieux, « ! » fraise si vide) ; panoplie en
pastilles ; stats avec l'écart de la pièce survolée. Sac en puits d'encre : recherche, tri « Pour ma classe », pastilles de filtre
(Ma classe, Portables, Nouveautés, Gardées, Inutiles) ; cases : ▲, « neuf » mandarine incliné, 🔒, fond fraise + niveau si trop haut, voile si
plus faible partout ; barre d'actions en masse (Démonter en fraise avec maintien, Garder, Annuler). Bas : **barre d'objectif** soleil.

**Infobulle** (`v2_infobulle`). Bandeau de rareté avec icône, nom blanc contouré, « rareté · emplacement · niveau · type d'armure »,
+N en pastille ; **verdict** (pomme / papier / fraise) + PE et écart ; stat principale en Mochiy 40 ; 3 stats ★ (profil) avec écarts,
le reste en gris sur une ligne ; gemmes dessinées ; enchantement ; panoplie en pastilles (claire = ajoutée par cette pièce) ; **provenance** ;
pied de touches (Maj, X, L, F). Carte portée à droite, réduite, alignée. Niveau trop haut : bandeau fraise à la place du verdict.
Apparition 300 ms, ressort 160 ms depuis 0,9, queue vers la case.

**Atelier > Fabriquer** (`v2_atelier`). Colonne des paliers (puits) avec jauges x / 9 ; palier de « ta bande » en lagon ; pastilles de
filtres. Centre : la **poupée du palier** (9 grandes cases : pleine = fabriquée, voilée = plan connu avec prix, trame = plan à trouver avec
le lieu) ; « Fabriquer les N plans connus · total ». Droite : carte de la pièce (verdict, stats, panoplie), encadré « Plan trouvé / Niveau »,
jauge d'insignes (« il en restera 220 » ou « il en manque 37 ≈ 1 carte d'Aventure »), bouton primaire soleil « Fabriquer · 83 », « Fabriquer
et porter » (lagon), « ★ Objectif ».

**Atelier > Forge > Améliorer** (`v2_forge`). Établis en onglets (+ « Reporter »). Liste des pièces portées d'abord (+N en pastille) et
« Tout l'équipement à +5 ». Centre : pièce, « +5 → +6 » Mochiy, **piste des 10 crans** (paliers à stat bonus marqués), tableau avant → après
(dont la puissance du héros), anneau de chance, **jauge de persévérance** améthyste avec ce qu'un échec ajoute, phrase d'échec non punitive,
bloc « Viser +8 · attendu ≈ 190 · au pire 260 · tu en as 420 », bouton primaire « Fortifier · 44 ». Retours : à droite de la maquette.

**Règles chiffrées proposées (à mesurer)** : persévérance + (1 − chance) × 50 % par échec ; chance + 10 % de la base par échec, plafond
× 1,5 ; plus aucune rétrogradation ; Reporter = +N − 2 ; objectif 1 + 5 ; préréglages 5. Aucun changement de prix des insignes ou des
cristaux dans ce lot : le coût attendu baisse un peu (plus de rétrogradation) ; si `progression_sim` montre le kit +10 plus de 2 h plus
tôt, relever `Forge.upgrade_crystals` plutôt que remettre du risque.

---

## 9. Questions ouvertes (recommandation)

| # | Question | Recommandation |
|---|---|---|
| Q1 | Supprimer la rétrogradation de la Forge (+6 et au-delà) au profit d'une jauge de persévérance ? | **Oui** : c'est le seul « remonter ce qu'on avait » du jeu ; la pitié garde l'émotion du tirage sans la perte (Lost Ark garde le frisson, WoW la sérénité : nous prenons les deux) |
| Q2 | Reporter le +N d'une pièce sur sa remplaçante (REFONTE Q8 « non pour l'instant ») ? | **Oui, à −2 crans** : l'échelle 1-90 change de pièce 12 fois par emplacement ; sans report, l'opti des 60 classes est une corvée de Forge. Mesurer avant (`progression_sim`, kit +10) |
| Q3 | Réajuster : le nouveau jet remplace-t-il l'ancien même s'il est moins bon ? | **Choix après tirage** (garder l'ancien ou le nouveau), comme Polir garde le meilleur ; coût inchangé |
| Q4 | Verdict de comparaison : profil de la classe ou PE commune ? | **Profil** pour le mot (Meilleure / Moins bonne), **PE** pour le chiffre ; Maj montre les deux |
| Q5 | Combien d'objectifs ? | **1 épinglé + 5 suivis** ; plus = liste de souhaits qu'on n'ouvre plus |
| Q6 | Préréglages par classe : 3 → 5 ? | **5**, nommés par usage, choisis sur la page de l'activité |
| Q7 | Verrou : par objet seulement, ou règles automatiques ? | **Par objet en P0** ; règles (« légendaires de ma classe ») en P2 |
| Q8 | Garder le sac illimité ? | **Oui** (mieux que les MMORPG) ; « Inutiles » + démontage en masse suffisent |
| Q9 | Titres dans l'écran Héros ? | **Oui** (onglet), le Carnet garde la collection |

---

## Annexe — reproduire les captures

Copie propre de HEAD : `python -c "import sys; sys.path.insert(0,'tools'); import run_tests as r; from pathlib import Path;
p=r.preparer_copie(Path(r'C:/AI/bmgear_snap')); r.importer(r.trouver_godot(None), p, Path(r'C:/AI/bmgear_snap/ud'))"`, puis pour chaque
outil, APPDATA détourné : `Godot --path C:/AI/bmgear_snap/game res://tests/shot_hero.tscn` (de même `shot_atelier`, `shot_h3`,
`shot_registry`, `shot_tips` avec `SHOT_DIR`). Les images restent hors dépôt (`C:\AI\benchmark_refs\equipement\eden_slash_nous\`).
Rendu des maquettes : Edge sans tête, `--screenshot`, 1600×900 (polices Mochiy Pop One / M PLUS Rounded 1c installées sinon repli).
