# R_TAC_5 : économie, objets et écran d'achat de L'Assaut (lot TAC-5, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.3 (économie), § 7.4 (31 objets), § 7.8 (écran d'achat, croquis
`tactique_maquettes/v2_achat.svg`), § 7.10 (plan d'achat des IA) et § 5.1 (achat conseillé, rachat). Socle : `R_TAC_0.md` (or de
manche, prime de défaite progressive), `R_TAC_4.md` (kits, ultime). Recommandations par défaut validées par le joueur.

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| Objets et paquetage | `game/scripts/core/assault_items.gd` (`AssaultItems`) | catalogue (les sorts 2 et 3 du kit + 26 objets), prix, limites, inventaire de manche, achat, revente, rachat, achat conseillé, plan d'équipe et achats des IA ; couche pure, sans scène |
| Utilitaires et fioles | `game/scripts/world/assault_gadgets.gd` (`AssaultGadgets`) | un nœud par objet lancé ou posé, dessiné au sol comme un sort ; effets chiffrés de l'étude |
| Écran d'achat | `game/scripts/ui/assault_shop.gd` (`AssaultShop`) | DA v2 « autocollant manga » : en-tête (manche, minuteur, or, prime de la prochaine défaite), 5 onglets, cartes, paquetage, colonne de l'équipe, pied (conseillé, racheter, tout revendre, fermer) ; manette (LB / RB, A, X, B) et raccourcis |
| Combat | `core/assault_combat.gd`, `combat/combatant.gd`, `player/player.gd` | bouclier d'armure qui encaisse avant la vie (`absorb`), enduit amer (`bitter`), cases achetées et ultime au lancement (`can_cast` / `on_cast` dans `Player.use_skill`), « Ébloui » et « Enduit amer » dans les effets connus |
| Vision | `world/assault_vision.gd` | ébloui = plus de cible pour l'IA ; Poudre de silence, Bottes feutrées : pas silencieux |
| Directeur | `core/assault_director.gd` | phase d'achat (`_buy_phase_start` : remise à zéro à la mi-temps et en prolongation, plans d'équipe, achats des IA, écran du joueur, conseillé au pilote), effets du paquetage (`_apply_kit`), cases possédées (`owned_slots`), points d'ultime (`ult_pts` : élimination, chute, pose, désamorçage), outils de la Charge (`tool_mult`), fin de manche (`_round_inventory`), touches du joueur ([C] fiole, [V] et [X] utilitaires), objets des IA (`_ai_items`), mesure des plans (`plan_log`) |
| Règles | `core/assault.gd` | `ult_points` 7 (et `bitter_cut`, `guard_cut` du lot TAC-4) |
| Mesure | `tools/assault_games.py` | part de chaque plan d'achat et victoires selon le plan |
| Captures | `game/tests/shot_tac5.tscn` -> `conception/benchmark/tac5/` | 4 onglets en 1280 × 720 et 1600 × 900, regardées (§ 4) |
| Test | `game/tests/test_tac5.tscn` | voir § 5 |

## 2. Économie et objets (valeurs de l'étude)

| Règle | Valeur |
|---|---|
| Or | départ 800 par moitié, prolongation 4 000 fixes, plafond 7 000 ; victoire 2 400 ; défaite 1 500 → 1 900 → 2 300 → 2 700, une victoire fait redescendre la série d'un cran ; élimination 200, aide 50, pose +300 à chaque attaquant, désamorçage +200 ; attaquant vivant au temps sans pose : rien (lot TAC-0, inchangé) |
| Ce qu'on garde | si l'on survit : sorts achetés, arme, armure (le reste du bouclier), utilitaires non lancés, fiole, outil ; on perd tout en tombant ou dans l'explosion ; tout est remis à zéro à la mi-temps et en prolongation ; l'ultime garde ses points |
| Sorts 2 et 3 | prix du kit : mobilité 200, dégâts 250, renfort 250, contrôle 300, soin / bouclier 300, invisibilité 350 |
| Armes | Arme affûtée 600 (× 1,15), Arme de maître 1 500 (× 1,30 ; l'affûtée de la même phase est remboursée), Arme d'appoint 400 (une arme commune d'un autre type, [Changer d'arme]), Enduit amer 300 (3 coups : soins reçus −40 % 4 s) |
| Armures | Gilet 400 (bouclier 25 % des PV max), Cuirasse 1 000 (50 %), Réparer au prorata du bouclier perdu |
| Utilitaires (2 sortes, 4 charges, 2 du même) | Brume 200 (5 m, 10 s, coupe la vue), Éclat aveuglant 150 (0,6 s, 12 m, ébloui 1,2 s si l'on regarde), Pot de feu 300 (4 m, 6 s, 6 % / s), Bombe d'éclats 300 (0,8 s, 5 m, 25 %), Œil de chouette 250 (12 m, 3 s, même derrière un mur), Clochette 150 (posée, 60 s, 5 m, révèle 2 s), Piège à ressort 250 (invisible au-delà de 4 m, immobilise 0,8 s, révèle 2 s), Barricade de glace 300 (4 × 2 m, 12 s : passage, vue et coups), Leurre 200 (court 4 s en faisant du bruit), Poudre de silence 200 (6 s sans bruit de pas) ; le Contrôleur paie ses utilitaires 20 % de moins |
| Fioles (une) | Soin 200 (30 % en 2 s, un coup de plus de 5 % l'interrompt, dans le plafond de soins), Hâte 150 (« Hâte » du jeu, 6 s), Garde 250 (−25 % 4 s, sous le plancher × 0,6), Clarté 200 (retire le contrôle, insensible 2 s) |
| Outils (un) | Pinces d'acier 300 (Défense, désamorçage 4 s), Gants de sapeur 300 (Attaque, pose 3 s), Talisman de ténacité 350 (contrôles −30 %, multiplié avec le Rempart), Bottes feutrées 300 (pas silencieux jusqu'à 75 % de la vitesse) |
| Ultime | 7 points (élimination, chute, pose, désamorçage) ; lancé, il retombe à 0 ; les orbes d'ultime de la carte restent à faire (§ 6) |
| Plan des IA (§ 7.10) | achat complet si l'or moyen de l'équipe ≥ 3 400 ; on force à la dernière manche d'une moitié, à la balle de match, en prolongation ou si l'autre équipe économise ; sinon on économise (sort le moins cher + un utilitaire, 40 % de l'or au plus) ; achat = l'« achat conseillé » du rôle |
| Achat conseillé | sorts 2 et 3 (le moins cher d'abord), armure et arme selon l'or (cuirasse + maître dès 3 400, cuirasse + affûtée dès 2 000, sinon gilet + affûtée), outil de son côté, 2 utilitaires du rôle, fiole de soin, tant que l'or suit |

## 3. Mesures (parties IA contre IA, Bourg, Difficile contre Difficile, achat de 2 s, ×3, machine saturée)

`python tools/assault_games.py --games 8 -j 2 --win 4 --rule buy_time:2 --rule buy_time_first:2` (premier à 4) et la même chose
au format normal (premier à 7, 12 manches et prolongation, `--games 4 --seed 2000`) :

| Mesure | TAC-4 (sans achat) | TAC-5, graines 1000 | TAC-5 final, graines 3000 | TAC-5, premier à 7 |
|---|---|---|---|---|
| Manches (parties finies) | 54 (8) | 54 (8) | 52 (8) | 45 (4, dont 2 prolongations) |
| Attaque gagne | 93 % | 96 % | **75 %** | 87 % |
| Façons | Charge 93 %, désamorçage 7 % | Charge 96 %, désamorçage 2 % | Charge 75 %, **désamorçage 25 %** | Charge 84 %, désamorçage 11 % |
| Manche jouée (médiane) | 62,4 s | 59,9 s | 60,8 s | 60,2 s |
| Temps de survie d'un héros tombé | 7,4 s, plus court 4,0 | 6,9 s, plus court 3,9 | **7,5 s, plus court 4,0, 0 sous 3,5 s sur 159** | 7,6 s, plus court 3,0 (avant la correction ci-dessous) |
| Plans (par équipe et par manche) | — | forcé 75 %, éco 17 %, complet 8 % | forcé 64 %, éco 23 %, complet 12 % | **complet 42 %**, forcé 40 %, éco 18 % |
| Victoire selon le plan | — | forcé 50 / 81, éco 3 / 18, complet 1 / 9 | forcé 38 / 67, éco 8 / 24, complet 6 / 13 | complet 17 / 38, forcé 22 / 36, éco 6 / 16 |

Rôles (éliminations / morts par héros et par partie, graines 3000) : Tireur 3,7 / 4,1 ; Soutien 3,2 / 4,4 ; Contrôleur 3,0 / 4,3 ;
Ouvreur 1,6 / 4,6 ; Rempart 0,9 / 4,6.

**Réglage fait pendant la mesure** : les dégâts des objets (bombe d'éclats, pot de feu) passaient hors de la règle de rafale du
JcJ (un héros est tombé en 3,0 s sous une bombe et trois attaquants) : ils comptent maintenant dans la rafale (45 % sur 2 s
au plus) ; la mesure du temps de survie part aussi du premier coup d'objet (avant, du premier coup de héros : elle sous-estimait).
Ensuite, 0 sous 3,5 s sur 159 chutes.

Lecture : l'économie tourne — les IA achètent à chaque manche, économisent après une défaite, forcent aux manches qui comptent,
achètent complet quand l'or le permet (au format normal, 42 % des manches) ; au format court la balle de match arrive tôt et
« on force » domine. Un achat complet ou forcé gagne nettement plus qu'une éco (17 / 38 et 22 / 36 contre 6 / 16) : le
retournement par l'économie existe. L'Attaque gagne encore trop (75 à 96 % selon les graines) : ce n'est pas l'économie, c'est
la Défense de l'agent provisoire qui reprend mal un site (lot TAC-6). Écart entre les graines : ±10 points sur 50 manches.

## 4. Captures regardées (`tests/shot_tac5.tscn`, fenêtre, copie de HEAD + TAC-5)

`conception/benchmark/tac5/achat_{1_sorts, 2_arme_conseille, 3_utilitaires, 4_fioles}_{1280x720, 1600x900}.jpg`. Corrigé en
regardant : cartes trop basses (texte qui débordait) → 138 / 142 px ; une étiquette longue (« Acheté · clic droit… ») élargissait
la carte et faisait déborder la description → étiquette coupée, texte « ✔ Acheté » ; pictogrammes absents (des noms de l'ancien
menu, pas des `ico_*`) → pictogrammes `Ico` existants (bouclier, bottes, gants, cadenas ouvert, racine, barrière…) ; descriptions
raccourcies (aucune ne dépasse 3 lignes) ; en 1280 × 720 l'onglet Utilitaires (10 cartes, 3 rangées) faisait sortir le pied de
l'écran → les cartes défilent dans leur cadre (le test contrôle désormais les 5 onglets aux deux tailles). Reste pour la revue DA
(TAC-14) : le HUD des sorts ne montre pas encore les cases à acheter ni l'ultime (lot TAC-7) ; « Offrir » à un allié (P1-14).

## 5. Preuves

`test_tac5` (vert) : catalogue, aucun pourcentage dans les textes permanents ; prix du kit ; achat, raison « Il manque … »,
revente au prix payé, tout revendre ; limites (2 du même, 2 sortes, 4 charges, une fiole, un outil), outil réservé à un côté ;
arme de maître qui rembourse l'affûtée ; réparation au prorata ; remise du Contrôleur ; phase suivante (plus revendable, liste
« Racheter ») ; chute (tout perdu, « Racheter » gardé) ; rachat ; achat conseillé dans le budget ; plans éco / complet ; achats
d'une IA ; prime de défaite 1 500 puis 1 900. Partie réelle : écran ouvert, 5 onglets, 4 cartes de sorts, « tab_screens », plan
et 4 lignes d'équipe, achat par l'écran, aucun sort pendant l'achat, onglet suivant, 21 boutons navigables, tout revendre, achat
conseillé, 7 IA sur 7 ont acheté, les 5 onglets tiennent dans 1280 × 720 et 1600 × 900 ; la manche ferme l'écran ; cases achetées,
pas l'ultime ; bouclier posé qui encaisse d'abord ; ultime à 7 points puis consommé ; brume (vue coupée), bombe d'éclats (touche
après son annonce), œil de chouette (révèle), fiole de soin (rend de la vie) ; à la fin de manche, le tombé perd son paquetage,
le survivant le garde.

## 6. Ce qui reste

1. **Arme d'appoint** : le joueur reçoit une arme commune d'un autre type (système des deux armes, `Player.swap_weapon`,
   [Changer d'arme]) ; les scriptés l'achètent rarement et ne s'en servent pas (`ClassRival` n'a qu'une arme).
2. **Orbes d'ultime** sur la carte (2 par carte, ramassage 2 s) : données de carte à poser (TAC-10) ; aujourd'hui 4 sources de points.
3. **Barricade** : 400 PV de l'étude non gérés (elle tient ses 12 s) ; le maillage de navigation ne la voit pas (l'IA peut
   la longer).
4. **Offrir un objet** à un allié qui manque d'or (P1-14) et le plan d'équipe annoncé en bulle (TAC-6).
5. Les IA utilisent leurs objets par règles simples (`_ai_items`) ; les lancers coordonnés aux points de la carte sont du lot TAC-6.

## 7. Non-régression

Copie propre de HEAD 0.1.312 + TAC-5 (`run_tests.py --reuse -j 1`, machine saturée) : test_tac0 à test_tac4, test_mode0, test_pvp,
test_duel_modes, test_m7, test_royale, test_nav_screens, test_texts_fr verts ; test_tac5 vert après deux corrections du test
(scriptés tenus en place, armure achetée d'un scripté qui encaissait la bombe). `check_scripts.py` vert sur l'arbre du commit.
