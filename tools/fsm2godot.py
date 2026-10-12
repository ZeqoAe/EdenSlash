"""Conversion d'une map Eden Eternal (.fsm + data/scene/*.ini) pour Godot.

    python -I tools/fsm2godot.py s002

Format .fsm (reconstitué) :
  'FSM V20100329' ... à 0x58 'LAY0HMd\\0'
  0x60  u32 largeur, u32 hauteur (225), f32 pas (2.0), u32 nb_blocs (60)
  blocs : en-tête (u32 33, u32 33, f32 2.0, u32 type 0=terrain 1=eau)
          33x33 sommets {x, y, z, nx, ny, nz, r, g, b, a} (f32, Z vers le haut)
          32 o inconnus, carte de mélange 128x128 RGBA8 (opacité des couches 2..5)
          nom de DarkMap (32 o), 5 couches {u8 actif, nom[71], f32 répétitions}
  sections étiquetées : 'GRL ' (modèles d'herbe), 'GRS ' (touffes d'herbe),
          'OBJ ' (objets : pos[3], rot[9], échelle, nom[40]), ...

Sorties : game/assets/maps/<id>/ (map.json, terrain.bin, blend/, dark/)
          game/assets/maps/textures/ (couches), game/assets/maps/objects/ (.glb)
"""
import io
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'game', 'assets', 'maps')
CHUNK_VERTS = 33
BLOCK = 16 + CHUNK_VERTS * CHUNK_VERTS * 40 + 32 + 128 * 128 * 4 + 32 + 5 * 76


def to_godot(p):
    """Gamebryo (x, y, z) Z-up -> Godot (x, z, -y) Y-up."""
    return [float(p[0]), float(p[2]), -float(p[1])]


C = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], dtype=np.float64)  # même changement de repère


def parse_fsm(d):
    width, height, step, nblocks = struct.unpack_from('<IIfI', d, 0x60)
    pos = 0x70
    chunks = []
    for i in range(nblocks):
        _, _, _, kind = struct.unpack_from('<IIfI', d, pos)
        v = np.frombuffer(d, dtype='<f4', count=CHUNK_VERTS * CHUNK_VERTS * 10, offset=pos + 16).reshape(-1, 10)
        b = pos + 16 + CHUNK_VERTS * CHUNK_VERTS * 40 + 32
        blend = np.frombuffer(d, dtype=np.uint8, count=128 * 128 * 4, offset=b).reshape(128, 128, 4)
        tail = d[b + 128 * 128 * 4:pos + BLOCK]
        dark = tail[:32].split(b'\0')[0].decode('latin1')
        layers = []
        for k in range(5):
            o = 32 + 76 * k
            name = tail[o + 1:o + 72].split(b'\0')[0].decode('latin1')
            rep = struct.unpack_from('<f', tail, o + 72)[0]
            layers.append({'texture': name, 'repeat': rep} if name else None)
        chunks.append({'index': i, 'kind': kind, 'verts': v.copy(), 'blend': blend.copy(),
                       'dark': dark, 'layers': layers})
        pos += BLOCK
    sections = {}
    while pos + 8 <= len(d):
        tag = d[pos:pos + 4].decode('latin1')
        size = struct.unpack_from('<I', d, pos + 4)[0]
        if size < 8:
            break
        sections[tag.strip()] = d[pos + 8:pos + size]
        pos += size
    return {'width': width, 'height': height, 'step': step, 'chunks': chunks, 'sections': sections}


def parse_objects(body):
    n = struct.unpack_from('<I', body, 0)[0]
    out = []
    for i in range(n):
        o = 4 + i * 92
        f = struct.unpack_from('<13f', body, o)
        name = body[o + 52:o + 92].split(b'\0')[0].decode('latin1')
        out.append({'model': name.lower(), 'pos': f[0:3], 'rot': f[3:12], 'scale': f[12]})
    return out


def parse_scene_ini(text):
    """data/scene/<id>.ini : fichier de map déclaré, points clés, camps de monstres."""
    declared = None
    events = []
    spawns = []
    section = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('['):
            section = line.strip('[],')
            continue
        if not line:
            continue
        f = line.rstrip(',').split(',')
        if section == 'globe_data' and declared is None:
            declared = f[0].strip().lower()
        elif section == 'event_area' and len(f) >= 9:
            events.append({'id': int(f[0]), 'pos': to_godot((float(f[1]), float(f[2]), float(f[3]))),
                           'size': [float(f[4]), float(f[5])], 'type': f[6], 'angle': float(f[7]),
                           'label': f[8].split('\t')[0]})
        elif section == 'reborn_monsters' and len(f) >= 7:
            # id, monstre, patrouille, nombre, ?, x, y, ...
            try:
                spawns.append({'monster': int(f[1]), 'count': int(f[3]),
                               'x': float(f[5]), 'z': -float(f[6]), 'label': f[14] if len(f) > 14 else ''})
            except ValueError:
                pass
    return declared, events, spawns


def convert_objects(objs, idx, conv):
    """Convertit les modèles de décor et renvoie les instances (repère Godot)."""
    models = sorted({o['model'] for o in objs})
    obj_dir = os.path.join(OUT, 'objects')
    os.makedirs(obj_dir, exist_ok=True)
    ok_models = set()
    for m in models:
        src = 'map/model/object/%s.nif' % m
        if src not in idx:
            cands = [p for p in idx if p.endswith('/%s.nif' % m) and p.startswith('map/')]
            src = cands[0] if cands else None
        if src is None:
            print('! modèle absent', m)
            continue
        dst = os.path.join(obj_dir, m + '.glb')
        if not os.path.exists(dst):
            try:
                conv.convert(src, [], dst)
            except Exception as ex:  # un modèle cassé ne doit pas bloquer la map
                print('! %s: %s' % (m, ex))
                continue
        ok_models.add(m)
    instances = []
    keys = ['m11', 'm21', 'm31', 'm12', 'm22', 'm32', 'm13', 'm23', 'm33']
    for o in objs:
        if o['model'] not in ok_models:
            continue
        R = nif2gltf.mat3(dict(zip(keys, o['rot'])))
        q = nif2gltf.quat_from_mat(C @ R @ C.T)
        instances.append({'model': o['model'], 'pos': to_godot(o['pos']),
                          'rot': [round(float(x), 6) for x in q], 'scale': round(float(o['scale']), 4)})
    return instances


def convert_terrain(map_id, fsm, idx, read, out):
    for sub in ('blend', 'dark'):
        os.makedirs(os.path.join(out, sub), exist_ok=True)
    tex_out = os.path.join(OUT, 'textures')
    os.makedirs(tex_out, exist_ok=True)
    verts = []
    meta = []
    used_tex = set()
    for c in fsm['chunks']:
        v = c['verts']
        g = np.empty((v.shape[0], 10), dtype=np.float32)
        g[:, 0], g[:, 1], g[:, 2] = v[:, 0], v[:, 2], -v[:, 1]  # position
        g[:, 3], g[:, 4], g[:, 5] = v[:, 3], v[:, 5], -v[:, 4]  # normale
        g[:, 6:10] = v[:, 6:10]                                 # couleur (alpha = trou)
        verts.append(g)
        entry = {'index': c['index'], 'kind': 'water' if c['kind'] == 1 else 'terrain',
                 'origin': [float(v[0, 0]), float(-v[0, 1])]}
        if c['kind'] == 0:
            Image.fromarray(c['blend'], 'RGBA').save(os.path.join(out, 'blend', '%d.png' % c['index']))
            dpath = 'map/model/%s/dark/%s.dds' % (map_id, c['dark'].lower())
            if dpath in idx:
                Image.open(io.BytesIO(read(dpath))).convert('L').save(os.path.join(out, 'dark', '%d.png' % c['index']))
                entry['dark'] = True
            entry['layers'] = []
            for layer in c['layers']:
                if layer is None:
                    entry['layers'].append(None)
                    continue
                stem = os.path.splitext(layer['texture'].lower())[0]
                used_tex.add(stem)
                entry['layers'].append({'texture': stem, 'repeat': layer['repeat']})
        meta.append(entry)
    np.concatenate(verts).astype('<f4').tofile(os.path.join(out, 'terrain.bin'))
    for stem in sorted(used_tex):
        p = 'map/texture/%s.dds' % stem
        dst = os.path.join(tex_out, stem + '.png')
        if p in idx and not os.path.exists(dst):
            Image.open(io.BytesIO(read(p))).convert('RGBA').save(dst)
    return meta


def main():
    map_id = sys.argv[1].lower() if len(sys.argv) > 1 else 's002'
    idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
    read = lambda p: edenpkg.read_file(nif2gltf.PKG, idx[p])  # noqa: E731
    scene_ini = 'data/scene/%s.ini' % map_id
    if scene_ini not in idx:
        sys.exit('pas de data/scene pour %s' % map_id)
    declared, events, spawns = parse_scene_ini(read(scene_ini).decode('big5', 'replace'))
    src = 'map/model/%s/%s' % (map_id, declared)
    if src not in idx:
        sys.exit('%s : fichier déclaré %s absent du client' % (map_id, declared))
    data = read(src)
    is_fsm = declared.endswith('.fsm')
    # entrée d'index périmée : le contenu ne correspond pas au format déclaré
    if (is_fsm and not data.startswith(b'FSM')) or (not is_fsm and not data.startswith(b'Gamebryo')):
        sys.exit('%s : %s introuvable dans le client (entrée d\'index périmée)' % (map_id, declared))
    out = os.path.join(OUT, map_id)
    os.makedirs(out, exist_ok=True)
    conv = nif2gltf.Converter(idx, os.path.join(OUT, 'objects', 'textures'), 'textures/')
    conv.collision = True
    info = {'id': map_id, 'events': events, 'spawns': spawns}
    if is_fsm:
        fsm = parse_fsm(data)
        info['chunks'] = convert_terrain(map_id, fsm, idx, read, out)
        info['objects'] = convert_objects(parse_objects(fsm['sections']['OBJ']), idx, conv)
        desc = '%d blocs, %d objets' % (len(info['chunks']), len(info['objects']))
    else:
        # donjon : une grande scène NIF (salles, murs, collisions)
        scene_conv = nif2gltf.Converter(idx, os.path.join(out, 'textures'), 'textures/')
        scene_conv.collision = True
        scene_conv.convert(src, [], os.path.join(out, 'scene.glb'))
        info['scene'] = 'scene.glb'
        conv.warnings += scene_conv.warnings
        desc = 'scène NIF'
    with open(os.path.join(out, 'map.json'), 'w', encoding='utf-8') as f:
        json.dump(info, f, ensure_ascii=False)
    for w in conv.warnings[:20]:
        print('  ! ' + w)
    print('%s : %s, %d points clés, %d camps de monstres' % (map_id, desc, len(events), len(spawns)))


if __name__ == '__main__':
    main()
