# Suivi du projet dans Notion

Le suivi d'Eden Slash vit dans un **hub Notion privé** (jamais partagé, jamais public), créé le 17/10/2026 à la version 0.1.255.

## Où est le hub

Page « Eden Slash » (liste des pages privées du compte Notion du joueur) :
<https://app.notion.com/p/3fcb320c1e538113b8ffc8d0fefd77dd>

Elle contient :
- la **vision en 10 lignes** et les liens vers les fichiers du dépôt (`CLAUDE.md`, `DESIGN.md`, `CHANGELOG.md`, `conception/nuit_15_10/INDEX.md`) ;
- la base **Lots** (112 lignes au départ) : Nom, Statut (À faire / En cours / Fait / Abandonné), Domaine (Aventure, Survivant, Battle royale, Autochess, Interface, Économie, Outils, Art), Version, Rapport (chemin du fichier `R_*.md` dans le dépôt), Date. Vues : « Par statut (tableau) », « Kanban », « Par domaine » ;
- la base **Retours à traiter** (33 lignes au départ) : Retour, Statut (À traiter / En cours / Fait / Écarté), Mode, Source (Note en jeu / Test / Idée), Détail. Vues : « Kanban par statut », « Par mode » ;
- la page **Prochaines étapes** : passe d'art (direction artistique, kit d'interface, illustrations, effets, mouvement et son, objets 3D), tests au ressenti (Aventure, Survivant, Battle royale, L'Échiquier), renommage Survie → Aventure (lot A9), lots restants du niveau de héros (H4b, H5, H6).

Le chemin du rapport (colonne Rapport) se lit à partir de la racine du dépôt. Lien complet :
`https://github.com/ZeqoAe/EdenSlash/blob/claude/optimistic-gauss-p2g2pq/<chemin>`.

## Comment le tenir à jour

**Règle : une ligne par lot terminé** dans la base Lots (Nom court, Statut « Fait », Domaine, Version, Rapport, Date). Une session qui pousse un lot peut le faire elle-même avec les outils Notion (`notion-create-pages` sur la base « Lots »). Un lot commencé se crée en « En cours » et passe en « Fait » à la livraison.

Pour « Retours à traiter » : une ligne par note du joueur (Alt + clic droit en jeu → `feedback/`), par idée ou par reste connu ; passer le statut à « Fait » quand la version qui le corrige est poussée.

## Ce qui est automatique et ce qui ne l'est pas

- **Rien n'est automatique.** Aucun script ne synchronise le dépôt et Notion : le hub est une copie de suivi, écrite à la main (par une session Claude) à partir de `CHANGELOG.md`, `STATUT_NUIT.md` et des rapports.
- Le dépôt reste la **source de vérité** (`CHANGELOG.md` pour les versions, `CLAUDE.md` pour l'état du jeu). En cas de désaccord, le dépôt gagne.
- Les notes en jeu (`feedback/`) ne sont pas dans git : le hub ne les voit que si une session les recopie dans « Retours à traiter » (une seule ligne les résume pour l'instant).
- Le lot **AC-I** (L'Échiquier : entrée et fin) est « En cours » dans le hub : son rapport existe mais n'était pas encore poussé au moment de l'import.
- Les versions antérieures à 0.1.132 ne sont pas importées.
