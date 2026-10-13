"""Conversion d'un modèle Eden Eternal (NIF + KF Gamebryo) en glTF binaire (.glb).

    nif2gltf.py <chemin_pkg_du_kfm_ou_nif> <dossier_sortie> [--tex-dir DIR]

Produit :
  <nom>.glb          maillages, squelette, skin, matériaux, toutes les séquences
  <nom>.anims.json   par séquence : durée, boucle, marqueurs texte (hit, sound...)
  textures PNG       dans --tex-dir (partagées entre modèles), référencées par URI
"""
import argparse
import hashlib
import io
import json
import math
import os
import re
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import edenpkg  # noqa: E402
import nif  # noqa: E402

PKG = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'EdenReforged', 'pkg')
FLT_INVALID = 3.0e38
FPS = 30.0

# Gamebryo est Z-up, glTF est Y-up : rotation de -90° autour de X.
ZUP_TO_YUP = [-math.sqrt(0.5), 0.0, 0.0, math.sqrt(0.5)]


# --- maths ------------------------------------------------------------------
def mat3(d):
    """Matrix33 NIF -> rotation (convention vecteur colonne).

    Gamebryo stocke la transposée : vérifié en exigeant que
    monde(os) @ skin(os) == monde(géométrie) sur les modèles skinnés.
    """
    return np.array([[d['m11'], d['m21'], d['m31']],
                     [d['m12'], d['m22'], d['m32']],
                     [d['m13'], d['m23'], d['m33']]], dtype=np.float64)


def vec3(d):
    return np.array([d['x'], d['y'], d['z']], dtype=np.float64)


def trs_mat(t, R, s):
    M = np.eye(4)
    M[:3, :3] = R * s
    M[:3, 3] = t
    return M


def quat_from_mat(R):
    """Matrice 3x3 (convention vecteur colonne) -> quaternion (x, y, z, w)."""
    m = R
    tr = m[0, 0] + m[1, 1] + m[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def valid(v):
    return abs(v) < FLT_INVALID


def fix_quat_signs(q):
    """Évite les sauts de signe entre clés successives (interpolation glTF)."""
    for i in range(1, len(q)):
        if np.dot(q[i - 1], q[i]) < 0:
            q[i] = -q[i]
    return q


# --- B-splines Gamebryo (degré 3, uniforme, bornée) -----------------------------
_basis_cache = {}


def bspline_basis(n, u):
    """Matrice (len(u), n) des fonctions de base pour n points de contrôle."""
    key = (n, len(u), float(u[0]), float(u[-1]))
    if key in _basis_cache:
        return _basis_cache[key]
    deg = 3
    knots = [0.0] * (deg + 1) + [float(i) for i in range(1, n - deg)] + [float(n - deg)] * (deg + 1)
    B = np.zeros((len(u), n))
    umax = n - deg
    for ti, uu in enumerate(u):
        uu = min(max(uu, 0.0), umax - 1e-9)
        k = int(uu) + deg
        # de Boor sur la base canonique
        N = np.zeros(deg + 1)
        N[0] = 1.0
        left = np.zeros(deg + 1)
        right = np.zeros(deg + 1)
        for j in range(1, deg + 1):
            left[j] = uu - knots[k + 1 - j]
            right[j] = knots[k + j] - uu
            saved = 0.0
            for r in range(j):
                den = right[r + 1] + left[j - r]
                tmp = N[r] / den if den else 0.0
                N[r] = saved + right[r + 1] * tmp
                saved = left[j - r] * tmp
            N[j] = saved
        B[ti, k - deg:k + 1] = N
    _basis_cache[key] = B
    return B


# --- glTF -------------------------------------------------------------------------
class Gltf:
    def __init__(self):
        self.j = {'asset': {'version': '2.0', 'generator': 'EdenSlash nif2gltf'},
                  'scene': 0, 'scenes': [{'nodes': []}], 'nodes': [], 'meshes': [],
                  'buffers': [], 'bufferViews': [], 'accessors': [], 'materials': [],
                  'textures': [], 'images': [], 'samplers': [{'magFilter': 9729, 'minFilter': 9987}],
                  'skins': [], 'animations': []}
        self.bin = bytearray()
        self.image_index = {}

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        bv = {'buffer': 0, 'byteOffset': len(self.bin), 'byteLength': len(data)}
        if target:
            bv['target'] = target
        self.bin += data
        self.j['bufferViews'].append(bv)
        return len(self.j['bufferViews']) - 1

    def accessor(self, arr, gtype, ctype=5126, target=None, minmax=False, normalized=False):
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[ctype]
        arr = np.ascontiguousarray(arr, dtype=dt)
        acc = {'bufferView': self.view(arr.tobytes(), target), 'componentType': ctype,
               'count': int(arr.shape[0]), 'type': gtype}
        if normalized:
            acc['normalized'] = True
        if minmax:
            a2 = arr.reshape(arr.shape[0], -1)
            acc['min'] = [float(x) for x in a2.min(axis=0)]
            acc['max'] = [float(x) for x in a2.max(axis=0)]
        self.j['accessors'].append(acc)
        return len(self.j['accessors']) - 1

    def image(self, uri):
        if uri not in self.image_index:
            self.j['images'].append({'uri': uri})
            self.j['textures'].append({'sampler': 0, 'source': len(self.j['images']) - 1})
            self.image_index[uri] = len(self.j['textures']) - 1
        return self.image_index[uri]

    def write(self, path):
        j = {k: v for k, v in self.j.items() if v != []}
        j['buffers'] = [{'byteLength': len(self.bin)}]
        js = json.dumps(j, separators=(',', ':')).encode()
        js += b' ' * ((4 - len(js) % 4) % 4)
        while len(self.bin) % 4:
            self.bin.append(0)
        with open(path, 'wb') as f:
            f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)))
            f.write(struct.pack('<II', len(js), 0x4E4F534A) + js)
            f.write(struct.pack('<II', len(self.bin), 0x004E4942) + bytes(self.bin))


# --- conversion ----------------------------------------------------------------------
class Converter:
    def __init__(self, idx, tex_dir, tex_uri_prefix, only_shapes=None):
        self.idx = idx
        self.only_shapes = set(only_shapes) if only_shapes else None
        self.anim_filter = None
        self.fx = None  # dict : mode effet (pistes de contrôleurs exportées en JSON)
        self._fx_names = set()
        self.collision = False
        self.dye = None
        self.keep_masks = False  # garde les masques de teinture (recoloration en jeu)
        self.dye_masks = {}  # texture teinte -> {mask, decal, key}
        self.by_name = {}
        for p in idx:
            self.by_name.setdefault(os.path.basename(p), []).append(p)
        self.tex_dir = tex_dir
        self.tex_uri_prefix = tex_uri_prefix
        self.warnings = []

    def read(self, path):
        return edenpkg.read_file(PKG, self.idx[path])

    def find_texture(self, fname, near):
        base = os.path.basename(fname.replace('\\', '/')).lower()
        cands = self.by_name.get(base, [])
        if not cands:
            return None
        top = near.split('/')[0]
        cands = sorted(cands, key=lambda p: (not p.startswith(top + '/'), p))
        return cands[0]

    def tex_path(self, prop, slot, model_path):
        src = prop[slot]['Source']
        st = self.blocks[src] if src is not None and src >= 0 else None
        if st is None:
            return None
        fname = st.get('File Name')
        if isinstance(fname, dict):
            fname = fname.get('Index') or fname.get('String') or ''
        path = self.find_texture(fname or '', model_path)
        if not path:
            self.warnings.append('texture introuvable %s' % fname)
        return path

    def load_rgba(self, pkg_path):
        from PIL import Image
        return np.asarray(Image.open(io.BytesIO(self.read(pkg_path))).convert('RGBA'), dtype=np.float32) / 255.0

    def dye_palette(self, matname):
        """Couleurs (R, V, B du masque) selon la catégorie de pièce."""
        m = matname.upper()
        if m.startswith('LFACE'):
            key = 'face'
        elif m.startswith('LBODY') or m.startswith('LX'):
            key = 'skin'
        elif re.match(r'L1\d', m):
            key = 'hair'
        else:
            key = 'outfit'
        return key, self.dye[key]

    def bake_dyed(self, base_path, decal_path, palette):
        """Masque de teinture (canaux R/V/B ombrés) x palette, puis détails A par-dessus."""
        from PIL import Image
        key, cols = palette
        stem = os.path.splitext(os.path.basename(base_path))[0]
        tag = '%s_%s' % (key, '_'.join('%02x%02x%02x' % tuple(c) for c in cols))
        name = '%s__%s.png' % (stem, hashlib.md5(tag.encode()).hexdigest()[:6])
        out = os.path.join(self.tex_dir, name)
        if self.keep_masks:
            mask = '%s_dyemask.png' % stem
            mpath = os.path.join(self.tex_dir, mask)
            if not os.path.exists(mpath):
                os.makedirs(self.tex_dir, exist_ok=True)
                img = Image.open(io.BytesIO(self.read(base_path))).convert('RGBA')
                if max(img.size) > 256:
                    img.thumbnail((256, 256), Image.LANCZOS)
                img.save(mpath, optimize=True)
            dec = None
            if decal_path:
                dec = os.path.splitext(os.path.basename(decal_path))[0] + '.png'
                if not os.path.exists(os.path.join(self.tex_dir, dec)):
                    img = Image.open(io.BytesIO(self.read(decal_path))).convert('RGBA')
                    if max(img.size) > 512:
                        img.thumbnail((512, 512), Image.LANCZOS)
                    img.save(os.path.join(self.tex_dir, dec), optimize=True)
            self.dye_masks[name] = {'mask': mask, 'decal': dec, 'key': key}
        if not os.path.exists(out):
            m = self.load_rgba(base_path)
            c = np.array(cols, dtype=np.float32) / 255.0  # (3, 3)
            rgb = m[..., 0:1] * c[0] + m[..., 1:2] * c[1] + m[..., 2:3] * c[2]
            rgb = np.clip(rgb, 0, 1)
            alpha = m[..., 3:4]
            if decal_path:
                a = self.load_rgba(decal_path)
                if a.shape != m.shape:
                    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize(m.shape[1::-1]), dtype=np.float32) / 255.0
                rgb = rgb * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]
            img = np.concatenate([rgb, alpha], axis=-1)
            os.makedirs(self.tex_dir, exist_ok=True)
            Image.fromarray((img * 255 + 0.5).astype(np.uint8), 'RGBA').save(out, optimize=True)
        return self.tex_uri_prefix + name

    def export_texture(self, pkg_path):
        from PIL import Image
        name = os.path.splitext(os.path.basename(pkg_path))[0] + '.png'
        out = os.path.join(self.tex_dir, name)
        if not os.path.exists(out):
            img = Image.open(io.BytesIO(self.read(pkg_path)))
            img.load()
            img = img.convert('RGBA')
            os.makedirs(self.tex_dir, exist_ok=True)
            img.save(out, optimize=True)
        return self.tex_uri_prefix + name

    # ---- scène ----
    def convert(self, model_path, kf_paths, out_glb):
        nf = nif.NifFile.parse(self.read(model_path))
        blocks = self.blocks = nf.blocks
        for b in blocks:
            if b.error and b.type in ('NiNode', 'NiTriShape', 'NiTriStrips', 'NiTriShapeData',
                                     'NiTriStripsData', 'NiSkinInstance', 'NiSkinData'):
                raise RuntimeError('bloc essentiel illisible %s: %s' % (b.type, b.error))
        g = Gltf()
        root = {'name': 'EdenRoot', 'rotation': ZUP_TO_YUP, 'children': []}
        g.j['nodes'].append(root)
        g.j['scenes'][0]['nodes'].append(0)
        node_of_block = {}
        world = {}
        pending_skins = []
        name_to_node = {}

        def as_list(v):
            if v is None:
                return []
            if isinstance(v, (int, np.integer)):
                return [int(v)]
            return [int(x) for x in v]

        def visit(bi, parent_node, parent_world, props):
            b = blocks[bi]
            if b.error or not nif.Spec.get().inherits(b.type, 'NiAVObject'):
                return
            if b.type.startswith('NiPSys') or b.type in ('NiParticleSystem', 'NiCamera', 'NiAmbientLight',
                                                        'NiDirectionalLight', 'NiPointLight'):
                return
            t, R, s = vec3(b['Translation']), mat3(b['Rotation']), float(b['Scale'])
            node = {'name': b['Name'] or ('%s_%d' % (b.type, bi))}
            if self.fx is not None:
                node['name'] = self._fx_name(node['name'], bi)
            if np.linalg.norm(t) > 0:
                node['translation'] = [float(x) for x in t]
            q = quat_from_mat(R)
            if abs(q[3]) < 0.999999:
                node['rotation'] = [float(x) for x in q]
            if abs(s - 1) > 1e-6:
                node['scale'] = [s, s, s]
            ni = len(g.j['nodes'])
            g.j['nodes'].append(node)
            g.j['nodes'][parent_node].setdefault('children', []).append(ni)
            node_of_block[bi] = ni
            name_to_node.setdefault(node['name'], ni)
            W = parent_world @ trs_mat(t, R, s)
            world[bi] = W
            props = props + [blocks[p] for p in as_list(b.get('Properties')) if p >= 0]
            if b.type in ('NiTriShape', 'NiTriStrips'):
                if self.only_shapes is not None and b['Name'] not in self.only_shapes:
                    g.j['nodes'][parent_node]['children'].remove(ni)
                    g.j['nodes'][ni] = {'name': '_unused'}
                    return
                textured = any(pp.type == 'NiTexturingProperty' for pp in props)
                collider = self.collision and not textured
                # forme cachée (bit 0 des drapeaux) ou repère sans texture d'un effet : ignorée
                if (int(b.get('Flags', 0)) & 1 and not collider) or (self.fx is not None and not textured):
                    g.j['nodes'][parent_node]['children'].remove(ni)
                    g.j['nodes'][ni] = {'name': '_unused'}
                    return
                if collider and (b['Name'] or '').lower().startswith('camera'):
                    g.j['nodes'][parent_node]['children'].remove(ni)
                    g.j['nodes'][ni] = {'name': '_unused'}
                    return
                mesh = self.mesh(g, b, blocks, props, model_path, collider)
                if mesh is not None:
                    node['mesh'] = mesh
                    if self.fx is not None:
                        self._fx_material(node['name'], props, blocks, model_path, g)
                    if collider:
                        # convention d'import Godot : collision sans rendu
                        node['name'] = node['name'] + '-colonly'
                    if b.get('Skin Instance', -1) >= 0:
                        pending_skins.append((ni, bi))
            if self.fx is not None:
                self._fx_node(node['name'], b, blocks)
            for c in as_list(b.get('Children')):
                if c >= 0:
                    visit(c, ni, W, props)

        for r in nf.roots:
            if r >= 0:
                visit(r, 0, np.eye(4), [])

        for ni, bi in pending_skins:
            self.skin(g, ni, bi, blocks, node_of_block, world)

        anims = {}
        for kp in kf_paths:
            try:
                kf = nif.NifFile.parse(self.read(kp))
            except Exception as ex:
                self.warnings.append('kf illisible %s: %s' % (kp, ex))
                continue
            for seq in kf.blocks:
                if self.anim_filter and not re.fullmatch(self.anim_filter, seq.get('Name', '')):
                    continue
                if seq.type == 'NiControllerSequence' and not seq.error:
                    info = self.animation(g, seq, kf.blocks, name_to_node)
                    if info:
                        anims[seq['Name']] = info
        g.write(out_glb)
        return anims

    def mesh(self, g, geom, blocks, props, model_path, collider=False):
        d = blocks[geom['Data']] if geom.get('Data', -1) >= 0 else None
        if d is None or d.error or not d.get('Num Vertices'):
            return None
        verts = np.asarray(d['Vertices'], dtype=np.float32).reshape(-1, 3)
        attrs = {'POSITION': g.accessor(verts, 'VEC3', target=34962, minmax=True)}
        if d.get('Has Normals'):
            n = np.asarray(d['Normals'], dtype=np.float32).reshape(-1, 3)
            ln = np.linalg.norm(n, axis=1, keepdims=True)
            ln[ln == 0] = 1
            attrs['NORMAL'] = g.accessor(n / ln, 'VEC3', target=34962)
        uvs = d.get('UV Sets')
        if uvs is not None and len(uvs):
            uv = np.asarray(uvs[0], dtype=np.float32).reshape(-1, 2)
            attrs['TEXCOORD_0'] = g.accessor(uv, 'VEC2', target=34962)
        if d.get('Has Vertex Colors'):
            col = np.clip(np.asarray(d['Vertex Colors'], dtype=np.float32).reshape(-1, 4), 0, 1)
            attrs['COLOR_0'] = g.accessor(col, 'VEC4', target=34962)

        if d.type == 'NiTriShapeData':
            tris = np.asarray(d.get('Triangles', []), dtype=np.uint32).reshape(-1, 3)
        else:
            tl = []
            for strip in d.get('Points', []):
                strip = [int(x) for x in np.atleast_1d(strip)]
                for i in range(len(strip) - 2):
                    a, b_, c = strip[i], strip[i + 1], strip[i + 2]
                    if a == b_ or b_ == c or a == c:
                        continue
                    tl.append((a, b_, c) if i % 2 == 0 else (a, c, b_))
            tris = np.array(tl, dtype=np.uint32).reshape(-1, 3)
        if not len(tris):
            return None
        prim = {'attributes': attrs, 'indices': g.accessor(tris.reshape(-1), 'SCALAR', 5125, target=34963)}
        if not collider:
            prim['material'] = self.material(g, props, model_path)
        geom['_prim'] = prim
        g.j['meshes'].append({'name': geom['Name'], 'primitives': [prim]})
        return len(g.j['meshes']) - 1

    def material(self, g, props, model_path):
        mat = {'pbrMetallicRoughness': {'metallicFactor': 0.0, 'roughnessFactor': 0.9}}
        name = 'mat'
        for p in props:
            if p.type == 'NiTexturingProperty' and p.get('Has Base Texture'):
                base = self.tex_path(p, 'Base Texture', model_path)
                decal = self.tex_path(p, 'Decal 1 Texture', model_path) if p.get('Has Decal 1 Texture') else None
                if base:
                    try:
                        if self.dye is not None:
                            uri = self.bake_dyed(base, decal, self.dye_palette(material_name(props)))
                        else:
                            uri = self.export_texture(base)
                        mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': g.image(uri)}
                        name = os.path.splitext(os.path.basename(uri))[0]
                    except Exception as ex:
                        self.warnings.append('texture %s: %s' % (base, ex))
            elif p.type == 'NiAlphaProperty':
                fl = int(p['Flags'])
                if fl & 0x200:
                    mat['alphaMode'] = 'MASK'
                    mat['alphaCutoff'] = int(p['Threshold']) / 255.0
                elif fl & 1:
                    mat['alphaMode'] = 'BLEND'
            elif p.type == 'NiMaterialProperty':
                a = float(p.get('Alpha', 1.0))
                if a < 0.999:
                    mat['pbrMetallicRoughness']['baseColorFactor'] = [1, 1, 1, a]
                    mat.setdefault('alphaMode', 'BLEND')
            elif p.type == 'NiStencilProperty':
                # draw mode 3 = both faces
                if ((int(p.get('Flags', 0)) >> 10) & 3) == 3 or p.get('Draw Mode') == 3:
                    mat['doubleSided'] = True
        mat['name'] = name
        g.j['materials'].append(mat)
        return len(g.j['materials']) - 1

    def skin(self, g, ni, bi, blocks, node_of_block, world):
        geom = blocks[bi]
        si = blocks[geom['Skin Instance']]
        sd = blocks[si['Data']]
        bones = [int(x) for x in np.atleast_1d(si['Bones'])]
        if any(b not in node_of_block for b in bones):
            self.warnings.append('os manquant pour %s' % geom['Name'])
            return
        nverts = blocks[geom['Data']]['Num Vertices']
        infl = [[] for _ in range(nverts)]
        if sd.get('Has Vertex Weights'):
            for bidx, bd in enumerate(sd['Bone List']):
                for vw in bd.get('Vertex Weights', []):
                    if vw['Weight'] > 0:
                        infl[vw['Index']].append((vw['Weight'], bidx))
        elif si.get('Skin Partition', -1) >= 0:
            sp = blocks[si['Skin Partition']]
            for part in sp.get('Partitions', []):
                pbones = np.atleast_1d(part['Bones'])
                vmap = np.atleast_1d(part['Vertex Map'])
                w = np.asarray(part['Vertex Weights']).reshape(len(vmap), -1)
                bix = np.asarray(part['Bone Indices']).reshape(len(vmap), -1)
                for k, v in enumerate(vmap):
                    for j in range(w.shape[1]):
                        if w[k, j] > 0:
                            infl[int(v)].append((float(w[k, j]), int(pbones[bix[k, j]])))
        joints = np.zeros((nverts, 4), dtype=np.uint16)
        weights = np.zeros((nverts, 4), dtype=np.float32)
        for v, lst in enumerate(infl):
            lst = sorted(lst, reverse=True)[:4]
            tot = sum(w for w, _ in lst) or 1.0
            for j, (w, b) in enumerate(lst):
                joints[v, j] = b
                weights[v, j] = w / tot
            if not lst:
                weights[v, 0] = 1.0
        # contrôle : le skin doit être exprimé dans l'espace monde de la racine
        K = world[bi] @ trs_mat(vec3(sd['Skin Transform']['Translation']),
                                mat3(sd['Skin Transform']['Rotation']),
                                float(sd['Skin Transform']['Scale']))
        if not np.allclose(K, np.eye(4), atol=1e-3):
            self.warnings.append('skin non-identité pour %s (approximé)' % geom['Name'])
        ibms = []
        for bd in sd['Bone List']:
            st = bd['Skin Transform']
            M = trs_mat(vec3(st['Translation']), mat3(st['Rotation']), float(st['Scale']))
            ibms.append(M @ K)
        ibm = np.array([m.T.reshape(-1) for m in ibms], dtype=np.float32)
        prim = geom['_prim']
        prim['attributes']['JOINTS_0'] = g.accessor(joints, 'VEC4', 5123, target=34962)
        prim['attributes']['WEIGHTS_0'] = g.accessor(weights, 'VEC4', target=34962)
        g.j['skins'].append({'joints': [node_of_block[b] for b in bones],
                             'inverseBindMatrices': g.accessor(ibm, 'MAT4'),
                             'skeleton': 0})
        g.j['nodes'][ni]['skin'] = len(g.j['skins']) - 1

    # ---- animation ----
    def animation(self, g, seq, blocks, name_to_node):
        t0, t1 = float(seq['Start Time']), float(seq['Stop Time'])
        if t1 <= t0:
            return None
        nframes = max(2, int(round((t1 - t0) * FPS)) + 1)
        times = np.linspace(t0, t1, nframes)
        tacc = g.accessor((times - t0).astype(np.float32), 'SCALAR', minmax=True)
        tacc1 = None
        anim = {'name': seq['Name'], 'channels': [], 'samplers': []}
        rest_default = {'translation': [0, 0, 0], 'rotation': [0, 0, 0, 1], 'scale': [1, 1, 1]}

        def add(node, path, values, gtype):
            nonlocal tacc1
            inp = tacc
            if np.ptp(values, axis=0).max() < 1e-4:
                # piste constante : rien si égale à la pose de repos, sinon une seule clé
                rest = np.array(g.j['nodes'][node].get(path, rest_default[path]))
                v0 = values[0]
                same = (abs(abs(float(np.dot(v0, rest))) - 1) < 1e-6) if path == 'rotation' else np.allclose(v0, rest, atol=1e-4)
                if same:
                    return
                if tacc1 is None:
                    tacc1 = g.accessor(np.zeros(1, dtype=np.float32), 'SCALAR', minmax=True)
                inp, values = tacc1, values[:1]
            anim['samplers'].append({'input': inp, 'output': g.accessor(values, gtype), 'interpolation': 'LINEAR'})
            anim['channels'].append({'sampler': len(anim['samplers']) - 1, 'target': {'node': node, 'path': path}})

        for cb in seq['Controlled Blocks']:
            node = name_to_node.get(cb.get('Node Name'))
            ii = cb.get('Interpolator', -1)
            if node is None or ii is None or ii < 0 or cb.get('Controller Type') not in ('NiTransformController', 'NiKeyframeController', ''):
                continue
            ip = blocks[ii]
            if ip.error:
                continue
            res = self.sample_interp(ip, blocks, times)
            if res is None:
                continue
            tr, rot, sc = res
            if tr is not None:
                add(node, 'translation', tr, 'VEC3')
            if rot is not None:
                add(node, 'rotation', fix_quat_signs(rot), 'VEC4')
            if sc is not None:
                add(node, 'scale', np.repeat(sc.reshape(-1, 1), 3, axis=1), 'VEC3')
        if not anim['channels']:
            return None
        g.j['animations'].append(anim)
        keys = []
        tk = seq.get('Text Keys', -1)
        if tk is not None and tk >= 0 and not blocks[tk].error:
            for k in blocks[tk].get('Text Keys', []):
                keys.append({'time': round(float(k['Time']) - t0, 4), 'text': k['Value']})
        return {'duration': round(t1 - t0, 4), 'loop': int(seq.get('Cycle Type', 0)) == 0,
                'frequency': float(seq.get('Frequency', 1.0)), 'keys': keys}

    def sample_interp(self, ip, blocks, times):
        n = len(times)
        T = ip.get('Transform')
        if ip.type in ('NiBSplineCompTransformInterpolator', 'NiBSplineTransformInterpolator'):
            if ip.get('Spline Data', -1) < 0 or ip.get('Basis Data', -1) < 0:
                return self.fill_static(T, None, None, None, n)
            sd, bd = blocks[ip['Spline Data']], blocks[ip['Basis Data']]
            ncp = int(bd['Num Control Points'])
            s0, s1 = float(ip['Start Time']), float(ip['Stop Time'])
            u = (np.clip(times, s0, s1) - s0) / max(s1 - s0, 1e-9) * (ncp - 3)
            B = bspline_basis(ncp, u)
            comp = ip.type == 'NiBSplineCompTransformInterpolator'

            def cps(handle, dim, off_key, half_key):
                if handle == 0xFFFF:
                    return None
                if comp:
                    raw = np.asarray(sd['Compact Control Points'], dtype=np.float64)[handle:handle + ncp * dim]
                    vals = float(ip[off_key]) + raw / 32767.0 * float(ip[half_key])
                else:
                    vals = np.asarray(sd['Float Control Points'], dtype=np.float64)[handle:handle + ncp * dim]
                return B @ vals.reshape(ncp, dim)

            tr = cps(ip['Translation Handle'], 3, 'Translation Offset', 'Translation Half Range')
            rq = cps(ip['Rotation Handle'], 4, 'Rotation Offset', 'Rotation Half Range')
            sc = cps(ip['Scale Handle'], 1, 'Scale Offset', 'Scale Half Range')
            rot = None
            if rq is not None:
                rot = rq[:, [1, 2, 3, 0]]
                rot /= np.linalg.norm(rot, axis=1, keepdims=True)
            sc = sc[:, 0] if sc is not None else None
            return self.fill_static(T, tr, rot, sc, n)
        if ip.type == 'NiTransformInterpolator':
            tr = rot = sc = None
            di = ip.get('Data', -1)
            if di is not None and di >= 0 and not blocks[di].error:
                d = blocks[di]
                tg = d.get('Translations') or {}
                if tg.get('Num Keys'):
                    tr = interp_keys([(k['Time'], vec3(k['Value'])) for k in tg['Keys']], times)
                if d.get('Num Rotation Keys'):
                    if d.get('Rotation Type') == 4:
                        rot = euler_keys(d['XYZ Rotations'], times)
                    else:
                        qk = [(k['Time'], np.array([k['Value']['x'], k['Value']['y'], k['Value']['z'], k['Value']['w']]))
                              for k in d['Quaternion Keys']]
                        rot = slerp_keys(qk, times)
                sg = d.get('Scales') or {}
                if sg.get('Num Keys'):
                    sc = interp_keys([(k['Time'], np.array([k['Value']])) for k in sg['Keys']], times)[:, 0]
            return self.fill_static(T, tr, rot, sc, n)
        return None

    @staticmethod
    def fill_static(T, tr, rot, sc, n):
        if T is not None:
            if tr is None and valid(T['Translation']['x']):
                tr = np.tile(vec3(T['Translation']), (n, 1))
            q = T['Rotation']
            if rot is None and valid(q['w']):
                rot = np.tile(np.array([q['x'], q['y'], q['z'], q['w']]), (n, 1))
            if sc is None and valid(T['Scale']):
                sc = np.full(n, float(T['Scale']))
        if tr is None and rot is None and sc is None:
            return None
        return tr, rot, sc


# --- effets (contrôleurs Gamebryo -> pistes échantillonnées) --------------------------
FX_FPS = 30.0


def _ctrl_chain(b, blocks):
    out = []
    c = b.get('Controller', -1)
    seen = set()
    while c is not None and c >= 0 and c not in seen:
        seen.add(c)
        cb = blocks[c]
        if cb.error:
            break
        out.append(cb)
        c = cb.get('Next Controller', -1)
    return out


def _ctrl_times(cb, times):
    """Temps local du contrôleur (fréquence, phase, boucle / aller-retour / bloqué)."""
    t0, t1 = float(cb.get('Start Time', 0.0)), float(cb.get('Stop Time', 0.0))
    freq = float(cb.get('Frequency', 1.0)) or 1.0
    ph = float(cb.get('Phase', 0.0))
    cycle = (int(cb.get('Flags', 0)) >> 1) & 3
    span = max(t1 - t0, 1e-6)
    lt = times * freq + ph
    if cycle == 0:
        return t0 + np.mod(lt - t0, span)
    if cycle == 1:
        m = np.mod(lt - t0, 2 * span)
        return t0 + np.where(m > span, 2 * span - m, m)
    return np.clip(lt, t0, t1)


def _sample_scalar(ip, blocks, lt):
    if ip is None or ip.error:
        return None
    if ip.type == 'NiBoolInterpolator':
        d = ip.get('Data', -1)
        if d is not None and d >= 0 and not blocks[d].error and blocks[d]['Data'].get('Num Keys'):
            keys = blocks[d]['Data']['Keys']
            kt = np.array([k['Time'] for k in keys])
            kv = np.array([float(k['Value']) for k in keys])
            idx = np.clip(np.searchsorted(kt, lt, side='right') - 1, 0, len(kt) - 1)
            return kv[idx]
        v = int(ip.get('Value', 2))
        return np.full(len(lt), 1.0 if v == 1 else 0.0) if v in (0, 1) else None
    if ip.type == 'NiFloatInterpolator':
        d = ip.get('Data', -1)
        if d is not None and d >= 0 and not blocks[d].error and blocks[d]['Data'].get('Num Keys'):
            keys = blocks[d]['Data']['Keys']
            return interp_keys([(k['Time'], np.array([k['Value']])) for k in keys], lt)[:, 0]
        v = float(ip.get('Value', -FLT_INVALID))
        return np.full(len(lt), v) if valid(v) else None
    return None


def _sample_vec3(ip, blocks, lt):
    if ip is None or ip.error or ip.type != 'NiPoint3Interpolator':
        return None
    d = ip.get('Data', -1)
    if d is not None and d >= 0 and not blocks[d].error and blocks[d]['Data'].get('Num Keys'):
        keys = blocks[d]['Data']['Keys']
        return interp_keys([(k['Time'], vec3(k['Value'])) for k in keys], lt)
    v = ip.get('Value')
    return np.tile(vec3(v), (len(lt), 1)) if v and valid(v['x']) else None


def _ctrl_duration(cb):
    freq = float(cb.get('Frequency', 1.0)) or 1.0
    return max(0.0, (float(cb.get('Stop Time', 0.0)) - float(cb.get('Phase', 0.0))) / freq)


def _r(a, nd=4):
    return np.round(np.asarray(a, dtype=np.float64), nd).tolist()


def _fx_name(self, name, bi):
    n = re.sub(r'[^A-Za-z0-9_]', '_', name) or 'node'
    if n in self._fx_names:
        n = '%s_%d' % (n, bi)
    self._fx_names.add(n)
    return n


def _fx_node(self, name, b, blocks):
    for cb in _ctrl_chain(b, blocks):
        self.fx.setdefault('_ctrls', []).append((name, 'node', cb, None))


def _fx_material(self, name, props, blocks, model_path, g):
    info = {'blend': 'mix', 'alpha': 1.0, 'color': [1, 1, 1], 'vcol': True}
    for p in props:
        if p.type == 'NiVertexColorProperty':
            # mode des couleurs de sommets : 0 = ignorées
            info['vcol'] = ((int(p.get('Flags', 0)) >> 4) & 3) != 0  # bits 4-5 en 20.x
        if p.type == 'NiAlphaProperty':
            fl = int(p['Flags'])
            dst = (fl >> 5) & 15
            # destination ONE ou SRC_COLOR : effet lumineux additif
            info['blend'] = 'add' if (fl & 1 and dst in (0, 2)) else ('mix' if fl & 1 else 'opaque')
        elif p.type == 'NiMaterialProperty':
            info['alpha'] = float(p.get('Alpha', 1.0))
            info['_emis'] = p.get('Emissive Color')
            info['_diff'] = p.get('Diffuse Color')
        for cb in _ctrl_chain(p, blocks):
            self.fx.setdefault('_ctrls', []).append((name, 'mat', cb, p))
    # additif : la couleur émissive porte la teinte ; mélange : la diffuse
    c = info.pop('_emis', None) if info['blend'] == 'add' else info.pop('_diff', None)
    info.pop('_emis', None)
    info.pop('_diff', None)
    if c and max(c['r'], c['g'], c['b']) > 0.01:
        info['color'] = [float(c['r']), float(c['g']), float(c['b'])]
    self.fx.setdefault('materials', {})[name] = info


def fx_finalize(conv, blocks):
    """Échantillonne toutes les pistes à 30 i/s sur la durée de l'effet."""
    ctrls = conv.fx.pop('_ctrls', [])
    dur = 0.0
    for _, _, cb, _ in ctrls:
        if (int(cb.get('Flags', 0)) >> 1) & 3 == 2:
            dur = max(dur, _ctrl_duration(cb))
    if dur <= 0.0:
        dur = max([_ctrl_duration(cb) for _, _, cb, _ in ctrls] or [1.0])
    dur = min(max(dur, 0.2), 6.0)
    times = np.arange(0.0, dur + 1e-6, 1.0 / FX_FPS)
    nodes = {}
    mats = conv.fx.setdefault('materials', {})
    for name, kind, cb, prop in ctrls:
        ii = cb.get('Interpolator', -1)
        ip = blocks[ii] if ii is not None and ii >= 0 else None
        lt = _ctrl_times(cb, times)
        if kind == 'node':
            if cb.type in ('NiTransformController', 'NiKeyframeController') and ip is not None and not ip.error:
                res = conv.sample_interp(ip, blocks, lt)
                if res:
                    tr, rot, sc = res
                    nd = nodes.setdefault(name, {})
                    if tr is not None:
                        nd['t'] = _r(tr)
                    if rot is not None:
                        nd['r'] = _r(fix_quat_signs(rot))
                    if sc is not None:
                        nd['s'] = _r(sc)
            elif cb.type == 'NiVisController':
                v = _sample_scalar(ip, blocks, lt)
                if v is not None:
                    nodes.setdefault(name, {})['vis'] = _r(v, 0)
            continue
        m = mats.setdefault(name, {})
        if cb.type == 'NiAlphaController':
            v = _sample_scalar(ip, blocks, lt)
            if v is not None:
                m['alpha_t'] = _r(v, 3)
        elif cb.type == 'NiMaterialColorController':
            v = _sample_vec3(ip, blocks, lt)
            if v is not None and int(cb.get('Target Color', 1)) in (1, 3):
                m['color_t'] = _r(v, 3)
        elif cb.type == 'NiTextureTransformController':
            v = _sample_scalar(ip, blocks, lt)
            if v is not None:
                op = int(cb.get('Operation', 0))
                m[['uv_u', 'uv_v', 'uv_rot', 'uv_su', 'uv_sv'][min(op, 4)]] = _r(v, 4)
        elif cb.type == 'NiFlipController':
            v = _sample_scalar(ip, blocks, lt)
            uris = []
            for si in np.atleast_1d(cb.get('Sources', [])):
                st = blocks[int(si)] if int(si) >= 0 else None
                fname = st.get('File Name') if st is not None else None
                if isinstance(fname, dict):
                    fname = fname.get('Index') or ''
                path = conv.find_texture(fname or '', 'effect/')
                if path:
                    uris.append(conv.export_texture(path))
            if v is not None and uris:
                m['flip'] = {'textures': uris, 'frames': [int(x) for x in np.clip(v, 0, len(uris) - 1)]}
    conv.fx['nodes'] = nodes
    conv.fx['duration'] = round(dur, 3)
    conv.fx['fps'] = FX_FPS
    return conv.fx


Converter._fx_name = _fx_name
Converter._fx_node = _fx_node
Converter._fx_material = _fx_material


def material_name(props):
    for p in props:
        if p.type == 'NiMaterialProperty':
            return p.get('Name') or ''
    return ''


DEFAULT_DYE = {
    # canal R, V, B du masque
    'skin': [[255, 222, 200], [240, 190, 170], [200, 150, 140]],
    'face': [[255, 222, 200], [70, 130, 210], [220, 120, 120]],
    'hair': [[120, 72, 48], [90, 50, 35], [60, 40, 30]],
    'outfit': [[70, 95, 160], [215, 190, 120], [60, 50, 50]],
}


def interp_keys(keys, times):
    kt = np.array([k[0] for k in keys])
    kv = np.array([k[1] for k in keys])
    return np.stack([np.interp(times, kt, kv[:, i]) for i in range(kv.shape[1])], axis=1)


def slerp_keys(keys, times):
    kt = np.array([k[0] for k in keys])
    kv = fix_quat_signs(np.array([k[1] for k in keys], dtype=np.float64))
    out = np.zeros((len(times), 4))
    for i, t in enumerate(times):
        j = np.searchsorted(kt, t, side='right') - 1
        j = min(max(j, 0), len(kt) - 1)
        if j == len(kt) - 1 or kt[j + 1] == kt[j]:
            out[i] = kv[j]
            continue
        a = (t - kt[j]) / (kt[j + 1] - kt[j])
        q = (1 - a) * kv[j] + a * kv[j + 1]  # nlerp
        out[i] = q / np.linalg.norm(q)
    return out


def euler_keys(groups, times):
    ang = []
    for gr in groups:
        if gr.get('Num Keys'):
            ang.append(interp_keys([(k['Time'], np.array([k['Value']])) for k in gr['Keys']], times)[:, 0])
        else:
            ang.append(np.zeros(len(times)))
    out = []
    for x, y, z in zip(*ang):
        cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
        Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
        Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
        Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
        out.append(quat_from_mat(Rz @ Ry @ Rx))
    return np.array(out)


def kfm_files(data):
    """Extrait le modèle et les .kf référencés par un .kfm.

    Les chemins sont des chaînes préfixées par leur longueur (uint32) et
    commencent par '.\\'.
    """
    paths = []
    pos = data.find(b'.\\')
    while pos >= 4:
        n = struct.unpack_from('<I', data, pos - 4)[0]
        if 0 < n < 260:
            paths.append(data[pos:pos + n].decode('cp1252', 'ignore'))
        pos = data.find(b'.\\', pos + 2)
    nif_ = [p for p in paths if p.lower().endswith('.nif')]
    kfs = [p for p in paths if p.lower().endswith('.kf')]
    return nif_, kfs


def resolve(base_dir, rel):
    rel = rel.replace('\\', '/').lstrip('./').lower()
    return (base_dir + '/' + rel) if base_dir else rel


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src', help='chemin pkg d\'un .kfm ou .nif (ex: monster/m010.kfm)')
    ap.add_argument('out_dir')
    ap.add_argument('--tex-dir', default=None)
    ap.add_argument('--tex-uri', default='../textures/')
    ap.add_argument('--only', default=None, help='pièces à garder, séparées par des virgules')
    ap.add_argument('--name', default=None, help='nom des fichiers de sortie')
    ap.add_argument('--dye', default=None, help="'default' ou JSON {skin,face,hair,outfit: [[r,g,b]x3]}")
    ap.add_argument('--collision', action='store_true', help='formes sans texture -> collisions Godot (-colonly)')
    ap.add_argument('--anims', default=None, help='regex des séquences à garder')
    ap.add_argument('--extra-kf', default='', help='.kf supplémentaires, séparés par des virgules')
    a = ap.parse_args()
    idx = {e['path']: e for e in edenpkg.load_index(PKG)}
    tex_dir = a.tex_dir or os.path.join(a.out_dir, '..', 'textures')
    conv = Converter(idx, tex_dir, a.tex_uri, a.only.split(',') if a.only else None)
    conv.anim_filter = a.anims
    conv.collision = a.collision
    if a.dye:
        conv.dye = dict(DEFAULT_DYE)
        if a.dye != 'default':
            conv.dye.update(json.loads(a.dye))
    src = a.src.lower()
    base = os.path.dirname(src)
    if src.endswith('.kfm'):
        nifs, kfs = kfm_files(conv.read(src))
        model = resolve(base, nifs[0])
        kf_paths = [resolve(base, k) for k in kfs]
    else:
        model, kf_paths = src, []
    kf_paths += [k.strip().lower() for k in a.extra_kf.split(',') if k.strip()]
    kf_paths = [k for k in dict.fromkeys(kf_paths) if k in idx]
    name = a.name or os.path.splitext(os.path.basename(src))[0]
    os.makedirs(a.out_dir, exist_ok=True)
    out = os.path.join(a.out_dir, name + '.glb')
    anims = conv.convert(model, kf_paths, out)
    with open(os.path.join(a.out_dir, name + '.anims.json'), 'w', encoding='utf-8') as f:
        json.dump(anims, f, indent=1, ensure_ascii=False)
    print('%s -> %s (%d anims)' % (src, out, len(anims)))
    for w in conv.warnings:
        print('  ! ' + w)


if __name__ == '__main__':
    main()
