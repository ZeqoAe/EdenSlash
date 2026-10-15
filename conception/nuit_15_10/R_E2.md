# R_E2 — Maîtrise du JcJ, insignes plafonnés, plans, panoplie des Esprits (A3 + A5 + B4)

## Fait

**A3 — maîtrise partout, insignes JcJ plafonnés (I6, I9)**
- Formule commune `League.mastery_for(manches, palier, part)` = (40 + 20 × palier + 150 × manche) × part ; la Ligue l'utilise
  (inchangée), `League.pvp_mastery(mode, manches, difficulté, adversaires en plus)` pour les autres modes.
- `Duel.settle` : maîtrise au Duel libre, aux Arènes, au Gantelet, au Panthéon (à chaque victoire, même classe déjà passée) ;
  `Royale.settle` : maîtrise selon la place et les éliminations. Le texte « Maîtrise : +N » rejoint les listes `text` existantes
  (bilans U9 inchangés).
- Insignes : `League.win_insignia(clé)` (1re victoire du jour de chaque mode pleine, puis 10) et `League.royale_insignia`
  (meilleure place du jour : la différence avec la précédente, + 3 par élimination). Compteurs dans `Profile.records.pvp_daily`.
- Anti-abus : duel libre contre un adversaire affaibli (préparation PV / dégâts < 1 ou adversaire de l'éditeur) = pas de
  maîtrise ; les modes classés remettent la préparation du duel libre à 1 pendant la partie (elle affaiblissait aussi les
  Arènes et le Gantelet) puis la rendent.

**A5 — plans et PE**
- Plan de la zone sûr au 1er donjon terminé de **chaque** difficulté (Normal compris) ; sinon 10 % (`Dungeons.PLAN_CHANCE`).
  Un plan par zone : la fabrication suit déjà la meilleure difficulté, d'où ce choix.
- Fabrication : arme (type de la classe choisie), collier, anneau en plus ; la pièce prend le modèle d'Eden **du niveau du
  donjon** (avant : de la zone choisie au lobby, même défaut que I8). Retouche ciblée de `ui/fabrication_page.gd` (2 endroits).
- Siège Normal : 0 % de PE (`Siege.POWER_RATIO[0]`).

**B4 — panoplie des Esprits universelle (I8)**
- Pièces = modèles fixes, légendaires de niveau d'Eden 70 (`Pantheon.PIECE_LEVEL`), choisis une fois pour toutes
  (`_base_template`), ajoutés à `GameData.eden_by_id` sous des ids à part (`Pantheon.shop_id` : 900000 + 100 × cerveau + type).
- Gagnée, une pièce entre dans `seen_gear` : l'Armurerie la revend (220 insignes) **sans modifier l'Armurerie** (elle lit
  déjà `seen_gear` + `eden_by_id`). Le Champion ouvre l'arme des Esprits des **17 types**. Sauvegardes existantes :
  `Pantheon.sync_seen()` au chargement (1 ligne dans `profile.gd`). Hors du compte « découvertes » (`Completion.armory_done`).
- Éveil : `Items.SETS.pantheon.awake` ; avec 6 pièces éveillées portées, le palier 6 devient +10 % dégâts, +5 % critique,
  esquive → hâte puis furie 4 s, recharge 4 s (au lieu de rien, 3 s, 8 s). Affiché dans l'infobulle (« 6 pièces éveillées »).

## Chiffres (avant → après)

| Activité | Insignes / heure (est., 100 % de victoires) | Maîtrise par victoire |
|---|---|---|
| Survie (référence, inchangée) | ≈ 360 (époque I) à 670 (époque IV) | ≈ 1 300 (≈ 2 200 / h) |
| Ligue | promotions seules (inchangé) | 360-420 (inchangé) |
| Duel libre | 0 → 0 | 0 → 90 (Facile) à 210 (Hardcore) |
| Arènes 3v3 (Difficile) | ≈ 1 800 → **185** (75 puis 10 / victoire) | 0 → 170 |
| Gantelet 1v3 | ≈ 1 800 → **≈ 180** (90 puis 10, ~10 victoires) | 0 → 255 (1v2 : 213) |
| Battle royale (gagnée, 2 élim.) | ≈ 3 000 → **182** (110 + 3 / élim.) | 0 → 162 (podium ≈ 90, 5e ≈ 26) |
| Panthéon | 0 | 0 → 360 (Débutant) à 460 (Champion) |

Première heure du jour en faisant tous les modes JcJ (tout gagné) : ≈ 300-450 insignes, sous la Survie d'époque III-IV.
Maîtrise / heure : Arènes ≈ 2 000 (12 victoires), Royale ≈ 1 000 (moyenne), donc sous la Survie gagnée (≈ 2 200).

## Décisions
- JcJ hors Ligue à la **moitié** de la Ligue (et selon la difficulté) : la Survie reste la source principale de maîtrise.
- Royale : seule la meilleure place du jour paie (« première victoire par rang ») ; le coffre d'apparence du podium reste à
  chaque partie (cosmétique, collection sans doublon).
- Niveau 70 pour les Esprits : comme les pièces « Awaken » de l'Armurerie ; le Panthéon arrive après la Ligue Platine.

## Retouches hors de mes fichiers (ciblées)
`ui/fabrication_page.gd` (U5 : liste des emplacements, modèle du niveau du donjon), `ui/activities.gd` (U1 : gains Arènes /
Royale « maîtrise »), `core/items.gd` (palier éveillé, `awakened_count`, ligne d'infobulle), `core/completion.gd` (compte de
l'Armurerie), `core/profile.gd` (1 ligne `Pantheon.sync_seen`). Ces fichiers ayant aussi des changements en cours d'autres
sessions, seuls mes extraits sont dans mon commit (index = HEAD + mes remplacements).

## Reste / pièges
- `test_siege` ne compile pas en ce moment à cause d'un travail en cours d'une autre session (`PauseMenu.leave_texts`
  absent) ; ma modification de ce test (Siège Normal PE 0) est faite, à relancer quand U9 aura poussé.
- Mesurer la maîtrise / heure réelle du JcJ avec le journal (E6). Les pièces des Esprits d'avant E2 gardent leur ancien
  niveau (pas de migration : on peut racheter la version fixe).
- `gear_shop_page.gd` (U5) n'est pas touché : si U5 filtre un jour les ids hors `Completion.armory_ids`, garder les
  `Pantheon.is_shop_id` (test_e2 le vérifie via `GearShopPage.make`).

Test : `tests/test_e2.tscn`. Verts : test_e2, test_lot8, test_lot13, test_lot14, test_lot17, test_lot18, test_siege,
test_progress, test_farm, test_gear_run. test_build (« pause : compétences sur 12 lignes ») et test_royale (« page Run :
lignes de sorts glissables ») ont chacun 1 échec d'écran venant du travail en cours d'U9 (menu pause), sans lien avec E2 ;
les vérifications de récompenses de test_royale passent.
