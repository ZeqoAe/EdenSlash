# Plan de la nuit du 15/10/2026 — instructions pour chaque session

Orchestrateur : la session « Orchestrateur nuit » (le joueur dort ; aucune question au joueur, trancher et documenter).
Sources : `A1_progression.md` (progression, lots A1-A6 / B1-B6 du §5.4) et `A2_interface.md` (interface, lots L1-L10 du §8).
Décision du joueur (15/10) : la Survie utilise l'équipement équipé au hub (session N1). Vision : toutes les activités servent
une quête commune (équipement optimal de toutes les classes, titres, cosmétiques) ; le jeu est poli comme un AAA : une idée
claire par écran, pas de texte superflu, pas de mention du jeu Eden d'origine (« était niveau 57 dans Eden »).

## Règles communes à toutes les sessions

1. Lire `CLAUDE.md`, puis la section de ce plan qui décrit ton lot, puis les passages de `A1_progression.md` / `A2_interface.md` cités.
2. **Dépôt partagé** : plusieurs sessions travaillent dans le même dossier, branche `claude/optimistic-gauss-p2g2pq`.
   - Interdits : `git stash`, `git reset`, `git checkout -- <fichier>`, `git clean`, réécrire un fichier entier qui n'est pas à toi.
     Modifier les fichiers des autres lots seulement par des éditions ciblées (Edit), jamais d'écrasement.
   - Les fichiers de ton lot sont à toi. Un fichier d'un autre lot : seulement une retouche minimale indispensable, notée dans ton rapport.
   - Commit avec les chemins explicites (`git add <tes fichiers>` puis `git commit`), jamais `git add -A`. Ne pas committer
     `conception/nuit_15_10/captures/` ni les fichiers `.uid` d'outils temporaires ; committer les rapports `conception/nuit_15_10/*.md`.
   - Avant de pousser : `git pull --no-rebase`, puis `git push`. Le numéro de version est celui du fichier à ce moment +1
     (`game/scripts/core/version.gd`), plus une ligne dans `CHANGELOG.md`, citée dans le message de commit (« 0.1.N : … »).
     Message de commit terminé par la ligne `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
3. **Tests** : lancer les tests `game/tests/test_*.tscn` concernés (`Godot --headless --path game res://tests/<test>.tscn`, voir CLAUDE.md ; après un
   nouveau `class_name`, un `--import` d'abord) et corriger ce qui casse, même si ce n'est pas ta faute directe quand c'est lié à ton changement.
   Ajouter un test pour tout nouveau système. Mettre à jour `tests/test_nav_screens` pour tout écran créé.
4. **Textes joueur** : en français, courts, sans jargon de développeur, une phrase par écran au plus, jamais de pourcentage dans le texte
   permanent (mettre le détail dans une infobulle). Aucune mention du jeu Eden d'origine côté joueur (les données restent).
5. **Documentation** : mettre à jour `DESIGN.md` pour toute règle de jeu changée, et la section concernée de `CLAUDE.md` en 2-3 lignes
   (pas de roman : `CLAUDE.md` est déjà long).
6. **Relecture « dictée » avant de rendre** (obligatoire) : relire ton diff ligne à ligne ; chercher fautes de français, chaînes en
   anglais, valeurs magiques, doublons, cas limites (profil vide, compte neuf, 60 classes, manette) ; relancer les tests ;
   pour l'interface, refaire les captures (`--lobby-shot=…` etc., voir A2 §0) et les REGARDER (Read sur l'image) : texte coupé,
   chevauchement, alignement, lisibilité ; se demander à chaque écran « un AAA ferait-il ça ? ». Corriger puis relire encore une fois.
7. **Rapport** : `conception/nuit_15_10/R_<id du lot>.md` : ce qui est fait, décisions prises (et pourquoi), chiffres mesurés,
   ce qui reste, pièges. Court (une page).
8. Si tu es bloqué par la limite de session ou une erreur d'outil, ne pas inventer : ranger le travail (tests verts, commit des
   fichiers sûrs) et le dire dans le rapport.

## File d'attente

Deux chaînes qui touchent des fichiers différents (U = interface, E = économie/progression). N1 est déjà en cours (Survie avec équipement du hub).
Le statut à jour est dans `STATUT_NUIT.md`.

### Chaîne U — interface (ordre : U1, U9, U3, U4, U5, U6, U7, U8, U2, U10)

Les lots sont décrits dans `A2_interface.md` §7-§8 (fichiers exclusifs par lot) et la table de texte superflu §6. « U<n> » = « L<n> » de A2.
- **U1 = L1** socle des menus du lobby (pages d'activité qui défilent + bouton d'action épinglé, lignes à hauteur auto, pied de page, activités,
  Tour). Prend aussi le texte faux de `ui/activities.gd:17` (la Tour ne donne pas « Joaillerie, cristaux » : voir lot E1 qui lui en donne ; écrire le
  texte final d'après `core/tower.gd` une fois E1 poussé, sinon neutre).
- **U9 = L9** HUD, pause, bilans (nouveau `ui/results_panel.gd`). Attend que N1 ait poussé pour `core/world.gd`.
- **U3 = L3** choix de carte en un geste, coffres, roulette (`core/rewards.gd` : après E1).
- **U4 = L4** Héros. **U5 = L5** Atelier et marchand. **U6 = L6** infobulles (après N1). **U7 = L7** Carnet. **U8 = L8** Paramètres.
  **U2 = L2** entrée du jeu (inclut `core/tutorial.gd` : texte « Ce que tu gardes » à corriger d'après N1).
  **U10 = L10** noms français (`data/names_fr.json`).

### Chaîne E — économie et progression

D'après `A1_progression.md` §5. Principe de la quête commune : **insignes = acquérir** (Armurerie), **cristaux = optimiser** (Forge),
**fournitures** (parchemins, gemmes, formules) = pipeline de coffres de matières généré au niveau de l'activité ; chaque activité a un rôle unique.

- **E1** = A4 + A1(a) + A2 : (a) coffres « forge » et « joaillier » au butin des Donjons, Ruée, Siège et Tour au niveau de l'activité (débloque +N / enchantements
  sur les pièces de niveau > 40) ; (b) recaler les cristaux (`Forge.GOLD_PER_CRYSTAL`, sources Donjons / Ruée / Siège / démontage) : une pièce à +10 = ~4 à 5 clears
  Mythiques ; (c) corriger les textes et compteurs faux côté `core/` (compteur 154 de `completion.gd:45` calculé, coffre « trophée » mort). Les textes de
  `ui/activities.gd` et `core/tutorial.gd` sont à U1 / U2, ne pas y toucher. Ne PAS toucher `run_director.gd` (N1 / E4).
- **E2** = A3 + A5 + B4 : maîtrise pour Arènes / Gantelet / Panthéon / Royale / Duel libre ; insignes JcJ plafonnés (1re victoire du jour / par rang) pour rester
  en dessous de la Survie à l'heure ; plan garanti au 1er clear de chaque difficulté, fabrication de l'arme et des bijoux, Siège Normal à 0 % de PE ;
  panoplie des Esprits universelle (pièces dans `Profile.seen_gear`, arme du Champion de n'importe quel type, éveil qui renforce vraiment le bonus 6 pièces).
- **E3** = B1 + B2 : **profils de stats** pour les 60 classes (règle sur `dmg_type` + attribut le plus fort, 5 à 8 profils, `data/class_profiles.json`), note pondérée
  `Items.rating(item, profil)`, bouton « Équiper le meilleur » (par classe, option « garder mes choix »), « Appliquer à la famille », puis **Registre de
  l'équipement** dans le Carnet (par classe : PE vs attendue, arme du bon type, archétype x/6, Esprits x/6, nombre de +10, gemmes ; ligne « il manque → activité X »).
  À faire après U4 et U7 pour les pages (ou en retouches minimales).
- **E4** = A6 + B3 + A1(b) : emplacement « dos » (capes) dans les coffres d'emplacement ; les 17 types d'arme (découverte automatique des armes de même palier des
  autres types à l'Armurerie, ou arme au choix en Ruée / Siège) ; en Survie fournitures au niveau de la carte d'époque et non plafonnées à 35. Après N1.
- **E5** = B5 + B6 : barème unique d'insignes par heure, puits supplémentaires quand la collection est complète ; pont vers la maîtrise des 60 classes.
- **E6** (dernier) : passe d'équilibrage globale par mesure (journal de run, `tools/journal_report.py`, simulations).

## Après la file d'attente : ne jamais s'arrêter

Consigne du joueur : **ne PAS écrire de rapport du matin tant qu'il ne le demande pas.** Quand tous les lots ci-dessus sont faits, l'orchestrateur lance
des passes de peaufinage, chacune par une session dédiée : relecture de chaque écran sur captures neuves, optimisation (performances du HUD et des
pages, temps de chargement), cohérence des textes, équilibrage par mesure (journal, simulations), tests de non-régression complets, nettoyage du code
mort et de la documentation. Chaque passe écrit un `R_<id>.md` court ; la suivante part de ces rapports.
