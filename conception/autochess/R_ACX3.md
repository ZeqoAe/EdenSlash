# R_ACX3 : L'Échiquier, le P1 restant du backlog BM-AUTO (17/10/2026)

Lot : `conception/benchmark/AUTOCHESS.md` §6, n° 12, 13, 15 (fin), 16, 17, 18, 19, 20, 21. DA : BIBLE v2 par le style du mode
(`AutochessHud`, `UiFeel`). Mode scellé, IA scriptée seulement. Tout ce qui touche l'équilibre est mesuré (§ Mesures).

## Ce qui est fait

### Format Éclair (n° 16)
- `AutochessData.FORMATS` : « classique » (inchangé) et « eclair » : **40 PV**, étape 1 réduite (ouverture, monstres, avec un
  héros de coût 2 offert), **7 or par manche fixes** (ni intérêts ni séries), **aucune XP offerte** (niveau 3 donné à 1-2, le
  reste s'achète), atouts en **2-1 et 3-1**, préparation de 18 s, PV perdus +10 %. Clés lues par `Autochess.configure(format,
  règle)` → `rules` (`rule()`, `max_hp`, `reroll_cost`, `xp_cost`, `kind_at`, `rounds_in`, `is_augment_round`, `interest_cap`) ;
  `AutochessData.round_kind / rounds_in / is_augment_round / prep_time / base_income / loot` prennent ces règles. Le format est
  sauvegardé avec la partie.
- IA : courbe de niveau propre (`ECLAIR_CURVE`), rien gardé pour les intérêts, relance quand le niveau visé est atteint ;
  Légende = plan du Champion (trois plans : trop lent pour 18 manches) ; notes d'atouts selon le format (Intérêts composés
  inutile, Trésor et Apprenti relevés, Pacte de sang prudent).
- Récompenses : « divisées par deux » (BM-AUTO Q5) = une place deux fois meilleure (2e = top 4, 1re = tout).
- Lobby : choix **Classique / Éclair** (`_ac_format`), étiquette « Éclair · … » sur la frise (infobulle : les règles).

### Partie du jour (n° 17)
- `AutochessData.daily_seed(jour)` (même graine pour tous ce jour-là), `daily_rule(jour)` : une des **8 règles du jour**
  (`DAY_RULES` : Trésor de départ, Boutique généreuse, Jour d'école, Jour de forge, Pluie d'éclats, Grand plateau, Banquiers,
  Jour d'hésitation), appliquées aux 8 stratèges. Partie du jour = Éclair, mélange Vétéran (`DAILY_DIFF`, `DAILY_FORMAT`).
- Record : `AutochessRewards.daily_state()` (meilleure place du jour, parties du jour, meilleure place, jours joués) ; bilan :
  « Partie du jour : 2e · nouveau record du jour ! ». Lobby : règle du jour, record, « Jouer la partie du jour » ; Rejouer garde
  la graine du jour. Lancement direct : `scenes/autochess.tscn -- --ac-daily` (ou `--ac-format=eclair`).

### Objets utilitaires et recettes (n° 19)
- `SPECIAL_ITEMS` + `UTILITY_ITEMS` : **Pince** (objets rendus intacts), **Creuset** (objets complets changés au hasard de la
  partie), **Miroir** (copie ★ d'un héros de coût 3 ou moins, prise à la réserve) ; le Marteau de réforge a désormais une icône.
  `Autochess.utility_ok` / `_use_utility` (annulables par Ctrl+Z). Butin : Miroir à 3-7, Pince à 4-7, Creuset à 6-7 (gardiens).
- IA (`AutochessAi._utilities`) : Miroir sur le héros bon marché qui vaut le plus (une ★★ qui se complète d'abord ; plus tard,
  la meilleure copie), Pince sur un héros du banc qui porte des objets ou pour rendre au porteur des objets mal placés,
  Creuset et Marteau sur les objets mal assortis au rôle.
- Fiche d'un composant : ses **8 recettes**, celles qu'on peut faire tout de suite (banc d'objets, composant seul sur un héros)
  en tête avec une pastille pomme (`AutochessUnitCard._recipes`, bulle plus large).

### Atouts 30 → 45 (n° 20)
15 atouts de plus (15 Argent / 17 Or / 13 Éclat) :
- de trait (`trait_plus` : un compte de plus + un bonus aux porteurs) : Serment du Rempart, Pacte de l'Ombre, Piste de la
  Traque, Flamme de la Ferveur, Savoir arcane ; Maître d'armes (un trait d'arme au choix), Grand cœur (+2 à une famille) ;
- d'unité : Recrue dorée (un coût 3 au choix), Jumeaux (copie du plus cher), Porte-étendard (le mieux équipé), Trinité (les
  3 plus chers), Ligne de boucliers, Grand grimoire ; d'objets : Atelier (Pince + Creuset), Miroir des âmes.
- Relevés : **Double trait** (tous les traits présents, familles comprises) et **Trésor du dragon** (40 or).
- Effets de combat dans `AutochessAugments` (même couche pour le simulateur et le vrai combat), notes des IA dans
  `AutochessAi.AUGMENT_BASE` + contexte (`_augment_rating` : trait du plan, compte au seuil − 1, porteur équipé…).

### Stratèges v2 (n° 12) et coup au stratège (n° 13)
- `Autochess.likely_opponents(pi)` : adversaires possibles d'après la seule règle publique d'appariement (les derniers
  adversaires évités ; aucun hasard lu ni tiré). En préparation d'une manche JcJ : pastille fraise « prochain ? » sur les lignes
  quand il reste deux candidats au plus ; sinon « Prochain adversaire parmi : … » dans ta bulle.
- Survol riche (`AutochessPlayers.Row._make_custom_tooltip`) : bulle papier avec niveau, PV, série, deux traits principaux,
  valeur d'équipe, deux derniers combats (« Défaite contre Daphné (−7 PV) »).
- Coup au stratège (`AutochessScreen._strike`) : après un vrai combat à ×1, les survivants du gagnant tirent (6 projectiles
  au plus, en cloche, couleur du camp) sur la figurine du perdant, chiffre « −N » à l'impact, secousse de la figurine et de sa
  ligne (`AutochessPlayers.flash`) ; 1 s environ, sauté en ×2 et ×3, au pilote et en durées réduites ; rien contre un écho.

### Fin de partie v2 (n° 15, fin)
« Ton équipe finale » (icône de classe sur la couleur du coût, étoiles, objets) et **coffres révélés un à un** (autocollant
qui s'ouvre en ressort, rayons tournants, son qui monte, confettis au dernier), sur une rangée sous le podium d'ACX-2.

### Planificateur (n° 18) et première partie guidée (n° 21)
- `ui/autochess_planner.gd` : 10 héros visés au plus (touche T ou clic du stick droit sur la fiche, ligne « Viser : T » /
  « ◎ Héros visé »), cible fraise sur leurs cartes de boutique ; gardé entre les parties (Settings « autochess » / « planned »).
- `ui/autochess_guide.gd` : bulle papier sous la frise, 4 étapes (acheter, placer, une étoile, un trait) cochées quand elles
  sont faites, dans n'importe quel ordre ; « Passer le guide » ; rien ne s'arrête (non bloquant, manette comprise). Fin ou
  passage : Settings « guide_done », fiches ac_shop / ac_stars / ac_traits marquées vues (le guide les remplace).

## Mesures (simulateur calé d'AC-J, mise en place « echelle », machine très chargée : 4-25 s par partie)
| Mesure | Avant (HEAD, 400 parties) | Après (269 parties) | Éclair (300 parties) | Cible |
|---|---|---|---|---|
| combat JcJ médian / sous 40 s / égalités | 22,8 s / 97 % / 0,7 % | 22,5 s / 97 % / 0,8 % | 22,6 s / 97 % / 0,8 % | 22-28 s / ≥ 90 % / < 3 % |
| partie entière ×1 (×2) | 29,6 min (22,7) | 29,7 min (22,8) | **14,4 min (10,6)** | 25-30 min ; Éclair 12-15 |
| manches | 33,3 | 33,5 | 18,4 | ≈ 35 |
| 1re élimination avant 4-1 | 8 % | 11 % | (format court) | < 20 % |
| échelle R / V / C / L (place) | 7,11 / 4,58 / 3,25 / 3,07 | 7,14 / 4,65 / 3,19 / 3,02 | 6,90 / 4,58 / 3,24 / 3,28 | décroissante |
| 1re composition gagnante | 30 % | 30 % | **18 %** | ≤ 20 % |
| atouts, top 4 relatif (min-max) | 36-67 % | 35-62 % ; les 15 neufs : 40-58 % | — | 40-60 % |
| Double trait / Trésor du dragon | 36 % / 40 % | **42 % / 41 %** | — | 40-60 % |

- Première passe (400 parties, atouts neufs sans retouche) : Grand cœur 37 % pour 61 % de prise, Grand grimoire 39 %, Double
  trait 37 % → Grand cœur noté 6 au lieu de 7,5 (46 % ensuite), Grand grimoire +35 % de sorts / +30 mana (42 %), Double trait
  étendu aux familles (42 %).
- Essai rejeté (passe « m3 », 147 parties) : Estoc 5 / 12 / 24 %, Rempart déf. 32 à 9, coût 5 × 1,8 : la méta se resserre
  (38 %, 6,5 compositions effectives au lieu de 8,7) ; rien gardé. `ROLE_BASE` non touché.
- Éclair, 1re passe (préparation 20 s, PV perdus ×1, Légende à trois plans, 182 parties) : 16,0 min et Légende derrière le
  Champion (3,48 contre 3,17) → préparation 18 s, PV perdus +10 %, Légende au plan du Champion, notes d'atouts du format.
- `tests/ac_mesures.json` refait (bloc `games` de cette passe, bloc `eclair` neuf) ; `test_ac_sim_real` relit les mêmes bornes.

## Ce qui reste
- **Méta ≤ 20 % en Classique non tenue** : Rempart + Estoc gagne 30 % (inchangé) ; les leviers essayés côté traits / coût 5
  la resserrent. Le levier restant est `ROLE_BASE` (tank) dans `autochess_effects.gd`, à mesurer sur 2 000 parties au calme.
- Couronne et Héros légendaire (atouts d'avant) : 61-62 % de top 4 relatif, pris 64-80 % des fois ; Niveau 11 à 35 %.
- Passes de 269-400 parties au lieu de 2 000 (machine saturée : jusqu'à 25 s par partie) ; l7r / r7l / pilote non refaits.
- P2 du backlog (figurines 3D, tactiques, règles d'étape, revoir le combat…).

## Tests et captures
- `test_acx3` (nouveau) : Éclair (règles, partie entre IA jusqu'au bout, sauvegarde), partie du jour (graine, stratèges,
  boutique, 8 règles), outils (Pince et annuler, Creuset, Miroir, refus coût 5, butin), 45 atouts pris par les IA et Miroirs
  utilisés, IA Miroir / Pince, adversaire probable (sans toucher au hasard), planificateur, récompenses Éclair et record du jour,
  écran (guide coché étape par étape et passé, T et cible, recettes, survol riche, coup au stratège en vrai combat, textes),
  bilan v2 (équipe finale, coffres ouverts un à un).
- Mis à jour : `test_ac_data` (45 atouts, formats, règles, outils), `test_ac_effects` (nouveaux atouts de combat et de
  partie), `test_nav_screens` (« Passer le guide » atteignable), `test_texts_fr` (recettes, outils), `shot_ac` (recettes,
  coup au stratège), `shot_acx3` (nouveau ; 1280 × 720 et 1600 × 900, 0 débord).
- `AutochessRewards.hub_view` ignore aussi `records.goals` (objectifs du lot GX-3, créés vides au premier accès) : sans ça
  `test_ac_rewards` voyait le hub « bouger ».
