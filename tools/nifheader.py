"""En-tête NIF Gamebryo 20.x (types de blocs, tailles, table de chaînes)."""
import struct

def parse_header(d):
    nl = d.index(b'\n')
    pos = nl + 1
    ver, endian, user_ver, nblocks = struct.unpack_from('<IBII', d, pos); pos += 13
    ntypes, = struct.unpack_from('<H', d, pos); pos += 2
    types = []
    for _ in range(ntypes):
        n, = struct.unpack_from('<I', d, pos); pos += 4
        types.append(d[pos:pos + n].decode('latin1')); pos += n
    type_idx = struct.unpack_from('<%dH' % nblocks, d, pos); pos += 2 * nblocks
    sizes = struct.unpack_from('<%dI' % nblocks, d, pos); pos += 4 * nblocks
    nstr, maxlen = struct.unpack_from('<II', d, pos); pos += 8
    strings = []
    for _ in range(nstr):
        n, = struct.unpack_from('<I', d, pos); pos += 4
        strings.append(d[pos:pos + n].decode('cp1252', 'replace')); pos += n
    ngroups, = struct.unpack_from('<I', d, pos); pos += 4 + 4 * ngroups
    return dict(version=ver, user_version=user_ver,
                blocks=[types[i & 0x7FFF] for i in type_idx],
                sizes=list(sizes), strings=strings, data_start=pos)
