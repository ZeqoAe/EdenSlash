# Annexe A — les 60 unités de L'Échiquier (provisoire, recalé par AC-J)

Généré depuis `game/data/classes.json` (script de conception, hors dépôt). Coût = palier de boutique (1 à 5). Famille =
trait de famille (seuils 3 / 6 / 9) ; Arme = trait d'arme (seuils 2 / 4 / 6). Portée en cases. Sort signature = proposition
automatique (parmi les sorts propres de la classe, hors sorts partagés de novice : meilleur score `mult` × rayon ; soin d'abord pour la famille Ferveur ; « n° » = rang dans `skills`) ; mana = recharge du sort × 10
(40 à 140). Rôle IA = comportement de l'IA de combat scriptée (SPEC §4.1 : tank, combattant, assassin, tireur, mage,
soigneur, soutien). Le lot AC-A écrit ces valeurs dans `data/autochess_units.json` et les relit à la main.

| Coût | id | Unité | Lignée | Famille | Arme (trait) | Portée | Place | Rôle IA | Sort signature | Mana |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `warrior` | Guerrier | verte | Rempart | Hache (Fracas) | 1 | avant | tank | Lacération (spin, n° 15) | 140 |
| 1 | `knight` | Chevalier | verte | Rempart | Rapière (Estoc) | 1 | avant | tank | Sceau des lames (spin, n° 8) | 60 |
| 1 | `thief` | Voleur | verte | Ombre | Dague (Tranchant) | 1 | avant | assassin | Embuscade (cone, n° 5) | 100 |
| 1 | `martial_artist` | Artiste martial | verte | Ombre | Gantelets (Impact) | 1 | avant | combattant | Cicatrice spirituelle (cone, n° 12) | 80 |
| 1 | `hunter` | Chasseur | verte | Traque | Arc (Tir) | 4 | arrière | tireur | Bombe flash (ground, n° 7) | 120 |
| 1 | `engineer` | Ingénieur | verte | Traque | Canon (Poudre) | 4 | arrière | tireur | Bombe gluante (ground, n° 12) | 120 |
| 1 | `cleric` | Clerc | verte | Ferveur | Sceptre (Chœur) | 3 | arrière | soigneur | Cure de vie (heal, n° 6) | 80 |
| 1 | `bard` | Barde | verte | Ferveur | Guitare (Chœur) | 3 | arrière | soigneur | Musique de vie (heal, n° 8) | 130 |
| 1 | `magician` | Magicien | verte | Arcane | Bâton (Élémentaire) | 4 | arrière | mage | Réaction de fusion (ground, n° 14) | 140 |
| 1 | `warlock` | Démoniste | verte | Arcane | Bâton de métal (Malédiction) | 3 | arrière | mage | Flèche d'ombre (bolt, n° 6) | 80 |
| 2 | `templar` | Templier | verte | Rempart | Épée (Escrime) | 1 | avant | tank | Marteau du tonnerre (spin, n° 13) | 110 |
| 2 | `dragon_knight` | Chevalier dragon | verte | Rempart | Lance (Estoc) | 2 | milieu | tank | Coup de queue du drake (cone, n° 7) | 60 |
| 2 | `shielder` | Protecteur | orange | Rempart | Épée (Escrime) | 1 | avant | tank | Coup provocant (cone, n° 12) | 80 |
| 2 | `samurai` | Samouraï | verte | Ombre | Katana (Tranchant) | 1 | avant | combattant | Lame d'Asura (fan, n° 12) | 100 |
| 2 | `blade_dancer` | Danseuse de lames | verte | Ombre | Épée (Escrime) | 1 | avant | combattant | Danse de l'oiseau de feu (spin, n° 14) | 70 |
| 2 | `assassin` | Assassin | orange | Ombre | Dague (Tranchant) | 1 | avant | assassin | Égorgement (cone, n° 12) | 80 |
| 2 | `ranger` | Rôdeur | verte | Traque | Arc (Tir) | 4 | arrière | tireur | Flèche de terreur (bolt, n° 11) | 140 |
| 2 | `inquisitor` | Inquisiteur | verte | Traque | Faux-fusil (Poudre) | 2 | milieu | tireur | Impact infernal (ground, n° 8) | 130 |
| 2 | `trainer` | Dompteur | orange | Traque | Arc (Tir) | 4 | arrière | tireur | Tir enchaîné (bolt, n° 11) | 80 |
| 2 | `shaman` | Chaman | verte | Ferveur | Bâton (Élémentaire) | 4 | arrière | soigneur | Gouttes du ciel (heal, n° 11) | 140 |
| 2 | `sage` | Sage | verte | Ferveur | Marteau (Fracas) | 1 | avant | soigneur | Aura : protection du marteau (heal, n° 8) | 140 |
| 2 | `battlefield_poet` | Chantre de guerre | orange | Ferveur | Guitare (Chœur) | 3 | arrière | soutien | Métal sombre (ground, n° 12) | 110 |
| 2 | `illusionist` | Illusionniste | verte | Arcane | Grimoire (Malédiction) | 4 | arrière | mage | Aérolithe (ground, n° 15) | 140 |
| 2 | `luminary` | Luminaire | verte | Arcane | Espadon (Impact) | 1 | avant | combattant | Formation du silence (ground, n° 12) | 80 |
| 2 | `conjurer` | Envoûteur | orange | Arcane | Bâton de métal (Malédiction) | 3 | arrière | mage | Tonnerre hanté (ground, n° 17) | 70 |
| 3 | `berserker` | Berserker | orange | Rempart | Hache (Fracas) | 1 | avant | combattant | Survie désespérée (spin, n° 15) | 120 |
| 3 | `executioner` | Exécuteur | orange | Rempart | Rapière (Estoc) | 1 | avant | combattant | Lame de sang (ground, n° 12) | 60 |
| 3 | `dawnbreaker` | Chevalier de sang | orange | Rempart | Épée (Escrime) | 1 | avant | combattant | Renaissance du sang (ground, n° 18) | 140 |
| 3 | `rakshasa` | Rakshasa | orange | Ombre | Gantelets (Impact) | 1 | avant | combattant | Vague du dragon de feu (fan, n° 11) | 80 |
| 3 | `blade_acrobat` | Danseuse d'épées | orange | Ombre | Épée (Escrime) | 1 | avant | combattant | Danse de la nuit noire (ground, n° 18) | 80 |
| 3 | `blade_master` | Maître-sabre | orange | Ombre | Katana (Tranchant) | 1 | avant | combattant | Sabre du rêve (cone, n° 14) | 100 |
| 3 | `mecha_ares` | Arès mécanique | orange | Traque | Canon (Poudre) | 4 | arrière | tireur | Anéantissement total (spin, n° 18) | 140 |
| 3 | `rifleteer` | Fusilier | orange | Traque | Faux-fusil (Poudre) | 2 | milieu | tireur | Champ du jugement (ground, n° 13) | 140 |
| 3 | `devil_hunter` | Chasseur de démons | orange | Traque | Arc (Tir) | 4 | arrière | tireur | Flèche vipérine (bolt, n° 15) | 80 |
| 3 | `druid` | Druide | orange | Ferveur | Bâton (Élémentaire) | 4 | arrière | soigneur | Source de vie (heal, n° 14) | 140 |
| 3 | `adjudicator` | Juge sacré | orange | Ferveur | Sceptre (Chœur) | 3 | arrière | soigneur | Frappe d'examen (heal, n° 11) | 140 |
| 3 | `psalmist` | Psalmiste | orange | Ferveur | Marteau (Fracas) | 1 | avant | soutien | Marteau de l'archange (cone, n° 11) | 90 |
| 3 | `arch_elementalist` | Archi-élémentaliste | orange | Arcane | Bâton (Élémentaire) | 4 | arrière | mage | Vent polaire du nord (ground, n° 12) | 130 |
| 3 | `demon_tamer` | Maître des chimères | orange | Arcane | Grimoire (Malédiction) | 4 | arrière | mage | Tempête des chimères (spin, n° 18) | 70 |
| 3 | `dark_envoy` | Émissaire des ténèbres | orange | Arcane | Bâton de métal (Malédiction) | 3 | arrière | mage | Venue de la mort (ground, n° 19) | 110 |
| 4 | `glacier_knight` | Gardien du serment | orange | Rempart | Rapière (Estoc) | 1 | avant | tank | Estoc à la cheville (cone, n° 18) | 100 |
| 4 | `dragon_soul` | Âme de dragon | orange | Rempart | Lance (Estoc) | 2 | milieu | tank | Terreur du dragon de feu (cone, n° 12) | 140 |
| 4 | `kage` | Kage | orange | Ombre | Dague (Tranchant) | 1 | avant | assassin | Corps : cyclone (spin, n° 13) | 80 |
| 4 | `elegant_dancer` | Danseuse envoûtante | orange | Ombre | Épée (Escrime) | 1 | avant | combattant | Pas étincelants (spin, n° 13) | 100 |
| 4 | `reaver` | Faucheur | orange | Traque | Faux-fusil (Poudre) | 2 | milieu | tireur | Moisson des âmes (cone, n° 13) | 120 |
| 4 | `holy_arrow` | Flèche sacrée | orange | Traque | Arc (Tir) | 4 | arrière | tireur | Désarmement céleste (fan, n° 12) | 100 |
| 4 | `equilibrian` | Prêtre de l'ombre | orange | Ferveur | Sceptre (Chœur) | 3 | arrière | soutien | Faux silencieuse (ground, n° 12) | 110 |
| 4 | `life_worshipper` | Chantre de vie | orange | Ferveur | Guitare (Chœur) | 3 | arrière | soigneur | Notes explosives (heal, n° 11) | 140 |
| 4 | `stormcaster` | Maître de la gravité | orange | Arcane | Bâton (Élémentaire) | 4 | arrière | mage | Attraction vers le bas (spin, n° 13) | 130 |
| 4 | `light_blade` | Lame de lumière | orange | Arcane | Espadon (Impact) | 1 | avant | combattant | Jour saint (ground, n° 12) | 140 |
| 5 | `paladin` | Paladin | orange | Rempart | Marteau (Fracas) | 1 | avant | tank | Marteau de tonnerre (ground, n° 16) | 80 |
| 5 | `dragon_rider` | Dompteur de dragons | orange | Rempart | Lance (Estoc) | 2 | milieu | tank | Lance dans l'âme (ground, n° 12) | 140 |
| 5 | `asura` | Asura | orange | Ombre | Gantelets (Impact) | 1 | avant | combattant | Brise-roi (cone, n° 17) | 90 |
| 5 | `master_fencer` | Héritier du sabre | orange | Ombre | Katana (Tranchant) | 1 | avant | combattant | Éclair de l'aube (spin, n° 17) | 100 |
| 5 | `annihilator` | Annihilateur | orange | Traque | Canon (Poudre) | 4 | arrière | tireur | Canon satellite (ground, n° 18) | 140 |
| 5 | `absolute_arrow` | Flèche absolue | orange | Traque | Arc (Tir) | 4 | arrière | tireur | Absolu : rafale (cone, n° 14) | 120 |
| 5 | `orator` | Orateur sacré | orange | Ferveur | Marteau (Fracas) | 1 | avant | soutien | Marteau du premier roi (cone, n° 13) | 110 |
| 5 | `archimage` | Chaman des totems | orange | Ferveur | Bâton (Élémentaire) | 4 | arrière | soutien | Contre-attaque de l'élu (ground, n° 12) | 110 |
| 5 | `chronologist` | Maître du temps | orange | Arcane | Grimoire (Malédiction) | 4 | arrière | mage | Hypnose temporelle (ground, n° 13) | 100 |
| 5 | `black_blade` | Lame noire | orange | Arcane | Espadon (Impact) | 1 | avant | combattant | Brise-démon (ground, n° 14) | 140 |

Comptes : par coût 1 : 10, 2 : 15, 3 : 15, 4 : 10, 5 : 10 ; par trait d'arme Chœur 6, Escrime 6, Estoc 6, Fracas 6, Impact 6, Malédiction 6, Poudre 6, Tir 6, Tranchant 6, Élémentaire 6 ; par rôle IA assassin 3, combattant 15, mage 9, soigneur 7, soutien 5, tank 9, tireur 12 ; 12 par famille.
