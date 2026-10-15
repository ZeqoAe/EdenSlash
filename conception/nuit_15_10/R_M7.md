# R_M7 — Arènes, Duel, Gantelet : peaufinage, équipes IA, durée des manches, idées

Captures regardées une à une (compte neuf et avancé, 1600×900 et 1280×720, APPDATA détourné) : `tests/shot_m7.tscn`
(`M7_PART=lobby|game`, `M7_RES=1280x720`) → `user://shots/m7_*.png` : Jouer, Duel (Libre à l'arme / équipé, Ligue, Panthéon
verrouillé puis ouvert, Gantelet), Arènes 2v2 / 3v3, éditeur d'adversaire, file (recherche, match, draft, récapitulatif),
Arène 3v3 (décompte, combat avec zones de feu, pause, joueur tombé, fin de manche), bilans d'arène et de Gantelet (abandon).

## 1. Détails corrigés
- **Gantelet** : la page lisait les conditions de l'**à l'arme** (le bouton s'ouvrait sans armure ; le Gantelet se joue équipé) ;
  conditions de l'équipé, en tête de page.
- **Réglages du duel libre écrasés** par la Ligue, le Panthéon et les Arènes (cerveau choisi, adversaire de l'éditeur perdu,
  à l'arme, niveau) : mis de côté puis rendus au retour au lobby (`Duel.save_free` / `restore_free`) ; ligne morte
  `Duel.pilot = Duel.pilot if …` retirée.
- **Cerveau adverse en équipe** : il ne visait que le joueur (figé quand celui-ci tombait) et les alliés IA ne pouvaient ni le
  viser ni le toucher (groupe `foe_heroes` absent de `Monster._hostile_pool` / `Combatant.hostile_targets`) : une manche
  « joueur à terre, alliés debout » ne pouvait plus finir. Corrigé (`MlDuelPilot.others`, `Player.foes`).
- **Alliés IA 2,5 fois trop forts** : ils gardaient les PV / l'attaque d'entraînement de `ClassRival` (× 3 à × 8) au lieu de la
  fiche d'un héros comme les adversaires ; ils étaient toujours en Difficile. Même fiche, même difficulté que les adversaires.
- HUD : « DUEL · CHEVALIER » en arène → « ARÈNE 3 CONTRE 3 », « Gantelet 1 contre 3 », « Ligue · Platine », « Panthéon ».
  Bilan : sous-titre au nom du mode, victoires du mode, « ABANDON » au lieu de « DÉFAITE » après un abandon, coffres
  d'apparence du Panthéon et de la Ligue enfin listés, bouton « Combat suivant » (Ligue, nouvelle classe), « Nouvelle équipe
  adverse » / « Nouveaux adversaires » (Arènes / Gantelet), « Rejouer (même adversaire) » (libre).
- Joueur tombé en équipe : la caméra suit un allié debout (elle restait sur le corps).
- Pause en duel : plus d'or / clés / cristaux, ni « Trophée et cartes », ni sac ; tuiles niveau, manches, durée, coup porté,
  coup reçu, mode.
- Pages du duel libre et du Gantelet : seulement les points à régler (« Certificats 0 / 0 emplacements ✔ », « Aucune tenue
  débloquée ✔ » disparaissent) ; tout réglé : « ✔ Héros prêt · préréglage « … » » (détail en infobulle). Textes ≥ 14 px.
- File : marges intérieures (le contenu touchait le cadre), Échap / B refuse un match trouvé, sous l'adversaire « Niveau 10 · IA
  difficile » (et plus « Clerc · Clerc »), draft du joueur sans la note sur l'IA ni le suffixe « (IA cerveau) », « Aucun » au lieu
  d'« Auto », noms de sorts coupés par « … ».

## 2. Équipes IA
- Choix de classes : familles différentes (`Duel.team_classes` : pas trois mêlées ni deux soigneurs) ; alliés au hasard d'une
  famille absente de ton équipe.
- Difficulté réglable (Arènes, Gantelet), niveau réglable (Arènes), alliés de la même difficulté.
- Comportement (`ClassRival`, en équipe seulement : duel 1 contre 1 inchangé) : **cible le plus faible** (Normal et plus), **esquive
  les zones rouges** de tous les héros adverses et de l'arène (groupe `telegraphs`), lit aussi les coups du joueur quand il vise
  un allié, **retraite** sous 30 % de PV vers un équipier (2,5 s, toutes les 12 s), les adversaires **soignent et renforcent**
  leur camp comme les alliés.
- Cerveau en premier adversaire : vérifié en test (il vise les alliés, ils le touchent, il les touche).

## 3. Durée des manches (cible 30 s – 1 min 30)
Arène d'IA, cerveau hardcore contre lui-même, 4 combats par paire (6 paires, niveaux 10 / 50 à l'arme, 50 / 90 équipé) :
50-90 s pour 4 paires sur 6 ; **soigneurs trop longs** : Clerc–Assassin 90 / 116 / 118 s, Paladin–Rôdeur 119 / 111 / 121 s,
Barde–Berserker 97 / 96 s. Essai soins ×0,25 au lieu de 0,35 : le Clerc passe de 4 / 4 victoires à 0 / 4 (rejeté). Retenu :
**mort subite** après 90 s (l'acharnement double en plus toutes les 5 s) : Clerc 116 → 81 s, Barde 96 → 82-94 s ; les manches
de moins de 90 s ne bougent pas. Paladin–Rôdeur équipé niveau 50 reste à 98-138 s : le cerveau du Paladin ne rattrape pas
le Rôdeur qui fuit (aucun coup ne porte : l'acharnement n'y peut rien) — à regarder côté cerveau.
Parties réelles en pilote automatique (`world.tscn -- --duel --duel-mode=… --autoplay --auto-quit`, Difficile, 4 classes ×2) :
Arènes 2v2 84 s → **74 s**, 3v3 104 s → **88 s** (échelle 0,022 → 0,026 et 0,018 → 0,024, acharnement dès 25 s / 20 s) ;
Gantelet (équipement d'époque II +10) : 34-42 s, le pilote gagnait 3 fois sur 4 à 1 contre 3 → adversaires qui se soignent :
2 sur 4 à 1 contre 3, 3 sur 4 à 1 contre 2, manches 37-41 s.

## 4. Idées (6 proposées, 3 faites ; détail dans `conception/IDEES_EN_VRAC.md`)
Faites : **arène piégée** (zones de feu violettes pour tous, option des Arènes et du Gantelet), **rang et série visibles** (pastilles,
IA du rang, récompense de promotion, 1re victoire du jour), **PV des équipes et tableau de manche** (`ui/team_bars.gd`).
Proposées : modificateur choisi par le perdant, saisons de Ligue, entraînement contre un cerveau avec retour chiffré.

## 5. Récompenses (quête commune)
Promotion de Ligue : + 40 × rang insignes (inchangé) **et un coffre d'apparence** (rare, rare, mythique, légendaire), une fois.
1re victoire du jour (Arènes, Gantelet) × difficulté rapportée à Difficile (Facile ≈ 60 %, Hardcore ≈ 118 %) : jouer en Facile ne
paie plus comme en Difficile. Aucun équipement brut ajouté.

## Fichiers
À moi : `core/duel.gd`, `core/duel_director.gd`, `core/league.gd`, `ui/duel_results.gd`, `ui/duel_queue.gd`, `ui/duel_prep.gd`,
`ui/team_bars.gd` (nouveau), `ml/ml_duel_pilot.gd`, `combat/pvp_caps.gd`, `core/mode_rules.gd`, `ai/class_rival.gd`, tests
`test_m7` (nouveau, 25 contrôles), `shot_m7`. Retouches ciblées : `ui/lobby.gd` (pages Duel / Arènes / Gantelet / Ligue),
`ui/run_page.gd` et `ui/pause_menu.gd` (pause en duel), `core/world.gd` (abandon, arguments de mesure), `player/player.gd`
(`foes`), `combat/combatant.gd`, `ai/monster.gd` (cibles des alliés), `combat/telegraph.gd` (groupe), `tests/test_lot15.gd`
(échelles, l'allié esquive maintenant).
Tests verts : test_m7, test_lot14, test_lot15, test_e2, test_nav_screens, test_p4_activities, test_results, test_royale, test_m1,
test_duel_modes, test_siege, test_hud.

## Reste / pièges
- Cerveau contre cerveau : une même classe gagne souvent 4 / 4 (Magicien > Guerrier, Démoniste > Samouraï) : c'est autant le
  cerveau que la classe ; ne pas régler les classes sur ces seuls chiffres.
- Les profils « opti » (`gen_profiles`) n'ont pas été régénérés.
- Le dossier partagé : plusieurs sessions éditaient `lobby.gd` en même temps ; le commit ne prend que mes morceaux.
