"""Aperçu d'une map d'Eden pour en faire un biome : textures du sol, décors, monstres.

    python -I tools/scan_biome.py s004 s006 ...
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_assets  # noqa: E402
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import fsm2godot  # noqa: E402
import nif2gltf  # noqa: E402


def scan(map_id, idx, read, cmon, tmon):
    ini = 'data/scene/%s.ini' % map_id
    declared, events, spawns = fsm2godot.parse_scene_ini(read(ini).decode('big5', 'replace'))
    src = 'map/model/%s/%s' % (map_id, declared)
    out = {'id': map_id, 'declared': declared, 'ok': False}
    if src not in idx:
        return out
    data = read(src)
    if not data.startswith(b'FSM'):
        return out
    fsm = fsm2godot.parse_fsm(data)
    tex = collections.Counter()
    for c in fsm['chunks']:
        if c['kind'] != 0:
            continue
        blend = c['blend'].reshape(-1, 4).mean(axis=0) / 255.0
        for k, layer in enumerate(c['layers']):
            if layer is None:
                continue
            # couche 0 = fond, couches 1..4 pondérées par leur masque moyen
            w = 1.0 if k == 0 else float(blend[k - 1])
            tex[os.path.splitext(layer['texture'].lower())[0]] += w
    objs = fsm2godot.parse_objects(fsm['sections'].get('OBJ', b'\0\0\0\0'))
    models = collections.Counter(o['model'] for o in objs)
    mons = collections.Counter()
    for sp in spawns:
        mons[sp['monster']] += sp['count']
    out.update({'ok': True, 'textures': tex.most_common(12), 'objects': models.most_common(40),
                'monsters': [(m, ' '.join(tmon.get(m, ['?'])[0].split()), build_assets.num(cmon[m][4]), build_assets.num(cmon[m][3]), n)
                             for m, n in mons.most_common() if m in cmon]})
    return out


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
    read = lambda p: edenpkg.read_file(nif2gltf.PKG, idx[p])  # noqa: E731
    cmon = {int(r[0]): r for r in edenini.read_table('c_monster') if r[0].isdigit()}
    tmon = edenini.read_text('t_monster')
    for m in sys.argv[1:]:
        r = scan(m, idx, read, cmon, tmon)
        print('==', m, r['declared'], 'OK' if r['ok'] else 'ILLISIBLE')
        if r['ok']:
            print('  textures', r['textures'])
            print('  objets', r['objects'][:30])
            print('  monstres', r['monsters'][:25])


if __name__ == '__main__':
    main()
