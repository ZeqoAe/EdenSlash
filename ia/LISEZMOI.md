# IA d'entraînement d'Eden Slash

Une IA apprend à jouer le **guerrier** en se battant des milliers de fois dans une arène du
jeu, sans fenêtre et en accéléré (environ 190 fois plus vite que le temps réel avec 12 jeux
en parallèle). Elle apprend par essais et erreurs (apprentissage par renforcement, algorithme
PPO) : elle reçoit des points quand elle fait des dégâts, gagne, esquive ou réussit une
annulation parfaite, et en perd quand elle est touchée, perd ou traîne.

## Utilisation (double-clic à la racine du dépôt)

| Fichier | Rôle |
|---|---|
| `IA_Installer.bat` | Une seule fois : installe Python, PyTorch et Stable-Baselines3 dans `ia/.venv`. |
| `IA_Entrainer.bat` | Lance l'entraînement. **Ctrl+C** l'arrête proprement ; le relancer reprend là où il s'était arrêté. |
| `IA_Regarder.bat` | Ouvre le jeu en fenêtre et montre l'IA en train de jouer (ex. `IA_Regarder.bat hardcore`). |

Pendant l'entraînement, la console affiche toutes les 30 s l'étape en cours, le taux de
réussite et, par scénario : victoires, survie, durée des combats, dégâts infligés et subis,
enchaînements réussis, annulations parfaites et coups esquivés. Les mêmes chiffres sont dans
`ia/progression.json` (dernier état) et `ia/journal_entrainement.csv` (historique).

Options : `IA_Entrainer.bat --jeux 8` (moins de jeux si le PC rame), `--nouveau` (repartir de
zéro, l'ancien modèle est mis de côté), `--etape 5` (sauter à une étape).

## Les étapes

L'étape suivante s'ouvre quand l'objectif est atteint sur les 200 derniers combats jugés.
Une partie des combats rejoue les étapes passées pour que l'IA ne les oublie pas.

1. **Mannequin, 4 sorts** : tuer un mannequin le plus vite possible (combo, portée, sorts).
2. **Mannequin, 12 sorts** : 2 enchaînements par case ; objectif : gagner avec au moins
   3 enchaînements réussis (bon timing de la barre).
3. **Adversaire fuyard** : il court, longe le mur et s'échappe d'un bond ; l'IA doit coller,
   enchaîner et utiliser les esquives d'annulation (bonus pour chaque annulation parfaite).
4. **Monstres, héros à 1 PV** : un coup et c'est perdu ; survivre 40 s ou tuer les monstres
   (1 ou 2 monstres d'Eden). Bonus pour chaque coup esquivé.
5. à 8. **Adversaire de classe** facile, normal, difficile puis **hardcore** (objectif : 70 %
   de victoires contre le hardcore).
9. **Perfectionnement** : hardcore sans fin.

Le modèle de chaque étape réussie est gardé dans `ia/modeles/etapes/` ; pour regarder un
ancien modèle : `.venv\Scripts\python watch.py hardcore --modele modeles/etapes/etape_3_reussie.zip`
(depuis le dossier `ia`).

## Comment ça marche

- `game/scenes/ml_arena.tscn` (`game/scripts/ml/ml_arena.gd`) : l'arène. Sol plat de 15 m de
  rayon entouré d'un mur, héros niveau 10 sans équipement, adversaire selon le scénario. Le jeu
  se connecte au programme Python et avance au même pas que lui : 1 décision toutes les
  3 images (20 décisions par seconde de jeu). Rien n'est sauvegardé (profil de test vierge).
- Ce que voit l'IA (133 nombres) : son état (PV, action en cours, instant de l'impact,
  fenêtre d'annulation parfaite, combo, recharges, enchaînements et barre de timing, saut,
  statuts), celui de l'adversaire (distance, direction, vitesse, PV, attaque en cours, esquives,
  statuts), les 2 zones rouges les plus proches de l'impact (forme, position, temps restant,
  « je suis dedans »), le projectile le plus proche et sa position dans l'arène.
- Ce qu'elle fait à chaque décision : une direction (rien ou 8 directions, par rapport à
  l'adversaire), une touche (rien, attaque, sort 1 à 4, esquive, saut) et une visée (sur
  l'adversaire, ou en avance sur son déplacement).
- `ia/eden_env.py` : lance les jeux et fait le lien avec Stable-Baselines3.
- `ia/curriculum.py` : les étapes, leurs scénarios et leurs objectifs (facile à modifier).
- `ia/train.py` et `ia/watch.py` : entraînement et visionnage.

Si une observation est ajoutée ou retirée dans `ml_arena.gd`, un modèle déjà entraîné ne peut
plus être chargé : relancer avec `--nouveau`.
