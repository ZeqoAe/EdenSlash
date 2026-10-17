# R_SND1 : bibliothèque de sons d'interface et de moments manga (département SND), 17/10/2026

Bible v2 § 7 et § 11 : matière « jouet » (bois, plastique, carillon, papier), courte, joyeuse, jamais agressive.
Planche détaillée (chaque son, durée, niveau, clarté, contrôle des clics) : `snd/index.md` ; **à écouter d'abord** :
`snd/ecoute_planche.ogg` (48 s, les 46 sons à la suite dans l'ordre de la planche).

## 1. Méthode retenue : synthèse procédurale (pas de modèle génératif)
| Piste | Constat | Verdict |
|---|---|---|
| Stable Audio Open 1.0 / Small (Stability AI) | licence « Stability AI Community License » : usage commercial gratuit sous 1 M$ de chiffre d'affaires annuel, sorties à nous (sous réserve de la politique d'usage) ; données d'entraînement Freesound + FMA en CC0 / CC BY / CC Sampling+ ; **accès fermé** sur Hugging Face (compte + acceptation des conditions : à faire par le joueur, pas par une session) ; aucun modèle audio n'est installé dans `C:\AI\ComfyUI\models`. | possible plus tard pour des **ambiances** (vent, foule, forge) ; mauvais outil pour des sons de 50 ms au millimètre (non déterministe, timbre peu contrôlable, aucune garantie de cohérence d'un son à l'autre) |
| AudioGen / MusicGen (Meta AudioCraft) | poids sous **CC BY-NC 4.0** : pas d'usage commercial | exclu |
| Synthèse en Python (numpy / scipy) | contrôle total (hauteur, durée, enveloppe), reproductible à l'identique (graine fixe), aucun échantillon extérieur, rien à licencier | **retenu** |

Script : `tools/art/snd_synth.py` (`python tools/art/snd_synth.py [--only nom] [--preview]`). Instruments maison : lame de
marimba (fondamentale + partiels 3,93 et 9,2 + toucher de maillet), carillon (partiels 1 ; 2,76 ; 5,40 ; 8,93), clochette
ronde, pincé FM doux, bloc de bois, « pop » de bulle (sinus qui glisse), souffle filtré qui glisse (filtre à état variable),
métal inharmonique (enclume, pièces), coup feutré ; petite pièce synthétique (convolution avec un bruit qui s'éteint) pour
coller les sons entre eux. **Gamme pentatonique de do** (do ré mi sol la) pour tous les sons tonals : deux sons qui se
suivent ne frottent jamais. Finition : passe-haut 70 Hz, passe-bas 10,5 kHz (aucun aigu perçant), saturation très douce,
queue coupée sous -54 dB puis fondu, montée ≥ 0,8 ms. **Aucun son d'un autre jeu**, aucun échantillon importé.

Format : WAV PCM 16 bits, 44,1 kHz, mono (comme les sons du jeu ; Godot les importe compressés, `compress/mode=2`).
**Même sonie pour tous** : -20 dB en pondération K (BS.1770) sur 50 ms = la sonie du son « confirm » d'origine (UI007) ;
la hiérarchie se fait en dB dans le jeu (`UiFeel.SOUNDS`, appels `Sfx.ui`). Poids : 46 fichiers, **2,3 Mo** (+ 200 Ko d'écoute
en OGG dans `conception/`).

## 2. Écoute indirecte (mesures du script, `snd/index.md`)
Pour chaque fichier : durée, crête, niveau court, centroïde spectral, part d'énergie au-dessus de 8 kHz, premier et dernier
échantillon. Résultats : **0 au début et à la fin de chaque fichier** (aucun clic), aucune composante continue, aigu > 8 kHz
≤ 1,1 % partout (seuil d'alerte 5 %), crêtes entre -6 et -17 dBFS (marge). Le survol (le son le plus répété) dure 50 ms,
centré vers 1,7 kHz, sans aigu ; l'appui 60 ms, centré vers 600 Hz (mat).

## 3. Les sons
| Groupe | Sons (nom Sfx) |
|---|---|
| Interface | survol `ui_hover` ×3, focus manette `ui_focus` ×3 (mi, ré, sol), appui `ui_press` ×3, relâchement `ui_release` ×3, primaire `ui_primary`, validation `confirm`, refus `ui_deny` / `error`, onglet `ui_tab`, interrupteur `ui_toggle_on` / `ui_toggle_off`, carte d'activité `ui_swoosh`, équipement `ui_equip`, page `ui_open` / `ui_close`, carte retournée `ui_card_flip`, carte choisie `ui_card_pick`, notification `ui_notify`, compte à rebours `ui_tick` + `ui_go` |
| Récompenses | or `ui_coin` ×3 (tintement de métal, pas une mélodie), objet par rareté `ui_reward_1` à `_5` (2 → 6 notes ; `Sfx.reward(rareté)` : commun et spécial = 1, rare 2, épique 3, mythique 4, légendaire 5) |
| Moments | niveau `ui_level_up` (aussi `level_up`), étoile `ui_star`, record `ui_record`, victoire `ui_victory`, défaite douce `ui_defeat` (accord suspendu, pas un glas), bannière manga `ui_banner`, forge `ui_forge_ok` / `ui_forge_fail`, coup reçu léger `ui_hit` ×3 |

## 4. Intégration
- `combat/sfx.gd` : noms `ui/…` lus dans `game/assets/sfx/ui/` ; **tous les sons provisoires `ui_*` remplacés** ; anciens noms
  d'interface passés à la bibliothèque : `click` (relâchement, -5 dB pour garder son niveau), `confirm`, `error`, `level_up`
  (+2 dB) ; les sons du monde (`chest`, `gold`, `pickup`, `station`, `wood`, `rock`, alertes de boss) ne changent pas.
  Une liste = variantes tirées au hasard ; `Sfx.ui` refuse déjà le même son deux fois en 40 ms.
- `core/ui_feel.gd` : `SOUNDS` sur la bibliothèque, dB de la bible (survol -26, focus -24, appui -15, relâchement -13,
  primaire -9, refus -13, onglet -16, interrupteur -16 / -17, carte -15, équipement -12, page -17 / -19), hauteur 1 (±3 % au
  hasard) ; un tic de survol ou de focus ne se pose jamais à moins de 40 ms d'un autre son d'interface ; `UiFeel.page_sound`.
- `ui/page_screen.gd` : `open` / `close_ui` jouent `ui_open` / `ui_close` (l'ouverture remplace le « clic » du bouton).
- Réglages : volume « Effets sonores » (`Sfx.volume_db`) ; « Réduire les animations » et « Vibration » ne coupent pas le son ;
  « Intensité des effets d'interface » à 0 coupe les sons de UiFeel (comportement d'UIK0, inchangé).
- Test `tests/test_snd1.tscn` : chargement de chaque fichier, durées, 3 variantes, noms de UiFeel, raretés, anti-répétition,
  volume, réduire les animations, poids ≤ 3 Mo.

## 5. Limites
- **Personne n'a écouté** ces sons avant le joueur : tout est mesuré, rien n'est jugé à l'oreille. Le timbre « jouet » est
  propre mais plus simple qu'une banque de bruitages enregistrés.
- Pas encore branchés (noms prêts, un appel chacun) : récompenses par rareté (coffres, bilans : `Sfx.ui(Sfx.reward(r))`),
  étoiles et record des bilans, victoire / défaite (`ResultsPanel`), bannières de moments (`AutochessMoment` : passer
  `ui_banner`, `ui_star`…), forge, compte à rebours, coup reçu du HUD, or (`gold` reste le son du jeu, très fréquent en partie :
  `ui_coin` est à essayer d'abord dans les menus). Les sons d'alerte du lot DNG-2 restent provisoires.
- Musique : hors de ce lot.

## 6. Ce que le joueur doit écouter et valider
1. `conception/art/snd/ecoute_planche.ogg` d'un bout à l'autre (l'ordre suit `snd/index.md`) : cohérence de la famille.
2. En jeu, menu principal et Paramètres : survol de 20 boutons de suite (fatigue ?), clic, onglets, interrupteur, ouverture et
   fermeture d'une page ; à la manette, le cadre qui avance (les 3 notes de focus : agréable ou trop « mélodique » ?).
3. Un bouton désactivé : le « bonk » est-il assez doux ? Un choix de carte (validation `confirm`).
4. Dire pour chacun : garder / plus doux / plus court / autre matière. Une retouche = un réglage dans `snd_synth.py`, puis
   relancer le script (mêmes noms de fichiers, rien à changer dans le jeu). Revenir à un ancien son : une ligne dans `Sfx.UI`.
