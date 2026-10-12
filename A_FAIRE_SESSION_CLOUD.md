# Chantier suivant — consignes pour la session cloud

> **État au 12/10/2026 (versions 0.1.22 à 0.1.26, session cloud, branche
> `claude/great-mayer-uin0gh`)** : les 4 parties sont faites.
> 1. Menus : Jouer, Héros, Coffres, Collection, Paramètres, Quitter ; écran Héros unique
>    (Équipement, Talents, Apparence, Grimoire, Classe, aide « ? ») ; Collection sans onglets ;
>    run lancée en un clic ; pause Run / Héros / Aide. **Reste : validation du joueur sur
>    captures.**
> 2. Mode dev : écran F10 (Paramètres > Caméra & interface > Mode dev) : Objets, Ressources,
>    Progression, Run.
> 3. Trophées : trophée de départ, buffs sous condition (`scripts/core/trophies.gd`, familles
>    par `tools/rework_trophies.py`), 25 objets parasites retirés du butin.
> 4. Zones / monnaies : réponses du joueur appliquées (voir le tableau dans `DESIGN.md`,
>    « Monnaies, coffres et zones ») : marchands ambulants à la place du village, coffres
>    payants (or ou clé), 10 sanctuaires, clés sur les élites, or seul pour +1 → +10, cristaux
>    (démontage, gardés) pour réforger et polir, or et clés perdus en fin de run, menu Coffres
>    (coffres de récompense hors run).
> Pour la session locale : rien à extraire du client pour ce chantier.

Rédigé par la session locale à la version 0.1.20 (12/10/2026). Le joueur a validé ces
objectifs ; la session locale ne code plus rien sur ce chantier. Lire d'abord `CLAUDE.md`
(branche, numéro de version, pull/push), puis ce fichier en entier avant de commencer.

**Ordre conseillé** : 1 (interface) → 2 (mode dev) → 3 (trophées) → 4 (zones, monnaies,
coffres). Pousser après chaque grande étape (une version par envoi), avec un résumé en
français pour le joueur. Quand une règle de jeu n'est pas tranchée ici (voir les « questions
à poser »), demander au joueur avant de coder.

---

## 0. Ce que la session cloud doit savoir

- **Pas de client Eden dans le cloud.** Les outils `tools/build_*.py` lisent le client
  (dossier `extracted/`, non versionné) : ils ne tournent pas dans le cloud. Toutes les
  données utiles sont déjà dans le dépôt :
  - `game/data/eden_catalog.json` : `items` (5 947 équipements : `id, name, slot, wtype,
    armor, level` = niveau d'Eden, `rarity` 0-5, `r` = stats relatives, `set`, `passive`
    {name, desc, stat, procs, eden = texte anglais d'Eden}, `arch` = catégorie d'archive,
    `src`), `sets`, `collection` (6 888 trésors : apparences, montures, familiers, auras…),
    `cosmetics` (422 tenues, chapeaux, dos).
  - Les modifications de données se font en éditant ce JSON (script Python sur le JSON, pas
    sur le client). Si une donnée du client manque, la noter pour la session locale.
- **Niveaux** : un objet a `level` (niveau d'Eden, affiché) et `plevel` (puissance, niveau de
  run où il est tombé). `GameData.eden_bands` = tranche d'Eden de chaque zone,
  `Items.eden_template()` choisit le modèle d'Eden (chronologie des zones).
- **Tests** (headless) : `test_pages, test_build, test_progress, test_hud, test_controls,
  test_cards` (+ `test_skills -- <classe>`, `test_aura`, `test_outfit` pour des planches
  d'images). Les arguments de ligne de commande utilisent un profil de test
  (`user://profile_test.json`), jamais la sauvegarde du joueur. Mettre les tests à jour
  quand une page est supprimée ou déplacée.
- **Captures du lobby** : `--lobby-shot=<s>` avec `--archive=N`, `--inventory`, `--prep=N`,
  `--archive-cat=c:32`, `--enc-cat=a:plates`, `--costume-cat=aura`, `--wear-aura` (ces
  options suivront les pages : les adapter ou les remplacer lors de la refonte).

---

## 1. Refonte de l'interface et des menus (priorité principale)

### Le problème
On a empilé des écrans à onglets pour des fonctions proches : ce n'est « vraiment pas
agréable ». Exemple donné par le joueur : l'écran **Collection** a 4 onglets (Collection,
Encyclopédie, Tenues, Apparences d'armes) — c'est trop.

### Ce que veut le joueur
- **Collection = une seule page** : l'archive des trésors (`ArchivePages.CollectionPage`).
  Les onglets Encyclopédie, Tenues et Apparences d'armes sont **supprimés** de cet écran.
- **Apparences et skins portés → page Classe** : choix de la tenue, du chapeau, du dos, des
  auras et de l'apparence d'arme de la classe, avec l'aperçu 3D du héros, au même endroit que
  le choix de la classe.
- **Tout recentraliser** et repenser le menu pour qu'il soit à la fois fonctionnel et
  optimal (moins d'écrans, moins de clics, une fonction = un seul endroit).
- L'**Encyclopédie** disparaît comme page à part : son contenu utile va dans le **mode dev**
  (section 2) ; la Collection garde sa recherche et ses filtres pour le joueur.

### État actuel (à recentraliser)
- Menu du lobby (`game/scripts/ui/lobby.gd`, `MENU`) : Jouer, Classe, Équipement,
  Collection, Infos, Paramètres, Quitter.
- Écrans à onglets (`PageScreen`, `lobby.gd` ~l.343-360) :
  - Préparer la run : « 1 · Équipement » + « 2 · Expertise & talents » ;
  - Expertise & talents (doublon de la préparation) ;
  - Archive : Collection + Encyclopédie + Tenues + Apparences d'armes
    (`game/scripts/ui/archive_pages.gd`) ;
  - Infos : guide des statistiques.
- Écran Équipement (`InventoryScreen` + `InventoryPage`) avec une barre de raccourcis :
  Talents, Classe, Grimoire, Statistiques, Collection.
- Sélecteur de classe plein écran (`class_picker.gd`), grimoire (`grimoire.gd`), page
  talents (`talents_page.gd`), page équipement ancienne (`equipment_page.gd` : son
  `HeroPreview` sert partout).
- Menu pause (`pause_menu.gd`) : Run, Équipement, Infos.
- Village (`village_ui.gd`) : un PNJ par métier, chacun avec ses onglets (marchand : Acheter /
  Vendre ; forgeron : Améliorer / Enchanter / Réforger / Fabriquer ; recycleur : Recycler /
  Convertir ; joaillière : Sertissage / Fusion).

### Piste de menu (à valider avec le joueur avant de coder)
- **Jouer** (zone, préparation de la run en une page : équipement à gauche, talents et
  certificats à droite ou en volet, bouton Lancer).
- **Héros** (fusion « Classe » + « Équipement ») : choix de la classe, équipement et
  inventaire, stats + Détail, **Apparence** (tenue, tête, dos, auras, arme), grimoire de la
  classe, talents.
- **Collection** : l'archive seule.
- **Paramètres** (et Infos / guide des statistiques en aide contextuelle, bouton « ? »).
- **Quitter**.
- En run : le menu pause reprend la même structure (Run / Héros / Aide) ; au village, un seul
  écran par PNJ avec des sections plutôt qu'une pile d'onglets si c'est plus clair.
- Règles : pas de doublon (talents accessibles à un seul endroit), retour toujours au même
  endroit (Échap), la barre de raccourcis de l'inventaire disparaît si le menu suffit.

### Critères d'acceptation
- Collection n'a plus d'onglets ; aucune fonction perdue (tenues, auras, apparences d'armes
  sont dans la page Classe / Héros).
- Chaque fonction n'est accessible que depuis un endroit logique ; le joueur valide le
  nouveau menu sur captures d'écran avant la finition.
- Les tests de pages (`test_pages`, `test_hud`) sont mis à jour et passent.

---

## 2. Un vrai mode dev, propre

Aujourd'hui le mode dev est un interrupteur dans l'onglet Encyclopédie de l'archive
(`EncyclopediaPage._build_dev`, `Profile.dev`). À refaire en **écran dédié** (raccourci
clavier, par ex. F10, et/ou bouton visible seulement si le mode dev est activé dans les
Paramètres) :
- **Objets** : tout le catalogue (équipements, trésors de collection, cosmétiques) avec les
  filtres de l'encyclopédie actuelle (catégorie, type d'armure, rareté, niveaux, sets,
  archive, tri, affichage par set et niveau) ; ajouter ×1 / ×5 au coffre ou au sac, en
  choisissant la rareté et le niveau de puissance.
- **Ressources** : or, matériaux, fournitures (gemmes, parchemins, perceuses…), et les
  nouvelles monnaies de la section 4 ; en run et pour le départ des runs.
- **Progression** : maîtrise de la classe, débloquer classes, zones, tenues, trésors.
- **Run** (en run) : niveau du héros, invincibilité, tuer la vague, faire apparaître élite /
  boss / coffre / marchand, téléporter au donjon, passer en rage.
- Tout ce qui touche la sauvegarde du joueur demande confirmation ; le mode dev ne doit pas
  apparaître pour un joueur qui ne l'a pas activé.

---

## 3. Refonte des trophées

### Constat
Le trophée (emplacement « trophy ») reçoit aujourd'hui les 548 trophées d'Eden convertis
automatiquement : des objets qui n'ont rien à y faire s'y sont glissés (transformations de
familier, « Test… », modificateurs de sorts d'autres classes comme « Scirocco Left Wing »),
et beaucoup donnent surtout des **stats fixes**.

### Ce que veut le joueur
- **Un trophée équipé de base** (trophée de départ donné à tout le monde, comme l'arme de
  départ dans `Profile._ensure_starter`) ; **les autres se lootent en jeu**.
- Un trophée donne **pas ou peu de stats fixes**, mais un **buff sous condition**. Exemples
  donnés : « 5 % de chances en attaquant de gagner +X d'Agilité », « +Agi et +Int », « taux
  et dégâts critiques », « probabilité de double attaque », etc.

### Pistes techniques
- Les effets déclenchés existent déjà : `game/scripts/combat/procs.gd` (déclencheurs `hit`,
  `crit`, `kill`, `dodge`, `low_hp`, `skill_hit`, `perfect`… ; effets `buff` avec un statut,
  `heal`, `lightning`, `freeze`…) et `combatant.gd` (`STATUS_INFO` : frenzy, keen, haste,
  might, swift, grace, resolve…). Ajouter les statuts manquants (ex. double attaque,
  Agi+Int, critique + dégâts critiques) et leur effet réel dans `player.gd`.
- Données : un script Python sur `eden_catalog.json` qui, pour chaque trophée, garde le nom
  et l'icône d'Eden, met `r` à presque rien (ou 0) et écrit un `passive` à déclenchement
  inspiré de son texte (`passive.eden` quand il existe) ; exclure du pool les trophées sans
  sens en jeu (familier, test, modificateurs de sorts) — les laisser dans l'archive.
- Rareté → force du buff (chance, valeur, durée) ; le trophée garde son niveau d'Eden.
- Mettre à jour la carte d'objet (`Items.describe`) et l'archive (`Archive.entry_bonus` :
  le trophée donne aujourd'hui +0,5 à chaque attribut par entrée).

---

## 4. Zones, monnaies, coffres : tout remettre au clair

### État actuel d'une run (`game/scripts/core/run_director.gd`)
- 10 minutes d'exploration puis la **rage** (monstres renforcés) ; le **donjon** est scellé :
  il faut **3 sceaux** portés par les gardiens d'élite des camps ; salle du boss avec ses
  mécaniques (`boss_brain.gd`) ; fin par victoire ou extraction.
- **Coffres** sur la carte : gratuits, donnent un consommable et un objet (meilleurs en rage).
- **Village** caché sur la carte : marchand, forgeron, recycleur, joaillière.
- **Monnaies** :
  - pendant la run : **or** et **matériaux** (fragments, essences, cristaux), remis à zéro au
    début de chaque run (`Profile.begin_run`) ;
  - entre les runs : **points d'expertise** (maîtrise de classe), **fournitures** gardées
    (`stash`, emportées à la run suivante, perdues si le héros tombe), le **coffre**
    d'objets (héritage), l'**archive** et les **trésors de collection** (boss).
  - Le joueur trouve que ce n'est pas clair : qui donne quoi, où, et à quoi ça sert.

### Ce que veut le joueur
- **Refaire le système de zone** et **remettre au clair les monnaies** : quand on obtient
  quoi et où.
- **Coffres en jeu où l'on débloque des choses**, en s'inspirant de **Megabonk** :
  **marchands**, **coffres**, **pièces**, **clés**, **zones à capturer**, **élites**, etc.

### Pistes (inspiration Megabonk, à valider avec le joueur)
- **Pièces** ramassées sur les monstres et dans des objets cassables ; elles servent sur la
  carte (coffres, marchands) pendant la run.
- **Coffres payants** dont le prix monte à chaque ouverture ; **clés** (trouvées sur les
  élites ou dans des pots) qui ouvrent un coffre sans payer ou un coffre spécial (doré).
- **Marchands ambulants** sur la carte (offres tirées au sort, payées en pièces).
- **Zones à capturer** (sanctuaires) : rester dans le cercle un certain temps sous la
  pression des monstres → récompense au choix (stat, carte de build, objet).
- **Élites** : porteurs de clés et de sceaux, butin garanti ; boss de zone qui ouvre la suite.
- Une **table claire « monnaie → où on l'obtient → à quoi elle sert »** affichée en jeu
  (aide) et dans `DESIGN.md`.

### Questions à poser au joueur avant de coder
1. Garde-t-on le village (PNJ fixes) en plus des marchands ambulants, ou les marchands le
   remplacent-ils ?
2. Les matériaux (fragments, essences, cristaux) restent-ils, ou deviennent-ils une seule
   monnaie d'amélioration ?
3. Que débloquent les coffres « hors run » (classes, cosmétiques, trésors de collection,
   bonus permanents) ?
4. Combien de zones à capturer par carte, et quelles récompenses ?
5. Les clés et pièces sont-elles perdues à la fin de la run ?

---

## Rappels
- Rapports et messages au joueur **en français**, sans jargon (il ne connaît pas git).
- Numéro de version augmenté à chaque push, ligne dans `CHANGELOG.md` (voir `CLAUDE.md`).
- Limites connues laissées par la session locale : montures et familiers présents dans
  l'archive mais pas jouables (il faudrait les animations du héros à cheval : à faire par la
  session locale, qui a le client) ; dépôt volumineux (~1,2 Go).
