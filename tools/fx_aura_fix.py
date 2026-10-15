"""Réparation des auras converties (pierres étoilées, pierres de lune) : P16.

    python tools/fx_aura_fix.py            # toutes les auras du catalogue (relançable : même résultat)
    python tools/fx_aura_fix.py --check    # rapport seulement, rien n'est écrit

(numpy est nécessaire : pas de « python -I », qui ignore les paquets de l'utilisateur.)

Défauts relevés sur les auras (note du joueur du 15/10, « Roche de Luna de la Lumière des étoiles
ardente »), lus dans le .nif d'origine de chaque effet :

1. Variantes de couleur qui partagent le maillage d'une autre (fx2godot.share_variants) : les noms de
   nœuds du .glb partagé ne sont pas toujours ceux de la variante (« Editable_Poly_416 » contre
   « Editable_Poly_415 » : un bloc de plus dans le .nif décale les suffixes). Le maillage sans entrée
   dans le .fx.json gardait le matériau brut du glTF : mur étoilé opaque derrière le héros, plaque
   blanche au sol. Les clés de la variante sont renommées d'après le parcours des deux .nif.
2. Enroulement des textures : Gamebryo bloque (clamp) la plupart des textures d'effet ; le shader les
   répétait (planche de 3 × 3 halos, « plaque carrée qui tourne »). "wrap" : 0 bloquée, 1 U bloqué,
   2 V bloqué. Transformation fixe de la texture ("uv0" : u, v, échelle u, échelle v, rotation).
3. Nœuds « panneau » (NiBillboardNode) : la lune et le soleil font face à la caméra ; ils étaient
   figés (plaque plate qui tourne avec son orbite). "billboards" : {nœud: mode}.
4. Masques (« dark map ») et textures de détail : la moitié des matériaux d'aura multiplient leur
   texture par un masque (dégradé, halo) qui efface les bords des panneaux ; ils étaient ignorés, et
   pire, l'animation de défilement du masque était appliquée à la texture de base (pistes UV de
   toutes les « cases » de texture confondues). Pistes UV refaites par case ; "dark" / "detail" :
   {tex, wrap, uv0, uv_u…}.

Enfin les pièces rectangulaires de chaque famille (fx2godot.AURA_BAD) sont masquées dans toutes les
variantes (les clés renommées les retrouvent).
"""
import difflib
import json
import os
import re
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import edenpkg  # noqa: E402
import nif  # noqa: E402
import nif2gltf  # noqa: E402
import fx2godot  # noqa: E402

OUT = fx2godot.OUT
CATALOG = os.path.join(os.path.dirname(__file__), '..', 'game', 'data', 'eden_catalog.json')
SKIP = ('NiCamera', 'NiAmbientLight', 'NiDirectionalLight', 'NiPointLight', 'NiParticleSystem')
UV_OPS = ['uv_u', 'uv_v', 'uv_rot', 'uv_su', 'uv_sv']  # NiTextureTransformController.Operation
SHOW_AGAIN = {'s8521': ['S85211_6']}  # poissons et oiseaux : « boîtes » dues aux rotations non définies
SLOTS = {0: ('Base Texture', None), 1: ('Dark Texture', 'dark'), 2: ('Detail Texture', 'detail')}


def aura_names():
    cat = json.load(open(CATALOG, encoding='utf-8'))
    return sorted({c['aura']['fx'].lower() for c in cat.get('collection', []) if 'aura' in c})


def walk(conv, name):
    """Nœuds de l'effet [name] dans l'ordre de nif2gltf (mêmes noms que le .glb) :
    [{name, type, mode (panneau), prop (NiTexturingProperty), blocks}]."""
    nf = nif.NifFile.parse(conv.read('effect/model/%s.nif' % name))
    blocks = nf.blocks
    spec = nif.Spec.get()
    seen = set()
    out = []

    def as_list(v):
        if v is None:
            return []
        if isinstance(v, int):
            return [v]
        return [int(x) for x in v]

    def visit(bi, props):
        b = blocks[bi]
        if b.error or not spec.inherits(b.type, 'NiAVObject'):
            return
        if b.type.startswith('NiPSys') or b.type in SKIP:
            return
        raw = b['Name'] or ('%s_%d' % (b.type, bi))
        n = re.sub(r'[^A-Za-z0-9_]', '_', raw) or 'node'
        if n in seen:
            n = '%s_%d' % (n, bi)
        seen.add(n)
        props = props + [blocks[p] for p in as_list(b.get('Properties')) if p >= 0]
        prop = None
        for p in props:
            if p.type == 'NiTexturingProperty' and p.get('Has Base Texture'):
                prop = p
        out.append({'name': n, 'type': b.type, 'mode': b.get('Billboard Mode') if b.type == 'NiBillboardNode' else None,
                    'prop': prop, 'blocks': blocks})
        for c in as_list(b.get('Children')):
            if c >= 0:
                visit(c, props)

    for r in nf.roots:
        if r >= 0:
            visit(r, [])
    return out


def _key(x):
    """Nom sans suffixe d'index de bloc (« Editable_Poly_415 » -> « Editable_Poly ») et type."""
    return (re.sub(r'_\d+$', '', x['name']), x['type'])


def _pair(wv, wb):
    """Nœuds de la variante [wv] associés à ceux de la base [wb] : même ordre si les deux parcours
    ont la même suite de types, sinon alignement sur (nom sans suffixe, type)."""
    if len(wv) == len(wb) and all(a['type'] == b['type'] for a, b in zip(wv, wb)):
        return list(zip(wv, wb))
    sm = difflib.SequenceMatcher(None, [_key(a) for a in wv], [_key(b) for b in wb], autojunk=False)
    out = []
    for blk in sm.get_matching_blocks():
        out += [(wv[blk.a + i], wb[blk.b + i]) for i in range(blk.size)]
    return out


def _uv0(tex):
    """Transformation fixe d'une texture (None si identité)."""
    if not tex or not tex.get('Has Texture Transform'):
        return None
    t, s, r = tex.get('Translation', {}), tex.get('Scale', {}), float(tex.get('Rotation', 0.0))
    v = [round(float(t.get('u', 0)), 4), round(float(t.get('v', 0)), 4), round(float(s.get('u', 1)), 4),
         round(float(s.get('v', 1)), 4), round(r, 4)]
    return None if v == [0, 0, 1, 1, 0] else v


DMAX = 32.0  # durée de boucle la plus longue gardée (s) : les auras d'Eden tournent sur 6 à 31 s
FPS = 15.0  # images par seconde des pistes d'aura (lues avec interpolation : 15 suffisent, le JSON garde sa taille)


def _period(cb):
    """Durée d'un cycle du contrôleur (s, temps de l'effet) ; None : bloqué à la fin (pas de boucle)."""
    freq = float(cb.get('Frequency', 1.0)) or 1.0
    span = max(float(cb.get('Stop Time', 0.0)) - float(cb.get('Start Time', 0.0)), 1e-6) / freq
    cycle = (int(cb.get('Flags', 0)) >> 1) & 3
    return span if cycle == 0 else (2 * span if cycle == 1 else None)


def resample(idx, n):
    """Toutes les pistes de l'effet [n] rééchantillonnées sur leur propre cycle (au lieu de 6 s pour
    tout l'effet : la lune revenait en arrière toutes les 6 s, les pièces tardives n'apparaissaient
    jamais). Piste en boucle : un cycle (lu modulo sa longueur) ; piste bloquée : la durée de l'effet.
    Renvoie (nœuds, matériaux {nom: {alpha_t, color_t, flip, uv_*, _dark: {uv_*}, _detail: {uv_*}}}, durée)."""
    conv = nif2gltf.Converter(idx, os.path.join(OUT, 'textures'), 'textures/')
    conv.fx = {}
    conv.convert('effect/model/%s.nif' % n, [], os.path.join(tempfile.gettempdir(), 'p16_fx_%s.glb' % n))
    blocks = conv.blocks
    ctrls = conv.fx.pop('_ctrls', [])
    fps = FPS
    ps = [_period(cb) for _, _, cb, _ in ctrls]
    dur = max([p for p in ps if p] + [nif2gltf._ctrl_duration(cb) for (_, _, cb, _), p in zip(ctrls, ps) if p is None] + [0.2])
    dur = min(dur, DMAX)

    def times_for(cb):
        p = _period(cb)
        if p is not None and p <= DMAX:
            return np.arange(max(1, int(round(p * fps)))) / fps
        return np.arange(0.0, dur + 1e-6, 1.0 / fps)

    nodes, mats = {}, {}
    for name, kind, cb, _prop in ctrls:
        ii = cb.get('Interpolator', -1)
        ip = blocks[ii] if ii is not None and ii >= 0 else None
        lt = nif2gltf._ctrl_times(cb, times_for(cb))
        if kind == 'node':
            if cb.type in ('NiTransformController', 'NiKeyframeController') and ip is not None and not ip.error:
                res = conv.sample_interp(ip, blocks, lt)
                if res:
                    tr, rot, sc = res
                    nd = nodes.setdefault(name, {})
                    if tr is not None:
                        nd['t'] = nif2gltf._r(tr)
                    if rot is not None:
                        nd['r'] = nif2gltf._r(nif2gltf.fix_quat_signs(rot))
                    if sc is not None:
                        nd['s'] = nif2gltf._r(sc)
            elif cb.type == 'NiVisController':
                v = nif2gltf._sample_scalar(ip, blocks, lt)
                if v is not None:
                    nodes.setdefault(name, {})['vis'] = nif2gltf._r(v, 0)
            continue
        m = mats.setdefault(name, {})
        if cb.type == 'NiAlphaController':
            v = nif2gltf._sample_scalar(ip, blocks, lt)
            if v is not None:
                m['alpha_t'] = nif2gltf._r(v, 3)
        elif cb.type == 'NiMaterialColorController':
            v = nif2gltf._sample_vec3(ip, blocks, lt)
            if v is not None and int(cb.get('Target Color', 1)) in (1, 3):
                m['color_t'] = nif2gltf._r(v, 3)
        elif cb.type == 'NiTextureTransformController':
            v = nif2gltf._sample_scalar(ip, blocks, lt)
            if v is not None:
                slot = int(cb.get('Texture Slot', 0))
                dst = m if slot == 0 else m.setdefault({1: '_dark', 2: '_detail'}.get(slot, '_other'), {})
                dst[UV_OPS[min(int(cb.get('Operation', 0)), 4)]] = nif2gltf._r(v, 4)
        elif cb.type == 'NiFlipController':
            v = nif2gltf._sample_scalar(ip, blocks, lt)
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
    return _const(nodes), _const(mats), round(dur, 3)


def _const(o):
    """Piste constante -> une seule valeur (lue modulo 1) : la moitié des pistes ne bougent pas."""
    if isinstance(o, dict):
        return {k: _const(v) for k, v in o.items()}
    if isinstance(o, list) and len(o) > 1 and not isinstance(o[0], str) and all(x == o[0] for x in o):
        return [o[0]]
    return o


def _texture_uri(conv, blocks, desc):
    src = desc.get('Source', -1)
    st = blocks[src] if src is not None and src >= 0 else None
    if st is None:
        return None
    fname = st.get('File Name')
    if isinstance(fname, dict):
        fname = fname.get('Index') or fname.get('String') or ''
    path = conv.find_texture(fname or '', 'effect/')
    return conv.export_texture(path) if path else None


def fix(names, write=True):
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    conv = nif2gltf.Converter(idx, os.path.join(OUT, 'textures'), 'textures/')
    if not write:
        conv.export_texture = lambda p: 'textures/' + os.path.splitext(os.path.basename(p))[0] + '.png'
    walks = {}
    stats = {'renamed': 0, 'variants': 0, 'billboards': 0, 'clamped': 0, 'uv0': 0, 'copied': 0, 'unmatched': [],
             'dark': 0, 'detail': 0, 'new_textures': 0}
    tex_before = set(os.listdir(os.path.join(OUT, 'textures')))
    for n in names:
        js = os.path.join(OUT, n + '.fx.json')
        if not os.path.exists(js):
            continue
        fx = json.load(open(js, encoding='utf-8'))
        base = fx.get('glb', n)
        try:
            for k in {n, base}:
                if k not in walks:
                    walks[k] = walk(conv, k)
        except Exception as ex:  # noqa: BLE001
            print('! %s : %s' % (n, ex))
            continue
        wv, wb = walks[n], walks[base]
        mats = fx.setdefault('materials', {})
        rename = {}
        pairs = list(zip(wv, wb)) if n == base else _pair(wv, wb)
        # "glb_names" : clés déjà aux noms du .glb partagé (outil relancé : ne jamais renommer deux fois,
        # un nom de la variante peut être celui d'un autre nœud de la base)
        if base != n and not fx.get('glb_names'):
            fx['glb_names'] = True
            if len(pairs) < len(wb):
                stats['unmatched'].append('%s (%d / %d)' % (n, len(pairs), len(wb)))
            rename = {a['name']: b['name'] for a, b in pairs if a['name'] != b['name']}
        if rename:
            stats['variants'] += 1
            stats['renamed'] += sum(1 for k in mats if k in rename)
            fx['materials'] = mats = {rename.get(k, k): v for k, v in mats.items()}
            fx['nodes'] = {rename.get(k, k): v for k, v in fx.get('nodes', {}).items()}
            # maillage du .glb partagé sans entrée chez la variante : celle de l'effet de base
            fxb = json.load(open(os.path.join(OUT, base + '.fx.json'), encoding='utf-8'))
            for k, v in fxb.get('materials', {}).items():
                if k not in mats:
                    mats[k] = dict(v)
                    stats['copied'] += 1
        # pièces masquées autrefois à tort (fx2godot.AURA_BAD), revues sur la planche tools/look_audit.tscn
        for k in SHOW_AGAIN.get(n[:5], []):
            if k in mats and mats[k].pop('hide', None):
                stats['shown_again'] = stats.get('shown_again', 0) + 1
        # variante : mêmes pièces masquées que l'effet de base (même maillage, revu à l'œil) ; la conversion
        # à part de la variante masquait parfois un modèle plein (fée de s82012) pris pour un quad à bords durs
        if base != n:
            fxb = json.load(open(os.path.join(OUT, base + '.fx.json'), encoding='utf-8')).get('materials', {})
            for k, info in mats.items():
                if k in fxb:
                    if fxb[k].get('hide'):
                        info['hide'] = True
                    elif info.pop('hide', None):
                        stats['unhidden'] = stats.get('unhidden', 0) + 1
        # pistes animées refaites sur leur propre cycle, par case de texture (noms de la variante -> noms du .glb)
        to_glb = {a['name']: b['name'] for a, b in pairs}
        r_nodes, r_mats, dur = resample(idx, n)
        fx['nodes'] = {to_glb.get(k, k): v for k, v in r_nodes.items()}
        fx['duration'] = dur
        fx['loop_tracks'] = True  # chaque piste se lit modulo sa longueur, interpolée (scripts/combat/eden_fx.gd)
        fx['fps'] = FPS
        r_mats = {to_glb.get(k, k): v for k, v in r_mats.items()}
        stats['tracks_s'] = stats.get('tracks_s', 0) + dur
        # textures de chaque matériau (noms du .glb = ceux de la base ; données lues dans le .nif de la variante)
        by_name = {b['name']: a for a, b in pairs}
        for k, info in mats.items():
            src = by_name.get(k)
            prop = src.get('prop') if src else None
            for key in ['wrap', 'uv0', 'dark', 'detail', 'alpha_t', 'color_t', 'flip'] + UV_OPS:
                info.pop(key, None)
            tr = r_mats.get(k, {})
            for key in ['alpha_t', 'color_t', 'flip'] + UV_OPS:  # case 0 : texture de base
                if key in tr:
                    info[key] = tr[key]
            if prop is None:
                continue
            for slot, (field, key) in SLOTS.items():
                if slot and not prop.get('Has ' + field):
                    continue
                desc = prop[field]
                d = info if slot == 0 else {}
                clamp = (int(desc.get('Flags', 0x3000)) >> 12) & 3
                if clamp != 3:
                    d['wrap'] = clamp
                    stats['clamped'] += 1
                u0 = _uv0(desc)
                if u0:
                    d['uv0'] = u0
                    stats['uv0'] += 1
                if slot:
                    uri = _texture_uri(conv, src['blocks'], desc)
                    if not uri:
                        continue
                    d['tex'] = uri
                    d.update(tr.get('_' + key, {}))
                    info[key] = d
                    stats[key] += 1
        bb = {b['name']: int(b['mode']) for b in wb if b['mode'] is not None}
        if bb:
            fx['billboards'] = bb
            stats['billboards'] += 1
        else:
            fx.pop('billboards', None)
        if write:
            fx2godot._dump_retry(js, fx)
    stats['new_textures'] = len(set(os.listdir(os.path.join(OUT, 'textures'))) - tex_before)
    if write:
        stats['hidden'] = fx2godot.hide_aura_parts([n for n in names if os.path.exists(os.path.join(OUT, n + '.fx.json'))])
    return stats


if __name__ == '__main__':
    st = fix(aura_names(), write='--check' not in sys.argv)
    print(json.dumps(st, ensure_ascii=False, indent=1))
