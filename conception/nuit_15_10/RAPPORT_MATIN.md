# Rapport de la nuit du 15/10/2026 (versions 0.1.165 à 0.1.185)

Rédigé à ta demande. Les chiffres viennent des rapports des agents (`R_*.md` dans ce dossier) ; je n'ai pas rejoué moi-même
les simulations. Trois passes (P2, P4, P6) travaillaient encore au moment de l'écriture : leurs résultats ne sont pas ici.

## Ce qui change pour toi

**1. Ton stuff du menu sert en Survie** (lot N1, 0.1.170)
- La Survie part avec le préréglage actif du hub : pièces, +N, gemmes, enchantements, panoplies, arme secondaire.
- Les trouvailles des coffres de la run remplacent un emplacement le temps de la run, puis le hub est restauré à l'identique
  (victoire, défaite, abandon, extraction, ou fermeture du jeu en pleine run). Les pièces choisies restent achetables à l'Armurerie.
- Compte neuf : 8 pièces de départ par classe (rares au mieux, niveau 10-30), remises une fois. Ton compte actuel sans armure en reçoit aussi.
- Ton journal réel : 9 runs perdues en 2 min 35 à 4 min 55, aucune n'atteignait le boss. Le début de partie est plus doux (XP ×2 au niveau 1).
- Même une défaite rapporte des insignes (25 de participation dès 10 monstres tués).
- Enclume : bonus de +0 à +7 ajouté au +N de la pièce, total plafonné à +12.

**2. Chaque activité sert la quête commune** (lots E1 à E6)
- Insignes = acquérir (Armurerie), cristaux = optimiser (Forge), parchemins / gemmes / formules = matières.
- Donjons, Ruée, Siège et Tour donnent maintenant des cristaux et des coffres de forge / joaillier au niveau de l'activité. Avant, aucune activité
  hors Survie ne donnait de quoi monter l'équipement, et les pièces de niveau 40 et plus ne pouvaient pas dépasser +0.
- Survie : parchemins et formules au niveau des pièces de la carte (plus de plafond à 35). Capes ajoutées (2 coffres par carte).
- Armurerie : catalogue entier (1 811 pièces) avec compteur « découvertes / total », filtres emplacement / époque / classe, paliers de prix
  (une pièce d'un palier déjà entamé coûte 15 %). Une arme choisie en Survie fait découvrir les armes des 17 types.
- JcJ : maîtrise partout (Duel libre, Arènes, Gantelet, Panthéon, Royale), insignes plafonnés au jour pour que le JcJ ne dépasse plus la Survie.
  Panoplie des Esprits achetable par toutes les classes, arme du Champion de n'importe quel type.
- Donjons : plan garanti au 1er clear de chaque difficulté, fabrication de l'arme et des bijoux.
- 60 classes : 7 profils de stats, « Équiper le meilleur », « Appliquer à la famille », annulation (Héros > Équipement > Gérer),
  et un **Registre de l'équipement** dans le Carnet (par classe : ce qui manque et quelle activité le donne ; « N / 60 classes équipées » dans le lobby).
- Maîtrise : rattrapage ×1,5 des classes en retard, bonus de première victoire par époque, 10 % partagés dans l'arbre de classe.

**3. Interface** (lots U1 à U10, P1, P3)
- Pages d'activité qui défilent avec le bouton Lancer toujours visible ; pied de page lisible ; tout tient en 1280×720.
- Choix de carte en un clic (plus de « Valider »). Coffres lisibles, « Ouvrir tout », Roulette qui montre l'apparence de chaque case.
- Un seul bilan de fin de partie pour tous les modes (Gagné / Gardé / Perdu), nombres animés, insignes expliqués au survol.
- HUD épuré (texte ≥ 14 px, AUTO seulement sur case remplie, Premiers pas seulement en Survie). Pause allégée avec « ? Aide » → Guide.
- Héros, Atelier (Forge avant → après), Carnet, Paramètres plein écran, accueil en 3 écrans, Guide F1 en 6 onglets.
- Infobulles courtes (stat principale en gros, comparaison ▲ / ▼, Maj pour les détails).
- Noms français pour 5 919 objets, 219 monstres, 8 zones. Plus aucune mention du jeu d'origine côté joueur (le mode dev garde ses outils).

## Décisions que j'ai fait prendre à ta place (à valider ou corriger)

1. **Équilibrage des époques** (E6) : la simulation montrait l'époque IV gagnée en ~10 h. Monstres désormais ×1 / 1,7 / 3,4 / 7 (avant ×1 / 1,35 / 1,75 / 2,2).
   Joueur moyen simulé : époque IV vers 27-28 h, équipement complet vers 30 h. **Les époques II à IV seront nettement plus dures.**
2. **Époque I adoucie** (monstres ×0,85, P5) : au pilote automatique le boss de la carte 1 est atteint dans 47 % des runs (27 % avant). Le pilote joue mal ;
   c'est un proxy, pas ton ressenti. **C'est la première chose à tester.**
3. **JcJ moins rentable en insignes** : environ 180-190 insignes par heure de JcJ contre 1 800-3 000 avant ; la Survie fait 360-670.
4. **Verrous de PE** des Donjons Héroïque / Mythique relevés (Héroïque vers l'époque III, Mythique après l'époque IV) ; ils s'ouvraient dès l'époque II.
5. Coffre « trophée » supprimé du menu Coffres (les anciens deviennent des coffres de set).
6. Les formules d'enchantement niveau 8-9 sont réservées au Siège.

## À tester en premier
1. Une Survie d'époque I sur ton compte actuel : atteins-tu le boss de la carte 1 ? Combien d'insignes gagnes-tu ? L'Armurerie propose-t-elle quelque chose d'achetable ?
2. Armurerie > achat > Forge > Survie : la pièce améliorée se sent-elle ?
3. Héros > Équipement > Gérer (« Équiper le meilleur ») et le Registre dans le Carnet.
4. Un clic sur une carte de niveau : choisie immédiatement (anti-rafale 0,3 s).
5. Le bilan de fin de Survie (survol des insignes).

## Restes et points ouverts
- P2 (performances), P4 (test de bout en bout de tous les modes) et P6 (boussole d'objectif dans le lobby, gains affichés par activité) : en cours.
- Dernier signalement connu : `test_e2` avait 2 échecs (duel) après P5, P4 doit les traiter.
- Le pilote automatique ne sait pas esquiver : toute mesure d'équilibrage reste un proxy. Ton journal de run (`journal.jsonl`) donnera les vraies mesures.
- Cerveaux d'IA, signatures de famille, Épreuves de maîtrise, images des activités et fiches : non traités cette nuit.
- Questions de conception ouvertes (A1 §5.5) : JcJ rapporte-t-il des insignes ou seulement titres et maîtrise ? Parchemin Lv 100 = objectif rare ou simple palier ?
- Les fichiers `A1_progression.md`, `A2_interface.md`, `PLAN_NUIT.md`, `STATUT_NUIT.md` et ce rapport ne sont pas encore commités ; les captures (`captures/`) ne sont volontairement pas dans git.
