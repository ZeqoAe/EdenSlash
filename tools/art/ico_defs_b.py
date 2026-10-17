"""Icônes « tile » : tuile bonbon + symbole blanc contouré (activités, ressources, rangs, difficultés, familles, résultats, statuts).
Le symbole se dessine dans un repère 0..100 (utile : 10..90) posé au centre de la tuile."""
from ico_kit import *  # noqa: F401,F403

SOL = tone("soleil")
MAN = tone("mandarine")
POM = tone("pomme")
LAG = tone("lagon")
AME = tone("amethyste")
FRA = tone("fraise")


def pennant(s, x, y, w, h, col):
    s.inked(poly([(x, y), (x + w, y + h * 0.3), (x, y + h * 0.6)]), col, 3.5)


# =============================================================================================================
# Activités (menu Jouer)
# =============================================================================================================
A = "Activités"


@icon("act_survival", "tile", "mandarine", A, "Survie : feu de camp")
def _(s):
    wline(s, "M20 84 L80 72 M20 72 L80 84", 8, "#FFE6B0", 3.5)
    wfill(s, flame_path(50, 46, 0.78))
    s.fill(flame_path(50, 55, 0.4), SOL)


@icon("act_survivor", "tile", "lagon", A, "Survivant : éclair")
def _(s):
    wfill(s, poly(bolt_pts(50, 50, 0.82)))
    wfill(s, sparkle(20, 24, 9, 3), WHITE, 3)
    wfill(s, sparkle(80, 76, 8, 2.6), WHITE, 3)


@icon("act_dungeon", "tile", "amethyste", A, "Donjons : porte voûtée")
def _(s):
    wfill(s, "M18 88 V44 A32 32 0 0 1 82 44 V88Z")
    s.fill("M32 88 V48 A18 18 0 0 1 68 48 V88Z", INK)
    s.fill(rrect(24, 78, 52, 10, 3), tone("amethyste", 2))
    wfill(s, circ(50, 40, 5), SOL, 2.5)


@icon("act_tower", "tile", "lagon", A, "La Tour")
def _(s):
    wfill(s, rrect(30, 18, 11, 16, 2))
    wfill(s, rrect(44.5, 18, 11, 16, 2))
    wfill(s, rrect(59, 18, 11, 16, 2))
    wfill(s, rrect(28, 30, 44, 60, 4))
    s.fill("M42 74 V58 A8 8 0 0 1 58 58 V74Z", INK)
    s.fill(rrect(46, 44, 8, 8, 2), LAG)


@icon("act_quests", "tile", "soleil", A, "Quêtes : parchemin")
def _(s):
    wfill(s, rrect(24, 16, 52, 68, 8))
    s.fill(rrect(46, 28, 9, 28, 4.5), tone("fraise", 2))
    s.fill(circ(50.5, 68, 5.5), tone("fraise", 2))
    wfill(s, rrect(18, 78, 64, 10, 5), tone("mandarine", 0), 3.5)


@icon("act_rush", "tile", "fraise", A, "Ruée des boss : tête cornue")
def _(s):
    wfill(s, "M30 48 Q2 46 6 10 Q20 30 42 34Z")
    wfill(s, "M70 48 Q98 46 94 10 Q80 30 58 34Z")
    wfill(s, "M24 56 Q24 30 50 30 Q76 30 76 56 Q76 84 50 86 Q24 84 24 56Z")
    s.fill(poly([(32, 52), (46, 58), (34, 62)]), INK)
    s.fill(poly([(68, 52), (54, 58), (66, 62)]), INK)
    s.fill(rrect(40, 72, 20, 7, 3.5), INK)


@icon("act_siege", "tile", "mandarine", A, "Le Siège : muraille et fanion")
def _(s):
    s.inked_line("M50 56 V12", 5, WHITE, 3.5)
    pennant(s, 50, 10, 30, 26, tone("fraise"))
    for x in (16, 38, 60):
        wfill(s, rrect(x, 46, 24, 14, 2))
    wfill(s, rrect(16, 54, 68, 34, 3))
    s.fill("M44 88 V74 A6 6 0 0 1 56 74 V88Z", INK)


@icon("act_duel", "tile", "fraise", A, "Duel : épées croisées")
def _(s):
    white_sword(s, 50, 52, 40, 0.95)
    white_sword(s, 50, 52, -40, 0.95)


@icon("act_arena", "tile", "mandarine", A, "Arènes : amphithéâtre")
def _(s):
    wfill(s, rrect(12, 30, 76, 54, 8))
    for x in (24, 43, 62):
        s.fill("M%d 82 V56 A7 7 0 0 1 %d 56 V82Z" % (x, x + 14), INK)
    wfill(s, rrect(8, 24, 84, 12, 6), tone("mandarine", 0), 3.5)


@icon("act_royale", "tile", "soleil", A, "Battle royale : zone et couronne")
def _(s):
    s.inked_line(circ(50, 52, 34), 6, WHITE, 3.5)
    wfill(s, poly(crown_pts(50, 52, 0.46)), tone("soleil", 0), 3.5)
    wfill(s, poly(star(50, 52, 4, 6, 2, -90)), WHITE, 0.01)


@icon("act_autochess", "tile", "amethyste", A, "L'Échiquier : pion")
def _(s):
    wfill(s, circ(50, 28, 13))
    wfill(s, "M38 46 H62 Q58 58 66 76 H34 Q42 58 38 46Z")
    wfill(s, rrect(24, 74, 52, 14, 6))


@icon("act_training", "tile", "pomme", A, "Entraînement : cible")
def _(s):
    wfill(s, circ(50, 50, 36))
    s.fill(circ(50, 50, 26), tone("fraise"))
    s.fill(circ(50, 50, 17), WHITE)
    s.fill(circ(50, 50, 8), tone("fraise"))


@icon("act_league", "tile", "lagon", A, "Ligue : écu à chevrons")
def _(s):
    wfill(s, shield_path(50, 50, 62, 76))
    for dy in (0, 16):
        s.line("M32 %d L50 %d L68 %d" % (38 + dy, 54 + dy, 38 + dy), 8, tone("lagon", 2))


@icon("act_pantheon", "tile", "amethyste", A, "Panthéon : temple")
def _(s):
    wfill(s, poly([(10, 38), (50, 12), (90, 38)]))
    for x in (20, 38, 56, 74):
        wfill(s, rrect(x, 42, 10, 36, 2))
    wfill(s, rrect(10, 78, 80, 12, 4))


@icon("act_gauntlet", "tile", "mandarine", A, "Gantelet : poing")
def _(s):
    wfill(s, rrect(28, 68, 44, 22, 5))
    wfill(s, rrect(22, 30, 56, 44, 12))
    for x in (30, 43, 56, 69):
        wfill(s, circ(x, 30, 8.5), WHITE, 3.5)
    s.line("M30 52 H70", 4, INK)
    wfill(s, rrect(14, 44, 14, 20, 7), WHITE, 3.5)


# =============================================================================================================
# Ressources et monnaies (à la place des pictogrammes blancs génériques)
# =============================================================================================================
R = "Ressources"


@icon("res_insignia", "tile", "soleil", R, "Insignes : médaille à ruban")
def _(s):
    wfill(s, poly([(30, 60), (22, 90), (38, 82), (46, 94), (52, 62)]), tone("fraise"), 3.5)
    wfill(s, poly([(70, 60), (78, 90), (62, 82), (54, 94), (48, 62)]), tone("fraise"), 3.5)
    wfill(s, circ(50, 40, 28))
    s.fill(circ(50, 40, 20), tone("soleil", 0))
    s.fill(poly(star(50, 40, 5, 15, 6.5, -90)), tone("mandarine", 1))


@icon("res_plan", "tile", "lagon", R, "Plans : rouleau de plan")
def _(s):
    wfill(s, rrect(20, 20, 60, 60, 6))
    for y in (34, 48, 62):
        s.line("M30 %d H%d" % (y, 70 if y != 48 else 58), 5, tone("lagon", 2))
    wfill(s, rrect(14, 74, 72, 14, 7), tone("mandarine", 0), 3.5)


@icon("res_piece", "tile", "pomme", R, "Pièces : plastron")
def _(s):
    wfill(s, "M30 18 L42 12 Q50 22 58 12 L70 18 L90 32 L80 50 L72 44 V86 H28 V44 L20 50 L10 32Z")
    s.line("M50 28 V80", 4, tone("pomme", 2))


@icon("res_panoply", "tile", "mandarine", R, "Panoplies : casque")
def _(s):
    wfill(s, "M18 66 A32 32 0 0 1 82 66 V78 Q82 84 76 84 H24 Q18 84 18 78Z")
    s.fill(rrect(28, 60, 44, 10, 5), INK)
    s.fill(rrect(46, 22, 8, 28, 4), tone("mandarine", 2))
    wfill(s, sparkle(50, 16, 9, 3), tone("fraise"), 3)


@icon("res_spirit", "tile", "amethyste", R, "Esprits : fantôme")
def _(s):
    wfill(s, "M22 84 V46 A28 28 0 0 1 78 46 V84 L68 76 L59 86 L50 76 L41 86 L32 76Z")
    s.fill(circ(40, 48, 5.5), INK)
    s.fill(circ(60, 48, 5.5), INK)
    s.fill(circ(50, 62, 4), INK)


@icon("res_mastery", "tile", "lagon", R, "Maîtrise : livre et étoile")
def _(s):
    wfill(s, "M50 40 Q34 30 12 36 V80 Q34 74 50 86Z")
    wfill(s, "M50 40 Q66 30 88 36 V80 Q66 74 50 86Z")
    wfill(s, poly(star(50, 26, 5, 14, 6, -90)), tone("soleil"), 3.5)


@icon("res_look", "tile", "fraise", R, "Apparences : cintre")
def _(s):
    wfill(s, "M50 40 L90 70 Q96 80 86 80 H14 Q4 80 10 70Z")
    s.inked_line("M50 40 V32 Q50 20 62 20 Q72 20 72 30", 7, WHITE, 3.5)


@icon("res_title", "tile", "soleil", R, "Titres : bannière")
def _(s):
    wfill(s, "M10 26 H90 L78 46 L90 66 H10 L22 46Z")
    wfill(s, poly(star(50, 46, 5, 12, 5, -90)), tone("mandarine"), 3)


@icon("res_rank", "tile", "mandarine", R, "Rangs : chevrons")
def _(s):
    for dy in (-18, 0, 18):
        wline(s, "M24 %d L50 %d L76 %d" % (62 + dy, 38 + dy, 62 + dy), 10)


@icon("res_star", "tile", "soleil", R, "Étoiles d'époque")
def _(s):
    wfill(s, poly(star(50, 54, 5, 40, 18, -90)))


@icon("res_card", "tile", "pomme", R, "Cartes")
def _(s):
    wfill(s, poly(xf([(-22, -34), (22, -34), (22, 34), (-22, 34)], 56, 50, 14)), tone("pomme", 0), 3.5)
    wfill(s, poly(xf([(-22, -34), (22, -34), (22, 34), (-22, 34)], 44, 52, -10)))
    s.fill(sparkle(44, 52, 13, 4.5), tone("pomme"))


@icon("res_level", "tile", "pomme", R, "Niveau de héros : flèche vers le haut")
def _(s):
    wfill(s, "M50 12 L86 48 H66 V86 H34 V48 H14Z")


@icon("res_pe", "tile", "mandarine", R, "Puissance d'équipement : écu et éclair")
def _(s):
    wfill(s, shield_path(50, 50, 62, 76))
    s.fill(poly(bolt_pts(50, 50, 0.5)), tone("mandarine", 1))


# =============================================================================================================
# Rangs, difficultés, familles, résultats
# =============================================================================================================
K = "Rangs et difficultés"


def medal(s, ribbon, inner):
    wfill(s, poly([(30, 62), (20, 92), (38, 84), (46, 96), (54, 64)]), ribbon, 3.5)
    wfill(s, poly([(70, 62), (80, 92), (62, 84), (54, 96), (46, 64)]), ribbon, 3.5)
    wfill(s, circ(50, 40, 29))
    s.fill(circ(50, 40, 21), inner)


@icon("rank_0", "tile", "gris", K, "Non classé")
def _(s):
    s.inked_line(circ(50, 50, 28), 9, "#E4DFF0", 3.5)
    s.line("M38 50 H62", 8, tone("gris", 2))


@icon("rank_1", "tile", "bronze", K, "Bronze")
def _(s):
    medal(s, tone("fraise"), tone("bronze", 0))
    s.fill(poly(star(50, 40, 5, 12, 5, -90)), tone("bronze", 2))


@icon("rank_2", "tile", "argent", K, "Argent")
def _(s):
    medal(s, tone("lagon"), tone("argent", 0))
    s.fill(poly(star(50, 40, 5, 12, 5, -90)), tone("argent", 2))
    s.fill(poly(star(50, 40, 5, 12, 5, -90)), tone("argent", 2))


@icon("rank_3", "tile", "soleil", K, "Or")
def _(s):
    medal(s, tone("fraise"), tone("soleil", 0))
    s.fill(poly(star(50, 40, 5, 12, 5, -90)), tone("mandarine", 1))


@icon("rank_4", "tile", "platine", K, "Platine")
def _(s):
    medal(s, tone("amethyste"), tone("platine", 0))
    s.fill(poly(gem_pts(50, 40, 0.34)), tone("platine", 2))


def chevrons(s, k):
    top = 50 - (k - 1) * 11
    for i in range(k):
        wline(s, "M24 %d L50 %d L76 %d" % (top + i * 22 + 24, top + i * 22, top + i * 22 + 24), 10)


@icon("diff_normal", "tile", "pomme", K, "Difficulté Normal : un chevron")
def _(s):
    chevrons(s, 1)


@icon("diff_heroic", "tile", "mandarine", K, "Difficulté Héroïque : deux chevrons")
def _(s):
    chevrons(s, 2)


@icon("diff_mythic", "tile", "amethyste", K, "Difficulté Mythique : trois chevrons")
def _(s):
    chevrons(s, 3)


F = "Familles de classes"


@icon("fam_rempart", "tile", "soleil", F, "Rempart : écu")
def _(s):
    wfill(s, shield_path(50, 50, 62, 76))
    s.fill(shield_path(50, 52, 34, 46), tone("soleil", 1))


@icon("fam_ombre", "tile", "mandarine", F, "Ombre : croissant")
def _(s):
    wfill(s, "M58 14 A38 38 0 1 0 86 62 A30 30 0 1 1 58 14Z")
    wfill(s, sparkle(74, 30, 9, 3), WHITE, 3)


@icon("fam_traque", "tile", "pomme", F, "Traque : arc")
def _(s):
    wline(s, "M62 10 Q22 50 62 90", 9)
    s.inked_line("M62 10 L62 90", 3, "#FFF8EC", 2.5, shadow=False)
    wline(s, "M24 50 H84", 5)
    wfill(s, poly([(92, 50), (76, 40), (76, 60)]), WHITE, 3)


@icon("fam_ferveur", "tile", "lagon", F, "Ferveur : croix de soin")
def _(s):
    wfill(s, "M38 12 H62 V38 H88 V62 H62 V88 H38 V62 H12 V38 H38Z")


@icon("fam_arcane", "tile", "amethyste", F, "Arcane : étoile")
def _(s):
    wfill(s, sparkle(50, 50, 40, 11, 4))
    wfill(s, sparkle(22, 24, 9, 3), WHITE, 3)
    wfill(s, sparkle(80, 80, 8, 2.8), WHITE, 3)


Z = "Résultats et quêtes"


@icon("res_win", "tile", "soleil", Z, "Victoire : coupe")
def _(s):
    wline(s, "M30 28 Q10 28 14 46 Q18 58 34 56 M70 28 Q90 28 86 46 Q82 58 66 56", 6)
    wfill(s, "M26 14 H74 V42 Q74 64 50 68 Q26 64 26 42Z")
    wfill(s, rrect(43, 66, 14, 12, 3))
    wfill(s, rrect(28, 78, 44, 12, 5))
    s.fill(poly(star(50, 38, 5, 10, 4.2, -90)), tone("mandarine", 1))


@icon("res_lose", "tile", "gris", Z, "Défaite : nuage de pluie")
def _(s):
    wfill(s, "M26 62 Q12 62 14 48 Q16 36 30 38 Q32 20 52 22 Q70 22 72 38 Q88 36 88 52 Q88 62 76 62Z")
    s.line("M32 74 L28 86 M52 74 L48 86 M72 74 L68 86", 6, tone("lagon", 1))


@icon("res_draw", "tile", "lagon", Z, "Égalité")
def _(s):
    wline(s, "M22 38 H78 M22 62 H78", 11)


@icon("res_record", "tile", "soleil", Z, "Record : éclat")
def _(s):
    wfill(s, poly(star(50, 50, 9, 42, 28, -90)))
    s.fill(poly(star(50, 50, 5, 20, 9, -90)), tone("mandarine", 1))


@icon("res_flee", "tile", "mandarine", Z, "Abandon : porte et flèche")
def _(s):
    wfill(s, rrect(46, 14, 38, 72, 5))
    s.fill(rrect(54, 22, 22, 56, 3), tone("mandarine", 2))
    wline(s, "M10 50 H40 M28 36 L42 50 L28 64", 8)


@icon("quest_daily", "tile", "soleil", Z, "Défi du jour : calendrier")
def _(s):
    wfill(s, rrect(14, 22, 72, 64, 8))
    s.fill("M14 30 Q14 22 22 22 H78 Q86 22 86 30 V44 H14Z", tone("fraise"))
    s.line("M14 44 H86", 4, INK)
    wline(s, "M32 12 V28 M68 12 V28", 7)
    wfill(s, circ(50, 66, 11), tone("soleil", 1), 3)


@icon("quest_contract", "tile", "lagon", Z, "Contrats : acte à sceau")
def _(s):
    wfill(s, rrect(22, 12, 56, 72, 6))
    for y in (28, 40, 52):
        s.line("M32 %d H68" % y, 5, tone("lagon", 2))
    wfill(s, circ(62, 74, 13), tone("fraise"), 3.5)


@icon("quest_achv", "tile", "mandarine", Z, "Succès : médaille étoilée")
def _(s):
    medal(s, tone("lagon"), tone("soleil", 0))
    s.fill(poly(star(50, 40, 5, 13, 5.5, -90)), tone("mandarine", 1))


# =============================================================================================================
# Statuts qui n'avaient pas d'icône
# =============================================================================================================
S = "Statuts"


@icon("st_root", "tile", "pomme", S, "Immobilisé : racines")
def _(s):
    wline(s, "M50 12 V50 M50 50 Q30 58 22 84 M50 50 Q70 58 78 84 M50 56 V88", 8)


@icon("st_sleep", "tile", "lagon", S, "Endormi : Z")
def _(s):
    wline(s, "M24 26 H46 L24 52 H46", 8)
    wline(s, "M52 52 H76 L52 82 H76", 8)


@icon("st_fear", "tile", "amethyste", S, "Terreur : fantôme effrayé")
def _(s):
    wfill(s, "M22 86 V44 A28 28 0 0 1 78 44 V86 L66 78 L56 90 L46 78 L36 90 L28 80Z")
    s.fill(circ(40, 46, 6), INK)
    s.fill(circ(60, 46, 6), INK)
    s.fill(ell(50, 66, 6, 8), INK)


@icon("st_disarm", "tile", "gris", S, "Désarmé : épée barrée")
def _(s):
    white_sword(s, 50, 44, 35, 0.75)
    wline(s, "M18 82 L82 18", 8, tone("fraise", 1), 3.5)


@icon("st_thorns", "tile", "pomme", S, "Épines")
def _(s):
    wfill(s, "M50 12 L60 40 L88 50 L60 60 L50 88 L40 60 L12 50 L40 40Z")
    wfill(s, poly(star(50, 50, 8, 12, 6.5, -90)), tone("pomme", 1), 3)


@icon("st_titan", "tile", "mandarine", S, "Mur du titan : bloc")
def _(s):
    wfill(s, rrect(14, 20, 72, 64, 6))
    s.line("M14 52 H86 M38 20 V52 M62 52 V84", 5, tone("mandarine", 2))


@icon("st_survival", "tile", "pomme", S, "Survie : cœur")
def _(s):
    wfill(s, heart_path(50, 52, 0.62))


@icon("st_might", "tile", "fraise", S, "Puissance : poing")
def _(s):
    wfill(s, rrect(24, 28, 52, 46, 12))
    s.line("M30 52 H70", 4, INK)
    wfill(s, rrect(32, 70, 36, 18, 5))


@icon("st_swift", "tile", "lagon", S, "Célérité : aile")
def _(s):
    wfill(s, "M14 68 Q16 36 50 22 Q74 12 88 20 Q78 24 74 32 Q86 30 90 36 Q78 40 74 48 Q70 74 38 78 Q26 80 14 68Z")
    s.line("M30 66 Q46 50 64 40", 4, tone("lagon", 2))


@icon("st_grace", "tile", "amethyste", S, "Grâce de sagesse : étincelle")
def _(s):
    wfill(s, sparkle(50, 50, 40, 12, 4))
    wfill(s, circ(50, 50, 10), tone("soleil"), 3)


@icon("st_vitality", "tile", "pomme", S, "Vitalité : croix verte")
def _(s):
    wfill(s, "M38 14 H62 V38 H86 V62 H62 V86 H38 V62 H14 V38 H38Z")


@icon("st_hunter_stance", "tile", "pomme", S, "Posture du chasseur : œil de cible")
def _(s):
    wfill(s, circ(50, 50, 34))
    s.fill(circ(50, 50, 22), tone("pomme", 1))
    s.fill(circ(50, 50, 10), WHITE)
    wline(s, "M50 8 V26 M50 74 V92 M8 50 H26 M74 50 H92", 5)


@icon("st_angel", "tile", "soleil", S, "Ange gardien : ailes et halo")
def _(s):
    wfill(s, "M50 78 Q22 80 8 50 Q24 56 34 52 Q22 44 18 28 Q38 40 50 62Z")
    wfill(s, "M50 78 Q78 80 92 50 Q76 56 66 52 Q78 44 82 28 Q62 40 50 62Z")
    s.inked_line(ell(50, 22, 14, 6), 5, tone("soleil", 0), 3)


@icon("st_resolve", "tile", "soleil", S, "Résolution : écu à étoile")
def _(s):
    wfill(s, shield_path(50, 50, 62, 76))
    s.fill(poly(star(50, 48, 5, 18, 8, -90)), tone("soleil", 1))


@icon("st_bleed", "tile", "fraise", S, "Saignement : goutte")
def _(s):
    wfill(s, drop_path(50, 58, 24))
    s.fill(drop_path(50, 62, 11), tone("fraise"))
