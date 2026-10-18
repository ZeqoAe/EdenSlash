# R_ACX4 : L'Échiquier, traits croisés et notes du joueur (17-18/10/2026)

Lot : retour à chaud du joueur (« les traits de la famille du Guerrier sont tellement bons qu'on veut toutes les classes
jaunes ») + six notes du joueur sur l'écran (`feedback/_SUIVI.md`). Mode scellé, IA scriptée seulement, DA v2 (UiTheme papier,
UiFeel, AutochessHud). Toutes les mesures : simulateur calé d'AC-J, parties entre IA (`tools/autochess_games.tscn` +
`tools/autochess_report.py`), machine partagée et saturée (20 à 60 Godot d'autres agents ; 3 à 25 s par partie).

## 1. Traits croisés
### Avant
5 familles (12 unités, seuils 3 / 6 / 9) + 10 traits d'arme (6 unités, 2 / 4 / 6) ; mais 6 traits d'arme sur 10 n'existaient
que dans une famille (Estoc = Rempart seulement, Tir et Poudre = Traque, Tranchant = Ombre, Chœur = Ferveur, Malédiction =
Arcane). Un plateau d'une couleur empilait donc famille + arme : Rempart + Estoc gagnait 31 % des parties, 93 % des
gagnants avaient 6 héros ou plus d'une seule famille.

### Après (`AutochessData.LINEAGE_STYLE`, `BRIDGES` ; `tools/autochess_units.py` régénère `data/autochess_units.json`)
- **Famille** (origine, inchangée) : identité de la lignée ; une lignée (classe verte + ses 2 éveils, coûts différents) garde
  ses deux traits, comme le joueur le proposait.
- **Style** (2e trait, transverse) : porté par la lignée, il réunit **2 lignées de 2 familles différentes**. Les 10 styles
  sont exactement les 10 paires de familles : chaque famille partage un style avec chacune des 4 autres.

| Style (2 / 4 / 6) | Lignées | Familles |
|---|---|---|
| Escrime | Templier · Danseuse de lames | Rempart · Ombre |
| Estoc | Chevalier · Rôdeur | Rempart · Traque |
| Fracas | Guerrier · Sage | Rempart · Ferveur |
| **Brasier** (ex-Poudre) | Chevalier dragon · Démoniste | Rempart · Arcane |
| Impact | Artiste martial · Luminaire | Ombre · Arcane |
| Tranchant | Voleur · Chasseur | Ombre · Traque |
| **Harmonie** (ex-Chœur) | Samouraï · Barde | Ombre · Ferveur |
| Malédiction | Inquisiteur · Clerc | Traque · Ferveur |
| **Cadence** (ex-Tir) | Ingénieur · Illusionniste | Traque · Arcane |
| Élémentaire | Chaman · Magicien | Ferveur · Arcane |

  Choix des paires d'après l'effet : les styles « d'équipe » (Harmonie, Malédiction) vont aux lignées de soigneurs, les
  styles d'attaque aux combattants et tireurs. Ids et effets des anciens traits d'arme **gardés** (sauvegardes, atouts
  « Maître d'armes », Emblèmes) ; trois noms changés parce qu'ils ne collaient plus (Tir, Chœur, Poudre).
- **5 unités ponts** (3e trait = la famille d'à côté, cycle Rempart → Ombre → Ferveur → Arcane → Traque → Rempart, un
  éveil de coût 3-4 choisi pour que l'effet lui serve) : Exécuteur +Ombre, Danseuse envoûtante +Ferveur, Chantre de vie
  +Arcane, Maître des chimères +Traque (« une classe descendante du mage a un trait en commun avec une autre famille »),
  Arès mécanique +Rempart.
- Interface : colonne des traits (infobulle : genre, familles reliées et héros, `AutochessData.trait_blurb`), fiche d'un
  trait (« Style : relie Rempart et Traque (6 héros) »), boutique (3e tuile d'une unité pont dans le pied de la carte, la
  hauteur ne change pas), fiche d'unité (3 lignes de trait pour un pont). Textes, SPEC §5.4, DESIGN, CLAUDE.

### L'IA (`AutochessAi`)
- Un plan part d'un **trait principal, famille ou style** (clé `meta.plan.family` gardée pour les sauvegardes) ; ses traits
  associés sont les styles de la famille, ou les deux familles du style (`_plan_weapons` généralisé) ; lecture des plateaux
  adverses par trait (un style disputé dès 2 unités vues). Notes : `TIER_VAL_WEAPON` 0,6 / 1,6 / 3,0 → **0,7 / 1,9 / 3,6**,
  `TIER_VAL_FAMILY` 2,2 / 4,5 → **2,0 / 3,8**, `DESIRE_FAMILY` 2,5 → **2,0**, `STYLE_PLAN` 1,3 (mesurées, passes vc / vd).
- Le combat (IA d'unité d'AC-U, `autochess_unit.gd`) n'est pas touché : le banc `autochess_ai_bench` (99 % contre l'IA
  naïve) reste valable.

### Mesures (mise en place « echelle » ; l7r, r7l, pilote à part)
| Mesure | Avant (HEAD 0.1.315, 510 parties) | Après (600 parties) | Cible |
|---|---|---|---|
| 1re composition gagnante (famille + style principaux) | **31 %** (Rempart + Estoc) | **17 %** (Rempart + Estoc) | ≤ 22 % |
| compositions gagnantes distinctes (nombre effectif) | 16 (8,4) | **34 (17,7)** | plus |
| entropie des compositions gagnantes | 2,13 | **2,87** | plus |
| paires de traits principaux (tous genres) : distinctes (effectif) | 23 (9,0) | 39 (20,4) | — |
| gagnants avec 6 héros ou plus d'une même famille | **93 %** | **34 %** | — |
| plateau du 1er pris dans une famille (moyenne) / aux ¾ d'une couleur | 87 % / 90 % | 60 % / 24 % | — |
| famille au palier 6+ chez les gagnants : Rempart / Ombre / Traque | 38 / 13 / 23 % | **27 / 12 / 9 %** | ≤ 25 % |
| famille « principale » des gagnants (palier puis compte) : Rempart | 40 % | 38 % | ≤ 25 % (voir écarts) |
| combat JcJ médian / sous 40 s / égalités | 22,5 s / 97 % / 0,8 % | 22,3 s / 98 % / 0,5 % | 22-28 s / ≥ 90 % / < 3 % |
| partie ×1 (×2) / manches | 29,6 min (22,7) / 33,4 | 29,8 min (23,0) / 34,2 | 25-30 min / ≈ 35 |
| 1re élimination avant 4-1 | 8 % | 3 % | < 20 % |
| échelle R / V / C / L (place) | 7,13 / 4,62 / 3,21 / 3,04 | 7,13 / 4,68 / **3,09 / 3,10** | décroissante |
| Légende contre 7 Recrues (top 4) / Recrue contre 7 Légendes / pilote Vétéran | 100 % / 0 % / 46 % (AC-J) | 98 % / 1 % / 48 % | ≥ 75 / ≤ 25 / ≈ 50 % |
| Éclair (200 parties) : 1re composition / partie | 18 % / 14,4 min | 16 % / 14,4 min | ≤ 20 % / 12-15 |

Passes d'essai (copies à part, 300-420 parties) : **v1** (traits croisés seuls) 13 % / 30 compositions / 70 % d'une
couleur ; **va** (`ROLE_BASE` tank : PV 1,35 → 1,3, défense 30 → 24) et **vb** (va + Rempart 5 / 15 / 30, Ferveur et Arcane
relevés) : la famille Rempart reste à 37-38 % des gagnants, rien gardé (le levier tank ne change pas la répartition) ;
**vc / vd** (notes de l'IA, retenue : vd) : plateaux aux ¾ d'une couleur 50 → 25 %.

### Écarts qui restent
- **« Famille principale » Rempart à 38 % des gagnants** : les 9 tanks du jeu sont tous de la famille du Guerrier ; tout
  plateau qui aligne 3 tanks a donc Rempart pour famille la plus haute, même quand il est mêlé. Mesuré autrement, la
  domination a fondu (Rempart à 6+ chez 27 % des gagnants, plateaux d'une couleur 90 → 24 %). Pour descendre sous 25 %, il
  faudrait des tanks hors de la famille du Guerrier (rôle de l'annexe A, décision de conception) : à trancher.
- **Légende au niveau du Champion** (3,10 contre 3,09 ; avant 3,04 contre 3,21) : le Champion, qui relit les plateaux à
  chaque étape, profite le plus des plans de style ; la Légende reste devant contre 7 Recrues (98 % de top 4) et devant le
  Vétéran. Essai rejeté (ve, 2 × 330 parties) : la Légende change de plan dès l'étape 2 avec une marge de 1,5 ou 0,8 :
  3,10 / 3,19, rien de mieux. À reprendre (plans de la Légende pensés pour les styles).
- Unités hors 40-60 % de top 4 relatif : 9 (Paladin, Annihilateur, Dompteur de dragons, Asura, Héritier du sabre, Flèche
  absolue, Prêtre de l'ombre au-dessus ; Psalmiste, Sage en dessous) ; paliers 2 de Rempart, Ombre, Estoc, Escrime,
  Harmonie au-dessus de 60 %.

## 2. Notes du joueur (une ligne chacune dans `feedback/_SUIVI.md`)
| Note | Fait |
|---|---|
| (a) « Verrouiller » ne doit valoir que pour la prochaine manche | le verrou saute au début de la préparation suivante (`Autochess._begin_prep`) ; infobulle « prochaine manche seulement » ; les IA reverrouillent si elles veulent (même comportement mesuré) |
| (b) la fiche de détail apparaît et disparaît aussitôt | la ligne « Viser : T » de la fiche (ACX-3) prenait la souris : en allant vers la fiche, on quittait le héros visé et elle se fermait. La fiche **reste tant que la souris est dessus**, « Viser » est cliquable, la fiche se remet à jour après T / stick droit / clic ; elle peut aussi sortir à côté de sa cible en montant (plateau d'objets) |
| (c) l'or en 5 sacs comme TFT, aussi chez les adversaires | `AutochessHud.GoldBags` : un sac par tranche de 10 or, plus ou moins rempli, contour pomme quand il rapporte 1 or d'intérêts (10 sacs avec Intérêts composés, grisés en Éclair) ; sur l'onglet de l'or et sur la ligne de chaque stratège (bulle : or en chiffre) |
| (d) composants en icônes à gauche, des enclumes avec les atouts à la place des objets | plateau « Objets » en bas de la colonne gauche (`AutochessHud.ItemTray`, 2 × 5) : ses icônes sont les cases « items » du curseur (`AutochessCursor.use_item_tray` : clic puis clic sur un héros, glisser-déposer, croix et A, fiche et recettes au survol) ; la colonne d'objets du plateau 3D montre **une enclume par manche d'atout** avec l'icône de l'atout pris (`AutochessBench.anvil_mode`), survol = fiche de l'atout |
| (e) défaite contre les monstres du tout début avec 3 héros | mesuré (300 parties arrêtées à 2-1) : 1-2 et 1-3 gagnées à 100 %, **1-4 (2 élites + 2 sbires) gagnée à 41 %** (Recrue 18 %) ; passé à **1 élite + 2 sbires : 96 %** (Recrue 89 %, Vétéran 97 %) ; essai 1 élite + 3 sbires : 78 % |
| (f) pendant le combat, vendre ses héros et en acheter | `Autochess._can_shop` : achat, actualisation, XP, verrou et vente **des héros du banc** pendant le combat et le bilan ; le plateau ne bouge pas (un achat va au banc ; une fusion qui toucherait un héros du plateau attend la préparation, `_merge_deferred`) ; rien d'annulable hors préparation. Écran : bouton **Boutique** (B, RB) au combat → boutique ouverte, banc en vignettes au-dessus (clic droit ou E : vendre, A / clic : vendre après confirmation ; un héros précieux demande toujours), « Voir le combat » (B) la replie ; 1 2 3 achètent quand la boutique est ouverte (vitesse sinon) |

## 3. Performances (suite de PERF-1)
- `AutochessBoard._sync_figures` : les figurines **adverses** se créent au fil des images (6 ms par image au plus, au moins
  une) ; celles du joueur restent immédiates. En vrai combat, l'écran ne pose plus les figurines adverses (le directeur
  les cache et pose ses combattants : jusqu'à 98 ms pour une image) : seul le stratège adverse est posé.
- Mesure `tools/ac_ready_probe.tscn` (10 manches, fenêtre, même graine, machine saturée : 38-60 Godot d'autres agents,
  images très bruitées), avant / après ce correctif sur la même copie : manches JcJ, appel de Prêt médian **41 → 34 ms**,
  première image après Prêt médiane **427 → 90 ms** (une manche à 1 s après, bruit de la machine) ; à refaire au calme.
- Non fait : réserve d'unités recyclées pour la fin de manche (~2 000 nœuds libérés) : dans `autochess_director.gd`, à
  faire avec une mesure au calme.

## 4. Tests et captures
- `test_acx4` (nouveau) : styles à deux familles, chaque famille liée aux 4 autres, lignées, ponts, textes ; IA Légende
  (plans de style, plateaux mêlés) ; verrou d'une manche ; vague 1-4 ; boutique au combat (achat, plateau intact, vente au
  banc permise / au plateau refusée, fusion à la préparation) ; écran : sacs (toi et 8 lignes), plateau d'objets (case
  2D du curseur, prise puis pose sur un héros), enclumes, « Viser » cliquable, combat : Boutique, vignettes, vente, textes.
- Mis à jour : `test_ac_data` (styles, ponts, 13 par famille), `test_ac_effects` (porteurs des styles), `test_acx1`
  (Tranchant 1 → 2, Ferveur et Malédiction du Clerc). Verts sur une copie de HEAD + ce lot : test_ac_data, test_ac_game,
  test_ac_effects, test_ac_ui, test_ac_board, test_ac_ai, test_ac_rewards, test_ac_stats, test_ac_sim_real, test_acx1,
  test_acx2, test_acx3, test_acx4, test_nav_screens, test_texts_fr.
- Captures `tests/shot_acx4.tscn` (1280 × 720 et 1600 × 900, regardées, 0 débord) : objets et enclumes, fiche d'un style,
  carte d'une unité pont, combat boutique ouverte / repliée ; `shot_ac` relancé.
- `tests/ac_mesures.json` refait (bloc `games` et `eclair` de cette passe).

## 5. Outils
- `autochess_report.py` : lignes « Entropie », « Paires de traits principaux » (tous genres), part du plateau du 1er dans
  une famille, écart « une famille > 25 % » ; `--data=<dossier game>` pour lire les tables d'une autre copie (mesure avant).
- `autochess_games.tscn` : `--set=clé:json` (règle d'essai dans `Autochess.rules`, ex. `monster_waves`), `--stop=E-M`
  (arrêt à une manche : mesure de l'étape 1), `pve1` par stratège (monstres de l'étape 1 : gagné, unités, coût).
