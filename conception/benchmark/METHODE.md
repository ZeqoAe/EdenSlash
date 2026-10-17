# Étude comparative des meilleurs jeux du genre (17/10/2026)

Décision du joueur : pour chaque mode, **viser le meilleur du genre** : s'inspirer de ce qui se fait de mieux (HUD, UI / UX, profondeur
des règles, détails de confort pour le joueur), l'adapter à notre identité (DA « autocollant manga » très colorée, `conception/art/BIBLE.md`)
et cloner ce qui fait la qualité des références, pas les copier. Un mode « fonctionnel » ne suffit pas : il doit tenir la comparaison.

## Règles
1. **Images de jeux concurrents** : autorisées pour l'ANALYSE interne (captures publiques : pages de boutique, kits de presse, wikis,
   vidéos, articles). Elles sont stockées **hors du dépôt** dans `C:\AI\benchmark_refs\<mode>\` (le dépôt GitHub est PUBLIC : ne commite JAMAIS
   une image, une icône, un son ou un texte tiers). Le dépôt ne reçoit que du texte d'analyse original (descriptions, tableaux, croquis
   maison). Rien de tiers ne rentre dans le jeu : on s'inspire des mécanismes, de la structure d'écran et de la sensation, pas des assets.
2. **Méthode** (chaque étude) : (a) choisir 3 à 6 références pertinentes (les meilleures du genre, de styles différents, y compris
   mobiles et indépendantes) ; (b) pour chacune, relever par écran : structure du HUD et de l'interface, hiérarchie d'information, retours
   (son, mouvement, particules), flux d'une partie, profondeur des règles, détails de confort (raccourcis, annulation, infobulles, aides
   à la décision, accessibilité, réglages, reprise, vitesse accélérée, rejouabilité, rythme des récompenses) ; (c) capturer NOS écrans
   équivalents (`tests/shot_*.tscn` sur une copie propre de HEAD, 1600×900) et les comparer **un à un** ; (d) tableau d'écarts : ce qu'ils
   font mieux, ce qu'on fait mieux, ce qui manque ; (e) backlog priorisé (P0 : sans ça le mode fait « prototype » ; P1 : ce qui fait la
   qualité ; P2 : finitions et confort), avec une estimation de taille et les fichiers concernés ; (f) spécification « version 2 » du mode
   (déroulé, écrans, retours, règles) dans notre DA.
3. **Honnêteté** : ne rien affirmer sur un jeu qu'on n'a pas pu vérifier ; citer la source (page, vidéo, date) ; marquer « non vérifié ».
4. **Livrables par mode** : `conception/benchmark/<MODE>.md` (analyse + tableau d'écarts + backlog + spec v2, ≈ 4-6 pages, tableaux) et,
   hors dépôt, le dossier d'images. Pas de code dans cette phase.
5. Après l'étude : lots d'implémentation numérotés par mode (équipe dédiée), toujours avec la bible de style (`BIBLE.md` v2) et le socle
   d'interface `UiTheme` v2 / `UiFeel`, tests, captures regardées, revue.

## Références proposées (à confirmer / compléter par chaque étude)
| Mode | Références |
|---|---|
| L'Échiquier (autochess) | Teamfight Tactics (Riot), Dota Underlords, Hearthstone Battlegrounds, Super Auto Pets, Auto Chess, TFT mobile |
| Battle royale | Fortnite, Apex Legends, Super Animal Royale, Spellbreak, Brawl Stars (Showdown), Realm Royale |
| Survivant | Vampire Survivors, Brotato, Halls of Torment, Megabonk, Risk of Rain 2, Hades (cartes de run) |
| Aventure / progression / butin | **MMORPG et RPG d'action en ligne** : World of Warcraft, Final Fantasy XIV, Lost Ark, Guild Wars 2, Black Desert, MapleStory, Elder Scrolls Online ; ARPG : Diablo IV, Path of Exile ; Genshin Impact, Wuthering Waves, Tower of Fantasy |
| Donjons / Tour / Ruée / Siège | **MMORPG** : WoW (donjons, raids, Mythic+), FFXIV (donjons, raids, Deep Dungeon, Duty Finder), Lost Ark (abysses, raids), Guild Wars 2 (donjons, fractales), Elder Scrolls Online (arènes, épreuves) ; Genshin (domaines, Abîme spiralé), Hades |
| Duel / Ligue / Panthéon / Arènes | Brawlhalla, Street Fighter 6 (classement), LoL Arena (atouts, duos), Smash, Rocket League (rangs), Hearthstone (ladder) |
| Quêtes / méta-progression | **MMORPG** : FFXIV (quêtes quotidiennes, Rôles, Journal), WoW (succès, quotidiennes, réputations), Lost Ark (tâches quotidiennes, passeport), GW2 (succès, récompenses quotidiennes) ; Genshin (commissions), Fortnite (passe), Hades (Miroir) |
| Hub / lobby / menus / HUD | **MMORPG** : WoW (capitale, barres d'action, journal, carte), FFXIV (HUD modulable, menus), Lost Ark, GW2, MapleStory, Black Desert (menu principal) ; Genshin, Honkai Star Rail, Persona 5, Hades, Brawl Stars |
| Héros / équipement / forge | **MMORPG** : WoW (personnage, talents, enchantements, transmogrification, sertissage), FFXIV (matérias, artisanat, ensembles), Lost Ark (transcendance, gemmes, renforcement), Black Desert (renforcement), MapleStory (potentiel, étoiles) ; Diablo IV, Path of Exile, Genshin (artefacts) |

**Précision du joueur (17/10)** : pour les modes de progression (Aventure, Donjons, Tour, Ruée, Siège, Quêtes, hub, Héros / équipement / forge),
s'inspirer des **MMORPG** (structure des écrans, profondeur des systèmes, confort), **sans** le côté corvée : pas de quêtes obligatoires, pas de
« bash » de monstres inutile (décision du 16/10 : le farm doit être intéressant par ses activités et son système de progression).
