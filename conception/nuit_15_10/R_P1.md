# R_P1 — Passe « raccords » (version 0.1.183)

Méthode : captures neuves de toutes les pages du lobby, de Héros, Coffres, Carnet, Atelier, Paramètres et Guide, en compte neuf puis avancé, à 1600×900
et 1280×720 (`tests/shot_p1.tscn`, variables `P1_STATE` et `P1_RES`, profil détourné ; chaque image regardée). L'outil écrit aussi une ligne `[débord]` par contrôle
visible hors de l'écran. Ce rapport s'appuie sur ces images (186) et sur les 56 tests `test_*` lancés en headless.

## Trouvé et corrigé

**Mise en page à 1280×720 (le gros morceau : le jeu n'était conçu que pour 1600×900)**
- En-tête des écrans à pages : six onglets de 150 px + titre de 340 px débordaient (bouton Fermer coupé, page entière décalée hors de l'écran pour Carnet, Paramètres, Atelier).
  `PageScreen._fit_header` : onglets et titre réduits sous 1500 px, **largeur du titre fixe** (les onglets sautaient de 17 px d'une page à l'autre), sous-titre abrégé (infobulle complète).
- Héros > Équipement (grille de 9 colonnes, poupée de 78 px : bas de page coupé, panneau de droite à 1468 px), Héros > Cartes, Carnet > Collection et Registre, Atelier >
  Armurerie et Forge, Coffres > Roulette (liste des gains de 850 px de haut) : colonnes, cases et panneaux réduits, listes qui défilent. Plus aucun `[débord]`.
- Lobby : menu et panneau central remontés (150 px) quand la fenêtre est basse (le panneau de zone passait sous « Paramètres » et « Quitter »), panneau qui laisse
  la place au pied de page, panneau de zone raccourci sous 1400 px.
- **Bug réel (aussi à 1600×900)** : après la page de la Tour, la page Duel gardait un panneau trop court, le bouton « S'inscrire » sortait du cadre
  (`_fit_scroll` ne remettait la taille du panneau à zéro que si la hauteur de la zone qui défile changeait).

**Textes**
- Jeu d'origine : formules et parchemins (« Enchant-Swift Song Lv3 », stat anglaise « Move SPD »), 98 tenues « Costume d'Eden L202 » → « Tenue n°202 » (`NamesFr.clean`),
  succès « Fléau d'Eden » → « Fléau des monstres », « catalogue / pièces / armes / coloris d'Eden » de l'éditeur d'adversaire. Test de non-régression qui lit le code (`test_p1`).
- Anglais : touches « Comma », « Delete », « Page Up »… (`Settings.event_label`), « Lv » → « niv. » (formules, forge, enchantements), « Preset » → « préréglage » partout.
- Vocabulaire : un seul mot par chose : préréglage (sorts et équipement), « Points de talent » (et non « de maîtrise ») dans la liste du Duel, « maîtrise » (et non
  « expertise »), coffre commun / réserve / sac (plus d'« inventaire »), « Coffre d'aura » (singulier comme « Coffre d'apparence »), « Entrer : Mine d'Andrew V » (plus de
  « dans Mine… »), « Bats le boss de la zone … ». Pluriels : plus un seul « objet(s) », « victoire(s) », « point(s) »… (`GearPower.plural`, 0 et 1 au singulier), « 2 400 insignes »
  séparés comme partout dans le pied du lobby (« 1 insigne », « 1 cristal »).
- Page Défi de maîtrise : « 15 octobre » (et non 2026-10-15), section « Lancer avec » (les trois classes étaient des boutons sans titre). Battle royale : la première puce répétait le sous-titre.
- Activités verrouillées : la carte dit comment l'ouvrir (« 🔒 Gagne l'époque II ») au lieu de n'être qu'un peu plus sombre ; badge ★ de la roulette caché tant que Coffres est verrouillé.

**Boutons manquants (puits d'E5)**
- Coffres > **Boutique** : un coffre d'apparence rare / mythique / légendaire, d'aura rare / légendaire par ligne, solde d'insignes, « n restants cette semaine », « Reviens lundi »,
  « Collection complète », bouton grisé avec « Il te manque N insignes ». Le coffre rejoint « Tes coffres ».
- Héros > Classe : **Leçon · 200 insignes · 3 restantes** à droite de la barre de maîtrise, seulement pour une classe en retard et hors run.

## Décisions
- Cinq colonnes de plus à 1280 plutôt qu'un second gabarit complet : un seuil à 1500 px de large / 840 px de haut, jamais de mise à l'échelle.
- Famille d'inventaire en icônes seules à 1280 (infobulle = nom) : « Arm » / « Arm » étaient ambigus.
- L'onglet « Aide » de la pause n'existe plus : P3 / U9 en ont fait le bouton « ? Aide » qui ouvre le Guide ; rien à faire.
- Mode dev (F10, éditeur d'objets) : ses chaînes « Niveau d'Eden » restent (outil du développeur, hors joueur).

## Tests
56 `test_*.tscn` headless : tout passe sauf `test_e6` (équilibrage d'E6 en cours : « 1re victoire d'époque I » 13 runs, légendaire d'un coffre niveau 90) et `test_p2` (« apparence d'arme changée, le modèle
est rechargé », passe P2 en cours). `test_nav_screens` entièrement vert (Boutique et leçon atteignables à la manette). Les 4 « test_ » `aura`, `backs`, `fx`, `outfit` sont
des planches de capture sans verdict (ils ne se terminent pas en headless : exclus). Nouveau : `test_p1` (textes, boutique, leçon, en-tête). Pièges : le dossier de travail est partagé, des erreurs
de compilation passagères d'autres sessions (« Could not resolve class ArchivePages ») font échouer des tests au hasard : relancer ; deux scripts partagés du dossier temporaire ont été écrasés par
une autre session (`g.sh`) : donner un nom propre aux scripts d'outils.

## Reste
- Pause en jeu et bilans à 1280×720 non recapturés (U9 / P3) ; Paramètres > Touches : 24 lignes défilent (voulu).
- Noms de zones sans article (« Mine d'Andrew V », « Forêt de Delphes ») : certaines phrases passent par « la zone … » ; une table d'articles réglerait le reste.
- Les cartes d'activité verrouillées font parfois deux lignes (« Bats un premier duelliste de la Tour »).
