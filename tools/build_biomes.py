"""Biomes des runs : une map d'Eden Eternal par biome sert de source (textures du sol,
décors les plus fréquents, monstres des camps, boss), le terrain reste généré.

    python -I tools/build_biomes.py [--skip-models]

Sorties (game/) :
  data/biomes.json      textures, teinte, ambiance, catalogue de décors par biome
  data/zones.json       zones jouables (Limestone + biomes), monstres, élites, boss
  data/monsters.json    complété avec les monstres des biomes
  assets/maps/objects/  décors convertis ; assets/maps/textures/ textures du sol
  assets/monsters/      modèles des nouveaux monstres
"""
import argparse
import collections
import io
import json
import os
import statistics
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_assets  # noqa: E402
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import fsm2godot  # noqa: E402
import nif2gltf  # noqa: E402
from glb_bounds import bounds  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), '..', 'game')
PY = sys.executable

# Ordre de progression : chaque boss vaincu débloque la zone suivante.
# level_bonus : niveaux ajoutés aux monstres (et au butin) par rapport à Limestone.
BIOMES = [
    {'id': 'rainbowfall', 'map': 's004', 'name': 'Rainbowfall Forest', 'levels': [14, 19], 'level_bonus': 3,
     'textures': {'grass': 'grass_04', 'grass2': 'grass_03', 'dirt': 'dust_03', 'road': 'road_03', 'rock': 'mount_03'},
     'tint': [0.82, 0.9, 0.8],
     'env': {'sky_top': [0.3, 0.55, 0.75], 'horizon': [0.75, 0.9, 0.85], 'fog': [0.72, 0.85, 0.78], 'fog_density': 0.0026,
             'ambient': [0.72, 0.82, 0.74], 'sun': [1.0, 0.97, 0.85]},
     'dungeon': 'Antre de la sorcière'},
    {'id': 'beluga', 'map': 's006', 'name': 'Beluga Bay', 'levels': [24, 29], 'level_bonus': 6,
     'textures': {'grass': 'grass_03', 'grass2': 'sand_01', 'dirt': 'sand_01', 'road': 'road_05', 'rock': 'mount_03'},
     'tint': [0.9, 0.95, 1.0],
     'env': {'sky_top': [0.32, 0.55, 0.85], 'horizon': [0.85, 0.92, 1.0], 'fog': [0.82, 0.9, 0.98], 'fog_density': 0.0022,
             'ambient': [0.8, 0.86, 0.95], 'sun': [0.98, 0.98, 1.0]},
     'dungeon': 'Repaire des Vileshark'},
    {'id': 'wetlands', 'map': 's007', 'name': 'Wetlands', 'levels': [29, 33], 'level_bonus': 9,
     'textures': {'grass': 'grass_13', 'grass2': 'grass_04', 'dirt': 'dust_06', 'road': 'road_06', 'rock': 'mount_06'},
     'tint': [0.66, 0.72, 0.6],
     'env': {'sky_top': [0.35, 0.45, 0.45], 'horizon': [0.65, 0.72, 0.62], 'fog': [0.55, 0.65, 0.52], 'fog_density': 0.0045,
             'ambient': [0.65, 0.72, 0.6], 'sun': [0.9, 0.95, 0.8]},
     'dungeon': 'Marais maudit'},
    {'id': 'avila', 'map': 's009', 'name': 'Avila Volcano', 'levels': [37, 41], 'level_bonus': 12,
     'textures': {'grass': 'mount_07', 'grass2': 'dust_05', 'dirt': 'dust_04', 'road': 'grass_08', 'rock': 'mount_03'},
     'tint': [0.72, 0.68, 0.68],
     'env': {'sky_top': [0.22, 0.18, 0.2], 'horizon': [0.65, 0.42, 0.34], 'fog': [0.42, 0.33, 0.31], 'fog_density': 0.003,
             'ambient': [0.72, 0.66, 0.64], 'sun': [1.0, 0.86, 0.72]},
     'dungeon': 'Cœur du volcan'},
    {'id': 'arid', 'map': 's011', 'name': 'Arid Wilds', 'levels': [45, 48], 'level_bonus': 15,
     'textures': {'grass': 'sand_02', 'grass2': 'dust_04', 'dirt': 'dust_08', 'road': 'road_04', 'rock': 'mount_02'},
     'tint': [1.0, 0.92, 0.8],
     'env': {'sky_top': [0.35, 0.55, 0.85], 'horizon': [1.0, 0.88, 0.7], 'fog': [0.95, 0.85, 0.68], 'fog_density': 0.0022,
             'ambient': [0.92, 0.85, 0.72], 'sun': [1.0, 0.92, 0.75]},
     'dungeon': 'Fosse du fourmilion'},
    {'id': 'delphi', 'map': 's012', 'name': 'Delphi Forest', 'levels': [49, 51], 'level_bonus': 18,
     'textures': {'grass': 'grass_03', 'grass2': 'grass_06', 'dirt': 'dust_05', 'road': 'road_05', 'rock': 'mount_07'},
     'tint': [0.85, 0.82, 0.74],
     'env': {'sky_top': [0.42, 0.45, 0.62], 'horizon': [0.95, 0.78, 0.6], 'fog': [0.78, 0.66, 0.55], 'fog_density': 0.003,
             'ambient': [0.8, 0.74, 0.66], 'sun': [1.0, 0.88, 0.7]},
     'dungeon': 'Laboratoire de Pross'},
    {'id': 'blackflame', 'map': 's013', 'name': 'Blackflame Peak', 'levels': [52, 54], 'level_bonus': 21,
     'textures': {'grass': 'grass_08', 'grass2': 'dust_05', 'dirt': 'dust_05', 'road': 'road_05', 'rock': 'mount_05'},
     'tint': [0.62, 0.58, 0.6],
     'env': {'sky_top': [0.16, 0.12, 0.16], 'horizon': [0.55, 0.28, 0.24], 'fog': [0.34, 0.24, 0.24], 'fog_density': 0.0035,
             'ambient': [0.66, 0.58, 0.58], 'sun': [1.0, 0.75, 0.6]},
     'dungeon': 'Trône du roi sorcier'},
]

# Salles de boss : vrai boss nommé d'Eden (c_monster rang 6), agencement de l'arène et
# mécaniques (voir BossBrain) ; hazard = style des flaques laissées par le boss.
DUNGEONS = {
    'limestone': {'boss': 58470, 'arena': 'pillars', 'mechanics': ['adds', 'puddles'], 'hazard': 'poison',
                  'intro': "Mori, roi des champignons, répand ses spores : évite les flaques vertes !"},
    'rainbowfall': {'boss': 58475, 'arena': 'swamp', 'mechanics': ['clones', 'puddles', 'lasers'], 'hazard': 'shadow',
                    'intro': "Angela, sorcière du marais noir, se dédouble : trouve la vraie !"},
    'beluga': {'boss': 58480, 'arena': 'frost', 'mechanics': ['stomp', 'adds'], 'hazard': 'frost',
               'intro': "Ulicul l'ogre sauvage fait trembler le sol : saute par-dessus ses ondes !"},
    'wetlands': {'boss': 58484, 'arena': 'crystal', 'mechanics': ['totems', 'lasers', 'puddles'], 'hazard': 'poison',
                 'intro': "Doubledoor, hôte de la magie, se protège derrière des totems : détruis-les !"},
    'avila': {'boss': 58488, 'arena': 'lava', 'mechanics': ['meteors', 'stomp'], 'hazard': 'lava',
              'intro': "Miller, bête de flammes géante : la lave monte, reste mobile !"},
    'arid': {'boss': 58486, 'arena': 'pillars', 'mechanics': ['adds', 'vortex', 'puddles'], 'hazard': 'poison',
             'intro': "La reine des insectes appelle sa nichée et t'attire dans sa fosse !"},
    'delphi': {'boss': 58502, 'pet': 58503, 'arena': 'crystal', 'mechanics': ['pet', 'lasers', 'adds', 'meteors'], 'hazard': 'shock',
               'intro': "Pross, le savant fou, lâche l'Expérience 627 : rayons et bombardements !"},
    'blackflame': {'boss': 58510, 'pet': 58511, 'arena': 'lava', 'mechanics': ['pet', 'meteors', 'clones', 'vortex'], 'hazard': 'lava',
                   'intro': "Wushu, le roi sorcier, et son familier Jiku règnent sur le pic de flamme noire !"},
}

MAX_TREES, MAX_ROCKS, MAX_PLANTS = 8, 7, 10


def object_catalog(objs, idx, conv):
    """Décors les plus fréquents de la map, classés arbres / rochers / plantes, avec
    échelle et rayon de collision calés sur Limestone (voir journal)."""
    count = collections.Counter(o['model'] for o in objs)
    scales = collections.defaultdict(list)
    for o in objs:
        scales[o['model']].append(o['scale'])
    trees, rocks, plants = [], [], []
    obj_dir = os.path.join(GAME, 'assets', 'maps', 'objects')
    os.makedirs(obj_dir, exist_ok=True)
    for model, n in count.most_common():
        if not (model.startswith('ue') or model.startswith('ud')) or n < 8:
            continue
        if len(trees) >= MAX_TREES and len(rocks) >= MAX_ROCKS and len(plants) >= MAX_PLANTS:
            break
        dst = os.path.join(obj_dir, model + '.glb')
        if not os.path.exists(dst):
            src = 'map/model/object/%s.nif' % model
            if src not in idx:
                cands = [p for p in idx if p.endswith('/%s.nif' % model) and p.startswith('map/')]
                src = cands[0] if cands else None
            if src is None:
                continue
            try:
                conv.convert(src, [], dst)
            except Exception as ex:  # un modèle cassé ne doit pas bloquer le biome
                print('  ! %s: %s' % (model, ex))
                continue
        lo, hi = bounds(dst)
        if hi[0] < lo[0]:
            continue
        fp = max(hi[0] - lo[0], hi[1] - lo[1])
        h = hi[2] - lo[2]
        med = statistics.median(scales[model])
        w = round(min(4.0, n / 40.0), 2)
        if model.startswith('ud'):
            if len(rocks) < MAX_ROCKS and fp > 0.5:
                rocks.append({'model': model, 'scale': [round(min(3.5 / fp, 1.0), 3), round(min(6.5 / fp, 1.3), 3)],
                              'col': round(0.33 * fp, 2), 'weight': max(w, 0.4)})
        elif h * med < 4.5:
            if len(plants) < MAX_PLANTS:
                plants.append({'model': model, 'scale': [round(med * 0.7, 3), round(med * 1.1, 3)], 'weight': max(w, 0.5)})
        elif len(trees) < MAX_TREES:
            trees.append({'model': model, 'scale': [round(med * 0.6, 3), round(med * 0.85, 3)],
                          'col': round(0.13 * fp, 2), 'weight': max(w, 0.5)})
    return trees, rocks, plants


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-models', action='store_true')
    a = ap.parse_args()
    idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
    read = lambda p: edenpkg.read_file(nif2gltf.PKG, idx[p])  # noqa: E731
    from PIL import Image
    cmon = {int(r[0]): r for r in edenini.read_table('c_monster') if r[0].isdigit()}
    tmon = edenini.read_text('t_monster')
    mlist = build_assets.monsterlist()
    mpath = os.path.join(GAME, 'data', 'monsters.json')
    monsters = json.load(open(mpath, encoding='utf-8'))
    new_kfms = set()

    def add(mid):
        r = cmon.get(mid)
        num = build_assets.num
        name = tmon.get(mid, ['?'])[0].strip()
        # monstre combattable : normal (2) ou élite (3), avec XP et un nom (tous niveaux)
        if r is None or num(r[3]) not in (2, 3) or num(r[14]) <= 10 or num(r[8]) <= 1 or name in ('', '?'):
            return False
        ml = mlist.get(r[1].lower())
        if ml is None:
            return False
        base = os.path.splitext(ml['kfm'])[0]
        if not os.path.exists(os.path.join(GAME, 'assets', 'monsters', base, base + '.glb')):
            new_kfms.add(base)
        monsters[str(mid)] = {
            'id': mid, 'name': ' '.join(tmon.get(mid, ['?'])[0].split()),
            'level': num(r[4]), 'hp': num(r[8]), 'xp': num(r[14]), 'atk': num(r[18]), 'def': num(r[20]),
            'mdef': num(r[22]), 'rank': num(r[3]), 'model': base,
            'texture': os.path.splitext(ml['texture'])[0], 'scale': ml['scale'],
        }
        return True

    conv = nif2gltf.Converter(idx, os.path.join(GAME, 'assets', 'maps', 'objects', 'textures'), 'textures/')
    tex_out = os.path.join(GAME, 'assets', 'maps', 'textures')
    biomes_out = {}
    zones = [z for z in json.load(open(os.path.join(GAME, 'data', 'zones.json'), encoding='utf-8')) if z['id'] == 'limestone']
    zones[0]['level_bonus'] = 0
    zones[0]['biome'] = 'limestone'
    def add_boss(mid, ref_id):
        """Boss nommé (rang 6) : statistiques calées sur l'élite de la zone (ref_id)."""
        r = cmon.get(mid)
        ml = mlist.get(r[1].lower()) if r else None
        if r is None or ml is None:
            return False
        num = build_assets.num
        base = os.path.splitext(ml['kfm'])[0]
        if not os.path.exists(os.path.join(GAME, 'assets', 'monsters', base, base + '.glb')):
            new_kfms.add(base)
        ref = monsters[str(ref_id)]
        lvl = num(r[4])
        k = 1.1 ** (lvl - ref['level'])
        title, _, name = ' '.join(tmon.get(mid, ['?'])[0].split('\n')).partition('>')
        monsters[str(mid)] = {
            'id': mid, 'name': ' '.join((name.strip() or title).split()), 'title': title.strip(' <'),
            'level': lvl, 'hp': int(ref['hp'] * 1.4 * k), 'xp': int(ref['xp'] * 1.5 * k), 'atk': int(ref['atk'] * 1.15 * k),
            'def': int(ref['def'] * k), 'mdef': int(ref.get('mdef', 0) * k), 'rank': 6, 'model': base,
            'texture': os.path.splitext(ml['texture'])[0], 'scale': ml['scale'],
        }
        return True

    lime = DUNGEONS['limestone']
    if add_boss(lime['boss'], zones[0]['elites'][-1] if zones[0].get('elites') else zones[0]['dungeon']['boss']):
        zones[0]['dungeon'].update({k: v for k, v in lime.items()})
    for b in BIOMES:
        declared, _events, spawns = fsm2godot.parse_scene_ini(read('data/scene/%s.ini' % b['map']).decode('big5', 'replace'))
        fsm = fsm2godot.parse_fsm(read('map/model/%s/%s' % (b['map'], declared)))
        objs = fsm2godot.parse_objects(fsm['sections']['OBJ'])
        trees, rocks, plants = object_catalog(objs, idx, conv)
        for t in b['textures'].values():
            dst = os.path.join(tex_out, t + '.png')
            if not os.path.exists(dst):
                Image.open(io.BytesIO(read('map/texture/%s.dds' % t))).convert('RGBA').save(dst)
        counts = collections.Counter()
        for sp in spawns:
            counts[sp['monster']] += sp['count']
        ids = [m for m, _ in counts.most_common() if add(m)]
        normal = sorted((m for m in ids if monsters[str(m)]['rank'] == 2), key=lambda m: monsters[str(m)]['level'])
        elites = sorted((m for m in ids if monsters[str(m)]['rank'] == 3), key=lambda m: monsters[str(m)]['level'])
        if not elites:
            elites = normal[-2:]
        boss = elites[-1]
        dcfg = DUNGEONS.get(b['id'], {})
        if dcfg and add_boss(dcfg['boss'], boss):
            if dcfg.get('pet'):
                add_boss(dcfg['pet'], boss)
            boss = dcfg['boss']
        biomes_out[b['id']] = {'textures': b['textures'], 'tint': b['tint'], 'env': b['env'],
                               'trees': trees, 'rocks': rocks, 'plants': plants}
        zones.append({'id': b['id'], 'biome': b['id'], 'node': int(b['map'][1:]), 'name': b['name'], 'levels': b['levels'],
                      'level_bonus': b['level_bonus'], 'max_level': 15 + b['level_bonus'],
                      'monsters': normal, 'elites': elites,
                      'dungeon': dict({'id': b['id'] + '_lair', 'name': b['dungeon'], 'boss': boss, 'monsters': normal[-4:]},
                                      **{k: v for k, v in dcfg.items() if k != 'boss'})})
        print('%s (%s) : %d monstres, %d élites, boss %s, %d arbres, %d rochers, %d plantes' % (
            b['name'], b['map'], len(normal), len(elites), monsters[str(boss)]['name'], len(trees), len(rocks), len(plants)))

    if not a.skip_models and new_kfms:
        tex_dir = os.path.join(GAME, 'assets', 'monsters', 'textures')
        for base in sorted(new_kfms):
            subprocess.run([PY, '-I', os.path.join(os.path.dirname(__file__), 'nif2gltf.py'),
                            'monster/%s.kfm' % base, os.path.join(GAME, 'assets', 'monsters', base),
                            '--tex-dir', tex_dir, '--anims', build_assets.MONSTER_ANIMS], check=True)
    if not a.skip_models:
        mconv = nif2gltf.Converter(idx, os.path.join(GAME, 'assets', 'monsters', 'textures'), '../textures/')
        for m in monsters.values():
            if not os.path.exists(os.path.join(GAME, 'assets', 'monsters', 'textures', m['texture'] + '.png')):
                p = mconv.find_texture(m['texture'] + '.dds', 'monster/')
                if p:
                    mconv.export_texture(p)
    with open(mpath, 'w', encoding='utf-8') as f:
        json.dump(dict(sorted(monsters.items(), key=lambda kv: int(kv[0]))), f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'zones.json'), 'w', encoding='utf-8') as f:
        json.dump(zones, f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'biomes.json'), 'w', encoding='utf-8') as f:
        json.dump(biomes_out, f, indent=1, ensure_ascii=False)
    print('%d zones, %d nouveaux modèles de monstres' % (len(zones), len(new_kfms)))


if __name__ == '__main__':
    main()
