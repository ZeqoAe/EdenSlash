"""Tête détaillée d'un héros sur le squelette Bip01 du corps commun (lot CHR-2, conception/art/R_CHR2.md).

Blender 5.2 en arrière-plan :
    blender --background --factory-startup --python tools/art/chr2_head.py -- --body <body_m.glb> --look <look.json>
            --tex <dossier des textures> --out <tete.glb> [--blend <fichier.blend>] [--render <dossier>]

Ce que fait le script (aucune image ni forme propre à un personnage n'est dans ce fichier : tout vient de --look) :
  1. visage : le visage d'Eden (#LFACE, 400 triangles, UV d'origine) subdivisé une fois (Catmull-Clark, UV lissés aux
     bords) : silhouette ronde, mêmes UV, poids transférés (Data Transfer, plus proche face) depuis le visage d'Eden ;
  2. cheveux : mèches 3D séparées (une coque effilée et courbe par mèche, section en losange, UV en bande) posées sur un
     crâne ellipsoïde, plus une calotte ; deux longues mèches de côté ont 2 os chacune (cheveux ×4, ressorts en jeu) ;
  3. bandeau : anneau d'étoffe à épaisseur, plaque de métal biseautée lisse (aucun symbole), nœud derrière, deux rubans
     de 3 os chacun (×6, ressorts en jeu) ;
  4. écrit un GLB « pièce » au format des pièces d'Eden : mêmes nœuds Bip01 (repos exacts du corps commun), maillages
     sous « Scene Root », matrices de liaison calculées (pas d'export glTF de Blender, qui réoriente les os) ; les os
     neufs sont pendus à « Bip01 Head » : EdenModel.dress les ajoute au squelette du héros au chargement.
--look (JSON) : couleurs, liste des mèches, bandeau, rubans (voir game/data/classes_custom.json -> look.premium pour la
forme). Textures attendues dans --tex : face.png, hair.png, band.png (tools/art/chr2_tex.py).
"""
import bpy
import bmesh
import json
import math
import os
import struct
import sys
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if "--" + name in ARGS:
        i = ARGS.index("--" + name)
        return ARGS[i + 1] if i + 1 < len(ARGS) and not ARGS[i + 1].startswith("--") else True
    return default


BODY = arg("body")
LOOK = json.load(open(arg("look"), encoding="utf-8")) if arg("look") else {}
TEX = arg("tex", ".")
OUT = arg("out", "chr2_head.glb")


# --- repère ---------------------------------------------------------------------------------------------------
class Frame:
    def __init__(self, arm):
        rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        h = lambda n: rest[n].translation.copy()
        self.rest = rest
        self.U = (h("Bip01 Head") - h("Bip01 Pelvis_Nub")).normalized()
        f = h("Bip01 L Toe0") - h("Bip01 L Foot")
        self.F = (f - self.U * f.dot(self.U)).normalized()
        self.L = self.U.cross(self.F).normalized()

    def v(self, c):
        return self.F * c[0] + self.L * c[1] + self.U * c[2]


def ell_point(fr, sk, az, el, scale=1.0):
    """Point du crâne ellipsoïde (az : 0 = devant, 90 = gauche ; el : 0 = équateur, 90 = sommet), et sa normale."""
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
    c = sk["center"]
    r = sk["radii"]
    p = [c[0] + d.x * r[0] * scale, c[1] + d.y * r[1] * scale, c[2] + d.z * r[2] * scale]
    n = Vector((d.x / r[0], d.y / r[1], d.z / r[2])).normalized()
    return fr.v(p), fr.v(n)


# --- maillages : accumulateur commun (positions, normales, UV, triangles, poids par os) ------------------------
class Mesh:
    def __init__(self, name, material):
        self.name = name
        self.material = material
        self.p, self.n, self.uv, self.w, self.tris = [], [], [], [], []

    def vert(self, p, n, uv, w):
        self.p.append(Vector(p))
        self.n.append(Vector(n).normalized())
        self.uv.append(uv)
        self.w.append(w)
        return len(self.p) - 1

    def tri(self, a, b, c):
        # sens des triangles : la face regarde du côté des normales de ses sommets (faces arrière éliminées en jeu)
        fn = (self.p[b] - self.p[a]).cross(self.p[c] - self.p[a])
        if fn.dot(self.n[a] + self.n[b] + self.n[c]) < 0:
            b, c = c, b
        self.tris.append((a, b, c))


def lock(mesh, fr, base, direction, bend, length, width, thick, twist_up, weights_fn, segs=5, sides=6):
    """Mèche effilée : centre P(s) = base + dir·len·s + bend·len·s², section en losange aplati (largeur le long de
    twist_up × dir), rayon qui décroît jusqu'à la pointe ; UV : u autour, v le long."""
    direction = direction.normalized()
    pts = [base + direction * length * s + bend * length * s * s for s in [i / segs for i in range(segs + 1)]]
    first = len(mesh.p)
    for i, c in enumerate(pts[:-1]):
        s = i / segs
        tng = (pts[i + 1] - c).normalized()
        side = tng.cross(twist_up).normalized()
        if side.length < 1e-4:
            side = tng.orthogonal().normalized()
        upv = side.cross(tng).normalized()
        w = width * (1.0 - s) ** 0.85
        t = thick * (1.0 - s) ** 0.85
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            off = side * math.cos(ang) * w + upv * math.sin(ang) * t
            mesh.vert(c + off, off, (k / sides, s), weights_fn(s))
    tip = mesh.vert(pts[-1], direction, (0.5, 1.0), weights_fn(1.0))
    for i in range(segs - 1):
        for k in range(sides):
            a = first + i * sides + k
            b = first + i * sides + (k + 1) % sides
            c2 = a + sides
            d = b + sides
            mesh.tri(a, c2, b)
            mesh.tri(b, c2, d)
    last = first + (segs - 1) * sides
    for k in range(sides):
        mesh.tri(last + k, tip, last + (k + 1) % sides)


def build_hair(fr, look):
    hl = look["hair"]
    sk = hl["skull"]
    mesh = Mesh("PremiumHair", "hair")
    head = "Bip01 Head"
    # calotte : ellipsoïde légèrement réduit, coupé devant sous la ligne des cheveux (le visage est là)
    rings, segs = 14, 20
    lo = hl.get("cap_low", -50)  # la calotte descend jusqu'à la nuque derrière (le visage d'Eden est une tête entière)
    idx = {}
    for i in range(rings + 1):
        el = lo + ((90 - lo) * i / rings)
        for j in range(segs):
            az = 360 * j / segs
            p, n = ell_point(fr, sk, az, min(el, 89.9), sk.get("cap_scale", 0.98))
            idx[(i, j)] = mesh.vert(p, n, (j / segs, 0.02 + 0.1 * i / rings), {head: 1.0})
    cut = hl.get("cap_cut", {"az": 50, "el": 28})
    for i in range(rings):
        el = lo + (90 - lo) * (i + 0.5) / rings
        for j in range(segs):
            az = 360 * (j + 0.5) / segs
            front = min(az, 360 - az)
            if front < cut["az"] and el < cut["el"]:
                continue  # visage
            if front < cut.get("jaw_az", 110) and el < cut.get("jaw_el", -8):
                continue  # joues et mâchoire
            if el < -20 and front < 135:
                continue  # sous l'oreille : seule la nuque est couverte
            a, b, c, d = idx[(i, j)], idx[(i, (j + 1) % segs)], idx[(i + 1, j)], idx[(i + 1, (j + 1) % segs)]
            mesh.tri(a, b, c)
            mesh.tri(b, d, c)
    # mèches : [az, el, longueur, largeur, tangage vers l'arrière (+) / avant (-), lacet, courbure, nom d'os (option)]
    for L in hl["locks"]:
        az, el, length, width = L[0], L[1], L[2], L[3]
        out_n = ell_point(fr, sk, az, el)[1]
        base = ell_point(fr, sk, az, el, 0.93)[0]
        up = fr.U
        dirv = (out_n + up * L[4] + fr.v([math.cos(math.radians(az + 90)), math.sin(math.radians(az + 90)), 0]) * L[5]).normalized()
        bend = fr.v([0, 0, -1]) * L[6] + (-fr.F) * L[6] * 0.4
        bones = L[7] if len(L) > 7 else None

        def wfn(s, bones=bones):
            if not bones:
                return {head: 1.0}
            # racine sur la tête, puis os 1 puis os 2 le long de la mèche
            if s < 0.25:
                return {head: 1.0 - s / 0.25 * 0.5, bones[0]: s / 0.25 * 0.5}
            if s < 0.6:
                k = (s - 0.25) / 0.35
                return {bones[0]: 1.0 - 0.5 * k, bones[1]: 0.5 * k} if k > 0 else {bones[0]: 1.0}
            return {bones[0]: max(0.0, 0.5 - (s - 0.6)), bones[1]: min(1.0, 0.5 + (s - 0.6))}
        lock(mesh, fr, base, dirv, bend, length, width, width * hl.get("flat", 0.42), out_n, wfn)
    return mesh


def build_band(fr, look):
    bd = look["band"]
    sk = look["hair"]["skull"]
    mesh = Mesh("PremiumBand", "band")
    head = "Bip01 Head"
    n = 56
    h, t = bd["height"], bd["thick"]
    ring = []
    for i in range(n + 1):
        az = 360.0 * i / n
        el = bd["el"] - bd["tilt"] * math.cos(math.radians(az))
        p, nn = ell_point(fr, sk, az, el, bd["scale"])
        ring.append((p, nn, i / n))
    sect = [(-0.5, 0.0), (-0.5, 1.0), (0.5, 1.0), (0.5, 0.0)]  # (haut, épaisseur) : bord bas, haut, côté extérieur
    rows = []
    for p, nn, u in ring:
        upv = fr.U
        r = []
        for k, (a, b) in enumerate([(-0.5, 0.15), (-0.42, 1.0), (0.42, 1.0), (0.5, 0.15)]):
            pos = p + upv * a * h + nn * b * t
            nrm = (nn * 0.8 + upv * (a * 1.2)).normalized()
            r.append(mesh.vert(pos, nrm, (u * bd["repeat"], 0.02 + 0.46 * (k / 3)), {head: 1.0}))
        rows.append(r)
    for i in range(n):
        for k in range(3):
            a, b, c, d = rows[i][k], rows[i][k + 1], rows[i + 1][k], rows[i + 1][k + 1]
            mesh.tri(a, c, b)
            mesh.tri(b, c, d)
    # plaque de métal lisse : grille courbe sur le devant, biseau, dos fermé
    pl = bd["plate"]
    gw, gh = 8, 4
    grid = {}
    for i in range(gw + 1):
        for j in range(gh + 1):
            az = (i / gw - 0.5) * pl["az_span"]
            el = bd["el"] - bd["tilt"] * math.cos(math.radians(az)) + (j / gh - 0.5) * pl["el_span"]
            p, nn = ell_point(fr, sk, az, el, bd["scale"])
            edge = min(i, gw - i, j, gh - j) == 0
            pos = p + nn * (t + (pl["thick"] * (0.35 if edge else 1.0)))
            grid[(i, j)] = mesh.vert(pos, nn, (0.05 + 0.9 * i / gw, 0.55 + 0.4 * j / gh), {head: 1.0})
    for i in range(gw):
        for j in range(gh):
            a, b, c, d = grid[(i, j)], grid[(i + 1, j)], grid[(i, j + 1)], grid[(i + 1, j + 1)]
            mesh.tri(a, b, c)
            mesh.tri(b, d, c)
    # nœud derrière : deux lobes aplatis
    kn = bd["knot"]
    for side in (-1, 1):
        c, nn = ell_point(fr, sk, 180 + side * kn["spread"], bd["el"] + bd["tilt"], bd["scale"] + 0.06)
        k0 = len(mesh.p)
        rs, ss = 5, 8
        for i in range(rs + 1):
            v = math.pi * i / rs
            for j in range(ss):
                u = 2 * math.pi * j / ss
                d = Vector((math.sin(v) * math.cos(u), math.sin(v) * math.sin(u), math.cos(v)))
                pos = c + fr.L * d.x * kn["size"] * 1.3 * side + fr.U * d.z * kn["size"] - fr.F * d.y * kn["size"] * 0.55
                mesh.vert(pos, fr.L * d.x + fr.U * d.z - fr.F * d.y, (0.1 + 0.3 * j / ss, 0.05 + 0.4 * i / rs), {head: 1.0})
        for i in range(rs):
            for j in range(ss):
                a = k0 + i * ss + j
                b = k0 + i * ss + (j + 1) % ss
                mesh.tri(a, a + ss, b)
                mesh.tri(b, a + ss, b + ss)
    return mesh


def build_ribbons(fr, look, bones_out):
    rb = look["ribbons"]
    sk = look["hair"]["skull"]
    bd = look["band"]
    mesh = Mesh("PremiumRibbons", "band")
    for side, tag in ((1, "L"), (-1, "R")):
        root, _n = ell_point(fr, sk, 180 + side * bd["knot"]["spread"] * 0.6, bd["el"] + bd["tilt"], bd["scale"] + 0.05)
        dirv = (fr.v([-0.55, side * rb["spread"], -1.0])).normalized()
        names = ["PremiumRibbon_%s%d" % (tag, i + 1) for i in range(3)]
        seg = rb["length"] / 3.0
        for i, nm in enumerate(names):
            bones_out.append((nm, names[i - 1] if i else "Bip01 Head", root + dirv * seg * i, root + dirv * seg * (i + 1)))
        segs = 12
        width_axis = fr.L.cross(dirv).cross(dirv).normalized().cross(dirv).normalized()
        rows = []
        for i in range(segs + 1):
            s = i / segs
            c = root + dirv * rb["length"] * s
            w = rb["width"] * (1.0 - 0.25 * s)
            pos_s = s * 3.0
            k = int(min(pos_s, 2.999))
            f = pos_s - k
            wts = {names[k]: 1.0 - 0.5 * f, (names[k + 1] if k < 2 else names[k]): 0.5 * f} if k < 2 else {names[2]: 1.0}
            if s < 0.08:
                wts = {"Bip01 Head": 1.0 - s / 0.08, names[0]: s / 0.08}
            nrm = width_axis.cross(dirv).normalized()
            rows.append((mesh.vert(c - width_axis * w, nrm, (0.05 + 0.4 * s, 0.06), wts),
                         mesh.vert(c + width_axis * w, nrm, (0.05 + 0.4 * s, 0.44), wts)))
        for i in range(segs):
            a, b = rows[i]
            c, d = rows[i + 1]
            mesh.tri(a, c, b)
            mesh.tri(b, c, d)
    return mesh


def build_face(arm):
    """Visage d'Eden subdivisé une fois (UV et groupes d'os gardés)."""
    src = bpy.data.objects["#LFACE"]
    obj = src.copy()
    obj.data = src.data.copy()
    bpy.context.scene.collection.objects.link(obj)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.0)
    bm.to_mesh(obj.data)
    bm.free()
    # lissage doux (Catmull-Clark approché) en gardant le bord : Smooth Corrective non dispo en arrière-plan -> smooth simple
    mod = obj.modifiers.new("lisse", "SMOOTH")
    mod.factor = 0.5
    mod.iterations = 2
    vg = obj.vertex_groups.new(name="_interieur")
    bmc = bmesh.new()
    bmc.from_mesh(obj.data)
    inner = [v.index for v in bmc.verts if not v.is_boundary]
    bmc.free()
    vg.add(inner, 1.0, "REPLACE")
    mod.vertex_group = "_interieur"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="lisse")
    if obj.vertex_groups.get("_interieur"):
        obj.vertex_groups.remove(obj.vertex_groups["_interieur"])
    # poids : transfert depuis le visage d'Eden (le maillage subdivisé a déjà des poids interpolés ; on les recale)
    try:
        obj.select_set(True)
        dt = obj.modifiers.new("poids", "DATA_TRANSFER")
        dt.object = src
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        bpy.ops.object.datalayout_transfer(modifier="poids")
        bpy.ops.object.modifier_apply(modifier="poids")
        print("CHR2_HEAD poids du visage : transfert depuis #LFACE")
    except Exception as e:  # les poids interpolés par la subdivision restent
        print("CHR2_HEAD poids du visage : interpolés (transfert impossible : %s)" % e)
    me = obj.data
    me.calc_loop_triangles()
    mesh = Mesh("PremiumFace", "face")
    uvl = me.uv_layers.active.data
    gname = {g.index: g.name for g in obj.vertex_groups}
    for tri in me.loop_triangles:
        ids = []
        for li in tri.loops:
            vi = me.loops[li].vertex_index
            v = me.vertices[vi]
            w = {gname[g.group]: g.weight for g in v.groups if g.weight > 0.001}
            uv = uvl[li].uv
            ids.append(mesh.vert(v.co.copy(), me.loops[li].normal.copy() if hasattr(me.loops[li], "normal") else v.normal, (uv.x, 1.0 - uv.y), w))
        mesh.tri(*ids)
    return mesh, obj


# --- écriture du GLB --------------------------------------------------------------------------------------------
def _glb_load(p):
    f = open(p, "rb").read()
    jl, _ = struct.unpack("<II", f[12:20])
    js = json.loads(f[20:20 + jl])
    return js


def _trs(n):
    m = np.eye(4)
    if "matrix" in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                  [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                  [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m[:3, :3] = R @ np.diag(n.get("scale", [1, 1, 1]))
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def _quat(R):
    q = Matrix(R.tolist()).to_quaternion()
    return [q.x, q.y, q.z, q.w]


def write_glb(path, meshes, new_bones, rest_blender, images):
    body = _glb_load(BODY)
    bn = body["nodes"]
    par = {}
    for i, n in enumerate(bn):
        for c in n.get("children", []):
            par[c] = i
    by_name = {n["name"]: i for i, n in enumerate(bn)}
    chain = []
    i = by_name["Bip01 Head"]
    while i is not None:
        chain.insert(0, i)
        i = par.get(i)
    # repère relatif à EdenRoot (nœud 0) : produit des TRS sous lui
    def rel(i):
        m = np.eye(4)
        while i is not None and i != 0:
            m = _trs(bn[i]) @ m
            i = par.get(i)
        return m
    # alignement Blender (armature) -> EdenRoot (Kabsch sur les os de la chaîne + bras + jambes)
    src, dst = [], []
    for name, j in by_name.items():
        if name in rest_blender and (name.startswith("Bip01 ") or name == "Bip01_Nub"):
            src.append(rest_blender[name])
            dst.append(rel(j)[:3, 3])
    src, dst = np.array(src), np.array(dst)
    cs, cd = src.mean(0), dst.mean(0)
    Hm = (src - cs).T @ (dst - cd)
    U_, S_, Vt = np.linalg.svd(Hm)
    D = np.diag([1, 1, np.sign(np.linalg.det(Vt.T @ U_.T))])
    Rk = Vt.T @ D @ U_.T
    tk = cd - Rk @ cs
    err = np.abs((src @ Rk.T + tk) - dst).max()
    print("CHR2_HEAD alignement : %d os, écart max %.5f" % (len(src), err))
    to_e = lambda p: Rk @ np.array(p) + tk
    # nœuds : EdenRoot, chaîne jusqu'à la tête (TRS exacts du corps commun), os neufs, maillages
    nodes = []
    remap = {}
    for k, j in enumerate(chain):
        n = {"name": bn[j]["name"]}
        for key in ("translation", "rotation", "scale"):
            if key in bn[j]:
                n[key] = bn[j][key]
        remap[j] = len(nodes)
        nodes.append(n)
    for k in range(len(chain) - 1):
        nodes[remap[chain[k]]].setdefault("children", []).append(remap[chain[k + 1]])
    world_e = {bn[j]["name"]: rel(j) for j in chain}
    for name, parent, head, tail in new_bones:
        h = to_e(head)
        tvec = to_e(tail) - h
        x = tvec / np.linalg.norm(tvec)
        ref = np.array([0.0, 0.0, 1.0]) if abs(x[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        y = np.cross(ref, x)
        y /= np.linalg.norm(y)
        z = np.cross(x, y)
        G = np.eye(4)
        G[:3, 0], G[:3, 1], G[:3, 2], G[:3, 3] = x, y, z, h
        world_e[name] = G
        local = np.linalg.inv(world_e[parent]) @ G
        n = {"name": name, "translation": local[:3, 3].tolist(), "rotation": _quat(local[:3, :3])}
        idx = len(nodes)
        nodes.append(n)
        pidx = [k for k, nn in enumerate(nodes) if nn["name"] == parent][0]
        nodes[pidx].setdefault("children", []).append(idx)
    scene_root = [k for k, nn in enumerate(nodes) if nn["name"] == "Scene Root"][0]
    joints_names = ["Bip01 Spine1", "Bip01 Neck", "Bip01 Head"] + [b[0] for b in new_bones]
    joints = [[k for k, nn in enumerate(nodes) if nn["name"] == jn][0] for jn in joints_names]
    jindex = {jn: i for i, jn in enumerate(joints_names)}
    # binaire
    blob = bytearray()
    views, accs = [], []

    def add(arr, target=None, comp=5126, typ="VEC3", minmax=False):
        a = np.ascontiguousarray(arr)
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(a.tobytes())
        v = {"buffer": 0, "byteOffset": off, "byteLength": a.nbytes}
        if target:
            v["target"] = target
        views.append(v)
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": int(a.shape[0]), "type": typ}
        if minmax:
            acc["min"] = a.min(0).tolist()
            acc["max"] = a.max(0).tolist()
        accs.append(acc)
        return len(accs) - 1
    # matrices de liaison : inverse(monde du joint) · monde du maillage ; maillage sous Scene Root (identité)
    mesh_world = world_e["Scene Root"]
    ibm = np.array([(np.linalg.inv(world_e[jn]) @ mesh_world).T.reshape(-1) for jn in joints_names], np.float32)
    ibm_acc = add(ibm, comp=5126, typ="MAT4")
    mats, mat_index, textures, images_js = [], {}, [], []
    for key, (img_path, double) in images.items():
        data = open(img_path, "rb").read()
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(data)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data)})
        images_js.append({"bufferView": len(views) - 1, "mimeType": "image/png", "name": "chr2_" + key})
        textures.append({"sampler": 0, "source": len(images_js) - 1})
        mats.append({"name": "chr2_" + key, "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.9,
                                                                      "baseColorTexture": {"index": len(textures) - 1}},
                     "doubleSided": bool(double)})
        mat_index[key] = len(mats) - 1
    meshes_js = []
    to_mesh = np.linalg.inv(mesh_world)
    total_tris = 0
    for m in meshes:
        P = np.array([to_e(p) for p in m.p])
        P = (P @ to_mesh[:3, :3].T + to_mesh[:3, 3]).astype(np.float32)
        N = np.array([Rk @ np.array(n) for n in m.n])
        N = (N @ to_mesh[:3, :3].T)
        N = (N / np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-8)).astype(np.float32)
        UV = np.array(m.uv, np.float32)
        J = np.zeros((len(m.p), 4), np.uint8)
        W = np.zeros((len(m.p), 4), np.float32)
        for vi, w in enumerate(m.w):
            items = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            s = sum(x for _, x in items) or 1.0
            for k, (bname, x) in enumerate(items):
                J[vi, k] = jindex[bname]
                W[vi, k] = x / s
        I = np.array(m.tris, np.uint32).reshape(-1)
        total_tris += len(m.tris)
        prim = {"attributes": {"POSITION": add(P, 34962, minmax=True), "NORMAL": add(N, 34962), "TEXCOORD_0": add(UV, 34962, typ="VEC2"),
                               "JOINTS_0": add(J, 34962, comp=5121, typ="VEC4"), "WEIGHTS_0": add(W, 34962, typ="VEC4")},
                "indices": add(I, 34963, comp=5125, typ="SCALAR"), "material": mat_index[m.material]}
        meshes_js.append({"name": m.name, "primitives": [prim]})
        idx = len(nodes)
        nodes.append({"name": m.name, "mesh": len(meshes_js) - 1, "skin": 0})
        nodes[scene_root].setdefault("children", []).append(idx)
    gl = {"asset": {"version": "2.0", "generator": "EdenSlash chr2_head.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
          "nodes": nodes, "meshes": meshes_js, "skins": [{"joints": joints, "inverseBindMatrices": ibm_acc, "skeleton": 0}],
          "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
          "materials": mats, "textures": textures, "images": images_js, "samplers": [{"magFilter": 9729, "minFilter": 9987}]}
    js = json.dumps(gl, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    while len(blob) % 4:
        blob.append(0)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(bytes(blob))
    print("CHR2_HEAD %s : %d triangles, %d os neufs, %.0f Ko" % (path, total_tris, len(new_bones), os.path.getsize(path) / 1024))
    return total_tris


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BODY)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    fr = Frame(arm)
    bones = []
    hair = build_hair(fr, LOOK)
    # os des mèches de côté : le long de leur axe (2 os chacune)
    for L in LOOK["hair"]["locks"]:
        if len(L) > 7:
            sk = LOOK["hair"]["skull"]
            out_n = ell_point(fr, sk, L[0], L[1])[1]
            base = ell_point(fr, sk, L[0], L[1], 0.93)[0]
            dirv = (out_n + fr.U * L[4] + fr.v([math.cos(math.radians(L[0] + 90)), math.sin(math.radians(L[0] + 90)), 0]) * L[5]).normalized()
            bend = fr.v([0, 0, -1]) * L[6] + (-fr.F) * L[6] * 0.4
            pt = lambda s: base + dirv * L[2] * s + bend * L[2] * s * s
            bones.append((L[7][0], "Bip01 Head", pt(0.2), pt(0.55)))
            bones.append((L[7][1], L[7][0], pt(0.55), pt(1.0)))
    band = build_band(fr, LOOK)
    ribbons = build_ribbons(fr, LOOK, bones)
    face, _obj = build_face(arm)
    rest_b = {n: list(m.translation) for n, m in fr.rest.items()}
    images = {"face": (os.path.join(TEX, "face.png"), False), "hair": (os.path.join(TEX, "hair.png"), False),
              "band": (os.path.join(TEX, "band.png"), True)}
    write_glb(OUT, [face, hair, band, ribbons], bones, rest_b, images)
    if arg("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(arg("blend")))


if __name__ == "__main__":
    main()
