# Audit de l'interface (Direction artistique, 17/10/2026, version 0.1.256)

**En une phrase** : l'interface est propre, lisible et cohérente dans ses couleurs, mais elle est faite d'**une seule forme**
(le rectangle à coins arrondis de 8 px, bordé d'un filet doré de 2 px) répétée à tous les niveaux, avec des pictogrammes
génériques et deux polices « par défaut » du genre : c'est exactement ce qui la fait passer pour un prototype ou une
interface générée.

Captures : `audit/` (JPG, 1600×900 et 1280×720, compte neuf et compte avancé), faites sur une copie propre de HEAD
(`tools/run_tests.py preparer_copie`, APPDATA détourné) avec `tests/shot_p1`, `shot_hud`, `shot_cards`, `shot_results`,
`shot_registry`, `shot_ac`, `world.tscn -- --card-shot | --gear-shot | --pause=1` et une capture de l'écran titre.
Planche des icônes : `audit/icones_planche.png`. Code lu : `ui/ui_theme.gd`, `assets/ui/frame/`, `assets/ui/icons/`.

---

## 1. Première impression (2 secondes)

| Écran | Ce qui attire l'œil d'abord | Est-ce juste ? |
|---|---|---|
| Lobby (`02_lobby_neuf_1600`) | le logo, puis la colonne de 7 boutons identiques | Non : « Jouer » (la seule action qui compte) pèse autant que « Quitter » |
| Jouer (`03_jouer_avance_1600`) | les cadenas et chaînes posés sur les cartes, puis les pastilles d'icônes | Non : les verrous crient plus fort que les activités ouvertes |
| Héros (`08_heros_equipement_neuf_1600`) | la grille de 45 cases vides à droite | Non : le vide domine, le héros et sa puissance passent après |
| Atelier, Coffres (`13`, `11`) | le grand cadre vide | Non : l'état vide n'a ni image ni action |
| HUD (`19_hud_survie_1600`) | les deux globes rouges et bruns | Oui pour la vie ; le globe « RUN 1 / 44 % » est obscur |
| Bilan (`24_bilan_victoire_1600`) | « VICTOIRE ! » puis 6 tuiles identiques | À moitié : les tuiles ont toutes le même poids |

---

## 2. Ce qui « sent l'IA » ou « sent le prototype » (liste précise, captures à l'appui)

1. **Une seule forme pour tout.** Bouton, onglet, case, carte, panneau, fenêtre, liste déroulante, pastille de filtre :
   même rectangle arrondi à 8 px, même filet doré de 2 px, même ombre de 5 px (`UiTheme.flat_box`, appelé 222 fois ;
   `Color(` littéral 910 fois dans `ui/`). Rien ne distingue un conteneur d'une action. Voir `17_parametres`, `15_carnet_ensemble`,
   `14_atelier_forge` : trois niveaux d'imbrication de la même boîte (fenêtre > panneau > carte > bouton).
2. **Les rangées de boîtes identiques.** Onglets en boîtes égales (`15_carnet`, `17_parametres`, `14_atelier`), tuiles du bilan
   (`24_bilan_victoire` : 6 tuiles égales), carnet en 10 cartes égales avec 10 barres vides (`15`), registre en 7 lignes
   identiques (`16_registre`), coffres en 6 lignes « icône ronde + texte + Ouvrir » (`12_coffres_avance`). C'est la signature
   d'une mise en page générée : la grille remplace la hiérarchie.
3. **Le filet doré avec losange au centre** (sous le logo, sous « VICTOIRE ! », coins en losange du cadre `frame/panel.png`).
   Motif de stock vu partout ; il ne dit rien du monde du jeu.
4. **Pictogrammes génériques de type « application »** (`audit/icones_planche.png`, ligne `icons`) : maison, horloge,
   engrenage, épingle de carte, personnage, loupe, disquette, flèche, cœur. Trait uniforme, blanc pur, sans matière : ils
   viennent du vocabulaire des applications web, pas d'un jeu de fantasy. Exemple : « 0 insigne » est annoncé par une
   silhouette de personne (`02_lobby_neuf`), le Carnet par un livre ouvert de traitement de texte.
5. **Trois familles d'icônes qui ne se parlent pas** : pictogrammes blancs plats, icônes peintes du client d'origine
   (sorts, objets, classes, statuts : cadre carré arrondi, fond dégradé saturé, contour noir épais) et icônes de monnaie
   encore d'un autre style (`23_pause_heros` : lingot, clé, cristal). Une icône d'objet porte même des lettres (« ER »).
   Ces icônes du client d'origine posent aussi la question de la règle 3 de l'organisation (rien du jeu d'origine).
6. **Polices du genre par défaut** : Cinzel (le « Trajan » de toutes les affiches de fantasy) pour les titres, Nunito (police
   ronde d'application) pour le texte. Le mélange se voit sur un même écran : onglets en Cinzel capitales (`14_atelier`),
   sous-onglets en Nunito (`14`), bouton primaire en Cinzel (`05_page_survie` « Lancer la run »), boutons secondaires en
   Nunito. Les chiffres de Cinzel sont élégants seuls (`19_hud` « 463 ») mais fatiguent dans les tableaux.
7. **Pastille « pilule »** pour l'avis du lobby (`02`), les filtres du registre (`16`), « Retour au menu » et « ? » ronds
   dans l'en-tête Héros (`08`) : quatre formes de bouton dans le même en-tête (pilule, cercle, rectangle arrondi, case).
8. **Verrous en chaînes + cadenas** dessinés par-dessus l'image de chaque activité fermée (`04_jouer_neuf_verrous`) :
   effet de clip-art, répété 7 fois sur un écran.
9. **États vides muets** : un texte centré au milieu d'un immense cadre (`13_atelier_fabriquer_vide`, `11_coffres_vide`,
   `10_heros_apparence`) et une grille de 45 cases vides (`08`). Aucun dessin, aucune action proposée.
10. **Remplissages de rareté en dégradé plein** sur les cartes d'équipement (`22_choix_equipement` : toute la carte violette
    ou dorée) : très saturé, « écran de loot de jeu mobile ».
11. **Textes et pourcentages** : « 7 % » en grand dans le Carnet (`15`), « 44 % » dans le HUD (`19`), « 0 % plus gros coup »
    dans le bilan du duel (`25`), « +98 % au plus » dans les cartes (`21`) : la vision du jeu interdit les pourcentages dans le
    texte permanent. Anglicismes visibles : « run » (bouton, onglet de pause, globe du HUD), « lobby » (« Retour au lobby »),
    « Set : » (`22`), « RTS / MOBA », « Bot » (`17`), « JcE / JcJ » en pastille sur chaque carte d'activité (`03`).
12. **Version et aides posées sur la scène sans plaque** : « Eden Slash v0.1.256 » et « Glisser : tourner · Molette : zoom »
    (`02`) en blanc à 50 % ou contour fin sur le ciel et le chemin clair : contraste mesuré ≈ 1,1:1 à 1,5:1.
13. **Le HUD ne parle pas la même langue que les menus** : globes à la Diablo + barre fine + cadres rectangulaires à
    losanges, emplacements de sorts vides marqués « — » (`19`), télégraphes d'attaque en rouge pur qui couvrent la moitié de
    l'écran avec « ESQUIVE ! » écrit deux fois l'un sur l'autre (`20_hud_donjon`).

---

## 3. Analyse par thème

### Hiérarchie visuelle
- Un seul niveau d'accent (or) pour tout : titre d'écran, onglet actif, valeur, bordure, bouton primaire, bouton survolé.
  Quand tout est doré, rien ne l'est. Il faut réserver l'or vif aux titres et aux valeurs clés, et porter la **sélection** par
  une autre couleur (émail bleu dans la bible).
- Le bouton d'action principal n'est pas toujours identifiable : « Rejouer (Époque II) » du bilan (`24`) ressemble à un
  bouton désactivé (brun sur brun, Cinzel), alors que « Retour au lobby » à côté paraît actif.
- Les titres se répètent : « Coffres » trois fois sur `11` (titre d'écran, onglet, en-tête de panneau), « Forge » deux fois
  (`14`), « Registre » deux fois (`16`).

### Formes, bordures, ombres
- Rayon unique de 8 px partout, quelques 4, 10 et 14 (`corner_radius_all`) sans règle. Aucune forme propre au jeu.
- Cadre orné `frame/panel.png` : double filet + losanges dans les coins, étiré en 9 tranches ; joli seul, mais il entoure
  aussi des panneaux à l'intérieur d'une fenêtre déjà ornée (`14`, `13`, `15`) : double cadre dans cadre.
- Ombres : une seule (5 px, 45 %) pour un bouton comme pour une fenêtre : aucun effet de profondeur.

### Polices et échelle
- 15 tailles de texte différentes écrites en dur (11 à 42 px), dont **15 réglages sous le plancher de 14 px** (11, 12, 13) :
  libellés « sort », « talents », « certificat » du parcours de maîtrise (`09_heros_classe_avance_1280`), catégories de
  l'inventaire (`08`), chiffres sous les cases.
- Pas d'échelle : 14, 15, 16, 17, 18, 19, 20, 21, 22 se côtoient. La bible fixe 7 tailles.
- Chiffres : Nunito a des chiffres proportionnels ; les colonnes du registre et des bilans ne s'alignent pas.

### Contrastes (WCAG 2.1 AA, mesurés)
| Paire | Rapport | Verdict |
|---|---|---|
| Texte `#F2EDFA` sur panneau `#171229` | 15,8:1 | très bon (à garder) |
| Texte secondaire `#C7C2DB` sur panneau | 10,5:1 | bon |
| Or `#FAC759` sur panneau | 11,6:1 | bon |
| Texte désactivé `#8C8799` sur `#1A1724` | 5,1:1 | bon |
| Bordure désactivée `#59546B` sur `#1A1724` | 2,4:1 | **sous 3:1** (contour non perçu) |
| Boutons « Coffres / Atelier / Carnet » verrouillés du lobby, posés à 35 % sur l'herbe (`02`) | ≈ 3:1 | **échec** (texte 22 px gras : 3:1 limite) |
| Version et aide « Glisser : tourner » sur la scène (`02`) | ≈ 1,1 à 1,5:1 | **échec** |
| « PE conseillée » rouge `#FF5C5C` / vert `#73EB8C` (`05`) | 6,0 / 12,1:1 | lisible, mais rouge et vert seuls portent le sens (daltonisme) |
| « Saignement » rouge sur télégraphe rouge (`20`) | ≈ 1,3:1 | **échec** |

### Densité et alignements
- Pages de lobby trop denses à 1280 (`09_heros_classe_avance_1280` : 4 niveaux de boîtes, 12 étapes de parcours en 9 px de
  libellé), pages d'atelier et de coffres trop vides à 1600.
- Bon point : **aucun débord** à 1280×720 (lignes `[débord]` vides pour P1, Échiquier : 0).
- Alignements : le titre du registre et le compteur « 0 / 60 ÉQUIPÉES » se touchent (`16`) ; les textes des cartes d'activité
  passent sous les icônes de récompense ; la description du Duel déborde sur deux lignes dans sa carte (`04`).

### États des boutons
| État | Aujourd'hui | Problème |
|---|---|---|
| Normal | fond indigo, filet or terne 2 px | identique à un panneau |
| Survol | fond plus clair, filet or | correct mais faible (seule la couleur change) |
| Pressé | fond brun | pas de mouvement, pas de creux |
| Désactivé | fond plus sombre, filet gris 1 px, ou transparence sur la scène (lobby) | illisible sur la scène ; on ne sait pas *pourquoi* c'est fermé (sauf lobby « Jouer ») |
| Focus manette | cadre doré `UiNav` | bien fait (apparition au premier mouvement), mais se confond avec le survol et l'onglet actif (même or) |
| Sélectionné | fond brun + filet or | identique au pressé |

### Icônes
Voir le point 2.4 et 2.5 : trois styles, des pictogrammes d'application, des icônes du client d'origine. Pas de cadre par
rareté commun (les cases d'objet colorent le filet, les cartes colorent tout le fond).

### Rythme des couleurs
Indigo + or partout, puis des couleurs pures ponctuelles : vert `#73EB8C`, rouge `#FF5C5C`, bleu de rareté, orange vif de
l'Échiquier (`26` : plateau orange sur sable orange, cases peu lisibles). Pas de neutre chaud : le texte est blanc lavande,
froid à côté de l'or. Les couleurs de rareté sont saturées au maximum (`Items.RARITIES`).

---

## 4. Écran par écran

| Écran (capture) | Constat | Gravité | Correction |
|---|---|---|---|
| Titre (`01`) | Bon cadrage, scène 3D vivante. Logo Cinzel + filet à losange ; bouton « Jouer » brun en Cinzel, deux autres en Nunito | moyenne | logo dessiné (lettrage propre), un primaire, deux tertiaires sans boîte |
| Lobby (`02`, `03`) | Colonne de 7 boîtes égales ; verrous translucides illisibles ; 4 blocs d'information dispersés dans les coins | haute | menu en texte gravé (une plaque pour l'entrée active), voile dégradé à gauche, condition d'ouverture écrite (maquette `bible/maquette_lobby.png`) |
| Jouer (`03`, `04`) | Cartes riches (vraies images du jeu : bien) mais surchargées : pastille JcE/JcJ, 2 à 4 icônes, chaînes, cadenas, chevron | haute | image + voile bas + titre + une ligne ; récompenses en 2 icônes au plus ; verrou = image désaturée + petit cadenas + condition |
| Pages d'activité (`05`, `06`, `07`) | Structure claire (bandeau, « Donne », options, bouton épinglé). Duel : 3 rangées de boutons segmentés + liste de « X » rouges | moyenne | une rangée de choix visible, le reste replié ; coche / croix dessinées dans le style du jeu |
| Héros (`08`, `09`, `10`) | En-tête avec 4 formes de bouton ; catégories en 12 px ; 45 cases vides ; parcours de maîtrise à 9-11 px | haute | cases vides montrant la silhouette de l'emplacement, grille qui grandit avec le contenu, en-tête unique `PageScreen` |
| Coffres (`11`, `12`) | Vide sans image ; titres répétés ; lignes « icône ronde + Ouvrir » | moyenne | état vide illustré (coffre fermé, « Les boss en donnent ») ; liste en cartes de coffre avec le coffre en image |
| Atelier (`13`, `14`) | Trois niveaux d'onglets de même forme ; panneau dans panneau | haute | onglets d'écran (rail), sous-onglets (segmenté discret), filtres (liste) : trois formes différentes |
| Carnet, Registre (`15`, `16`) | Bonne idée (vue d'ensemble), exécution en tableau de bord : 10 barres vides, « 7 % » | moyenne | vue d'ensemble en « pages de livre » : 3 chiffres forts, le reste en liste ; jamais de % |
| Paramètres (`17`) | Lisible, infobulle fixe (bien) ; boutons de mode en grille de 7 boîtes ; termes anglais | basse | liste de modes en lignes avec description ; « Stratégie (vue de dessus) » au lieu de « RTS / MOBA » |
| Guide (`18`) | Très lisible ; touches en or sans dessin de touche | basse | dessiner les touches (plaque claire, `key` de la bible) |
| HUD (`19`, `20`) | Vie bien placée ; globe « RUN » obscur ; sorts vides en « — » ; télégraphes rouge pur ; textes flottants qui se chevauchent | haute | voir bible § Effets : rouge du danger désaturé et bordé, textes flottants empilés, un seul style de chiffre |
| Choix de carte (`21`, `22`, `28`) | Hiérarchie bonne (titre, 3 cartes, relancer) ; fonds de rareté pleins ; textes longs avec % | moyenne | carte sombre, rareté au cadre et au bandeau ; une phrase, détail chiffré en infobulle |
| Pause (`23`) | Même structure que Héros (bien) ; monnaies en icônes du client d'origine | basse | icônes de monnaie maison |
| Bilans (`24`, `25`, `27`) | Composant unique `ResultsPanel` (excellent) ; 6 tuiles égales ; « Retour au lobby » ; bouton primaire qui paraît éteint | moyenne | une tuile héroïne (le résultat), les autres en ligne ; primaire en plaque d'or |
| L'Échiquier (`26`, `27`) | Plateau orange sur sable orange ; bouton « Prêt » jaune vif d'un autre style ; boutique lisible | moyenne | plateau en pierre sombre et filets de bronze, « Prêt » = primaire de la bible |

---

## 5. Ce qui est déjà bon (à garder)
- **La structure** : `PageScreen` (titre, sous-titre, onglets, Fermer), `ResultsPanel` unique pour tous les bilans,
  `InfoCard` au lieu des fenêtres natives, `CardPicker` unique. La refonte peut changer la peau sans toucher la mécanique.
- **La navigation manette** (`UiNav`) : cadre qui saute au plus proche, barre d'aide, LB / RB ; rare dans un jeu amateur.
- **Les contrastes du texte** sur les panneaux (10 à 16:1) et le plancher `MIN_TEXT` (14).
- **Aucun débord à 1280×720**, infobulle fixe en pied des Paramètres, interrupteurs `UiTheme.Switch`.
- **Les cartes d'activité tirées de vraies vues du jeu** : elles relient le menu au monde ; à garder comme base de l'illustration.
- **La scène 3D vivante derrière le lobby et le titre**.
- La couleur indigo nuit + or est une bonne base : la bible la garde en la réchauffant (bronze, parchemin) et en ajoutant l'émail.

## 6. Priorités (dans l'ordre)
1. **Une famille de formes** (chanfreins, trois niveaux de profondeur, onglets en rail) : supprime l'effet « boîtes partout ».
2. **Deux polices et 7 tailles** ; chiffres alignés ; rien sous 14 px.
3. **Une seule famille d'icônes maison** (pictogrammes gravés + icônes peintes à cadre de rareté) ; fin des pictogrammes d'application.
4. **États** : la sélection en émail bleu, le focus en anneau clair, le désactivé avec sa raison.
5. **États vides illustrés** et grilles qui grandissent avec le contenu.
6. **Textes** : chasse aux % permanents et aux anglicismes (« partie », « menu principal », « panoplie »).
7. **HUD et effets** : lisibilité des télégraphes et des textes flottants.
