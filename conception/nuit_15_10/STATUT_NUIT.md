# Statut de la nuit (tenu à jour par l'orchestrateur)

| Lot | Exécutant | Statut | Version |
|---|---|---|---|
| N1 Survie + équipement du hub | session n1 | fait | 0.1.170 |
| A1 audit progression, A2 audit interface | sessions a1, a2 | faits | — |
| E1 matières et cristaux | session e1 | fait | 0.1.165 |
| U7 Carnet | session u7 | fait | 0.1.166 |
| U8 Paramètres | session u8 | fait | 0.1.167 |
| U10 noms français | session u10 | fait | 0.1.168 |
| U1 menus du lobby | session u1 | fait | 0.1.169 |
| U9 HUD, pause, bilans | sous-agent | en cours | — |
| U3 cartes, coffres, roulette | sous-agent | fait | 0.1.174 |
| U4 Héros | sous-agent | fait | 0.1.175 |
| U5 Atelier, marchand | sous-agent | fait | 0.1.176 |
| U6 infobulles | sous-agent | fait | 0.1.172 |
| U2 entrée du jeu, Guide | sous-agent | fait | 0.1.173 |
| E2 JcJ, plans, Esprits | sous-agent | fait | 0.1.171 |
| E4 capes, 17 armes, fournitures | sous-agent (opus) | en cours | — |
| E3 profils de classe, meilleur équipement, Registre | sous-agent | fait | 0.1.178 |
| E5 insignes/heure, maîtrise 60 classes | sous-agent | fait | 0.1.177 |
| Passes de peaufinage | — | après la file | — |
| S1 Survivant : socle et crochets (`conception/survivor/R_S1.md`) | sous-agent | fait | 0.1.194 |
| S4 Survivant : déroulé de la run (`conception/survivor/R_S4.md`) | sous-agent | fait | 0.1.197 |
| S2 Survivant : pièces et arme (`conception/survivor/R_S2.md`) | sous-agent | fait | 0.1.195 |
| S3 Survivant : cartes (`conception/survivor/R_S3.md`) | sous-agent | fait | 0.1.198 |
| S5 Survivant : interface en run (`conception/survivor/R_S5.md`) | sous-agent | fait | 0.1.203 |
| S6 Survivant : fin de run, coffres d'apparence seulement (`conception/survivor/R_S6.md`) | sous-agent | fait | 0.1.204 |
| S7 Survivant : équilibrage par mesures (`conception/survivor/R_S7.md`) | sous-agent | fait | 0.1.209 |
| S8 Survivant : paliers I-V, mode ouvert à tous, documentation (`conception/survivor/R_S8.md`) | sous-agent | fait | 0.1.210 |

Note : le lancement de sessions séparées est refusé quand le tour vient d'un événement automatique ; l'orchestrateur utilise alors des sous-agents.

## Plan de l'orchestrateur (le joueur est parti pour des heures : lancer la suite sans s'arrêter, pas de rapport tant qu'il ne le demande pas)

Fait depuis le tableau : U9 0.1.180, E4 0.1.179, P1 0.1.183, P2 0.1.186, P3 0.1.181, P4 0.1.185, P5 0.1.184, P6 0.1.188, P8 0.1.187, P9 0.1.189,
P10 0.1.190, P11 0.1.192, P12 0.1.191, P13 0.1.193, M5 0.1.196 (quêtes).
En cours : S3 (cartes Survivant), S4 (déroulé de la run Survivant), P14 (suite de tests verte), P15 (spawn varié, scaling des monstres),
M1 (Battle royale), M2 (bibliothèque de boss + Donjons à la carte), P16 (bugs skins : aura, arme).
File d'attente, dans l'ordre :
1. S7 équilibrage par mesures · S8 paliers (le paramètre `tier` de `SurvivorRewards.settle` / `board` est prêt), doc, mode visible (lever `Survivor.READY`). S1 à S6 faits.
2. M3 La Tour (après M2) : un élite au minimum par étage, étages de boss (bibliothèque), étages « Ombres » (IA qui joue une classe), vagues moins ennuyeuses.
3. M6 Ruée des boss + Siège (après M2) : bibliothèque de boss, lisibilité de la difficulté (jauge de PE), équilibre.
4. M7 Arènes (duel, duo, trio) et Gantelet : polissage et idées.
5. Nettoyage de CLAUDE.md / DESIGN.md, passe de régression complète (tools/run_tests.py de P14), nouvelles notes feedback/ (suivi : feedback/_SUIVI.md).
6. Restes connus : image de la carte Quêtes (session locale), tools/reparer_cache_uid.py à lancer au calme, pas d'annonce quand un coffre du menu accomplit une quête.

## Mise à jour finale (0.1.213)
Tout le plan est poussé : S3 0.1.198 · P14 0.1.199 · P16 0.1.200 · M1 0.1.201 · M2 0.1.202 · S5 0.1.203 · S6 0.1.204 · M7 0.1.205 · P15 0.1.206 ·
M3 0.1.207 · M6 0.1.208 · S7 0.1.209 · S8 0.1.210 (Survivant visible) · M8 0.1.211 · P17 0.1.212 (doc) · P18 0.1.213 (régression : 80/82 verts puis tous verts).
Restes pour le joueur : valider l'équilibrage au ressenti (Survie époque I : temps pour tuer « moyen » 26-55 % plus lent qu'en P11 ; Survivant palier II trop facile
au pilote, débutant un peu fort ; Tour : bruit ±40 %, boss 100/150/200 hors borne entre classes) ; illustrations dédiées (Quêtes, Survivant) à demander à la session locale ;
tools/reparer_cache_uid.py à lancer au calme ; code mort `Profile.end_run_extract`.
