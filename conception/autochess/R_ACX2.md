# R_ACX2 : L'Échiquier, confort, lecture du combat et moments (backlog BM-AUTO hors ACX-1), 17/10/2026

Lot : `conception/benchmark/AUTOCHESS.md` §6, P0 n° 5 à 10, plus P1 n° 11 (Passer), 14 (spectateur) et une partie du n° 15
(podium). DA : `conception/art/BIBLE.md` v2 (socle UIK-0 : `UiTheme` v2, `UiFeel`, Mochiy Pop One / M PLUS Rounded 1c) par le
style du mode `AutochessHud` (ACX-1). Mode scellé, IA scriptée seulement. Aucun réglage d'équilibre touché
(`tests/ac_mesures.json` intact, `test_ac_sim_real` vert).

## Ce qui est fait

### Curseur de cases et annulations (P0 n° 5)
- **Annuler** (`core/autochess.gd`, `undo` / `can_undo` / `undo_list`, pile de 12) : achat, vente, déplacement (plateau, banc,
  échange) et objet donné se défont exactement (or, boutique, banc, plateau, objets, réserve partagée, hasard de la partie :
  un Emblème refait propose les mêmes traits). Jamais une actualisation, un achat d'XP ni un choix (la pile est vidée), ni d'une
  préparation à l'autre ; le verrou et la meta du stratège restent. Seuls les stratèges humains prennent un instantané (les IA :
  aucun coût). Ctrl+Z / Retour arrière, bouton « Vue » de la manette, bouton « Annuler · Ctrl+Z » au bout de l'onglet de l'or
  (visible s'il y a quelque chose à annuler) ; avis « Achat annulé »…
- **Vente confirmée** (`ui/autochess_cursor.gd`) : zone « Vendre · +3 or » en autocollant fraise avec anneau de maintien et
  touche dessinée ; X (manette) ou E (clavier) maintenus 0,6 s (BIBLE §6) ; un héros précieux (★★ et plus, ou avec objets)
  vendu d'un coup (E bref, déposé sur « Vendre ») demande « Vendre Chevalier ★★ ? » (`InfoCard.ask`) ; après une vente, l'avis
  rappelle « Ctrl+Z pour annuler ».
- **Unité tenue** : aperçu des traits dans la colonne (« Ombre 1 → 2 », « Tranchant 0 → 1 ») pour un héros du banc pas encore
  sur le plateau ; la fiche se cache pendant qu'on tient (la zone « Vendre » et l'aperçu parlent) ; cases valides / plateau
  plein en rouge : déjà faits par AC-F.
- **Raccourcis** : W (héros sous le curseur : banc ↔ plateau, première case de sa place), Q / R (plateau du stratège précédent /
  suivant en préparation, combat précédent / suivant en combat, stratège suivi en spectateur), Espace en combat (retour à son
  combat, sinon vitesse), 1 / 2 / 3 en combat (vitesse), P / X (Passer), Échap / Start (pause). Touches dessinées en pastilles
  sur les boutons (Pause « Échap », Vitesse « 1 2 3 », Passer « P » / X, Relancer « R » / X, Voir le plateau Y, Détail « Tab »).

### Combat lisible (P0 n° 6, P1 n° 11)
- **Barres** (`ai/autochess_unit.gd`, shader commun) : deux jauges contourées d'encre, PV en deux tons nets (reflet) avec bord
  droit d'encre et **trace claire des dégâts** qui rattrape les PV, mana lagon, creux encre-500 ; **pomme pour le stratège qui
  regarde, fraise pour l'adversaire, quel que soit le camp** (`AutochessDirector.viewer` / `is_mine` : corrige R_AC_V, où le
  camp b voyait ses unités en rouge) ; étoiles à gauche de la barre ; **objets en mini-cases sous la barre** (Sprite3D, icônes
  du jeu) ; **aucun nom** par défaut : nom au survol de la souris (unité la plus proche, 60 px) ou réglage « Noms ».
- **Nom du sort** : quand un sort signature (ou le 2e sort d'une ★★★) part, son nom s'affiche 1 s au-dessus de l'unité
  (lagon pour les siens, fraise pour l'adversaire).
- **Chiffres sobres** (`AutochessDirector.on_effects`) : un coup sous 6 % des PV max de la cible s'écrit petit et estompé ;
  critiques en grand (l'événement « damage » de la couche dit maintenant `crit`) ; dégâts subis par ses propres unités en
  rouge ; soins pomme au-dessus de 4 % ; « Esquive » / « Parade » en lagon.
- **Vitesse ×1 / ×2 / ×3** (bouton, Y, 1 2 3), **vraie pause** (l'arbre s'arrête, combat compris ; carte Pause avec Reprendre,
  Réglages, Menu principal, Abandonner), **Passer** (`AutochessDirector.skip` : tous les combats finis tout de suite au combat
  de données, même couche d'effets à partir de leur état ; infobulle « résultat calculé »).
- Compteur de dégâts **replié par défaut** (« Dégâts ▸ »), en papier avec ses lignes dans un puits d'encre ; barres d'équipe
  en papier (pastilles contourées, PV pomme / fraise, chronomètre Mochiy, vitesse en pastille soleil).

### Bilan de manche non bloquant (P0 n° 7)
- `AutochessRecap.RoundStrip` : bandeau papier en haut au centre, « Victoire » / « Défaite » / « Égalité » incliné sur sa couleur,
  « +6 or · Butin : … » ou « −7 PV », puis le revenu de la manche suivante en plots (base, intérêts, série, atout) ; [Détail]
  (Tab, cadre de la manette) ouvre le bilan complet ; il tient 3,2 s (plus tant qu'il est survolé) et ne bloque rien : la
  manche suivante enchaîne (pause de 1,8 s après un vrai combat au lieu d'attendre jusqu'à 20 s un clic).
- Réglage « Bilan à chaque manche » : l'ancien comportement. Le bilan complet passe au papier (« Meilleur héros de la manche »
  au lieu de « MVP »).

### Moments manga (P0 n° 8)
- `ui/autochess_moment.gd` (`AutochessMoment`, calque au-dessus du mode, ne prend jamais la souris) : **bannière inclinée** (−4°,
  Mochiy 48 blanc contouré sur autocollant de couleur, traits de vitesse et étincelles, ressort d'entrée, une à la fois en file),
  **éclat sur place** (onomatopée au-dessus d'une figurine + anneau et étoiles d'UiFeel), **vignette d'élimination** (portrait
  qui se grise et tombe, « Daphné · éliminé · 7e »). Son et vibration de la manette par `UiFeel.cue` (nouvelle fonction publique,
  minimale, qui respecte intensité et vibration réglées) ; « Réduire les animations » : fondu seul.
- Branchés : « Combat ! » / « Gardien ! » au début du combat ; « Victoire ! » (pomme, son clair, vibration) / « Défaite » (fraise,
  son sourd, vibration forte) ; « ★★ ! » sur la figurine à la fusion, « Trois étoiles ! » en bannière + confettis ; « Objet
  complet ! » quand deux composants se combinent ; « Niveau 7 ! » à l'achat d'XP ; élimination des autres en vignette ;
  « Éliminé » pour toi.

### Cartes d'atouts v2, libellés (P0 n° 9)
- `ui/autochess_augments.gd` : voile d'encre, titre Mochiy incliné, cartes papier à **cadre de rareté** (Argent lagon clair, Or
  soleil, Éclat améthyste + rayons qui tournent), **médaillon** contouré avec l'**icône du jeu** (clé `icon` ajoutée aux 30 atouts
  dans `AutochessData.AUGMENTS`, icônes de passifs `Boons.ICONS`), nom en Mochiy, **une phrase**, étiquette du genre (Économie,
  Combat, Unités, Objets), détail chiffré en fondu sur la carte visée seulement ; « Relancer · 1 » (R, X), « Voir le plateau » (Y) ;
  distribution des cartes en fondu. Même carte pour premier héros, héros légendaire, objet, composant, famille, emblème.
- Libellés : « Menu principal » (bilan de fin, pause), plus de « MVP », « Esquive » / « Parade » en minuscules ; `test_texts_fr`
  vert.

### Préparation sans minuteur (P0 n° 10)
- Réglage `Settings` section « autochess » (`no_timer`, `names`, `recap_always`, gardés dans les Paramètres) ; carte « Réglages de
  l'Échiquier » depuis la pause ; proposé dans la fiche « Achète et place » de la 1re partie (« Jouer sans minuteur »). Sans
  minuteur : le chiffre et la barre disparaissent, la préparation attend Prêt ; le pilote automatique et la sauvegarde ne
  changent pas.

### Spectateur après élimination (P1 n° 14) et fin (P1 n° 15, en partie)
- À ta chute : place et récompenses **fixées tout de suite** (`AutochessRewards.finish` une seule fois, hub remis, partie gardée
  effacée, plus aucune sauvegarde), bannière « Éliminé », carte « Tu es éliminé · 6e » : **Regarder la fin** (les autres combats
  en vrai, ×2, le stratège en tête suivi, Q / R ou clic sur sa ligne pour en suivre un autre ; Bilan depuis la pause) ou **Bilan**.
- Bilan de fin : **podium des 8** (portrait, place, trait principal ; toi en soleil) sous les tuiles ; « Menu principal ».
- Pilote automatique, durées réduites et `--auto-quit` : la fin tout de suite comme avant (mesures AC-J inchangées).

### Illustration de l'activité
`assets/ui/activities/autochess.jpg` définitive : intégrée par ILL-2 (0.1.272) ; rien à refaire ici.

## Mesures
| | |
|---|---|
| `test_acx2` (nouveau) | 38 vérifications vertes : annuler (achat, déplacement, vente ; actualisation et XP vident la pile), Ctrl+Z, ★★ et son éclat, vente confirmée (« Vendre … ★★ ? », confirmation, maintien), W, Q / R, sans minuteur, noms, camp b en pomme, vitesse ×1 → ×3, atout v2 (icônes des 30, phrase sans %), bandeau + revenu, « Combat ! » puis bandeau sans bilan imposé, élimination → spectateur ×2 → partie jusqu'au bout (28 manches regardées) → place inchangée → podium et « Menu principal », textes français |
| `test_ac_ui`, `test_ac_rewards`, `test_nav_screens`, `test_ac_game`, `test_ac_board`, `test_ac_stats`, `test_ac_effects`, `test_acx1`, `test_ac_unit_ai`, `test_ac_sim_real`, `test_texts_fr` | verts (copie de HEAD + ce lot) |
| `test_ac_fight` | rouge sous charge (19 Godot ouverts : image médiane 40 ms) ; même échec que sur HEAD pendant la mesure d'ACX-1 ; à relancer au calme |
| Captures `shot_ac` 1280 × 720 et 1600 × 900 | 0 débord ; vrai combat rendu dans l'arène : image médiane 6,1 ms / 6,5 ms, p95 12,5 / 14,1 ms (ACX-1 : 6,1-6,2 ms) : barres, étoiles, objets et noms de sorts ne coûtent rien de visible |

## Décisions
- Annuler côté machine (instantané du stratège humain + réserve + hasard) plutôt que des actions inverses : exact, court, et
  l'IA ne paie rien. Le verrou reste tel quel (il n'est pas une décision qui coûte).
- Vente confirmée = maintien 0,6 s (manette, clavier) ; la question n'arrive que pour un héros précieux vendu d'un coup ;
  glisser vers « Vendre » reste direct pour un ★ sans objet (geste volontaire, annulable).
- Bandeau + bannière : la bannière fait le moment (0,6 s), le bandeau garde l'information (revenu, butin, Détail).
- Noms des sorts courts et colorés par camp, pas d'onomatopée sur chaque sort (le combat reste calme, BIBLE §2.5).
- Spectateur : récompenses fixées à la chute (quitter pendant qu'on regarde ne fait rien perdre).

## Reste (backlog BM-AUTO)
- P1 : coup au stratège (n° 13), stratèges v2 (survol riche, adversaire probable, n° 12 ; Q / R faits), fin de partie v2 complète
  (« Ton équipe finale », coffres révélés un à un, n° 15), format Éclair (n° 16), graine du jour (n° 17), planificateur (n° 18),
  objets utilitaires et recettes au survol (n° 19), atouts 30 → 45 (n° 20), première partie guidée (n° 21).
- P2 : figurines 3D en boutique (n° 22), tactiques du stratège (n° 23), règles d'étape, traits uniques, revoir le dernier combat,
  options d'affichage restantes (n° 24).
- `ResultsPanel` (commun) et `InfoCard` gardent leur thème : leur passage au papier est au lot des écrans communs.
- `test_ac_fight` à relancer quand le processeur est libre.
