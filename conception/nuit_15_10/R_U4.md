# R_U4 — Héros (lot L4 de A2)

Fichiers : `ui/hero_screen.gd`, `ui/hero_pages.gd`, `ui/inventory_page.gd`, `ui/equipment_page.gd` (réduit à un espace de noms : `PresetBar` et `HeroPreview`),
`ui/talents_page.gd`, `ui/grimoire.gd`, `ui/spell_info.gd`, `ui/class_picker.gd`, tests `test_pages` (section Héros), `test_nav_screens`, nouvel outil `tests/shot_hero.tscn`.
Captures regardées une à une (compte neuf, compte équipé, pause en Survie) : toutes les sous-pages, le Grimoire, le menu des classes, le Guide ouvert par « ? ».

## Fait
- **Équipement** : plus de carte « Classe affichée » (la classe est celle de la carte en haut à droite) ; **3 préréglages** en tête de page (un clic change, « Gérer ▾ » :
  copier l'équipement porté vers un autre préréglage avec le nombre de pièces remplacées, renommer), message bref sous les filtres. La **fiche d'objet est cachée sans
  sélection** (la grille gagne 280 px) ; les deux notices et « Bonus de set » vide sont partis. **Comparaison visible** : carte « Pièce portée » (icône, nom, niveau, ▲ / ▼ en %,
  variation de puissance d'équipement) à côté de la pièce choisie, écarts par statistique en vert / rouge, statistiques sur 2 colonnes ; l'arme d'un autre type se compare à
  l'arme secondaire. Panoplie : une ligne « Aucune panoplie active / Nom · N pièces » + bouton « Panoplies » (liste des pièces en infobulle). État vide : « Ton coffre est vide… ».
  Pause en Survie : ni préréglages (classe fixée) ni bouton Forge. « Prochain niveau : x % » et la règle du prix hors run sont passés en infobulle du bouton Forge.
- **Classe** : maîtrise (niveau + barre chiffrée) et parcours toujours visibles, puis **3 sous-onglets** Sorts (tuiles ; un clic ouvre le Grimoire sur ce sort), Talents (points et
  « Réinitialiser » seulement ici, paliers en infobulle), Certificats (plateau, bonus de placement, légende des couleurs, liste « Disponibles »). Les 5 phrases d'aide sont parties.
- **Apparence** : « Débloqués uniquement » **activé par défaut** et visible (interrupteur doré), « 122 à découvrir : butin des boss », texte récapitulatif sous la poupée supprimé
  (il ne reste que le bonus de l'aura), astuce de caméra courte, plus de phrase de 330 caractères sur l'arme.
- **Cartes** : plus de sous-titre ni de phrase d'intro (le détail est dans l'infobulle du compteur, sans « Eden »), titres de groupes courts, icône dans la fiche.
- **Grimoire** : ligne du combo supprimée (obsolète depuis 0.1.127), aide des compétences supprimée, éditeur de presets en infobulle, textes de l'arme et du certificat raccourcis ;
  `open(classe, id_sort)` ouvre sur un sort. **Sorts** (`spell_info.gd`) : plus de « Eden Eternal : … », plus de description répétée sous « Effets » (1015 sorts testés : tous
  ont des lignes d'effets), plus de légende des attributs dans les statistiques de base.
- **Aide « ? »** : ouvre le **Guide sur ses formules** (U2 y a rangé `InfoPage`) ; plus de page d'aide à part dans l'écran Héros.
- **Écran Héros** : plus de sous-titre, plus de carte de zone (reliquat), **LB / RB** changent de section (`step_page`, groupe `tab_screens`).
- **Eden** : « Eden Eternal : … » (sorts, talents), « objet d'Eden (niveau … dans le jeu d'origine) », « Costumes / Apparences d'armes d'Eden », « Coloris d'Eden », « Les sets d'Eden… »,
  « bonus d'Eden », type d'armure anglais de la fiche : retirés. Sélecteur de classe : plus de nom anglais ni de phrases d'explication.

## Décisions
- `EquipmentPage` n'était plus une page (l'écran utilise `InventoryPage`) : j'ai supprimé son code mort et gardé le nom comme espace de noms, pour y mettre `PresetBar`.
  **Point d'entrée pour E3** : `hero.page.preset_bar.extra_actions.append({"label": "Équiper le meilleur", "call": func(cid): …; return "message", "tip": "…"})` ; l'entrée apparaît dans « Gérer ».
  La barre est cachée en run : l'action n'y est proposée qu'au hub.
- « preset » (sorts) est resté tel quel : `core/duel.gd` et `lobby.gd` y renvoient (« Grimoire > Créer un preset »). Les préréglages d'équipement s'appellent déjà « préréglages ».
- La description de sort a été retirée (et non les puces) : les puces sont chiffrées et couvrent toutes les descriptions ; seul le bonus conditionnel de « Volonté du sanctuaire » (immunité sous Bénédiction solaire) n'est plus écrit.
- Le « ? » ouvre le Guide plutôt que de disparaître : l'aide reste à un clic dans l'écran.

## Mesuré
`test_pages` 214 OK, `test_nav_screens` 59 OK (Héros : 77 à 92 contrôles atteignables par écran, y compris le menu « Gérer »), `test_lot11`, `test_lot9`, `test_cards`, `test_hud` verts.
Nouveaux contrôles : fiche masquée sans sélection, pièce portée à côté, menu « Gérer » + action ajoutée, changement de préréglage, sous-onglets, sort → Grimoire, LB / RB, filtre par défaut, « ? » → Guide.

## Reste / pièges
- Pas de jauge d'amélioration ni d'infobulle flottante à la place de la fiche (P3 de A2) ; l'Aide du menu pause (U9) est la même `InfoPage`.
- Noms de costumes « Tenue secrète n°N » (10 vignettes sans nom) : données, visibles seulement si « Débloqués uniquement » est désactivé.
- Les captures de test (`shot_hero`) créent un compte avec 12 pièces ; lancer avec `APPDATA` détourné (comme les autres `shot_*`).
- Piège d'outillage : plusieurs sessions éditent la même arborescence ; un fichier d'un autre lot qui ne compile pas pendant quelques minutes fait échouer tous les tests (relancer).
- `test_tooltips` (U6) : « la ligne fusionnée porte le pourcentage » échoue au moment de mes tests (hors lot) ; `test_build` : « pause : compétences sur 12 lignes » (U9, `run_page.gd`).
