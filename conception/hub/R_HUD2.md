# Lot HUD-2 : le HUD en partie passe en DA v2 (17/10/2026)

Source : étude BM-HUB (`conception/benchmark/HUB_HUD_QUETES.md`, P0-6 à P0-9, P1-3, P1-7 en partie ; croquis
`hub_maquettes/hud.html`), bible v2 (`conception/art/BIBLE.md` § 5, § 6, § 10, § 12), suite de `R_HUB1.md` (logique) et
`R_UIK2.md` (« Reste : HUD de la Survie »). Toutes les recommandations sont validées. **Aucune règle de jeu ne change** :
affichage seulement. « Survie » n'est pas renommé (lot A9).
Modes servis par `ui/hud.gd` : Survie, Donjons, Tour, Ruée, Siège, Duel, Arènes, Gantelet, entraînement. Le Battle royale
(`RoyaleHud`) et le Survivant (`SurvivorHud`) posent toujours leurs modules par-dessus ; ils héritent des nouvelles cases.

Captures regardées (dossier `hud2/`, 1600×900 et 1280×720) : Survie (Premiers pas + fiche + fil du butin + compteur, bandeau
d'annonce), profils Compact et Minimal, Donjon (combat de boss, barre de boss DNG-2 gardée), Tour, Duel, Arène 3 contre 3
(combat, pause), Gantelet. Outil : `godot --path game res://tests/shot_hud2.tscn -- [survie|donjon|tour|duel|tout]`
(`HUD2_RES=1280x720`).

## Fait

| Sujet | Où | Contenu |
|---|---|---|
| Vie | `ui/hud_v2.gd` (`HudV2.LifeGauge`), `Hud._build_action_bar` | jauge large autocollante (creux d'encre 500, contour d'encre 3 px, ombre dure, fraise deux tons, **trace claire** des dégâts qui rattrape, « Vie » en Mochiy et chiffres contourés, pulsation fraise sous 30 %) **sous** les cases, comme le Survivant : les icônes d'enchaînement et la barre du bon timing, au-dessus des cases, ne la cachent jamais. Redessinée seulement quand elle change. |
| Niveau | `HudV2.LevelBar` | **barre de niveau lagon** et pastille « Niv. 8 » à la place du globe ; éclat soleil à la montée de niveau ; le pourcentage n'est que dans l'infobulle (Survie : « Niveau de partie 3 : chaque niveau donne une carte. Ton héros se bat au niveau 47 »). Niveau d'aide en mots du jeu à côté (« Assisté », « Pilote auto » ; rien en Manuel, rien en Battle royale). |
| Cases | `ui/hud_widgets.gd` (`SkillSlot`, `PotionSlot`, `QueueStrip`, `StatusIcon`) | case autocollante (fond d'encre 500, contour d'encre, ombre dure ; les coins de l'icône passent sous l'encre) au lieu du cadre doré ; **touche dessinée en pastille sous chaque case** (papier ; manette : A pomme, B fraise, X lagon, Y soleil) dans tous les modes ; vide = trame (jamais « — ») ; recharge en camembert + chiffre contouré ; **éclat soleil** quand elle redevient prête ; esquive ronde à anneau pomme ; potions avec leur nombre en pastille fraise ; effets positifs bord pomme / négatifs bord fraise (lagon / mandarine pour les daltoniens), boîtes gardées (plus aucune boîte créée à chaque image). Globe `Orb` supprimé. |
| Arme rangée (N2) | `Hud._update_swap`, `Player.weapon_swapped` | case ronde à anneau lagon, touche « Changer d'arme » dessous, recharge ; **s'éclaire à chaque échange**. |
| Mini-carte | `HudV2.MapRing`, `ui/minimap.gd` | cadre **papier** (bande crème entre deux contours d'encre, ombre dure, reflet) au lieu des anneaux dorés ; brouillard et dehors de la carte **au papier** (petit shader `Minimap.fog_material` : le brouillard noir à transparence est peint en papier-300) ; « N » en pastille papier ; flèche du héros contourée d'encre ; légende de la grande carte en puits d'encre. |
| Colonne de droite | `Hud._layout_right`, `Hud._feed_room` | mini-carte, compteur de dégâts, **carte de notification** (file HudNotices), **fil du butin** : chacun sous le précédent, jamais sur la barre d'action. Sur un petit écran, la carte passe avant le compteur (il s'efface le temps qu'elle est là) et le butin attend la place ; une ligne qui n'a plus la place se cache. Battle royale : sa propre colonne (inchangé). |
| Fil du butin | `Hud.feed` | colonne de droite (Diablo, WoW) : ligne autocollante d'encre, **case de couleur** du genre de trouvaille (butin et coffre soleil, clé mandarine, cristal lagon, potion fraise, équipé pomme), texte papier ; 3 lignes (Compact 2, Minimal 0) ; attend la fin du bandeau d'annonce, y compris pendant son fondu d'entrée (`banner_up`). Battle royale et Survivant : pile de gauche, comme avant. |
| Premiers pas / fiches | pile de gauche / colonne de droite | les Premiers pas restent en haut à gauche (bouton « Passer » papier), la fiche de découverte est dans la colonne de droite sous la mini-carte et le compteur : **plus aucune superposition** (à 1280×720 la fiche chevauchait le compteur de dégâts). |
| Quête suivie (P0-6) | `ui/quest_badge.gd` | puits d'encre translucide contouré, **pastille ★** (soleil : épinglée au Journal, papier : la plus avancée de l'activité), compteur en chiffres soleil, jauge fine contourée. |
| Bandeau d'annonce | `Hud.show_message` | autocollant d'encre (contour, ombre dure) au lieu du dégradé noir ; titre Mochiy soleil contouré, détail papier ; largeur bornée entre la pile de gauche et la mini-carte (`BANNER_SIDE` 390) : à 1280×720 il ne passe plus sur les Premiers pas. Les annonces de boss restent celles de DNG-2 (`HudAlert`). |
| Cible | `Hud._bar` | jauges de la cible au creux d'encre contouré, fraise de la bible, trace papier. Barre de boss DNG-2 (`BossBar`) gardée telle quelle. |
| Divers | `ui/hud.gd` | invite « [F] Ouvrir » sur papier (texte à l'encre), objet meilleur dans un autocollant d'encre bordé pomme, flèche d'objectif contourée d'encre, compteur de dégâts en Mochiy soleil contouré (« partie » au lieu de « run » dans son record), contours d'encre au lieu du noir pour tous les textes du HUD (`Hud._label`). |
| Profils (P1-3) | `HudV2.PROFILES`, `core/settings.gd` (`interface.hud_profile`), `ui/settings_menu.gd` | Paramètres > Affichage > HUD en partie > **Profil du HUD** : **Standard** (tout), **Compact** (× 0,88, sans compteur de dégâts, fil du butin de 2 lignes), **Minimal** (vie, sorts, cible, annonces ; objectifs repliés même à une découverte, sans mini-carte ni quête suivie ni fil du butin ; la grande carte reste sur sa touche). Taille et opacité (HUB-1) s'y ajoutent. Le Battle royale garde sa mini-carte quel que soit le profil. |

## Demande de la coordination (constats BM-MOBA)
- **« Aucun HUD dans les Arènes / le Gantelet » (shot_m7, HEAD 0.1.284)** : non reproduit sur une copie propre de HEAD (0.1.284
  puis 0.1.286) avec et sans ce lot : barres d'équipe, cases, cible, décompte présents (`hud2/arene3_combat_1600x900.jpg`,
  `hud2/gantelet_combat_1600x900.jpg`). Cause probable : la capture a tourné dans le dossier partagé pendant qu'un autre lot
  ajoutait la classe `Ico` (ICO-1) sans que le cache des classes soit à jour : j'ai obtenu exactement ce symptôme sur une copie
  où `ico.gd` manquait (« Identifier "Ico" not declared » dans `ui_nav.gd`, `talents_page.gd`…, puis « Failed to compile
  depended scripts » : le HUD ne se construit plus). Ce n'est pas une régression du code ; relancer `--import` suffit.
- **Pause des Arènes** : « Tes sorts » au lieu de « Compétences de la partie (4 / 12) » (aucune carte en duel), case libre
  « les sorts du duel viennent de ton préréglage », plus de « Pas encore améliorée (cartes d'amélioration d'arme) » ; bouton
  « Abandonner l'arène » / « Abandonner le Gantelet » (et leur confirmation) au lieu de « Abandonner le duel ».
- **Pourcentages permanents** : tuiles « coup porté / coup reçu » de la pause et du bilan du duel en mots (« Léger », « Moyen »,
  « Lourd », « Plafond » : `RunPage.hit_word`), le chiffre dans l'infobulle ; barres d'équipe (`ui/team_bars.gd`) au puits
  d'encre, lagon pour ton camp, fraise pour l'autre, largeur de la pile. **Reste hors de mon périmètre** : le « 62 % » écrit sur
  la barre de boss v2 (`ui/boss_bar.gd`, lot DNG, fichier en cours chez une autre équipe).
- **`tests/shot_m7.gd`** : la pause est refermée explicitement (deuxième fermeture si besoin, arbre dépausé) et l'outil écrit
  `[m7] pause refermée : true, HUD visible : true` ; les captures 22 (pause), 23 (joueur tombé) et 24 (manche) diffèrent.

## Mesures
- Coût de la mise à jour du HUD commun en Survie (sonde temporaire, même mesure que `test_hud2` : meilleure de 7 séries de
  100 images, même copie, l'une après l'autre) : **0,33-0,38 ms avec le lot, 0,34 ms sans** : pas de régression (machine chargée par d'autres agents).
  Côté dessin : la vie et le niveau ne se redessinent qu'à un changement (le globe se redessinait à chaque image), le cadre de
  la mini-carte est fixe, les effets ne créent plus de boîte à chaque image. `test_hud2` garde un plafond de 0,8 ms.
- Mise en page vérifiée à 1600×900 et 1280×720 en Survie (avec Premiers pas, fiche, compteur, fil du butin, bandeau), en
  Donjon, Tour et Duel : rien hors de l'écran, rien ne se recouvre (`test_hud2`).

## Tests (copie propre de HEAD + lot, `run_tests.py -j 2`)
- `test_hud2` (nouveau, ~45 contrôles) : pièces, éclat de l'arme rangée, fil du butin à droite et qui attend le bandeau,
  colonne de droite et pile de gauche sans chevauchement aux deux tailles, profils, taille réglée, 3 autres modes, coût.
- Verts : test_hud2, test_hud (mis à jour : fil du butin à droite, barre de niveau), test_hub1, test_bri1, test_dng2, test_dng1,
  test_uik0, test_nav_screens, test_texts_fr, test_p2, test_pages, test_results, test_quests, test_n2, test_duel_modes, test_m7,
  test_sv5, test_svx1, test_controls.
- Rouges **sans lien avec ce lot** : `test_svx2` « 1280x720 bilan : tient dans la fenêtre » (déjà rouge sur HEAD 0.1.281, voir
  `R_UIK2.md`) ; `test_sv6` « la page du mode montre ✔ pour les paliers déjà gagnés » (page du Survivant au menu, aucun
  fichier de ce lot).

## Reste / pistes
- Profil « Télé / manette » de l'étude (× 1,25, textes ≥ 18 px, touches manette) : les trois profils demandés sont Standard,
  Compact, Minimal ; un profil Télé se fait en ajoutant une entrée à `HudV2.PROFILES` (taille et `shows`).
- Cible : « prochaine attaque nommée » (P1-7) seulement pour les boss (DNG-2) ; rien pour les élites.
- Fil du butin : la rareté réelle d'une pièce n'est pas transmise par les messages (« Butin : X ») : la case dit le genre de
  trouvaille, pas la rareté.
- Édition libre du HUD : pas faite (recommandation : seulement si des notes Alt + clic droit la demandent).
