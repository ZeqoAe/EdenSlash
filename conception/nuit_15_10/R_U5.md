# R_U5 — Atelier et marchand (lot L5 de A2, version 0.1.176)

Fichiers : `ui/gear_shop_page.gd` (réécrit), `ui/fabrication_page.gd` (réécrit), `ui/forge_bench.gd` (réécrit), `ui/merchant_pages.gd`, `ui/merchant_ui.gd`,
nouveau `ui/workshop_purse.gd`. Tests : nouveau `tests/test_workshop.tscn` (45 contrôles), `test_nav_screens` (Armurerie remplie, Forge, Forge avec pièce).
Outils de capture : `tests/shot_atelier.tscn` (compte neuf puis avancé, 3 onglets, 6 établis, verdict) et `tests/shot_merchant.tscn` (Boutique, Vendre, Forge de run).
Captures regardées une à une : `captures/u5/` (`atelier_neuf_*`, `atelier_avance_*`, `merchant_*`).

## Fait
- **Bourse commune** dans l'en-tête de l'Atelier : insignes (acquérir) et cristaux (optimiser), quel que soit l'onglet ; les trois onglets n'ont plus leur propre
  total. Sous-titre par onglet (« Pièces découvertes en Survie », « Plans de donjon, contre des cristaux », « Améliorer, enchanter, sertir »), plus de liste des onglets.
- **Armurerie** : le catalogue entier (1 811 pièces avec les capes d'E4 ; `Completion.armory_ids()` donne maintenant la première époque de chaque pièce), compteur
  « 48 / 1 811 découvertes » avec le vrai total. Statut : à acheter (défaut), possédées (✓ grisées), à découvrir (case « ? » avec emplacement et niveau ; le détail dit
  « Coffres d'emplacement · Époque II », jamais le nom), toutes. Filtres emplacement, époque, classe (ses armes seulement) ; 84 pièces par page. Prix en pastille
  sur chaque case, dans le bouton, et « Il te manque N insignes » en rouge. Le pavé de comparaison de 6 lignes est remplacé par le verdict (« Meilleur +20 % »),
  la PE et trois écarts au plus. Panneau de droite caché quand il n'y a rien à montrer. Après un achat la pièce reste choisie (un double clic n'achète pas deux fois).
- **Fabrication** : une carte par donjon (panoplie, emplacement, « Fabriquer · 60 cristaux », « il te manque N cristaux » en rouge), les plans trouvés d'abord ; sans plan :
  bandeau « Aucun plan pour l'instant / Termine un donjon pour en recevoir le plan » (ou la condition d'ouverture des donjons), cartes « Termine ce donjon pour recevoir
  son plan ». Les bonus de panoplie passent en infobulle. `SLOTS` / `COST` / `craft` inchangés (E2 a déjà élargi `SLOTS` : l'interface suit la constante).
- **Forge** : un seul panneau. Six établis en haut ; la pièce ; le tableau **avant → après** (Amélioration +3 → +4, quatre stats principales, « Stat bonus +1 au hasard » aux
  paliers, Qualité 91 % → jusqu'à 100 %, Cristaux 420 → 423 au démontage, Emplacements 0 / 2 → 1 / 2) ; la ligne **Coût** (icône, « 20 cristaux », « tu en as 420 », en rouge
  s'il manque) ; l'action principale épinglée en bas, la barre de verdict compacte au-dessus (cachée au repos, effacée quand on change de pièce ou d'établi). Prix partout
  en mots (`MerchantPages.price_words` : « 1 cristal », « 3 cristaux », « 90 or ») ; plus de « crist. ». Plus aucun paragraphe d'aide.
- **Fusion de gemmes recalée** (note de R_E1) : `Forge.fuse_price(tier)` : or en run, cristaux hors run au taux 25 (2 / 4 / 5 / 7 cristaux) ; `Forge.fuse` paie ce même prix et
  l'interface l'affiche. Avec le taux 125 la fusion coûtait 1 à 2 cristaux : presque gratuite.
- **Marchand de run** : une ligne sur la Boutique (« L'or est perdu en fin de run : dépense-le. »), plus de sous-titres longs, plus de « Ton or » / « Prix » en double (le bouton
  et la bourse le disent), sélections rapides de Vendre simplifiées, `CraftPage` (fabrication de mythiques « Plans d'Eden », code mort) et `bag_text` supprimés, plus de ligne
  « Eden : … » dans les infobulles de fournitures.

## Décisions
- Silhouettes sans icône : les icônes d'objets ont un fond opaque (une silhouette noire donnait un carré noir) et montrer l'icône dévoilerait la pièce.
- Forge de run (`ForgePage`, marchand et fiche d'objet du hub) gardée en sections : elle sert en pleine partie, où voir fortifier / polir / gemmes d'un coup est utile ; seule
  l'Atelier a l'établi.
- Après un achat, pas d'avance automatique vers la pièce suivante : sûreté contre le double clic.
- Statut par défaut « À acheter » plutôt que « Toutes » : c'est le geste du joueur ; les silhouettes sont à un clic.

## Mesures / pièges
- `Completion.armory_ids()` coûte ≈ 0,9 s au premier appel (324 tirages de `SlotChests.pool` sur ~10 000 entrées) : la page le lance en différé à sa création (au chargement du
  lobby) plutôt qu'au premier clic. Une vraie optimisation de `SlotChests.pool` (index par emplacement) reste à faire (hors lot).
- La Fabrication et l'Armurerie lisent `Items.SLOTS` / `FabricationPage.SLOTS` / `Completion.armory_ids` : E2 (Panoplie des Esprits dans `seen_gear`, ids ≥ 900 000) et E4 (cape,
  armes des autres types) y entrent sans retouche ; les pièces vues hors catalogue sont listées (époque 0 : visibles seulement avec « Toutes les époques »).
- Fichiers d'autres lots touchés (retouches minimales) : `core/completion.gd` (la valeur de `_armory_ids` devient l'époque), `core/forge.gd` (`fuse_price`), `ui/lobby.gd`
  (2 lignes : titre sans sous-titre et bourse), `tests/test_nav_screens.gd` (3 sondes).
- `test_loot` a planté un moment sur du code d'un autre lot en cours (`last_shared`) ; relancé vert ensuite.

## Reste
- Le « Eden : … » des infobulles de fournitures vient aussi de `Craft.describe_key` (`core/craft.gd`, hors lot) : « (Épée de lumière) » entre parenthèses.
- La Forge de run (sections) n'a pas le tableau avant → après ; à unifier si le joueur le demande.
- Noms de classes dans le filtre : tri alphabétique de `name_fr` (60 entrées) ; un regroupement par famille serait plus court.
