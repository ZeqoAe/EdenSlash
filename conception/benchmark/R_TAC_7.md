# R_TAC_7 : HUD de L'Assaut (lot TAC-7, 18/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.8 (« HUD de manche »), § 5 (confort : dernière position, noms des lieux,
« Voir les sons ») ; croquis `tactique_maquettes/v2_hud_manche.svg`. Bible v2 (`conception/art/BIBLE.md` : autocollant d'encre,
bonbons, Mochiy Pop One / M PLUS Rounded 1c, aucun pourcentage dans le texte permanent). Socle : `R_TAC_0.md` à `R_TAC_5.md`,
`R_MODE0.md` (couleurs et blasons d'équipe), `conception/hub/R_HUD2.md` (HUD v2 commun). Recommandations par défaut validées.
Avant ce lot, le HUD commun montrait en Assaut le titre « L'Assaut » seul, la barre de niveau (« Niv. 50 »), des cases de sorts
toutes prêtes (même non achetées) et rien de la manche (score, minuteur, Charge, or).

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| HUD du mode | `game/scripts/ui/assault_hud.gd` (`AssaultHud`, `AssaultHud.current`) | posé par `Hud._build` quand `Modes.current() == "assault"` (comme `RoyaleHud`) ; cache le panneau d'objectifs de la Survie, la barre de niveau et le niveau d'aide ; tout se lit sur `AssaultDirector` et `Assault` |
| Bandeau du score | `AssaultHud.ScoreBand` | en haut au centre : 4 + 4 portraits (icône de classe sur la couleur de sa famille ; à terre : voile d'encre tramé et ✕ fraise ; anneau lagon = toi ; pastille soleil = porteur de la Charge, pour la Défense seulement si elle le voit ; jauge soleil d'ultime sous les alliés), score de chaque équipe sur sa couleur avec son blason (`TeamSigil`), minuteur au centre (achat sur papier crème, manche sur papier, 10 dernières secondes en fraise, mèche de la Charge sur fond fraise), « Manche 8 · Attaque », « prolongation » |
| Ligne de la Charge | `AssaultHud.ChargeLine` (`state` pur) | « Charge : tu la portes · pose-la en A ou en B », « Charge : Druide la porte », « Charge au sol · Halle », « Porteur repéré », « Défends A et B : la Charge n'est pas en vue », pose et désamorçage avec leur avancée (repère de sauvegarde à la moitié), « Charge posée en A · reprise à 2,0 s » |
| Or | `AssaultHud.GoldBox` | bas gauche : l'or, « prochaine manche : +1 500 au moins » (prime de la prochaine défaite), pendant l'achat le plan de l'équipe ; le barème en infobulle |
| Kit | `AssaultHud.SlotMark` (`state_of` pur) | cases 2 et 3 non achetées : voile tramé, cadenas, prix « 250 or » ; ultime : jauge en 7 crans soleil autour de la case et « 5 / 7 », éclat quand il est prêt |
| Objets | `AssaultHud.ItemRow` (`entries` pur) | à la place de la barre de niveau : fiole [C], deux utilitaires [V] / [X] avec leurs charges, l'outil (passif) ; touches dessinées dessous |
| Bouclier | `AssaultHud.ShieldMark` (`ratio_of` pur) | gilet / cuirasse : bande lagon en crans (un cran = un dixième des PV max) posée sur le haut de la jauge de vie, sous les touches |
| Mini-carte | `AssaultHud.minimap_overlay` (une ligne gardée dans `ui/minimap.gd`) | ce que voient le joueur et ses alliés debout (éventails lagon clair, 3 fois par seconde), sites A / B, alliés (✕ à terre), derniers vus « ? » fraise qui s'effacent en 4 s, bruits entendus (anneaux : combat fraise, Charge soleil, pas lilas), repère |
| Colonne de droite | `AssaultHud.SideColumn` | sous la mini-carte : le lieu où se tient le héros regardé (« Halle »), le fil des éliminations en pastilles (« Maître-sabre ⚔ Toi », point de la couleur d'équipe, toi en soleil), le repère, les réponses des alliés |
| Annonces | `game/scripts/ui/assault_announce.gd` (`AssaultAnnounce`, sur `RoyaleAnnounce`) | une à la fois, sous le cadre de cible, par le crochet de `Hud.show_message` : manche et côté, « C'est parti ! » lagon, « Charge posée en A ! » soleil en Attaque et fraise en Défense, « 10 secondes ! », désamorçage lagon, « 2 contre 4 ! », « À toi de jouer ! », « VICTOIRE ! » ; « K.O. ! » au-dessus du héros ; les fins de manche et la chute du joueur ont leur carte (lot TAC-8) |
| Repère | `AssaultHud.place_ping`, `AssaultDirector.set_ping` | [ping] (clic molette, L3) : épingle lagon au sol avec le lieu et la distance, sur la mini-carte et dans la colonne ; reposé au même endroit, il s'enlève ; lu par l'ordre « Va au repère » (TAC-8) |
| Barrières d'encre | `game/scripts/world/assault_barrier.gd` (`AssaultBarrier`) | les deux départs pendant l'achat : parois translucides de la couleur du camp, bord d'encre ; elles tombent à « C'est parti ! » (le joueur était déjà tenu dans son départ, `_hold_in_spawn`) |
| Directeur | `core/assault_director.gd` (bloc « HUD, mort, ordres et bilan », appelé par 5 lignes) | `dmg_total`, `last_hits`, `ko_log`, `round_cards`, `ping`, `place_of`, `hero_name`, `_show_barriers` |
| Icônes d'effets | `ui/status_db.gd` (`ASSAULT_ICO`) | « Insensible aux contrôles », « Ébloui », « Enduit amer » (lots TAC-4 / TAC-5) avaient une case d'effet vide : pictogrammes maison (test_hud repasse au vert) |
| Captures | `game/tests/shot_tac7.tscn` -> `conception/benchmark/tac7/` | manche, Charge posée, chute, ordres, fin de manche, bilan, page du lobby ; 1280 × 720 et 1600 × 900 |
| Test | `game/tests/test_tac7.tscn` | voir § 3 |

## 2. Captures regardées (fenêtre, copie de HEAD + lot)

`conception/benchmark/tac7/1_manche_{1280x720,1600x900}.jpg`, `2_pose_*`. Corrigé en regardant : la ligne de l'or coupait « au
moins » (cadre élargi à 304 px) ; la jauge d'ultime en arc hors de la case passait sous la touche dessinée (arc posé sur le bord de
la case, crans plus épais) ; le bouclier posé dans la jauge de vie cachait « Vie » (bande au-dessus de la jauge, sous les cases et
leurs touches) ; une annonce posée avant l'apparition du cadre de cible passait dessous (l'annonce se recale à chaque image) ; la
carte de fin de manche et l'annonce se superposaient (pile : récapitulatif de chute, carte de fin de manche, puis annonce).
En 1280 × 720, le bandeau du score (réduit à 0,8) croisait la pile de gauche : elle passe sous le bandeau.

## 3. Preuves

`test_tac7` (vert, 36 contrôles) : annonces (sens et rang), lignes sans partie ; partie réelle sur le Bourg : HUD posé, panneau
de la Survie et barre de niveau cachés ; cases (gratuite, à acheter, achetée, ultime 0 / 7 puis prêt) ; or (plan pendant l'achat,
prime de la prochaine défaite en manche) ; fiole, utilitaires et outil dans l'ordre ; bouclier ; « tu la portes » ; à 1280 × 720
et 1600 × 900 : bandeau, ligne de la Charge, or et objets dans l'écran, bandeau hors de la mini-carte et de la pile de gauche, or
hors de la barre d'action ; barrières tombées à la manche ; annonce montrée, fin de manche avalée ; une chute -> « 4 contre 3 ! »
et le fil ; repère posé, dans la colonne, retiré ; 4 polygones de vue sur la mini-carte ; Charge posée, désamorçage adverse avec
sa sauvegarde à la moitié ; coût de la mise à jour du HUD du mode **0,05 à 0,13 ms par image** (machine chargée) ; plus de HUD hors partie.

## 4. Pièges

1. `AssaultHud` ne garde aucune référence typée vers un héros scripté (ils sont libérés à leur chute) : tout passe par
   `AssaultDirector.hero(clé)`.
2. Le cadre de cible, le récapitulatif de chute, la carte de fin de manche et l'annonce se rangent en pile sous le bandeau
   (`AssaultHud._layout`, à chaque image) : un nouvel élément du haut de l'écran doit entrer dans cette pile.
3. Les états dessinés sont aussi calculés hors du dessin (`ChargeLine.state`, `SlotMark.state_of`, `ItemRow.entries`,
   `ShieldMark.ratio_of`, `GoldBox.second_line`) : les tests sans fenêtre les lisent là, jamais dans `_draw`.
4. La mini-carte dessine ce que voit l'équipe en triangles (`canvas_item_add_triangle_array`) : un polygone en étoile ne se
   triangule pas toujours (piège du voile, R_TAC_2).
5. Les ordres d'IA de l'équipe TAC-C (`AssaultCoach.orders[clé].text`, `plan_text()`) ne sont pas encore affichés : bulles des
   alliés au lot TAC-11.

## 5. Reste

Roue de ping à plusieurs sens et bulles d'intention des alliés (TAC-11) ; option daltonisme « alliés ronds, ennemis en losange »
sur la mini-carte (les bruits et la danger passent déjà en mandarine) ; noms des lieux sur la mini-carte elle-même ; musique qui
baisse sur « À toi de jouer ! » (TAC-13).

## 6. Non-régression

Voir le rapport du lot TAC-8 (`R_TAC_8.md` § 6) : la suite a tourné une fois sur la copie de HEAD + TAC-7 + TAC-8.
