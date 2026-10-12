"""Lecteur des archives pkg d'Eden Eternal (pkg.idx + pkg###.pkg, zlib)."""
import struct, zlib, sys, os, csv, fnmatch

REC = 592

def read_index(pkg_dir):
    d = open(os.path.join(pkg_dir, 'pkg.idx'), 'rb').read()
    cs = lambda b: b.split(b'\0')[0].decode('cp1252', 'replace')
    out = []
    for base in range(0, len(d) - REC + 1, REC):
        b = d[base:base + REC]
        name = cs(b[0x160:0x250])
        if not name:
            continue
        out.append(dict(
            path=(cs(b[0x14:0x11c]) + name).replace(chr(92), '/').lower(),
            pkg=struct.unpack_from('<I', b, 0x11c)[0],
            off=struct.unpack_from('<I', b, 0x128)[0],
            csize=struct.unpack_from('<I', b, 0x130)[0],
            usize=struct.unpack_from('<I', b, 0x15c)[0]))
    return out

def read_file(pkg_dir, e):
    with open(os.path.join(pkg_dir, 'pkg%03d.pkg' % e['pkg']), 'rb') as f:
        f.seek(e['off'])
        c = f.read(e['csize'])
        if e['csize'] == e['usize'] and not c.startswith(b'\x78\x9c'):
            return c
        # Les tailles de l'index sont parfois périmées (fichier mis à jour plus
        # gros) : on décompresse jusqu'à la vraie fin du flux zlib.
        d = zlib.decompressobj()
        out = [d.decompress(c)]
        while not d.eof:
            more = f.read(1 << 20)
            if not more:
                raise zlib.error('flux zlib incomplet pour %s' % e.get('path'))
            out.append(d.decompress(more))
        return b''.join(out)

if __name__ == '__main__':
    # usage: edenpkg.py list <pkg_dir> <out.csv>
    #        edenpkg.py extract <pkg_dir> <out_dir> <glob> [<glob>...]
    cmd, pkg_dir = sys.argv[1], sys.argv[2]
    idx = read_index(pkg_dir)
    if cmd == 'list':
        with open(sys.argv[3], 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=['path', 'pkg', 'off', 'csize', 'usize'])
            w.writeheader(); w.writerows(idx)
        print(len(idx), 'entries')
    elif cmd == 'extract':
        out, pats = sys.argv[3], sys.argv[4:]
        n = err = 0
        for e in idx:
            if any(fnmatch.fnmatch(e['path'], p) for p in pats):
                dst = os.path.join(out, e['path'])
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                try:
                    open(dst, 'wb').write(read_file(pkg_dir, e)); n += 1
                except Exception as ex:
                    err += 1; print('ERR', e['path'], ex)
        print(n, 'extracted,', err, 'errors')
