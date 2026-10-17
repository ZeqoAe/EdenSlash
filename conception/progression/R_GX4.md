# R_GX4 — « Tout monter à +5 », gemmes lisibles, 5 préréglages, recherche (17/10/2026)

Lot GX-4 = levier proposé par H56 (`R_H56.md` §1 : le rythme visé n'est tenu que si le joueur monte toutes les pièces à +5 avant
d'en pousser une à +10) + reste du backlog P1 / P2 de `conception/benchmark/HEROS_EQUIPEMENT_PROGRESSION.md` qui touche
l'Atelier et l'écran Héros (recommandations validées : Q2 non traitée ici, Q6 « 5 préréglages nommés par usage », « désertir
gratuit », « comparer avec un autre préréglage », « tenue enregistrée par préréglage », « provenance des apparences »).
DA v2 (`UiTheme` papier, `ForgeWidgets.candy_button`).

## Fait
- **Tout monter à +5** (Forge > Améliorer) : rangée au-dessus de la grille « ‹ Tout monter à +5 · 7 pièces › » (cible +1 à +10,
  défaut `Forge.EVEN_TARGET` 5). Pièces = les 9 emplacements portés du préréglage actif (`Forge.even_pieces` : ni trophée, ni arme
  secondaire, qui ne donnent pas de stats). Un essai à la fois, **la moins montée d'abord** (ordre de la poupée à égalité, donc une
  pièce ratée est reprise aussitôt et sa persévérance finit le cran) : `Forge.even_step`, mêmes règles que « Fortifier » (lot
  GX-2 : un parchemin et le prix par essai, persévérance, aucune rétrogradation). Une pièce sans parchemin qui convienne est
  sautée, les autres continuent ; faute de cristaux pour toutes, arrêt propre (ce qui est monté le reste, rien n'est payé sans
  essai). **Confirmation** (`InfoCard.ask`) : les pièces en cases avec « +2 → +5 », crans, cristaux attendu / au pire / ce qu'on a,
  parchemins de garde et de puissance attendus / au pire / utilisables (`Forge.plan_even`, somme de `Craft.plan_upgrade`), « s'il
  en manque, la Forge s'arrête : rien n'est perdu », interrupteur « Utiliser mes pierres de chance (les plus petites d'abord) »
  (`Forge.smallest_stone`, éteint par défaut). **Séance** : la barre de forge se remplit à chaque essai (0,16 s), « Cran 7 / 22 »,
  la pièce en cours et le bilan (essais, ratés, cristaux) dans la fiche, le +N des cases suit ; **« Arrêter »** (fraise) remplace
  l'action principale et arrête après l'essai en cours ; établis et sélection bloqués pendant la séance ; fermer l'Atelier
  arrête aussi. **Verdict** : pomme « Tout l'équipement à +5 · 24 essais (2 ratés) · 607 cristaux · Stats bonus : … », lagon pour
  un arrêt (« Arrêt : plus assez de cristaux · 4 pièces sur 7 à +5 »). `Forge.even_all` = la même chose sans animation (tests).
  Boussole : quand 2 pièces ou plus sont sous +5, l'infobulle du conseil Forge dit « à la Forge, « Tout monter à +5 » les monte
  toutes, la moins montée d'abord ». Grille de la Forge : pièces portées d'abord (`ItemGrid.first_fn`), plus de ▲ / ▼ sur les
  cases (`ItemGrid.compare`, ils cachaient le +N), recherche par nom.
- **Gemmes lisibles** : chaque bouton dit ce que la gemme donne **sur cette pièce** (`Craft.gem_value_text` : « Sertir Grenat taillé
  · +80 PV ×3 », valeurs de la Survie au niveau du héros) ; tableau de l'établi « Gemme 1 · Grenat pur · +140 PV » ; **« Retirer »
  gratuit** (`Craft.remove_gem` : la gemme revient au sac, l'emplacement reste percé) ; sertir sur une gemme **la renvoie au sac**
  au lieu de la détruire ; **« Tout fusionner »** (`Forge.fuse_all` : plus petites tailles d'abord, en cascade, tant que le prix
  suit ; le message ne compte que le gain net) ; note « Perce d'abord un emplacement » quand la pièce n'en a pas.
- **5 préréglages par classe** (`Profile.PRESETS_PER_CLASS` 3 → 5) : une vieille sauvegarde garde ses 3 (noms, pièces, actif) et
  reçoit 2 préréglages vides (`_class_presets` complète déjà la liste : aucune clé renommée). Barre : l'actif garde son nom, un
  préréglage au nom d'origine ne montre que son numéro (« Survie | 2 | Donjons | 4 | 5 | Gérer »), infobulle nom + pièces.
  **Gérer** : une ligne par autre préréglage « Copier ici » / « Comparer » ; noms d'usage en un clic (Survie, Donjons, Tour, Duel,
  Essai : `Profile.PRESET_USES`) ; **tenue liée** (« Lier ma tenue à ce préréglage » : clé `look` du préréglage = tenue, tête, dos,
  auras, couleurs ; elle revient quand on reprend le préréglage et suit les retouches faites pendant qu'il est actif ; un
  préréglage sans tenue liée ne touche pas à l'apparence ; aucune stat). **Comparer** (`PresetBar.compare_plan`) : « « Survie » →
  « Donjons » », PE des deux et l'écart, « 1 emplacement change · 8 pièces en commun », lignes case → case, « Passer à « Donjons » ».
  `Profile.preset_gear(classe, i)` relit l'équipement d'un préréglage non actif.
- **Préréglages de sorts** (Grimoire) : sous les boutons, les 4 sorts principaux du préréglage actif en petites cases (infobulle :
  la case et ses enchaînements), puis son nom ; « Dupliquer « X » » dans le menu (copie « X (copie) », chargée).
- **Aperçu de la panoplie** (Héros) : la panoplie la plus portée même sans bonus (« Panoplie du Désert · 3 / 6 · bonus à 4 »,
  « complète »), paliers au survol (✓ = actif) ; sans pièce de panoplie : « Aucune panoplie portée » + d'où elles viennent.
- **Apparences** : provenance juste des apparences verrouillées (« boss et coffres d'apparence » + la liste des activités, au lieu
  de « butin des boss ») ; l'essai par clic existait déjà. Pas de transmogrification de pièce : l'apparence est déjà séparée de
  l'équipement (tenue, tête, dos, aura, arme par type) ; l'étude recommandait la tenue par préréglage, faite ci-dessus.
- **Listes et recherche** : Fabriquer > Catalogue complet : champ « Chercher » (plans découverts seulement : un plan à découvrir
  reste anonyme) ; Forge : recherche ; `ItemGrid.enable_search` / `ItemGrid.name_matches` (sans accents ni casse, nom ou emplacement).
- **Manette** : la barre d'aide dessine **X** quand le contrôle visé (ou un parent) porte la meta `pad_x` (`UiNav.x_hint`) :
  « Équiper » sur une case du sac, « Retirer » sur la poupée (X = clic droit, déjà branché).
- **1280 × 720** : le Grimoire débordait de 20 px (déjà avant ce lot) : colonnes gauche / droite réduites de 30 / 40 px sous 1500 px.

## Économie
Aucun prix, aucun taux, aucune récompense changés (`Forge.GOLD_PER_CRYSTAL` 108, tables d'époque, verrous de PE de H56 intacts).
Deux règles touchent l'économie de loin : « Tout monter » ne change pas le coût d'un essai (il rend naturel l'ordre `--even` mesuré
par H56) ; les gemmes ne sont plus détruites (remplacement, pièce changée). `progression_sim` modélise maintenant les deux
(`_wear` : les gemmes de la pièce remplacée et la gemme remplacée reviennent au sac ; `--even` garde la définition de H56).
Mesures sur une copie propre de HEAD (0.1.284 + ICO-1) + ce lot, 12 comptes « moyen », guerrier, 50 h,
`--heros --refonte --plans=boss --hubvalue --bossplans --even`, machine très chargée (≈ 55 processus Godot ; bruit ± 1,5 h,
H56). Médianes en heures (part des comptes qui atteignent le jalon) :

| Variante | graine 1 | graine 2 | graine 3 | graine 4 |
|---|---|---|---|---|
| HEAD, `kit80_ok` | 32,4 (67 %) | 32,1 (83 %) | 31,0 (92 %) | 32,5 (83 %) |
| **ce lot (gemmes rendues), `kit80_ok`** | **32,2** (83 %) | **30,4** (75 %) | — | **31,0** (83 %) |
| essai : `--even` « la moins montée d'abord », `kit80_ok` | 29,1 (83 %) | non atteint (42 %) | 30,6 (92 %) | — |
| HEAD / ce lot, `kit80_p10` | 34,3 / 39,6 | 36,1 / 34,6 | 36,8 / — | 36,7 / 34,8 |
| `kit90_ok`, `kit90_opti` | jamais atteints (0 %), avant comme après | | | |

Sans `--even` (graines 1 et 2, ce lot) : `kit80_ok` 34,6 (92 %) et 34,9 (58 %). Lecture : rendre les gemmes ne bouge pas
l'équipement correct (il ne compte pas les gemmes) et `kit90_opti` reste hors d'atteinte en 50 h ; **`kit80_ok` reste dans 30-36 h**.
L'essai « la moins montée d'abord » (l'ordre exact du bouton) donne 29-31 h, à la limite basse de la cible et dans le bruit ;
il n'est pas gardé dans l'outil (le `--even` de H56 reste la référence des séries). Le bouton ne change aucun coût : il rend
naturel le chemin `--even` (≈ 31-32 h au lieu de ≈ 35 h pour le joueur qui monte une pièce à +10 avant les autres).

## Tests et captures
Nouveau `test_gx4` (≈ 45 vérifications : plan et séance « Tout monter » sans animation, persévérance vidée, jamais au-delà de la
cible, coût entre « si tout réussit » et « au pire », pierres les plus petites d'abord ou aucune, arrêt faute de cristaux (rien
de négatif, écart d'un cran au plus), pièce sans parchemin sautée ; écran : rangée, pièces portées d'abord, confirmation (coûts,
9 cases), séance jusqu'au bout, « Tout est à +5 ✓ », › vise +7, « Arrêter » qui résiste aux clics d'établi et de grille ; gemmes
(retirer, remplacer sans détruire, tout fusionner en cascade) ; préréglages (5, vieille sauvegarde à 3, nom d'origine, comparer,
`preset_gear`, tenue liée relue du disque, délier) ; barre et « Gérer » ; recherche ; X de la manette ; boussole). Captures `tests/shot_gx4.tscn` (`GX4_RES=1280x720`, lignes `[débord]`) regardées à
1600 × 900 et 1280 × 720 : Forge (rangée, confirmation, séance, verdict, gemmes), Fabriquer (recherche), Héros (5 préréglages,
« Gérer », comparaison), Grimoire (préréglage de sorts) ; aucun débord après la correction du Grimoire. Retouches après
captures : confirmation sur des lignes plus courtes (le nombre de parchemins passait seul à la ligne), compteur « Cran 7 / 22 »
(« Pièce 1 / 7 » restait figé tant que la pièce la plus basse montait), fiche de la pièce en cours et +N des cases pendant la séance,
préréglage de sorts sur une ligne à part (la rangée élargissait le Grimoire).
Verts sur une copie propre de HEAD + ce lot (`-j 2`) : test_gx4, test_gx2, test_gx3, test_h3, test_h56, test_workshop, test_loot,
test_e6, test_nav_screens, test_pages, test_texts_fr, test_compass, test_progress, test_p4_flow, test_build, test_tooltips. Mis à
jour : `test_gx2` (le › de « Viser » est cherché dans la zone épinglée : celui de « Tout monter » est au-dessus de la grille),
`test_pages` (5 préréglages, « Copier ici »).

## Reste / pièges
- **Reporter le +N** (P1, Q2 « oui, à −2 crans ») : non fait, il change le coût de la Forge et demande sa propre mesure.
- Choix du préréglage sur la page d'une activité avant « Lancer » (Q6) : non fait (lobby en travaux d'autres lots) ; « Passer à »
  depuis la comparaison et la barre de Héros suffisent en attendant.
- P1 hors de ce lot : talents v2, titres dans Héros, Registre v2, ouvrir tout des coffres, jalons du niveau de héros ; P2 : verrou
  par règle, « idéale pour », rareté sans couleur, « pourquoi cette PE », filtre de butin, 48 plans en silhouettes.
- `progression_sim --even` garde l'ordre de H56 (chaque pièce à +5 dans l'ordre des emplacements) ; le bouton monte la moins
  montée d'abord, essai par essai (mesuré à part : 29-31 h, voir plus haut).
- Le mot « Survie » reste (préréglage « Survie », lot A9 plus tard).
