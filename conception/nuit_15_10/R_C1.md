# R_C1 — Création de personnage

Demande du joueur : « je choisis une classe mais pas mon apparence, pas la couleur des yeux, des cheveux etc., j'ai pas de nom ».

## Ce qui est fait (0.1.225)

- **Nom du héros** (`Profile.hero_name`) : 3 à 16 signes (lettres accentuées, chiffres, espace, tiret, au moins une lettre),
  filtre de mots grossiers (mots entiers pour les plus courts, « l33t » ramené aux lettres : « Conan », « Monique » passent),
  « Au hasard » (syllabes, 170 noms différents sur 200 tirages). Affiché : badge du lobby (avec le titre porté), titre de Héros,
  bilans Survie / Survivant / Duel / Battle royale (« Nom · Classe »), page Ligue, barres d'équipe des Arènes, file du Duel,
  fil de la Battle royale (`Player.display_name`), résumé de la sauvegarde à l'écran titre. Adversaires : nom de classe.
- **Visage** (`Profile.hero_look` = {hair, hair_color, eyes}, vaut pour les 60 classes, vide = celui de la classe) :
  6 coiffures, 12 couleurs de cheveux, 8 couleurs d'yeux, « Aléatoire », « Réinitialiser ». Aperçu 3D qui tourne (souris,
  molette, stick droit), cadré sur le buste.
- **Écran** `ui/hero_creator.gd` (PageScreen, une page) : après l'accueil d'un compte neuf (juste après le choix de la classe,
  avant l'échauffement), une fois pour un ancien compte (pré-rempli, « Garder tel quel »), puis Héros > « Personnage » (hors
  run ; icône seule sous 1500 px). Gratuit ; plus tard, petite confirmation « Garder ces changements ? ». Échap = rien ne change.
- Tout modèle du héros du joueur passe par `EdenModel.instantiate_hero(..., look)` (lobby, Héros, aperçus) ou `Player._dress_model`
  (en jeu). Les adversaires « fiche d'un vrai héros » (ClassRival, Tour, Panthéon) ne changent pas.

## Ce qui est personnalisable, et comment

| Élément | Possible ? | Technique |
|---|---|---|
| Coiffure | oui, 6 | les 6 coiffures du client (`assets/player/hairs/l10X_*.glb`) remplacent la pièce de cheveux de la classe |
| Couleur des cheveux | oui, 12 | variante grise de chaque coiffure (`*_a1c527.glb`, existe pour les 6) + teinte `use_tint` du shader `eden_character` |
| Couleur des yeux | oui, 8 | masque des iris tiré de la texture du visage (`tools/gen_eye_mask.py` -> `lfaces01b_eyemask.png`) + `use_eye` (nouveau, 3 lignes) |
| Tenues, chapeaux, ailes, auras, teintures | déjà là | Héros > Apparence, par classe ; se portent avec le visage choisi (testé) |
| Couleur de peau | **non** | la peau des bras / jambes est peinte dans les ~300 textures de tenues, sans masque : teinter le seul visage jurerait |
| Visage, expression | **non** | un seul visage (`lfaces01b`) ; l'autre texture de visage (`mfaces`) est celle d'une mascotte |
| Corps / sexe, taille | **non** | un seul corps (`body_m.glb`) pour les 60 classes |

Choix d'une coiffure avec la couleur « D'origine » : la coiffure dans la couleur de la classe si elle existe, sinon la variante
grise teinte de la couleur la plus proche (`HeroLook.CLASS_COLORS`).

## À demander à la session locale (assets)

1. Corps féminin (et ses coiffures / visages) depuis le client, exporté sur le même squelette que `body_m` : ouvrirait « Corps ».
2. Autres textures de visage (yeux, sourcils, bouche) : un sélecteur « Visage ».
3. Masques de peau (canal) sur les textures de tenues, ou textures de peau séparées : ouvrirait « Peau ».

## Idées d'extension

Couleurs de peau (avec 3), tatouages / marques de visage en décalque (`dye_decal` existe déjà dans le shader), cicatrices,
voix (cris d'attaque du client par corps), couleur des sourcils liée aux cheveux, nom affiché au-dessus du héros en JcJ.

## Tests et captures

`test_c1` (57 vérifications : noms, filtre, sauvegarde SafeFile et .bak, migration et valeurs abîmées, 60 classes, apparence
débloquée + visage, en jeu, adversaire inchangé, écran : aperçu, rotation, Aléatoire, Réinitialiser, Valider, Annuler,
confirmation, « Garder tel quel », manette) ; ajouts dans `test_nav_screens` (33 / 33 contrôles atteignables), `test_pages`
(tient dans 1280 × 720), `test_p4_migration`. Verts aussi : test_p2, test_texts_fr, test_p4_flow, test_p13, test_results,
test_m7, test_pvp, test_p1, test_p8. Captures : `tests/shot_c1.tscn` (`C1_RES=1280x720`, `C1_ONLY=screens`) : planches des
coiffures, couleurs, yeux et classes, écran (neuf, erreur, choix, manette, confirmation), lobby et Héros avec le nom le plus long.

## Pièges

- `PageScreen` a déjà un membre `_right` : une sous-classe ne peut pas le redéclarer.
- Un paramètre de shader jamais posé vaut `null` (`float(null)` plante) : `HeroLook._on`.
- `test_royale` (« pièce de coffre portée ») échoue dans le dossier partagé à cause du travail en cours sur l'arme secondaire
  (N2), pas de ce lot.
