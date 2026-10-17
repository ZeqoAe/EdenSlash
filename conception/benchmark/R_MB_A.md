# R_MB_A : Les Deux Voies, lot MB-A — données, règles, kits des 60 classes

Lot MB-A du plan `conception/benchmark/MOBA.md` (§ 9). Fondation sans scène des « Deux Voies » (MOBA 4 contre 4, nom
interne « moba ») : toutes les règles chiffrées du mode en un fichier, les kits de partie des 60 classes générés, le profil
de combat `moba` de `ModeRules`, la fiche `moba` de `TeamMatch` complétée. Rien de visible en jeu (le mode n'est pas encore
lançable : carte au lot MB-B, structures et sbires au lot MB-C). Recommandations par défaut de l'étude : validées par le joueur.

## 1. Livré

| Élément | Fichier | Contenu |
|---|---|---|
| Règles du mode | `game/scripts/core/moba_data.gd` (`MobaData`) | réglages en tête (§ 7.2-7.7 de l'étude) ; fonctions de lecture ; `validate()` |
| Kits des 60 classes | `tools/moba_kits.py` → `game/data/moba_kits.json` | 3 cases de base + 1 ultime, enchaînements (2 + 2 + 2 + 1) ; `--check` |
| Profil de combat | `MobaData.RULES`, `MobaData.ensure_rules()` → `ModeRules.register("moba", …)` | lu par `PvpCaps` quand `TeamMatch` joue « moba » |
| Fiche du mode | `game/scripts/core/team_match.gd` (`MODES.moba`) | + `director` (`core/moba_director.gd`, lot MB-C), `potions` (boutique, touches C / V) |
| Test | `game/tests/test_mb_data.tscn` | 30 contrôles (§ 3) |

## 2. Ce que contient `MobaData`

- **Déroulé** : vagues dès 0:40 puis toutes les 30 s (bélier une vague sur 3, sur 2 dès 12:00), camps 1:30, Gardien 3:00
  (annoncé 45 s avant, revient 3 min après), protection des T1 jusqu'à 4:00 (dégâts × 0,5), Colosse 9:00 (60 s d'annonce, revient
  4 min après), réapparition + 25 % dès 15:00, Marée 18:00, fin au temps 25:00.
- **Héros en partie** : niveaux 1 à 12, fiche d'un héros de la classe au niveau 30 + 5 × (niveau − 1) ; XP 120, 160 … 520
  (3 520 pour le niveau 12) ; gains (sbires 30 / 20 / 60 / 90, héros 100 + 25 × niveau, camps 60 / 100, Gardien 150, Colosse
  250, 1 par seconde) ; partage à 15 m ; rattrapage + 30 % sous la moyenne adverse de 2 niveaux ; or : départ 500, 2 / s dès 0:40,
  dernier coup 100 %, allié proche 60 %, achevé par un sbire ou une tour 50 % ; primes (300, premier sang + 100, série + 100 au-delà
  de 2, 700 au plus ; T1 250, T2 300) ; réapparition 5 + 2 × niveau s (7 à 29 s) × 1,25 / × 1,5 ; rappel 6 s ; fontaine 12 % / s.
- **Niveau attendu** `expected_level(t)` (1 à 0:00, 4,8 à 5:00, 10,4 à 15:00, 12 à 18:00) et **héros de référence**
  `ref_hero(niveau)` (fiche moyenne de 6 classes, une par famille + Rôdeur, calculée une fois : 11 ms les 12 niveaux) : la
  force des sbires suit la partie, et **l'unité de dégâts des structures** (`ref_auto(t)`) = une auto-attaque de ce héros.
  Mesuré : niveau 1 = 4 398 PV, 80 de défense, 511 par auto-attaque ; niveau 12 = 20 696 PV, 212, 90 658 (l'attaque monte bien
  plus vite que les PV : d'où des sbires et des structures exprimés en parts du héros, jamais en valeurs fixes).
- **Sbires** (mêlée, tireur, bélier, géant) : monstres des deux camps (Grand champignon rocheux / Champignon au chapeau rouge,
  Angelly arc-en-ciel, Grand bison cornu / Yak aux cornes acérées, Forgé de calcaire / Golem de calcaire), PV en auto-attaques d'un héros (4 / 3 / 10 / 25), coup = 3 / 2,5 / 5 / 6 % des PV d'un héros,
  dégâts entre sbires en parts d'un mêlée, dégâts sur les structures en unités (1 / 0,8 / 2 / 3), tirs de tour pour les tuer ;
  vague 3 mêlées + 2 tireurs ; plafond de 60 vivants (budget R_MB0 § 6).
- **Structures** : tours (portée 9 m, 1 tir / s, 10 % des PV d'un héros, × 1,4 par tir de suite jusqu'à × 2,2, remis à zéro en 5 s),
  Cœur (2 tirs / s, 6 %, PV = 1,5 × T2), protection − 66 % sans sbire ennemi à 12 m, T2 invulnérable tant que la T1 tient.
- **Postes** (conseil par famille, jamais imposé) : Brumes = Rempart, jungle = Ombre, Soleil tir = Traque / Arcane, Soleil
  soutien = Ferveur. **Camps** (Source, Braise, petits ; laisse 12 m) et **objectifs** (Gardien palier 1 → Sceau, Colosse
  palier 3 → Bannière) : chiffres pour le lot MB-F.
- **Boutique** : les **40 objets** de l'étude (9 composants, 5 bottes, 22 finis, 4 potions) : prix, recette, stats en part de la
  fiche de base, déclencheur (`proc`) ; `text` = la phrase du joueur **sans pourcentage**, `tip` = les chiffres pour l'infobulle ;
  7 onglets ; 2 parcours conseillés par famille. Appliqués par le lot MB-D (Q13 de l'étude : pénétration et ténacité gardées
  comme stats ; si elles coûtent trop, les objets 15 et 27 se simplifient).

## 3. Kits générés (`tools/moba_kits.py`)

Règles de l'étude § 7.6, sans aucun kit écrit à la main : déplacement (dash, blink, sort qui fait avancer) et contrôle (renversement,
gel, sommeil, terreur, immobilisation, désarmement, ralenti, attraction) dans les 3 cases quand la classe en a ; un soin pour la
Ferveur ; ultime = sort offensif de plus forte valeur (multiplicateur × coups × zone) parmi ceux de plus de 12 s de recharge
(Ferveur : son meilleur soin), recharge × 4 bornée à 60-90 s, puissance × 1,6 ; le reste des cases = les sorts principaux de la
classe d'abord ; enchaînements = les plus forts des sorts restants. Résultat : **60 kits**, 48 ultimes offensifs et 12 de soutien ;
aucun manque de déplacement, de contrôle ou de soin ; les cases de base reprennent un sort principal de la classe pour les 60.
`test_mb_data` relance `moba_kits.py --check` (fichier à jour). « Mon kit » (préréglage du Duel) : P1, lot MB-D.

## 4. Mode scellé et profil de combat

`Modes.sealed()` était déjà vrai pour toute fiche de `TeamMatch` (lot MODE-0) : vérifié pour « moba » (scellé, JcJ, partie entre
héros, ni `Duel.active` ni `Royale.active`). Profil `moba` : échelle 0,09, soins × 0,6, coup ≤ 22 % des PV max, rafale ≤ 50 % sur 2 s,
pas d'acharnement ; enregistré au lancement (`MobaData.ensure_rules`, comme l'Assaut et le Colisée), pas dans `ModeRules.PROFILES`
(fichier partagé par les trois modes d'équipes en cours).

## 5. Tests

`test_mb_data` (copie de HEAD 0.1.295 + ce lot) : **vert** (30 contrôles : tables, XP, réapparition, primes, niveau attendu, déroulé,
vagues, postes, camps et objectifs, héros de référence, sbires, 40 objets et recettes, textes sans « % », onglets, parcours, 60 kits,
fichier à jour, profil lu par PvpCaps, fiche, scellé, fin). `test_texts_fr`, `test_mode0` : voir le rapport du lot MB-C (repassés à
chaque envoi).

## 6. Pour la suite
- MB-B : carte (`world/moba_map.gd`), lit `MobaData.TOWER_AT`, `CAMPS`, `OBJECTIVES`.
- MB-C : structures et sbires lisent `MINIONS`, `TOWER`, `CORE`, `minion_stats`, `ref_auto`, `wave`.
- MB-J recalibre : `EXPECTED_LEVEL`, `RULES.dmg_scale`, PV des structures, `MINIONS`.
