"""Catalogue de tous les équipements d'Eden Eternal (c_item + t_item), de leurs sets
(c_equipset) et des cosmétiques, pour le butin, la fabrication et l'archive.

    python -I tools/build_items.py [--no-models]

Sortie : game/data/eden_catalog.json
  items : [{id, name, slot, wtype, armor, level, rarity, icon, code, r: {stat: ratio},
            set, passive, band, model, texture}]
  sets  : {"e<id>": {name, pieces: [ids], bonus: {n: {stat, text}}}}
  cosmetics : (tools/build_cosmetics.py)

Raretés d'Eden (c_item col. 19) -> jeu : vide = blanc commun (0), 2 = vert spécial (1),
4 = bleu rare (2), 6 = violet épique (3), 3 = orange mythique (4), 5 = or légendaire (5).
Seuls les mythiques et légendaires vont dans l'archive (comme dans Eden).

Statistiques : chaque stat d'Eden est rapportée à la valeur habituelle d'un objet du même
emplacement (ou type d'arme) au même niveau d'Eden (courbe ajustée sur tout le catalogue) :
r = 1 pour un objet moyen. Le jeu multiplie r par sa propre valeur de référence au niveau
de la run, puis par le jet de qualité.

Colonnes de c_item : 1 icône, 2 modèle, 8 catégorie (1-15 armures : 1/4/7/10/13 plates,
2/5/... cuir, 3/6/... tissu ; 16 cape ; 17-33 armes ; 37 collier ; 38 bague ; 39 trophée),
14 niveau, 19 qualité, 23 passif (t_enchant), 37/38 déf. physique / magique, 39-43 FOR AGI
INT SAG CHA, 45/46 att. physique / magique, 50 PV, 51 précision, 52 esquive, 53 critique,
54-60 et 61 bonus secondaires, 66-71 résistances élémentaires.
"""
import argparse
import io
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), '..', 'game')
ARMOR_SLOT = {1: 'head', 2: 'head', 3: 'head', 4: 'chest', 5: 'chest', 6: 'chest', 7: 'legs', 8: 'legs', 9: 'legs',
              10: 'gloves', 11: 'gloves', 12: 'gloves', 13: 'boots', 14: 'boots', 15: 'boots', 16: 'back',
              37: 'necklace', 38: 'ring', 39: 'trophy'}
ARMOR_CLASS = {1: 'plates', 2: 'cuir', 0: 'tissu'}  # catégorie % 3
FAMILY_WORDS = [('西洋劍', 'rapier'), ('槍鐮', 'gunscythe'), ('匕首', 'dagger'), ('大劍', 'greatsword'), ('太刀', 'katana'),
                ('巨斧', 'axe'), ('雙手斧', 'axe'), ('權杖', 'scepter'), ('金屬棒', 'rod'), ('拳套', 'cestus'), ('巨鎚', 'hammer'),
                ('巨槌', 'hammer'), ('雙鎚', 'hammer'), ('火炮', 'cannon'), ('火砲', 'cannon'), ('長槍', 'spear'), ('弓', 'bow'),
                ('法杖', 'staff'), ('法仗', 'staff'), ('杖', 'staff'), ('吉他', 'guitar'), ('法書', 'grimoire'), ('盾', 'shield'),
                ('劍', 'sword')]
RARITY = {'': 0, '1': 0, '2': 1, '4': 2, '6': 3, '3': 4, '5': 5}
# colonne d'Eden -> stat du jeu
STAT_COLS = {39: 'str', 40: 'agi', 41: 'int', 42: 'wis', 43: 'lck', 45: 'patk', 46: 'matk', 50: 'hp',
             51: 'dmg_pct', 52: 'eva', 53: 'crit', 54: 'mcrit', 55: 'crit_dmg', 56: 'parry', 57: 'atk_speed',
             58: 'move_speed', 59: 'def_pct', 60: 'cdr', 61: 'crit_dmg'}
# niveaux d'Eden des objets répartis sur les zones du jeu (data/zones.json, dans l'ordre)
ZONE_BANDS = [(1, 25), (26, 35), (36, 45), (46, 50), (51, 55), (56, 62), (63, 68), (69, 99)]


def weapon_families():
    raw = open(os.path.join(edenini.DB, 'weapon.ini'), 'rb').read().decode('big5', 'replace')
    fam = {}
    for line in raw.split('\r\n'):
        m = re.match(r'DB\d+=(W\d{3})\d\d,[^,]*,[^,]*,(.*)', line)
        if not m or m.group(1) in fam:
            continue
        for word, wt in FAMILY_WORDS:
            if word in m.group(2):
                fam[m.group(1)] = wt
                break
    return fam


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return 0.0


def clean(text):
    text = text.replace('\r\n', '\n')
    text = re.sub(r'\$\d+\$', '', text)
    return re.sub(r'[ \t]+', ' ', text).strip()


def fit_curve(points):
    """log(v) = a + b log(niveau) ; renvoie f(niveau)."""
    pts = [(l, v) for l, v in points if l > 0 and v > 0]
    if len(pts) < 8:
        med = sorted(v for _, v in pts)[len(pts) // 2] if pts else 1.0
        return lambda lvl: med
    xs = [math.log(l) for l, _ in pts]
    ys = [math.log(v) for _, v in pts]
    mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
    sxx = sum((x - mx) ** 2 for x in xs) or 1e-9
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    a = my - b * mx
    return lambda lvl: math.exp(a + b * math.log(max(lvl, 1)))


# --- passifs et bonus de set : texte d'Eden -> stats / effets déclenchés du jeu -------------
BUFF_WORDS = [(r'atk spd|attack speed|cast spd', 'frenzy'), (r'crit', 'keen'), (r'move spd', 'haste'),
              (r'\bdef\b|damage taken|dmg taken|received', 'barrier'), (r'\bstr\b|p-atk|\batk\b', 'might'),
              (r'\bagi\b', 'swift'), (r'\bint\b|\bwis\b|m-atk', 'grace'), (r'hp', 'vitality')]
STATUS_FR = {'frenzy': 'Frénésie', 'keen': 'Œil acéré', 'haste': 'Hâte', 'barrier': 'Barrière', 'might': 'Puissance',
             'swift': 'Célérité', 'grace': 'Grâce', 'vitality': 'Vitalité', 'fury': 'Fureur'}


def parse_passive(name, text):
    """Passif d'arme mythique ou légendaire -> {name, desc, stat, procs}."""
    t = text.lower()
    out = {'name': name, 'eden': text, 'stat': {}, 'procs': []}
    lines = []
    m = re.search(r'convert (\d+)% of damage dealt into hp', t)
    if m:
        v = round(int(m.group(1)) * 0.004, 3)
        out['stat']['lifesteal'] = v
        lines.append('%d %% des dégâts infligés rendent des PV' % round(v * 100))
    m = re.search(r'parry \+(\d+)%', t)
    if m:
        out['stat']['parry'] = round(int(m.group(1)) * 0.005, 3)
        lines.append('+%d %% de parade' % round(out['stat']['parry'] * 100))
    if 'elemental resistances +' in t:
        out['stat']['def_pct'] = out['stat'].get('def_pct', 0.0) + 0.03
        lines.append('+3 % de défense')
    head = t.split('chance')[0] if 'chance' in t else t
    m = re.search(r'move spd \+(\d+)%', head)
    if m:
        out['stat']['move_speed'] = round(int(m.group(1)) * 0.01, 3)
        lines.append('+%d %% de vitesse' % int(m.group(1)))
    if re.search(r'max mp \+|mp cost -', head):
        out['stat']['cdr'] = 0.03
        lines.append('-3 % de temps de recharge')
    m = re.search(r'additional (\d+) (fire|ice|lightning|nature|holy|dark)', head)
    if m:
        out['procs'].append({'trigger': 'hit', 'chance': 0.15, 'cd': 2.0,
                             'effect': {'fire': 'burn', 'ice': 'chill', 'lightning': 'shock'}.get(m.group(2), 'shock'),
                             'duration': 3.0, 'radius': 1.5})
        lines.append('à l\'impact, 15 %% de chances : dégâts %s sur la durée' % {'fire': 'de feu', 'ice': 'de glace',
                     'lightning': 'de foudre'}.get(m.group(2), 'élémentaires'))
    if re.search(r'restore.*health|recover.*health|recover \d+% of health', t) and 'lifesteal' not in out['stat']:
        out['stat']['lifesteal'] = 0.02
        lines.append('2 % des dégâts infligés rendent des PV')
    m = re.search(r'(\d+)% chance to (gain an effect|apply a debuff)[^.]*?(?:for (\d+) seconds)?', t)
    if m:
        chance = min(0.25, int(m.group(1)) / 100.0 * 2.0)
        dur = min(float(m.group(3) or 6), 8.0)
        eff = t[m.end():]
        if m.group(2) == 'gain an effect':
            if 'double damage' in eff:
                status = 'fury'
                dur = 3.0
            else:
                status = next((s for pat, s in BUFF_WORDS if re.search(pat, eff)), 'might')
            trig = 'crit' if 'crit hit' in t[:m.start()] else 'hit'
            out['procs'].append({'trigger': trig, 'chance': chance, 'cd': 4.0, 'effect': 'buff', 'status': status, 'duration': dur})
            lines.append('à l\'impact, %d %% de chances : %s (%g s)' % (round(chance * 100), STATUS_FR.get(status, status), dur))
        else:
            if 'move spd' in eff or 'atk spd' in eff:
                effect = 'chill'
                what = 'ralentit la cible'
            elif 'burn' in eff or 'fire' in eff:
                effect = 'burn'
                what = 'brûle la cible'
            else:
                effect = 'shock'
                what = 'la cible subit +15 % de dégâts'
            out['procs'].append({'trigger': 'hit', 'chance': chance, 'cd': 3.0, 'effect': effect, 'duration': dur, 'radius': 1.5})
            lines.append('à l\'impact, %d %% de chances : %s (%g s)' % (round(chance * 100), what, dur))
    if not lines and re.search(r'crit rate \+', t):
        out['stat']['crit'] = 0.03
        lines.append('+3 % de critique')
    if not lines:
        out['stat']['dmg_pct'] = 0.03
        lines.append('+3 % de dégâts')
    out['desc'] = ' ; '.join(lines)
    return out


SET_WORDS = [(r'max hp|\bhp\b', 'hp_pct', 0.04), (r'm-def|p-def|\bdef\b|block', 'def_pct', 0.04),
             (r'm-atk', 'matk_pct', 0.04), (r'p-atk|\batk\b(?! spd)', 'atk_pct', 0.04),
             (r'm-crit', 'mcrit', 0.03), (r'crit dmg|critical damage', 'crit_dmg', 0.08), (r'crit', 'crit', 0.03),
             (r'atk spd|attack speed', 'atk_speed', 0.04), (r'cast spd', 'cast_speed', 0.04), (r'move spd', 'move_speed', 0.03),
             (r'\beva\b|dodge', 'eva', 0.02), (r'\bacc\b', 'dmg_pct', 0.02), (r'parry', 'parry', 0.03),
             (r'heal', 'heal_pct', 0.06), (r'\bstr\b', 'str_pct', 0.04), (r'\bagi\b', 'agi_pct', 0.04),
             (r'\bint\b', 'int_pct', 0.04), (r'\bwis\b', 'wis_pct', 0.04), (r'\blck\b|luck', 'lck_pct', 0.04),
             (r'resist', 'def_pct', 0.02), (r'damage|dmg', 'dmg_pct', 0.03)]


def parse_set_bonus(text, pieces):
    t = text.lower().split(':', 1)[-1]
    stat = {}
    for part in re.split(r',| and ', t):
        for pat, key, v in SET_WORDS:
            if re.search(pat, part):
                stat[key] = round(stat.get(key, 0.0) + v * pieces / 2.0, 3)
                break
    if not stat:
        stat = {'dmg_pct': round(0.02 * pieces / 2.0, 3)}
    return stat


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--no-models', action='store_true', help="pas d'export des modèles d'armes mythiques et légendaires")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    from PIL import Image
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    ti = edenini.read_text('t_item')
    te = edenini.read_text('t_enchant')
    tcol = edenini.read_text('t_collection')
    rows = [r for r in edenini.read_table('c_item') if r[0].isdigit()]
    by_id = {r[0]: r for r in rows}
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

    # --- sets d'Eden ---------------------------------------------------------------------
    tset = edenini.read_text('t_equipset')
    sets, piece_set = {}, {}
    for r in edenini.read_rows('c_equipset'):
        if not r[0].strip().isdigit():
            continue
        sid = int(r[0])
        pieces = [int(c) for c in r[3:14] if c.strip().isdigit() and int(c) > 0]
        effects = [c for c in r[14:] if c.strip().isdigit() and int(c) > 1000]
        if len(pieces) < 2 or not effects:
            continue
        bonus = {}
        for e in effects:
            txt = ' '.join(ti.get(int(e), ['', ''])[1:]).strip()
            m = re.search(r'(\d+)-Piece', txt)
            if not m:
                continue
            n = min(int(m.group(1)), len(pieces))
            bonus[str(n)] = {'stat': parse_set_bonus(txt, n), 'eden': clean(txt)}
        if not bonus:
            continue
        name = tset.get(sid, ['Set %d' % sid])[0].strip()
        sets['e%d' % sid] = {'name': name, 'pieces': pieces, 'bonus': bonus}
        for p in pieces:
            piece_set[p] = 'e%d' % sid

    # --- objets ------------------------------------------------------------------------
    items = []
    seen = set()
    for r in rows:
        cat = int(r[8]) if r[8].isdigit() else 0
        if not (1 <= cat <= 39) or cat in (34, 35, 36):
            continue
        iid = int(r[0])
        name = ti.get(iid, [''])[0].strip()
        if name in ('', '?'):
            name = tcol.get(iid, [''])[0].strip()
        if name in ('', '?') or not r[1]:
            continue
        code = (r[2] or r[1]).strip()
        e = {'id': iid, 'name': name, 'level': int(num(r[14])) or 1, 'rarity': RARITY.get(r[19].strip(), 0), 'code': code}
        if cat in ARMOR_SLOT:
            e['slot'] = ARMOR_SLOT[cat]
            if cat <= 15:
                e['armor'] = ARMOR_CLASS[cat % 3]
        elif code.startswith('W'):
            wt = fam.get(code[:4])
            if wt is None or wt == 'shield':
                continue
            e['slot'] = 'weapon'
            e['wtype'] = wt
        else:
            continue
        key = (name, e['slot'], e['level'], e['rarity'])
        if key in seen:
            continue
        seen.add(key)
        e['icon'] = icon(r[1].strip())
        if not e['icon']:
            continue
        raw = {}
        for col, st in STAT_COLS.items():
            v = num(r[col])
            if v > 0:
                raw[st] = raw.get(st, 0.0) + v
        d = (num(r[37]) + num(r[38])) / (2.0 if num(r[38]) > 0 and num(r[37]) > 0 else 1.0)
        if d > 0:
            raw['def'] = d
        res = sum(num(r[c]) for c in range(66, 72))
        if res > 0:
            raw['def_pct'] = raw.get('def_pct', 0.0) + res
        e['_raw'] = raw
        if iid in piece_set:
            e['set'] = piece_set[iid]
        pas = r[23].strip()
        if e['rarity'] >= 4 and e['slot'] == 'weapon' and pas.isdigit() and int(pas) in te:
            txt = clean(' '.join(te[int(pas)][1:3]))
            nm = te[int(pas)][0].strip()
            if txt:
                e['passive'] = parse_passive(nm, txt)
        lvl = e['level']
        e['band'] = next((i for i, (lo, hi) in enumerate(ZONE_BANDS) if lo <= lvl <= hi), len(ZONE_BANDS) - 1)
        items.append(e)

    # --- ratios : stat / valeur habituelle au même niveau (même emplacement ou type d'arme) ---
    def group(e):
        return e.get('wtype', e['slot'])

    curves = {}
    groups = {}
    for e in items:
        g = group(e)
        for st, v in e['_raw'].items():
            key = (g, 'atk' if st in ('patk', 'matk') else st)
            vv = max(e['_raw'].get('patk', 0), e['_raw'].get('matk', 0)) if st in ('patk', 'matk') else v
            groups.setdefault(key, []).append((e['level'], vv))
    for key, pts in groups.items():
        curves[key] = fit_curve(pts)
    for e in items:
        g = group(e)
        rr = {}
        for st, v in e['_raw'].items():
            exp = curves[(g, 'atk' if st in ('patk', 'matk') else st)](e['level'])
            ratio = v / exp if exp > 0 else 1.0
            # écarts adoucis : un objet d'exception reste fort sans casser l'équilibrage
            rr[st] = round(min(max(ratio, 0.05), 3.0) ** 0.7, 3)
        e['r'] = rr
        del e['_raw']

    # --- modèles 3D des armes mythiques et légendaires (apparences à collectionner) ------
    if not a.no_models:
        wdir = os.path.join(GAME, 'assets', 'weapons')
        conv = nif2gltf.Converter(idx, os.path.join(wdir, 'textures'), 'textures/')
        for e in items:
            if e['slot'] != 'weapon' or e['rarity'] < 4:
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
            except Exception as ex:
                print('  ! %s : %s' % (code, ex))
            if os.path.exists(glb) and os.path.exists(tex):
                e['model'] = 'res://assets/weapons/%s.glb' % code[:4]
                e['texture'] = 'res://assets/weapons/textures/%s.png' % code

    items.sort(key=lambda e: (e['slot'], e.get('wtype', ''), e['level'], e['rarity'], e['name']))
    used_sets = {e['set'] for e in items if 'set' in e}
    sets = {k: v for k, v in sets.items() if k in used_sets}
    out = os.path.join(GAME, 'data', 'eden_catalog.json')
    old = json.load(open(out, encoding='utf-8')) if os.path.exists(out) else {}
    legacy = os.path.join(GAME, 'data', 'eden_items.json')
    if 'cosmetics' not in old and os.path.exists(legacy):
        old['cosmetics'] = json.load(open(legacy, encoding='utf-8')).get('cosmetics', [])
    old['items'] = items
    old['sets'] = sets
    old['bands'] = ZONE_BANDS
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(old, f, ensure_ascii=False, separators=(',', ':'))
    import collections
    print('%d objets, %d sets, %d passifs' % (len(items), len(sets), sum(1 for e in items if 'passive' in e)))
    print('raretés :', dict(sorted(collections.Counter(e['rarity'] for e in items).items())))
    arch = collections.Counter(e.get('wtype', e['slot']) for e in items if e['rarity'] >= 4)
    print('archive (mythiques + légendaires) :', dict(arch))
    print('par zone :', dict(sorted(collections.Counter(e['band'] for e in items).items())))


if __name__ == '__main__':
    main()
