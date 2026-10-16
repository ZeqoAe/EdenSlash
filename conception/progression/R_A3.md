# R_A3 — « Fabriquer » lisible (lot A3 de la refonte Aventure)

## Fait
- Atelier : onglet **Armurerie -> « Fabriquer »**, onglet **Fabrication -> « Plans de donjon »** (intitulés dans `ui/lobby.gd`,
  contenu de la 2e page à A1). Même catalogue, mêmes prix (`Economy.armory_price`), mêmes filtres.
- `ui/gear_shop_page.gd` : bouton « Fabriquer · N insignes » (le mot « acheter » n'apparaît plus pour une pièce), statuts
  **À fabriquer / Fabriquées / Plans à découvrir / Tous**, compteur « N / total plans découverts », silhouette « Plan à découvrir »,
  messages d'état vide reformulés, sous-titre « Pièces dont tu as le plan ».
- Ligne **« Plan trouvé : Époque I · Monts Calcaires »** dans le détail d'une pièce dont le plan est connu, **« Plan à trouver : … »** sur
  un plan à découvrir. Le lieu est la première carte dont un coffre propose la pièce : `Completion.plan_place(id)`
  (`core/completion.gd` garde maintenant la carte en plus de l'époque, `Completion.armory_ids()` est inchangé ; le cache disque
  `armory_cache.json` porte une clé `stages`, un vieux cache sans elle est recalculé).
- Carnet : la catégorie « Équipement » devient **« Plans »** (« plans de pièces découverts »), même position, même lien vers le Registre.
- Tests : `test_workshop` (statuts, bouton, aucun texte « achet… » dans la page, `plan_place`, lignes « Plan trouvé / à trouver »),
  `test_pages` (noms d'onglets), `test_loot` (catégorie « Plans »).

## Décisions
- Identifiants internes gardés (`_buy`, `_on_buy`, états `buy` / `owned` / `locked`, `GearShopPage`, `Unlocks "armory"`) : les tests et
  les autres lots s'en servent ; seuls les textes lus par le joueur changent.
- « Plan trouvé » n'est pas la carte réellement jouée (non enregistrée) mais le premier endroit du catalogue : infobulle sur la ligne.
- Les textes disent encore « Survie » (renommage en lot A9).

## Restes pour les autres lots (textes qui citent encore « Armurerie » / « Fabrication »)
`core/compass.gd`, `core/class_gear.gd` (« Survie, puis Armurerie », testé par `test_e3`) : A8 ; `core/resource_help.gd` : A1 ;
`ui/guide.gd`, `ui/info_page.gd`, `ui/difficulty_panel.gd`, `ui/results_screen.gd`, `core/pantheon.gd`, `core/unlocks.gd` (« Atelier :
Armurerie ») : à reprendre au lot A9 (renommage) ou A8.
