# R_GX5 — Talents v2, titres, Registre v2, « Ouvrir tout », jalons, préréglage d'activité, Reporter (17/10/2026)

Lot GX-5 = les P1 restants de l'étude `conception/benchmark/HEROS_EQUIPEMENT_PROGRESSION.md` (BM-GEAR, recommandations validées) :
talents v2, titres dans Héros (Q9), Registre v2, « Ouvrir tout » des coffres, jalons du niveau de héros, choix du préréglage sur
la page d'une activité (Q6) et « Reporter le +N » (Q2). DA v2 (`UiTheme` papier, `ForgeWidgets.candy_button`, pictogrammes ICO-1).

## Fait
- **Talents v2** (`ui/talents_page.gd`, `core/profile.gd`) : points libres toujours visibles (« 3 points libres · 14 placés »,
  depuis Sorts, Talents et Certificats ; un clic ouvre l'arbre) ; l'arbre a une rangée d'en-têtes (« 15 pts » … « 35 pts »,
  cadenas tant que le palier manque, pomme une fois atteint) et dessine ses prérequis (`TalentsPage.TreeView` : lien d'encre,
  pomme quand il est tenu, gris sinon, le niveau demandé dans une pastille au milieu) ; bord lagon = un point peut aller ici ;
  infobulle : effet **maintenant** / **avec un point de plus** / au niveau maximal (`TalentsPage.effect_at`, d'après le texte « par
  niveau » de chaque talent : 1 060 talents vérifiés), prérequis et colonne ✓ / ✗, clic / clic droit. **Réaffecter sans
  punition** : clic droit (X à la manette, meta `pad_x`) retire un point, gratuit (`Profile.remove_talent`), refusé seulement
  si un talent plus loin en dépend (`Profile.talent_set_valid` : l'arbre doit se rebâtir point par point ; `talent_remove_block`
  dit pourquoi) ; « Tout reprendre » (gratuit) puis « Annuler » (`Profile.undo_talent_reset`, le temps de la séance, tant que
  rien n'a été replacé). Recherche par nom ou effet (sans accents ; les autres cases pâlissent avec leurs liens). Cases plus
  petites sous 800 px de haut. **Modes scellés intacts** : rien n'a changé dans `Run.passive_stats` / `skill_talent` ; la page dit
  « Mode à part : talents et certificats n'y comptent pas » quand on l'ouvre en Survivant, Battle royale ou Échiquier.
- **Titres** (`core/titles.gd` `Titles`, `ui/titles_page.gd` `TitlesPage`) : section « Titres » de l'écran Héros (entre Apparence et
  Cartes ; LB / RB la parcourent) ; à gauche le nom du héros, le titre porté, « N'en porter aucun », « 4 titres sur 66 » ; à droite
  tous les titres rangés par source (niveau de héros, succès, Survie, Donjons, Ruée, Siège, Duel et Arènes, Panthéon, Quêtes,
  Survivant, Battle royale, Échiquier, « Autres » pour un titre gagné hors catalogue) avec la phrase qui dit comment l'obtenir,
  « Porter » / « Porté ✓ » / « À obtenir », filtres et recherche. Le titre porté s'affiche sous le nom dans l'en-tête de Héros (un
  clic ouvre la section). Les sources des lots non poussés (étoiles de donjon, défis du Survivant, Ligue royale) sont lues par
  `Titles._const` (classe trouvée par nom) : le catalogue ne dépend pas de leur présence.
- **Registre v2** (`ui/registry_page.gd`, `core/class_gear.gd`) : un clic sur une classe déplie sa fiche : profil (« Rempart ·
  armure de plates · dégâts physiques ») et 5 stats qui comptent le plus (★ dès un poids de 1,2, une seule « Défense » pour
  `def` / `def_pct`, `ClassGear.top_stats`) ; **tout ce qui manque**, dans l'ordre conseillé, chacun avec son activité
  (`ClassGear.missing`, au lieu du seul premier manque) ; **classes voisines** (arbre de déblocage puis même profil, débloquées
  d'abord, `ClassGear.neighbours`) dans un petit tableau PE / pièces / +10 / gemmes / état avec une phrase (« … a 2 400 PE de plus,
  même profil : ses pièces t'iraient (Héros > Gérer > Appliquer à la famille) », `compare_line`) ; « Voir l'équipement ». Le
  nombre de lignes du Registre ne change pas (la fiche est dans la carte de la classe).
- **« Ouvrir tout »** (`ui/chests_page.gd`) : carte de confirmation (`ChestsPage.ask_open_all` / `open_all_text` : un genre par
  ligne « ×N », les coffres à choix restent, « rien n'est vendu ni démonté ») ; un seul coffre s'ouvre sans carte ;
  récapitulatif (`recap_text`) : raretés obtenues de la plus haute à la plus basse (« 1 légendaire · 3 épiques »), « ▲ N pièces
  meilleures pour <classe> » (portables), nouvelles apparences, fournitures ; cases révélées par rareté montante, la plus rare en
  dernier (2,4 s au plus) ; le son de la plus haute rareté (SND-2) reste. `open_many` (sans carte) est inchangé pour les tests.
- **Jalons du niveau de héros** (`core/hero_level.gd`) : `HeroLevel.MILESTONES` 10 / 25 / 50 / 75 / 90 = un titre et des coffres
  d'apparence seulement (Aventurier + apparence rare ; Baroudeur + aura rare ; Héros aguerri + apparence mythique ; Héros de
  renom + apparence légendaire ; Héros sans égal + apparence et aura légendaires) ; donnés une fois au passage (`claim_milestones`,
  `records.hero_miles`, appelé par `add_xp`) ; bilan « Jalon du niveau 25 : … (menu Coffres) » ; compte déjà haut : ses jalons au
  menu principal (`take_note`, carte « Niveau de héros »). Jauge : « ★ 75 » à droite de la barre (écran Héros, `show_milestone`) et
  « Prochain jalon · … » dans l'infobulle ; Journal : 6e onglet « Niveau de héros » (les 5 jalons, obtenus / « encore N niveaux »).
- **Préréglage sur la page d'une activité** (`ui/preset_pick.gd` `PresetPick`) : rangée « Équipement » épinglée au-dessus du
  bouton de lancement (Survie, Donjons, Ruée, Siège, étages de la Tour, Duel équipé) : les préréglages qui ont des pièces, l'actif
  en mandarine « ✓ », ★ sur celui dont le nom d'usage va avec l'activité (Survie, Donjons, Tour, Duel), PE en infobulle ; un clic
  le rend actif (`Profile.set_active_preset`) et refait la page (PE conseillée, estimation). Rien en partie, rien quand un seul
  préréglage est rempli. Quatre lignes dans `lobby.gd` (Donjons, Ruée, Siège passent par `_pe_next`).
- **Reporter le +N** (`core/forge.gd` `Forge.report*`, 7e établi « Reporter » de la Forge) : la pièce choisie (la neuve) prend le +N
  d'une pièce du même emplacement (armes entre elles), de niveau égal ou plus bas, **moins 2 crans** (`REPORT_LOSS`), avec ses
  stats bonus des paliers gardés ; l'ancienne revient à +0 (persévérance, jet en attente effacés). Prix : les cristaux des crans
  reçus **sans échec ni parchemin** (`report_cost` = `Forge.upgrade_crystals` au niveau de la neuve). Refus écrits : en partie,
  pièce gardée, source sous +3, rien à gagner, pièce plus basse, cristaux. L'établi liste les 4 meilleures sources (« Prendre le
  +7 de … (portée) → +5 · 102 cristaux » pour un casque de niveau 50), tableau avant → après (amélioration, stats bonus), prix ; confirmation (`InfoCard.ask`) avec
  ce que devient chaque pièce, le prix, ce qu'on a, les préréglages qui utilisent l'ancienne ; puis la barre de forge.

## Économie et rythme
Aucun prix, aucun taux changés hors de Reporter. Les jalons ne donnent que des titres et des coffres d'apparence (aucune
puissance). « Reporter » touche le rythme : il a été mesuré avant d'être réglé.

`progression_sim --heros --refonte --plans=boss --hubvalue --bossplans --even` (12 comptes « moyen », guerrier, 50 h), copie de
HEAD 0.1.289 + ce lot, 4 processus en parallèle sur une machine chargée (bruit ± 1,5 h). `--report` modélise le report dans
`_wear` (une pièce neuve prend le +N de celle qu'elle remplace moins 2 crans quand c'est mieux), `--report-cost=` son prix.
Médianes en heures (part des comptes qui atteignent le jalon) :

| Variante | `kit80_ok` g. 1 | `kit80_ok` g. 2 | `kit80_p10` g. 1 | `kit80_p10` g. 2 | époque IV g. 1 / 2 |
|---|---|---|---|---|---|
| sans Reporter | 32,2 (83 %) | 30,4 (75 %) | 39,6 | 34,6 | 28,2 / 27,5 |
| Reporter gratuit (étude) | 28,6 (75 %) | 28,4 (83 %) | 29,0 | 28,4 | 24,1 / 25,0 |
| un parchemin par cran reçu | 27,3 (92 %) | 26,5 (75 %) | 27,3 | 27,2 | 24,3 / 23,2 |
| **cristaux des crans sans échec (retenu)** | **30,9** (83 %) | **31,9** (83 %) | 36,0 | 35,3 | 26,5 / 27,4 |

`kit90_ok` / `kit90_opti` : jamais atteints en 50 h, dans toutes les variantes. Lecture : gratuit, le report rend l'équipement
80-90 correct 2 à 4 h plus tôt (il passe sous 30 h, hors de la cible 30-36 h) et l'époque IV aussi (les pièces neuves arrivent
montées) ; les parchemins ne sont pas le goulot du modèle (le prix en parchemins est encore plus rapide). Au prix des crans sans
échec, `kit80_ok` reste dans 30-36 h (30,9-31,9 h, comme sans Reporter à l'intérieur du bruit) ; ce qu'on gagne : ni échec, ni
parchemin, les stats bonus suivent, `kit80_p10` 0,5 à 3,6 h plus tôt.

## Tests et captures
Nouveau `test_gx5` (≈ 125 vérifications : règles des talents, page des talents, titres et page, Registre, coffres, jalons, jauge,
Journal, préréglage d'activité, Reporter règles et établi, lobby et Héros). Mis à jour : `test_h1` (le message de migration
nomme aussi les jalons franchis), `test_hub1` (Journal à 6 onglets), `test_ideas` (sept établis), `test_nav_screens` (Registre
déplié, Forge > Reporter, Héros > Titres, confirmation de « Ouvrir tout » ; le nouvel onglet du Journal est parcouru avec les
autres). Verts sur une copie de HEAD 0.1.290 + ce lot (`-j 2`, machine chargée) : test_gx5, test_gx2, test_gx3, test_gx4, test_h1,
test_h3, test_h56, test_hub1, test_workshop, test_loot, test_e6, test_e3, test_nav_screens, test_pages, test_texts_fr, test_compass,
test_progress, test_p1, test_u3, test_snd2. `test_ideas` : un échec « forge : le parchemin est consommé » **déjà présent sur HEAD
sans ce lot** (vérifié sur une copie propre), le reste vert (dont « sept établis »). Captures `tests/shot_gx5.tscn` (`GX5_RES=1280x720`, lignes `[débord]`), regardées à 1600 × 900 et 1280 × 720 : talents (arbre, liens,
paliers, recherche), Classe > Sorts (points visibles), Titres, Registre (fiche dépliée), « Ouvrir tout » (confirmation, récapitulatif),
Journal > Niveau de héros, Survie et Donjons (rangée « Équipement »), Forge > Reporter et sa confirmation. Retouches après captures :
la rangée des sous-onglets des talents débordait de 54 px à 1280 (boutons, recherche et « Reprendre » plus étroits sous 1500 px) ;
les points libres en encre (l'or ne se lisait pas sur le papier) ; « Tout reprendre » / « Annuler » en boutons autocollants ; la
rangée du préréglage était sous le pli de la page (épinglée au-dessus du bouton) ; la fiche dépliée du Registre était sous le bord
à 720 px (la page défile jusqu'à elle) ; « 2 mythique » → « 2 mythiques ». Aucun `[débord]` restant.

## Reste / pièges
- Talents : pas de « chargements » ni de « build conseillé » (les profils opti de `data/build_profiles.json` mettent tous les
  talents au maximum : 178 points, il n'y en a que 80 ; un ordre conseillé reste à concevoir).
- `ui/chests_page.gd`, `lobby.gd`, `hero_screen.gd`, `profile.gd`, `test_nav_screens.gd`, `CLAUDE.md` avaient du travail d'autres
  lots en cours : le commit est construit depuis HEAD par remplacements de texte ciblés.
- Le mot « Survie » reste (lot A9).
