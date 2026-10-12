"""Catalogue de tous les équipements d'Eden Eternal (c_item + t_item), de leurs sets
(c_equipset) et des cosmétiques, pour le butin, la fabrication et l'archive.

    python -I tools/build_items.py [--no-models]

Sortie : game/data/eden_catalog.json
  items : [{id, name, slot, wtype, armor, level, rarity, icon, code, r: {stat: ratio},
            set, passive, band, model, texture}]
  sets  : {"e<id>": {name, pieces: [ids], bonus: {n: {stat, text}}}}
  collection : entrées de l'archive d'Eden hors équipement (apparences, montures, familiers,
            boîte arcanique, autres objets) : [{id, cat, name, icon, code, rarity, mall, ord,
            src, aura?, mount?}]
  cosmetics : (tools/build_cosmetics.py)

Archive d'Eden (c_collection) : col. 2 = 0 jeu / 1 boutique, col. 3 = catégorie :
1 tête, 2 dos, 3 corps, 4 armes (apparences) ; 5-20 armes ; 21 boucliers ; 22 faux-fusils ;
23 plates, 24 cuir, 25 tissu ; 26 bijoux ; 27 capes ; 28 trophées ; 29 montures ;
30 familiers ; 31 boîte arcanique ; 32 autres objets (pierres étoilées, pierres de lune...).
Les objets de la boutique sont dans c_itemmall (enchantements : c_itemmallenchant).
Auras : enchantement de l'objet -> col. 3 = effet visuel (effect/model/sXXXXX.nif),
col. 10-14 = FOR AGI INT SAG CHA en %.

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
              (r'\bdef\b|defense|damage taken|dmg taken|received', 'barrier'), (r'\bstr\b|p-atk|\batk\b', 'might'),
              (r'\bagi\b', 'swift'), (r'\bint\b|\bwis\b|m-atk', 'grace'), (r'hp', 'vitality')]
STATUS_FR = {'frenzy': 'Frénésie', 'keen': 'Œil acéré', 'haste': 'Hâte', 'barrier': 'Barrière', 'might': 'Puissance',
             'swift': 'Célérité', 'grace': 'Grâce', 'vitality': 'Vitalité', 'fury': 'Fureur'}


# trophées : « STR +23 », « Max HP +595 », « increases the HP limit by 417 points »…
TROPHY_FLAT = [(r'\bstr(?:ength)?\b', 'str'), (r'\bagi(?:lity)?\b', 'agi'), (r'\bint(?:elligence)?\b', 'int'),
               (r'\bwis(?:dom)?\b', 'wis'), (r'\blck\b|\bluck\b', 'lck'), (r'p-atk|attack power|\batk\b', 'patk'),
               (r'm-atk|magic attack', 'matk'), (r'max hp|hp limit|\bhp\b', 'hp'), (r'p-def|m-def|\bdef(?:ense)?\b', 'def')]
TROPHY_PCT = [(r'm-crit', 'mcrit', 0.0002), (r'crit', 'crit', 0.0002), (r'resist', 'def_pct', 0.002),
              (r'atk spd|cast spd', 'atk_speed', 0.0002), (r'move spd', 'move_speed', 0.002)]


def parse_trophy(name, text):
    """Effet d'un trophée d'Eden -> (stats brutes comme les colonnes de c_item, passif
    {name, desc, stat, procs} pour l'effet à déclenchement)."""
    t = text.lower().replace('$15$', ' ')
    raw = {}
    passive = {'name': name, 'eden': text, 'stat': {}, 'procs': []}
    lines = []
    parts = re.split(r'(?:\r?\n)+|\.\s+', t)
    for part in parts:
        if 'chance' in part or 'effect' in part:
            continue
        nums = re.findall(r'\+\s*(\d+)|by (\d+)', part)
        if not nums:
            continue
        v = float(next(int(a or b) for a, b in nums))
        done = False
        for pat, st, k in TROPHY_PCT:
            if re.search(pat, part):
                raw[st] = raw.get(st, 0.0) + v * k
                done = True
                break
        if done:
            continue
        for pat, st in TROPHY_FLAT:
            if re.search(pat, part):
                keys = [s2 for p2, s2 in TROPHY_FLAT[:5] if re.search(p2, part)] if st in ('str', 'agi', 'int', 'wis', 'lck') else [st]
                for kk in keys:
                    raw[kk] = raw.get(kk, 0.0) + v
                break
    m = re.search(r'(\d+)% chance', t)
    if m:
        chance = min(0.25, int(m.group(1)) / 100.0 * 2.0)
        eff = t[m.start():]  # phrase de l'effet (et « effect : … » qui suit)
        md = re.search(r'for (\d+) seconds', eff)
        dur = min(float(md.group(1)) if md else 6.0, 8.0)
        if re.search(r'recover|restore|heal', eff):
            passive['procs'].append({'trigger': 'hit', 'chance': chance, 'cd': 8.0, 'effect': 'heal', 'amount': 0.04})
            lines.append('%d %% de chances en frappant : rend 4 %% des PV' % round(chance * 100))
        elif 'debuff' in eff:
            passive['procs'].append({'trigger': 'hit', 'chance': chance, 'cd': 8.0, 'effect': 'buff', 'status': 'resolve', 'duration': dur})
            lines.append('%d %% de chances en frappant : Détermination (%g s)' % (round(chance * 100), dur))
        else:
            status = next((s for pat, s in BUFF_WORDS if re.search(pat, eff)), 'might')
            passive['procs'].append({'trigger': 'hit', 'chance': chance, 'cd': 8.0, 'effect': 'buff', 'status': status, 'duration': dur})
            lines.append('%d %% de chances en frappant : %s (%g s)' % (round(chance * 100), STATUS_FR.get(status, status), dur))
    if not raw and not passive['procs']:
        return {}, {}
    passive['desc'] = ' ; '.join(lines) if lines else 'effet d\'Eden (voir le texte)'
    return raw, (passive if passive['procs'] else {})


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


# Pièces des factions (version taïwanaise seulement, sans nom anglais)
ZH_PREFIX = {'部落之翼': "l'Aile de la Tribu", '聯邦之翼': "l'Aile de la Fédération", '部落勇士': 'Brave de la Tribu',
             '聯邦鬥士': 'Lutteur de la Fédération', '部落之啄': 'Bec de la Tribu', '聯邦之啄': 'Bec de la Fédération',
             '部落突襲': 'Raid de la Tribu', '聯邦影者': 'Ombre de la Fédération', '部落之靈': 'Esprit de la Tribu',
             '聯邦之靈': 'Esprit de la Fédération', '部落先知': 'Prophète de la Tribu', '聯邦魔士': 'Mage de la Fédération'}
ZH_PIECE = {'頭盔': 'Casque', '鎧甲': 'Armure', '腰帶': 'Ceinture', '腕甲': 'Brassards', '戰靴': 'Bottes de guerre',
            '皮冠': 'Coiffe de cuir', '皮甲': 'Plastron de cuir', '力套': 'Gantelets', '皮靴': 'Bottes de cuir',
            '頭冠': 'Diadème', '法袍': 'Robe', '手套': 'Gants', '法靴': 'Bottes de mage'}


def zh_name(n):
    """Nom de l'archive : anglais tel quel, chinois traduit si connu, sinon ''."""
    if not n or n == '?':
        return ''
    if all(ord(ch) < 0x3000 for ch in n):
        return n
    for p, fr in ZH_PREFIX.items():
        if n.startswith(p) and n[len(p):] in ZH_PIECE:
            return '%s (%s)' % (ZH_PIECE[n[len(p):]], fr[0].upper() + fr[1:] if not fr.startswith("l'") else "L'" + fr[2:])
    return ''


ATTR_PCT = {10: 'str_pct', 11: 'agi_pct', 12: 'int_pct', 13: 'wis_pct', 14: 'lck_pct'}


def build_collection(coll, by_id, mall, ti, tm, tcol, icon, idx):
    """Entrées de l'archive d'Eden hors équipement, avec les auras (effet + bonus)."""
    import fx2godot
    ench = {r[0]: r for r in edenini.read_rows('c_enchant') if r and r[0].isdigit()}
    mench = {r[0]: r for r in edenini.read_rows('c_itemmallenchant') if r and r[0].isdigit()}
    te = edenini.read_text('t_enchant')
    tme = edenini.read_text('t_itemmallenchant')
    out, seen, fxs = [], set(), set()
    for r in coll:
        c, iid = int(r[3]), int(r[0])
        if 5 <= c <= 28 or c > 32 or iid in seen:
            continue
        it, is_mall = by_id.get(r[0]), False
        if it is None:
            it, is_mall = mall.get(r[0]), True
        if it is None:
            continue
        name = ''
        for t in (tcol, ti, tm):
            n = t.get(iid, [''])[0].strip()
            if n and n != '?':
                name = n
                break
        if not name:
            name = zh_name(r[1].strip())
        if not name:
            continue
        ic = icon(it[1].strip())
        if not ic:
            continue
        seen.add(iid)
        x = {'id': iid, 'cat': c, 'name': name, 'icon': ic, 'code': it[1].strip(),
             'rarity': RARITY.get(it[19].strip(), 0), 'mall': r[2] == '1', 'ord': int(r[4]) if r[4].isdigit() else 0}
        src = tcol.get(iid, ['', ''])
        if len(src) > 1 and src[1].strip() and src[1].strip() != '?':
            x['src'] = clean(src[1])
        eid = it[23].strip() if len(it) > 23 else ''
        e = (mench if is_mall else ench).get(eid) or (ench if is_mall else mench).get(eid)
        if e is not None and c in (29, 30, 31, 32):
            txt = ''
            for t in ((tme, te) if is_mall else (te, tme)):
                f = t.get(int(eid))
                if f:
                    txt = clean(' '.join(f[1:3]))
                    break
            if c == 29 and len(e) > 17 and e[17].strip().isdigit():
                x['mount'] = {'speed': int(e[17]), 'ride': e[10].strip()}
            fx = e[3].strip().lower() if len(e) > 3 else ''
            if c == 32 and fx.startswith('s') and 'effect/model/%s.nif' % fx in idx:
                stat = {}
                for col, st in ATTR_PCT.items():
                    v = num(e[col]) if len(e) > col else 0.0
                    if v > 0:
                        stat[st] = round(v / 100.0, 3)
                if not stat and txt:
                    m = re.search(r'(\d+)\s*%', txt)
                    stat = {k: round(v / 0.04 * (int(m.group(1)) / 100.0 if m else 0.03), 3)
                            for k, v in parse_set_bonus(txt, 2).items()}
                low = name.lower()
                kind = 'star' if 'star stone' in low else ('luna' if 'luna' in low or 'moon' in low else 'other')
                x['aura'] = {'fx': fx, 'stat': stat, 'kind': kind, 'eden': txt}
                fxs.add(fx)
        out.append(x)
    have = {f[:-len('.fx.json')] for f in os.listdir(fx2godot.OUT) if f.endswith('.fx.json')}
    todo = sorted(fxs - have)
    if todo:
        print('effets d\'aura à convertir : %d' % len(todo))
        fx2godot.convert(todo, idx, quads_only=True)
    have = {f[:-len('.fx.json')] for f in os.listdir(fx2godot.OUT) if f.endswith('.fx.json')}
    fx2godot.share_variants(sorted(fxs & have))
    for f in sorted(fxs & have):
        fx2godot.mark_hard_quads(f, quads_only=True)  # auras : maillages (dragons, papillons) gardés
    fx2godot.hide_aura_parts(fxs & have)  # boîtes et panneaux rectangulaires autour du héros
    for x in out:
        if 'aura' in x and x['aura']['fx'] not in have:
            del x['aura']
    out.sort(key=lambda x: (x['cat'], x['mall'], x['ord'], x['id']))
    return out


def weapon_skins(collection, idx):
    """Apparences d'armes de l'archive (catégorie 4, codes K…) : weapon.ini donne le modèle
    (item/model/wNNN.nif) et la texture ; exportés dans assets/weapons (textures 256 px)."""
    from PIL import Image
    raw = open(os.path.join(edenini.DB, 'weapon.ini'), 'rb').read().decode('big5', 'replace')
    kmap = {}
    for line in raw.split('\r\n'):
        m = re.match(r'DB\d+=(K\d+),([^,]*),([^,]*),(.*)', line)
        if m:
            kmap.setdefault(m.group(1), (m.group(2).strip().lower(), m.group(3).strip().lower(), m.group(4)))
    wdir = os.path.join(GAME, 'assets', 'weapons')
    conv = nif2gltf.Converter(idx, os.path.join(wdir, 'textures'), 'textures/')
    n = 0
    for x in collection:
        if x['cat'] != 4 or x['code'] not in kmap:
            continue
        model, tex, zh = kmap[x['code']]
        tex = tex[:-4] if tex.endswith('.dds') else tex
        glb = os.path.join(wdir, model + '.glb')
        png = os.path.join(wdir, 'textures', tex + '.png')
        try:
            if not os.path.exists(glb) and 'item/model/%s.nif' % model in idx:
                conv.convert('item/model/%s.nif' % model, [], glb)
            if not os.path.exists(png):
                p = conv.find_texture(tex + '.dds', 'item/')
                if p:
                    conv.export_texture(p)
                    if os.path.exists(png):
                        im = Image.open(png)
                        if max(im.size) > 256:
                            im.thumbnail((256, 256), Image.LANCZOS)
                            im.save(png)
        except Exception as ex:
            print('  ! %s : %s' % (model, ex))
        if os.path.exists(glb) and os.path.getsize(glb) < 2000:
            os.remove(glb)  # modèle sans maillage
            for f in (glb + '.import',):
                if os.path.exists(f):
                    os.remove(f)
            continue
        wt = next((t for w, t in FAMILY_WORDS if w in zh), '')
        if wt != 'shield' and os.path.exists(glb) and os.path.exists(png):
            x['skin'] = {'model': 'res://assets/weapons/%s.glb' % model,
                         'texture': 'res://assets/weapons/textures/%s.png' % tex, 'wtype': '' if wt == 'shield' else wt}
            n += 1
    print('apparences d\'armes : %d' % n)


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
    # read_rows : certaines lignes de c_item sont séparées par plusieurs sauts de ligne
    rows = [r for r in edenini.read_rows('c_item') if r[0].isdigit() and len(r) > 71]
    mall = {r[0]: r for r in edenini.read_rows('c_itemmall') if r[0].isdigit() and len(r) > 30}
    tm = edenini.read_text('t_itemmall')
    coll = [r for r in edenini.read_rows('c_collection') if len(r) > 5 and r[0].isdigit() and r[3].isdigit()]
    coll_cat, coll_ord, coll_name = {}, {}, {}
    for r in coll:
        coll_cat.setdefault(int(r[0]), int(r[3]))
        coll_name.setdefault(int(r[0]), zh_name(r[1].strip()))
        coll_ord.setdefault(int(r[0]), int(r[4]) if r[4].isdigit() else 0)
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
        if not (1 <= cat <= 39) or cat in (35, 36):
            continue
        iid = int(r[0])
        name = ti.get(iid, [''])[0].strip()
        if name in ('', '?'):
            name = tcol.get(iid, [''])[0].strip()
        if name in ('', '?'):
            name = coll_name.get(iid, '')  # objets sans nom anglais : nom de l'archive
        if name in ('', '?') or not r[1]:
            continue
        if (name.lower().startswith('test') or '測試' in r[7]) and iid not in coll_cat:
            continue  # objets de test d'Eden (sauf ceux listés dans son archive)
        code = (r[2] or r[1]).strip()
        # niveau requis dans Eden (0 : sans niveau, comme les trophées)
        e = {'id': iid, 'name': name, 'level': int(num(r[14])), 'rarity': RARITY.get(r[19].strip(), 0), 'code': code}
        if cat in ARMOR_SLOT:
            e['slot'] = ARMOR_SLOT[cat]
            if cat <= 15:
                e['armor'] = ARMOR_CLASS[cat % 3]
        elif code.startswith('W'):
            wt = fam.get(code[:4])
            if wt is None:
                continue
            if wt == 'shield' or cat == 34:
                e['slot'] = 'shield'  # boucliers : pièces de collection (pas d'emplacement main gauche)
            else:
                e['slot'] = 'weapon'
                e['wtype'] = wt
        else:
            continue
        if cat == 34 and e['slot'] != 'shield':
            continue
        if e['rarity'] >= 4 and e['level'] <= 1 and e['slot'] != 'trophy':
            e['level'] = 90  # objets de fin de jeu sans niveau requis (Reforged Ascension, Ragnarok…)
        key = (name, e['slot'], e['level'], e['rarity'])
        if iid in coll_cat and 5 <= coll_cat[iid] <= 28:
            # entrée de l'archive d'Eden : toujours gardée (même nom qu'un autre objet)
            e['arch'] = coll_cat[iid]
            e['ord'] = coll_ord[iid]
            src = tcol.get(iid, ['', ''])
            if len(src) > 1 and src[1].strip() and src[1].strip() != '?':
                e['src'] = clean(src[1])
        elif key in seen:
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
        if e['slot'] == 'trophy' and r[23].strip().isdigit() and int(r[23]) in te:
            # trophée : ses bonus sont dans son effet d'Eden (texte), pas dans les colonnes
            traw, tpas = parse_trophy(te[int(r[23])][0].strip(), clean(' '.join(te[int(r[23])][1:3])))
            for k, v in traw.items():
                raw[k] = raw.get(k, 0.0) + v
            if tpas:
                e['passive'] = tpas
        e['_raw'] = raw
        if iid in piece_set:
            e['set'] = piece_set[iid]
        pas = r[23].strip()
        # passif d'arme ; effet d'un trophée (son seul bonus dans Eden)
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
    collection = build_collection(coll, by_id, mall, ti, tm, tcol, icon, idx)
    if not a.no_models:
        weapon_skins(collection, idx)
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
    old['collection'] = collection
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(old, f, ensure_ascii=False, separators=(',', ':'))
    import collections
    print('%d objets, %d sets, %d passifs' % (len(items), len(sets), sum(1 for e in items if 'passive' in e)))
    print('raretés :', dict(sorted(collections.Counter(e['rarity'] for e in items).items())))
    arch = collections.Counter(e.get('wtype', e['slot']) for e in items if e['rarity'] >= 4)
    print('archive (mythiques + légendaires) :', dict(arch))
    print('par zone :', dict(sorted(collections.Counter(e['band'] for e in items).items())))
    print('archive : %d équipements, %d autres entrées %s, %d auras' % (
        sum(1 for e in items if 'arch' in e), len(collection),
        dict(sorted(collections.Counter(c['cat'] for c in collection).items())),
        sum(1 for c in collection if 'aura' in c)))


if __name__ == '__main__':
    main()
