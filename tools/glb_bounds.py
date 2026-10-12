"""Boîte englobante (repère du modèle, Z vers le haut) d'un .glb converti."""
import json
import struct


def bounds(path):
    b = open(path, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for m in j.get('meshes', []):
        for p in m['primitives']:
            a = j['accessors'][p['attributes']['POSITION']]
            if 'min' in a:
                lo = [min(x, y) for x, y in zip(lo, a['min'])]
                hi = [max(x, y) for x, y in zip(hi, a['max'])]
    return lo, hi
