"""Lot PRP-1 : nettoyage d'un objet Pixal3D brut dans Blender (en arrière-plan), appelé par prp_pipeline.py.

  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup \\
      --python tools/art/prp_blender.py -- params.json

params.json : src, dst, kind (weapon | back), type, tri_max, tex, max_kb, render_dir, id, metrics ;
arme : length, grip (null = détectée à la garde), w1, w2 ; dos : span.

Étapes
1. Import, fusion, petits morceaux retirés (< 0,4 % de la surface), soudure des sommets, normales recalculées.
2. Orientation et échelle dans le REPÈRE DE L'OS (comme les armes et accessoires du jeu, EdenModel) :
   - arme (os de la main) : axe long = +Z (pointe en haut), largeur = X, épaisseur = Y ; origine = la main
     (milieu de la poignée : entre le pommeau et la garde, ou part fixe de la longueur selon le type) ;
     nœuds W1 (base de la lame) et W2 (pointe) pour la traînée d'arme (Player._blade_base / _blade_tip) ;
   - ailes (os « Bip01 Spine1 ») : X = haut du dos, Y = devant du héros (les ailes sont du côté -Y, collées au dos à
     y = -0,08), Z = de côté ; envergure fixée, centre à 0,10 au-dessus de l'os.
   Le tout sous un nœud « EdenRoot » tourné de -90° sur X (export sans conversion d'axes) : le jeu remet EdenRoot à
   l'identité, la pièce est alors exprimée dans le repère de l'os ; un visualiseur glTF la montre debout.
3. Retopologie légère : copie remaillée par voxels (coque double fondue, surface fermée) puis réduite (Decimate « collapse »,
   triangles <= tri_max), dépliage UV neuf (Smart UV),
   couleur RE-CUITE depuis le modèle haute définition (Cycles, passe d'émission, processeur : la carte reste à ComfyUI).
   Couleur « toon » : occlusion ambiante multipliée dans la couleur (creux lisibles sans éclairage), saturation x1,15,
   métal 0 (le shader du jeu ne lit que la couleur : eden_character.gdshader).
4. Contrôles (rejets) : triangles, poids, composantes, arêtes non-manifold, trous ; export GLB (JPEG), rendu d'aperçu.
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

T0 = time.time()
P = json.load(open(sys.argv[sys.argv.index("--") + 1], encoding="utf-8"))
KIND = P["kind"]
REM = []  # remarques (fiche)


def log(*a):
    print("[prp]", P["id"], *a, flush=True)


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def islands(obj):
    """Composantes connexes : liste (nb de faces, surface) et index de composante par face."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    comp = [-1] * len(bm.faces)
    out = []
    for f in bm.faces:
        if comp[f.index] >= 0:
            continue
        cid = len(out)
        stack, n, area = [f], 0, 0.0
        comp[f.index] = cid
        while stack:
            g = stack.pop()
            n += 1
            area += g.calc_area()
            for e in g.edges:
                for h in e.link_faces:
                    if comp[h.index] < 0:
                        comp[h.index] = cid
                        stack.append(h)
        out.append((n, area))
    bm.free()
    return out, comp


def topo(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    nm = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    bd = sum(1 for e in bm.edges if e.is_boundary)
    deg = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    ne = len(bm.edges)
    bm.free()
    return {"aretes": ne, "non_manifold": nm, "bords": bd, "faces_degenerees": deg}


# --- 1. import ----------------------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=P["src"])
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
hi = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != hi:
        bpy.data.objects.remove(o)
hi.name = "haut"
raw_tris = sum(len(p.vertices) - 2 for p in hi.data.polygons)

# images source : couleur et ORM (occlusion = canal R), avant de toucher aux matériaux
mat_src = hi.data.materials[0] if hi.data.materials else None
base_img = orm_img = None
if mat_src and mat_src.use_nodes:
    for n in mat_src.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            for l in n.outputs["Color"].links:
                if l.to_socket.name == "Base Color":
                    base_img = n.image
                elif l.to_node.type in ("SEPARATE_COLOR", "SEPRGB", "SEPARATE_RGB"):
                    orm_img = n.image
if base_img is None:
    raise SystemExit("pas de texture de couleur dans le GLB brut")

# soudure d'abord : le GLB brut coupe les sommets aux coutures UV (50 000 « bords » sur une épée) ; les UV restent par coin
bm = bmesh.new()
bm.from_mesh(hi.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(hi.data)
bm.free()
# socle plat (ombre de l'image devenue une plaque sous l'objet : sac, guitare) : on coupe le bas sur « cut_bottom » de la hauteur
if P.get("cut_bottom"):
    zs = [v.co.z for v in hi.data.vertices]
    z_cut = min(zs) + P["cut_bottom"] * (max(zs) - min(zs))
    bm = bmesh.new()
    bm.from_mesh(hi.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < z_cut], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(hi.data)
    bm.free()
    REM.append("socle coupé")
# petits morceaux (éclats, poussière de reconstruction) : retirés
isl, comp = islands(hi)
total_area = sum(a for _, a in isl)
small = {i for i, (n, a) in enumerate(isl) if a < 0.004 * total_area}
if P.get("single") and isl:
    # une seule pièce (lance) : Pixal3D double parfois un objet très fin (deux hampes côte à côte) ; on garde la plus grande
    best = max(range(len(isl)), key=lambda i: isl[i][1])
    small = {i for i in range(len(isl)) if i != best}
    REM.append("plus grande pièce gardée")
if small:
    bm = bmesh.new()
    bm.from_mesh(hi.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if comp[f.index] in small], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(hi.data)
    bm.free()
isl, _ = islands(hi)
big_parts = sum(1 for _, a in isl if a > 0.02 * total_area)
log(f"brut {raw_tris} triangles, {len(isl) + len(small)} composantes dont {len(small)} miettes retirées, {big_parts} grandes")

# --- 2. orientation, échelle, repère de l'os -------------------------------------------------------------------------
co = np.empty(len(hi.data.vertices) * 3, np.float64)
hi.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
c0 = co.mean(0)


def profile(pts, z0, z1, n=100):
    """Largeur (X) de l'objet par tranche de hauteur."""
    b = np.linspace(z0, z1, n + 1)
    out = np.zeros(n)
    for i in range(n):
        sel = (pts[:, 2] >= b[i]) & (pts[:, 2] < b[i + 1])
        if sel.sum() > 3:
            out[i] = np.ptp(pts[sel, 0])
    return out


def apply(mat4):
    hi.data.transform(mat4)
    hi.data.update()


apply(Matrix.Translation(Vector(-c0)))
co = co - c0
if KIND == "weapon":
    # axe long = axe principal (l'image est debout : on corrige l'inclinaison sans retourner l'objet)
    w, v = np.linalg.eigh(np.cov(co.T))
    a1 = v[:, 2] * (1 if v[2, 2] >= 0 else -1)
    rot = Vector(a1).rotation_difference(Vector((0, 0, 1))).to_matrix().to_4x4()
    tilt = math.degrees(Vector(a1).angle(Vector((0, 0, 1))))
    apply(rot)
    co = (np.array(rot.to_3x3()) @ co.T).T
    # largeur = X (face à l'image), épaisseur = Y
    xy = co[:, :2]
    w2, v2 = np.linalg.eigh(np.cov(xy.T))
    a2 = v2[:, 1] * (1 if v2[0, 1] >= 0 else -1)
    ang = math.atan2(a2[1], a2[0])
    rz = Matrix.Rotation(-ang, 4, "Z")
    apply(rz)
    co = (np.array(rz.to_3x3()) @ co.T).T
    if tilt > 3:
        REM.append(f"inclinaison corrigée {tilt:.0f}°")
    # sens : lames = la garde est dans la moitié basse (lame plus longue que la poignée) ; autres armes = la tête
    # (bout le plus large) en haut. Sinon demi-tour autour de Y (la largeur reste sur X).
    lo_z, hi_z = co[:, 2].min(), co[:, 2].max()
    prof = profile(co, lo_z, hi_z)
    sens = P.get("sens") or ""
    if sens == "image":
        flip = False  # canon, grimoire : le haut de l'image est le haut de l'arme (Pixal3D le garde)
    elif sens == "large_bas":
        flip = prof[75:].mean() > prof[:25].mean()  # guitare : la caisse (bout le plus large) en bas
    elif P.get("grip") is None:
        flip = 5 + int(np.argmax(prof[5:95])) > 50
    else:
        flip = prof[75:].mean() < prof[:25].mean()
    if flip:
        ry = Matrix.Rotation(math.pi, 4, "Y")
        apply(ry)
        co = (np.array(ry.to_3x3()) @ co.T).T
        REM.append("retournée (pointe en haut)")
    lo_z, hi_z = co[:, 2].min(), co[:, 2].max()
    s = P["length"] / (hi_z - lo_z)
    apply(Matrix.Scale(s, 4))
    co *= s
    lo_z, hi_z = co[:, 2].min(), co[:, 2].max()
    L = hi_z - lo_z
    # garde = section la plus large dans la moitié basse (lames) ; main = entre le pommeau et la garde
    bins = np.linspace(lo_z, hi_z, 101)
    width = profile(co, lo_z, hi_z)
    if P.get("grip") is None:
        lo_i, hi_i = 5, 50
        gi = lo_i + int(np.argmax(width[lo_i:hi_i]))
        guard = bins[gi]
        grip_z = (lo_z + guard) / 2
        w1 = guard + 0.02 * L
        REM_g = f"garde détectée à {100 * (guard - lo_z) / L:.0f} % de la longueur"
        log(REM_g)
    else:
        grip_z = lo_z + P["grip"] * L
        w1 = lo_z + P["w1"] * L
    # la main tient le manche au centre de sa section (X, Y)
    near = np.abs(co[:, 2] - grip_z) < 0.03 * L
    gx, gy = (co[near, 0].mean(), co[near, 1].mean()) if near.sum() > 3 else (0.0, 0.0)
    apply(Matrix.Translation(Vector((-gx, -gy, -grip_z))))
    w1 -= grip_z
    w2 = lo_z + P["w2"] * L - grip_z
else:
    # ailes : l'image les montre de dos. Blender : X = côté, Z = haut, -Y = vers la caméra = dos du héros.
    # repère de l'os du dos : X_os = haut (Z), Y_os = devant (+Y), Z_os = -X (rotation directe)
    to_bone = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))
    apply(to_bone)
    co = (np.array(to_bone.to_3x3()) @ co.T).T
    span = np.ptp(co[:, 2])
    s = P["span"] / span
    apply(Matrix.Scale(s, 4))
    co *= s
    cx = (co[:, 0].min() + co[:, 0].max()) / 2
    cz = (co[:, 2].min() + co[:, 2].max()) / 2
    front = co[:, 1].max()  # point le plus proche du dos
    # centre à « haut » au-dessus de l'os (ailes 0,10 ; halo plus haut, derrière les épaules), « recul » = écart au dos
    UP, GAP = P.get("up", 0.10), P.get("gap", 0.0)
    apply(Matrix.Translation(Vector((UP - cx, -0.08 - GAP - front, -cz))))
    co = co + np.array([UP - cx, -0.08 - GAP - front, -cz])
    depth = np.ptp(co[:, 1])
    if depth > 0.6 * P["span"]:
        REM.append("ailes très épaisses")

bpy.ops.object.select_all(action="DESELECT")
select_only(hi)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

# couleur « toon » du haut détail : occlusion multipliée, saturation relevée (calcul en sRGB, comme le peintre)
W, H = base_img.size
px = np.empty(W * H * 4, np.float32)
base_img.pixels.foreach_get(px)
px = px.reshape(H, W, 4)
rgb = px[:, :, :3]
if orm_img is not None and tuple(orm_img.size) == (W, H):
    o = np.empty(W * H * 4, np.float32)
    orm_img.pixels.foreach_get(o)
    ao = o.reshape(H, W, 4)[:, :, 0:1]
    rgb = rgb * (0.55 + 0.45 * ao)
lum = (rgb * np.array([0.299, 0.587, 0.114], np.float32)).sum(2, keepdims=True)
rgb = np.clip(lum + (rgb - lum) * 1.15, 0, 1) * 1.04
px[:, :, :3] = np.clip(rgb, 0, 1)
px[:, :, 3] = 1.0
tone = bpy.data.images.new("prp_ton", W, H)
tone.pixels.foreach_set(px.ravel())
mat_hi = bpy.data.materials.new("haut")
mat_hi.use_nodes = True
nt = mat_hi.node_tree
nt.nodes.clear()
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = tone
em = nt.nodes.new("ShaderNodeEmission")
outn = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(tn.outputs["Color"], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], outn.inputs["Surface"])
hi.data.materials.clear()
hi.data.materials.append(mat_hi)

# --- 3. retopologie légère et re-cuisson ---------------------------------------------------------------------------
lo = hi.copy()
lo.data = hi.data.copy()
lo.name = lo.data.name = P["id"]
bpy.context.scene.collection.objects.link(lo)
select_only(lo)
tris_hi = sum(len(p.vertices) - 2 for p in lo.data.polygons)


def mesh_area(o):
    return sum(p.area for p in o.data.polygons)


# remaillage par voxels d'abord : la réduction directe du maillage Pixal3D plie les parties fines (300 à 400 arêtes à
# 3 faces sur une épée) ; un remaillage voxel donne une surface fermée et propre que la réduction garde propre.
# Taille du voxel = plus grande dimension / résolution (armes 400, ailes 900 : les membranes sont très fines).
# Le maillage Pixal3D (remaillage « udf ») est une coque double (deux parois serrées) : le voxel les fond en une, l'aire
# tombe donc vers 50 %. Garde-fou : aire < 35 % ou boîte changée de plus de 8 % = des parties fines ont disparu, on
# revient à la réduction directe.
area0 = mesh_area(lo)
dims0 = Vector(lo.dimensions)
res = P.get("voxel_res", 400 if KIND == "weapon" else 900)
vm = lo.modifiers.new("vox", "REMESH")
vm.mode = "VOXEL"
vm.voxel_size = max(lo.dimensions) / res
tv = time.time()
bpy.ops.object.modifier_apply(modifier=vm.name)
ratio = mesh_area(lo) / max(area0, 1e-9)
log(f"voxel 1/{res} : {len(lo.data.polygons)} faces en {time.time() - tv:.1f} s, aire x{ratio:.2f}")
RETOPO = "voxel puis réduction"
dd = max(abs(a - b) / max(b, 1e-6) for a, b in zip(lo.dimensions, dims0) if b > 0.05 * max(dims0))
if ratio < 0.35 or dd > 0.08:
    lo.data = hi.data.copy()
    RETOPO = "réduction directe (voxel trop grossier)"
    REM.append("voxel abandonné")
target = P["tri_max"]
for attempt in range(4):
    m = lo.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.use_collapse_triangulate = True
    m.ratio = min(1.0, target / max(1, sum(len(p.vertices) - 2 for p in lo.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=m.name)
    n = sum(len(p.vertices) - 2 for p in lo.data.polygons)
    if n <= P["tri_max"]:
        break
    target = int(target * 0.95)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, area_weight=0.0, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.shade_smooth()

TEX = P["tex"]
baked = bpy.data.images.new("prp_couleur", TEX, TEX)
mat_lo = bpy.data.materials.new(P["id"])
mat_lo.use_nodes = True
nt = mat_lo.node_tree
bsdf = nt.nodes.get("Principled BSDF")
bt = nt.nodes.new("ShaderNodeTexImage")
bt.image = baked
nt.links.new(bt.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 1.0  # mat (PRP-2) : le shader du jeu ne lit que la couleur
nt.nodes.active = bt
lo.data.materials.clear()
lo.data.materials.append(mat_lo)

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 1
size = max(lo.dimensions)
bpy.ops.object.select_all(action="DESELECT")
hi.select_set(True)
lo.select_set(True)
bpy.context.view_layer.objects.active = lo
tb = time.time()
bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.01 * size,
                    max_ray_distance=0.04 * size, margin=8)
log(f"cuisson {TEX} px en {time.time() - tb:.1f} s")


def _hsv(rgb):
    mx, mn = rgb.max(2), rgb.min(2)
    d = mx - mn
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) / 6.0
    return np.where(d > 1e-6, h, 0.0), s, mx


def _rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (a, b, c) in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == k
        out[m, 0], out[m, 1], out[m, 2] = a[m], b[m], c[m]
    return out


def _median(a, r=2):
    hh, ww = a.shape
    pad = np.pad(a, r, mode="edge")
    return np.median(np.stack([pad[r + dy:r + dy + hh, r + dx:r + dx + ww] for dy in range(-r, r + 1) for dx in range(-r, r + 1)]), 0)


def flatten(img):
    """Aplats (PRP-2) : la texture SDXL a des reflets « jouet verni » (traînées blanches, dégradés brillants) là où les armes
    d'Eden ont 2-3 tons nets. Valeur lissée (médiane 5×5) et ramenée vers 5 paliers, reflets écrasés au-dessus de 0,82,
    saturation des reflets rendue (médiane voisine) : la couleur et la teinte restent, le vernis part."""
    w_, h_ = img.size
    a = np.empty(w_ * h_ * 4, np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(h_, w_, 4)
    h, s, v = _hsv(a[:, :, :3])
    vm, sm = _median(v, 3), _median(s, 3)
    v1 = 0.25 * v + 0.75 * vm
    v1 = np.where(v1 > 0.78, 0.78 + (v1 - 0.78) * 0.3, v1)
    v1 = 0.7 * v1 + 0.3 * np.round(v1 * 5) / 5
    s1 = np.clip(np.maximum(s, 0.9 * sm) * 1.05, 0, 1)
    a[:, :, :3] = np.clip(_rgb(h, s1, np.clip(v1, 0, 1)), 0, 1)
    img.pixels.foreach_set(a.ravel())


if P.get("flat", True):
    flatten(baked)
    REM.append("aplats")
baked.pack()

# --- EdenRoot, W1 / W2 ---------------------------------------------------------------------------------------------
root = bpy.data.objects.new("EdenRoot", None)
sc.collection.objects.link(root)
root.rotation_euler = (math.radians(-90), 0, 0)
lo.parent = root
lo.matrix_parent_inverse = Matrix.Identity(4)
extra = [root, lo]
if KIND == "weapon":
    for name, z in (("W1", w1), ("W2", w2)):
        e = bpy.data.objects.new(name, None)
        sc.collection.objects.link(e)
        e.parent = root
        e.location = (0, 0, z)
        extra.append(e)

bpy.data.objects.remove(hi)

# --- ailes animées (PRP-2) : deux moitiés AileG (côté -Z de l'os) et AileD (+Z), origine à la charnière (milieu du dos) ;
# le jeu les fait battre par une rotation autour de l'axe X de l'os (haut du dos), voir PrpWingFlap
halves = []
if KIND == "back" and P.get("flap"):
    bpy.context.view_layer.update()
    mw = lo.matrix_world.copy()
    hinge_y = max(v.co.y for v in lo.data.vertices)
    hinge_x = P.get("up", 0.10)
    for name, keep_pos in (("AileD", True), ("AileG", False)):
        o = lo.copy()
        o.data = lo.data.copy()
        o.name = o.data.name = name
        sc.collection.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if (f.calc_center_median().z >= 0) != keep_pos], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((-hinge_x, -hinge_y, 0)))
        bm.to_mesh(o.data)
        bm.free()
        o.parent = root
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.location = (hinge_x, hinge_y, 0)
        halves.append(o)

# --- 4. contrôles et export ----------------------------------------------------------------------------------------
tp = topo(lo)
isl, _ = islands(lo)
area = sum(a for _, a in isl)
parts = sum(1 for _, a in isl if a > 0.02 * area)
tris = sum(len(p.vertices) - 2 for p in lo.data.polygons)


def export(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (([root] + halves) if halves else extra):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=False,
                              export_image_format="JPEG", export_jpeg_quality=88, export_apply=True,
                              export_texcoords=True, export_normals=True, export_tangents=False,
                              export_materials="EXPORT", export_extras=False)
    return os.path.getsize(path) // 1024


kb = export(P["dst"])
while kb > P["max_kb"] and TEX > 256:
    TEX //= 2
    baked.scale(TEX, TEX)
    baked.pack()
    kb = export(P["dst"])
    REM.append(f"texture réduite à {TEX} px")

verdict = []
if tris > P["tri_max"] / 0.96:
    verdict.append("trop de triangles")
if kb > P["max_kb"]:
    verdict.append("trop lourd")
if tp["non_manifold"] > 0.02 * tp["aretes"]:
    verdict.append("topologie cassée (non-manifold)")
if tp["bords"] > 0.05 * tp["aretes"]:
    verdict.append("maillage troué")
if parts > (6 if KIND == "weapon" else 14):
    verdict.append(f"en {parts} morceaux")
dims = [round(d, 3) for d in lo.dimensions]
met = {"id": P["id"], "triangles": tris, "triangles_brut": raw_tris, "sommets": len(lo.data.vertices), "ko": kb,
       "texture": TEX, "dimensions": dims, "composantes": len(isl), "grandes_composantes": parts,
       "aretes_non_manifold": tp["non_manifold"], "bords": tp["bords"], "aretes": tp["aretes"],
       "verdict": ", ".join(verdict) if verdict else "ok", "remarques": ", ".join(REM), "retopo": RETOPO}
if KIND == "weapon":
    met.update({"w1": round(w1, 3), "w2": round(w2, 3)})
if halves:
    met["battement"] = [o.name for o in halves]
log(f"{tris} triangles, {kb} Ko, dimensions {dims}, {tp['non_manifold']} arêtes non-manifold, {tp['bords']} bords, "
    f"{parts} grandes composantes -> {met['verdict']}")

# --- aperçu toon (3 tons, sans contour, comme le shader du jeu) ------------------------------------------------------
prev = bpy.data.materials.new("apercu")
prev.use_nodes = True
nt = prev.node_tree
nt.nodes.clear()
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = baked
dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
s2r = nt.nodes.new("ShaderNodeShaderToRGB")
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.interpolation = "CONSTANT"
ramp.color_ramp.elements[0].color = (0.62, 0.6, 0.72, 1)
ramp.color_ramp.elements[1].position = 0.12
ramp.color_ramp.elements[1].color = (0.86, 0.85, 0.9, 1)
e3 = ramp.color_ramp.elements.new(0.45)
e3.color = (1.0, 1.0, 1.0, 1)
mul = nt.nodes.new("ShaderNodeMix")
mul.data_type = "RGBA"
mul.blend_type = "MULTIPLY"
mul.inputs[0].default_value = 1.0
em = nt.nodes.new("ShaderNodeEmission")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(dif.outputs[0], s2r.inputs[0])
nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
nt.links.new(tx.outputs["Color"], mul.inputs[6])
nt.links.new(ramp.outputs["Color"], mul.inputs[7])
nt.links.new(mul.outputs[2], em.inputs["Color"])
nt.links.new(em.outputs[0], out.inputs["Surface"])
lo.data.materials[0] = prev

sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
sc.render.resolution_x = sc.render.resolution_y = 600
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.72, 0.86, 1)  # ciel du jeu #CCDEF3 (linéaire)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
sc.collection.objects.link(cam)
sc.camera = cam
bpy.context.view_layer.update()
# la pièce posée en diagonale (armes) ou vue de dos en 3/4 (ailes), cadrée sur sa boîte
# (Blender a Z en haut : le repère de l'os y est posé directement, sans le -90° de l'export)
if KIND == "weapon":
    root.rotation_euler = (0, math.radians(-40), 0)  # lame (Z_os) penchée dans le plan de l'image, largeur face caméra
    view = Vector((0.25, -1.0, 0.18)).normalized()
else:
    root.rotation_euler = (0, math.radians(-90), 0)  # X_os (haut du dos) -> Z ; les ailes (côté -Y_os) face caméra
    view = Vector((0.45, -1.0, 0.35)).normalized()
bpy.context.view_layer.update()
pts = [lo.matrix_world @ Vector(c) for c in lo.bound_box]
ctr = sum(pts, Vector()) / 8
rad = max((p - ctr).length for p in pts)
cam.location = ctr + view * rad * 4
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.ortho_scale = rad * 2.05
sun.rotation_euler = (cam.location - ctr).to_track_quat("Z", "Y").to_euler()
sun.rotation_euler.rotate_axis("X", math.radians(-35))
sun.rotation_euler.rotate_axis("Y", math.radians(25))
sc.render.filepath = os.path.join(P["render_dir"], P["id"] + "_vue.png")
bpy.ops.render.render(write_still=True)

# --- rendu pour l'icône (PRP-2) : fond transparent, arme en diagonale (poignée en bas à gauche, pointe en haut à droite,
# comme les icônes d'armes du jeu), dos vu de derrière ; la tuile autocollante est posée par prp_pipeline.py icon
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = 512
if KIND == "weapon":
    root.rotation_euler = (0, math.radians(45), 0)
    view = Vector((0.12, -1.0, 0.1)).normalized()
else:
    root.rotation_euler = (0, math.radians(-90), 0)
    view = Vector((0.0, -1.0, 0.12)).normalized()
bpy.context.view_layer.update()
pts = [lo.matrix_world @ Vector(c) for c in lo.bound_box]
ctr = sum(pts, Vector()) / 8
rad = max((p - ctr).length for p in pts)
cam.location = ctr + view * rad * 4
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.ortho_scale = rad * (1.62 if KIND == "weapon" else 2.0)
sun.rotation_euler = (cam.location - ctr).to_track_quat("Z", "Y").to_euler()
sun.rotation_euler.rotate_axis("X", math.radians(-35))
sun.rotation_euler.rotate_axis("Y", math.radians(25))
sc.render.filepath = os.path.join(P["render_dir"], P["id"] + "_icone.png")
bpy.ops.render.render(write_still=True)

met["secondes"] = round(time.time() - T0, 1)
with open(P["metrics"], "w", encoding="utf-8") as f:
    json.dump(met, f, ensure_ascii=False, indent=1)
log(f"fini en {met['secondes']} s")
