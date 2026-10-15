# R_U6 — Infobulles d'objets (lot U6 = L6 de A2)

**Fait** : la carte d'objet (`Items.describe`, `ItemWidgets.item_card`) est refaite ; plus aucune mention du jeu d'origine sur les cartes.
Fichiers : `core/items.gd` (partie affichage), `ui/item_widgets.gd`, `core/archive.gd` (2 phrases), test `tests/test_tooltips.tscn`,
captures `tests/shot_tips.tscn` (images regardées dans `captures/u6/`).

## La carte, de haut en bas
1. Icône, nom à la couleur de la rareté (le nom de la panoplie entre parenthèses est retiré du titre : il est écrit plus bas).
2. « Rareté · emplacement · niveau » puis **PE de la pièce** (en doré) et qualité.
3. **Statistique principale en gros** : attaque (armes, gants, bagues), défense puis PV (armures, capes, bottes), PV (colliers) ;
   écart dû à la qualité et au +N entre parenthèses (vert / rouge).
4. Cinq lignes secondaires au plus (les plus lourdes pour l'emplacement) puis « + N autres statistiques ». Les affixes sont en bleu.
5. Passif, gemmes (et emplacements vides), enchantement.
6. Panoplie **« x / N »** (N = dernier palier du set) et **panoplie de donjon** (archétype) avec le **prochain palier** seulement.
7. Comparaison avec la pièce portée : nom, verdict (▲ Meilleur / ≈ Équivalent / ▼ Moins bien), écart de PE, une ligne ▲ vert / ▼ rouge
   par différence (5 au plus, les plus lourdes d'abord).
8. « Maj : détails ».

**Maj** (touche tenue, la carte se met à jour pendant l'affichage) : tous les paliers de panoplie, bonus d'amélioration, « Prochaine
amélioration : x % » (jamais en run), niveau de puissance (en run : « suit ton niveau, plafond N »), ligne « Enclume de la run », toutes
les différences. Les pages qui affichent une fiche à demeure (`Items.describe(item)` : Atelier, marchand, outils de dev) gardent la carte complète
(le paramètre `detailed` vaut vrai par défaut : aucune de ces pages n'a été modifiée).

## Décisions
- **Dédoublonnage** : une statistique plate et son pourcentage du même nom (`def`/`def_pct`, `matk`/`matk_pct`, `str`/`str_pct`…) tiennent sur
  une seule ligne (« Défense 231 (+32) +4 % »). La table est `Items.PCT_OF`.
- **Niveau d'Eden** : le « niveau N » de la pièce (celui du coin des cases) reste sur la carte comme niveau d'objet, sans le mot Eden ; la
  ligne « Dans Eden : … » est supprimée ; « Suit ton niveau en run jusqu'au niveau N » passe derrière Maj.
- **Survie (N1)** : la pièce portée s'affiche et se compare avec le bonus d'enclume de son emplacement (`Items.anvil_applied`, copie ; la pièce
  d'origine ne change pas). `Items.compare_to_equipped` applique l'enclume aux deux pièces (la nouvelle pièce prendrait aussi le bonus de
  l'emplacement) : le verdict ▲ / ▼ de la case et celui de la carte restent d'accord. La PE de la ligne de comparaison (`GearPower.delta_if_equipped`,
  fichier hors lot) n'applique pas l'enclume : écart d'au plus quelques points.
- **Noms (U10)** : rien à changer, `display_name` lit déjà le nom français.
- Filet horizontal : `[hr color=…]` du moteur (Godot 4.7), constante `Items.SEPARATOR`.
- `archive.gd` : les phrases de `source_text` étaient déjà propres (U7) ; la carte des trésors de collection raccourcie (2 phrases), commentaire d'en-tête sans « Eden ».

## Mesures et tests
- `test_tooltips` : 54 pièces (6 raretés × 9 emplacements), cartes courte et complète sans erreur, pas de mot « Eden » / « Dans », pas de doublon de statistique,
  statistique principale en gros, courte ≤ 18 lignes, complète ≥ courte, PE / passif / gemme / enchantement / panoplie x / N / archétype, fusion Défense,
  comparaison (nom, verdict, flèches, couleurs), widget (courte, complète, bascule Maj, traitement par image coupé hors Maj), enclume de Survie. Tout OK.
- Autres tests relancés : `test_names_fr`, `test_items`, `test_lot7`, `test_lot18`, `test_gear_run`, `test_nav_screens` OK ; `test_build` (1 échec : « pause : compétences sur 12 lignes »,
  `ui/run_page.gd`, lot U9) et `test_pages` (5 échecs : apparences du Héros, lot U4) ne viennent pas de ce lot (aucune ligne d'objet en échec).

## Pièges
- Le moteur remet `_process` à vrai quand un nœud entre dans l'arbre : `ItemCard._ready` le recoupe (sans cela une carte « complète » forcée repassait en courte).
- Les infobulles natives n'ont pas pu être survolées par script (la souris synthétique ne déclenche pas l'infobulle) : la carte, sa bascule Maj et son
  changement de taille (`reset_size`, fenêtre d'infobulle à contenu enveloppé) sont vérifiés par le widget, pas par un survol réel. À confirmer à la souris.
- Pas de touche Maj à la manette : la carte reste courte (les détails sont dans les pages Atelier / Héros).

## Reste
- Cartes de sorts (`ui/spell_info.gd`, « Eden Eternal : … » à retirer) et mentions d'Eden restantes hors de mes fichiers (lot U4/U5) : `inventory_page.gd:836`,
  `merchant_pages.gd:278,410`, `talents_page.gd`, `hero_pages.gd`.
- Les cartes embarquées à demeure (`chests_page.gd`, `gear_shop_page.gd`) appellent `item_card(it)` : courte + Maj ; si le lot U3 veut la carte complète, passer `mode = 1`.
