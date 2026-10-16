# R_H2 — Modes scellés (lot H2 de `NIVEAU_HEROS.md`, §2.3)

## Fait
- `core/modes.gd` : `Modes.SEALED` (survivor, royale) et `Modes.sealed()` = `Survivor.active or Royale.active` ou mode imposé
  scellé. Un seul test, branché aux 7 endroits du §2.3 :
  1. `Run.passive_stats` : ni talents, ni certificats, ni plateau (remplace `Survivor.active`) ;
  2. `Run.skill_talent` : aucun talent de sort ;
  3. `Player.knock_immune` : certificats du compte ignorés (une carte de certificat de la run garderait son effet, mais il n'en
     tombe plus) ;
  4. `Player.recalc_stats` : ni archive, ni aura (`Survivor.cap_hero` reste au seul Survivant) ;
  5. `Run.roll_cards` : tous les sorts de la classe, sans le filtre de maîtrise ;
  6. `Run.roll_cards` : `Cards.card_unlocked` ignoré (toutes les cartes communes) ;
  7. `Run.certificate_pool()` vide.
- Classes et apparences débloquées : inchangées (elles ne touchent pas le combat). Gains de fin du Battle royale (maîtrise,
  insignes plafonnés) : inchangés. Équipement : déjà celui de la partie (`Royale.start` vide `Profile.equipped`).
- `tools/hl_probe.gd -- --sealed` : compte opti contre compte neuf en Aventure et en Battle royale.
- `tests/test_h2` (31 vérifications) : interrupteur (menu, Aventure, Battle royale, Survivant, Duel, mode imposé), compte opti
  (talents du build opti, 7 certificats, archive de 100 entrées, aura) : passifs, talent de sort et certificats en carte présents
  en Aventure, absents en Battle royale et en Survivant ; fiche du héros opti = fiche du compte neuf en Battle royale ; maîtrise 0 :
  9 sorts sur 15 en Aventure, 15 en Battle royale ; cartes fermées proposées seulement en Battle royale ; certificat
  « insensible aux renversements » ; Duel équipé garde ses talents.

## Mesures
- Sonde (kit 2.3.5.3, niveau 60, indice √(PV effectifs × DPS), plafonds JcJ compris des deux côtés) — compte opti / neuf :

  | Classe | Aventure | Battle royale avant | après |
  |---|---|---|---|
  | Guerrier | ×2,87 | ×2,64 | ×1,00 |
  | Magicien | ×2,76 | ×2,50 | ×1,00 |
  | Chasseur | ×2,99 | ×2,52 | ×1,00 |
  | Clerc | ×2,45 | ×2,24 | ×1,00 |
  | Voleur | ×2,83 | ×2,35 | ×1,00 |
  | Chevalier | ×2,70 | ×2,46 | ×1,00 |
  | Sage | ×2,39 | ×2,19 | ×1,00 |
  | Rôdeur | ×2,88 | ×2,52 | ×1,00 |

- Parties réelles au pilote (`world.tscn -- --royale --autoplay --royale-diff=2`, profil opti guerrier ×2 et magicien ×2) :
  avant, victoire en 212-440 s (moy. 313 s, 5,8 éliminations), PV niveau 6-8 : 1 150-2 350 ; après, victoire en 326-388 s
  (moy. 346 s, 4,3 éliminations), PV niveau 5-6 : 980-1 450. Le pilote gagne toujours en Difficile : il reste nettement plus
  fort que les scriptés ; un équilibrage du Battle royale n'est pas l'objet du lot.
- Survivant : aucun changement de comportement (il était déjà coupé partout ; `SurvivorCards` tire ses propres cartes) :
  `tests/sv7_mesures.json` n'a pas à être refait ; `test_sv1`-`sv9` verts.

## Tests
Verts (copie propre de HEAD + ce lot) : `test_h2`, `test_h1`, `test_royale`, `test_sv1`-`sv9`, `test_br3`, `test_br4`,
`test_e2`, `test_cards`, `test_pvp`, `test_duel_modes`. `test_m1` instable aussi sur HEAD sans ce lot (choix de coffre d'un
scripté Facile, 1 échec sur 4) ; `test_br2` plante aussi sur HEAD sans ce lot (code 0xC0000005) : hors lot.

## Reste
Règle JcJ complète (Duel équipé, Arènes, Gantelet au niveau de héros) : lot H5. Tout nouvel effet du compte en combat doit
passer par `Modes.sealed()`.
