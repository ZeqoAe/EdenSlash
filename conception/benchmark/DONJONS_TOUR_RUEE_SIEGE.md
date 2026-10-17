# Donjons, Tour, Ruée et Siège face aux MMORPG : étude comparative (BM-DNG, 17/10/2026)

Mandat du joueur : « s'inspirer des MMORPG ; reprendre des images des concurrents pour analyser et comparer avec le nôtre, nos points
faibles ; HUD, UI / UX, profondeur, confort ; dans notre nouvelle DA », **sans la corvée** (précision du 17/10, `METHODE.md`). Méthode :
`METHODE.md`. DA : `art/BIBLE.md` v2. Nos règles : DESIGN « Bibliothèque de boss », « La Tour », « Ruée et Siège » ; rapports
`nuit_15_10/R_M2.md`, `R_M3.md`, `R_M6.md`, `R_M8.md`, `R_P11.md`, `progression/R_A2.md`. Croquis maison : `donjons_maquettes/` (SVG,
ouvrir dans un navigateur). Images de référence et nos captures : **hors dépôt**, `C:\AI\benchmark_refs\donjons\` (`wow`, `ffxiv`,
`gw2_ui`, `lost_ark`, `eso`, `hades`, `monster_hunter_wilds`, `_planches`, `eden_slash_606f6b10`). Aucun texte, image ou son tiers ici : on décrit.

**Verdict en une phrase** : le **fond** est au niveau des bons MMORPG solo (48 boss à briques, donjon au choix de la pièce voulue, plan
garanti, butin sans doublon, Tour à types d'étage avec Ombres, Ruée à graine et modificateurs, PE conseillée lisible) ; ce qui fait
« prototype », c'est **la lecture du combat** (barre de boss muette : ni seuils réels, ni mécanique en cours, ni minuteur de fureur ; aucune
frise de ce qui arrive ; annonces en bandeau seul, sans son ; télégraphes rouge plein qui couvrent l'écran), **l'après-combat** (aucun
« qu'est-ce qui m'a tué ? », aucun temps record, butin non montré), **la mémoire** (pas de journal des rencontres, records = simples
compteurs) et **la DA** (encore l'ancien bleu nuit à filet doré, pages de texte sans portrait de boss).

---

## 1. Sources et ce qui a été vérifié

| Référence | Ce qu'on a regardé (images dans `C:\AI\benchmark_refs\donjons\`) | Sources écrites (consultées le 17/10/2026) |
|---|---|---|
| World of Warcraft (Midnight 12.0, The War Within) | 5 images de l'article officiel « Midnight : interface » (frise de combat, alertes, compteur de dégâts, barre personnelle) | Blizzard, *Midnight: Get up to Speed with User Interface Updates* ; warcraft.wiki.gg (Adventure Guide, Delves, Bountiful delves, API DeathRecap) ; Wowhead / Raider.io (affixes de la saison 3) ; Icy Veins (Delves) |
| Final Fantasy XIV (7.x) | fenêtre « Duty Finder » et « Raid Finder » (wiki), 8 vues de Pilgrim's Traverse, 8 vues Steam | consolegameswiki : Duty Finder, Pilgrim's Traverse, Mechanics, Duty Support / Trust ; Prima Games (Variant) |
| Lost Ark | 8 vues Steam (sans HUD) | Upcomer (combat : jauge de chancellement, contre), Zockify / KeenGamer (Valtan : barres de PV comptées), PlayNews (Contre et Parade parfaite, 09/2026) |
| Guild Wars 2 | fenêtre de choix des fractales (wiki officiel), 8 vues Steam | wiki.guildwars2.com (Fractals of the Mists), annonce officielle « Upcoming Changes for the Fractals » |
| Elder Scrolls Online | 6 vues Steam (sans HUD) | ESO-Hub (Infinite Archive, guide et bilan du 1er mois), forums officiels |
| Genshin Impact | aucune image (wiki Fandom refusé) | Timesaver / AllThingsHow (Abîme spiralé, cycles), Icy Veins / BossRush (Stygian Onslaught) |
| Hades | 8 vues Steam **avec HUD** (deux barres de boss, Défi de la mort, bénédictions) | Prima Games, RPG Site (Pacte de punition), Fextralife (mode Dieu) |
| Monster Hunter (World / Wilds) | 8 vues Steam Wilds (sans HUD) | Prima Games (Notes du chasseur, World), Gamer Guides (faiblesses, Wilds) |
| **Eden Slash** (HEAD `606f6b10`, v0.1.256, copie propre) | **83 captures 1600×900** : `shot_m2` (13), `shot_m3` (16), `shot_m6` (15), `shot_m8` (22), `shot_p12` (7), `shot_m1` (10) | code : `ui/hud.gd`, `ai/boss_brain.gd`, `ai/boss_bricks.gd`, `combat/telegraph.gd`, `ui/dungeon_page.gd`, `ui/*_results.gd`, `core/dungeons.gd` |

Limites : aucune partie jouée des références (pas de client, pas de compte). Les vues Steam de FFXIV, Lost Ark, ESO et Monster Hunter sont
des images promotionnelles **sans HUD** : leurs HUD de combat sont décrits d'après les wikis et guides, marqués **non vérifié (visuel)**.
warcraft.wiki.gg sert ses images derrière une vérification anti-robot : non contournée, le Journal des rencontres est décrit d'après le texte du wiki.

---

## 2. Ce qui fait la qualité de chaque référence

### World of Warcraft : la mécanique se lit avant, pendant et après
- **Frise des mécaniques (Midnight 12.0, vérifié sur l'image officielle)** : colonne verticale à droite, une icône par capacité à venir avec son
  **compte à rebours**, couleur de cadre selon la gravité (rouge = critique, orange, bleu) ; trois tailles d'**alertes texte au centre**
  (« mineure, moyenne, critique ») ; une **barre d'incantation agrandie et surlignée** pour les sorts mortels à interrompre ; alerte quand
  on est ciblé. Tout est réglable dans le mode d'édition (orientation, taille, transparence, minuteur). Blizzard intègre ce que les joueurs
  demandaient aux add-ons : c'est le standard 2026.
- **Compteur de dégâts intégré** (serveur, par rencontre, détail par sort). **Récap de mort** : l'API rend les 5 derniers coups subis ;
  la fenêtre du jeu est **non vérifiée** ici.
- **Journal des rencontres (Adventure Guide)** : par boss, onglets **Aperçu**, **Capacités**, **Butin**, **Modèle 3D** ; icônes « tank /
  dégâts / soins » sur les capacités, icônes « Héroïque seulement » / « Mythique seulement » ; contenu suggéré selon le niveau, un clic
  pour chercher un groupe (texte du wiki, image non vue).
- **Mythique+** : clé de niveau croissant, minuteur, **affixes** qui tournent chaque semaine et s'ajoutent par paliers de clé (+4, +7, +10, +12 ;
  à +12 en saison 3, chaque mort retire 15 s, vérifié Wowhead / Raider.io). Coffre hebdomadaire (Grande Chambre forte) : **non vérifié** ici.
- **Gouffres (Delves)** : le donjon solo de WoW. Paliers 1 à 11, **un compagnon IA** (Brann, rôle dégâts ou soins, équipé de « curios »),
  **4 gouffres « généreux » par jour** (coffre bonus), affixe de saison dès le palier 4 dont le nettoyage augmente le butin (vérifié wiki).
  C'est la référence la plus proche de nos Donjons solo avec alliés IA.

### Final Fantasy XIV : le confort d'entrée et le donjon profond
- **Recherche de mission** (vérifié, image) : fenêtre unique, en tête niveau, classe, **niveau d'objet**, rôle ; liste par catégories
  (roulettes, donjons, épreuves, raids) avec niveau requis et **icône de bonus** ; réglages : groupe non restreint (avec bonus « Écho »
  qui renforce PV et dégâts), **mode Explorateur** (visiter un donjon fini sans ennemis), niveau d'objet minimal, partir sans pénalité si
  on rejoint en cours. **L'Écho** renforce l'équipe dans les vieux contenus et après des échecs : la difficulté baisse sans qu'on le demande.
- **Soutien de mission / Trust** (vérifié wiki) : 3 PNJ alliés pour faire seul les donjons ; PNJ volontairement moins forts (≈ 20-30 min) ;
  si le joueur tombe, l'équipe échoue, mais le buff **Volonté** donne des vies supplémentaires aux boss.
- **Donjons « Variante »** (vérifié Prima) : 1 à 4 joueurs, **12 fins** selon les chemins choisis, actions spéciales qui remplacent les rôles.
- **Pilgrim's Traverse** (7.35, vérifié wiki) : 100 étages, un boss tous les 10, **points de reprise 1, 21, 31, 51, 71**, 2 sauvegardes ;
  **pomandres** (objets à usage unique trouvés en coffre, 3 de chaque au plus) et **votives** à activer (effet sur l'étage suivant, positif
  seulement avant l'étage 30) ; équipement propre au donjon qui monte jusqu'à +99 ; un compteur de chutes rend une sauvegarde rouge ;
  **classement quotidien** au-delà de l'étage 30 ; jouable seul.
- **Grammaire des télégraphes** (vérifié wiki « Mechanics ») : cercle, beignet, cône, ligne, tour, attache, regard, marqueurs au-dessus de
  la tête (se regrouper / se disperser / coup de tank) : un **vocabulaire visuel fixe** que tout joueur apprend une fois.

### Lost Ark : le combat de boss lisible en action vue de dessus
- **Barres de PV comptées** (« ×160 ») : les mécaniques tombent à des **nombres de barres annoncés** (Valtan porte 2 : 130, 110, 85, 65, 30, 16 ;
  vérifié Zockify / Mobalytics) ; tout le groupe parle le même langage. **Jauge de chancellement** violette sous la barre : la vider étourdit
  le boss ; **contre** : le boss qui prépare une attaque **brille en bleu**, un sort de contre l'annule (vérifié Upcomer). Septembre 2026 :
  « Contre et Parade parfaite » ajoutés à 7 gardiens (PlayNews). Visuel du HUD : **non vérifié** (pas d'image avec HUD).

### Guild Wars 2 : la fractale, échelle infinie et instabilités du jour
- **Choix d'échelle** (vérifié, image) : niveau de fractale perso et **résistance à l'agonie** en tête, 4 onglets de palier (Initié, Adepte,
  Expert, Maître : 1-25 … 76-100), liste des 25 échelles, **marqueur des quotidiennes**, ligne de résumé « AR conseillée 150 · joueurs
  conseillés 5 », « fractale au hasard du palier ». **Instabilités** (modificateurs) tirées chaque jour : 1 dès l'échelle 26, 2 dès 51, 3 dès 76.

### Elder Scrolls Online : l'Archive infinie (la Tour d'un MMORPG)
- Étapes → cycles (boss) → arcs (gros boss) ; **un « verset » à choisir après chaque étape, une « vision » après chaque cycle** (pouvoirs
  de run) ; seul, avec un compagnon PNJ ou à deux ; **classements séparés solo / duo** ; sans chrono, ce qui crée des égalités en tête
  (critique relevée sur les forums). Vérifié ESO-Hub ; visuel non vérifié.

### Genshin Impact : étoiles au chrono et défi de boss à 6 paliers
- **Abîme spiralé** : remise à zéro le 16 de chaque mois ; **3 étoiles par salle selon le temps restant** (ex. 180 / 300 / 420 s) ; un
  « trouble des lignes » (modificateur) par moitié. **Stygian Onslaught** (2025) : 3 boss par cycle, **6 difficultés**, les plus hautes
  imposent des restrictions et le solo ; récompenses de fin de paliers en cosmétiques. Vérifié (guides) ; visuel non vérifié.

### Hades : la sobriété et la seconde chance
- **Barres de boss fines en haut au centre**, nom au-dessus, sans chiffres ; **deux barres** quand deux boss se battent ensemble (Thésée
  et le Minotaure, vérifié image) ; PV du héros en bas à gauche avec le **compteur de Défi de la mort (1/3)** juste à côté.
- **Pacte de punition** : la difficulté est un menu de crans choisis (Chaleur), dont « Mesures extrêmes » qui **ajoute des techniques aux
  boss**, région par région ; **mode Dieu** : −20 % de dégâts, +2 % à chaque échec, 80 % au plus, sans aucune pénalité (vérifié).

### Monster Hunter : apprendre le monstre
- **Notes du chasseur** : par monstre, nombre chassé / capturé, plus petit et plus grand, habitats, **faiblesses** (World, vérifié Prima).
  Quête qui échoue après 3 chutes : connu, **non vérifié** dans cette étude.

---

## 3. Nos écrans, un à un (captures 1600×900, `eden_slash_606f6b10\`)

| Critère | Eden Slash (ce qu'on voit) | Les meilleurs | Écart |
|---|---|---|---|
| **Télégraphes** | zones rouges qui se remplissent, cercle sûr vert, mur d'arène (`m2_boss_*`) ; **aucun son** (`telegraph.gd`) ; au Siège et au Cercle sûr, le rouge **couvre tout l'écran** (`m2_boss_alonzo`, `m6_siege_chacun_pour_soi`) : on ne voit plus où aller | FFXIV : formes fixes à bord net ; WoW : alerte sonore + texte selon la gravité | **gros** |
| **Annonces** | bandeau en haut au centre, ancien style, un seul niveau ; au Siège il **déborde** sur la mini-carte et dit « **Doubledoor** » en anglais alors que la barre dit « Double-porte » (`m6_siege_boss`, texte figé dans `data/zones.json` l. 228) | WoW : 3 niveaux, court, configurable | **gros** (+ bug) |
| **Barre de boss** | nom, « BOSS · Nv », PV exacts, trace des dégâts, **une encoche à 50 %** (`hud.gd` l. 602) qui ne correspond pas aux seuils réels des briques (70 %, 35 %, 30 %…) ; ni mécanique en cours, ni incantation, ni minuteur de fureur (l'Impatience, la rage du boss existent pourtant) ; la barre **cache le boss** quand il est en haut de l'écran (`m6_ruee_boss1`, `m6_siege_boss`) | Lost Ark : seuils comptés ; WoW : incantation surlignée ; Hades : fine, ne cache rien | **gros** |
| **Ce qui arrive** | rien : les briques ont pourtant des minuteurs connus (`every`, `first`, seuils `at` dans `BossBricks.DEFS`) | WoW Midnight : frise avec comptes à rebours | **gros, et facile chez nous** |
| **Entrée du donjon** | page riche mais **en texte** : boss, mécaniques en mots, pièces, PE conseillée + estimation, récompenses (`m8_donjon`) ; liste de 48 tuiles texte sans portrait ni statut (`m8_donjon_bas`) ; l'état de la difficulté choisie peut prêter à confusion (`m2_arene_mythique` : Normal paraît sélectionné, les chiffres sont ceux du Mythique) | FFXIV : une fenêtre, niveau d'objet en tête ; GW2 : résumé « AR conseillée · joueurs conseillés » ; WoW : modèle 3D + butin en cases | moyen |
| **Progression** | « Salle n/3 », « Étage 12/200 · Ombre », « Boss 3/8 · Ensuite : Buster » (`m8_hud_*`) : bon | M+ : minuteur + paliers ; Abîme : étoiles au chrono | petit (manque le chrono) |
| **Journal des rencontres** | aucun ; les mécaniques ne sont lisibles que sur la page de donjon et la fiche d'étage (`m8_fiche_10_boss`, bonne fiche) | WoW : journal par boss ; MH : notes de chasse | **gros** |
| **Records** | compteurs de victoires (`dgb_<boss>_<diff>`, `Dungeons.reward`), étage record de la Tour ; **aucun temps** | Abîme, Archive, M+ : temps, étoiles, classements | **gros** |
| **Choix de difficulté** | 3 boutons + jauge de PE et estimation Facile → Hors de portée (bon, `DifficultyPanel`) | GW2 / FFXIV : même idée | petit (on fait aussi bien) |
| **Rejouabilité** | Ruée : graine affichée + 3 modificateurs choisis ; Siège : boss du jour ; **rien d'hebdomadaire**, rien de « vedette » | M+ et fractales : affixes tournants ; Gouffres : « généreux du jour » | moyen |
| **Butin** | coffre de set 3 pièces au choix, **jamais un doublon**, plan garanti à la 1re victoire (mieux que la plupart) ; mais le bilan dit « Coffre de set ×1 » sans montrer la pièce (`m8_bilan_donjon`) | WoW : butin en cases sur le journal et le bilan | moyen |
| **Mort et reprise** | une vie ; « Rejouer » au même donjon / même tirage ; Tour reprend par palier de 10 ; **aucune relève** | FFXIV : Volonté (vies aux boss) ; Hades : Défi de la mort | moyen |
| **« Qu'est-ce qui m'a tué ? »** | rien : le bilan d'échec (`m8_bilan_tour`, `m6_ruee_bilan`) donne étage, durée, butin | WoW : récap des 5 derniers coups | **gros** |
| **Accessibilité** | aide au combat (Assisté, Bot), lisibilité des effets `fx_factor` (jamais les zones) ; **aucun mode daltonien**, aucun indice de forme (danger et sûr ne diffèrent que par la couleur), aucune alerte sonore | WoW : alertes sonores réglables ; Hades : mode Dieu | moyen |
| **Manette** | tout se joue à la manette (`UiNav`, A / B / LB / RB) : **on fait aussi bien ou mieux** | FFXIV : très bonne manette (non vérifié ici) | aucun |
| **Tutoriel de mécaniques** | le conseil de chaque brique (« passe dans son dos quand il te fixe ») est bien écrit et montré à l'entrée ; aucune démo, aucun essai | Pas de vrai modèle chez les MMO (guides externes) ; Lost Ark : salle d'essai (non vérifié) | moyen |
| **Siège à 3** | chacun pour soi, objectifs ★ ; le panneau « Dégâts cumulés » **sort de l'écran** à droite (`m6_siege_boss`) ; pas de tableau des 3 joueurs | Hades : deux barres côte à côte ; arènes : tableau des scores | moyen (+ bug) |

**Artefacts de capture, pas des bugs du jeu** : « Salle 4/3 » vient de `shot_m2.gd` (`tower.begin(4)`, ancien donjon à 4 salles,
obsolète depuis A2) ; « Rejouer (étage 1) » après une chute à l'étage 12 dans `shot_m8` vient de l'état préparé par le script : à
vérifier en partie réelle (la reprise doit proposer l'étage 11). Le héros caché dans le boss (`m8_hud_tour_boss`) : position imposée par le script.

---

## 4. Profondeur

| Thème | Nous | Références | Lecture |
|---|---|---|---|
| Variété des boss | 48 boss, 2 à 4 briques parmi 29 (10 familles), PV fixes, palier qui accélère, Impatience en Mythique | WoW / FFXIV : chaque boss écrit à la main ; Lost Ark : phases à seuils | **Force** en nombre ; **faiblesse en signature** : une brique a les mêmes effets chez tous les boss (R_M2 « signatures visuelles propres : pas encore ») ; aucun boss n'a de phase scénarisée ni de « coup signature » nommé |
| Paliers | Normal / Héroïque / Mythique (+ Facile / Difficile / Hardcore à la Tour) | M+ (infini), fractales 1-100, Stygian 6 paliers | correct ; au-delà du Mythique, rien qui monte sans fin (sauf la Tour) |
| Farm sans corvée | choisir le boss qui donne la pièce voulue, pas de doublon, plan garanti, 5-6 min | Gouffres généreux, affixes, Abîme mensuel | très bon socle ; manquent **un défi chronométré facultatif** et **une raison hebdomadaire de varier** (sans obligation) |
| Rythme de la Tour | 10 étages : monstres + élite à mécanique, 2 Ombres, élites, maudit, halte, boss (M3) | Archive ESO : choix de pouvoir après chaque étape ; Traverse : objets d'étage | bon ; **manque de choix entre les étages** (seule la halte donne une carte) et d'objets d'étage |
| Ombres | ta classe 1 fois sur 4, cerveau du Panthéon dès l'étage 100 Hardcore | aucun équivalent direct (le plus original de nos modes) | à mettre en scène : intro, nom, « ton ombre » mise en avant |
| Ruée | 8 boss à graine, 3 modificateurs, carte et 50 % PV entre deux | Hades (enchaînement Thésée), Stygian | bon ; manquent **temps par boss**, meilleur tirage, partage de graine |
| Siège | boss du jour × 3,2, vagues en escouades, lieutenants, chacun pour soi, 3 étoiles | aucun MMO ne fait du « JcE en chacun pour soi » | original ; manquent la **lisibilité de la compétition** (qui mène ? qui a pris la dernière frappe ?) et une coopération forcée au boss (« trêve » quand il enrage) |

---

## 5. Tableau d'écarts

| Ils font mieux | On fait mieux | Il nous manque |
|---|---|---|
| frise des mécaniques à venir (WoW) | choix du boss par la pièce voulue (filtre pièce / panoplie / mécanique) | journal des rencontres |
| barre de boss à seuils parlants (Lost Ark), incantation surlignée (WoW) | butin sans doublon + 3 pièces au choix + plan garanti | temps record, étoiles au chrono |
| alertes à 3 niveaux, avec son | PE conseillée + estimation lisible avant d'entrer | récap de mort |
| télégraphes à formes fixes (FFXIV) | manette partout | défi hebdomadaire facultatif |
| butin montré en cases (WoW, journal et bilan) | Ombres (IA qui joue ta classe) | relève (seconde chance) en Normal |
| seconde chance sans honte (mode Dieu, Volonté, Écho) | une seule bibliothèque de boss pour 4 activités | portrait / modèle du boss sur les pages |
| choix de pouvoir entre étapes (Archive ESO) | modificateurs de Ruée au choix, cumulables | objets d'étage dans la Tour |

---

## 6. Détails de confort relevés (à reprendre tels quels)
1. Compte à rebours **sur** l'icône de la prochaine mécanique (WoW) ; la couleur du cadre dit la gravité.
2. Incantation dangereuse : barre plus grande, couleur vive, nom du coup (WoW 12.0).
3. Seuils de PV **dessinés** sur la barre là où une mécanique se déclenche (Lost Ark).
4. Deux boss en même temps : deux barres côte à côte, l'inactif estompé (Hades).
5. Le compteur de secondes chances **collé aux PV** (Hades « 1/3 »).
6. Résumé d'entrée en une ligne : « conseillé · ta valeur · joueurs » (GW2).
7. Marqueur « quotidienne / bonus » dans la liste de choix (GW2, FFXIV).
8. « Au hasard » dans la liste (GW2 « Random Tier 1 Fractal »).
9. Mode Explorateur : revisiter une salle de boss sans ennemis (FFXIV) → notre « S'entraîner ».
10. Étoiles au chrono avec les seuils affichés à l'avance (Genshin).
11. Reprises à des étages fixes et sauvegardes multiples (FFXIV Traverse).
12. Les 5 derniers coups subis à la mort (WoW).
13. Difficulté qui baisse d'elle-même après des échecs, sans menu (FFXIV Écho, Hades mode Dieu) → à proposer, jamais imposé.

---

## 7. Backlog
Taille : **S** ≤ 1 jour, **M** 2-4 jours, **L** ≥ 1 semaine. Fichiers à la date de HEAD `606f6b10`.

### P0 : sans ça, les modes de boss font « prototype »
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| P0-1 | **Barre de boss v2** : portrait, difficulté, seuils **réels** des briques `at` (pastille couleur de famille), trace, % au centre (PV exacts en infobulle), minuteur de fureur (Impatience, rage du boss de la Survie), pastilles des mécaniques du boss avec l'active surlignée ; la caméra / la barre ne cachent jamais le boss (flèche hors écran sinon) | M | `ui/hud.gd` (cadre cible → `ui/boss_bar.gd` nouveau), `ai/boss_brain.gd` (signaux `brick_started` / `brick_ended`, `thresholds()`), `core/camera_rig.gd` |
| P0-2 | **Frise « À venir »** : prochaines mécaniques et comptes à rebours, calculés par `BossBrain` (périodiques × rythme, seuils en % PV), option dans Paramètres (affichée par défaut) | M | `ai/boss_brain.gd` (`upcoming(n)`), `ui/boss_timeline.gd` nouveau, `ui/settings_menu.gd` |
| P0-3 | **Annonces à 3 niveaux** (mineure : texte seul ; moyenne : bulle lagon ; critique : bulle fraise + son), ≤ 28 signes, jamais hors écran ; noms toujours français (« Doubledoor » de `zones.json` passe par `NamesFr` ou est réécrit) | S | `ui/hud.gd` (`_banner`), `core/run_director.gd` (`message` + niveau), `data/zones.json`, `combat/sfx.gd`, `tests/test_texts_fr` |
| P0-4 | **Télégraphes v2** (BIBLE § 10) : bord net clair 2 px + contour d'encre, intérieur ≤ 35 % qui monte, **hachures** sur le danger et **pointillés** sur le sûr (lisible sans la couleur) ; quand le danger couvre plus de la moitié de l'écran, on peint le sûr, pas le danger ; un son court à l'armement des zones de boss | M | `combat/telegraph.gd`, `shaders/` (effets au sol), `ai/boss_bricks.gd` (`safe_zone`, `shrink`, `gale`), `combat/sfx.gd` |
| P0-5 | **« Ce qui t'a battu »** : tampon des 8 dernières secondes de coups subis (source, mécanique, part des PV), 3 lignes + le **conseil de la brique** fautive, dans tous les bilans d'échec (Donjon, Tour, Ruée, Siège, Survie) | M | `combat/combatant.gd` ou `player/player.gd` (tampon), `ui/results_panel.gd`, `ui/dungeon_results.gd`, `ui/tower_results.gd` |
| P0-6 | **Temps et records** : meilleur temps par boss et difficulté, par donjon, par tranche de 10 étages, par tirage de Ruée (et par boss de la Ruée) ; « Record ! » au bilan | S | `core/dungeons.gd` (`reward` : durée), `core/rush.gd`, `core/tower.gd`, `ui/*_results.gd` |
| P0-7 | **Bilan v2** (maquette `v2_bilan.svg`) : butin **montré en cases** (la pièce, son gain de puissance), temps vs record, étoiles d'objectifs, prochaine pièce manquante, boutons Rejouer / Autre boss / Menu ; défaite : « Réessayer le boss » et « S'entraîner » | M | `ui/results_panel.gd`, `ui/dungeon_results.gd`, `ui/tower_results.gd`, `core/rewards.gd` (ouvrir le coffre de set au bilan) |
| P0-8 | **Page Donjons v2** (maquette `v2_selection_donjon.svg`) : portrait / rendu du boss, mécaniques en pastilles icône + conseil, butin en cases (possédé coché), difficulté en onglets nets (corrige l'état ambigu), record et étoiles, statut N / H / M sur chaque tuile de la liste | M | `ui/dungeon_page.gd`, `ui/lobby.gd`, `ui/difficulty_panel.gd`, `ui/item_widgets.gd` |
| P0-9 | **Journal des rencontres** (Carnet > « Rencontres », maquette `v2_journal_rencontres.svg`) : 48 fiches vaincu / rencontré / à découvrir, mécaniques vues (compteur), records par difficulté, butin, « Aller à son donjon » | M | `ui/carnet_pages.gd` (onglet ajouté **à la fin**), `ui/encounter_journal.gd` nouveau, `core/boss_library.gd`, `Profile.records` (`seen_<brique>`, `met_<boss>`) |
| P0-10 | **Corrections visibles** : panneau « Dégâts cumulés » hors écran au Siège, bandeau qui déborde, `shot_m2` mis à jour (3 salles) et test de non-débordement du HUD de boss à 1280×720 et 1600×900 | S | `ui/hud.gd` (`_dmg_box`), `tests/shot_m2.gd`, `tests/test_hud.gd` |

### P1 : ce qui fait la qualité
| # | Lot | Taille | Fichiers |
|---|---|---|---|
| P1-1 | **Étoiles de donjon** (comme le Siège) : ★ fini, ★ sous un temps affiché à l'avance (mesuré : médiane du pilote × 1,3), ★ sans tomber ; +cristaux par étoile neuve, jamais requis pour le butin | S | `core/dungeons.gd`, `ui/dungeon_page.gd`, `ui/dungeon_results.gd` |
| P1-2 | **Défi de la semaine, facultatif** : un « donjon vedette » (+1 coffre de matières la 1re victoire de la semaine) et un modificateur commun aux Donjons / Ruée / Tour (au choix, cristaux en plus) ; jamais de perte si on l'ignore | M | `core/challenge.gd`, `core/rush.gd` (modificateurs réutilisés), `core/dungeons.gd`, `ui/dungeon_page.gd` |
| P1-3 | **Relève** (seconde chance) : 1 par boss en Normal et Héroïque, 0 en Mythique et dans la Tour Hardcore ; compteur collé aux PV ; les alliés IA peuvent te relever | M | `player/player.gd`, `core/tower_director.gd`, `ai/class_rival.gd`, `ui/hud.gd` |
| P1-4 | **S'entraîner** contre un boss : salle d'essai, héros invincible au choix, mécanique à rejouer à volonté, sans butin (le moteur `Training` existe) | M | `core/training.gd`, `ui/training_panel.gd`, `core/boss_library.gd` |
| P1-5 | **Première rencontre d'une mécanique** : ralenti de 0,5 s + bulle « Regard : passe dans son dos » la 1re fois seulement (journal coché) | S | `ai/boss_brain.gd`, `ui/hud.gd`, `core/tutorial.gd` |
| P1-6 | **Coups signatures** : chaque boss renomme et recolore ses briques (« Pluie céleste de Latif ») et garde un « coup fétiche » propre ; une phase scénarisée à 50 % pour les 8 gardiens | L | `data/bosses.json`, `ai/boss_bricks.gd` (paramètres d'aspect), `assets/fx` |
| P1-7 | **Tour : choix entre étages** façon Archive : après chaque étage d'élites ou d'Ombre, 1 « faveur » parmi 3 (petit pouvoir de run) ; objets d'étage (bombe, bouclier) dans les coffres maudits | M | `core/tower_director.gd`, `core/tower.gd`, `ui/card_picker.gd` |
| P1-8 | **Ombres mises en scène** : carte d'intro (portrait de la classe, « Ton ombre » en mandarine), barre d'adversaire au style héros, cri de victoire | S | `core/tower_director.gd`, `ui/hud.gd` |
| P1-9 | **Siège lisible** : tableau des 3 (dégâts au boss, chutes, dernier coup), « trêve » annoncée quand le boss enrage, deux barres si lieutenant et boss ensemble | M | `core/siege_director.gd`, `ui/team_bars.gd`, `ui/hud.gd` |
| P1-10 | **Ruée chronométrée** : temps par boss (fil des temps à droite), meilleur tirage, graine copiable et « Rejouer ce tirage » | S | `core/rush_director.gd`, `core/rush.gd`, `ui/dungeon_results.gd` |
| P1-11 | **Accessibilité** : palette des télégraphes réglable (rouge / mandarine / améthyste), formes toujours doublées (hachures / pointillés), alertes sonores par gravité, « Aide douce » qui baisse les dégâts reçus de 10 % après 3 échecs sur le même boss (proposée, jamais imposée) | M | `core/settings.gd`, `ui/settings_menu.gd`, `combat/telegraph.gd`, `core/dungeons.gd` |
| P1-12 | **Passage DA v2** des pages Donjons / Tour / Ruée / Siège et des bilans (papier, puits d'encre, onglets mandarine, primaire soleil) | M | dépend du socle `UiTheme` v2 / `UiFeel` |

### P2 : finitions
- Compteur de dégâts de rencontre (par sort) consultable au bilan (S, `ui/results_panel.gd`). Vue 3D tournante du boss dans le journal (M).
- « Explorer » une salle de boss sans ennemis pour la regarder (S). Classement local par graine de Ruée et par tranche de la Tour (S).
- Ligne « Coups reçus » optionnelle dans le HUD (S). Vibrations par gravité d'alerte (S). Photo de victoire (S).
- Mythique « + » : paliers infinis par boss après le Mythique (Mythique +1… +10 : PV × 1,1, une brique de plus tous les 3) si le joueur le demande (M).

---

## 8. Spécification « version 2 » (dans notre DA)

**Déroulé d'un donjon v2.** Menu > Jouer > Donjons : la page s'ouvre sur le **donjon vedette** (ou le dernier joué), portrait du boss sur
rayons de soleil, ses mécaniques en pastilles (icône, nom, conseil), le butin en cases (emplacements, panoplie, plan « garanti 1re fois »,
pièces déjà possédées cochées), la difficulté en onglets (actif mandarine, verrouillé tramé + cadenas + condition), la jauge de PE et
l'estimation, le record et les étoiles. À gauche, la liste en puits d'encre : tuiles avec portrait, deux emplacements, pastilles de familles,
médailles N / H / M. Filtres en pastilles. Bouton primaire soleil épinglé « Entrer : … » (A). → Salle 1 (élites une à une) → salle 2
(lieutenant, barre plus petite) → salle 3 (boss). → Bilan.

**HUD de boss v2** (maquette `v2_barre_boss.svg`). En haut, au centre, une **barre compacte** (papier, contour d'encre 3 px, ombre dure) :
médaillon portrait, nom en M PLUS Rounded 800, pastille de difficulté, minuteur de fureur fraise quand il existe ; jauge 30 px (creux
encre-500, remplissage fraise deux tons, trace claire, bord droit d'encre), **encoches aux seuils réels** avec pastilles de la couleur de
la famille ; dessous, les pastilles des mécaniques du boss, l'active cerclée de blanc, et la **ligne d'incantation** mandarine avec le
nom et le conseil (« Pluie de météores · bouge ! »). À droite, la **frise « À venir »** (puits d'encre, 4 lignes, comptes à rebours). Au
centre, les **alertes** : mineure = texte contouré, moyenne = bulle lagon, critique = bulle fraise inclinée −3° + son « gong » (jamais de
vibration pendant un télégraphe, BIBLE § 7). Hors écran : flèche soleil vers totem, cristal, tourelle (« Totem 2/3 »). Bas : PV du héros
avec la pastille « Relève 1 ». La caméra garde le boss sous la barre (cadrage relevé de quelques degrés en combat de boss).

**Télégraphes v2.** Danger = hachures fraise à 30 % + cœur qui grossit jusqu'au bord pendant l'armement + bord net (encre 5 px + liseré
papier 2 px) + compte à rebours sur les grosses zones ; sûr = pomme à 28 % + bord en **pointillés** + mot « SÛR » ; mur d'arène =
anneau mandarine. Les monstres ordinaires gardent l'annonce discrète (`small`). Couleurs réglables, formes jamais.

**Bilan v2** (maquette `v2_bilan.svg`). Victoire : titre soleil incliné, 3 étoiles d'objectifs, tuiles temps / boss / chutes (« Record ! »
en pastille mandarine), butin en cases avec le gain de puissance, ligne « prochaine victoire ici : les Gants » (malchance protégée
**visible**), ligne « Ta quête », boutons Rejouer (primaire) / Autre boss / Menu ; confettis 1,2 s. Défaite : titre fraise, « Ce qui
t'a battu » (3 coups, part des PV, coup final), **conseil de la brique**, ce qui est gardé, le meilleur pourcentage atteint sur ce boss,
« Réessayer le boss » (depuis la salle 3) et « S'entraîner ».

**Journal des rencontres** (maquette `v2_journal_rencontres.svg`, Carnet > Rencontres) : grille par zone (6 boss), états vaincu (coche
pomme) / rencontré (couleur) / à découvrir (« ? » tramé : nom caché tant que la zone n'est pas atteinte) ; fiche : rendu 3D, titre,
« rencontré dans : Survie, Tour (étage 30), Ruée », panoplie et emplacements, mécaniques (vues : compteur ; pas vues : grisées mais
**conseil lisible** : on ne cache jamais l'aide), records par difficulté (victoires, meilleur temps, étoiles), « Aller à son donjon »
(primaire) et « S'entraîner ».

**Tour v2.** Page des étages inchangée sur le fond (icônes de type, fiche) ; ajouter le temps record par tranche, la faveur choisie
(P1-7) et l'intro des Ombres (P1-8). Bilan d'une chute : « Ce qui t'a battu », « Reprendre à l'étage 11 ». **Ruée v2** : fil des temps
par boss à droite pendant la partie, meilleur temps du tirage au bilan, graine copiable. **Siège v2** : tableau des 3 en haut à droite
(dégâts au boss, chutes), trêve annoncée, objectifs ★ au HUD.

**Règles inchangées** : PV fixes, plafonds de coups (40 % / 25 % Tour), PE requise et conseillée, butin et plans, ouvertures. Les étoiles,
défis de la semaine et records ne conditionnent **jamais** le butin principal (pas de corvée).

---

## 9. Questions ouvertes (avec recommandation)
1. **Frise « À venir » affichée par défaut ?** Recommandation : **oui** partout, désactivable ; elle transforme 29 briques en
   lecture au lieu de réflexes à apprendre par l'échec, et nos boss sont joués seuls (pas d'appel vocal d'un chef de groupe).
2. **Défi de la semaine imposé ou au choix ?** **Au choix**, comme les modificateurs de la Ruée ; le donjon vedette donne un bonus la
   1re fois de la semaine, l'ignorer ne coûte rien.
3. **Une relève en donjon ?** **Oui, 1 par boss en Normal / Héroïque**, aucune en Mythique et en Tour Hardcore ; la Survie reste à une vie.
4. **Mythique « + » infini ?** **Pas maintenant** : la Tour joue déjà ce rôle ; on le reconsidère si le joueur finit les 48 boss en Mythique.
5. **Classements en ligne ?** **Non** (pas de serveur) : records locaux + graine de Ruée partageable.
6. **Noms et mécaniques cachés dans le journal ?** Nom caché tant que la zone n'est pas ouverte ; **conseil toujours lisible** (l'aide
   avant l'échec prime sur la découverte).
7. **Compteur de dégâts (style WoW) ?** En P2, au bilan seulement : pas de chiffre permanent de plus dans le HUD (règle « aucun pourcentage
   dans le texte permanent »).
8. **Portraits de boss** : rendus 3D du modèle d'Eden dans un cadre autocollant (session locale, `tools/look_audit` existe) plutôt
   qu'une illustration peinte (BIBLE § 9).

---

## 10. Sources
- Blizzard, « Midnight: Get up to Speed with User Interface Updates » : https://worldofwarcraft.blizzard.com/news/24223311
- warcraft.wiki.gg : Adventure Guide, Delve(s), Bountiful delves, API DeathRecap GetEvents, Mythic+ affix
- Wowhead, guide Mythique+ saison 3 (The War Within) ; Raider.io, « The weekly route » ; Icy Veins, Delves guide
- consolegameswiki : https://ffxiv.consolegameswiki.com/wiki/Duty_Finder , /Pilgrim%27s_Traverse , /Mechanics , /Duty_Support ; Prima Games, « All Variant Dungeons »
- Upcomer, « Lost Ark's combat system explained » ; Zockify, Valtan Gate 1 / 2 ; KeenGamer, Valtan phase 1 ; PlayNews, « Counter Attack and Perfect Block » (09/2026)
- https://wiki.guildwars2.com/wiki/Fractals_of_the_Mists (images « Fractal Difficulty Scale Selection », « Fractal Quickplay Selection »)
- ESO-Hub, « Infinite Archive : evaluations of the first month » et guide ; forums officiels ESO
- Timesaver.gg et AllThingsHow (Abîme spiralé, cycles 2026) ; Icy Veins et BossRush (Stygian Onslaught)
- Prima Games et RPG Site (Pacte de punition) ; Fextralife (mode Dieu) ; Steam, fiche Hades (captures)
- Prima Games, « Monster Hunter: World – How to Find Monster Weaknesses » ; Gamer Guides, faiblesses (Wilds)
