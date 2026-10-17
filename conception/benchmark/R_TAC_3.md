# R_TAC_3 : la Charge de L'Assaut (lot TAC-3, 17/10/2026)

Étude : `conception/benchmark/TACTIQUE.md` § 7.2 (règles chiffrées), § 7.8 (retours) et § 5 (confort). Socle : `R_TAC_0.md`
(machine de manche), `R_TAC_1.md` (Bourg), `R_TAC_2.md` (vue et bruits). Recommandations par défaut validées par le joueur.

## 1. Ce qui est livré

| Élément | Fichier | Rôle |
|---|---|---|
| La Charge | `game/scripts/world/assault_charge.gd` (`AssaultCharge`) | l'objet : porté (lanterne sur le dos du porteur, cachée avec lui), au sol, posé, désamorcé, explosé ; dessin « autocollant » (boule soleil, coque d'encre, mèche fraise), anneau fraise qui pulse au rythme des bips, lumière qui clignote ; bips qui accélèrent (`beep_interval`) avec une hauteur qui monte ; explosion (onde de choc mandarine, éclair soleil, anneau fraise, son) ; désamorçage (anneau lagon) |
| Directeur | `game/scripts/core/assault_director.gd` | porteur choisi à chaque manche (`_pick_carrier`), Charge lâchée à la mort du porteur ou par le joueur ([G]), ramassée en passant (`_try_pickup`), vue de la Défense honnête (`charge_seen`), mini-carte (`markers`), pose et désamorçage avec outils (crochets `_plant_full` / `_defuse_full` pour le lot TAC-5), interruptions par contrôle (`_interrupted`), explosion qui emporte les héros proches (`blasted`), annonces, agent provisoire (ramasser, garder la Charge au sol) |
| Règles | `game/scripts/core/assault.gd` | `pickup_radius` 1,5 m, `blast_radius` 9 m (profil `assault`) ; option de lancement `--assault-rule=clé:valeur` (toute règle, pour les mesures) |
| Mini-carte | `game/scripts/core/run_director.gd` | `markers()` en état « team » : ceux du directeur du mode (la Charge, étoile soleil) |
| Mesure | `tools/assault_games.py` | parties IA contre IA en parallèle (lignes `[assault] manche …`), part de l'Attaque, façons de gagner, durée des manches, `--jsonl` |
| Test | `game/tests/test_tac3.tscn` | voir § 4 |

## 2. Règles codées

| Règle | Valeur | Où |
|---|---|---|
| Porteur | toi si tu attaques (option `player_carry`, vrai) ; sinon l'attaquant scripté au meilleur score : jamais le premier de l'équipe (il ouvre), puis le rôle (lot TAC-4 : Soutien 3, Contrôleur et Tireur 2, Rempart 1, Ouvreur −3) | `_pick_carrier`, `_carrier_score` |
| Lâcher | à la mort du porteur, à ses pieds ; le joueur porteur hors d'un site : [G] (`quick_equip`) la pose devant lui | `_drop_charge` |
| Ramasser | un attaquant debout à moins de 1,5 m la prend en passant (le joueur aussi) | `_try_pickup` |
| Qui la voit | l'Attaque toujours ; la Défense : posée (tout le monde), au sol si l'un de ses héros debout voit l'endroit (22 m, murs), portée si elle voit le porteur | `charge_seen` |
| Pose | 4 s immobile dans un site ; annulée par un pas, un coup, un sort, une esquive ou un **contrôle subi** (renversé, gelé, endormi, terreur, immobilisé) ; les dégâts seuls ne l'annulent pas | `_player_actions`, `_ai_actions`, `_interrupted` |
| Mèche | 40 s ; bips de 1 s à 0,14 s (courbe en carré), deux fois plus serrés les 10 dernières secondes ; « 10 secondes ! » | `AssaultCharge.beep_interval` |
| Désamorçage | 7 s, sauvegarde à la moitié (repris à 3,5 s si interrompu après) ; l'invite le dit (« reprend à 3,5 s ») ; « Ils désamorcent la Charge ! » pour l'Attaque | `_progress_defuse`, `_stop_defuse` |
| Explosion | fin de manche (Attaque) ; tout héros à moins de 9 m est emporté (il ne survit pas à la manche : lot TAC-5, ce qu'on garde) | `_explode`, `blasted` |
| Annonces | « Manche n · côté · score » + but (« pose la Charge en A ou en B », « défends A et B », « tu portes la Charge ») ; « La Charge est tombée ! », « X ramasse la Charge », « Charge posée en A ! », « 10 secondes ! », « Charge désamorcée ! » / « Ouf ! » à moins d'1 s, « La Charge explose ! » | directeur |

## 3. Mesures (parties IA contre IA, Bourg, Difficile contre Difficile, premier à 4, achat de 2 s, ×3, machine saturée)

`python tools/assault_games.py --games 8 -j 2 --win 4 --rule buy_time:2 --rule buy_time_first:2` (copie de HEAD + TAC-3) :

| Mesure | Résultat | Cible de l'étude (TAC-9) |
|---|---|---|
| Manches | 53 (8 parties finies sur 8) | — |
| Attaque gagne | **94 %** (50 sur 53) | 45-55 % |
| Façons | Charge 91 %, élimination 9 %, désamorçage 0, temps 0 | — |
| Durée d'une manche jouée | médiane 67,7 s (10e 60,4, 90e 85,2) | 55-80 s |
| Manches gagnées par la Charge | pose vers 27 s de manche, explosion 40 s après | — |

Lecture : la Charge marche (posée dans 91 % des manches), mais **la Défense ne reprend jamais un site** : l'agent provisoire
(TAC-0) défend en 2-2 et les combats durent encore 20 à 40 s (règles de combat de départ, non mesurées) ; un attaquant qui
garde la Charge à moins de 9 m empêche le désamorçage, et les 40 s de mèche passent avant que le combat ne finisse. Deux suites :
**TAC-4** raccourcit les combats (cible 7 à 10 s par duel) — la mesure est refaite là (`R_TAC_4.md`) ; **TAC-6** (stratège
d'équipe : rotations sur information, reprise groupée, utilitaires) corrigera le reste. Aucune règle de la Charge n'est
retouchée pour compenser une IA provisoire (règle de l'Échiquier : on mesure, puis on règle la bonne couche).

## 4. Preuves

`test_tac3` (vert) : bips (1 s au début, de plus en plus serrés, ≤ 0,15 s à la fin) ; règles dans le profil ; partie réelle sur
le Bourg (8 IA, héros tenus à la main) : porteur = un attaquant qui n'ouvre pas, la Charge sur son dos ; porteur à terre → Charge
au sol à ses pieds ; l'Attaque la voit, la Défense à 90 m non, un défenseur tout près oui ; mini-carte ; ramassée en passant ;
pose en cours annulée par un renversement, puis faite (dans le site A) ; bips ; la Défense la connaît une fois posée ;
désamorçage interrompu après 4,2 s → repris à 3,5 s, puis réussi (la Défense gagne) ; manche suivante : mèche courte au bout,
l'explosion emporte les deux attaquants proches, les défenseurs au loin survivent ; aucun tir ami. Joueur : il porte la Charge
quand il attaque, invite « [G] la lâcher », lâchée puis ramassée en passant, abandon propre.

Non-régression (copie propre de HEAD 0.1.302 + TAC-3, `run_tests.py --reuse -j 2`, machine saturée) : voir § 6.

## 5. Pièges

1. La lanterne du porteur est un enfant du héros (`AssaultChargePack`) : elle se cache avec lui (vision) ; le joueur garde son
   nœud d'une manche à l'autre, donc `_new_charge` retire l'ancienne lanterne (retrait immédiat, pas `queue_free` seul).
2. Le directeur décide de tout ; `AssaultCharge` ne fait que dessiner et biper : pour la tester sans scène, `beep_interval`.
3. Un attaquant perçu à moins de 9 m (`THREAT`) empêche l'IA de poser ou de désamorcer : un test de désamorçage doit écarter
   l'Attaque.
4. `view_hero` lisait `rig.target` libéré (un scripté tombé) : `is_instance_valid` avant `is`.

## 6. Non-régression

Copie propre de HEAD 0.1.302 + TAC-3 (`run_tests.py --reuse -j 2`) : test_tac0, test_tac1, test_tac2, test_tac3, test_mode0,
test_royale, test_texts_fr verts. `check_scripts.py` vert sur l'arbre du commit.
