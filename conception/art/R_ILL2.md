# R_ILL2 : intégration des 21 illustrations validées (17/10/2026)

Suite de `R_ILL1.md` : le joueur a validé la planche, les images entrent dans le jeu. Captures avant / après : `ill2_captures.jpg`
(titre, fenêtre Jouer, cartes d'activité, bilans victoire / défaite / boss) ; refaire : `tests/shot_ill2.tscn`.

## Ce qui est fait
| Pièce | Où | Comment |
|---|---|---|
| 13 cartes d'activité (960 × 320) | `game/assets/ui/activities/<id>.jpg` | une image par activité, nom = `id` de `Activities.LIST` ; les clés `"img"` qui renvoyaient à une capture d'une autre activité (`training`, `dungeon`, `arena3`, `arena2`, `battlefield`) sont retirées (aucune clé renommée) ; `arena2` / `arena3` / `battlefield` supprimées (plus lues par personne) |
| Voile des cartes | `Activities._art` | voile qui monte plus tôt (point à 72 % de la hauteur) et contour sombre de 3 px sur le sous-titre ; contraste mesuré du sous-titre (blanc cassé contre l'image voilée, 90e centile) : 6,4 à 9,6 pour 1 sur les 13 images, avant 5,7 à 9,0 |
| Écran titre | `ui/title_screen.gd`, `assets/ui/backdrops/titre.jpg` | l'illustration remplace le survol 3D des maps (plus de génération de carte au titre : démarrage plus léger) ; logo en haut au centre dans le ciel, boutons en bas à gauche (hors du héros et du royaume) ; voiles du titre plus légers |
| Menu principal | `assets/ui/backdrops/menu.jpg` | fondu par-dessus le titre quand la fenêtre Jouer (Continuer / Charger / Nouvelle partie) s'ouvre, retour au titre en la fermant ; voiles du titre coupés, dim de la fenêtre 0,22 |
| 6 fonds de fin | `ui/results_panel.gd` (`backdrop_key`, `backdrop_art`), `assets/ui/backdrops/fin_*.jpg` | derrière le voile du bilan (opacité réglée à `BACKDROP_VEIL` 0,45 quelle que soit la couleur du voile du composant), apparition en fondu de 0,6 s ; le panneau reste opaque |

Choix du fond (`ResultsPanel.backdrop_key`, clé `bg` possible dans la description pour forcer) : ton « lose » : **défaite** ; ton neutre
(« info », l'extraction de la Survie) : **égalité** ; victoire : **étoiles** si une étoile d'époque est gagnée (ligne « Étoile d'époque » ou objectif
neuf) > **record** (note « Record ! » ou ligne « Nouveau record ») > **boss** (butin en cases, c'est-à-dire un boss tombé avec son coffre) > **victoire**.
Aucun bilan existant n'a été modifié : tout se lit dans la description.

## Décision à connaître : le lobby garde sa scène 3D
Le menu principal du jeu (le lobby) est la scène du héros du joueur dans la zone choisie (caméra qui tourne, tenue, aura, zone en vignette) : y poser
une image aurait supprimé la présentation du héros, et l'équipe HUB-1 y travaille. L'image `menu` sert donc au menu du titre (Jouer), là où il n'y a pas de
scène à montrer. Si le joueur veut `menu` dans le lobby aussi (par exemple derrière les pages plein cadre), c'est un autre lot.

## Poids (le dépôt est public)
Cartes 70 à 105 Ko, fonds 215 à 320 Ko, au plus 400 Ko chacune ; `.import` des 8 fonds : `compress/mode=1` (WebP avec perte, 0,8) : ≈ 100 à 160 Ko
par fond dans le cache importé, contre 1 à 1,5 Mo sans perte ; cartes en mode 0 comme les autres. Rien de tiers.

## Vérifications
`check_scripts` (les 4 scripts touchés compilent ; une erreur d'un test d'une autre équipe, `test_bri3`, était en cours), `test_nav_screens`, `test_pages` (le test du titre lit
maintenant les deux illustrations au lieu de la carte 3D), `test_results`, `test_p2` verts sur une copie propre de HEAD + ce lot. Captures `shot_ill2` à 1280 × 720 et
1600 × 900, comptes neuf et avancé : aucune ligne `[débord]`, noms et sous-titres lisibles sur les 13 cartes (neuves, verrouillées et ouvertes), bandeaux de page, 6 bilans.

## Restes
- `Activities.banner` (bandeau des pages d'activité, 150 px) recadre l'image 3:1 en haut et en bas : le sujet reste centré, rien à retoucher.
- `ui/title_screen.gd` : `MapBackdrop.fly_over` n'est plus appelé (le lobby garde `MapBackdrop`).
