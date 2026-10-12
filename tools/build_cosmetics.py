"""Cosmétiques d'Eden (costumes, codes K… de c_item, catégorie 68) -> skins de tenue.

    python -I tools/build_cosmetics.py [--max N]

char/texture/4pequip.ini relie chaque costume à un maillage de tenue par morphologie ;
le héros utilise la table « Loli » (#L…). Chaque maillage distinct devient une tenue
(assets/player/outfits/cos_<code>.glb) teinte avec les couleurs du premier costume nommé
qui l'utilise (couleurs RGB565 de 4pequip). Textures réduites à 512 px pour le poids.
Sortie : data/eden_items.json -> "cosmetics".
"""
import argparse
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), '..', 'game')
ROOT = os.path.join(os.path.dirname(__file__), '..')


def rgb565(h):
    v = int(h, 16)
    return [round(((v >> 11) & 31) * 255 / 31), round(((v >> 5) & 63) * 255 / 63), round((v & 31) * 255 / 31)]


def dye_of(hexes):
    hexes = hexes.strip()
    if len(hexes) < 12:
        return None
    hexes = hexes.zfill(12)
    return [rgb565(hexes[i:i + 4]) for i in (0, 4, 8)]


def loli_table(idx):
    raw = edenpkg.read_file(nif2gltf.PKG, idx['char/texture/4pequip.ini']).decode('big5', 'replace')
    out, cur = [], None
    for line in raw.split('\r\n'):
        if line.startswith('['):
            cur = line
            continue
        if cur == '[TableLoli]' and '=' in line:
            out.append(line.split('=', 1)[1].split(','))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--max', type=int, default=0, help='nombre max de tenues exportées (test)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    from PIL import Image
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    ti = edenini.read_text('t_item')
    items = {}
    for r in edenini.read_table('c_item'):
        if r[0].isdigit() and r[8] == '68' and r[1].startswith('K'):
            name = ti.get(int(r[0]), [''])[0].strip()
            if name and name != '?':
                items.setdefault(r[1].strip(), (int(r[0]), name, r[1].strip()))
    meshes = {}  # #Lnnn -> [code K, dye]
    for f in loli_table(idx):
        if len(f) < 6 or f[0][:1] not in ('K', 'A') or f[1] != '0' or not f[2].startswith('#L'):
            continue
        meshes.setdefault(f[2], []).append((f[0], dye_of(f[5])))
    tex_dir = os.path.join(GAME, 'assets', 'player', 'textures')
    out_dir = os.path.join(GAME, 'assets', 'player', 'outfits')
    os.makedirs(out_dir, exist_ok=True)
    icon_dir = os.path.join(GAME, 'assets', 'ui', 'items')
    cosmetics = []
    done = 0
    for mesh, variants in sorted(meshes.items()):
        named = [v for v in variants if v[0] in items]
        if named:
            code, dye = named[0]
            iid, name, icon_code = items[code]
        else:
            # costume sans nom anglais dans le client : nom générique
            code, dye = variants[0]
            iid, name, icon_code = 0, "Costume d'Eden %s" % mesh.lstrip('#'), code
        rel = 'cos_%s.glb' % mesh.lstrip('#').lower()
        glb = os.path.join(out_dir, rel)
        skin = 'S' + mesh.lstrip('#')
        if not os.path.exists(glb):
            if a.max and done >= a.max:
                continue
            before = set(os.listdir(tex_dir))
            conv = nif2gltf.Converter(idx, tex_dir, '../textures/', [mesh, skin])
            conv.anim_filter = '^$'
            conv.dye = dict(nif2gltf.DEFAULT_DYE)
            if dye:
                conv.dye['outfit'] = dye
            nifs, _kfs = nif2gltf.kfm_files(conv.read('char/m.kfm'))
            try:
                conv.convert(nif2gltf.resolve('char', nifs[0]), [], glb)
            except Exception as ex:
                print('  ! %s : %s' % (mesh, ex))
                continue
            # textures neuves réduites à 512 px
            for t in set(os.listdir(tex_dir)) - before:
                p = os.path.join(tex_dir, t)
                if t.endswith('.png'):
                    im = Image.open(p)
                    if max(im.size) > 512:
                        im.thumbnail((512, 512), Image.LANCZOS)
                        im.save(p)
            done += 1
            print('  tenue', mesh, name)
        icon = ''
        p = 'ui/itemicon/%s.dds' % icon_code.lower()
        dst = os.path.join(icon_dir, icon_code.lower() + '.png')
        if os.path.exists(dst):
            icon = 'res://assets/ui/items/%s.png' % icon_code.lower()
        elif p in idx and idx[p].get('pkg') is not None:
            Image.open(io.BytesIO(edenpkg.read_file(nif2gltf.PKG, idx[p]))).convert('RGBA').save(dst)
            icon = 'res://assets/ui/items/%s.png' % icon_code.lower()
        cosmetics.append({'id': mesh.lstrip('#'), 'name': name, 'eden_item': iid, 'icon': icon, 'rarity': 3,
                          'outfit': 'res://assets/player/outfits/' + rel, 'variants': len(variants)})
    path = os.path.join(GAME, 'data', 'eden_items.json')
    data = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
    data['cosmetics'] = [c for c in cosmetics if os.path.exists(os.path.join(out_dir, os.path.basename(c['outfit'])))]
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print('%d tenues cosmétiques (%d exportées maintenant)' % (len(data['cosmetics']), done))


if __name__ == '__main__':
    main()
