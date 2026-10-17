# R_CO_F : Le Colisée, lot CO-F — enclumes, or, revente, sorts des manches 3 et 6 (17/10/2026)

Étude : `ARENA.md` § 6.5 (économie de partie), § 6.7 (enclumes), § 6.3 (sorts), § 6.12 (confort) ; socle : `R_CO_A.md` (machine),
`R_CO_C.md` (directeur). Lot = backlog n° 7. Fait en même temps que le lot CO-E (atouts, `R_CO_E.md`) par la même équipe ; l'IA
d'équipe (CO-D) est faite en parallèle par une autre équipe : coordination par deux points d'extension (§ 4).

## 1. Ce qui a été livré

| Élément | Fichier | Rôle |
|---|---|---|
| Construction d'un héros | `game/scripts/core/colisee_build.gd` (`ColiseeBuild`) | un objet par héros et par partie (gardé dans la machine `Colisee` : `ColiseeBuild.of(g, équipe, place)`) : or et son journal, atouts et offre en cours, relances, pièces (`gear`), bonus de stat, enclume ouverte, enclumes offertes, sorts gagnés et offre de sort, K.O. de la manche ; rôle de combat de la classe (`role_of` : fiche de l'Échiquier — tank, mêlée, distance, soin) |
| Économie de partie | `game/scripts/core/colisee_anvil.gd` (`ColiseeAnvil`) | or de manche (`INCOME`, `income`), enclumes (`ANVILS`, `open_anvil`, `options`, `choose`), revente (`sell`, `resale`), annulation d'un bonus de stat (`undo_stat`), enclumes offertes (`GIFTS`), sorts des manches 3 / 6 (`SPELL_ROUNDS`, `spell_pool`, `open_spells`, `take_spell`, `grant_spells`), préparation des IA (`ai_prep`, `shop`), choix automatique du joueur au temps écoulé (`auto_finish`), point d'extension du chef d'équipe (`coach`) |
| Directeur | `game/scripts/core/colisee_director.gd` (éditions ciblées) | constructions créées au lancement (`ColiseeAnvil.setup`), préparation de chaque manche (`round_start` : or, offres ; les IA décident), pièces passées à `TeamMatch.make_hero`, construction posée sur chaque héros à son apparition (`ColiseeAugments.apply_hero`, `grant_spells`), fin de préparation (`auto_finish`, fiche du joueur refaite), page de préparation |
| Page minimale de préparation | `game/scripts/ui/colisee_prep_page.gd` (`ColiseePrepPage`) | essais à la main (l'écran de l'étude vient au lot CO-G) : or, offre d'atouts (icône, nom, une phrase, bandeau de rareté, détail chiffré en infobulle, relance), sort de plus, enclumes (offertes, puis à leur prix) et leurs 3 options, pièces portées (« Revendre (+n) »), bonus de la manche (« Annuler (+n) »), « Prêt ». Ne tient pas la pause. Montrée hors pilote automatique et hors mode sans écran ; la préparation dure alors celle du format (30 s), « Prêt » la termine |
| Tests | `game/tests/test_co_f.tscn` ; capture `game/tests/shot_co_prep.tscn` | § 5 |

## 2. Règles codées (valeurs de l'étude, toutes validées)

- **Or** (`ColiseeAnvil.INCOME`) : 10 par manche ; à partir de la manche 2, +3 si la manche d'avant est gagnée, +2 par K.O. donné
  (3 comptés au plus) ; Tirelire +4 ; Mise : +15 de plus sur une victoire, aucun or de manche sur une défaite ; exempt : la base. Pas
  d'intérêts, pas de série : l'or sert à construire. Les K.O. sont comptés par héros (crochet de K.O. de la couche des atouts).
- **Enclumes** (on paie pour ouvrir, on garde une option parmi trois) :

| Enclume | Prix | Options | Code réutilisé |
|---|---|---|---|
| Stat | 6 | 3 bonus différents parmi PV +6 %, Attaque +5 %, Vitesse d'attaque +8 %, Recharge −5 %, Critique +4 %, Défense +10 %, tirés au poids du profil de la classe (`ClassGear.profile().weights`) ; plafonds cumulés (`STATS.cap` : PV 36 %, Attaque 30 %, Vitesse 40 %, Recharge 15 %, Critique 20 %, Défense 60 %) | `ClassGear` |
| Pièce | 12 | une pièce par **emplacement vide d'abord** (jamais d'arme : celle de la classe reste, comme au Battle royale) ; équipement plein : mises à niveau, rareté +1, forge, ou une pièce meilleure (gain de note) ; qualité « argent » du Battle royale, « or » dès la manche 6 | `RoyaleLoot._piece`, `rate`, `_amount`, `_apply` |
| Panoplie | 20 ; **offerte manche 3** | 3 pièces de la panoplie la plus portée qui manquent (bonus 2 / 4 pièces) ; sans pièce de panoplie : 3 panoplies différentes (armure de la classe d'abord) | `SurvivorPool` (13 panoplies niveau 90), `Items.from_template` |
| Éclat | **offerte manche 9** (jamais en boutique) | 3 pièces légendaires de ta classe sur tes emplacements les plus faibles | `RoyaleLoot._piece` (qualité largage, rareté légendaire) |

  Éclair : panoplie offerte manche 2, éclat manche 5.
- **Revente** (`resale`) : au prix payé pendant la préparation de l'achat, à moitié ensuite ; une pièce remplacée par une enclume est
  revendue d'office ; une amélioration garde le prix de la pièce (prix cumulés). Un bonus de stat s'annule (remboursé) tant que la
  préparation de l'achat dure (`undo_stat`) : aucun achat définitif par erreur (§ 6.12-3).
- **Sorts** : 4 au départ (ceux du préréglage ; les enchaînements du préréglage sont retirés au lancement, comme les héros scriptés
  qui en ont 4) ; une place de plus aux manches 3 et 6 (Éclair : 2 et 4 ; Maître des sorts : une de plus) : 3 sorts de la classe
  pas encore pris, les mieux notés (`spell_score` : dégâts et contrôles ÷ √recharge, soins pour un soigneur) avec du hasard. Le
  joueur l'a en **enchaînement** d'une de ses quatre touches (celle qui en a le moins : `Run.chains`, le système des cartes « chain ») ;
  un héros scripté l'ajoute à ses sorts (`ClassRival._skills`, sorts d'attaque seulement : il ne lance ses soutiens qu'en allié).
- **Préparation** (`round_start`) : or versé, offre d'atouts (manches 1 / 4 / 7 / 10), enclume offerte, offre de sort ; les IA
  décident tout de suite (`ai_prep` : atout, sort, enclume offerte, puis achats : pièce pour un emplacement vide, panoplie déjà
  portée — Difficile et plus —, puis stats ; Facile s'arrête au hasard) ; le joueur choisit sur la page ; **au temps écoulé**, ce qui
  l'attend encore prend l'option la mieux notée, jamais au hasard (`auto_finish`) ; son or n'est jamais dépensé pour lui.
- **Pièces sur les héros** : héros scripté = `TeamMatch.make_hero(…, gear)` (fiche d'un vrai héros équipé, comme avant) ; joueur =
  `Profile.equipped` (même dictionnaire que `ColiseeBuild.gear`, équipement du compte mis de côté par `Colisee.begin`, rendu à la fin).

## 3. Mesures

- **Économie d'une partie** (`test_co_f`, machine seule, 3 parties Classique de 10 manches, IA Hardcore) : or reçu moyen par héros
  encore en lice à la manche 10 : **139-148** ; pièces portées : **8 / 8** (équipement complet vers la manche 8, puis améliorations) ;
  4 atouts (moins après une fusion) et 2 sorts de plus ; jamais d'or négatif.
- **Valeur d'une pièce en combat** (banc des atouts, `R_CO_E.md` § 3 : trio contre le même trio, Hardcore, 30 combats chacun) : 2 pièces
  d'enclume par héros gagnent 63 %, 5 pièces 62 % ; écart de force par héros et par pièce ≈ +0,06 logit (un atout moyen d'Argent vaut à peu
  près 1,5 pièce). Les pièces pèsent peu : l'échelle relative du JcJ (dégâts × √(PV) ÷ √(puissance) des deux héros, `PvpCaps.damage_mult`)
  écrase les stats d'équipement, et l'arme reste celle de la classe. **À reprendre au lot CO-I** (calibrage) : un multiplicateur des stats de
  pièce propre au profil « colisee », ou des enclumes moins chères, si les parties réelles montrent que l'or ne se sent pas.
- **Fiche** : une pièce d'enclume de pièce relève les PV d'un Guerrier de 15 260 à 15 712 (+3 %) ; un héros scripté équipé de 6 pièces
  a plus de PV que nu (`test_co_f`).

## 4. Interface avec l'IA d'équipe (lot CO-D, autre équipe)

- `ColiseeAnvil.coach` : un objet qui a `choose_augment(offres, construction, ctx)`, `choose_anvil(options, construction, ctx)`,
  `choose_spell(ids, construction, ctx)` (indices) et `shop(construction, partie)` ; sinon, **le chef d'équipe `ColiseeCoach`
  s'il existe** (chargé dynamiquement : aucune dépendance de compilation) est appelé avec ses fonctions statiques
  `choose_augment(offres en dictionnaires {score, tags}, classe, difficulté, classes du trio, hasard)` et `choose_anvil(options
  {gain}, …)` ; sinon, les choix notés de ce lot (`ColiseeAugments.choose_augment` / `score`, `ColiseeAnvil.choose_anvil` /
  `choose_spell`). `ColiseeAugments.offer_dicts` met les offres au format du chef d'équipe.
- Notes réutilisables : `ColiseeAugments.score(id, construction, ctx, synergie)` (rôle, synergie du trio et de la recette, état de la
  partie : PV d'équipe, manche, victoires), `ColiseeAugments.context_for(partie, construction)`, options d'enclume avec leur `gain`.

## 5. Tests et captures

`test_co_f` (≈ 47 contrôles, 15-35 s) : or (manche 1, victoire et K.O., plafond des K.O., exempt, Tirelire, Mise) ; enclume de stat
(prix, refus sans or, 3 bonus différents, choix, annulation remboursée, plafonds) ; enclume de pièce (emplacements vides d'abord, jamais
d'arme, prix et manche notés, revente au prix puis à moitié, équipement plein : améliorations ou remplacements, prix cumulé) ;
panoplie (3 panoplies sans pièce portée, puis la panoplie portée, bonus 2 pièces) ; éclat offerte (gratuite, légendaire) ; pictogrammes
Ico ; sorts (pool d'attaque d'un héros scripté, manches 2 / 3 / 6, enchaînement du joueur) ; préparation des IA (atout pris, or dépensé)
et du joueur (rien pris pour lui, temps écoulé = meilleure note même noté Facile, or intact) ; pièces sur un héros scripté ; économie
de 10 manches.

Résultats (copie de HEAD 0.1.306 + CO-E / CO-F, `run_tests.py --reuse -j 2`, 30 à 34 Godot actifs) : voir `R_CO_E.md` § 5 (même série).

Capture regardée (`shot_co_prep`, 1280 × 720, hors dépôt : `%TEMP%/co3_shots`) : offre d'atouts lisible (encre sur papier, bandeau de
rareté, relance en pictogramme), enclume de pièce et ses 3 options, pièce portée avec « Revendre (+12) » ; corrigé après lecture : textes
clairs sur papier (illisibles), relances en lignes entières, pictogrammes d'enclumes absents (ids Ico inexistants).

## 6. Pièges pour la suite

1. `ColiseeBuild.gear` du joueur **est** `Profile.equipped` : ne jamais le remplacer par un autre dictionnaire pendant la partie.
2. Les héros scriptés sont recréés à chaque manche : tout ce qui doit durer (or, pièces, atouts, sorts) vit dans la construction, jamais
   sur le héros ; `ColiseeAugments.apply_hero` et `ColiseeAnvil.grant_spells` le reposent à l'apparition.
3. La page de préparation n'est qu'un banc d'essai : l'écran du lot CO-G la remplace (mêmes appels : `ColiseeAugments.take` / `reroll`,
   `ColiseeAnvil.open_anvil` / `choose` / `sell` / `undo_stat` / `take_spell`, puis `ColiseeAugments.apply_hero` sur le joueur).
4. Banc IA contre IA du lot CO-D (trio 0 tiré sans la classe du joueur) : aucune construction « joueur » (`ColiseeBuild.setup` vérifie
   la classe), le trio 0 est préparé comme une IA.
