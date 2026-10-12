"""Retrouve dans les pkg les fichiers absents de l'index (entrées périmées).

    python -I tools/scan_orphans.py <signature> [<signature>...]  > orphans.txt

Cherche chaque début de flux zlib (78 9C), décompresse les premiers octets et
garde ceux qui commencent par une des signatures (ex. 'FSM V', '|V.').
Sortie : pkg, offset, aperçu de l'en-tête.
"""
import os
import sys
import zlib
from concurrent.futures import ProcessPoolExecutor

sys.path.insert(0, os.path.dirname(__file__))
import edenpkg  # noqa: E402

PKG = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'EdenReforged', 'pkg')


def scan(args):
    path, sigs = args
    data = open(path, 'rb').read()
    found = []
    pos = data.find(b'\x78\x9c')
    while pos >= 0:
        try:
            head = zlib.decompressobj().decompress(data[pos:pos + 512], 128)
            if any(head.startswith(s) for s in sigs):
                found.append((os.path.basename(path), pos, head[:96]))
        except zlib.error:
            pass
        pos = data.find(b'\x78\x9c', pos + 2)
    return found


def main():
    sigs = [s.encode('latin1') for s in sys.argv[1:]]
    files = sorted(f for f in os.listdir(PKG) if f.endswith('.pkg'))
    with ProcessPoolExecutor() as ex:
        for res in ex.map(scan, [(os.path.join(PKG, f), sigs) for f in files]):
            for name, off, head in res:
                print('%s\t%d\t%r' % (name, off, head), flush=True)


if __name__ == '__main__':
    main()
