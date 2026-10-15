# R_U7 — Carnet (lot L7 de A2)

Fichiers : `ui/carnet_pages.gd` (réécrit), `ui/archive_pages.gd`, `ui/page_screen.gd`, `ui/info_page.gd` (2 mots), tests `test_lot11`, `test_nav_screens`, nouvel outil `tests/shot_carnet.tscn`.
Retouches hors lot (minimales) : `core/archive.gd` (textes `source_text`, `collection_text`, `refusal` : plus de « Eden »), `ui/lobby.gd` (une ligne : le Carnet prend `CarnetPages.tabs()`).
Captures regardées : `captures/u7/carnet_neuf_*.png` (compte neuf) et `carnet_avance_*.png` (compte avancé, 6 pièces archivées).

## Fait
- **Sous-titre par onglet** : `PageScreen` lit `subtitle()` sur la page affichée (sinon le sous-titre de l'écran : rétrocompatible, les autres écrans ne changent pas). Plus de
  « Archive des trésors… » partout. Ajout de `page_count()`.
- **Onglets extensibles** : `CarnetPages.tabs()` ; le Registre de l'équipement (E3) s'ajoute à la fin de la liste (la Collection garde l'indice 4, `test_pages` l'utilise).
- **Vue d'ensemble** : bandeau (pourcentage en grand, barre, « Le plus avancé : … ») puis les 10 catégories en cartes de 2 colonnes, sans défilement ; les cartes qui ont une
  page (Succès, Cartes, Trophées, Classes, Maîtrise) sont cliquables (›). « Déblocages » et la phrase « Rien de ce qui est compté… » supprimés.
- **Succès** : compteur, filtre Tous / En cours / Obtenus, 2 colonnes, obtenus d'abord puis en cours par avancement, date en français, état vide utile (« Commence par … »).
  Titres : pastilles à bascule (second clic = retirer), absentes tant qu'aucun titre n'est gagné ; plus de « Aucun titre » ni de phrase « sans aucune statistique ».
- **Cartes** : plus de liste de 49 lignes (doublon de Héros > Cartes) : compteur, barres par rareté, 5 prochaines cartes à débloquer avec progression, bouton « Voir toutes les cartes »
  (ferme le Carnet, ouvre Héros > Cartes).
- **Trophées** : cartes des seuls effets découverts (+ « Encore N effets à découvrir »), état vide utile, décimales françaises (« 1,0 s »), phrase d'aide supprimée.
- **Collection** : tris/filtres sensés (Tous / Obtenus / Manquants ; Obtenus d'abord par défaut / ordre du catalogue / inversé) à la place de 2 cases invisibles et du filtre « boutique » ;
  « Taux : x % (a / b) » → « a / b » ; colonne de droite « Avancement » sans score ni pourcentages, milliers séparés (« 10 500 ») ; fiche de détail cachée sans sélection ;
  les 3 phrases d'aide supprimées ; états vides courts ; « onglet Tenues » (n'existe plus) → « Héros > Apparence ».
- **Eden** : « (niveau %d dans Eden) », « Niveau %d d'Eden… », « Dans Eden : … », « boutique d'Eden », « Monture d'Eden », « comme dans Eden » dans les infobulles de collection ;
  `info_page.gd` : « pièces d'Eden », « fiche d'Eden ». Les données ne changent pas.
- Tests : `test_lot11`, `test_pages`, `test_nav_screens` verts (sauf « cadre doré caché… » qui est celui de U8, hors lot). `test_nav_screens` vérifie un sous-titre distinct par onglet et le lien Cartes → Héros.

## Décisions
- Cartes : j'ai gardé l'onglet (compteur + lien, comme demandé) plutôt que de le supprimer : il montre en plus les prochains exploits à accomplir, ce que Héros > Cartes ne met pas en avant.
- Tri des Succès : « obtenus d'abord » pour cohérence avec la Collection et le Codex ; « En cours » est à un clic.
- Aide (`InfoPage`) non fusionnée dans le Guide : L2 n'est pas passé. Seules les mentions d'Eden y ont été retirées.

## Restes / pièges
- « Fléau d'Eden » (succès + titre, `core/achievements.gd`) : nom du monde, laissé ; à trancher par le joueur.
- Noms d'objets / zones encore en anglais dans la Collection et le détail (« Swift Wind Katana », « Blackflame Peak ») : lot U10.
- `ItemGrid` du coffre (filtres Toutes raretés / Tous types / Tri) reste affiché même vide : `ui/item_widgets.gd` (U6).
- `README.md` parle encore de « l'archive d'Eden » (documentation, pas le joueur).
- `core/archive.gd` : U6 y a prévu des retouches (A2 §6.1) ; les textes ci-dessus sont déjà faits, relire avant d'y toucher.
- Registre de l'équipement (E3) : ajouter `["Registre", RegistryPage.new()]` à la fin de `CarnetPages.tabs()` ; héritez de `CarnetPages.ScrollPage` (`heading`, `bar`, `card`, `cards_grid`, `empty`, `chips`) pour un cadre identique.
- Un faux positif possible : `Profile.title` supprimé par second clic sur la pastille ; pas de confirmation (réversible).
