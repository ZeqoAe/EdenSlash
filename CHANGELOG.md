# Versions d'Eden Slash

Le numéro est affiché en bas à droite de tous les écrans du jeu. Si ce numéro n'est pas
le même que la dernière ligne ci-dessous, ta copie n'est pas à jour (`Mettre_a_jour.bat`).

Règle : **à chaque envoi sur GitHub, +1 sur le dernier chiffre** (0.1.7 → 0.1.8…),
dans `game/scripts/core/version.gd` et ici.

| Version | Contenu | Fait par |
|---|---|---|
| 0.1.0 | Premier prototype : run de 10 min, rage, boss, héritage roguelite | session locale |
| 0.1.1 | Cartes de niveau : sélection puis bouton Valider | session cloud |
| 0.1.2 | Paramètres : modes de jeu, touches, affichage, combat automatique | session cloud |
| 0.1.3 | Build roguelite : combo d'auto-attaque, procs, sets, cartes à rareté, plafond niveau 15 | session cloud |
| 0.1.4 | Interface : thème or sur indigo, orbes vie / XP, buffs et debuffs, objectifs (Tab) | session cloud |
| 0.1.5 | Classes (Guerrier, Voleur, Chasseur, Clerc, Magicien), biomes, combos de classe, grimoire | session locale |
| 0.1.6 | Icônes poison, régénération, invisibilité, évasion | session cloud |
| 0.1.7 | Numéro de version à l'écran, CHANGELOG, `Envoyer.bat` / `Mettre_a_jour.bat` | session cloud |
| 0.1.8 | Sorts complets (14 à 15 par classe), talents, artisanat, fournitures gardées à l'extraction | session locale |
| 0.1.9 | Icônes des effets de classe (Mur du titan, Ange gardien…) reprises du sort d'Eden qui les donne | session cloud |
| 0.1.10 | Écrans plein écran : Personnage (3 préréglages par classe, coffre commun, aperçu 3D), menu pause, village à 4 métiers (réforge, conversion, fusion de gemmes) | session cloud |
| 0.1.11 | Archive (collection or / violet / orange, bijoux, trophées, apparences d'armes), rareté Légendaire, collier / bague / trophée, carte d'objet au survol, page Infos (stats et dégâts), lancement de run Équipement → Expertise (7 certificats) | session cloud |
| 0.1.12 | Écran titre (maps 3D qui défilent, Jouer : continuer / charger / nouvelle partie sur 3 sauvegardes) et nouveau menu principal (menu à icônes, sous-menus, héros dans la map de la zone) | session cloud |
| 0.1.13 | Mettre_a_jour.bat met de côté les fichiers modifiés par l'éditeur Godot (ils bloquaient la mise à jour) | session cloud |
| 0.1.14 | Graphismes modernisés : herbe 3D animée, sol en relief sans motif répété, éclairage stylisé des personnages et du décor, occlusion ambiante, effets d'attaque lumineux et fondus, réglage Qualité graphique | session cloud |
| 0.1.15 | Progression : on démarre Guerrier, classes débloquées par missions, 4 sorts au départ puis débloqués par la maîtrise, parcours de maîtrise ; plateau de certificats 1-2-1-2-1 à synergies de couleurs ; talents au survol | session cloud |
| 0.1.16 | Les 60 classes d'Eden jouables (14 vertes + 40 orange, ~480 sorts convertis, sorts partagés jouables d'emblée, 11 nouvelles armes, talents), sélecteur de classe, modèles modulaires ; 3 880 objets d'Eden comme identité du butin ; encyclopédie + mode dev dans l'archive ; 127 costumes en skins (butin des boss) | session locale |
| 0.1.17 | 2 nouveaux biomes (Delphi Forest, Blackflame Peak) et leurs monstres, un vrai boss nommé d'Eden par zone avec sa salle (piliers, lave, marais, givre, cristaux) et ses mécaniques (renforts, illusions, totems-bouclier, météores, ondes, rayons, tourbillon, compagnon) ; décors et maisons agrandis par IA (Real-ESRGAN) | session locale |
| 0.1.18 | Nouvel écran Inventaire (maquette : raccourcis à gauche, héros entouré de son équipement, classe affichée, set, 5 stats + Détail, inventaire illimité avec familles, recherche et tri, fiche avec Équiper / Améliorer / Démonter) ; correctif des animations des héros (corps commun) ; textures des effets agrandies par IA | session locale |
| 0.1.19 | Import complet de l'archive d'Eden : 3 881 objets aux 6 raretés d'Eden (mythiques et légendaires seulement sur les boss ou à fabriquer, jets aléatoires du commun à l'épique), 204 sets avec leurs vrais effets, passifs des armes, archive des trésors façon Eden (2 182 entrées), fabrication chez le forgeron, 278 cosmétiques (tenues, chapeaux, ailes et dos) | session locale |
| 0.1.20 | Toute l'archive d'Eden : 10 554 entrées dans ses catégories (apparences, montures, familiers, boîte arcanique, autres objets), lecture corrigée de la table des objets (5 947 équipements), niveau d'Eden affiché et chronologie des zones, auras (pierres étoilées et pierres de lune avec leur effet), 652 apparences d'armes, encyclopédie filtrable et regroupée par set et niveau | session locale |
| 0.1.21 | Consignes pour la session cloud (A_FAIRE_SESSION_CLOUD.md) : refonte des menus (Collection seule, apparences dans la page Classe), vrai mode dev, trophées à buffs sous condition, zones / monnaies / coffres façon Megabonk ; aucun changement de jeu | session locale |
| 0.1.22 | Menus refaits : menu principal à 5 entrées (Jouer, Héros, Collection, Paramètres, Quitter), écran Héros unique (équipement, talents, apparence avec tenues / auras / armes, grimoire, classe, aide « ? »), Collection sans onglets, lancement de run en un clic, menu pause Run / Héros / Aide | session cloud |
| 0.1.23 | Vrai mode dev : écran à part (F10, activé dans Paramètres > Caméra & interface) avec tout le catalogue et ses filtres (ajout ×1 / ×5, rareté et puissance au choix), ressources, progression (avec confirmation) et actions en run (niveau, invincible, élite, boss, coffre, rage, donjon) ; l'encyclopédie quitte la Collection | session cloud |
