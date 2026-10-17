"""Animations neuves sur le corps commun (squelette Bip01 d'Eden), lot CHR-2 (conception/art/R_CHR2.md).

Blender 5.2 en arrière-plan :
    blender --background --factory-startup --python tools/art/chr2_anims.py -- --out <dossier> [--only kick,seal] [--validate]
                                                                             [--render] [--blend <fichier.blend>]
Ce que fait le script :
  1. importe game/assets/player/body/body_m.glb (corps commun : 40 os, 94 animations d'Eden) ;
  2. pour chaque animation de ANIMS, évalue sa fonction de pose image par image (30 images/s) : poses-clés en repère du
     personnage (devant, gauche, haut), interpolées avec des courbes d'élan (anticipation, frappe, rebond), puis résolues sur
     le squelette : rotations du buste, visées des membres, IK analytique à deux os pour les bras et les jambes (pieds calés au
     sol, mains jointes) ; pose les clés dans une Action Blender (fichier .blend gardé : un animateur peut la reprendre) ;
  3. cuit chaque Action (la vraie évaluation de Blender, image par image) en « deltas monde » par os :
     D = P · R⁻¹ (pose dans le repère de l'armature × inverse du repos), indépendants de l'orientation des os de Blender ;
  4. écrit <out>/chr2_anims.json, lu par game/tools/chr2/chr2_anim_build.gd qui en fait une AnimationLibrary Godot aux
     chemins de pistes du corps commun (aucune conversion d'axes à deviner : alignement des repos calculé) ;
  --validate cuit aussi « attack20 » d'Eden par le même chemin (contrôle d'aller-retour : l'outil Godot la compare à
  l'originale) ; --render écrit des vignettes (Workbench) de chaque animation dans <out>/render/.
Repère de l'armature importée : haut = -Y, devant = -Z, gauche = +X (calculé au démarrage, pas supposé).
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Quaternion, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FPS = 30


def arg(name, default=None):
    for a in ARGS:
        if a.startswith("--" + name + "="):
            return a.split("=", 1)[1]
        if a == "--" + name:
            i = ARGS.index(a)
            if i + 1 < len(ARGS) and not ARGS[i + 1].startswith("--"):
                return ARGS[i + 1]
            return True
    return default


BODY = arg("body", os.path.join(ROOT, "game", "assets", "player", "body", "body_m.glb"))
OUT = arg("out", os.path.join(os.environ.get("TEMP", "."), "chr2_anims"))
os.makedirs(OUT, exist_ok=True)

# --- courbes ------------------------------------------------------------------------------------------------


def ease_io(x):  # entrée et sortie douces
    return x * x * (3.0 - 2.0 * x)


def ease_out(x):  # départ sec, arrivée douce (frappe)
    return 1.0 - (1.0 - x) ** 3


def ease_in(x):  # départ doux, arrivée sèche (armé)
    return x ** 3


def back_out(x, s=1.6):  # dépasse un peu puis revient (rebond)
    x -= 1.0
    return x * x * ((s + 1.0) * x + s) + 1.0


def lin(x):
    return x


CURVES = {"io": ease_io, "out": ease_out, "in": ease_in, "back": back_out, "lin": lin}


def lerp(a, b, k):
    if isinstance(a, (int, float)):
        return a + (b - a) * k
    return [x + (y - x) * k for x, y in zip(a, b)]


def blend_spec(a, b, k):
    """Mélange deux poses (dictionnaires imbriqués de listes / nombres) ; une clé absente d'un côté garde l'autre."""
    out = {}
    for key in set(a) | set(b):
        if key not in a:
            out[key] = b[key]
        elif key not in b:
            out[key] = a[key]
        elif isinstance(a[key], dict):
            out[key] = blend_spec(a[key], b[key], k)
        elif isinstance(a[key], str):
            out[key] = b[key] if k >= 0.5 else a[key]
        else:
            out[key] = lerp(a[key], b[key], k)
    return out


def keyed(keys, t):
    """keys = [(temps, pose, courbe vers la suivante)] : pose interpolée à l'instant t."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, p0, c), (t1, p1, _c) in zip(keys, keys[1:]):
        if t <= t1:
            x = (t - t0) / max(t1 - t0, 1e-6)
            return blend_spec(p0, p1, CURVES[c](x))
    return keys[-1][1]


# --- squelette ----------------------------------------------------------------------------------------------


class Rig:
    def __init__(self, arm):
        self.arm = arm
        bones = arm.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.order = sorted(self.rest, key=self._depth)
        h = lambda n: self.rest[n].translation.copy()
        self.U = (h("Bip01 Head") - h("Bip01 Pelvis_Nub")).normalized()
        f = (h("Bip01 L Toe0") - h("Bip01 L Foot"))
        self.F = (f - self.U * f.dot(self.U)).normalized()
        self.L = self.U.cross(self.F).normalized()
        self.root = "Bip01_Nub"
        self.seg = {}  # direction du segment (vers l'enfant) dans le repère local de repos de l'os
        child = {"Bip01 L UpperArm": "Bip01 L Forearm", "Bip01 L Forearm": "Bip01 L Hand", "Bip01 L Hand": "Bip01 L Finger1",
                 "Bip01 R UpperArm": "Bip01 R Forearm", "Bip01 R Forearm": "Bip01 R Hand", "Bip01 R Hand": "Bip01 R Finger1",
                 "Bip01 L Thigh": "Bip01 L Calf", "Bip01 L Calf": "Bip01 L Foot", "Bip01 L Foot": "Bip01 L Toe0",
                 "Bip01 R Thigh": "Bip01 R Calf", "Bip01 R Calf": "Bip01 R Foot", "Bip01 R Foot": "Bip01 R Toe0",
                 "Bip01 L Finger1": "Bip01 L Finger11", "Bip01 R Finger1": "Bip01 R Finger11",
                 "Bip01 L Finger0": "Bip01 L Finger01", "Bip01 R Finger0": "Bip01 R Finger01",
                 "Bip01 Neck": "Bip01 Head", "Bip01 Spine1": "Bip01 Neck", "Bip01 Spine": "Bip01 Spine1"}
        self.child = child
        for b, c in child.items():
            w = h(c) - h(b)
            self.seg[b] = (self.rest[b].to_3x3().inverted() @ w).normalized()
        self.length = {b: (h(c) - h(b)).length for b, c in child.items()}

    def _depth(self, n):
        d = 0
        while self.parent[n]:
            n = self.parent[n]
            d += 1
        return d

    def v(self, c):
        """Repère du personnage [devant, gauche, haut] -> repère de l'armature."""
        return self.F * c[0] + self.L * c[1] + self.U * c[2]

    def q(self, e, axes=None):
        """[tangage (penche devant +), lacet (tourne à gauche +), roulis (penche à droite +)] en degrés."""
        F, L, U = axes if axes else (self.F, self.L, self.U)
        return (Quaternion(U, math.radians(e[1])) @ Quaternion(L, math.radians(e[0])) @ Quaternion(F, math.radians(e[2])))


def solve(rig, spec):
    """Pose -> matrices de pose (repère de l'armature) de tous les os."""
    P = {}
    delta = {}
    root_rot = rig.q(spec.get("root_rot", [0, 0, 0]))
    root_pos = rig.v(spec.get("root_pos", [0, 0, 0]))
    rots = spec.get("rot", {})
    aims = spec.get("aim", {})
    ik = spec.get("ik", {})
    flat = spec.get("flat", {})
    curl = spec.get("curl", {})
    done = set()  # os déjà posés par une IK (et leurs descendants) : la boucle ne les reprend pas
    for n in rig.order:
        if n in done:
            continue
        p = rig.parent[n]
        R = rig.rest[n]
        if p is None or p not in P:
            carried = R.copy()
        else:
            carried = P[p] @ rig.rest[p].inverted() @ R
        head = carried.translation.copy()
        rot = carried.to_3x3().to_quaternion()
        pd = delta.get(p, Quaternion()) if p else Quaternion()
        axes = (pd @ rig.F, pd @ rig.L, pd @ rig.U)
        Q = Quaternion()
        if n == rig.root:
            Q = root_rot
            head = head + root_pos
        if n in rots:
            Q = rig.q(rots[n], axes) @ Q
        if n in aims:
            d = rig.v(aims[n])
            if n.endswith("Hand") or n.endswith("Foot"):
                d = rig.v(aims[n])
            cur = (rot @ rig.seg[n])
            Q = cur.rotation_difference(d.normalized()) @ Q
        if n in curl:  # doigts : repli autour de l'axe gauche-droite de la main
            hand_axes = (pd @ rig.F, pd @ rig.L, pd @ rig.U)
            side = rot @ Vector((0, 0, 1))
            Q = Quaternion(side, math.radians(curl[n])) @ Q
        if n in flat:  # pied à plat, tourné du lacet donné (repos du pied × lacet)
            Q = Quaternion(rig.U, math.radians(flat[n])) @ R.to_3x3().to_quaternion() @ rot.inverted()
        M = Matrix.Translation(head) @ (Q @ rot).to_matrix().to_4x4()
        P[n] = M
        delta[n] = (M.to_3x3() @ R.to_3x3().inverted()).to_quaternion()
        # IK : quand on vient de poser la cuisse ou le bras, on oriente le membre entier vers la cible
        for side, chain in (("L", "Bip01 L Thigh"), ("R", "Bip01 R Thigh"), ("LA", "Bip01 L UpperArm"), ("RA", "Bip01 R UpperArm")):
            if n == chain and side in ik:
                done |= _ik(rig, P, delta, chain, ik[side], spec)
    return P


def _ik(rig, P, delta, upper, tgt, spec):
    """IK analytique à deux os : [upper] (cuisse / bras) et son enfant (mollet / avant-bras) vers la cible ; coude / genou
    vers le pôle. Cible : « at » en repère du personnage, relative au sol (jambes) ou au cou posé (bras, « rel »: "neck")."""
    lower = rig.child[upper]
    end = rig.child[lower]
    H = P[upper].translation.copy()
    base = Vector((0, 0, 0))
    if tgt.get("rel") == "neck" and "Bip01 Neck" in P:
        base = P["Bip01 Neck"].translation.copy()
        yaw_q = delta.get("Bip01 Spine1", Quaternion())
        A = base + yaw_q @ rig.v(tgt["at"])
        pole = yaw_q @ rig.v(tgt.get("pole", [0, 0, -1]))
    else:
        A = rig.v(tgt["at"])
        pole = rig.v(tgt.get("pole", [1, 0, 0]))
    l1 = rig.length[upper]
    l2 = rig.length[lower]
    d_vec = A - H
    d = min(max(d_vec.length, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.9995)
    dn = d_vec.normalized()
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    a = math.acos(max(-1.0, min(1.0, cos_a)))
    pn = (pole - dn * pole.dot(dn))
    if pn.length < 1e-6:
        pn = rig.F - dn * rig.F.dot(dn)
    pn.normalize()
    d1 = (dn * math.cos(a) + pn * math.sin(a)).normalized()
    K = H + d1 * l1
    d2 = (A - K).normalized()
    for bone, want in ((upper, d1), (lower, d2)):
        p = rig.parent[bone]
        carried = P[p] @ rig.rest[p].inverted() @ rig.rest[bone]
        rot = carried.to_3x3().to_quaternion()
        cur = rot @ rig.seg[bone]
        Q = cur.rotation_difference(want)
        M = Matrix.Translation(carried.translation) @ (Q @ rot).to_matrix().to_4x4()
        P[bone] = M
        delta[bone] = (M.to_3x3() @ rig.rest[bone].to_3x3().inverted()).to_quaternion()
    # les enfants du segment bas (main, pied, doigts) : reposés ici sous le membre résolu
    return {upper, lower} | _carry_subtree(rig, P, delta, end, spec)


def _carry_subtree(rig, P, delta, start, spec):
    """Repose [start] et ses descendants sous leur parent (déjà posé par l'IK)."""
    todo = [n for n in rig.order if n == start or _is_desc(rig, n, start)]
    flat = spec.get("flat", {})
    aims = spec.get("aim", {})
    curl = spec.get("curl", {})
    for n in todo:
        p = rig.parent[n]
        carried = P[p] @ rig.rest[p].inverted() @ rig.rest[n]
        rot = carried.to_3x3().to_quaternion()
        Q = Quaternion()
        if n in aims:
            Q = (rot @ rig.seg[n]).rotation_difference(rig.v(aims[n]).normalized())
        if n in curl:
            side = rot @ Vector((0, 0, 1))
            Q = Quaternion(side, math.radians(curl[n])) @ Q
        if n in flat:
            Q = Quaternion(rig.U, math.radians(flat[n])) @ rig.rest[n].to_3x3().to_quaternion() @ rot.inverted()
        M = Matrix.Translation(carried.translation) @ (Q @ rot).to_matrix().to_4x4()
        P[n] = M
        delta[n] = (M.to_3x3() @ rig.rest[n].to_3x3().inverted()).to_quaternion()
    return set(todo)


def _is_desc(rig, n, anc):
    p = rig.parent[n]
    while p:
        if p == anc:
            return True
        p = rig.parent[p]
    return False


# --- les animations du Ninja du Tourbillon -----------------------------------------------------------------
# Longueurs et instants d'impact = ceux des animations d'Eden qu'elles remplacent (le jeu cale ses coups sur
# l'animation d'Eden : longueur × 0,4 ; changer la longueur changerait le jeu, pas seulement l'image).
# Repère [devant, gauche, haut] en mètres (héros de 1,45 m avant l'échelle du jeu), angles en degrés.

def stance(lead=0.14, width=0.16, crouch=0.10, yaw=-35.0):
    """Garde basse : pied gauche devant, genoux bien fléchis, buste tourné, mains hautes devant (amplitudes exagérées :
    le corps chibi est vu de loin, un geste « réaliste » ne se lit pas)."""
    return {
        "root_pos": [0.0, 0.0, -crouch], "root_rot": [10, yaw, 0],
        "rot": {"Bip01 Spine1": [6, -yaw * 0.35, 0], "Bip01 Neck": [-6, -yaw * 0.3, 0], "Bip01 Head": [-6, -yaw * 0.25, 0]},
        "ik": {"L": {"at": [lead, width, 0.082], "pole": [1, 0.45, 0]}, "R": {"at": [-lead, -width, 0.082], "pole": [1, -0.45, 0]},
               "LA": {"at": [0.26, 0.12, 0.0], "rel": "neck", "pole": [-0.3, 1, -1]},
               "RA": {"at": [0.20, -0.10, -0.10], "rel": "neck", "pole": [-0.3, -1, -1]}},
        "flat": {"Bip01 L Foot": 20, "Bip01 R Foot": -35},
        "aim": {"Bip01 L Hand": [0.8, -0.1, 0.6], "Bip01 R Hand": [0.8, 0.2, 0.3]},
        "curl": {"Bip01 L Finger1": 40, "Bip01 L Finger11": 60, "Bip01 R Finger1": 70, "Bip01 R Finger11": 80},
    }


def guard(t):  # idle de garde (boucle 2 s) : respiration, léger balancement, rebond sur les appuis
    ph = 2 * math.pi * t / 2.0
    s = stance()
    s["root_pos"][2] += 0.012 * math.sin(2 * ph)
    s["root_rot"][2] = 2.0 * math.sin(ph)
    s["root_rot"][1] += 3.0 * math.sin(ph + 0.5)
    s["rot"]["Bip01 Spine1"][0] += 2.0 * math.sin(2 * ph + 0.6)
    s["ik"]["LA"]["at"] = [0.26 + 0.015 * math.sin(ph + 1.0), 0.12, 0.0 + 0.02 * math.sin(2 * ph + 0.4)]
    s["ik"]["RA"]["at"] = [0.20, -0.10, -0.10 + 0.015 * math.sin(2 * ph + 0.9)]
    return s


def run(t):  # course ninja penchée (boucle 0,8 s = 2 pas), bras tendus en arrière
    ph = t / 0.8
    s = {"root_rot": [40, 0, 0], "root_pos": [0.08, 0, -0.09 + 0.035 * abs(math.sin(2 * math.pi * ph))],
         "rot": {"Bip01 Spine1": [10, 8 * math.sin(2 * math.pi * ph), 0], "Bip01 Neck": [-18, 0, 0], "Bip01 Head": [-24, -5 * math.sin(2 * math.pi * ph), 0]},
         "aim": {"Bip01 L UpperArm": [-0.9, 0.32, -0.15 + 0.08 * math.sin(2 * math.pi * ph)], "Bip01 L Forearm": [-0.95, 0.2, -0.05],
                 "Bip01 L Hand": [-0.9, 0.1, -0.2],
                 "Bip01 R UpperArm": [-0.9, -0.32, -0.15 - 0.08 * math.sin(2 * math.pi * ph)], "Bip01 R Forearm": [-0.95, -0.2, -0.05],
                 "Bip01 R Hand": [-0.9, -0.1, -0.2]},
         "ik": {}, "flat": {}, "curl": {"Bip01 L Finger1": 15, "Bip01 R Finger1": 15}}
    for side, off in (("L", 0.0), ("R", 0.5)):
        u = (ph + off) % 1.0
        lat = 0.07 if side == "L" else -0.07
        if u < 0.42:  # appui : le pied file vers l'arrière au sol
            k = u / 0.42
            f, h = lerp(0.32, -0.24, k), 0.082
        else:  # vol : talon qui remonte haut derrière, genou qui passe devant
            k = (u - 0.42) / 0.58
            f = -0.24 + 0.56 * ease_io(k)
            h = 0.082 + 0.36 * math.sin(math.pi * min(1.0, k * 1.15)) * (1.0 - 0.4 * k)
        s["ik"][side] = {"at": [f, lat, h], "pole": [1, lat * 2, 0.2]}
        s["flat"]["Bip01 %s Foot" % side] = 0
    return s


def kick(t):  # coup de pied circulaire, jambe droite (0,8 s, impact à 0,32 s = attack20)
    g = stance()
    chamber = blend_spec(g, {
        "root_pos": [0.0, 0.03, -0.02], "root_rot": [-8, 40, 10],
        "rot": {"Bip01 Spine1": [-8, -5, 6], "Bip01 Neck": [0, -10, 0], "Bip01 Head": [0, -15, 0]},
        "ik": {"L": {"at": [0.02, 0.07, 0.082], "pole": [1, 0.3, 0]}, "R": {"at": [0.22, -0.14, 0.48], "pole": [0.4, -1, 0.6]},
               "LA": {"at": [0.24, 0.06, 0.04], "rel": "neck", "pole": [-0.3, 1, -1]},
               "RA": {"at": [0.10, -0.16, -0.10], "rel": "neck", "pole": [-0.3, -1, -1]}},
        "flat": {"Bip01 L Foot": 40, "Bip01 R Foot": -40}}, 1.0)
    impact = blend_spec(chamber, {
        "root_pos": [-0.04, 0.08, 0.03], "root_rot": [-20, 80, 28],
        "rot": {"Bip01 Spine1": [-10, -5, 14], "Bip01 Neck": [6, -25, -10], "Bip01 Head": [8, -30, -12]},
        "ik": {"L": {"at": [0.0, 0.06, 0.082], "pole": [1, 0.6, 0]}, "R": {"at": [0.70, -0.06, 0.66], "pole": [0, -0.6, 1]},
               "LA": {"at": [0.24, 0.24, -0.02], "rel": "neck", "pole": [-0.3, 1, -1]},
               "RA": {"at": [-0.18, -0.34, -0.24], "rel": "neck", "pole": [0, -1, 0.3]}},
        "flat": {"Bip01 L Foot": 80, "Bip01 R Foot": 30}}, 1.0)
    follow = blend_spec(impact, {
        "root_rot": [-14, 125, 20],
        "ik": {"R": {"at": [0.42, 0.42, 0.56], "pole": [0, 0.3, 1]}, "L": {"at": [0.0, 0.06, 0.082], "pole": [1, 0.8, 0]}},
        "flat": {"Bip01 L Foot": 110}}, 1.0)
    retract = blend_spec(follow, {
        "root_pos": [0.0, 0.03, -0.06], "root_rot": [2, 50, 4],
        "ik": {"R": {"at": [0.10, 0.04, 0.40], "pole": [1, 0, 0.6]}, "L": {"at": [0.02, 0.07, 0.082], "pole": [1, 0.4, 0]}},
        "flat": {"Bip01 L Foot": 55, "Bip01 R Foot": -10}}, 1.0)
    keys = [(0.0, g, "io"), (0.13, chamber, "out"), (0.32, impact, "out"), (0.45, follow, "io"), (0.62, retract, "io"), (0.80, g, "io")]
    return keyed(keys, t)


def seal(t):  # signe des mains (0,667 s = magic01 ; les doubles surgissent à 0,267 s)
    g = stance()

    def hands(lat_l, lat_r, up_l, up_r, f=0.24, aim_l=(0.3, -0.2, 1), aim_r=(0.3, 0.2, 1)):
        return {"ik": {"LA": {"at": [f, lat_l, up_l], "rel": "neck", "pole": [-0.2, 1, -0.4]},
                       "RA": {"at": [f, lat_r, up_r], "rel": "neck", "pole": [-0.2, -1, -0.4]}},
                "aim": {"Bip01 L Hand": list(aim_l), "Bip01 R Hand": list(aim_r)}}
    s1 = blend_spec(g, hands(0.02, -0.02, -0.04, -0.04), 1.0)
    s1["root_rot"] = [6, -10, 0]
    s1["curl"] = {"Bip01 L Finger1": 0, "Bip01 L Finger11": 0, "Bip01 R Finger1": 0, "Bip01 R Finger11": 0}
    s2 = blend_spec(s1, hands(0.01, -0.03, -0.07, -0.01, aim_l=(0.3, -0.1, 1), aim_r=(0.2, 1, 0.1)), 1.0)
    s3 = blend_spec(s1, hands(0.015, -0.015, 0.02, 0.02, f=0.27, aim_l=(0.15, -0.1, 1), aim_r=(0.15, 0.1, 1)), 1.0)
    s3["root_pos"] = [0.0, 0.0, -0.16]
    s3["rot"] = {"Bip01 Spine1": [14, 0, 0], "Bip01 Neck": [6, 0, 0], "Bip01 Head": [6, 0, 0]}
    s3["root_rot"] = [8, -10, 0]
    s3["ik"]["L"] = {"at": [0.10, 0.20, 0.082], "pole": [1, 0.6, 0]}
    s3["ik"]["R"] = {"at": [-0.12, -0.20, 0.082], "pole": [1, -0.6, 0]}
    keys = [(0.0, g, "io"), (0.10, s1, "io"), (0.18, s2, "out"), (0.267, s3, "back"), (0.45, s3, "io"), (0.667, g, "io")]
    return keyed(keys, t)


def throw(t):  # lancer d'étoiles en éventail, bras droit (0,9 s = shoot50, lâcher à 0,36 s)
    g = stance()
    wind = blend_spec(g, {
        "root_pos": [-0.04, 0.0, -0.12], "root_rot": [4, 60, 0],
        "rot": {"Bip01 Spine1": [8, 20, 0], "Bip01 Neck": [0, -35, 0], "Bip01 Head": [0, -35, 0]},
        "ik": {"RA": {"at": [0.08, 0.22, 0.06], "rel": "neck", "pole": [-0.5, -0.6, -1]},
               "LA": {"at": [0.34, -0.02, 0.04], "rel": "neck", "pole": [0, 1, -1]},
               "L": {"at": [0.18, 0.18, 0.082], "pole": [1, 0.5, 0]}},
        "aim": {"Bip01 R Hand": [0.2, 0.9, 0.3], "Bip01 L Hand": [1, -0.2, 0.1]}}, 1.0)
    release = blend_spec(wind, {
        "root_pos": [0.06, 0.0, -0.10], "root_rot": [18, -45, 0],
        "rot": {"Bip01 Spine1": [8, -25, 0], "Bip01 Neck": [-2, 35, 0], "Bip01 Head": [-4, 30, 0]},
        "ik": {"RA": {"at": [0.36, -0.36, 0.0], "rel": "neck", "pole": [0, -0.3, -1]},
               "LA": {"at": [0.06, 0.16, -0.14], "rel": "neck", "pole": [-0.3, 1, -1]},
               "L": {"at": [0.22, 0.16, 0.082], "pole": [1, 0.3, 0]}},
        "aim": {"Bip01 R Hand": [0.6, -0.8, 0.0]}}, 1.0)
    follow = blend_spec(release, {
        "root_rot": [16, -65, 0],
        "ik": {"RA": {"at": [0.10, -0.40, -0.12], "rel": "neck", "pole": [-0.5, -0.4, -1]}},
        "aim": {"Bip01 R Hand": [-0.2, -1, -0.2]}}, 1.0)
    keys = [(0.0, g, "io"), (0.22, wind, "in"), (0.36, release, "out"), (0.52, follow, "io"), (0.9, g, "io")]
    return keyed(keys, t)


def ult_pose(tremble=0.0, t=0.0):
    """Bras levés en V, larges (sinon la grosse tête chibi les cache), jambes écartées, buste cambré."""
    s = {"root_pos": [0.0, 0.0, -0.14], "root_rot": [-8, 0, 0],
         "rot": {"Bip01 Spine1": [-10, 0, 0], "Bip01 Neck": [-4, 0, 0], "Bip01 Head": [-6, 0, 0]},
         "ik": {"L": {"at": [0.04, 0.22, 0.082], "pole": [1, 0.9, 0]}, "R": {"at": [-0.04, -0.22, 0.082], "pole": [1, -0.9, 0]},
                "LA": {"at": [0.04, 0.34, 0.30], "rel": "neck", "pole": [0, 1, -0.2]},
                "RA": {"at": [0.04, -0.34, 0.30], "rel": "neck", "pole": [0, -1, -0.2]}},
         "flat": {"Bip01 L Foot": 30, "Bip01 R Foot": -30},
         "aim": {"Bip01 L Hand": [0.2, 0.6, 1], "Bip01 R Hand": [0.2, -0.6, 1]},
         "curl": {"Bip01 L Finger1": 10, "Bip01 R Finger1": 10}}
    if tremble:
        n = tremble * math.sin(t * 2 * math.pi * 17.0)
        m = tremble * math.sin(t * 2 * math.pi * 11.0 + 1.3)
        s["root_pos"][1] += 0.005 * n
        s["root_pos"][2] += 0.004 * m
        s["ik"]["LA"]["at"][0] += 0.008 * m
        s["ik"]["RA"]["at"][0] += 0.008 * n
    return s


def ult_charge(t):  # ultime : bras levés, charge (1,3 s, non bouclée : tenue jusqu'au lancer)
    g = stance()
    crouch = blend_spec(g, {"root_pos": [0, 0, -0.18], "root_rot": [22, 0, 0],
                            "ik": {"LA": {"at": [0.20, 0.08, -0.16], "rel": "neck", "pole": [-0.3, 1, -1]},
                                   "RA": {"at": [0.20, -0.08, -0.16], "rel": "neck", "pole": [-0.3, -1, -1]},
                                   "L": {"at": [0.04, 0.20, 0.082], "pole": [1, 0.8, 0]}, "R": {"at": [-0.04, -0.20, 0.082], "pole": [1, -0.8, 0]}}}, 1.0)
    up = ult_pose(min(1.0, max(0.0, (t - 0.3) / 0.7)), t)
    keys = [(0.0, g, "io"), (0.10, crouch, "back"), (0.30, ult_pose(), "lin"), (1.3, ult_pose(), "lin")]
    p = keyed(keys, t)
    if t > 0.3:
        p = blend_spec(p, up, 1.0)
    return p


def ult_throw(t):  # lancer de l'étoile géante (0,55 s, lâcher à 0,12 s) : fente avant, bras qui s'abattent
    g = stance()
    start = ult_pose()
    rel = blend_spec(start, {"root_pos": [0.12, 0, -0.14], "root_rot": [30, 0, 0],
                             "rot": {"Bip01 Spine1": [14, 0, 0], "Bip01 Neck": [-10, 0, 0], "Bip01 Head": [-12, 0, 0]},
                             "ik": {"LA": {"at": [0.38, 0.08, 0.02], "rel": "neck", "pole": [0, 1, -0.3]},
                                    "RA": {"at": [0.38, -0.08, 0.02], "rel": "neck", "pole": [0, -1, -0.3]},
                                    "L": {"at": [0.30, 0.16, 0.082], "pole": [1, 0.5, 0]},
                                    "R": {"at": [-0.20, -0.18, 0.082], "pole": [1, -0.5, 0]}},
                             "aim": {"Bip01 L Hand": [1, -0.2, 0.2], "Bip01 R Hand": [1, 0.2, 0.2]}}, 1.0)
    fol = blend_spec(rel, {"root_rot": [34, 0, 0], "ik": {"LA": {"at": [0.30, 0.12, -0.24], "rel": "neck", "pole": [0, 1, -1]},
                                                          "RA": {"at": [0.30, -0.12, -0.24], "rel": "neck", "pole": [0, -1, -1]}}}, 1.0)
    keys = [(0.0, start, "in"), (0.12, rel, "out"), (0.28, fol, "io"), (0.55, g, "io")]
    return keyed(keys, t)


# nom -> (fonction, longueur s, boucle, remplace, impact s)
ANIMS = {
    "ninja_guard": (guard, 2.0, True, "battle", None),
    "ninja_run": (run, 0.8, True, "move02", None),
    "ninja_kick": (kick, 0.8, False, "attack20", 0.32),
    "ninja_seal": (seal, 0.6667, False, "magic01", 0.267),
    "ninja_throw": (throw, 0.9, False, "shoot50", 0.36),
    "ninja_ult_charge": (ult_charge, 1.3, False, "", None),
    "ninja_ult_throw": (ult_throw, 0.55, False, "", 0.12),
}

# --- Blender ------------------------------------------------------------------------------------------------


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BODY)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    if arm.animation_data is None:
        arm.animation_data_create()
    return arm


def author(arm, rig, name, fn, length, loop):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    n_frames = int(round(length * FPS))
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for f in range(n_frames + 1):
        t = min(f / FPS, length)
        if loop and f == n_frames:
            t = 0.0
        P = solve(rig, fn(t))
        for n in rig.order:
            if n not in P or n.startswith("Bone_"):
                continue
            p = rig.parent[n]
            R = rig.rest[n]
            local_rest = (rig.rest[p].inverted() @ R) if p else R
            parent_pose = P[p] if p else Matrix.Identity(4)
            mb = local_rest.inverted() @ parent_pose.inverted() @ P[n]
            pb = arm.pose.bones[n]
            pb.matrix_basis = mb
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
            if n == rig.root:
                pb.keyframe_insert("location", frame=f + 1)
    return act


def bake(arm, rig, act, length, fps_src, start=1.0):
    """Évaluation de Blender image par image -> deltas monde par os."""
    arm.animation_data.action = act
    ad = arm.animation_data
    if hasattr(ad, "action_slot") and ad.action_slot is None and len(act.slots):
        ad.action_slot = act.slots[0]
    scene = bpy.context.scene
    n = int(round(length * FPS))
    frames = []
    names = [b for b in rig.order if b == rig.root or (b.startswith("Bip01 ") and b not in ("Bip01 NonAccum", "Bip01 Pelvis"))]
    for i in range(n + 1):
        t = min(i / FPS, length)
        fr = start + t * fps_src
        scene.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
        row = {}
        for b in names:
            D = arm.pose.bones[b].matrix @ rig.rest[b].inverted()
            q = D.to_quaternion()
            tr = D.translation
            row[b] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6), round(tr.x, 6), round(tr.y, 6), round(tr.z, 6)]
        frames.append(row)
    return frames


def main():
    arm = setup()
    rig = Rig(arm)
    scene = bpy.context.scene
    fps_src = scene.render.fps / scene.render.fps_base  # images des actions importées (glTF : 24)
    only = [x for x in str(arg("only", "")).split(",") if x]
    out = {"fps": FPS, "frame": {"F": list(rig.F), "L": list(rig.L), "U": list(rig.U)},
           "rest": {n: list(rig.rest[n].translation) for n in rig.order}, "anims": {}}
    eden = {a.name: a for a in bpy.data.actions}
    if arg("validate"):
        for name in ("attack20", "stand01"):
            act = eden[name]
            f0 = act.frame_range[0]
            length = (act.frame_range[1] - f0) / fps_src
            out["anims"]["rt_" + name] = {"length": round(length, 4), "loop": name == "stand01", "frames": bake(arm, rig, act, length, fps_src, f0)}
    for name, (fn, length, loop, replaces, hit) in ANIMS.items():
        if only and name not in only and name.replace("ninja_", "") not in only:
            continue
        act = author(arm, rig, name, fn, length, loop)
        frames = bake(arm, rig, act, length, FPS)
        out["anims"][name] = {"length": length, "loop": loop, "replaces": replaces, "hit": hit, "frames": frames}
    with open(os.path.join(OUT, "chr2_anims.json"), "w") as f:
        json.dump(out, f)
    blend = arg("blend")
    if blend:
        # actions d'Eden retirées du fichier gardé (lourd) : seules les nôtres restent, éditables
        for a in list(bpy.data.actions):
            if a.name in eden and a.name not in ANIMS:
                bpy.data.actions.remove(a)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(blend))
    if arg("render"):
        render(arm, rig, [n for n in out["anims"]])
    print("CHR2_ANIMS", len(out["anims"]), os.path.join(OUT, "chr2_anims.json"))


def render(arm, rig, names):
    """Vignettes Workbench : 8 images par animation, de trois quarts face et de profil."""
    import bpy_extras  # noqa: F401
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 240
    scene.render.resolution_y = 300
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for o in bpy.data.objects:
        if o.name == "Icosphere":
            o.hide_render = True
    mw = arm.matrix_world
    center = mw @ (rig.U * 0.72)
    U = (mw.to_3x3() @ rig.U).normalized()
    views = {"face": (rig.F * 0.8 + rig.L * -0.6), "profil": (rig.L * -1.0)}
    rdir = os.path.join(OUT, "render")
    os.makedirs(rdir, exist_ok=True)
    for name in names:
        act = bpy.data.actions.get(name) or bpy.data.actions.get(name.replace("rt_", ""))
        if act is None:
            continue
        arm.animation_data.action = act
        ad = arm.animation_data
        if hasattr(ad, "action_slot") and ad.action_slot is None and len(act.slots):
            ad.action_slot = act.slots[0]
        f0, f1 = act.frame_range
        for vname, vd in views.items():
            d = (mw.to_3x3() @ vd).normalized()
            cam.location = center + d * 6.0
            cam.rotation_mode = "QUATERNION"
            cam.rotation_quaternion = (-d).to_track_quat("-Z", "Y")
            # remet le haut de la caméra sur le haut du personnage
            for i in range(8):
                fr = f0 + (f1 - f0) * i / 7.0
                scene.frame_set(int(fr), subframe=fr - int(fr))
                scene.render.filepath = os.path.join(rdir, "%s_%s_%d.png" % (name, vname, i))
                bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
