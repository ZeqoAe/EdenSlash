"""Lecture des tables .ini d'Eden Eternal (|V.x|ncols| puis lignes séparées par '|').

Les champs peuvent contenir des retours à la ligne : une ligne logique se termine
quand on a lu `ncols` champs.
"""
import os

DB = os.path.join(os.path.dirname(__file__), '..', 'extracted', 'data', 'db')
if not os.path.isdir(DB):
    # session sans client Eden : tables copiées dans le kit (tools/export_kit.py)
    DB = os.path.join(os.path.dirname(__file__), '..', 'eden_kit', 'db')

def read_table(name, encoding='big5'):
    raw = open(os.path.join(DB, name + '.ini'), 'rb').read().decode(encoding, 'replace')
    head, _, body = raw.partition('\r\n')
    parts = head.strip('|').split('|')
    ncols = int(parts[-1])
    rows, cur = [], []
    for field in body.split('|'):
        if len(cur) == ncols:
            # le séparateur de ligne "\r\n" est collé au début du champ suivant
            rows.append(cur)
            cur = []
            field = field[2:] if field.startswith('\r\n') else field
        cur.append(field)
    if len(cur) == ncols:
        rows.append(cur)
    return rows

def read_text(name):
    """Tables t_*.ini : 'N|' puis liste des colonnes utiles, puis id|texte...|"""
    raw = open(os.path.join(DB, name + '.ini'), 'rb').read().decode('cp1252', 'replace')
    lines = raw.split('\r\n')
    nfields = int(lines[0].strip('|'))
    body = '\r\n'.join(lines[2:])
    fields = body.split('|')
    out, i = {}, 0
    while i + nfields <= len(fields):
        rec = [f.lstrip('\r\n') if j == 0 else f for j, f in enumerate(fields[i:i + nfields])]
        if rec[0].strip().isdigit():
            out[int(rec[0])] = rec[1:]
        i += nfields
    return out


def read_rows(name, encoding='big5'):
    """Comme read_table, mais découpe les lignes sur « |\r\n<nombre>| » : résiste aux
    lignes qui n'ont pas exactement ncols champs (c_enchant)."""
    import re
    raw = open(os.path.join(DB, name + '.ini'), 'rb').read().decode(encoding, 'replace')
    _head, _, body = raw.partition('\r\n')
    return [chunk.split('|') for chunk in re.split(r'\|\r\n(?=\d+\|)', body) if chunk]
