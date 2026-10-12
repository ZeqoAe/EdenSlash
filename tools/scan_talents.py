"""Aperçu des talents d'Eden (c_talent + c_enchant) : codes d'effet et exemples.

    python -I tools/scan_talents.py 1 2 3 4 5 16
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402


def talent_rows(class_ids):
    rows = [r for r in edenini.read_table('c_talent') if r and r[0].isdigit()]
    out = {}
    for r in rows:
        k = int(r[0])
        if k > 1000 or k // 10 not in class_ids:  # 11..613 : classes 1 à 61
            continue
        cells = []
        for col, cell in enumerate(r[2:]):
            f = cell.split()
            if len(f) >= 6:
                cells.append({'col': col, 'id': int(f[0]), 'max': int(f[1]), 'req': int(f[2]), 'req_pts': int(f[3]),
                              'spent': int(f[5])})
        out.setdefault(k // 10, []).append(cells)
    return out


def describe(text):
    text = text.replace('\r', ' ').replace('\n', ' ')
    m = re.search(r'\$15\$(.*?)(\$7\$|$)', text)
    return re.sub(r'\$\d+\$', '', m.group(1) if m else text).strip()


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    te = edenini.read_text('t_enchant')
    ce = {int(r[0]): r for r in edenini.read_table('c_enchant') if r[0].isdigit()}
    ids = [int(x) for x in sys.argv[1:]] or [1, 2, 3, 4, 5, 16]
    codes = collections.Counter()
    ex = {}
    for cid, tree in talent_rows(ids).items():
        for row in tree:
            for c in row:
                e = ce.get(c['id'])
                if not e:
                    continue
                codes[e[9]] += 1
                ex.setdefault(e[9], (te.get(c['id'], ['?'])[0], describe(' '.join(te.get(c['id'], ['', ''])[1:]))[:120]))
    for code, n in codes.most_common():
        print(code, n, ex[code])


if __name__ == '__main__':
    main()
