# R_SND2 : sons de la bibliothèque SND-1 branchés (département SND), 17/10/2026

Aucun son ni aucune règle modifiés : seuls des appels (`UiFeel.cue`, qui respecte « Intensité des effets d'interface » et le
volume « Effets sonores » de `Sfx`) ont été ajoutés, un par cas, plus quelques changements de nom de son dans l'Échiquier.
« Réduire les animations » ne coupe pas le son (comportement d'SND-1). L'anti-répétition de 40 ms de `Sfx.ui` s'applique partout.

## 1. Cas branchés
| Cas | Où | Son (dB) | Remarque |
|---|---|---|---|
| Victoire d'un bilan | `ResultsPanel.show_spec` (donc Survie, Survivant, Donjons, Tour, Ruée, Siège, Duel, Échiquier, Battle royale) | `ui_victory` (-6) | ton « win » |
| Défaite douce d'un bilan | idem | `ui_defeat` (-8) | ton « lose » ; un bilan neutre (extraction) se tait |
| « Record ! » | idem (`ResultsPanel.has_record` : tuile « Record ! », note « Record… », ligne « record ») | `ui_record` (-8) | accent à 1,5 s |
| Étoile gagnée | idem (`has_new_star` : objectif « nouvelle », ligne « Étoile… ») | `ui_star` (-8) | accent suivant |
| Butin de fin par rareté | idem (plus haute rareté de `spec.loot`) | `Sfx.reward(rareté)` (-9) | un seul son, pas un par pièce |
| Niveau de héros gagné | idem (note « Ton héros passe au niveau N. ») | `ui_level_up` (-9) | |
| Coffre ouvert (menu Coffres) | `ChestsPage._show_loot` (aussi « Ouvrir tout ») | `Sfx.reward(plus haute rareté du contenu)` (-9, +0,3 s) | fournitures seules : aucun son de rareté |
| Meilleure pièce trouvée en partie | `Hud.show_better` (hors Battle royale) | `Sfx.reward(rareté)` (-10) | pas deux en moins de 1,5 s |
| Forge réussie / ratée | `ForgeBench.done` (`verdict_sound`) | `ui_forge_ok` / `ui_forge_fail` (-9) | une demande refusée (« Pas assez de… », « Il faut… ») joue `ui_deny` : ce n'est pas une forge ratée |
| Compte à rebours et « C'est parti » | `DuelDirector.update` (3, 2, 1 puis COMBAT !) | `ui_tick` (-8) / `ui_go` (-8) | Battle royale : déjà ses `tick` / `doors` |
| Coup reçu léger | `Hud._on_player_hit` (signal `damaged` du héros) | `ui_hit` (-10) | de 1,2 % à 30 % des PV max, avec une source, au plus un toutes les 0,45 s |
| Or d'une vente | `MerchantPages` (vente qui rapporte de l'or) | `ui_coin` (-10) | le `gold` du jeu (ramassage en partie) ne change pas |
| Moments de l'Échiquier | `AutochessScreen` : Gardien ! -> `ui_banner` ; Trois étoiles ! et ★★ -> `ui_star` ; Niveau n ! -> `ui_level_up` | -6 / -9 / -10 | passés au module ACX-2 par ses paramètres, rien dans le module |

Les accents d'un bilan (`ResultsPanel.moments`) : le résultat à 0 s, puis au plus 3 accents espacés d'1 s à partir de 1,5 s, dans
l'ordre record, étoile, butin, niveau de héros. Les minuteurs sont liés au bilan : s'il est fermé avant, l'accent ne se joue pas.
Outils ajoutés : `Sfx.played` (compteur de lectures par nom, pour les tests), `UiFeel.cue_later(délai, …)`, `UiFeel.reward_cue(rareté, dB, délai)`.

## 2. Doublons évités
- Battle royale : `RoyaleResults._confetti` jouait `confirm` à la victoire ; retiré (`ui_victory` du bilan le remplace). Le reste de BR-I3
  (`RoyaleAmbience`, `ui_banner` / `ui_star` / `ui_tick` / `ui_go` des annonces) n'est pas touché.
- Survivant (SVX-2, `survivor_moments.gd`) : « Niveau ! » joue déjà `ui_primary`, l'évolution `level_up` (même fichier que `ui_level_up`),
  « Le boss ! » `rock` : laissés tels quels ; son bilan passe par `ResultsPanel` (victoire / défaite seulement).
- Survie : la montée de niveau de partie (`world.gd`) joue déjà `level_up`, qui est le fichier de `ui_level_up` : rien à ajouter.
- Échiquier : les coffres du bilan (`ChestSticker`) gardent leur `confirm` montant ; la fin de partie ajoute victoire / défaite.

## 3. Cas laissés et pourquoi
- Butin ramassé au sol en Survie (`loot_drop`) et coffres d'emplacement : trop fréquents (30 par carte), le son de rareté y serait du bruit ;
  la signalisation de rareté y reste le rayon de lumière. À reconsidérer après écoute (par exemple épique et au-delà seulement).
- Or ramassé en partie (`gold`, `run_director`) : le son du jeu reste, très fréquent ; `ui_coin` n'est que dans les menus.
- Montée de niveau de héros dans le lobby (jauge) : aucune animation de montée à l'écran ; le son suit la note du bilan.
- Compte à rebours hors duel : il n'y en a pas (Tour, Ruée, Siège, Donjons commencent sans chiffres) ; ajouter un compte à rebours
  serait une règle de jeu.
- `ui_notify`, `ui_card_flip`, `ui_card_pick` : hors de la mission (autres cas), toujours prêts.

## 4. Test
`tests/test_snd2.tscn` : le plan des sons du bilan (victoire, défaite, record, étoile, six raretés, niveau de héros, plafond de 3
accents, espacement), un bilan réel (ordre des sons, aucun son après fermeture, silence à intensité 0), un coffre (commun puis légendaire :
un seul son, fournitures seules : aucun), la forge (réussie, ratée, refusée), le compte à rebours du duel, l'or, le câblage de l'Échiquier
et du Battle royale, et dans un monde réel le coup léger du HUD (trop faible, trop fort, sans source, anti-spam) et la pièce meilleure.
Chaque cas lit `Sfx.played`. Piège : un minuteur créé juste après l'ouverture d'un bilan (image lente) peut se déclencher trop tôt ; le
test attend donc par les images.

## 5. À écouter
Le coup reçu léger en Survivant (une horde peut le déclencher toutes les 0,45 s) : trop présent ? Réglages dans `Hud` (`HIT_MIN`,
`HIT_MAX`, `HIT_GAP_MS`) et le dB de l'appel. La suite victoire + record + butin d'un bilan chargé (3,5 s) : trop longue ? (`MOMENT_*`).
