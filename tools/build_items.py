"""Catalogue de tous les équipements d'Eden Eternal (c_item + t_item).

    python -I tools/build_items.py [--no-models]

Sortie : game/data/eden_items.json
  {"items": [{id, name, cn, slot, wtype, level, rarity, icon, code, model, texture}],
   "cosmetics": [...] (voir build_cosmetics)}
Les objets générés en jeu (Items.generate) prennent l'identité (nom, icône, modèle d'arme)
d'un objet d'Eden de même emplacement / type d'arme, de niveau et de rareté proches ;
l'archive les montre tous.

Colonnes de c_item : 1 icône, 2 modèle, 8 catégorie (1-16 armures, 17-34 armes, 37 collier,
38 bague, 39 trophée, 68 cosmétique), 14 niveau requis, 19 qualité d'Eden (3 bleu, 4 or,
5 violet, 6 orange).
"""
import argparse
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), '..', 'game')
ARMOR_CAT = {1: 'head', 2: 'head', 3: 'head', 4: 'chest', 5: 'chest', 6: 'chest', 7: 'legs', 8: 'legs', 9: 'legs',
             10: 'gloves', 11: 'gloves', 12: 'gloves', 13: 'boots', 14: 'boots', 15: 'boots', 16: 'back',
             37: 'necklace', 38: 'ring', 39: 'trophy'}
ARMOR_TYPE = {1: 'tissu', 2: 'cuir', 3: 'plates'}  # catégories 1/2/3, 4/5/6… (ordre d'Eden à vérifier)
# famille d'arme d'après le nom chinois de weapon.ini (ordre : du plus précis au plus général)
FAMILY_WORDS = [('西洋劍', 'rapier'), ('槍鐮', 'gunscythe'), ('匕首', 'dagger'), ('大劍', 'greatsword'), ('太刀', 'katana'),
                ('巨斧', 'axe'), ('雙手斧', 'axe'), ('權杖', 'scepter'), ('金屬棒', 'rod'), ('拳套', 'cestus'), ('巨鎚', 'hammer'),
                ('巨槌', 'hammer'), ('雙鎚', 'hammer'), ('火炮', 'cannon'), ('火砲', 'cannon'), ('長槍', 'spear'), ('弓', 'bow'),
                ('法杖', 'staff'), ('法仗', 'staff'), ('杖', 'staff'), ('吉他', 'guitar'), ('法書', 'grimoire'), ('盾', 'shield'),
                ('劍', 'sword')]
# qualité d'Eden -> rareté du jeu (0 commun, 1 magique, 2 rare/or, 3 épique, 4 légendaire)
RARITY = {'': 0, '1': 0, '2': 0, '3': 1, '4': 2, '5': 3, '6': 4}


def weapon_families():
    raw = open(os.path.join(edenini.DB, 'weapon.ini'), 'rb').read().decode('big5', 'replace')
    fam = {}
    for line in raw.split('\r\n'):
        m = re.match(r'DB\d+=(W\d{3})\d\d,[^,]*,[^,]*,(.*)', line)
        if not m or m.group(1) in fam:
            continue
        name = m.group(2)
        for word, wt in FAMILY_WORDS:
            if word in name:
                fam[m.group(1)] = wt
                break
    return fam


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--no-models', action='store_true', help="pas d'export des modèles d'armes épiques et légendaires")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    from PIL import Image
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    ti = edenini.read_text('t_item')
    rows = [r for r in edenini.read_table('c_item') if r[0].isdigit()]
    fam = weapon_families()
    icon_dir = os.path.join(GAME, 'assets', 'ui', 'items')
    os.makedirs(icon_dir, exist_ok=True)

    def icon(code):
        code = code.lower()
        dst = os.path.join(icon_dir, code + '.png')
        if not os.path.exists(dst):
            p = 'ui/itemicon/%s.dds' % code
            if p not in idx or idx[p].get('pkg') is None:
                return ''
            Image.open(io.BytesIO(edenpkg.read_file(nif2gltf.PKG, idx[p]))).convert('RGBA').save(dst)
        return 'res://assets/ui/items/%s.png' % code

    items, seen = [], set()
    for r in rows:
        cat = int(r[8]) if r[8].isdigit() else 0
        if not (1 <= cat <= 39) or cat in (35, 36):
            continue
        iid = int(r[0])
        name = ti.get(iid, [''])[0].strip()
        if name in ('', '?') or not r[1]:
            continue
        code = (r[2] or r[1]).strip()
        e = {'id': iid, 'name': name, 'cn': r[7].strip(), 'level': int(r[14]) if r[14].isdigit() else 1,
             'rarity': RARITY.get(r[19].strip(), 0), 'code': code}
        if cat in ARMOR_CAT:
            e['slot'] = ARMOR_CAT[cat]
            if cat <= 15:
                e['armor'] = ARMOR_TYPE[(cat - 1) % 3 + 1]
        elif code.startswith('W'):
            wt = fam.get(code[:4])
            if wt is None or wt == 'shield':
                continue
            e['slot'] = 'weapon'
            e['wtype'] = wt
        else:
            continue
        key = (name, e['slot'], e['level'])
        if key in seen:
            continue  # variantes identiques (quêtes, événements)
        seen.add(key)
        e['icon'] = icon(r[1].strip())
        if not e['icon']:
            continue
        items.append(e)
    # modèles 3D des armes épiques et légendaires (apparences d'arme à collectionner)
    if not a.no_models:
        wdir = os.path.join(GAME, 'assets', 'weapons')
        conv = nif2gltf.Converter(idx, os.path.join(wdir, 'textures'), 'textures/')
        done = 0
        for e in items:
            if e['slot'] != 'weapon' or e['rarity'] < 3:
                continue
            code = e['code'].lower()
            glb = os.path.join(wdir, code[:4] + '.glb')
            tex = os.path.join(wdir, 'textures', code + '.png')
            try:
                if not os.path.exists(glb) and 'item/model/%s.nif' % code[:4] in idx:
                    conv.convert('item/model/%s.nif' % code[:4], [], glb)
                if not os.path.exists(tex):
                    p = conv.find_texture(code + '.dds', 'item/')
                    if p:
                        conv.export_texture(p)
                        done += 1
            except Exception as ex:  # modèle illisible : l'objet garde le modèle de son type
                print('  ! %s : %s' % (code, ex))
            if os.path.exists(glb) and os.path.exists(tex):
                e['model'] = 'res://assets/weapons/%s.glb' % code[:4]
                e['texture'] = 'res://assets/weapons/textures/%s.png' % code
        print('%d textures d\'armes exportées' % done)
    items.sort(key=lambda e: (e['slot'], e.get('wtype', ''), e['level'], e['rarity'], e['name']))
    out = os.path.join(GAME, 'data', 'eden_items.json')
    old = json.load(open(out, encoding='utf-8')) if os.path.exists(out) else {}
    old['items'] = items
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(old, f, ensure_ascii=False, separators=(',', ':'))
    by = {}
    for e in items:
        by[e.get('wtype', e['slot'])] = by.get(e.get('wtype', e['slot']), 0) + 1
    print('%d objets : %s' % (len(items), by))


if __name__ == '__main__':
    main()
