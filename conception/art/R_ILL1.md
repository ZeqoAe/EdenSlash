# R_ILL1 : illustrations candidates avec le LoRA `eden_style_v0b` (17/10/2026)

Département ILL (`ORGANISATION.md`). **Rien n'est intégré au jeu** (aucun fichier de `game/` touché) : le joueur valide d'abord
sur la planche, un lot suivant intègre les images retenues.

## À regarder
`conception/art/ill/planche.jpg` (21 images, la graine retenue est écrite sur chaque case). Les images seules : `conception/art/ill/<nom>.jpg`.

| Groupe | Images | Taille finale |
|---|---|---|
| Cartes d'activité (13) | `survival`, `survivor`, `dungeon`, `tower`, `quests`, `trials`, `rush`, `siege`, `autochess`, `duel`, `arenas`, `royale`, `training` (mêmes noms que `Activities.LIST`, sauf `arenas` : une image pour 2v2 et 3v3) | 960×320 (68 à 105 Ko) |
| Écran titre et menu principal (2) | `titre` (héros de dos devant un royaume, ciel dégagé en haut pour le logo), `menu` (place de ville au crépuscule, avant-plan calme pour les boutons) | 1600×900 (230 à 270 Ko) |
| Fonds de fin (6) | `fin_victoire`, `fin_defaite` (doux, bleu-lilas, pas sombre), `fin_record` (couronne et podium), `fin_boss` (coffre et gemmes), `fin_egalite` (lac et lanternes, fin neutre), `fin_etoiles` (étoiles d'époque) | 1600×900 (215 à 320 Ko) |

Aucun texte, aucune marque ni personnage d'un autre jeu. Chaque variante a été relue à l'œil ; les visages sont de petite taille
ou de dos (`duel`, `titre`) ; `fin_record` a été pris sans personnage (la variante avec une figure au visage flou a été écartée).

## Réglages
- LoRA `eden_style_v0b.safetensors` (fichier final) à **0,5**, SDXL base 1.0, 30 pas, `dpmpp_2m` / `karras`, cfg 6,5, mot-clé `edenstyle`
  (`tools/art/gen_with_lora.py`, `workflows/sdxl_lora.json`).
- Génération en 1536×512 (cartes, 3:1) ou 1344×768 (16:9), réduite à l'export en JPG (qualité 90, progressif).
- Négatif : texte, lettres, filigrane, logo, interface, photo, flou, mains et visages déformés, « dark, gloomy » (la bible veut des écrans clairs).
- 4 graines par image (`1000 + 10 × rang + k`), puis un **second tour** (graines + 500, prompt renforcé avec pondération « (sujet:1.4) » et le sujet
  en tête) pour 5 images dont le sujet manquait : `survival`, `survivor`, `quests`, `siege`, `royale`.
- Couleurs dominantes de la bible dans les prompts (Survie lagon / pomme, Survivant mandarine / améthyste, Donjons mandarine / améthyste,
  Tour lagon / soleil, Ruée fraise / mandarine, Échiquier améthyste / soleil, Duel fraise / soleil, Arènes lagon contre fraise, Battle royale lagon / pomme…).

## Refaire
`C:\AI\venv_comfy\Scripts\python.exe tools/art/ill_batch.py gen [--only nom,nom] [--retry]` (images brutes dans `C:\AI\ill1_raw`, hors dépôt, avec une
planche de 4 variantes `var_<nom>.jpg` par image ; reprenable), puis `export` (variantes de `CHOICES` -> `conception/art/ill/`) et `sheet` (planche).
Pour changer une image : changer sa graine dans `CHOICES` (les 8 graines de chaque image sont dans `C:\AI\ill1_raw`, sinon relancer `gen`).
Prompts, formats et couleurs : tableau `IMAGES` et `RETRY` en tête du script.

## Temps GPU
104 images, **27 minutes** de calcul (9 à 25 s par image, 13 s en moyenne, RTX 5070 partagée), une génération à la fois, sans autre usage de la carte. Bien sous les 2 h.

## Limites et points de choix pour le joueur
- Le LoRA à 0,5 donne un rendu « 3D toon coloré » cohérent avec les héros et les monstres du jeu, mais ce sont des **décors d'ambiance** : les personnages sont
  petits ou de dos, les foules sont des masses de détails sans visages lisibles (`arenas`, `duel`).
- Sujets partiellement rendus : `arenas` montre le colisée et les bannières bleues contre rouges mais pas deux équipes nettes ; `autochess` : plateau hexagonal
  et figurine centrale, sans pièces nombreuses ; `royale` : l'île et la tempête bleue, pas de héros lisibles ; `tower` : tour dorée dans les nuages, moins élancée que demandé ;
  `quests` : panneau d'annonces, les parchemins portent des gribouillis illisibles (pas de texte réel) ; `trials` : stade et coupe, pas de médailles lisibles.
- Teintes : le LoRA tire vers le vert et le rose pastel ; `fin_defaite` reste lumineuse (couchant lilas) pour respecter « pas de fond sombre » de la bible : à dire si le
  joueur veut une défaite plus grave.
- Pas de remplacement dans `game/assets/` : les cartes actuelles (captures du jeu) restent. Une image validée demande ensuite un lot d'intégration
  (copie dans `game/assets/ui/activities/`, `.import`, capture 1280×720 avec le voile bas des cartes, vérification du contraste du nom et du sous-titre).
- Alternatives par image : chaque `C:\AI\ill1_raw\var_<nom>.jpg` (hors dépôt) montre les autres variantes ; je peux les mettre dans le dépôt sur demande (≈ 300 Ko chacune).
- Choix à faire : (1) garder le style à 0,5 pour toutes les cartes ou mélanger avec les captures du jeu (rendu « jeu » plus fidèle aux héros) ; (2) un seul fond de fin neutre
  ou un par résultat ; (3) l'écran titre : `titre` (héros devant un royaume) convient-il, ou une variante avec une classe précise ?
