"""Teste le lecteur NIF sur un échantillon d'assets et compte les blocs en erreur."""
import sys, random, collections, time
sys.path.insert(0, __import__('os').path.dirname(__file__))
import edenpkg, nif

P = 'C:/Users/Nico/AppData/Local/EdenReforged/pkg'
prefixes = sys.argv[1:] or ['char/', 'monster/', 'map/', 'item/', 'effect/', 'ride/']
idx = edenpkg.read_index(P)
for prefix in prefixes:
    fs = [e for e in idx if e['path'].startswith(prefix) and e['path'].endswith(('.nif', '.kf'))]
    random.seed(2); smp = random.sample(fs, min(120, len(fs)))
    errs = collections.Counter(); ex_files = {}; nfiles = nblk = fatal = 0
    t = time.time()
    for e in smp:
        try:
            d = edenpkg.read_file(P, e)
        except Exception:
            continue
        if not d.startswith(b'Gamebryo'):
            continue
        nfiles += 1
        try:
            nf = nif.NifFile.parse(d)
        except Exception as ex:
            fatal += 1; errs['FATAL ' + str(ex)[:90]] += 1; ex_files.setdefault('FATAL ' + str(ex)[:90], e['path']); continue
        for b in nf.blocks:
            nblk += 1
            if b.error:
                k = b.error[:90]; errs[k] += 1; ex_files.setdefault(k, e['path'])
    print('== %s files=%d blocks=%d fatal=%d errblocks=%d (%.1fs)' % (prefix, nfiles, nblk, fatal, sum(errs.values()) - fatal, time.time() - t))
    for k, v in errs.most_common(8):
        print('   %4d %s   [%s]' % (v, k, ex_files[k]))
