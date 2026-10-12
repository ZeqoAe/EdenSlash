"""Conversion d'effets visuels d'Eden (effect/model/*.nif) pour Godot.

    python -I tools/fx2godot.py s36041 s36021 ...

Produit game/assets/fx/<nom>.glb (maillages) + <nom>.fx.json (pistes animées :
transformations, visibilité, transparence, couleur, défilement et planches de
texture) lus par scripts/combat/eden_fx.gd. Textures dans game/assets/fx/textures.
"""
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), '..', 'game', 'assets', 'fx')


def _node_textures(glb_path):
    """nom de nœud -> uri de texture, lu dans le JSON du .glb."""
    b = open(glb_path, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    out = {}
    for nd in j.get('nodes', []):
        if 'mesh' not in nd:
            continue
        prim = j['meshes'][nd['mesh']]['primitives'][0]
        mat = j['materials'][prim['material']] if 'material' in prim else {}
        t = mat.get('pbrMetallicRoughness', {}).get('baseColorTexture', {}).get('index')
        if t is not None:
            out[nd['name']] = j['images'][j['textures'][t]['source']].get('uri')
    return out


_edge_cache = {}


def _hard_edges(uri, blend):
    """Vrai si la texture reste opaque / lumineuse jusqu'au bord : le quad
    apparaîtrait comme un carré plein (textures prévues pour d'autres modes
    de mélange de Gamebryo)."""
    key = (uri, blend)
    if key not in _edge_cache:
        im = Image.open(os.path.join(OUT, uri)).convert('RGBA')
        w, h = im.size
        px = im.load()
        ring = [px[x, y] for x in range(w) for y in (0, 1, h - 2, h - 1)]
        ring += [px[x, y] for y in range(h) for x in (0, 1, w - 2, w - 1)]
        if blend == 'add':
            v = sum(max(r, g, b_) * a for r, g, b_, a in ring) / (len(ring) * 255.0 * 255.0)
        else:
            v = sum(a for *_, a in ring) / (len(ring) * 255.0)
        _edge_cache[key] = v > 0.3
    return _edge_cache[key]


def _node_vertex_counts(glb_path):
    """nom de nœud -> nombre de sommets de son maillage."""
    _bin, j = _glb_parts(glb_path)
    out = {}
    for nd in j.get('nodes', []):
        if 'mesh' in nd:
            prim = j['meshes'][nd['mesh']]['primitives'][0]
            out[nd['name']] = j['accessors'][prim['attributes']['POSITION']]['count']
    return out


_opaque_cache = {}


def _opaque_share(uri):
    """Part des pixels presque opaques de la texture (modèle plein vs voile translucide)."""
    if uri not in _opaque_cache:
        a = Image.open(os.path.join(OUT, uri)).convert('RGBA').getchannel('A')
        hist = a.histogram()
        _opaque_cache[uri] = sum(hist[205:]) / max(1, sum(hist))
    return _opaque_cache[uri]


def mark_hard_quads(name, quads_only=False):
    """Marque 'hide' les matériaux d'un effet converti dont le quad aurait des bords durs.
    [quads_only] (auras) : seulement les vrais quads (4 à 8 sommets), pas les maillages
    (dragon, papillons) dont la texture touche le bord ; et les voiles translucides en
    mélange normal (panneaux pâles rectangulaires autour du héros) sont masqués : on ne
    garde que la lumière (additif) et les modèles pleins."""
    js = os.path.join(OUT, name + '.fx.json')
    fx = json.load(open(js, encoding='utf-8'))
    glb = os.path.join(OUT, fx.get('glb', name) + '.glb')
    tex = _node_textures(glb)
    verts = _node_vertex_counts(glb) if quads_only else {}
    hidden = []
    for node, info in fx.get('materials', {}).items():
        uri = info.get('tex', tex.get(node))
        info.pop('hide', None)
        if quads_only and uri and info.get('blend', 'mix') == 'mix' and os.path.exists(os.path.join(OUT, uri))                 and _opaque_share(uri) < 0.5:
            info['hide'] = True
            hidden.append(node)
            continue
        if quads_only and verts.get(node, 4) > 8:
            continue
        if uri and os.path.exists(os.path.join(OUT, uri)) and _hard_edges(uri, info.get('blend', 'mix')):
            info['hide'] = True
            hidden.append(node)
    with open(js, 'w', encoding='utf-8') as f:
        json.dump(fx, f, separators=(',', ':'))
    return hidden


def convert(names, idx=None, quads_only=False):
    idx = idx or {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    os.makedirs(OUT, exist_ok=True)
    done = []
    for name in names:
        src = 'effect/model/%s.nif' % name.lower()
        if src not in idx:
            print('! effet absent', name)
            continue
        conv = nif2gltf.Converter(idx, os.path.join(OUT, 'textures'), 'textures/')
        conv.fx = {}
        try:
            conv.convert(src, [], os.path.join(OUT, name.lower() + '.glb'))
            fx = nif2gltf.fx_finalize(conv, conv.blocks)
        except Exception as ex:  # un effet cassé ne doit pas bloquer les autres
            print('! %s: %s' % (name, ex))
            continue
        with open(os.path.join(OUT, name.lower() + '.fx.json'), 'w', encoding='utf-8') as f:
            json.dump(fx, f, separators=(',', ':'))
        hidden = mark_hard_quads(name.lower(), quads_only)
        if hidden:
            print('  quads à bords durs masqués :', ', '.join(hidden))
        done.append(name.lower())
        print('%s : %.2f s, %d nœuds animés, %d matériaux' % (name, fx['duration'], len(fx['nodes']), len(fx['materials'])))
    return done


def _glb_parts(path):
    b = open(path, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    return b[20 + n:], json.loads(b[20:20 + n])


def share_variants(names):
    """Variantes de couleur d'un même effet (s83111 … s83115 : même maillage, autres
    textures) : une seule copie du .glb ; le .fx.json de chaque variante pointe vers
    ce maillage ("glb") et donne ses textures par matériau ("tex")."""
    groups = {}
    for n in sorted(names):
        groups.setdefault(n[:-1], []).append(n)
    saved = 0
    for _key, members in groups.items():
        live = [m for m in members if os.path.exists(os.path.join(OUT, m + '.glb'))]
        if len(live) < 2:
            continue
        base = live[0]
        bin0, _j0 = _glb_parts(os.path.join(OUT, base + '.glb'))
        tex0 = _node_textures(os.path.join(OUT, base + '.glb'))
        for v in live[1:]:
            glb = os.path.join(OUT, v + '.glb')
            binv, _jv = _glb_parts(glb)
            if binv != bin0:
                continue  # maillage différent : on garde les deux
            texv = _node_textures(glb)
            js = os.path.join(OUT, v + '.fx.json')
            fx = json.load(open(js, encoding='utf-8'))
            mats = fx.setdefault('materials', {})
            if any(node not in mats for node, uri in texv.items() if tex0.get(node) != uri):
                continue  # texture sur un nœud non animé : pas de remplacement possible
            for node, uri in texv.items():
                if tex0.get(node) != uri:
                    mats[node]['tex'] = uri
            fx['glb'] = base
            with open(js, 'w', encoding='utf-8') as f:
                json.dump(fx, f, separators=(',', ':'))
            saved += os.path.getsize(glb)
            os.remove(glb)
            if os.path.exists(glb + '.import'):
                os.remove(glb + '.import')
    print('variantes partagées : %.1f Mo économisés' % (saved / 1e6))


# Auras : pièces qui dessinent des boîtes ou des panneaux rectangulaires autour du héros
# (relevées à l'œil sur tests/test_aura.tscn). Textures de l'effet de base de la famille
# (5 premiers caractères) ; les pièces correspondantes sont masquées dans toutes les
# variantes de couleur. "*" : textures de halo carré masquées dans toutes les auras.
AURA_BAD = {'*': ['s0084104', 's0014104'],
            's8071': ['s8071101', 's8071103'], 's8191': ['s8191115'], 's8281': ['s8281154', 's8071204'],
            's8741': ['s8341101', 's12963107', 's8741151'], 's8521': ['s8521101']}
AURA_BAD_NODES = {'s8311': ['Plane01', 'Plane13']}  # cône plein


def hide_aura_parts(names):
    """Masque les pièces rectangulaires des auras (voir AURA_BAD) ; renvoie le nombre."""
    names = sorted(names)
    fams = {}
    for n in names:
        fams.setdefault(n[:5], []).append(n)
    total = 0
    for fam, members in fams.items():
        base = members[0]
        fx0 = json.load(open(os.path.join(OUT, base + '.fx.json'), encoding='utf-8'))
        tex0 = _node_textures(os.path.join(OUT, fx0.get('glb', base) + '.glb'))
        bad = set(AURA_BAD['*']) | set(AURA_BAD.get(fam, []))
        nodes = set(AURA_BAD_NODES.get(fam, []))
        for node, info in fx0.get('materials', {}).items():
            uri = info.get('tex', tex0.get(node, ''))
            if os.path.basename(uri)[:-4] in bad:
                nodes.add(node)
        for n in members:
            js = os.path.join(OUT, n + '.fx.json')
            fx = json.load(open(js, encoding='utf-8'))
            tex = _node_textures(os.path.join(OUT, fx.get('glb', n) + '.glb'))
            for node, info in fx.get('materials', {}).items():
                uri = info.get('tex', tex.get(node, ''))
                if (node in nodes or os.path.basename(uri)[:-4] in AURA_BAD['*']) and not info.get('hide'):
                    info['hide'] = True
                    total += 1
            with open(js, 'w', encoding='utf-8') as f:
                json.dump(fx, f, separators=(',', ':'))
    return total


if __name__ == '__main__':
    if sys.argv[1:2] == ['--mark-existing']:
        for f in sorted(os.listdir(OUT)):
            if f.endswith('.fx.json'):
                n = f[:-len('.fx.json')]
                print(n, mark_hard_quads(n))
    else:
        convert(sys.argv[1:])
