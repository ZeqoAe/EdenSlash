# R_AC_H — L'Échiquier, lot AC-H : les effets (17/10/2026)

## Fait
- `game/scripts/core/autochess_effects.gd` (`AutochessEffects`) : la **couche d'effets d'un combat, pure** (aucun nœud),
  un seul code pour le simulateur (AC-C) et le vrai combat (AC-E / AC-U). Elle tient les PV, la mana, les boucliers, les
  bonus temporaires, les contrôles, brûlures / saignements, zones et déclencheurs ; elle résout chaque coup (esquive, parade,
  critique, défense, dégâts reçus, Fureur, plafond de 20 % hors gardiens).
- `core/autochess_items.gd` (36 objets, 8 composants, emblème), `core/autochess_traits.gd` (15 traits, paliers),
  `core/autochess_augments.gd` (atouts de combat ; `scope(id)` dit qui applique chaque atout : combat / partie / les deux).
- Test `test_ac_effects` (≈ 100 vérifications, 15 s) avec un **mini-simulateur de test** (le vrai est AC-C) : chaque objet,
  composant, emblème, trait (palier 1 contre rien, palier 3 ≥ palier 1, effets propres aux paliers hauts) et atout (12 de
  combat en mini-combat, 19 de partie sur une partie d'AC-B) a un effet mesurable ; plafonds ; aucun NaN sur des fiches
  nulles ou énormes ; aucune cascade ; ordre déterministe ; une partie entière d'AC-B jouée avec cette couche.

## Interfaces pour AC-C et AC-E (dictionnaires simples)
| Appel | Rôle |
|---|---|
| `ctx := AutochessEffects.context(fight.ctx, [board_a, board_b], base_fn)` | contexte d'un combat ; fid = ordre (camp 0 puis camp 1) ; fiche de base : champ `sheet` de l'unité, sinon `base_fn.call(unité)`, sinon `default_base` (données seules, provisoire) ; fiches finales par `apply_stats` |
| `apply_stats(unité, ctx) -> fiche` (alias SPEC : `AutochessItems.apply`) | base + traits + objets + atouts + gardien (« mult », Menace), additif puis borné (`CAPS`) |
| `start(ctx)` / `tick(ctx, dt)` | « debut_combat » ; avance le temps (`dt` quelconque, 0,1 s conseillé ; impulsions toutes les 0,5 s) |
| `attack(ctx, src, dst)` | à l'impact d'une auto-attaque : mana +10, « attaque », « esquive », « critique », « coup_recu »… |
| `can_cast` / `mana_needed` / `cast(ctx, fid)` puis `spell_hit(ctx, src, dst, base)` / `spell_heal` | sort à mana pleine ; `base` 0 = fiche `spell_base` |
| `damage(ctx, src, dst, n, opts)`, `apply_cc(ctx, src, dst, kind, dur)` | mécaniques du moteur (gardien, zones de sorts) ; Brute refuse les contrôles |
| `set_pos(ctx, fid, Vector2)` | positions en mètres (départ : `cell_pos`, camp 0 en y négatif) ; servent aux zones, rebonds, explosions |
| lecture : `hp`, `hp_max`, `mana`, `alive`, `disabled`, `stat(ctx, fid, "atk"/"as"/"reach"/"move"/…)`, `heal_mult`, `result(ctx)` | `result` = format du combat injecté d'AC-B (`winner`, `stars`, `duration`, `gold` de Fortune) |
| `on_trigger(trigger, event, ctx)` | déclencheur générique (`TRIGGERS`) ; ceux de partie (achat, debut_manche, immediat, gardien) restent dans `Autochess` |

Chaque appel rend les effets produits (`type` : damage, heal, shield, mana, cc, buff, dodge, parry, death, invuln, zone,
gold) — déjà appliqués, pour l'affichage — et deux que **le moteur exécute** : `leap` (Ombre : saut sur l'arrière ennemi) et
`recast` (Arcane à 9 : relancer le sort sans mana). Statistiques par unité dans `ctx.units[fid].stats` (dégâts, soins,
boucliers, contrôles, éliminations… : compteur de dégâts, « meilleure unité », mesures AC-J).

Pour AC-E : `Combatant.hp` = miroir de `hp(ctx, fid)` (ne pas appliquer sa propre défense : la couche l'a fait) ; vitesse
d'attaque = `stat(ctx, fid, "as")`, portée = `stat(ctx, fid, "reach")`, déplacement × `stat(ctx, fid, "move")`.

## Décisions
- **Défense** : dégâts × 100 / (100 + défense) (« def » physique, « mdef » sorts) ; la fiche de base d'AC-E doit être à
  cette échelle. **Esquive** et **parade** = chances d'éviter une auto-attaque (jamais un sort) ; l'esquive de zone de
  l'IA (AC-U) est en plus.
- Dégâts « proc » (éclairs, rebonds, renvois, ripostes, explosions, brûlures) : sans esquive ni effets d'attaque ; un renvoi
  ne renvoie jamais (Robustesse contre Robustesse : un renvoi par coup). Garde-fous : profondeur 3, 96 effets par appel.
- Deux exemplaires du même objet doublent l'ampleur, pas la fréquence ; effets « une fois » (Second souffle, Ange gardien,
  bouclier de Soif de sang) une fois. Ordre : traits (clé), objets (ordre de `ITEMS`), atouts ; fiche additive : l'ordre des
  objets et des atouts ne change rien (testé).
- Hasard : `ctx.rng` à la graine du combat, tiré seulement si la chance est entre 0 et 1.
- Choix non chiffrés par la SPEC : Tir à 6 traverse vers l'ennemi suivant (≤ 2 cases derrière, ≤ 0,6 case d'écart, 100 %) ;
  zone Élémentaire de 1 case autour de la 1re cible ; ralentissement de zone −30 % de déplacement 1 s ; Tranchant achève
  aussi par les sorts, jamais un gardien ; Malédiction vise les plus forts (PV max × attaque) ; Ferveur soigne le plus bas
  en part de PV ; Garde du corps = rangée la plus avancée puis colonne la plus centrale ; Chef de guerre = coût, puis
  étoiles, puis fid ; Fortune plafonnée à 2 or par porteur et par combat ; Brute = insensible aux contrôles 10 s.

## Reste / approximatif
- Fiches de base : `default_base` (rôle × coût × étoiles) est un remplaçant ; AC-E / AC-C donnent la vraie (Duel.rival_sheet
  ramenée à l'échelle de défense ci-dessus) et `spell_base` du vrai sort (rang compris).
- Brûlures en % des PV max (Braise, Plaies) : très fortes contre un gardien (non plafonnées par coup) ; à mesurer par AC-J.
- « Pierce », zones et explosions dépendent des positions données par `set_pos` : sans mise à jour, positions de départ.
- La SPEC demandait aussi la preuve « en combat réel (5 contre 5) » : à ajouter par AC-E dans `test_ac_fight` quand le
  directeur existe (mêmes appels que `_data_fight` du test).
