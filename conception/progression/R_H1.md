# R_H1 — Niveau de héros permanent, socle (lot H1 de `NIVEAU_HEROS.md`)

## Fait
- `game/scripts/core/hero_level.gd` (`HeroLevel`, nouveau) : état `Profile.records["hero_xp"]` (XP totale ; aucun champ ajouté
  à `profile.gd`), courbe 105 × 1,035^L (niveau 1 → 90 : 63 229 XP), écart de niveau ×0,1 à ×3, élite 4 / boss 8, +20 % à la
  victoire, migration paresseuse et idempotente (`ensure`, `start_level`), lecture (`level`, `xp_in_level`, `xp_needed`,
  `xp_left`, `progress`, `tooltip`), signaux `HeroLevel.events.xp_changed` / `level_up`, ligne du bilan (`decorate`).
- Crochets (une ligne chacun) : `ai/monster.gd` `_on_death` → `HeroLevel.on_kill` ; `core/quests.gd` `end_run` →
  `HeroLevel.settle` (le bus de fin de partie, appelé après le rechargement de la sauvegarde et avant son enregistrement par
  toutes les activités) ; `ui/results_panel.gd` `show_spec` → `HeroLevel.decorate` (tous les bilans, une fois par partie).
- `ui/hero_level_gauge.gd` (`HeroLevelGauge`, nouveau) : « Niv. N » + barre fine, infobulle, mise à jour par signal. Lobby : dans
  le badge de classe (« Héros niv. N », pour ne pas le confondre avec la maîtrise) ; écran Héros : à côté du titre.
- Lobby : carte « Niveau de héros » une seule fois pour un compte migré au-dessus du niveau 1 (« Ton héros est niveau N. Il garde
  ce niveau dans toutes les classes. »).
- Bilan : bloc Gagné en tête « Niveau de héros 34 → 36 · +2 niveaux » (infobulle : XP gagnée), ou « XP de héros · +N » ; annonce
  dorée « Ton héros passe au niveau 36. ». Rien en Survivant, Battle royale, Duel.
- Test `test_h1` (66 vérifications) : courbe, écart, modes (Survie, Tour, Donjon, Ruée, Siège oui ; Survivant, Battle royale,
  Duel, Arènes, entraînement, menu, Défi du jour, monstre tué par un monstre non), vrai monstre tué dans l'arbre, versement par
  `Quests.end_run`, ligne et annonce du bilan, vrai `ResultsPanel`, sauvegarde relue (SafeFile) et `reload_keep_records`,
  9 profils types migrés, jauge. Verts aussi : `test_p4_migration`, `test_pages`, `test_nav_screens`, `test_results`,
  `test_texts_fr`, `test_quests`, `test_p4_flow`, `test_journal` (copie de HEAD + ce lot).

## Décisions
- **XP versée au bilan, pas au kill** (conception) : le kill remplit `HeroLevel.pending`, lié à `Run.started_at` ; une partie
  quittée sans bilan (ou une nouvelle partie) l'oublie. Le versement passe par `Quests.end_run` : c'est déjà le point unique de
  fin de partie, au bon moment (après `reload_keep_records` de la Tour / des donjons, avant `save_profile`).
- **Qui compte** : `Modes.current()` ∈ survival / dungeon / tower (Ruée et Siège sont des « donjons » de la Tour) et pas le Défi du
  jour (conception §1.3 « jamais ») ; le monstre doit tomber sous les coups du camp du héros (joueur, allié IA, effet sans auteur).
- **Migration** : pièces de départ (`starter`) et du Survivant (`sv`) exclues de « la plus haute pièce portée » (sinon un compte neuf
  partirait au niveau 20-30) ; niveau d'une pièce = son niveau d'Eden (`level`, `plevel` hors pièces d'Eden), plafonné à 90 ;
  rangs héroïques : le meilleur rang toutes époques (+1 par rang) ; Mythique = un record `dungeon_<zone>_2` ou `dgb_<boss>_2` > 0.
  Compte neuf : niveau 1, aucun message.
- Les textes disent « Survie » (le renommage « Aventure » est le lot A9).

## Chiffres
Besoin : niv. 10 → 148 XP, 43 → 461, 60 → 827, 89 → 2 243 ; total pour le 90 : 63 229 (≈ 29 h au rythme mesuré par PR2).
Écart : +10 niveaux ×2,59, −10 ×0,39, bornes ×3 / ×0,1.

## Reste (lots suivants)
H3 (porter selon le niveau, « Niveau N requis »), H4 (Aventure au niveau du héros, bandes, HUD « Run N »), H5 (activités à
min(H, niveau)), H6 (Guide, tutoriel, boussole, succès `lvl_25` / `lvl_50` sur H). Tant que H4 n'est pas passé, les monstres de la
Survie restent à leurs niveaux actuels (≤ 35) : un compte migré haut gagne peu en époque I (×0,1), c'est voulu.

## Pièges
- `HeroLevel.ensure()` écrit dans `records` à la première lecture : un test qui compare `records` avant / après doit l'appeler d'abord.
- `lobby.gd` et `hero_screen.gd` avaient du travail non poussé de C1 : seuls les hunks H1 ont été mis dans l'index (blob construit
  depuis HEAD).
