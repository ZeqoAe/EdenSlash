# Refonte graphique : organisation du travail (17/10/2026)

Objectif du joueur : un jeu qui ne « sent pas l'IA » ; chaque bouton, chaque page, chaque effet travaillé comme dans un jeu
conçu en 3 ans par une équipe de 30. Méthode : des **départements** (chacun une fiche de mission, des livrables, un critère de
qualité), une **bible de style** qui prime sur tout, des **points de contrôle humains** (le joueur choisit parmi des variantes),
une **revue** indépendante avant chaque intégration.

## Règles communes
1. La bible `conception/art/BIBLE.md` fait foi (palette, polices, formes, icônes, mouvement, son). Aucun livrable ne la contredit ;
   une proposition de changement passe par la Direction artistique.
2. Une idée par écran, textes français courts, aucun pourcentage dans le texte permanent, aucune mention du jeu d'origine côté joueur.
3. Aucune image du jeu d'origine n'est copiée ou « améliorée » dans les livrables : tout est original (génération locale, procédural, dessin).
4. Rien n'est intégré au jeu sans passer la revue (capture 1280×720 et 1600×900, manette, performances, test).
5. Les assets lourds restent hors du dépôt tant qu'ils ne sont pas validés (`conception/art/` pour les essais) ; un asset validé entre
   dans `game/assets/` avec son script de fabrication (`tools/art/`) pour pouvoir le refaire.
6. Chaque département écrit un rapport court (`conception/art/R_<id>.md`) ; la production tient le tableau dans Notion.

## Départements
| Id | Département | Mission | Livrables | Dépend de |
|---|---|---|---|---|
| DA | Direction artistique | Audit de l'existant, bible de style, tokens (couleurs, espacements, courbes), planche de références, règles « à faire / à ne pas faire » | `BIBLE.md`, `tokens.json`, `AUDIT_UI.md` | — |
| LORA | Modèle de style (Kohya) | Entraîner un style maison sur nos propres images (SDXL ou équivalent libre) ; pipeline reproductible | LoRA `eden_style_v1`, jeu de données, procédure | DA (style) |
| UIK | Kit d'interface | Cadres, boutons, onglets, jauges, séparateurs, fonds : ornements générés + nettoyés, assemblés en code (9-slice, shaders), tous les états ; remplace les formes trop géométriques | thème `UiTheme` v2, pièces dans `game/assets/ui/kit/` | DA, LORA |
| TYP | Typographie et textes | Choix de 2 polices libres de droits (titres, texte), échelle typographique, ligatures, test en français (accents), lisibilité 14 px mini | polices, `UiTheme.text_size`, règles | DA |
| ILL | Illustration | Cartes d'activités, fonds de menu, écran titre, titres de zones, écrans de fin | images 960×320 et plein écran | DA, LORA |
| ICO | Icônes | Objets, sorts, talents, statuts, activités : jeu cohérent (silhouette, lumière, cadre par rareté) | atlas d'icônes | DA, LORA |
| FX | Effets visuels | Auras, attaques, impacts, sorts : sprites générés détourés, shaders, particules ; lisibilité (Settings.fx_factor) | `game/assets/fx/`, shaders | DA |
| ANI | Mouvement d'interface | Transitions d'écran, ressorts, survols, nombres animés, états vides, chargements | bibliothèque de tweens `UiMotion` | DA, UIK |
| SND | Son et musique | Retours d'interface, impacts, ambiances, musiques par mode (modèles locaux) | `game/assets/sfx/`, `music/` | DA |
| PRP | Objets 3D | Armes, coffres, décor : image → 3D (Pixal3D), nettoyage Blender, matériaux | GLB validés | DA, LORA |
| CHR | Personnages | Tenues, coiffures, skins, auras de classe : audit de l'existant, retouches, cohérence | liste de correctifs et assets | DA |
| TEC | Pipeline technique | `tools/art/` (génération en série, nettoyage GLB, détourage), import Godot, budgets (VRAM, poids, temps de chargement) | scripts, budgets | tous |
| REV | Revue | Compare chaque livrable à la bible (critique de design, accessibilité, texte), refuse ou valide | rapports de revue | tous |
| PRD | Production | Tableau Notion des départements, ordre, dépendances, points de contrôle du joueur | Notion | — |

## Vagues
1. **Fondations** : DA (audit + bible) et LORA (pipeline Kohya + jeu de données) en parallèle.
2. **Choix du joueur** : planches de variantes (style, cadres, polices, icônes) → le joueur choisit ; LORA v1 entraîné sur ses choix.
3. **Production** : UIK, TYP, ILL, ICO, FX en parallèle (4 agents au plus à la fois), REV après chaque lot.
4. **Finition** : ANI, SND, PRP, CHR, puis passe de cohérence écran par écran (REV) et intégration (TEC).
