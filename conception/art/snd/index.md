# Planche des sons d'interface (lot SND-1)

Générée par `python tools/art/snd_synth.py` (ne pas éditer à la main). Fichiers : `game/assets/sfx/ui/` (WAV 16 bits,
44,1 kHz, mono ; tous à la même sonie, -20 dB en pondération K sur 50 ms, crête ≤ -1 dBFS : le volume de chaque rôle
se règle dans le jeu, `UiFeel.SOUNDS` et les appels `Sfx.ui`). Rôle = nom passé à `Sfx.ui(...)` (une liste = variantes
tirées au hasard). Écoute d'un coup :
`ecoute_planche.ogg` (tous les sons à la suite, dans l'ordre du tableau, 0,45 s de silence entre deux).

Mesures : **RMS** = niveau le plus fort sur 30 ms (dBFS, avant le volume du jeu) ; **centre** = centroïde spectral
(clarté) ; **> 8 kHz** = part de l'énergie dans l'aigu (perçant au-delà de 5 %) ; **bords** = premier / dernier
échantillon (0 = aucun clic au début ni à la fin) ; **saut** = plus grand écart entre deux échantillons voisins.

Total : 46 fichiers, 2357 Ko.


## Interface

| Fichier | Rôle | Son | Durée | RMS | Centre | > 8 kHz | Bords | Saut | Ko |
|---|---|---|---|---|---|---|---|---|---|
| `hover_1.wav` | `ui_hover` | « tic » de bois très court (50 ms), doux, sans aigu : survol à la souris | 50 ms | -20.2 | 1679 Hz | 0.0 % | 0e+00 | 0.15 | 4 |
| `hover_2.wav` | `ui_hover` | « tic » de bois très court (50 ms), doux, sans aigu : survol à la souris | 50 ms | -20.4 | 1810 Hz | 0.0 % | 0e+00 | 0.17 | 4 |
| `hover_3.wav` | `ui_hover` | « tic » de bois très court (50 ms), doux, sans aigu : survol à la souris | 50 ms | -20.0 | 1575 Hz | 0.0 % | 0e+00 | 0.16 | 4 |
| `focus_1.wav` | `ui_focus` | note de marimba aiguë très brève (mi, ré, sol) : le cadre de la manette avance | 182 ms | -20.0 | 1371 Hz | 0.0 % | 0e+00 | 0.08 | 16 |
| `focus_2.wav` | `ui_focus` | note de marimba aiguë très brève (mi, ré, sol) : le cadre de la manette avance | 165 ms | -19.1 | 1280 Hz | 0.0 % | 0e+00 | 0.07 | 14 |
| `focus_3.wav` | `ui_focus` | note de marimba aiguë très brève (mi, ré, sol) : le cadre de la manette avance | 189 ms | -20.0 | 1670 Hz | 0.0 % | 0e+00 | 0.11 | 16 |
| `press_1.wav` | `ui_press` | « pop » mat de bulle (60 ms) : bouton enfoncé | 60 ms | -18.0 | 615 Hz | 0.0 % | 0e+00 | 0.04 | 5 |
| `press_2.wav` | `ui_press` | « pop » mat de bulle (60 ms) : bouton enfoncé | 60 ms | -18.0 | 661 Hz | 0.0 % | 0e+00 | 0.04 | 5 |
| `press_3.wav` | `ui_press` | « pop » mat de bulle (60 ms) : bouton enfoncé | 60 ms | -17.9 | 569 Hz | 0.0 % | 0e+00 | 0.03 | 5 |
| `release_1.wav` | `ui_release` | « clic » clair de bloc de bois + petite montée : bouton relâché | 127 ms | -19.1 | 1442 Hz | 0.0 % | 0e+00 | 0.09 | 11 |
| `release_2.wav` | `ui_release` | « clic » clair de bloc de bois + petite montée : bouton relâché | 137 ms | -19.5 | 1733 Hz | 0.0 % | 0e+00 | 0.11 | 12 |
| `release_3.wav` | `ui_release` | « clic » clair de bloc de bois + petite montée : bouton relâché | 130 ms | -18.9 | 1288 Hz | 0.0 % | 0e+00 | 0.09 | 11 |
| `primary.wav` | `ui_primary` | pop + carillon montant do → sol : bouton primaire (soleil) | 882 ms | -20.9 | 1410 Hz | 0.1 % | 0e+00 | 0.08 | 76 |
| `confirm.wav` | `confirm` | deux lames la → mi qui montent : validation, achat, choix confirmé | 602 ms | -20.3 | 1298 Hz | 0.0 % | 0e+00 | 0.06 | 52 |
| `deny.wav` | `ui_deny` | « bonk » rond et sourd qui descend : bouton désactivé, action refusée | 240 ms | -18.9 | 254 Hz | 0.0 % | 0e+00 | 0.01 | 21 |
| `tab.wav` | `ui_tab` | « flip » de papier + petit tic : changement d'onglet | 216 ms | -21.9 | 2870 Hz | 3.3 % | 0e+00 | 0.14 | 19 |
| `toggle_on.wav` | `ui_toggle_on` | clic-clac qui monte : interrupteur allumé | 166 ms | -20.8 | 1605 Hz | 0.0 % | 0e+00 | 0.13 | 14 |
| `toggle_off.wav` | `ui_toggle_off` | clac-clic qui descend : interrupteur éteint | 168 ms | -19.7 | 894 Hz | 0.0 % | 0e+00 | 0.09 | 15 |
| `swoosh.wav` | `ui_swoosh` | souffle doux qui monte : carte d'activité ouverte | 406 ms | -20.8 | 1888 Hz | 1.9 % | 0e+00 | 0.09 | 35 |
| `equip.wav` | `ui_equip` | « clac » de plastique + petite clochette : pièce équipée | 330 ms | -20.6 | 1320 Hz | 0.0 % | 0e+00 | 0.06 | 28 |
| `open.wav` | `ui_open` | souffle montant + pincé sol-do : page ou fenêtre qui s'ouvre | 552 ms | -20.5 | 934 Hz | 0.0 % | 0e+00 | 0.07 | 48 |
| `close.wav` | `ui_close` | souffle descendant + pincé do grave : page qui se ferme | 426 ms | -19.3 | 565 Hz | 0.0 % | 0e+00 | 0.12 | 37 |
| `card_flip.wav` | `ui_card_flip` | deux frottements de papier + note : carte qui se retourne | 255 ms | -21.9 | 2159 Hz | 1.1 % | 0e+00 | 0.21 | 22 |
| `card_pick.wav` | `ui_card_pick` | « shing » : souffle aigu + clochettes mi-la : carte choisie | 955 ms | -21.9 | 1883 Hz | 0.1 % | 0e+00 | 0.12 | 82 |
| `notify.wav` | `ui_notify` | deux lames sol → ré (quinte) : notification, nouveauté | 776 ms | -20.5 | 1173 Hz | 0.0 % | 0e+00 | 0.05 | 67 |
| `tick.wav` | `ui_tick` | bloc de bois sec et rond : compte à rebours (3, 2, 1) | 138 ms | -18.8 | 1061 Hz | 0.0 % | 0e+00 | 0.09 | 12 |
| `go.wav` | `ui_go` | accord de clochettes do-mi-sol + élan : « C'est parti ! » | 1004 ms | -21.2 | 1474 Hz | 0.0 % | 0e+00 | 0.06 | 87 |

## Récompenses

| Fichier | Rôle | Son | Durée | RMS | Centre | > 8 kHz | Bords | Saut | Ko |
|---|---|---|---|---|---|---|---|---|---|
| `coin_1.wav` | `ui_coin` | deux pièces de métal qui tintent (inharmonique, pas une mélodie) : or, pièces | 358 ms | -23.3 | 3433 Hz | 0.5 % | 0e+00 | 0.10 | 31 |
| `coin_2.wav` | `ui_coin` | deux pièces de métal qui tintent (inharmonique, pas une mélodie) : or, pièces | 340 ms | -22.1 | 3542 Hz | 0.9 % | 0e+00 | 0.11 | 29 |
| `coin_3.wav` | `ui_coin` | deux pièces de métal qui tintent (inharmonique, pas une mélodie) : or, pièces | 345 ms | -22.7 | 3362 Hz | 0.0 % | 0e+00 | 0.10 | 30 |
| `reward_1.wav` | `ui_reward_1` | 2 notes montantes : objet commun ou spécial | 732 ms | -19.8 | 626 Hz | 0.0 % | 0e+00 | 0.03 | 63 |
| `reward_2.wav` | `ui_reward_2` | 3 notes : objet rare | 944 ms | -20.0 | 826 Hz | 0.0 % | 0e+00 | 0.04 | 81 |
| `reward_3.wav` | `ui_reward_3` | 4 notes + clochette : objet épique | 1328 ms | -19.7 | 1344 Hz | 0.0 % | 0e+00 | 0.05 | 114 |
| `reward_4.wav` | `ui_reward_4` | 5 notes + clochettes + scintillement : objet mythique | 1625 ms | -20.6 | 1243 Hz | 0.1 % | 0e+00 | 0.07 | 140 |
| `reward_5.wav` | `ui_reward_5` | 6 notes + accord + étincelles + basse : objet légendaire (signature, bible § 7) | 1905 ms | -21.0 | 1956 Hz | 0.0 % | 0e+00 | 0.07 | 164 |

## Moments

| Fichier | Rôle | Son | Durée | RMS | Centre | > 8 kHz | Bords | Saut | Ko |
|---|---|---|---|---|---|---|---|---|---|
| `level_up.wav` | `ui_level_up` | gamme qui monte puis accord de clochettes : niveau gagné | 1526 ms | -19.9 | 1048 Hz | 0.1 % | 0e+00 | 0.05 | 131 |
| `star.wav` | `ui_star` | éclat de verre + clochettes mi-si : étoile gagnée | 796 ms | -21.5 | 1432 Hz | 0.0 % | 0e+00 | 0.07 | 69 |
| `record.wav` | `ui_record` | « ta-ta-taa » (la la ré) + accord : record battu | 1425 ms | -21.1 | 1473 Hz | 0.0 % | 0e+00 | 0.06 | 123 |
| `victory.wav` | `ui_victory` | petite mélodie montante + accord tenu + étincelles (1,9 s) : victoire | 2492 ms | -21.5 | 1402 Hz | 0.1 % | 0e+00 | 0.06 | 215 |
| `defeat.wav` | `ui_defeat` | 4 lames qui descendent + accord suspendu, feutré : défaite douce | 2364 ms | -19.7 | 384 Hz | 0.0 % | 0e+00 | 0.02 | 204 |
| `banner.wav` | `ui_banner` | élan + coup rond grave + éclat de clochettes (0,4 s) : bannière de moment manga | 657 ms | -18.2 | 1066 Hz | 0.0 % | 0e+00 | 0.05 | 57 |
| `forge_ok.wav` | `ui_forge_ok` | tintement d'enclume + arpège de clochettes : forge réussie | 1094 ms | -21.6 | 1410 Hz | 0.1 % | 0e+00 | 0.07 | 94 |
| `forge_fail.wav` | `ui_forge_fail` | « clonk » étouffé + bouffée + 2 notes qui descendent, sans dureté : forge ratée | 766 ms | -19.1 | 481 Hz | 0.0 % | 0e+00 | 0.03 | 66 |
| `hit_1.wav` | `ui_hit` | coup feutré grave (90 ms), sans aigu : coup reçu léger (HUD) | 90 ms | -18.0 | 149 Hz | 0.0 % | 0e+00 | 0.02 | 8 |
| `hit_2.wav` | `ui_hit` | coup feutré grave (90 ms), sans aigu : coup reçu léger (HUD) | 90 ms | -18.1 | 162 Hz | 0.0 % | 0e+00 | 0.02 | 8 |
| `hit_3.wav` | `ui_hit` | coup feutré grave (90 ms), sans aigu : coup reçu léger (HUD) | 90 ms | -17.8 | 138 Hz | 0.0 % | 0e+00 | 0.01 | 8 |
