"""Essai de reciblage (lot CHR-2, conception/art/R_CHR2.md) : que devient un mouvement capté sur un corps aux proportions
adultes une fois posé sur le corps chibi (tête énorme, bras et jambes courts) ?

    blender --background --factory-startup --python tools/art/chr2_retarget.py -- --body <body_m.glb> --out <rapport.json>

Sans télécharger de banque de mouvements (droit d'usage à faire valider par le joueur), on fabrique la source : un squelette
« adulte » (copie du Bip01 aux proportions d'un corps de 7 têtes : jambes ×1,9, bras ×1,75, buste ×1,5) qui joue nos
propres gestes (tools/art/chr2_anims.py) à son échelle, comme le ferait une capture. Puis deux reciblages vers le chibi :
  A. copie des rotations (ce que fait un reciblage simple, BoneMap de Godot ou Blender) : mêmes rotations monde par os,
     bassin ramené à la hauteur des hanches ;
  B. A + correction : mains et pieds recalés par IK (positions ramenées aux longueurs des membres du chibi, mains repoussées
     hors de la tête).
Mesures par geste, comparées au geste fait directement sur le chibi (la « vérité ») : erreur de position des mains, écart
entre les deux mains (signe), mains dans la tête (pénétration), pieds sous le sol et glissement des pieds en appui.
"""
import json
import math
import os
import sys

from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("chr2_anims", os.path.join(HERE, "chr2_anims.py"))
A = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(A)
import bpy  # noqa: E402

LEG, ARM, SPINE = 1.9, 1.75, 1.5
HEAD_C = [0.135, 0.0, 1.20]  # crâne du chibi (repère du personnage), rayon moyen
HEAD_R = 0.20


def scale_of(name):
    if any(k in name for k in ("Thigh", "Calf", "Foot", "Toe")):
        return LEG
    if any(k in name for k in ("UpperArm", "Forearm", "Hand", "Finger")):
        return ARM
    if any(k in name for k in ("Spine", "Neck", "Clavicle")):
        return SPINE
    return 1.0


def make_adult(arm):
    """Copie de l'armature, chaque os éloigné de son parent selon sa famille (hanches et épaules gardent leur écart)."""
    adult = arm.copy()
    adult.data = arm.data.copy()
    bpy.context.scene.collection.objects.link(adult)
    bpy.context.view_layer.objects.active = adult
    bpy.ops.object.mode_set(mode="EDIT")
    eb = adult.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy()) for b in eb}
    new_head = {}
    order = sorted(eb, key=lambda b: len(b.parent_recursive))
    for b in order:
        h, t = old[b.name]
        if b.parent is None:
            new_head[b.name] = h
        else:
            ph = old[b.parent.name][0]
            k = scale_of(b.name) if b.name not in ("Bip01 L Thigh", "Bip01 R Thigh") else 1.0
            if "Pelvis_Nub" in b.name or b.name in ("Bip01_Nub", "Bip01 Pelvis"):
                k = LEG  # le bassin monte à la hauteur des hanches de l'adulte
            new_head[b.name] = new_head[b.parent.name] + (h - ph) * k
        b.tail = new_head[b.name] + (t - h)
        b.head = new_head[b.name]
    bpy.ops.object.mode_set(mode="OBJECT")
    return adult


def scaled_spec(spec):
    """Le même geste à l'échelle de l'adulte (cibles des jambes ×LEG, des bras ×ARM, bassin ×LEG)."""
    s = json.loads(json.dumps(spec))
    if "root_pos" in s:
        s["root_pos"] = [x * LEG for x in s["root_pos"]]
    for side, tg in s.get("ik", {}).items():
        k = ARM if side in ("LA", "RA") else LEG
        tg["at"] = [x * k for x in tg["at"]]
    return s


def copy_rotations(rig_src, P_src, rig_dst, root_scale):
    """Reciblage A : rotation monde de chaque os copiée (D = P·R⁻¹), positions portées par la hiérarchie du chibi."""
    P = {}
    for n in rig_dst.order:
        p = rig_dst.parent[n]
        R = rig_dst.rest[n]
        carried = R.copy() if (p is None or p not in P) else P[p] @ rig_dst.rest[p].inverted() @ R
        head = carried.translation.copy()
        if n in P_src:
            q = (P_src[n].to_3x3() @ rig_src.rest[n].to_3x3().inverted()).to_quaternion()
        else:
            q = Quaternion()
        if n == rig_dst.root:
            head = head + (P_src[n].translation - rig_src.rest[n].translation) * root_scale
        P[n] = Matrix.Translation(head) @ (q @ R.to_3x3().to_quaternion()).to_matrix().to_4x4()
    return P


def pos(P, n):
    return P[n].translation.copy()


def char(rig, v):
    return [v.dot(rig.F), v.dot(rig.L), v.dot(rig.U)]


def head_center(rig, P):
    """Centre du crâne suivant la tête posée (le repos HEAD_C porté par l'os de la tête)."""
    return P["Bip01 Head"] @ (rig.rest["Bip01 Head"].inverted() @ rig.v(HEAD_C))


def measure(rig, P, truth):
    hc = head_center(rig, P)
    out = {}
    hands = [pos(P, "Bip01 L Hand"), pos(P, "Bip01 R Hand")]
    out["main_tete"] = min((h - hc).length - HEAD_R for h in hands)  # < 0 : main dans la tête
    out["ecart_mains"] = (hands[0] - hands[1]).length
    out["err_mains"] = max((pos(P, n) - pos(truth, n)).length for n in ("Bip01 L Hand", "Bip01 R Hand"))
    feet = [pos(P, "Bip01 L Foot"), pos(P, "Bip01 R Foot")]
    out["pied_sol"] = min(char(rig, f)[2] for f in feet)  # hauteur de cheville ; repos 0,082
    out["pieds"] = [char(rig, f) for f in feet]
    return out


def main():
    arm = A.setup()
    rig = A.Rig(arm)
    adult = make_adult(arm)
    rig_a = A.Rig(adult)
    rig_a.root = rig.root
    report = {"proportions": {"jambes": LEG, "bras": ARM, "buste": SPINE}, "gestes": {}}
    for name in ("ninja_seal", "ninja_ult_charge", "ninja_kick", "ninja_run", "ninja_throw"):
        fn, length, loop, _r, _h = A.ANIMS[name]
        rows = {"verite": [], "A_rotations": [], "B_corrige": []}
        frames = int(length * 30)
        for f in range(frames + 1):
            t = f / 30.0
            spec = fn(t)
            truth = A.solve(rig, spec)
            src = A.solve(rig_a, scaled_spec(spec))
            pa = copy_rotations(rig_a, src, rig, 1.0 / LEG)
            # B : mêmes rotations du buste et du bassin, membres recalés par IK aux cibles ramenées au chibi
            spec_b = json.loads(json.dumps(spec))
            for side, tg in spec_b.get("ik", {}).items():
                if side in ("LA", "RA"):
                    hand = "Bip01 %s Hand" % ("L" if side == "LA" else "R")
                    rel = pos(src, hand) - pos(src, "Bip01 Neck")
                    yaw_q = (src["Bip01 Spine1"].to_3x3() @ rig_a.rest["Bip01 Spine1"].to_3x3().inverted()).to_quaternion()
                    tg["at"] = char(rig, yaw_q.inverted() @ (rel / ARM))
                    # hors de la tête : on repousse la cible à la surface du crâne
                    at_w = pos(truth, "Bip01 Neck") + yaw_q @ rig.v(tg["at"])
                    hc = head_center(rig, truth)
                    d = at_w - hc
                    if d.length < HEAD_R + 0.03:
                        at_w = hc + d.normalized() * (HEAD_R + 0.03)
                        tg["at"] = char(rig, yaw_q.inverted() @ (at_w - pos(truth, "Bip01 Neck")))
                else:
                    foot = "Bip01 %s Foot" % side
                    tg["at"] = [x / LEG for x in char(rig_a, pos(src, foot))]
            pb = A.solve(rig, spec_b)
            rows["verite"].append(measure(rig, truth, truth))
            rows["A_rotations"].append(measure(rig, pa, truth))
            rows["B_corrige"].append(measure(rig, pb, truth))
        summ = {}
        for k, r in rows.items():
            stance = []
            for side in (0, 1):  # glissement : déplacement du pied quand il est au sol (hauteur < 0,1)
                xs = [(x["pieds"][side][0], x["pieds"][side][1]) for x in r if x["pieds"][side][2] < 0.1]
                if len(xs) > 1:
                    stance.append(max(math.dist(xs[0], p) for p in xs))
            summ[k] = {
                "main_dans_tete_cm": round(-min(0.0, min(x["main_tete"] for x in r)) * 100, 1),
                "ecart_mains_min_cm": round(min(x["ecart_mains"] for x in r) * 100, 1),
                "erreur_mains_max_cm": round(max(x["err_mains"] for x in r) * 100, 1),
                "pied_sous_sol_cm": round(max(0.0, 0.082 - min(x["pied_sol"] for x in r)) * 100, 1),
                "pied_en_l_air_cm": round(max(0.0, min(max(x["pieds"][0][2], x["pieds"][1][2]) for x in r) - 0.082) * 100, 1),
                "glissement_cm": round(max(stance) * 100, 1) if stance else None,
            }
        report["gestes"][name] = summ
        print("CHR2_RT", name, json.dumps(summ, ensure_ascii=False))
    # gestes « d'adulte » (comme une banque de mouvements les contient), sans équivalent chibi : seules les mesures absolues
    base = {"root_pos": [0, 0, 0], "ik": {"L": {"at": [0.0, 0.12 * LEG, 0.082 * LEG]}, "R": {"at": [0.0, -0.12 * LEG, 0.082 * LEG]}}}
    adult_gestures = {
        "bras_leves": {"LA": [0.02, 0.12, 0.62], "RA": [0.02, -0.12, 0.62]},
        "mains_jointes_visage": {"LA": [0.30, 0.02, 0.16], "RA": [0.30, -0.02, 0.16]},
        "main_au_front": {"LA": [0.10, 0.25, -0.35], "RA": [0.20, -0.04, 0.24]},
    }
    for gname, arms in adult_gestures.items():
        spec = json.loads(json.dumps(base))
        for side, at in arms.items():
            spec["ik"][side] = {"at": at, "rel": "neck", "pole": [-0.2, 1 if side == "LA" else -1, -0.5]}
        src = A.solve(rig_a, spec)
        pa = copy_rotations(rig_a, src, rig, 1.0 / LEG)
        spec_b = json.loads(json.dumps(spec))
        for side in ("LA", "RA"):
            hand = "Bip01 %s Hand" % ("L" if side == "LA" else "R")
            rel = (pos(src, hand) - pos(src, "Bip01 Neck")) / ARM
            at_w = pos(pa, "Bip01 Neck") + rel
            hc = head_center(rig, pa)
            d = at_w - hc
            if d.length < HEAD_R + 0.03:
                at_w = hc + d.normalized() * (HEAD_R + 0.03)
            spec_b["ik"][side]["at"] = char(rig, at_w - pos(pa, "Bip01 Neck"))
        for side in ("L", "R"):
            spec_b["ik"][side]["at"] = [x / LEG for x in spec["ik"][side]["at"]]
        pb = A.solve(rig, spec_b)
        summ = {}
        for k, P in (("A_rotations", pa), ("B_corrige", pb)):
            m = measure(rig, P, P)
            summ[k] = {"main_dans_tete_cm": round(-min(0.0, m["main_tete"]) * 100, 1), "ecart_mains_cm": round(m["ecart_mains"] * 100, 1),
                       "pied_sous_sol_cm": round(max(0.0, 0.082 - m["pied_sol"]) * 100, 1)}
        report["gestes"]["adulte_" + gname] = summ
        print("CHR2_RT adulte_" + gname, json.dumps(summ, ensure_ascii=False))
    out = A.arg("rapport", os.path.join(A.OUT, "chr2_retarget.json"))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    print("CHR2_RT rapport", out)


main()
