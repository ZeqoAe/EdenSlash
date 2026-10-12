"""Cosmétiques d'Eden -> skins portables par toutes les classes.

    python -I tools/build_cosmetics.py [--max N]

char/texture/4pequip.ini relie chaque cosmétique (codes K… / A… des objets) à un maillage
par morphologie ; le héros utilise la table « Loli ». Catégories :
  body : tenues (#L… du vestiaire char/m.nif, colonne 1 = 0), teintes avec les couleurs
         RGB565 de 4pequip ;
  head : chapeaux, lunettes, masques, accessoires de bouche (char/model/L1xxx.nif, colonne 1 = 2) ;
  back : ailes, auréoles, sacs, croix (char/model/X6xxA.nif, colonne 1 = 1).
Noms : objets cosmétiques de c_item / c_itemmall (catégorie 68 et skins d'arme), reliés par
le code du **modèle** (colonne 2 ; la colonne 1 est l'icône), et entrées de l'archive
d'Eden (t_collection) ; sinon un nom générique. Textures réduites à 512 px.
Sortie : data/eden_catalog.json -> "cosmetics" : [{id, cat, name, icon, outfit, variants}].
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
CAT_SLOT = {'0': 'body', '2': 'head', '1': 'back'}
GENERIC = {'body': "Costume d'Eden %s", 'head': "Accessoire de tête %s", 'back': "Ailes et dos d'Eden %s"}


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
    ap.add_argument('--max', type=int, default=0, help='nombre max de pièces exportées (test)')
    ap.add_argument('--redo', default='', help='catégories à réexporter (ex. head,back)')
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    from PIL import Image
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    ti = edenini.read_text('t_item')
    tcol = edenini.read_text('t_collection')
    tm = edenini.read_text('t_itemmall')
    # code K du modèle (colonne 2 de c_item ; la colonne 1 est l'icône) -> (id, nom, icône)
    names = {}  # objets du jeu et de la boutique d'Eden
    for table, texts in (('c_item', ti), ('c_itemmall', tm)):
        for r in edenini.read_rows(table):
            if len(r) < 20 or not r[0].isdigit() or not r[1].startswith(('K', 'A')):
                continue
            if r[8] not in ('68', '61', '65', '67') and not r[1].startswith('A'):
                continue
            name = texts.get(int(r[0]), [''])[0].strip()
            if name in ('', '?'):
                name = tcol.get(int(r[0]), [''])[0].strip()
            if name and name != '?':
                model = (r[2] or r[1]).strip()
                names.setdefault(model, (int(r[0]), name, r[1].strip()))
    meshes = {}  # (catégorie, maillage) -> [(code, teinte)]
    for f in loli_table(idx):
        if len(f) < 6 or f[0][:1] not in ('K', 'A') or f[1] not in CAT_SLOT:
            continue
        cat = CAT_SLOT[f[1]]
        mesh = f[2]
        if cat == 'body' and not mesh.startswith('#L'):
            continue
        if cat != 'body' and 'char/model/%s.nif' % mesh.lower() not in idx:
            continue
        if cat == 'head' and f[0].startswith('A'):
            continue  # casques des armures de classe : déjà sur les tenues
        meshes.setdefault((cat, mesh), []).append((f[0], dye_of(f[5])))
    tex_dir = os.path.join(GAME, 'assets', 'player', 'textures')
    out_dir = os.path.join(GAME, 'assets', 'player', 'outfits')
    os.makedirs(out_dir, exist_ok=True)
    icon_dir = os.path.join(GAME, 'assets', 'ui', 'items')
    cosmetics = []
    done = 0
    redone = set()
    for (cat, mesh), variants in sorted(meshes.items()):
        named = [v for v in variants if v[0] in names]
        code, dye = named[0] if named else variants[0]
        if cat == 'head' and not named:
            continue  # chapeaux sans nom (boutique d'Eden) : trop nombreux, on garde les nommés
        iid, name, icon_code = names[code] if named else (0, GENERIC[cat] % mesh.lstrip('#'), code)
        short = mesh.lstrip('#').lower()
        rel = ('cos_%s.glb' % short) if cat == 'body' else ('%s_%s.glb' % (cat, short))
        glb = os.path.join(out_dir, rel)
        if cat in a.redo.split(',') and os.path.exists(glb) and glb not in redone:
            os.remove(glb)
            redone.add(glb)
        if not os.path.exists(glb):
            if a.max and done >= a.max:
                continue
            before = set(os.listdir(tex_dir))
            try:
                if cat == 'body':
                    conv = nif2gltf.Converter(idx, tex_dir, '../textures/', [mesh, 'S' + mesh.lstrip('#')])
                    conv.anim_filter = '^$'
                    conv.dye = dict(nif2gltf.DEFAULT_DYE)
                    if dye:
                        conv.dye['outfit'] = dye
                    nifs, _kfs = nif2gltf.kfm_files(conv.read('char/m.kfm'))
                    conv.convert(nif2gltf.resolve('char', nifs[0]), [], glb)
                else:
                    conv = nif2gltf.Converter(idx, tex_dir, '../textures/')
                    conv.anim_filter = '^$'
                    # couleurs de la variante pour toute la pièce (les chapeaux « L1xxx » seraient
                    # sinon teints comme des cheveux, en brun)
                    pal = dye or nif2gltf.DEFAULT_DYE['outfit']
                    conv.dye = {k: pal for k in nif2gltf.DEFAULT_DYE}
                    conv.convert('char/model/%s.nif' % mesh.lower(), [], glb)
            except Exception as ex:
                print('  ! %s : %s' % (mesh, ex))
                continue
            for t in set(os.listdir(tex_dir)) - before:
                p = os.path.join(tex_dir, t)
                if t.endswith('.png'):
                    im = Image.open(p)
                    if max(im.size) > 512:
                        im.thumbnail((512, 512), Image.LANCZOS)
                        im.save(p)
            done += 1
            print('  %s %s %s' % (cat, mesh, name))
        icon = ''
        p = 'ui/itemicon/%s.dds' % icon_code.lower()
        dst = os.path.join(icon_dir, icon_code.lower() + '.png')
        if os.path.exists(dst):
            icon = 'res://assets/ui/items/%s.png' % icon_code.lower()
        elif p in idx and idx[p].get('pkg') is not None:
            Image.open(io.BytesIO(edenpkg.read_file(nif2gltf.PKG, idx[p]))).convert('RGBA').save(dst)
            icon = 'res://assets/ui/items/%s.png' % icon_code.lower()
        cosmetics.append({'id': short if cat == 'body' else '%s_%s' % (cat, short), 'cat': cat, 'name': name,
                          'eden_item': iid, 'icon': icon, 'rarity': 4, 'outfit': 'res://assets/player/outfits/' + rel,
                          'variants': len(variants), 'codes': sorted({v[0] for v in variants})})
    path = os.path.join(GAME, 'data', 'eden_catalog.json')
    data = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
    data['cosmetics'] = [c for c in cosmetics if os.path.exists(os.path.join(out_dir, os.path.basename(c['outfit'])))]
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    import collections
    print('%d cosmétiques %s (%d exportés maintenant)' % (len(data['cosmetics']),
          dict(collections.Counter(c['cat'] for c in data['cosmetics'])), done))


if __name__ == '__main__':
    main()
