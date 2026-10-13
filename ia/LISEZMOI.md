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
   (1 ou 2 monstres d'Eden, insensibles aux contrôles). Bonus pour chaque coup esquivé.
5. à 7. **Adversaire de classe** facile, normal, difficile (90 % de victoires).
8. **Hardcore** : gagner en perdant moins de la moitié de ses PV.
9. **Expert** : hardcore de toutes les classes et **1 contre 2** (comme la Tour), en perdant
   moins de 30 % de ses PV.
10. **Maître** : sans fin, mêmes combats ; on vise la victoire sans presque être touché.

Le modèle de chaque étape réussie est gardé dans `ia/modeles/etapes/` ; pour regarder un
ancien modèle : `.venv\Scripts\python watch.py hardcore --modele modeles/etapes/etape_3_reussie.zip`
(depuis le dossier `ia`).

## Cerveaux pour le jeu (la Tour)

Le jeu fait tourner un cerveau tout seul, sans Python (`MlBrain`, `game/scripts/ml/ml_brain.gd` :
mêmes décisions que dans Python, environ 2,5 ms par décision, soit 5 % d'un cœur). Les cerveaux
sont exportés automatiquement dans `game/data/cerveaux/` quand une étape est réussie :

| Fichier | Après l'étape |
|---|---|
| `guerrier_debutant.json` | 4 (sait esquiver, jamais affronté de héros) |
| `guerrier_facile.json` … `guerrier_hardcore.json` | 5 à 8 (bat l'adversaire de ce niveau) |
| `guerrier_expert.json` | 9 (toutes les classes, 1 contre 2) |
| `guerrier_maitre.json` | 10, mis à jour toutes les 10 minutes |

Export à la main : `.venv\Scripts\python export_brain.py modeles/guerrier.zip guerrier_test`.
Dans le jeu : `MlBrain.load_file(chemin).act(obs, temperature)` ; `temperature` 0 = le meilleur
choix, plus haut = des erreurs (plus humain, plus facile). Essai sans fenêtre :
`Godot --headless --fixed-fps 60 --path game res://scenes/ml_arena.tscn -- --brain=res://data/cerveaux/guerrier_maitre.json --scenario=duo --episodes=20`
(scénarios : mannequin, fuyard, survie, facile, normal, difficile, hardcore, toutes, duo).
Le test `res://tests/test_ml_brain.tscn` vérifie qu'un cerveau donne les mêmes actions que Python.

Pour l'instant le cerveau pilote le héros (`Player.bot`) : pour qu'il joue un adversaire dans
la Tour, il faudra un héros ennemi qui a les mêmes mécaniques que le joueur.

## Comment ça marche

- `game/scenes/ml_arena.tscn` (`game/scripts/ml/ml_arena.gd`) : l'arène. Sol plat de 15 m de
  rayon entouré d'un mur, héros niveau 10 sans équipement, adversaire selon le scénario. Le jeu
  se connecte au programme Python et avance au même pas que lui : 1 décision toutes les
  3 images (20 décisions par seconde de jeu). Rien n'est sauvegardé (profil de test vierge).
- Ce que voit l'IA (139 nombres, dont les insensibilités aux contrôles de l'adversaire) : son état (PV, action en cours, instant de l'impact,
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
