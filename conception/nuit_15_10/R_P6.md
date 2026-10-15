# R_P6 — la quête commune se voit (passe P6, version 0.1.188)

Règles dans `DESIGN.md`, « La quête commune se voit ». Test : `tests/test_compass.tscn` (boussole sur 6 états de compte, bilans,
ressources, pastilles) ; `test_nav_screens` étendu (la boussole est atteignable à la manette et ouvre une page). Captures :
`tests/shot_p6.tscn` (neuf / début / avancé, 1600×900 et 1280×720), toutes regardées.

## Fait

1. **Gains des activités en pastilles** : `Activities.LIST` clé `gives` (rôle unique de chaque activité, A1 §5.3), `ui/gain_chips.gd` :
   icônes seules sur l'étiquette de la page Jouer (grisées si fermée, la condition est déjà écrite dessus), icônes + noms sous le bandeau de
   la page de l'activité. Chaque icône dit au survol où trouver la ressource et à quoi elle sert.
2. **Table des ressources** `core/resource_help.gd` : 16 ressources (insignes, cristaux, parchemins, pierres, gemmes, formules, plans, pièces,
   panoplies, Esprits, maîtrise, apparences, titres, rangs, étoiles, cartes), « où en trouver / à quoi ça sert ». Branchée sur : pied du
   lobby, bourse de l'Atelier, fournitures (`Craft.describe_key`, donc réserve, forge, marchand), compteur de plans, lignes du bilan
   (cristaux, insignes, fournitures), Forge sans cristaux (« Tu n'as pas de cristaux. Donjons, Ruée, Siège, Tour, démontage »).
3. **Boussole** `core/compass.gd` : pastille cliquable en haut du lobby, un conseil recalculé à chaque affichage. Ordre : 1re Survie ; pièce
   que « Équiper le meilleur » poserait ; pièce achetable (« 120 insignes : une pièce est achetable ») ; coffres ; manque de la classe
   (emplacement, niveau, panoplie ou Esprits, +10 / cristaux, gemmes, enchantements) avec l'activité ; échelon du fil d'éveil (« Ligue
   Argent : ouvre la Battle royale ») ; classe suivante du Registre. Jamais en partie. Un clic ouvre la bonne page (Armurerie, Forge,
   Donjon sur la zone de la panoplie, Coffres, Registre, Héros…).
4. **Bilans** : ligne « Ta quête » (`spec.quest`, `Compass.after`) sur les cinq bilans : deux gains au plus (« plan obtenu », « panoplie
   Tempête 0 / 6 : un coffre de set à ouvrir », « 90 cristaux pour la Forge »…), la suite quand il reste de la place. La liste du bilan
   se raccourcit selon la hauteur de la fenêtre (elle défile) : le bilan tient en 720 px avec la ligne.
5. **Première heure** (accueil → Survie → hub → achat → Forge), frictions corrigées :
   - après un achat à l'Armurerie, « Dans ton coffre » ne disait pas quoi faire : « À équiper : Héros > Équipement » (vert) ; la boussole
     enchaîne (« une pièce t'attend dans ton coffre ») ;
   - Forge à 0 cristal : état vide expliqué (voir 2) ;
   - texte du verrou du Siège faux (« puis atteins une puissance… » alors que le Normal est à 0 PE) ;
   - pages Donjon, Siège, Ruée : sous la difficulté choisie, jauge « Héroïque : PE requise … · la tienne … » de la première difficulté
     fermée ; Armurerie sans achat : « La Survie révèle d'autres pièces ».

## Décisions

- La boussole ne lit que le compte (profil, Registre, fil d'éveil) : aucun état enregistré, pas de « conseil ignoré » à gérer.
- Une pièce moins bonne que celle portée ne déclenche pas « équipe-la » (`Compass.spare_slot` lit `ClassGear.best_gear`) : pas d'impasse
  où le bouton ne ferait rien.
- Pastilles d'icônes seules sur les étiquettes (le nom suffit sur la page) ; icônes du menu génériques : le survol fait foi.
- Pas d'option « masquer la boussole » dans les Paramètres (`settings_menu.gd` modifié par une autre passe) : à ajouter si le joueur la trouve gênante.

## Reste / pièges

- Chaîne « Esprits » du Registre / boussole : compte des pièces des Esprits = pièces découvertes (`seen_gear`), pas portées.
- Vu en passant, hors lot : l'Armurerie affiche encore des textes de passifs en anglais (« Bone Shattered Harvest Axe : +3 % de dégâts »).
- Les tests de simulation (`test_siege`) peuvent échouer sous charge (plusieurs Godot en parallèle), repassent seuls.
- Les autres sessions ont commité des fichiers partagés avec mes modifications en cours (`lobby.gd`, `CLAUDE.md`, `test_nav_screens.gd`) :
  le `test_nav_screens` de HEAD 0.1.187 appelait la boussole avant que son code soit commité (ce commit la fournit).
