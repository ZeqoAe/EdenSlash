# Équipe Équilibrage — concertation (tour 2, jeu 0.1.130)

Lu : `00_BRIEF.md`, notre `rapport_1.md`, et les rapports `progression/`, `builds/`, `interface/`,
`modes/`. Un seul point vérifié dans le code (question d'Interface sur `ZONE_DAMAGE`, voir 1.1).
Renvois : E1-E9 (nous), P1-P9 (Progression), B1-B13 (Builds), I1-I9 (Interface), M0-M7 (Modes).

---

## En bref

- **Fusion principale** : notre E1 (profils de mode) et le M0 de Modes (socle « activité ») deviennent
  **un seul bloc** en deux couches : `Activity` (Modes : *comment* le mode se déroule) et
  `ModeRules` (nous : *les chiffres* du mode). Une activité nomme son profil ; plus aucun
  `if Duel.active` pour un chiffre.
- **Accords larges** : une seule règle de 1 contre 1 (Duel et duels de la Tour), identité de build
  identique partout (Builds §8), Donjons avec l'équipement du hub synchronisé au niveau (M2 option A
  = notre E4), garde-fous chiffrés (B3, B8, B13 = notre E7), cristaux en Tour (P5 = notre E8).
- **Conflits tranchés** : format du Panthéon (3 avis différents → « fiche d'entraînement » pour les
  deux héros), durée des Donjons (on prend celle de Modes), acharnement dans la Tour (on le garde,
  plus tard), cartes en Donjon (une par salle).
- **Abandons** : profils détaillés des Arènes et du Champ de bataille (reportés, Champ retiré du
  menu : d'accord avec Modes) ; « pas d'acharnement en Tour ».

---

## 1. Réponses aux questions qui nous sont posées

### 1.1 Interface

**Q1. `ZONE_DAMAGE` adoucit la 1re map de chaque époque : est-ce voulu ?** Non. Vérifié :
`run_director.gd:522` prend `Run.stage - 1` en Survie, sans regarder l'époque. Résultat à l'époque IV :
map 1 = 0,55 × 2,2 = **×1,21**, map 3 = **×2,2** (marche ×1,8 en deux maps). Détail que le
rapport 1 n'avait pas vu : **le boss de la map 1 est adouci lui aussi** (aucune exception `boss`
ligne 523), et `EARLY_EASE` (×0,6 → ×1 en 3 min) se rejoue à chaque map.
Proposition (E5, valeurs du profil `survie`) :

| Époque | `stage_dmg` map 1 / 2 / 3 | `EARLY_EASE` |
|---|---|---|
| I | 0,55 / 0,8 / 1 (inchangé : c'est le tutoriel des Premiers pas, I1) | maps 1 à 3 (inchangé) |
| II | 0,8 / 0,9 / 1 | map 1 seulement |
| III, IV | 0,9 / 1 / 1 | map 1 seulement |

Le boss garde `stage_dmg` (il fait partie de la marche) mais jamais `EARLY_EASE` (déjà le cas :
l'arène n'est pas en état `explore`). Pour les Premiers pas, rien ne change à l'époque I.

**Q2. Fourchettes du menu Coffres (I4)** : d'accord pour que l'aperçu lise **les mêmes tables** que
`Rewards.open` (une seule source). Si E8 change un contenu, l'aperçu suit tout seul ; nous le
signalerons quand même dans le CHANGELOG.

**Où afficher les règles d'un mode (notre question)** : Interface propose la ligne « Rapporte : … »
sur la page d'activité (I3). Nous demandons une 2e ligne **« Règles : … »** générée depuis le profil
(3 écarts au plus par rapport à la Survie, p. ex. « Équipement ramené au niveau 45 · soins ×0,35 ·
acharnement après 30 s »). Niveau synchronisé d'une pièce : « 23 → 45 » en gris sur la fiche d'objet
quand une activité synchronisée est sélectionnée.

### 1.2 Modes

**Q1. Champs du profil, durées cibles** : voir la version consolidée (section 5). Durées : nous
prenons les vôtres pour la Survie, les Donjons et les Défis (section 3.2).

**Q2. Une seule échelle de 1 contre 1 (`PvpCaps`) pour la Tour et le Duel** : **oui**, c'est notre
E3.4. La Tour garde deux valeurs à elle (PV du duelliste ×0,45 → voir 3.3, poids de l'équipement 0,75).

**Q3. Donjons option A (équipement du hub ramené au niveau)** : faisable, et c'est ce qui le
distingue de la Tour. La Tour fait déjà `min(niveau de l'étage, plafond de la pièce)` : **même règle**
en Donjon (pas de nouveau calcul). La difficulté ne s'écrase pas tant que le niveau du donjon est
**imposé par la difficulté** (Normal = niveau de la zone, Héroïque +15, Mythique +30, plafonné à
100), et non choisi librement. Comparaison : en Tour le niveau monte avec l'étage et la pièce
« décroche » vers l'étage 2N ; en Donjon le niveau est fixe, une pièce trop basse se voit dès l'entrée.

**Q4. Panthéon** : voir conflit 3.1.

**Q5. Reprise de Tour et Défi du jour**
- Reprise à l'étage N : **les 12 sorts du preset** (`Run.fill_from_preset`, comme le Duel), plus
  **N ÷ 5 cartes de build** tirées d'un coup (rareté normale), plafonnées à 30 ; trophées : N ÷ 10
  (plafond 12, si M3 garde les trophées). Avec les paliers de 10 étages de M3, le héros de l'étage
  151 a 30 cartes et 12 trophées : un peu sous la courbe d'un joueur parti de 1 (≈ 1 carte par étage
  vidé), ce qui garde l'intérêt de monter d'une traite.
- Modificateurs du Défi du jour (chacun = une **surcharge** du profil `survie`, pas de code à part) :

| Modificateur | Surcharge | Contrepartie (pour rester jouable) |
|---|---|---|
| Projectiles doublés | `bonus_proj` +2 | PV des monstres ×1,3 |
| Soins réduits | `heal_mult` 0,5 | dégâts des monstres ×0,85 |
| Élites partout | part d'élites ×3 | or des élites ×0,5 |
| Coffres moins chers, sans enclume | `chest_base` ×0,6, `anvil` non | — |
| Une vie, dégâts ×1,5 | `res` 0, dégâts du héros ×1,5 | — |
| Rage précoce | rage à 6 min | insignes ×1,2 |
| Verre (dégâts ×2, PV ×0,5) | héros | — |
| Horde | flux ×1,5, PV ×0,7 | — |
| Sans auto-attaque | `basic_mult` 0 | recharges −30 % |
| Gel en série | durée des contrôles ×1,5 | boss insensibles (inchangé) |

  On en tire 2 non contradictoires ; gains : insignes ×1,5 d'une map de Survie (≈ 150 en époque I).

### 1.3 Builds

**DPS des 34 variantes avec 0 / 2 / 5 projectiles, Élan meurtrier en horde** : pas mesuré dans
l'atelier (règle : on mesure avec le banc E6). Le modèle du rapport 1 (1.4) suffit à fixer `proj_gain` ;
la mesure vient **après** E7, sur 3 armes témoins (Iaï, Mitraille, Pluie de flèches).

**B5 (physique / magique) : compenser ?** Non, comme dit au tour 1 : on corrige, on mesure (journal
E6), on ne compense que si une classe dépasse la médiane de +30 % de temps de map. En Duel :
régénérer les profils « opti » (`tools/gen_profiles`) et relancer l'essai `--scenario=duel`.

**Effets sur la durée non cumulables** : voulu, on le garde (sinon le poison explose en horde).

**Budget d'un certificat** : ≈ 3 cartes communes de la même stat (rapport 1, question 5 aux Builds) ;
proc ≈ une carte rare au niveau 3. Le rang II / III (P7) multiplie ce budget dans la limite du
plafond de méta (1.4).

**Combos d'états en duel** (votre §8, et question de Modes) : oui, ×1,5 au lieu de ×2, champ
`combo_mult` du profil.

### 1.4 Progression

1. **Mesures en Survie** : le journal de run (E6, coût S) est fait pour ça ; nous proposons de le
   coder **avant** tout réglage, avec **les mêmes compteurs** que les succès (P4) : `kills`,
   `elite_kills`, `boss_kills`, `deaths`, `res_used`, `gold_in` par source, `gold_out`, `chests` (or /
   clé), `anvil_max`, `trophies`, `time_map`, `time_boss`, `dmg_taken`. Une seule liste, dans
   `Profile.records` (cumul) et dans le journal (par run).
2. **Cristaux et forge** : le coût actuel n'est pas « voulu », il date d'avant la Survie. Cible E8 :
   +6 en ~2 sessions de Tour, +10 en ~15. Donc coût ÷ 3 de +1 à +6, coût actuel de +7 à +10, et
   **cristaux en Tour = votre formule** (2 + étage ÷ 20 par étage gravi, ≈ 450 de 1 à 100), ×0,75 /
   1 / 1,3 / 1,6 selon la difficulté comme la maîtrise.
3. **Plafond de puissance permanente en Survie** : talents + certificats (rangs compris) + archive +
   aura ≤ **×1,6 de puissance effective à la maîtrise 20, ×1,8 au maximum**. Mise en œuvre simple :
   un champ `meta` du profil (1 = plein) et un plafond sur la **somme** des % d'attaque et de PV de
   source méta (`run.gd:passive_stats`). En JcJ, `meta` vaut 1 mais le poids g (E3) les ramène.
4. **Rangs héroïques (P6)** : rang r = PV des monstres ×(1 + 0,12 r), dégâts ×(1 + 0,08 r), en plus de
   l'époque **séparée** PV / dégâts (E5) ; insignes ×(1 + 0,15 r). Contraintes « pacte » : nous les
   prenons dans la même liste que les modificateurs du Défi du jour (1.2), une par rang. Prix de
   l'Armurerie : inchangés (≈ 4-5 pièces par victoire en époque I, 2 en époque IV : bonne cible).

---

## 2. Accords (sans changement)

| Sujet | Équipes | Ce qui est acquis |
|---|---|---|
| Identité de build constante, chiffres par mode à un seul endroit | Builds §8, Modes §4, nous E1 | principe de l'ajout n°3 |
| Une seule règle de 1 contre 1 | Modes, nous E3.4 | `tour_duel` hérite de `duel` |
| Ce qui vit dans la run reste dans la run | Builds §8 | cartes, trophées, armes de run : Survie, Tour, Donjon, Défis ; jamais en JcJ |
| Donjons : équipement du hub synchronisé (option A) | Modes M2, nous E4, Progression P5 | profil `donjon`, `gear = "sync"` |
| Projectile supplémentaire normalisé `proj_gain`, effet légendaire au niveau 4 | Builds B3, nous E7 | nos chiffres +40 à +60 % ; B3 pour la fréquence |
| Trophées « à l'impact » avec recharge | Builds B8, nous E7 | **5 s** (Double frappe 1 s), chance ×1,5 |
| Lame large plafonnée +100 % | B13, nous E7 | reste commune |
| Cartes retirées au plafond | B1, nous E7 | — |
| Tour = source de cristaux et de joaillerie | P5, M3, nous E8 | formule de Progression |
| Champ de bataille 10v10 retiré du menu | Modes M6 | nous retirons son profil |
| Pas de cerveau en Survie ni en Donjon | Modes §4 | — |
| Records gardés dans tous les modes | P1g, M0 | règle commune du socle |
| Duel : un peu de maîtrise par victoire | M4 | 40 + 20 × rang de Ligue (≈ 1/10 d'une map) |

---

## 3. Conflits : position et compromis

### 3.1 Panthéon des cerveaux : à quelles conditions ?

- Progression P8 : règles du duel, l'adversaire **copie ton équipement et tes bonus**.
- Modes M4 : au **niveau du cerveau** ou avec les plafonds JcJ, « à valider ».
- Nous (E3.5) : **conditions d'entraînement** (niveau 10, sans équipement, sans `PvpCaps`).

**Le fait qui tranche** : un cerveau a appris un jeu précis (niveau 10, sans équipement, sans
plafonds, `ml_arena.gd:429`). Dans d'autres conditions, il joue un jeu qu'il ne connaît pas : il
devient soit plus faible (défi raté), soit imprévisible. « Copier ton équipement » le fait sortir de
ses conditions **et** rend le défi dépendant du stuff, ce que P8 veut justement éviter.

**Compromis proposé (profil `pantheon`)** : les **deux** héros jouent la **fiche d'entraînement** :
niveau 10, équipement neutre identique des deux côtés (aucun), `meta` 0 (ni talents ni certificats ni
archive), sorts = le kit de la classe comme `MlArena._pick_kit`, règles de l'arène, **plus**
l'acharnement (30 s, pour finir les manches). C'est « seul le jeu compte », au sens fort. Le joueur
garde sa classe et son preset de sorts (le cerveau a joué les 60 classes). Validation : `IA_Duel.bat`
du cerveau contre l'IA scriptée Hardcore sous ce profil = taux de victoire de l'entraînement (±5 %).
**Si le joueur préfère « mon vrai héros contre le cerveau »** : une étape d'entraînement de plus
(`--scenario=duel`, niveau 90, builds opti), sans nouvelle observation ; c'est un chantier L
(entraînement), pas un réglage.

Conséquence pour M3 (cerveaux aux étages 50 / 100 / 150 / 200 de la Tour) : même problème. Ces
duellistes jouent **sous le profil `pantheon`** (l'étage passe en « fiche d'entraînement », annoncé
sur la page des étages), ou bien on y met l'IA scriptée Hardcore. À trancher avec Modes ; nous
préférons la 1re option (avant-goût fidèle du Panthéon).

### 3.2 Durées des Donjons et des boss

- Modes : donjon 8-12 min, boss 1 min 30 à 3 min ; nous : donjon 10-15 min, boss 2-4 min.
- **Nous nous alignons sur Modes** (un donjon court se rejoue, c'est sa fonction de source de butin
  ciblé). Ajustement : **boss 1 min 30 à 2 min 30 en Normal, 2 à 3 min en Mythique** ; rage du boss
  à 3 min (et non 4) en Normal / Héroïque, 3 min 30 en Mythique.
- Survie : nous prenons la cible de Modes (map ~12 min, run 30-45 min) ; notre cible « boss de map
  60-120 s » reste.

### 3.3 Duels de la Tour : acharnement et PV ×0,45

Nous proposions « pas d'acharnement en Tour » ; mais le duelliste à 45 % de PV sous les règles du
Duel tomberait en ~25 s, et un duel sans acharnement entre héros défensifs peut ne pas finir.
**Compromis** : `tour_duel` = profil `duel` avec `gear_weight` 0,75, PV du duelliste **×0,6** (au
lieu de 0,45 : l'échelle `PvpCaps` est plus lente que `hero_vs_hero_factor`), acharnement **à 45 s**.
Cible : 20 à 45 s par duel (contrat E2). À vérifier par l'essai `--scenario=duel` à 3 niveaux.

### 3.4 Cartes en Donjon

Builds : mini-Survie (cartes de run) ; Modes : preset + une carte par salle ; notre E4 laissait
deux jeux de chiffres. **On prend Modes** : 12 sorts du preset, **1 carte par salle** (3-4) et
1 à la mort de l'élite de salle, rareté relevée d'un cran (pas de commune) ; pas de trophée ni
d'enclume. Donc **un seul jeu de chiffres** : PV des monstres ×1,8 (entre Survie 2,4 et « sans
cartes » 1,6), dégâts ×1,6, élites ×2,5, boss ×25 à pleine force avec ses mécaniques.

### 3.5 Ouverture des Donjons (avis, pas notre décision)

Progression : époque II ; Modes : boss de la zone battu en Survie. Pour l'équilibrage, **celle de
Modes convient mieux** : le niveau Normal du donjon = niveau de la zone que le joueur vient de
battre, donc sa puissance est déjà à la hauteur. Héroïque et Mythique s'ouvrent ensuite (Normal
gagné, puis Héroïque gagné).

### 3.6 Variante d'arme qui change au coffre (B3) et `proj_gain`

Pas de conflit de fond. Précision : `proj_gain` est porté **par la variante**, donc garder la
variante (B3) est nécessaire pour que le gain reste lisible ; d'accord.

---

## 4. Imbrications et fusions

### 4.1 E1 + M0 : un seul socle « activité + profil »

| Couche | Porteur | Contenu | Fichier |
|---|---|---|---|
| Fiche | Modes / Interface | id, groupe, nom, image, `unlock` (P2), « Rapporte » (P5), durée, **`rules` = clé du profil** | `ui/activities.gd:LIST` |
| Déroulé | Modes | `start`, directeur, `on_hero_down`, `on_level_up`, `cards_at_start`, `finish`, `keeps_records` | `core/activity.gd` (base) + `tower.gd`, `duel.gd`, `training.gd`, `survival.gd` |
| **Chiffres** | **Équilibrage** | profils nommés, valeurs par défaut = chiffres actuels, surcharges du mode dev et des modificateurs | **`core/mode_rules.gd`** |

- Règle : le déroulé ne contient **aucun chiffre d'équilibrage** ; il lit `ModeRules.cur.<champ>`.
  Les champs « structurels » de M0 (source des sorts, source de l'équipement, résurrections, niveau)
  vont dans le **profil** (ce sont aussi des réglages qu'on veut changer sans code : un Défi « une vie »
  est une surcharge `res` 0).
- `ModeRules.cur` est posé par `Activity.start` (profil + surcharges) : on supprime les tests
  `Run.survival / Tower.active / Duel.active` **pour les chiffres** (`pvp_caps.gd`, `combatant.gd`,
  `monster.gd`, `run_director.gd:_spawn_monster`).
- Envoi en 2 temps (un seul bloc de conception) : **(a)** rangement sans changement visible (valeurs
  actuelles, `test_farm` et `test_pvp` identiques) ; **(b)** changements de valeurs (E3, E5, E7),
  chacun dans son envoi.
- Coût : **M** (a) pour les deux équipes ensemble, au lieu de M + M.

### 4.2 E4 + M2 : Donjons

Format = M2 (8 donjons, Normal / Héroïque / Mythique, 3-4 salles, butin de panoplie, plans).
Chiffres = profil `donjon` (section 5), cartes selon 3.4, durées selon 3.2. Le butin d'équipement des
monstres hors Survie (code mort, E9) **n'est pas supprimé** tant que M2 n'a pas choisi : il peut
servir aux salles. Coût de fabrication des plans : Progression ; nous proposons un ordre de grandeur :
éclats d'un donjon Normal ≈ 10, plan d'une pièce mythique = 60 éclats + 200 cristaux, légendaire
150 éclats + 500 cristaux (≈ 6 et 15 donjons).

### 4.3 E3 + M4 (Ligue, Panthéon, Gantelet) + P8

| Activité | Profil | Poids de l'équipement g | Particularités |
|---|---|---|---|
| Duel libre | `duel` + surcharges de l'éditeur (PV ×, dégâts ×) | 0,5 | aucune récompense, donc surcharges libres |
| Ligue (Bronze → Platine) | `duel` | 0,5 | adversaire = build opti, surcharges interdites |
| Panthéon | `pantheon` | 0 (fiche d'entraînement) | voir 3.1 |
| Gantelet 1 contre 2 / 3 | `gantelet` = `duel` + « pris pour cible » ×0,8, adversaires PV ×0,6 (1v2) / ×0,45 (1v3), `hit_cap` 0,15 | 0,5 | cerveaux en 1v2 seulement (préréglage `duo` connu) |

g = 0,75 (« duel libre où la forge paie ») n'est plus proposé pour le Duel : il ne sert qu'à la Tour.
Question au joueur maintenue (rapport 1, Q2), mais on la pose **une seule fois** : « en Ligue,
l'équipement compte un peu (0,5) ou pas du tout (0) ? ».

### 4.4 E5 + P6 (rangs héroïques) + M1a (Défi du jour)

Même mécanisme : PV et dégâts des monstres **séparés** (`epoch_hp`, `epoch_atk`), multipliés par le
rang (1.4), plus des **modificateurs** pris dans une liste unique (1.2). Une contrainte de rang
héroïque = un modificateur du Défi = une surcharge du profil `survie`. Une seule liste à écrire.

### 4.5 E6 + P4 : compteurs uniques (1.4, point 1)

### 4.6 E7 + B1 / B3 / B8 / B13 : un seul envoi « garde-fous » (S), chiffres de E7, fréquence de B3.

### 4.7 E8 + P5 / P9 / M3 : cristaux de Tour, coût de forge ÷ 3 jusqu'à +6, insignes ×1,5 au Défi.

### 4.8 Profil `tutoriel` (rapport 1, §6) : **abandonné**. L'époque I fait déjà ce travail (1.1), et
I1 apprend dans la vraie Survie : un profil de plus pour rien.

---

## 5. Ajout n°3 — équilibrage distinct par mode : version consolidée (pilote)

### 5.1 Principe (en une phrase pour le joueur)

« Ton héros joue pareil partout ; chaque mode a **sa** fiche de chiffres (force des monstres, poids
de l'équipement, soins, durée des combats), à un seul endroit, visible sur la page du mode et
réglable dans le mode dev. »

### 5.2 Les profils (valeurs proposées ; « = » = valeur actuelle du code)

| Champ | `survie` | `tour` | `donjon` | `duel` | `tour_duel` | `pantheon` | `gantelet` | `entrainement` |
|---|---|---|---|---|---|---|---|---|
| Équipement (`gear`) | run (+0 au niveau) = | sync = | sync | norm = | sync | aucun (niv. 10) | norm | choisi = |
| Sorts | cartes = | 1 carte + cartes = (reprise : 1.2) | preset + 1 carte / salle | preset = | — | kit d'arène | preset | panneau = |
| Cartes / trophées / enclume | oui / oui / oui = | oui / 1 par 10 ét. / non | 1 par salle / non / non | non | — | non | non | panneau |
| Méta (`meta`) | 1, plafond ×1,6-1,8 | 1 | 1 | 1 (ramené par g) | 1 | **0** | 1 | 1 |
| Résurrections | 1 = | 0 = | 1 | — | — | — | — | ∞ |
| PV / dégâts des monstres | 2,4 / 1,6 = | = (`Tower.RULES`) | **1,8 / 1,6** | — | — | — | — | = |
| Élite PV, boss PV | 1,6 ; 14 = | = ; 0,3 × donjon = | 2,5 ; **25** | — | — | — | — | = |
| Époques PV / dégâts | **1-1,35-1,75-2,2 / 1-1,25-1,5-1,75** | — | difficulté : niv. +0 / +15 / +30 | — | — | — | — | — |
| `stage_dmg`, `EARLY_EASE` | 1.1 | — | — | — | — | — | — | — |
| Rage | 10 min = | — | boss 3 min (Myth. 3 min 30) | — | — | — | — | non |
| Échelle JcJ `dmg_scale` | — | — | — | 0,012 = | 0,012 | — | 0,012 | — |
| Poids de l'équipement g | — | — | — | 0,5 = | **0,75** | 0 | 0,5 | — |
| Plafond par coup | — | — | — | 0,2 = | 0,2 | 0,2 | 0,15 | — |
| Soins | 1 | 1 | 1 | 0,35 = | 0,35 | 1 (arène) | 0,35 | 1 |
| Auto-attaque héros contre héros | — | — | — | ×0,7 sans contrôle = | idem | 1 (arène) | idem | = |
| Acharnement | — | — | — | 30 s, ×2 / 20 s = | **45 s** | 30 s | 40 s | — |
| Contrôles (`cc_mult`, `cc_chain`) | 1, non | 1, non | 1, non | **0,7, oui** | 0,7, oui | 1, non (arène) | 0,7, oui | = |
| Combos d'états | ×2 = | ×2 | ×2 | **×1,5** | ×1,5 | ×2 | ×1,5 | = |
| Plafonds de stats | — | — | — | dégâts / durée **+100 %**, zone **+50 %**, autres = | idem | = arène | idem | — |
| PV de l'adversaire héros | — | — | — | 1 | **0,6** | 1 | 0,6 / 0,45 | = |
| Gains | maîtrise, insignes = | maîtrise =, **cristaux** | éclats, pièce de panoplie, plans | — / Ligue : maîtrise | — | titres, panoplie | titres | rien |

Les **Défis** (M1a, M1c) et les **rangs héroïques** (P6) ne sont pas des profils : ce sont
`survie` + surcharges (1.2, 1.4). La Ruée des boss (M1c) : `survie` + « boss seulement », PV des
boss ×0,8 (6 cartes au départ, 3 entre deux boss : moins de build qu'à la fin d'une map), cible
1 min 30 par boss. `arene` (2v2 / 3v3) : profil réservé, valeurs du rapport 1 (E3.6) gardées en
note, rempli seulement si M6 est lancé.

### 5.3 Contrat chiffré (E2 ajusté avec Modes)

| Activité | Cible | Contrôle |
|---|---|---|
| Survie | map ~12 min, run 30-45 min ; boss de map 60-120 s ; un monstre normal tue en 20-25 coups (É I) → 15-18 (É IV, avec E5) | journal E6 |
| Tour | étage de vagues 30-60 s ; duelliste 20-45 s ; boss 60-90 s | `Tower.RULES` + journal |
| Donjon | 8-12 min ; salle 20-40 s ; boss 1 min 30-2 min 30 (Myth. 2-3 min) ; pièces +0 : boss juste avant la rage ; +10 gemmées : ~1 min | banc E6 |
| Duel, Ligue | manche 30-90 s à tout niveau (tenu en 0.1.118) | `--scenario=duel` niveaux 25, 60, 90 |
| Panthéon | manche 45-90 s ; cerveau = son taux d'entraînement ±5 % | `IA_Duel.bat` |
| Défi du jour, Ruée | ~10 min ; ~1 min 30 par boss | journal |

### 5.4 Où on le voit et où on le règle

- **Page de l'activité** (Interface I3) : « Règles : … » en une ligne générée (1.1).
- **Mode dev** : une page « Modes » (copie de la page Tour : nom, valeur, pas, « valeurs d'origine »),
  surcharges dans `data/dev_edits.json → "modes"` ; `Tower.RULES` y est rangé tel quel (la page Tour
  reste pour les réglages par étage).
- **Arène d'IA** : aucune observation ajoutée ; `pantheon` reproduit ses conditions.

### 5.5 Ce que l'ajout n°3 ne fait pas

Pas de stats différentes **par classe** selon le mode (on règle des règles, pas des classes) ; pas de
sort qui change d'effet selon le mode (Builds §8) ; pas de nouveau calcul de dégâts : `PvpCaps` est
généralisé, pas remplacé.

---

## 6. Ce que nous ajustons ou abandonnons

| Rapport 1 | Tour 2 |
|---|---|
| E1 profils (M) | **fusionné avec M0** (4.1), coût M partagé |
| E2 durées des Donjons 10-15 min, boss 2-4 min | **alignées sur Modes** (3.2) |
| E3.4 Tour sans acharnement, PV ×0,45 | acharnement 45 s, PV ×0,6 (3.3) |
| E3.5 Panthéon « conditions d'entraînement » | gardé, précisé : fiche d'entraînement **pour les deux héros** (3.1) |
| E3.1 g = 0,75 « duel libre » | **abandonné** pour le Duel ; g 0,75 réservé à `tour_duel` |
| E3.6 Arènes et Champ | Champ **abandonné** ; Arènes en attente de M6 |
| E4 deux jeux de chiffres selon les cartes | **un seul** (3.4) |
| Profil `tutoriel` | **abandonné** (4.8) |
| E5 `stage_dmg` | précisé par époque (1.1), boss compris |
| E9 suppression du butin hors Survie | **suspendue** jusqu'au format M2 |

---

## 7. Liste mise à jour des propositions

| # | Proposition | Coût | Avec | Ordre |
|---|---|---|---|---|
| E6a | Journal de run, compteurs communs avec les succès | S | Progression P4 | 1 |
| E9 | Ménage (`ZONE_MAX_LEVEL`, commentaires faux de `pvp_caps.gd`, `run_director.gd:606`) ; butin hors Survie suspendu | S | Interface I7 | 1 |
| E1+M0 (a) | Socle activité + `mode_rules.gd`, valeurs actuelles, aucun changement visible | M | Modes | 2 |
| E7 | Garde-fous (projectiles normalisés, Élan meurtrier, trophées 5 s, Lame large, plafonds) | S | Builds B1, B3, B8, B13 | 3 |
| E3 | JcJ : g, % ramenés, contrôles partagés, combos ×1,5, `tour_duel`, `pantheon` | M | Modes M4, Progression P8 | 3 |
| E5 | Époques PV / dégâts séparés, `stage_dmg` par époque, `EARLY_EASE` map 1 | S | Interface I1 | 4 (après le ressenti du joueur à l'époque II) |
| E8 | Cristaux de Tour, forge ÷ 3 jusqu'à +6, insignes des Défis et rangs | S | Progression P5, P6, P9 | 4 |
| E10 | Surcharges : modificateurs du Défi = contraintes des rangs héroïques (une liste) | S | Modes M1a, Progression P6 | 5 |
| E4 | Profil `donjon` et coûts des plans | S (chiffres) | Modes M2 (M) | 6 |
| E6b | Banc d'essai headless (5 classes × 4 époques) | M | session locale | 6 |
| E3.6 | Profil `arene` | S | Modes M6 (L) | si M6 |

Ordre : **mesurer (E6a, E9) → ranger (E1+M0 a) → corriger (E7, E3) → régler au ressenti (E5, E8) →
nouveaux contenus (E10, E4) → banc (E6b)**.

---

## 8. Questions qui restent au joueur (fusionnées avec les autres équipes)

1. **Panthéon** : « fiche d'entraînement » (niveau 10, rien que le jeu) ou « ton vrai héros »
   (demande un nouvel entraînement des cerveaux) ?
2. **Ligue de Duel** : l'équipement compte un peu (aujourd'hui) ou pas du tout ?
3. **Époque II** : les monstres « frappent trop » ou « tiennent trop » ? (choisit entre E5 dégâts et PV)
4. **Or** : ouvres-tu presque tous les coffres d'une map ?

---

## Résumé (5 lignes)

1. **E1 + M0 fusionnés** : `Activity` (Modes, le déroulé) nomme un profil de `ModeRules` (nous, les chiffres) ; 1er envoi = rangement sans changement visible, puis les réglages un par un.
2. **Ajout n°3 consolidé** : 8 profils (Survie, Tour, Donjon, Duel, duels de la Tour, Panthéon, Gantelet, entraînement) dans un tableau unique ; Défis et rangs héroïques = Survie + surcharges d'une seule liste de modificateurs.
3. **Conflits tranchés** : Panthéon = fiche d'entraînement pour les deux héros (seul cadre où un cerveau joue juste) ; Donjons 8-12 min, boss 1 min 30-2 min 30, une carte par salle, PV ×1,8 ; duels de la Tour sous `PvpCaps` avec g 0,75, PV ×0,6, acharnement à 45 s.
4. **Réponse à Interface** : `ZONE_DAMAGE` adoucit bien la 1re map (boss compris) de chaque époque, ce n'est pas voulu ; on le garde à l'époque I (tutoriel) et on l'atténue ensuite (0,8 puis 0,9), `EARLY_EASE` sur la map 1 seulement.
5. **Abandons** : Champ de bataille, profil tutoriel, g 0,75 en Duel ; ordre : journal et ménage (S) → socle (M) → garde-fous et JcJ → époques et économie au ressenti → Donjons.
