# L'Échiquier face aux meilleurs du genre : étude comparative (BM-AUTO, 17/10/2026)

Mandat du joueur : « un clone des jeux du genre, en tirant parti de ce qui se fait de mieux, adapté à nous ; comparer nos écrans, voir
nos points faibles (HUD, UI / UX, profondeur, confort), le tout dans notre nouvelle DA ». Méthode : `METHODE.md`. DA : `art/BIBLE.md` v2.
Notre mode : `autochess/SPEC.md`, rapports `R_AC_*.md` (mesures : `R_AC_J.md`). Croquis maison : `autochess_maquettes/` (HTML, ouvrir dans
un navigateur). Images de référence et nos captures : **hors dépôt**, `C:\AI\benchmark_refs\autochess\` (`tft`, `underlords`,
`hs_battlegrounds`, `super_auto_pets`, `auto_chess`, `eden_slash_nous`). Aucun texte, image ou son tiers n'est repris ici : on décrit.

**Verdict en une phrase** : les règles et les outils de mesure de l'Échiquier sont au niveau d'un TFT simplifié (économie, réserve
partagée, atouts, objets, 15 traits, 7 IA mesurées, statistiques de combat, reprise de partie) ; ce qui le fait encore « prototype » est
**la sensation** (aucune célébration d'achat, de fusion, de niveau, d'élimination ; sons presque absents), **l'aide à la décision**
(traits cachés par la fiche, pas de taux de boutique, pas de lien visuel unité ↔ trait ↔ boutique), **le tempo** (bilan de manche
bloquant, partie de 30 min sans format court, pas de « passer le combat ») et **la DA** (encore l'ancien thème bleu nuit et filet doré).

---

## 1. Sources et ce qui a été vérifié

| Référence | Ce qu'on a regardé (images dans `C:\AI\benchmark_refs\autochess\`) | Sources écrites |
|---|---|---|
| Teamfight Tactics (Riot, PC + mobile) | 5 captures de la fiche App Store FR (2026) : début de partie, plateau 2-5, carrousel 2-4, combat 2-6, plateau 4-5 | notes de patch officielles 9.20, 10.25, 11.11, 13.5, 14.22 (wiki LoL / site TFT) ; guides Mobalytics (raccourcis) ; Upcomer / Dot Esports (atouts) ; page d'aide Riot (mode Choncc) |
| Dota Underlords (Valve) | 5 captures Steam (combat, boutique, récompenses, Underlords) | Inven Global (refonte de l'interface 06/2019, Big Update) ; wiki Fandom Underlords (Underlords, objets) |
| Hearthstone Battlegrounds (Blizzard) | 7 images de l'annonce officielle (bannière « Recrutement », choix du héros, statistiques bonus) | annonce Blizzard « Introducing Hearthstone Battlegrounds » ; wiki.gg Battlegrounds (classement, survol) |
| Super Auto Pets (Team Wood) | 5 captures Steam FR (boutique, combat, plage) | fiche Steam ; Pocket Gamer (critique) |
| Auto Chess (Dragonest / Longyuan) | 4 captures Steam (saison 39, combat) | fiche Steam |
| **Eden Slash** (0.1.256, HEAD propre) | 28 captures `tests/shot_ac.tscn` (1280×720 et 1600×900) + `shot_ac_fight.tscn` | `SPEC.md`, `R_AC_*.md`, code `game/scripts/ui/autochess_*.gd` |

Limites : aucune partie jouée des références (pas de client installé, pas de compte) ; les comportements fins viennent des notes de
patch, wikis et captures. **Non vérifié** = signalé comme tel. Notre passe de capture en 1600×900 reste à l'étape 1-1 (la boucle du
pilote de `shot_ac.gd` n'atteint pas 3-1 au second tour de résolution) : les vues de combat, bilan et fin sont lues en 1280×720.

---

## 2. Ce qui fait la qualité de chaque référence

### Teamfight Tactics : le standard (profondeur + lisibilité)
- **HUD de combat presque vide** (captures mobiles) : en haut une frise d'étape compacte (étape, pictos des manches, minuteur et barre
  de temps), à droite une colonne de portraits avec PV seulement, en bas à gauche un gros bouton rond « XP » (coût, niveau, progression
  « 4/36 »). Le plateau occupe 85 % de l'écran ; le nombre d'unités posées / permises est **peint sur le sol** du plateau (« 5/5 »).
- **Barres d'unité** : barre de PV + mana, étoiles à gauche, **icônes des objets portés juste sous la barre** ; pas de nom au-dessus des
  unités en combat. Les chiffres de dégâts sont petits et colorés par type.
- **Boutique** : coût = couleur du cadre (gris, vert, bleu, violet, or) + chiffre ; **étoile dans le coin quand l'achat fait monter une
  unité d'étoile** (patch 9.20, vérifié) ; verrou ; actualiser (D) ; XP (F). Taux de la boutique par niveau affichés près du niveau
  (**non vérifié** pour la version actuelle ; Underlords le met dans l'infobulle du niveau, vérifié).
- **Raccourcis** (vérifiés, Mobalytics / wiki) : D actualise, F achète l'XP, E vend l'unité survolée, W envoie l'unité survolée du banc au
  plateau ou l'inverse, Q / R passent au plateau du joueur précédent / suivant, Espace revient au sien.
- **Confort** : banc plein au retour du carrousel → l'unité en trop est vendue en fin de préparation **avec un avertissement et un
  surlignage rouge** (10.25, vérifié) ; statut de chaque joueur pendant les combats (en cours, perdu, gagné) dans la colonne de droite
  (9.20, vérifié) ; description complète des objets en jeu (11.11) ; **planificateur d'équipe** (13.5, codes partagés en 14.22, vérifiés) :
  les unités prévues sont marquées dans la boutique.
- **Profondeur** : ~60 unités par saison, ~25 traits, composants → objets, atouts à 3 raretés (Argent / Or / Prismatique) à 2-1, 3-2,
  4-2 avec relance (règles de relance variables selon les saisons, vérifié), carrousel où **les plus bas en PV choisissent d'abord**
  (comeback), séries de victoires / défaites, réserve partagée, saisons qui renouvellent tout (~4 mois), classement, modes rapides et
  saisonniers (Double Up, mode « Choncc » avec unité 4-5 offerte au départ, vérifié 2026).
- **Mobile** : même jeu, boutique en tiroir (bouton), gros boutons ronds, plateau lisible en petit.

### Dota Underlords : la lisibilité de la boutique
- Carte de boutique = **figurine 3D éclairée sur socle**, nom coloré par rareté, **pastille de coût dorée**, 2 ou 3 tuiles d'alliance
  colorées sous le nom, **progression ★ / ★★ / ★★★ en miniature** sous la carte quand on possède déjà des copies (capture Steam).
- Interface « PC » qui laisse voir le plateau pendant les achats ; fusion de boutique « plus brillante et évidente » ; clic hors de la
  boutique la ferme ; liste des raccourcis dans les options (Inven, vérifié).
- Barres de combat : petit portrait + PV vert (allié) / rouge (ennemi) + mana bleue + anneau d'étoiles.
- **Underlords** : un commandant qui combat avec le plateau, choisi en cours de partie (Standard : manche 10 ; « Knockout », mode court :
  manche 2 ; vérifié wiki) ; objets **à choisir 1 parmi 3** par palier, sans recettes (vérifié) ; mode court « Knockout » ; passe de
  saison en carte de quartier (« City Crawl », **non vérifié** dans le détail).

### Hearthstone Battlegrounds : le tempo et la mise en scène
- Partie courte (≈ 15-20 min, **non vérifié** chiffré), **bannières de phase** énormes (« Recrutement » sur ruban, rayons, chope) : on
  sait toujours dans quelle phase on est.
- Tour de taverne simple : acheter 3, vendre 1, actualiser 1, **geler gratuit**, monter de palier (moins cher chaque tour où l'on
  attend) ; triple → carte qui fait **découvrir** une unité du palier suivant (récompense immédiate et visible).
- **Héros à pouvoir** (1 parmi 2-4) : chaque partie commence par une identité ; « Buddies », atouts (« trinkets »), quêtes selon les saisons.
- **Classement à gauche** : survol d'un joueur = palier de taverne, nombre d'unités de sa tribu principale, **résumé de ses 2 derniers
  combats** ; **prochain adversaire entouré de rouge et décalé** (wiki.gg, vérifié).
- Récompenses de saison : statistiques personnelles en tuiles (triples, top 4, dégâts en un tour…), émoticônes visuelles.

### Super Auto Pets : la DA la plus proche de la nôtre, le confort du solo
- **Autocollants contourés** (épais contour noir, aplats, bulles « comics ») : c'est notre BIBLE presque mot pour mot. HUD en 4 tuiles
  blanches contourées en haut à gauche (or, vies, trophées « 0/10 », tour), pancartes en bois « Magasin » / « Combat ».
- Fiche au survol en **une phrase avec icônes en ligne** (« Achat → +1 d'attaque [icône] et +1 de santé [icône] pour un ami au hasard ») ;
  pastilles de stats (attaque grise, PV cœur rouge) **sous chaque unité**, niveau « Lvl 2 » en étiquette au-dessus ;
  **flèches blanches** au-dessus des cases où l'on peut poser (glisser-déposer guidé).
- **Combat rejouable** : barre Rembobiner · Pause · Jeu automatique · Rapide · Passer (capture Steam FR).
- Mode « arène » **asynchrone sans minuteur** (fiche Steam, vérifié) contre des équipes « fantômes » d'autres joueurs ; 5 vies, 10 victoires.
- Rejouabilité par **« packs »** d'animaux (règles de la semaine, packs personnalisés) : variété sans complexité.

### Auto Chess (Dragonest) : la densité d'information
- Colonne gauche des 8 joueurs (niveau, or, PV) ; colonne droite **compteur de dégâts** en direct ; bouton rond « EXP » (4 or, niveau,
  « 64/64 ») et gros bouton boutique avec l'or ; en haut : manche, adversaire, minuteur, pièces posées « 10/16 ». Saisons numérotées (S39).

---

## 3. Écarts écran par écran (nous, captures 0.1.256, contre elles)

| Écran | Nous (observé) | Elles font mieux | On fait mieux | Écart |
|---|---|---|---|---|
| **Préparation : cadre** | 3 colonnes fixes (traits 230 px à gauche, stratèges 230 px à droite) + pied de 120 px : le plateau n'a que ≈ 55 % de l'écran ; panneaux bleu nuit à filet doré, titres serif (ancienne DA) | TFT : plateau ≈ 85 %, panneaux réduits au bord, compteur d'unités peint au sol | frise d'étape lisible (● ▲ ◆ gardien), minuteur + barre | P0 : DA v2 + resserrer les colonnes |
| **Traits** | colonne « Traits » remplacée par la fiche dès qu'on vise une unité (captures 1, 3, 4 : les traits disparaissent au moment où on en a besoin) ; seuils « 2 4 6 » en chiffres gris | TFT : traits toujours visibles, fiche à part ; survol d'un trait → unités concernées (**non vérifié**) | pastille hexagonale du palier, actifs d'abord | **P0** : fiche en infobulle flottante, traits fixes |
| **Boutique** | 5 cartes : icône de classe, nom, 2 traits en texte, ◇◇◇ copies, coût ; carte qui donne une ★ cerclée d'or ; touche dans le coin | Underlords : figurine, coût en pastille, tuiles de trait colorées ; TFT : étoile d'amélioration ; marques du planificateur | copies possédées en pastilles (TFT n'en a pas, **non vérifié**) | P0 : traits en tuiles couleur + marque « trait qui monte » ; P1 : figurine / buste |
| **Économie** | or + 5 pastilles d'intérêts (bonne idée), revenu détaillé dans le bandeau de manche | TFT / Underlords : taux de boutique au niveau ; série affichée (flamme) près de l'or | pastilles d'intérêts lisibles d'un coup d'œil | P0 : taux en barre de 5 couleurs (sans % ; chiffres en infobulle) + série |
| **Niveau / XP** | « Niveau 6 », barre fine, « 4 / 36 XP », bouton « Acheter de l'XP · 4 » | TFT : gros bouton rond XP au pouce | texte clair | P2 : bouton rond autocollant |
| **Stratèges** | 8 lignes : rang, icône de classe, nom, barre PV, frise des 6 dernières manches ; adversaire de la manche en rouge en combat ; clic = voir son plateau | HS : **prochain adversaire signalé**, survol = palier + tribu + 2 derniers combats ; TFT : statut en direct, Q / R | frise des 6 manches (personne ne l'a aussi lisible) | P1 : survol riche (niveau, 2 traits, valeur d'équipe, 2 derniers combats) + adversaire probable |
| **Unité tenue** | la boutique devient « Vendre · +1 or · touche E » (bien) ; aucune case surlignée, aucun aperçu des traits | SAP : flèches sur les cases valides ; TFT : avertissement rouge banc plein | prix de vente affiché | P0 : cases valides + aperçu « +1 Ombre » |
| **Combat : cadre** | barres d'équipe en haut (pastilles par unité, chrono, « Fureur »), compteur Dégâts / Subis / Soins / Boucliers à gauche, stratèges à droite, « Vitesse ×1 » | TFT : HUD minimal ; SAP : Pause · Rapide · **Passer** | compteur à 4 onglets en direct, barres d'équipe (TFT n'a pas les deux) | P1 : « Passer » ; P2 : compteur repliable par défaut |
| **Combat : plateau** | **un nom au-dessus de chaque unité** + barre + chiffres + effets de sorts très chargés : à 20 unités on ne lit plus rien (capture mêlée) ; barres rouges pour ses propres unités si on est le camp 1 (R_AC_V) | TFT / Underlords : pas de noms, barre + étoiles + **objets sous la barre**, couleur allié / ennemi stable | vrais héros qui esquivent, gardiens à mécaniques (unique au genre) | **P0** : noms retirés (survol seulement), objets sous la barre, couleur de camp fixe |
| **Bilan de manche** | fenêtre plein centre « Victoire · MVP · barres · Continuer (Entrée) » qui **retient la manche suivante jusqu'à 20 s** | TFT : bilan de dégâts consultable mais rien ne bloque ; HS : enchaînement direct | MVP et barres par camp (excellent) | **P0** : bandeau non bloquant 2,5 s + « Détail » facultatif |
| **Perte de PV** | texte « Défaite · −7 PV » | TFT / HS : les unités survivantes **frappent le stratège perdant** (projectiles, secousse, chiffre) | — | P1 : moment « coup au stratège » |
| **Atout** | 3 cartes bleu nuit, « Or » en texte, nom + une phrase, **aucune icône**, 60 % de vide ; Relancer, Voir le plateau | TFT : icône, cadre de rareté (argent, or, prisme), description courte, relance | phrase sans pourcentage (règle tenue) | **P0** : carte autocollante de rareté + icône du jeu |
| **Choix partagé** | 9 cartes en anneau (icône, nom, composant), ordre des stratèges en haut, « À toi ! 10 », « Pris par … » | TFT : vrai carrousel 3D (les tacticiens courent) ; ordre par PV (même règle) | lisible en un coup d'œil, manette | P2 : figurines sur l'anneau 3D derrière |
| **Fusion ★ / niveau / élimination** | toast « Niveau 7 : une place de plus » ; **fusion silencieuse** ; élimination d'un adversaire non annoncée | Underlords / TFT : effet et son de fusion, annonce d'élimination avec place ; HS : triple doré + carte « Découverte » | — | **P0** : trois moments manga (§5) |
| **Fin de partie** | « VICTOIRE ! » + 5 tuiles (place, manches, dégâts, meilleure unité, durée), Rejouer · Statistiques · **« Retour au lobby »** (mot interdit par la BIBLE) | TFT : podium des 8 avec leurs équipes ; HS : tuiles de stats de saison | Statistiques détaillées à part | P0 : texte « Menu principal » ; P1 : « Ton équipe finale » + classement des 8 (SPEC §7.1 non fait) |
| **Éliminé** | le bilan s'ouvre aussitôt (spectateur non fait, R_AC_I) | TFT : on peut rester regarder ou partir | — | P1 : « Regarder la fin » (combats en ×2) |
| **Tutoriel** | 3 fiches (`ac_shop`, `ac_stars`, `ac_traits`) | TFT : missions d'apprentissage ; SAP : tutoriel guidé court | fiches au bon moment | P1 : « Première partie guidée » (4 étapes) |
| **Réglages** | ×1 / ×2 gardé ; pause | SAP : sans minuteur ; TFT : options d'affichage (noms, barres) | reprise exacte de la partie (même boutique) | **P0** : « Préparation sans minuteur » ; P2 : options d'affichage |

---

## 4. Écarts par mécanisme (profondeur)

| Mécanisme | Nous | Références | Ce qui manque / à faire |
|---|---|---|---|
| Économie (intérêts, séries, XP, actualiser) | identique à TFT (§5.1) ; mesuré : Champion 55,7 or à 4-1, niveau 7,0 (R_AC_J) | TFT, Underlords | rien sur les règles ; l'écart est d'affichage (taux, série, revenu projeté) |
| Réserve partagée | oui, invariant testé | TFT, Underlords | la montrer : « encore 12 en réserve » dans la fiche (P1) — TFT ne l'affiche pas (outils tiers) |
| Traits | 15 (5 familles × 3 seuils, 10 armes × 3 seuils), emblèmes | TFT ≈ 25 par saison dont des traits « uniques » ; HS 9-10 tribus | 2-3 **traits uniques** de coût 5 (une seule unité, effet propre) donneraient des pivots (P2) |
| Objets | 8 composants → 36 objets, 3 par unité, retour au banc à la vente | TFT (recettes + objets utilitaires : retire-objet, reforge, duplicateur) ; Underlords (choix 1 parmi 3) | **objets utilitaires** : « Pince » (retire les objets d'une unité), « Reforge », « Copie » d'une unité ≤ coût 3 (P1, S) ; tableau des recettes au survol d'un composant (P0, S) |
| Atouts | 30, 3 raretés, 1 relance, 2-1 / 3-2 / 4-2 | TFT : centaines, renouvelés chaque saison, atouts liés à un trait / une unité | 30 → 45 dont **atouts de trait** (« +1 Ombre et les Ombre plongent deux fois ») et **atouts d'unité** (P1, M) ; Double trait 34 % et Trésor 38 % de top 4 relatif à relever (R_AC_J §5) |
| Positionnement | placement libre sur 28 cases, combat libre (vrais héros) | TFT : cases fixes, portée visible | portée et rôle visibles quand on tient une unité (anneau de cases) (P1, S) |
| Contre-jeu / lecture | voir le plateau d'un stratège en préparation | HS : prochain adversaire + survol ; TFT : Q / R | adversaire probable + survol riche + Q / R (P1) |
| Hasard contrôlé | verrou, relance d'atout, ordre du choix partagé par PV | idem TFT | **planificateur** « Mes héros visés » marqués dans la boutique (P1, M) |
| Comebacks | séries de défaites, choix partagé (PV bas d'abord) | idem | rien de neuf à inventer ; montrer la série (flamme) et « tu choisis 2e » |
| Identité de départ | 1er héros parmi 4 à 1-1 | HS : héros à pouvoir ; Underlords : commandant | **Tactiques du stratège** (1 parmi 3 à 1-1, voir §8 Q2) (P2, M) |
| Diversité des compositions | méta : Rempart + Estoc gagne 33 % (cible ≤ 15 %), tanks 57 % de top 4 relatif, 4 coût 5 hors fourchette | TFT vise ≈ 10-15 % par compo (**non vérifié** chiffré) | continuer le lot d'équilibrage (R_AC_J §5 : `ROLE_BASE` tank, `COST_MULT` coût 5) avant tout ajout de contenu |
| Événements de partie | gardiens (boss de la bibliothèque, 48), décor qui change par étape | TFT : rencontres / portails selon les saisons (**non vérifié** dans le détail) | P2 : « règle de l'étape » tirée à la graine (6 règles douces) |
| Tempo | 29,6 min ×1, 22,7 min en ×2 (mesuré) | HS ≈ 15-20 min, TFT ≈ 30-40 min, Underlords Knockout et SAP plus courts (**non vérifié** chiffré) | **format « Éclair »** 12-15 min (P1, M) ; « Passer le combat » (P1, S) |
| Rejouabilité | 4 difficultés, 3 coffres, 8 titres, quêtes | saisons, classement, modes tournants, packs (SAP), défis | **Graine du jour** + règle du jour, record personnel (P1, M) ; échelle locale de points (P2, M) |

Ce qu'on fait **mieux que tous** : 7 IA à 4 difficultés mesurées (TFT n'a pas de solo sérieux), reprise exacte, mode jouable entièrement à
la manette, statistiques de combat en direct à 4 onglets + MVP, vrais héros qui esquivent, gardiens-boss à mécaniques, récompenses
cosmétiques sans pouvoir (mode scellé). Il ne faut rien de cela perdre dans la v2.

---

## 5. Détails de confort à reprendre (liste de contrôle)

1. **Étoile d'amélioration** sur la carte de boutique qui fait monter une unité (TFT 9.20) — nous : cadre doré ; ajouter l'étoile + mini
   progression ★ / ★★ / ★★★ (Underlords).
2. **Survol d'une carte de boutique → les copies déjà possédées s'illuminent** sur le plateau et le banc ; **survol d'un trait → ses
   unités s'illuminent** (plateau, banc, boutique). (Underlords le fait pour les objets globaux, vérifié ; TFT **non vérifié**.)
3. **Marque « fait monter un trait »** sur la carte de boutique (petite flèche pomme sur la tuile du trait concerné).
4. **Taux de la boutique** en barre de 5 couleurs sous le niveau ; chiffres dans l'infobulle (règle « aucun % permanent »).
5. **Revenu de la manche suivante** en infobulle de l'or : base, intérêts, série, victoire (déjà calculé : `income_for`).
6. **Cases valides surlignées** pendant qu'on tient une unité (SAP), **aperçu des traits** (« Ombre 2 → 3 »), case de vente avec prix.
7. **Banc plein** : avertissement + unité surlignée en fraise avant la vente d'office (TFT 10.25) ; choix partagé banc plein : prévenir avant.
8. **Raccourcis** complets : W (banc ↔ plateau), Q / R (stratège précédent / suivant), Espace (retour à son plateau en combat), Tab
   (onglets du compteur, déjà fait), Retour arrière : **annuler la dernière action** (achat, vente, déplacement ; jamais une
   actualisation) — possible chez nous car le jeu est solo.
9. **« Passer »** le combat (fin au simulateur, repli déjà écrit : `AutochessSim.run`) et **« Préparation sans minuteur »** (SAP arène).
10. **Noms au survol seulement** en combat, objets sous la barre, couleurs de camp fixes (toi = pomme, adversaire = fraise).
11. **Statut des combats** des autres dans la colonne des stratèges (en cours · gagné · perdu, TFT 9.20).
12. **Annonce d'élimination** : bandeau « Daphné est éliminée · 7e » + portrait grisé.
13. **Bannières de phase** (HS) : « Préparation » / « Combat ! » 0,8 s, autocollant incliné, traits de vitesse.
14. **Recettes d'objets** : survol d'un composant → ses 8 combinaisons avec celles que tu peux faire tout de suite en avant.
15. **Tutoriel guidé** court ; fiche « Les traits » au premier trait actif (déjà) ; Guide F1 (déjà).
16. Bouton de vitesse **gardé entre les parties** (déjà), pause (déjà), reprise (déjà) : à garder et à montrer (« Reprendre la partie »).

---

## 6. Backlog priorisé (P0 : sans ça le mode fait « prototype » ; P1 : la qualité ; P2 : finitions)

Taille : S ≤ 1 jour d'agent, M 2-3, L 4+. Fichiers sous `game/scripts/`. Tout lot : BIBLE v2 + `UiTheme` v2 / `UiFeel` (socle des
équipes DA, en cours), captures `tests/shot_ac.tscn` regardées, `test_ac_ui`, `test_nav_screens`, `test_texts_fr`.

| # | P | Lot | Taille | Fichiers | Acceptation |
|---|---|---|---|---|---|
| 1 | P0 | **Habillage DA v2** de tout l'écran (papier / encre / bonbons, Mochiy + M PLUS Rounded, contours 3 px, ombres dures), colonnes resserrées (plateau ≥ 70 % en 1600×900) | M | `ui/autochess_hud.gd`, `_shop`, `_traits`, `_players`, `_unit_card`, `_augments`, `_carousel`, `_recap`, `_results`, `_team_bars`, `_meter` | captures 1280 / 1600 sans débord ; revue BIBLE §12 |
| 2 | P0 | **Traits toujours visibles** ; fiche d'unité en **infobulle flottante** près de l'unité (ou panneau droit en manette) ; survol trait ↔ unités ↔ boutique illuminés | M | `ui/autochess_traits.gd`, `ui/autochess_unit_card.gd`, `world/autochess_board.gd` (surlignage), `ui/autochess_shop.gd` | les traits ne disparaissent jamais en préparation ; test : survol d'un trait → n unités marquées |
| 3 | P0 | **Boutique v2** : tuiles de trait en couleur de famille / arme, étoile d'amélioration + mini ★★★, flèche « trait qui monte », coût en pastille | S | `ui/autochess_shop.gd` | `test_ac_ui` : marque présente quand 2 copies possédées / trait au seuil − 1 |
| 4 | P0 | **Aides éco** : barre des taux de la boutique (5 couleurs, % en infobulle), flamme de série, infobulle de revenu projeté | S | `ui/autochess_hud.gd` (lit `AutochessData`, `Autochess.income_for`) | aucun « % » dans le texte permanent (`test_texts_fr`) |
| 5 | P0 | **Unité tenue** : cases valides, aperçu des traits, banc plein en fraise ; raccourcis W, Q, R, Espace ; **annuler** (achat, vente, déplacement) | M | `ui/autochess_cursor.gd`, `ui/autochess_screen.gd`, `core/autochess.gd` (pile d'annulation de la préparation, hors actualisation) | test : annuler un achat rend l'or et la case de boutique ; réserve inchangée |
| 6 | P0 | **Lisibilité du combat** : noms au survol seulement, objets sous la barre, couleur de camp fixe (corrige R_AC_V), chiffres de dégâts plus petits pour les non-critiques | S | `ai/autochess_unit.gd` (barres), `core/autochess_director.gd` | capture mêlée : 20 unités lisibles ; barres pomme / fraise quel que soit le camp |
| 7 | P0 | **Bilan de manche non bloquant** (bandeau 2,5 s : résultat, PV, or ; « Détail » ouvre l'actuel) + **bannières de phase** | S | `ui/autochess_recap.gd`, `ui/autochess_hud.gd`, `ui/autochess_screen.gd` | la manche suivante n'attend plus aucun clic (sauf option) |
| 8 | P0 | **Moments manga + sons** : achat (pop), fusion ★ (éclat + étoiles + « Étoile ! » + carillon), niveau (« Niveau ! »), victoire / défaite de manche, élimination d'un adversaire, coup au stratège ; vibration manette (BIBLE §7) | M | `ui/autochess_screen.gd`, `world/autochess_board.gd`, `combat/sfx.gd` (sons d'interface), `core/ui_feel.gd` | chaque événement a son et animation ; « Réduire les animations » respecté |
| 9 | P0 | **Atout v2** : carte autocollante de rareté (Argent = lagon clair, Or = soleil, Éclat = améthyste + rayons), icône du jeu, une phrase, détail chiffré au survol ; textes « Menu principal » au lieu de « lobby » | S | `ui/autochess_augments.gd`, `ui/autochess_results.gd`, `core/autochess_data.gd` (clé `icon` par atout) | `test_texts_fr` ; capture atout |
| 10 | P0 | **Préparation sans minuteur** (réglage, défaut : avec) | S | `core/settings.gd`, `ui/autochess_screen.gd` | partie au pilote identique ; sauvegarde inchangée |
| 11 | P1 | **Passer le combat** (fin au simulateur) + statut des combats des autres dans la colonne | S | `core/autochess_director.gd` (`run` du simulateur), `ui/autochess_players.gd` | « Passer » donne un vainqueur en < 0,2 s ; `test_ac_fight` |
| 12 | P1 | **Stratèges v2** : survol riche (niveau, 2 traits, valeur d'équipe, 2 derniers combats), adversaire probable signalé, Q / R | M | `ui/autochess_players.gd`, `core/autochess.gd` (lecture de l'appariement suivant si déjà connu, sinon « parmi n ») | test nav ; aucune donnée cachée révélée (même règle que HS : pas le plateau avant le combat) |
| 13 | P1 | **Coup au stratège** : les survivants tirent sur le stratège perdant (projectiles d'arme, chiffre, secousse de la barre) | M | `world/autochess_board.gd`, `ui/autochess_screen.gd` | 1,2 s au plus, sauté en ×2 |
| 14 | P1 | **Spectateur après élimination** (« Regarder la fin » en ×2, bilan à tout moment) | M | `ui/autochess_screen.gd`, `core/autochess.gd` (`play_to_end` visible) | test : élimination → spectateur → bilan, place inchangée |
| 15 | P1 | **Fin de partie v2** : podium des 8 (portrait, place, trait principal), « Ton équipe finale », coffres révélés (§7 BIBLE) | M | `ui/autochess_results.gd`, `ui/results_panel.gd` (s'il faut un bloc) | capture victoire / 5e place |
| 16 | P1 | **Format Éclair** (12-15 min : PV 40, revenu fixe, pas d'intérêts, niveau acheté seulement, atouts 2-1 / 3-1 ; inspiré des modes courts) | M | `core/autochess_data.gd` (profil), `core/autochess.gd`, `ui/lobby.gd` (page), `core/autochess_ai.gd` | mesure AC-J : médiane 12-15 min, échelle des difficultés gardée |
| 17 | P1 | **Graine du jour** + règle du jour (une parmi 8) + record personnel | M | `core/autochess.gd`, `core/challenge.gd` (Défi du jour), `ui/lobby.gd` | même graine pour la journée ; test de reprise |
| 18 | P1 | **Planificateur** « Mes héros visés » (10 au plus, marque dans la boutique), gardé entre les parties | M | `ui/autochess_unit_card.gd`, `ui/autochess_shop.gd`, `core/settings.gd` | test : unité visée marquée |
| 19 | P1 | **Objets utilitaires** (Pince, Reforge, Copie) + recettes au survol d'un composant | S-M | `core/autochess_data.gd`, `core/autochess_items.gd`, `ui/autochess_unit_card.gd` | `test_ac_effects` ; mesure AC-J |
| 20 | P1 | **Atouts 30 → 45** (traits, unités) + relever Double trait / Trésor ; puis méta ≤ 20 % (R_AC_J §5) | M | `core/autochess_data.gd`, `core/autochess_augments.gd`, `core/autochess_ai.gd` (notes) | 2 000 parties : aucune compo > 20 %, atouts 40-60 % |
| 21 | P1 | **Première partie guidée** (4 étapes : acheter, placer, ★, trait) | M | `core/tutorial.gd`, `ui/autochess_screen.gd` | `test_lot9` ; jouable à la manette |
| 22 | P2 | Figurines 3D sur les cartes de boutique et du choix partagé (rendu hors écran) | L | `ui/autochess_shop.gd`, `ui/autochess_carousel.gd` | coût d'image < 1 ms |
| 23 | P2 | Tactiques du stratège (1 parmi 3 à 1-1) | M | `core/autochess_data.gd`, `core/autochess.gd`, `core/autochess_ai.gd` | mesure AC-J |
| 24 | P2 | Règles d'étape, traits uniques, échelle locale de points, revoir le dernier combat, options d'affichage (noms, chiffres, compteur) | M chacun | `core/autochess*.gd`, `core/settings.gd` | — |

---

## 7. Spécification « version 2 » des écrans (DA autocollant manga)

Valeurs : `conception/art/tokens.json` ; tailles à 1600×900 (× 0,8 à 1280×720). Croquis : `autochess_maquettes/*.html`. Règle d'or :
**le plateau d'abord** — au repos, le cadre occupe au plus 30 % de l'écran ; le papier crème entoure, l'encre remplit les zones denses.

### 7.1 Préparation (`autochess_maquettes/preparation.html`)
- **Haut, centre** (520 × 64) : autocollant papier contouré, frise de l'étape (pictos ronds : JcJ épée, monstres patte, choix ◆,
  gardien couronne fraise, atout étoile soleil), « Étape 3 · manche 2 » en Mochiy 22, minuteur en grand chiffre 34 + barre ; en mode sans
  minuteur, la barre disparaît et le bouton Prêt clignote doucement.
- **Gauche** (220 de large, hauteur selon le contenu) : **Traits**, une pastille hexagonale par trait (fond = couleur de famille ; armes
  = lagon clair) contourée d'encre, chiffre du compte dedans, nom, puis les seuils en petits plots (plot rempli = atteint). Actifs en
  haut sur papier, inactifs en dessous sur encre-500 à 70 %. Survol : les unités du trait s'illuminent (anneau lagon) sur plateau, banc
  et boutique ; infobulle bulle avec l'effet de chaque seuil.
- **Droite** (220) : **Stratèges**, 8 lignes : rang, portrait rond contouré, nom, barre de PV épaisse (pomme → soleil → fraise selon
  les PV), frise des 6 dernières manches (pastilles pomme / fraise), statut en combat (… / ✔ / ✖). Toi : autocollant soleil. Adversaire
  probable : bord fraise + pastille « prochain ? ». Éliminé : gris tramé + place.
- **Sol du plateau** : nombre « 6 / 7 » peint en Mochiy encre à 35 % au bord de ton camp (TFT) ; quand il reste une place et une unité
  au banc : le chiffre passe en soleil et respire.
- **Bas** (pied de 150, posé sur la scène, ombre dure 7 px) :
  - à gauche, **gros bouton rond XP** (96 px, lagon) : « XP » + coût en pastille d'or, anneau de progression autour, niveau dans une
    pastille d'encre ; dessous, **barre des taux** (5 segments aux couleurs des coûts, largeur proportionnelle ; infobulle : les %) ;
  - au centre, **5 cartes de boutique** (180 × 120) : bandeau haut couleur du coût, icône de classe 56 px, nom M PLUS 800, 2 tuiles
    de trait (icône + couleur), pastille de coût soleil en bas à droite, mini ★★★ des copies possédées en bas à gauche ; carte qui
    donne une étoile : rayons soleil tournants derrière + étoile autocollante dans le coin ; flèche pomme sur la tuile du trait qui monte ;
  - au-dessus des cartes, **l'onglet de l'or** (autocollant soleil, chiffre 26) avec 5 pastilles d'intérêts et la flamme de série ;
  - à droite, Actualiser (lagon, « 2 ») et Verrou (cadenas, état allumé = soleil) empilés, puis **Prêt** (bouton primaire soleil 64 px).
  - Touches dessinées en pastilles rondes (A pomme, B fraise, X lagon, Y soleil ; clavier : touche autocollante papier).
- **Fiche d'unité** : bulle papier qui sort de l'unité visée (souris) ou panneau fixe à droite (manette, à la place des stratèges
  pendant la visée) : portrait, étoiles, rôle, 2 traits (compte / seuil suivant), sort (icône du jeu, une phrase), 3 barres, objets,
  « encore 12 en réserve » ; [Viser] (planificateur).
- **Unité tenue** : la boutique glisse vers le bas et laisse « Vendre · +3 or » (fraise, maintien 0,6 s à la manette) ; cases valides
  en anneaux lagon, case visée pleine ; aperçu des traits dans la colonne gauche (« Ombre 2 → 3 » en pomme).

### 7.2 Combat (`autochess_maquettes/combat.html`)
- Bannière « Combat ! » 0,8 s (Mochiy 56, incliné −3°, traits de vitesse), puis cadre réduit : barres d'équipe en haut (comme
  aujourd'hui, en autocollant), stratèges à droite en version courte (portrait + PV + statut), compteur à gauche **replié par défaut**
  (onglet « Dégâts ▸ » ; ouvert, il garde ses 4 onglets), en bas : Pause · ×1 / ×2 · **Passer** (le seul bouton à droite).
- Au-dessus de chaque unité : barre courte contourée (PV pomme pour toi, fraise pour l'adversaire, mana lagon), étoiles à gauche,
  **objets en 3 mini-cases sous la barre** ; **aucun nom** (survol / visée : nom en bulle). Chiffres : critiques en Mochiy contouré,
  le reste en M PLUS 900 petit ; soins pomme.
- Fin : « Victoire » / « Défaite » 1 s au centre, puis les survivants tirent sur le stratège perdant (1,2 s), puis bandeau non bloquant.

### 7.3 Bilan de manche, élimination, fin (`autochess_maquettes/bilans.html`)
- **Bandeau** (haut-centre, 600 × 90, 2,5 s, glisse puis repart) : « Victoire · +6 or » (pomme) ou « Défaite · −7 PV » (fraise) ;
  détail du revenu en petits plots (base, intérêts, série) ; bouton « Détail » (le bilan actuel avec MVP et barres) ; rien n'attend.
- **Élimination d'un autre** : vignette à droite « Daphné · 7e » avec portrait qui se grise et tombe (300 ms), son sourd.
- **Ta fin** : écran de bilan commun `ResultsPanel` en papier ; place en chiffre héros 44 (rayons si top 4, confettis si 1re) ;
  **podium des 8** (portrait, place, trait principal) ; « Ton équipe finale » (figurines ou icônes avec étoiles et objets) ; tuiles
  (manches, dégâts, meilleure unité, durée) ; coffres révélés un à un (§7 BIBLE) ; boutons Rejouer (primaire) · Statistiques · Menu principal.

### 7.4 Atout et choix partagé (`autochess_maquettes/choix.html`)
- **Atout** : titre « Choisis un atout » (Mochiy 34 incliné), 3 cartes 300 × 380 : cadre de rareté (Argent : lagon clair ; Or : soleil ;
  Éclat : améthyste + rayons tournants), icône du jeu 96 px dans un médaillon, nom en Mochiy 26, **une phrase** (M PLUS 19), étiquette
  du type (« Économie », « Combat », « Unités ») ; survol : la carte monte, le détail chiffré apparaît en bas ; [Relancer · 1] et
  [Voir le plateau] dessous ; à la manette : A choisit, X relance, Y voir le plateau.
- **Choix partagé** : ordre en haut (portraits en file, toi en soleil, « À toi ! » + compte à rebours), 9 cartes en anneau (icône +
  nom + composant), « Pris par … » en tampon fraise incliné sur les cartes prises.

---

## 8. Questions ouvertes (recommandation par défaut)

| # | Question | Recommandation par défaut | Pourquoi |
|---|---|---|---|
| Q1 | Bilan de manche : bandeau non bloquant ou fenêtre ? | **Bandeau** ; la fenêtre reste sur « Détail » et en option « Toujours montrer » | tempo (TFT / HS n'arrêtent jamais la partie) |
| Q2 | Ajouter des **tactiques de stratège** (pouvoir de départ, HS / Underlords) ? | **Pas avant la v2 de l'interface** ; puis 1 parmi 3 à 1-1, 12 tactiques douces, mesurées par AC-J | donne une identité à chaque partie, mais ajoute du hasard alors que la méta n'est pas encore assez ouverte (33 %) |
| Q3 | Annuler la dernière action ? | **Oui** (achat, vente, déplacement ; jamais actualiser ni verrouiller) | jeu solo : aucun abus possible sauf l'actualisation, exclue |
| Q4 | « Passer le combat » change-t-il le résultat ? | Oui, fin au simulateur (88-89 % de même vainqueur, R_AC_J) ; texte de l'infobulle : « résultat calculé » | confort ; les puristes laissent tourner |
| Q5 | Format court ? | **« Éclair »** 12-15 min dans la page du lobby, mêmes récompenses divisées par deux | la partie de 30 min est la cible d'origine mais rebute en soirée |
| Q6 | Montrer le prochain adversaire ? | **« Adversaire probable »** seulement quand l'appariement est connu (3 vivants ou moins, ou fantôme) ; sinon « parmi Daphné, Élouan… » | même niveau d'information que HS sans révéler les plateaux |
| Q7 | Figurines 3D dans la boutique (Underlords) ? | **Icône de classe en v2**, figurines en P2 | coût de rendu et d'intégration ; l'icône du jeu est déjà belle dans un autocollant |
| Q8 | Classement ? | **Échelle locale de points** contre les IA (P2), pas de réseau | SPEC : pas de classement en v1 ; un objectif long sans réseau |
| Q9 | Noms des unités en combat ? | **Cachés par défaut**, option « Noms au-dessus des héros » | lisibilité à 20 unités (constaté) |
| Q10 | Préparation sans minuteur par défaut ? | **Non** (réglage proposé à la 1re partie dans la fiche « Achète et place ») | le minuteur donne le rythme ; le réglage sert ceux qui jouent posé |

---

## 9. Ce que cette étude n'a pas pu confirmer
Taux de boutique affichés en permanence dans TFT ; surlignage des unités au survol d'un trait dans TFT ; durée moyenne d'une partie de
HS Battlegrounds, d'Underlords Knockout et de SAP ; détail des rencontres / portails de TFT ; passe « City Crawl » d'Underlords. Rien de
ces points n'est une condition du backlog : chaque élément est justifié par notre propre écran ou par une source vérifiée.
