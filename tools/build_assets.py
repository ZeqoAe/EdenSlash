"""Construit les assets et données du jeu à partir du client Eden Eternal.

    python -I tools/build_assets.py [--skip-models]

Sorties (dans game/) :
  assets/monsters/<modèle>/<modèle>.glb (+ .anims.json)
  assets/monsters/textures/*.png
  data/monsters.json   stats réelles des monstres utilisés
  data/zones.json      zones jouables, roster de monstres, donjons
  data/levels.json     courbe d'XP
"""
import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
GAME = os.path.join(ROOT, 'game')
PY = sys.executable

# Animations utiles en hack and slash (le reste alourdit les fichiers)
MONSTER_ANIMS = r'stand0[1-2]|battle01|move0[1-2]|attack0[1-4]|magic0[1-2]|shoot0[1-2]|hurt0[1-2]|death01'

# Zones jouables. Les monstres sont lus dans les camps ([reborn_monsters]) des maps
# converties par fsm2godot.py ; seules les cartes présentes dans le client sont listées
# (Angor Quarry et Tranquil Hill ont été retirés du client Eden Reforged).
ZONES = [
    {'id': 'limestone', 'node': 2, 'name': 'Limestone Mtn.', 'levels': [1, 8],
     'map': 's002', 'start_event': 'BORN',
     'dungeon': {'id': 'andrew_mine', 'name': 'Andrew V. Mine', 'required_level': 8, 'level': 9,
                 'map': 's100', 'gateway_label': '往安德魯村內礦坑'}},
]


def map_spawn_ids(map_id):
    path = os.path.join(GAME, 'assets', 'maps', map_id, 'map.json')
    if not os.path.exists(path):
        sys.exit("lancer d'abord : python -I tools/fsm2godot.py %s" % map_id)
    info = json.load(open(path, encoding='utf-8'))
    return sorted({sp['monster'] for sp in info.get('spawns', [])})


def usable(r, tmon, mid):
    """Vrai monstre combattable : normal (2) ou élite (3), avec XP et un nom."""
    name = tmon.get(mid, ['?'])[0].strip()
    return num(r[3]) in (2, 3) and num(r[14]) > 10 and num(r[8]) > 1 and 0 < num(r[4]) <= 40 and name not in ('', '?')


def num(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        try:
            return float(v)
        except (TypeError, ValueError):
            return default


def monsterlist():
    out = {}
    path = os.path.join(edenini.DB, 'monsterlist.ini')
    for line in open(path, encoding='cp1252', errors='replace'):
        if line.startswith('DB') and '=' in line:
            f = line.strip().split('=', 1)[1].split(',')
            out[f[0].lower()] = {'kfm': f[1].lower(), 'scale': num(f[2], 1.0), 'texture': f[8].lower()}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-models', action='store_true')
    a = ap.parse_args()

    cmon = {int(r[0]): r for r in edenini.read_table('c_monster') if r[0].isdigit()}
    tmon = edenini.read_text('t_monster')
    mlist = monsterlist()
    monsters = {}
    kfms = set()
    def add(mid):
        r = cmon.get(mid)
        if r is None or not usable(r, tmon, mid):
            return False
        ml = mlist.get(r[1].lower())
        if ml is None:
            print('! modèle inconnu', mid, r[1])
            return False
        base = os.path.splitext(ml['kfm'])[0]
        kfms.add(base)
        monsters[mid] = {
            'id': mid,
            'name': ' '.join(tmon.get(mid, ['?'])[0].split()),
            'level': num(r[4]), 'hp': num(r[8]), 'xp': num(r[14]),
            'atk': num(r[18]), 'def': num(r[20]), 'mdef': num(r[22]),
            'rank': num(r[3]),
            'model': base,
            'texture': os.path.splitext(ml['texture'])[0],
            'scale': ml['scale'],
        }
        return True

    for z in ZONES:
        ids = [m for m in map_spawn_ids(z['map']) if add(m)]
        z['monsters'] = sorted((m for m in ids if monsters[m]['rank'] == 2), key=lambda m: monsters[m]['level'])
        z['elites'] = [m for m in ids if monsters[m]['rank'] == 3]
        dj = z['dungeon']
        dids = [m for m in map_spawn_ids(dj['map']) if add(m)]
        dj['monsters'] = [m for m in dids if monsters[m]['rank'] == 2]
        bosses = [m for m in dids if monsters[m]['rank'] == 3]
        dj['boss'] = bosses[0] if bosses else z['elites'][-1]
    os.makedirs(os.path.join(GAME, 'data'), exist_ok=True)

    if not a.skip_models:
        tex_dir = os.path.join(GAME, 'assets', 'monsters', 'textures')
        for base in sorted(kfms):
            out = os.path.join(GAME, 'assets', 'monsters', base)
            subprocess.run([PY, '-I', os.path.join(os.path.dirname(__file__), 'nif2gltf.py'),
                            'monster/%s.kfm' % base, out, '--tex-dir', tex_dir,
                            '--anims', MONSTER_ANIMS], check=True)
        # textures des variantes (recolorations d'un même modèle)
        sys.path.insert(0, os.path.dirname(__file__))
        import edenpkg
        import nif2gltf
        idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
        conv = nif2gltf.Converter(idx, tex_dir, '../textures/')
        for m in monsters.values():
            p = conv.find_texture(m['texture'] + '.dds', 'monster/')
            if p:
                conv.export_texture(p)
            else:
                print('! texture introuvable', m['texture'])

    # PNJ du village et coffres (modèles d'Eden partagés avec les monstres)
    npcs = {
        'merchant': {'model': 'm012', 'texture': 'm01201', 'scale': 1.1, 'name': 'Alec, marchand zumi'},
        'smith': {'model': 'm052', 'texture': 'm05203', 'scale': 1.0, 'name': 'Bryson, forgeron ursun'},
        'trader': {'model': 'm109', 'texture': 'm10901', 'scale': 1.05, 'name': 'Abel, négociant'},
        'chest': {'model': 'm604', 'texture': 'm60401', 'scale': 1.0, 'name': 'Coffre secret'},
    }
    if not a.skip_models:
        tex_dir = os.path.join(GAME, 'assets', 'monsters', 'textures')
        for n in npcs.values():
            out = os.path.join(GAME, 'assets', 'monsters', n['model'])
            if not os.path.exists(os.path.join(out, n['model'] + '.glb')):
                subprocess.run([PY, '-I', os.path.join(os.path.dirname(__file__), 'nif2gltf.py'),
                                'monster/%s.kfm' % n['model'], out, '--tex-dir', tex_dir,
                                '--anims', MONSTER_ANIMS + r'|trigger0[1-3]|condition0[1-3]'], check=True)
            import edenpkg
            import nif2gltf
            idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
            conv = nif2gltf.Converter(idx, tex_dir, '../textures/')
            p = conv.find_texture(n['texture'] + '.dds', 'monster/')
            if p:
                conv.export_texture(p)
    with open(os.path.join(GAME, 'data', 'npcs.json'), 'w', encoding='utf-8') as f:
        json.dump(npcs, f, indent=1, ensure_ascii=False)

    lv = edenini.read_table('c_level')
    levels = [{'level': num(r[0]), 'xp': num(r[1]), 'hp': num(r[2]), 'mp': num(r[3])} for r in lv if r[0].isdigit()]

    with open(os.path.join(GAME, 'data', 'monsters.json'), 'w', encoding='utf-8') as f:
        json.dump({str(k): v for k, v in sorted(monsters.items())}, f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'zones.json'), 'w', encoding='utf-8') as f:
        json.dump(ZONES, f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'levels.json'), 'w', encoding='utf-8') as f:
        json.dump(levels, f, indent=1)
    print('%d monstres, %d modèles, %d niveaux' % (len(monsters), len(kfms), len(levels)))


if __name__ == '__main__':
    main()
