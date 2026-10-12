"""Talents de classe d'Eden (arbre « Class Talent ») et certificats.

    python -I tools/build_talents.py

Sortie : game/data/talents.json
  {classe: {"rows": [[cellule|null × 8] × 3], "talents": {id: {...}}}}
  cellule : {id, max, req (talent prérequis), req_pts, tier}
  talent  : nom, icône, niveau max, effet {type, stat | skill, per_level}, description FR.
Les talents viennent de c_talent (arbre) et c_enchant / t_enchant (effets, textes).
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402
from scan_talents import describe, talent_rows  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), '..', 'game')
# toutes les classes de data/classes.json (numéro de classe d'Eden : class_id)
CLASS_IDS = {}

# code d'effet d'Eden -> (type, stat du jeu, facteur appliqué au nombre de la description)
STAT_CODES = {
    2083: ('stat', 'def_pct', 0.01), 2002: ('stat', 'hp_pct', 0.01), 2040: ('stat', 'crit', 0.01),
    2043: ('stat', 'crit_dmg', 0.01), 2038: ('stat', 'heal_pct', 0.01), 2108: ('stat', 'parry', 0.01),
    2109: ('stat', 'parry', 0.01), 2069: ('stat', 'cast_speed', 0.01), 2068: ('stat', 'atk_speed', 0.01),
    2051: ('stat', 'move_speed', 0.01), 2095: ('stat', 'def_pct', 0.01), 2015: ('stat', 'cdr', 0.01),
    2102: ('stat', 'atk_pct', 0.01), 2103: ('stat', 'atk_pct', 0.01), 2104: ('stat', 'atk_pct', 0.01),
    2088: ('stat', 'dmg_pct', 0.005),  # précision (ACC) : convertie en dégâts
}
ATTR_WORDS = {'STR': 'str', 'AGI': 'agi', 'INT': 'int', 'WIS': 'wis', 'LCK': 'lck'}
STAT_FR = {
    'def_pct': 'de défense', 'hp_pct': 'de PV max', 'crit': 'de critique', 'crit_dmg': 'de dégâts critiques',
    'heal_pct': 'de soins reçus', 'parry': 'de parade', 'cast_speed': "de vitesse d'incantation",
    'atk_speed': "de vitesse d'attaque", 'move_speed': 'de vitesse', 'cdr': 'de réduction des recharges',
    'atk_pct': "d'attaque physique et magique", 'dmg_pct': 'de dégâts (précision)',
    'str_pct': 'de force', 'agi_pct': "d'agilité", 'int_pct': "d'intelligence", 'wis_pct': 'de sagesse', 'lck_pct': 'de chance',
}


def first_number(text):
    m = re.search(r'([+-]?\d+(?:\.\d+)?)\s*(%|sec)', text)
    return float(m.group(1)) if m else 1.0


def effect_of(row, text):
    code = int(row[9]) if row[9].isdigit() else 0
    skill = int(row[10]) if len(row) > 10 and row[10].isdigit() and int(row[10]) > 1000 else 0
    n = first_number(text)
    if code == 2085:
        attr = next((v for k, v in ATTR_WORDS.items() if k in text), 'str')
        return {'type': 'stat', 'stat': attr + '_pct', 'per_level': n * 0.01}
    if code in STAT_CODES:
        t, stat, k = STAT_CODES[code]
        return {'type': t, 'stat': stat, 'per_level': round(n * k, 4)}
    if code == 2064 and skill:
        return {'type': 'skill_dmg', 'skill': skill, 'per_level': n * 0.01}
    if code == 2141 and skill:
        return {'type': 'skill_cd', 'skill': skill, 'per_level': abs(n) * 0.01}
    if code == 2065 and skill:
        return {'type': 'skill_duration', 'skill': skill, 'per_level': n}
    if code in (2066, 2945) and skill:
        return {'type': 'skill_power', 'skill': skill, 'per_level': 0.2}
    return {'type': 'stat', 'stat': 'dmg_pct', 'per_level': 0.01}


def fr_desc(eff, skills):
    t = eff['type']
    if t == 'stat':
        v = eff['per_level'] * 100
        return '+%s %% %s par niveau' % (('%g' % round(v, 2)).replace('.', ','), STAT_FR.get(eff['stat'], eff['stat']))
    name = skills.get(eff.get('skill'), 'la compétence')
    if t == 'skill_dmg':
        return '+%g %% de dégâts de « %s » par niveau' % (eff['per_level'] * 100, name)
    if t == 'skill_cd':
        return '-%g %% de recharge de « %s » par niveau' % (eff['per_level'] * 100, name)
    if t == 'skill_duration':
        return '+%g s de durée des effets de « %s » par niveau' % (eff['per_level'], name)
    return '« %s » renforcée : +20 %% de dégâts et de durée des effets' % name


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    idx = {e['path']: e for e in edenpkg.load_index(nif2gltf.PKG)}
    from PIL import Image
    te = edenini.read_text('t_enchant')
    ce = {int(r[0]): r for r in edenini.read_rows('c_enchant') if r[0].isdigit()}
    classes = json.load(open(os.path.join(GAME, 'data', 'classes.json'), encoding='utf-8'))
    CLASS_IDS.update({cid: int(c['class_id']) for cid, c in classes.items()})
    out_dir = os.path.join(GAME, 'assets', 'ui', 'talents')
    os.makedirs(out_dir, exist_ok=True)

    def icon(code):
        p = 'ui/skillicon/%s.dds' % code.lower()
        dst = os.path.join(out_dir, code.lower() + '.png')
        if os.path.exists(dst):
            return 'res://assets/ui/talents/%s.png' % code.lower()
        if p not in idx or idx[p].get('pkg') is None:
            return ''
        Image.open(io.BytesIO(edenpkg.read_file(nif2gltf.PKG, idx[p]))).convert('RGBA').save(dst)
        return 'res://assets/ui/talents/%s.png' % code.lower()

    trees = talent_rows(set(CLASS_IDS.values()))
    data = {}
    for cid, num in CLASS_IDS.items():
        skills = {int(s['id']): s['name'] for s in classes[cid]['skills']}
        rows_out, talents = [], {}
        for row in trees.get(num, [])[:3]:
            cells = [None] * 8
            for c in row:
                e = ce.get(c['id'])
                if e is None:
                    continue
                text = describe(' '.join(te.get(c['id'], ['', ''])[1:]))
                eff = effect_of(e, text)
                # la colonne de la case vaut le palier ; le prérequis de points dépensés en découle
                cells[min(c['col'], 7)] = {'id': c['id'], 'max': c['max'], 'req': c['req'], 'req_pts': c['req_pts'], 'tier': c['col'], 'spent': c['spent']}
                talents[str(c['id'])] = {'name': te.get(c['id'], ['?'])[0], 'icon': icon(e[1]), 'max': c['max'],
                                         'effect': eff, 'desc': fr_desc(eff, skills), 'eden': text}
            rows_out.append(cells)
        data[cid] = {'rows': rows_out, 'talents': talents,
                     'certificates': [p['id'] for p in classes[cid].get('passives', []) if p.get('eden')]}
        print('%s : %d talents' % (cid, len(talents)))
    with open(os.path.join(GAME, 'data', 'talents.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
