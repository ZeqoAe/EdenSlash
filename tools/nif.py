"""Lecteur NIF Gamebryo générique piloté par nif.xml (niftools).

Usage :
    nf = NifFile.parse(data)
    for blk in nf.blocks: blk.type, blk['Name'], ...

Les références (Ref/Ptr) restent des index entiers (-1 = nul). Les chaînes
indexées (string / NiFixedString) sont résolues via la table de l'en-tête.
Les tableaux de structures simples (Vector3, TexCoord, Triangle...) sont
décodés en bloc avec numpy et renvoyés sous forme de ndarray (N, k).
"""
import os
import re
import struct
import xml.etree.ElementTree as ET

import numpy as np

XML_PATH = os.path.join(os.path.dirname(__file__), 'third_party', 'nif.xml')

BASIC_FMT = {
    'uint64': 'Q', 'int64': 'q', 'ulittle32': 'I', 'uint': 'I', 'int': 'i',
    'ushort': 'H', 'short': 'h', 'char': 'b', 'sbyte': 'b', 'byte': 'B',
    'normbyte': 'B', 'bool': 'B', 'BlockTypeIndex': 'H', 'FileVersion': 'I',
    'float': 'f', 'hfloat': 'e', 'Ptr': 'i', 'Ref': 'i', 'StringOffset': 'I',
    'NiFixedString': 'I',
}


def ver_num(s):
    """'20.2.0.7' ou 'V20_2_0_7' -> 0x14020007"""
    m = re.match(r'V?(\d+)(?:[._](\d+))?(?:[._](\d+))?(?:[._](\d+))?', s)
    if not m:
        raise ValueError(s)
    a, b, c, d = (int(x or 0) for x in m.groups())
    return (a << 24) | (b << 16) | (c << 8) | d


class Spec:
    _inst = None

    @classmethod
    def get(cls):
        if cls._inst is None:
            cls._inst = Spec(XML_PATH)
        return cls._inst

    def __init__(self, path):
        root = ET.parse(path).getroot()
        self.tokens = []  # (attrs, token, string) dans l'ordre du fichier
        for tok in root.findall('token'):
            attrs = tok.get('attrs').split()
            for sub in tok:
                self.tokens.append((attrs, sub.get('token'), sub.get('string')))
        self.basics = {e.get('name'): e for e in root.findall('basic')}
        self.enums = {}
        for tag in ('enum', 'bitflags', 'bitfield'):
            for e in root.findall(tag):
                self.enums[e.get('name')] = e.get('storage')
        self.structs = {e.get('name'): e for e in root.findall('struct')}
        self.objects = {e.get('name'): e for e in root.findall('niobject')}
        self._expr_cache = {}
        self._fields_cache = {}
        self._fast_cache = {}

    # --- expressions -------------------------------------------------------
    def subst(self, s, attr):
        for attrs, tok, rep in self.tokens:
            if attr in attrs and tok in s:
                s = s.replace(tok, rep)
        return s

    _split = re.compile(r'(&&|\|\||==|!=|<=|>=|<<|>>|[()<>&|+\-*/!])')

    def compile_expr(self, s, attr):
        key = (s, attr)
        c = self._expr_cache.get(key)
        if c is not None:
            return c
        s = self.subst(s, attr)
        names, out = [], []
        for part in self._split.split(s):
            p = part.strip()
            if not p:
                continue
            if p == '&&':
                out.append(' and ')
            elif p == '||':
                out.append(' or ')
            elif p == '!':
                out.append(' not ')
            elif p == '/':
                out.append('//')
            elif self._split.fullmatch(p):
                out.append(p)
            elif re.fullmatch(r'\d+(\.\d+){3}', p):
                out.append(str(ver_num(p)))
            elif re.fullmatch(r'0x[0-9a-fA-F]+|\d+(\.\d+)?([eE][-+]?\d+)?', p):
                out.append(p)
            elif p in ('true', 'false'):
                out.append('True' if p == 'true' else 'False')
            else:
                names.append(p)
                out.append('V[%d]' % (len(names) - 1))
        code = compile(''.join(out).strip(), s, 'eval')
        c = (code, names)
        self._expr_cache[key] = c
        return c

    def inherits(self, objtype, base):
        while objtype:
            if objtype == base:
                return True
            objtype = self.objects[objtype].get('inherit')
        return False

    def object_fields(self, objtype):
        f = self._fields_cache.get(objtype)
        if f is None:
            e = self.objects[objtype]
            parent = e.get('inherit')
            f = (self.object_fields(parent) if parent else []) + e.findall('field')
            self._fields_cache[objtype] = f
        return f


class NifError(Exception):
    pass


class Reader:
    def __init__(self, data, version, user_version, strings):
        self.d = data
        self.pos = 0
        self.version = version
        self.user_version = user_version
        self.strings = strings
        self.spec = Spec.get()
        self.objtype = None

    def unpack(self, fmt, n=None):
        if n is None:
            v = struct.unpack_from('<' + fmt, self.d, self.pos)[0]
            self.pos += struct.calcsize(fmt)
            return v
        sz = struct.calcsize(fmt) * n
        arr = np.frombuffer(self.d, dtype='<' + fmt, count=n, offset=self.pos).copy()
        self.pos += sz
        return arr

    # --- évaluation ---------------------------------------------------------
    def eval(self, expr, attr, scope, arg, T=None):
        code, names = self.spec.compile_expr(expr, attr)
        vals = []
        for n in names:
            if n == 'Version':
                vals.append(self.version)
            elif n == 'User Version':
                vals.append(self.user_version)
            elif n == 'BS Header\\BS Version':
                vals.append(0)
            elif n == '#ARG#':
                vals.append(arg if arg is not None else 0)
            elif '\\' in n:
                obj = scope
                for part in n.split('\\'):
                    obj = obj.get(part, 0) if isinstance(obj, dict) else 0
                vals.append(obj)
            else:
                v = scope.get(n, 0)
                if isinstance(v, dict):  # bitfield lu comme dict
                    v = v.get('_value', 0)
                vals.append(v)
        try:
            return eval(code, {'V': vals})
        except Exception as ex:
            raise NifError('expr %r: %s' % (expr, ex))

    def field_active(self, f, scope, arg):
        g = f.get
        if g('since') and self.version < ver_num(g('since')):
            return False
        if g('until') and self.version > ver_num(g('until')):
            return False
        if g('versions'):
            return False  # restreint à des versions Bethesda
        if g('onlyT') and not self.spec.inherits(self.objtype, g('onlyT')):
            return False
        if g('excludeT') and self.spec.inherits(self.objtype, g('excludeT')):
            return False
        if g('vercond') and not self.eval(g('vercond'), 'vercond', scope, arg):
            return False
        if g('cond') and not self.eval(g('cond'), 'cond', scope, arg):
            return False
        return True

    # --- lecture des types ---------------------------------------------------
    def fast_fmt(self, typ):
        """Format struct pour une structure composée uniquement de basiques."""
        cache = self.spec._fast_cache
        if typ in cache:
            return cache[typ]
        fmt = None
        if typ in BASIC_FMT and typ not in ('bool', 'NiFixedString'):
            fmt = BASIC_FMT[typ]
        elif typ in self.spec.structs:
            parts = []
            for f in self.spec.structs[typ].findall('field'):
                if any(f.get(a) for a in ('since', 'until', 'cond', 'vercond', 'arg', 'template', 'width')):
                    parts = None
                    break
                sub = self.fast_fmt(f.get('type'))
                n = f.get('length')
                if sub is None or (n and not n.isdigit()) or len(set(sub)) != 1:
                    parts = None
                    break
                parts.append(sub * int(n or 1))
            if parts and len(set(''.join(parts))) == 1:
                fmt = ''.join(parts)
        cache[typ] = fmt
        return fmt

    def read_array(self, typ, n, arg, T):
        if n <= 0:
            return []
        fmt = self.fast_fmt(typ)
        if fmt is not None:
            arr = self.unpack(fmt[0], n * len(fmt))
            return arr.reshape(n, len(fmt)) if len(fmt) > 1 else arr
        return [self.read_type(typ, arg, T) for _ in range(n)]

    def read_type(self, typ, arg=None, T=None):
        if typ == '#T#':
            typ = T
        if typ == 'bool':
            return self.unpack('B') if self.version >= 0x04010001 else self.unpack('I')
        if typ == 'NiFixedString':
            i = self.unpack('i')
            return self.strings[i] if 0 <= i < len(self.strings) else ''
        if typ in BASIC_FMT:
            return self.unpack(BASIC_FMT[typ])
        if typ in self.spec.enums:
            return self.unpack(BASIC_FMT[self.spec.enums[typ]])
        if typ == 'string' and self.version >= 0x14010003:
            i = self.unpack('i')
            return self.strings[i] if 0 <= i < len(self.strings) else ''
        if typ == 'SizedString' or typ == 'string':
            n = self.unpack('I')
            s = self.d[self.pos:self.pos + n].decode('cp1252', 'replace')
            self.pos += n
            return s
        if typ in self.spec.structs:
            return self.read_fields(self.spec.structs[typ].findall('field'), arg, T)
        raise NifError('type inconnu %s' % typ)

    def read_fields(self, fields, arg=None, T=None, scope=None):
        scope = {} if scope is None else scope
        for f in fields:
            if not self.field_active(f, scope, arg):
                continue
            typ = f.get('type')
            fT = f.get('template')
            if fT == '#T#':
                fT = T
            farg = f.get('arg')
            if farg is not None:
                farg = self.eval(farg, 'arg', scope, arg)
            length = f.get('length')
            if length is None:
                val = self.read_type(typ, farg, fT or T)
            else:
                n = int(self.eval(length, 'length', scope, arg))
                width = f.get('width')
                if width is None:
                    val = self.read_array(typ, n, farg, fT or T)
                else:
                    w = scope.get(width) if width in scope else None
                    if w is not None and not isinstance(w, (int, np.integer)):
                        val = [self.read_array(typ, int(w[i]), farg, fT or T) for i in range(n)]
                    else:
                        m = int(self.eval(width, 'width', scope, arg))
                        flat = self.read_array(typ, n * m, farg, fT or T)
                        if isinstance(flat, np.ndarray) and n * m:
                            val = flat.reshape((n, m) + flat.shape[1:])
                        else:
                            val = [flat[i * m:(i + 1) * m] for i in range(n)]
            scope[f.get('name')] = val
        return scope


class Block(dict):
    type = ''
    index = -1
    error = None


class NifFile:
    def __init__(self):
        self.version = 0
        self.blocks = []
        self.roots = []
        self.strings = []

    @classmethod
    def parse(cls, data, strict=False):
        nf = cls()
        nl = data.index(b'\n')
        pos = nl + 1
        ver, = struct.unpack_from('<I', data, pos); pos += 4
        nf.version = ver
        if ver >= 0x14000003:
            pos += 1  # endian
        user_ver = 0
        if ver >= 0x0A000108:
            user_ver, = struct.unpack_from('<I', data, pos); pos += 4
        nblocks, = struct.unpack_from('<I', data, pos); pos += 4
        if ver < 0x14000000:
            raise NifError('version non gérée %x' % ver)
        ntypes, = struct.unpack_from('<H', data, pos); pos += 2
        types = []
        for _ in range(ntypes):
            n, = struct.unpack_from('<I', data, pos); pos += 4
            types.append(data[pos:pos + n].decode('latin1')); pos += n
        tidx = struct.unpack_from('<%dH' % nblocks, data, pos); pos += 2 * nblocks
        sizes = None
        if ver >= 0x14020005:
            sizes = struct.unpack_from('<%dI' % nblocks, data, pos); pos += 4 * nblocks
        nstr, _ = struct.unpack_from('<II', data, pos); pos += 8
        for _ in range(nstr):
            n, = struct.unpack_from('<I', data, pos); pos += 4
            nf.strings.append(data[pos:pos + n].decode('cp1252', 'replace')); pos += n
        ngroups, = struct.unpack_from('<I', data, pos); pos += 4 + 4 * ngroups

        r = Reader(data, ver, user_ver, nf.strings)
        r.pos = pos
        spec = r.spec
        for i in range(nblocks):
            btype = types[tidx[i] & 0x7FFF]
            start = r.pos
            blk = Block()
            blk.type, blk.index = btype, i
            if ver < 0x14020005 and False:
                pass
            try:
                if btype not in spec.objects:
                    raise NifError('bloc inconnu %s' % btype)
                r.objtype = btype
                r.read_fields(spec.object_fields(btype), scope=blk)
                if sizes is not None and r.pos - start != sizes[i]:
                    raise NifError('%s: lu %d octets, attendu %d' % (btype, r.pos - start, sizes[i]))
            except (NifError, struct.error, ValueError, IndexError) as ex:
                blk.error = str(ex)
                if strict or sizes is None:
                    raise NifError('bloc %d %s: %s' % (i, btype, ex))
            if sizes is not None:
                r.pos = start + sizes[i]
            nf.blocks.append(blk)
        try:
            nroots = r.unpack('I')
            nf.roots = [r.unpack('i') for _ in range(nroots)]
        except struct.error:
            nf.roots = [0]
        return nf
