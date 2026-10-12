"""Construit les classes jouables à partir des données d'Eden Eternal.

    python -I tools/build_classes.py [--skip-models]

Sorties (game/) :
  data/classes.json        classes, compétences, passifs (adaptés au hack and slash)
  data/motion_keys.json    impacts / sons / traînées par animation (motion.ini)
  data/minimaps.json       mini-cartes officielles et leur calage monde -> image
  assets/player/<classe>/  modèle du héros (tenue de classe, animations utiles)
  assets/weapons/          armes de la classe (+ icônes)
  assets/ui/skills/        icônes des compétences
  assets/sound/            sons référencés par les animations
"""
import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
GAME = os.path.join(ROOT, 'game')
PY = sys.executable

# Animation Eden (c_spell col. 3 = identifiant de séquence) -> nom de l'animation
MOTION_ID = {3001: 'shoot23', 3002: 'shoot24', 3003: 'shoot25', 412: 'shoot12'}

# Calage des mini-cartes officielles (tools : ajustement eau / sol, voir journal)
MINIMAPS = {
    's002': {'image': 'res://assets/ui/maps/s002m.png', 'ppm': 1.0971, 'ox': 12, 'oy': 8},
    's100': {'image': 'res://assets/ui/maps/s100m.png', 'ppm': 3.2, 'ox': 36, 'oy': 54},
}

# --- Samouraï : compétences d'Eden adaptées au hack and slash -------------------------
# kind : dash (fond en avant), spin (autour de soi), cone (devant), fan (éventail long),
#        flurry (plusieurs coups), line (estoc), buff (renforcement)
SAMURAI_SKILLS = [
    {'id': 50181, 'kind': 'dash', 'mult': 1.8, 'radius': 2.6, 'arc': 120, 'dash': 6.0, 'cooldown': 6.0,
     'applies': {'bleed': 8.0},
     'desc': "Fond sur l'ennemi (6 m) : {dmg} % de dégâts et Saignement (8 s, 15 % de l'attaque par seconde)."},
    {'id': 50182, 'kind': 'spin', 'mult': 1.1, 'hits': 2, 'radius': 4.0, 'arc': 360, 'cooldown': 9.0,
     'buff': {'solar': 8.0},
     'desc': "Tourbillon solaire autour de toi : 2 coups de {dmg} %. Bénédiction solaire : -25 % de dégâts subis (8 s)."},
    {'id': 50183, 'kind': 'cone', 'mult': 2.0, 'radius': 4.0, 'arc': 120, 'cooldown': 5.0,
     'combo': {'requires': 'bleed', 'applies': {'scar': 8.0}},
     'desc': "Entaille en croix : {dmg} %. Sur une cible en Saignement : Cicatrice (ses dégâts -30 %, 8 s)."},
    {'id': 50184, 'kind': 'fan', 'mult': 1.7, 'radius': 10.0, 'arc': 90, 'cooldown': 8.0,
     'applies': {'purgatory': 8.0},
     'desc': "Purgatoire en éventail (10 m) : {dmg} % et Purgatoire (dégâts subis +20 %, 8 s)."},
    {'id': 50185, 'kind': 'flurry', 'mult': 0.9, 'hits': 3, 'radius': 3.5, 'arc': 160, 'cooldown': 7.0,
     'combo': {'requires': 'bleed', 'applies': {'cranes': 8.0}},
     'desc': "Danse des grues : 3 coups de {dmg} %. Sur Saignement : Mille grues (dégâts subis +15 %, 8 s)."},
    {'id': 50186, 'kind': 'cone', 'mult': 2.8, 'radius': 3.5, 'arc': 70, 'cooldown': 10.0,
     'combo': {'requires': 'scar', 'buff': {'marduk': 8.0}},
     'desc': "Frappe éclair : {dmg} %. Sur Cicatrice : Langue de Marduk (+30 % d'attaque et de vitesse, 8 s)."},
    {'id': 50187, 'kind': 'fan', 'mult': 2.2, 'radius': 10.0, 'arc': 90, 'cooldown': 10.0,
     'combo': {'requires': 'purgatory', 'double': True},
     'desc': "Lame d'Asura en éventail (10 m) : {dmg} %, doublé sur les cibles en Purgatoire."},
    {'id': 50188, 'kind': 'line', 'mult': 2.3, 'radius': 8.0, 'arc': 25, 'cooldown': 8.0,
     'combo': {'requires': 'cranes', 'applies': {'stun': 2.0}},
     'desc': "Estoc en ligne (8 m) : {dmg} %. Sur Mille grues : renverse la cible (2 s)."},
    {'id': 50189, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 25.0,
     'buff': {'shrine': 10.0},
     'desc': "Volonté du sanctuaire : +30 % de vitesse et -30 % de dégâts subis (10 s). Sous Bénédiction solaire : immunité au renversement."},
]

SAMURAI_PASSIVES = [
    {'id': 'battojutsu', 'eden': 50302, 'name': 'Battojutsu', 'stat': {'crit': 0.20}, 'max': 1,
     'desc': '+20 % de chances de coup critique.'},
    {'id': 'katana_expert', 'eden': 50305, 'name': 'Katana Expert', 'stat': {'atk_pct': 0.15}, 'max': 1,
     'desc': '+15 % d\'attaque avec un katana.'},
    {'id': 'vigor', 'name': 'Corps aguerri', 'stat': {'hp_pct': 0.15}, 'max': 3, 'desc': '+15 % de PV max.'},
    {'id': 'swift_blade', 'name': 'Lame du vent', 'stat': {'atk_speed': 0.12}, 'max': 3,
     'desc': "+12 % de vitesse d'attaque."},
    {'id': 'bloodthirst', 'name': 'Soif de sang', 'stat': {'lifesteal': 0.03}, 'max': 3,
     'desc': '3 % des dégâts infligés rendent des PV.'},
    {'id': 'light_step', 'name': 'Pas léger', 'stat': {'move_speed': 0.08}, 'max': 2,
     'desc': '+8 % de vitesse de déplacement.'},
    {'id': 'keen_edge', 'name': 'Fil tranchant', 'stat': {'crit_dmg': 0.30}, 'max': 3,
     'desc': '+30 % de dégâts critiques.'},
    {'id': 'focus', 'name': 'Concentration', 'stat': {'cdr': 0.08}, 'max': 3,
     'desc': '-8 % de temps de recharge des compétences.'},
    # build « aérien » : le saut devient une arme
    {'id': 'air_jump', 'name': 'Saut aérien', 'stat': {}, 'max': 2,
     'desc': "+1 saut en l'air (double, puis triple saut)."},
    {'id': 'high_jump', 'name': 'Bond puissant', 'stat': {}, 'max': 2,
     'desc': "+20 % de hauteur de saut : passe au-dessus de plus d'attaques."},
    {'id': 'dive_strike', 'name': 'Frappe plongeante', 'stat': {}, 'max': 3,
     'desc': "Attaquer en l'air plonge au sol : dégâts de zone et étourdissement."},
    {'id': 'featherfall', 'name': 'Apesanteur', 'stat': {}, 'max': 2,
     'desc': "Saut flottant : -25 % de gravité, plus de temps en l'air pour viser et esquiver."},
    {'id': 'air_dash', 'name': 'Pas aérien', 'stat': {}, 'max': 2,
     'desc': "+1 esquive en l'air avant de retoucher le sol."},
]

CLASSES = {
    'samurai': {
        'class_id': 16, 'body': 'm',
        'appearance': {'outfit': '#L272', 'skin': 'SL272', 'hair': '#L107', 'face': '#LFACE',
                       'dye': {'outfit': [[150, 25, 30], [225, 180, 90], [35, 30, 40]],
                               'hair': [[40, 32, 40], [30, 25, 30], [20, 20, 20]]}},
        'weapons': ['W21301', 'W21401', 'W21501', 'W21601'],
        'anims': {'idle': 'stand01', 'battle': 'battle13', 'run': 'move02', 'attacks': ['attack25', 'attack26'],
                  'hurt': 'hurt13', 'death': 'death01', 'jump': 'jump01', 'dodge': 'jump02'},
        'skills': SAMURAI_SKILLS,
        'passives': SAMURAI_PASSIVES,
        'start_skills': 3,  # cartes de compétence proposées au départ de la run
        'lore_fr': ("Un samouraï ne se fie qu'à son katana. Après des années d'entraînement, "
                    "même la lame la plus lourde lui paraît légère comme une plume."),
    },
}

ANIM_FILTER = (r'stand0[1-3]|battle13|move0[1-4]|move3[7-9]|move4[0-3]|attack2[5-6]|shoot12|shoot2[3-5]'
               r'|hurt13|hurt01|death01|jump0[1-3]')


def clean_eden_text(s):
    s = re.sub(r'\$\d+\$', '', s or '')
    return re.sub(r'#[^#]*#', '', s).replace('\r\n', ' ').strip()


def parse_motion(path):
    """motion.ini -> {kfm: {anim: {'hit': [t], 'sounds': [[t, wav]], 'trail': [t0, t1], 'len': t}}}"""
    out = {}
    for line in open(path, encoding='cp1252', errors='replace'):
        if not line.startswith('DB') or '=' not in line:
            continue
        f = line.strip().split('=', 1)[1].split(',')
        if len(f) < 7:
            continue
        kfm, _kf, t, key, _link, sound, anim = f[:7]
        try:
            t = float(t)
        except ValueError:
            continue
        a = out.setdefault(kfm.lower(), {}).setdefault(anim, {'hit': [], 'sounds': [], 'trail': []})
        k = key.lower()
        if k in ('hit', '_hit1', '_hit2', '_hit3', '_hit4'):
            a['hit'].append(round(t, 4))
        elif k == 'end':
            a['len'] = round(t, 4)
        elif k in ('y1', 'y2'):
            a['trail'].append(round(t, 4))
        if sound and sound.lower().endswith('.wav'):
            a['sounds'].append([round(t, 4), sound.lower()])
    for kfm in out.values():
        for a in kfm.values():
            a['hit'].sort()
            a['trail'].sort()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-models', action='store_true')
    a = ap.parse_args()
    idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
    read = lambda p: edenpkg.read_file(nif2gltf.PKG, idx[p])  # noqa: E731
    from PIL import Image

    tspell = edenini.read_text('t_spell')
    cspell = {int(r[0]): r for r in edenini.read_table('c_spell') if r[0].isdigit()}
    tclass = edenini.read_text('t_class')
    motion = parse_motion(os.path.join(edenini.DB, 'motion.ini'))

    def export_icon(code, folder='skillicon', res_dir='assets/ui/skills'):
        p = 'ui/%s/%s.dds' % (folder, code.lower())
        if p not in idx:
            return ''
        out_dir = os.path.join(GAME, res_dir)
        os.makedirs(out_dir, exist_ok=True)
        dst = os.path.join(out_dir, code.lower() + '.png')
        if not os.path.exists(dst):
            Image.open(io.BytesIO(read(p))).convert('RGBA').save(dst)
        return 'res://%s/%s.png' % (res_dir, code.lower())

    out_classes = {}
    used_anims = set()
    fx_names = {'s00141', 's00241', 's00341', 's00441', 's00541'}  # impacts des attaques de base
    for cid, c in CLASSES.items():
        crow = next(r for r in edenini.read_table('c_class') if r[0] == str(c['class_id']))
        entry = {k: v for k, v in c.items() if k not in ('skills', 'passives')}
        entry['name'] = tclass[c['class_id']][0]
        entry['name_fr'] = {'samurai': 'Samouraï'}.get(cid, entry['name'])
        entry['lore'] = c.get('lore_fr') or clean_eden_text(tclass[c['class_id']][1])
        entry['icon'] = export_icon(crow[3])
        entry['model'] = 'res://assets/player/%s/%s.glb' % (cid, cid)
        skills = []
        for s in c['skills']:
            r = cspell[s['id']]
            anim = MOTION_ID.get(int(r[3]), 'shoot23')
            used_anims.add(anim)
            sk = dict(s)
            sk['name'] = tspell[s['id']][0]
            sk['icon'] = export_icon(r[1])
            sk['anim'] = anim
            sk['desc'] = s['desc'].format(dmg=int(round(s['mult'] * 100)))
            # effets d'Eden : incantation (code E -> s), impact (colonne 10)
            cast = ('s' + r[5][1:]).lower() if r[5].upper().startswith('E') else ''
            hit = r[10].lower()
            sk['fx'] = {'cast': cast if 'effect/model/%s.nif' % cast in idx else '',
                        'hit': hit if 'effect/model/%s.nif' % hit in idx else ''}
            fx_names.update(v for v in sk['fx'].values() if v)
            skills.append(sk)
        entry['skills'] = skills
        passives = []
        for p in c['passives']:
            pp = dict(p)
            if 'eden' in p:
                pp['icon'] = export_icon(cspell[p['eden']][1])
            passives.append(pp)
        entry['passives'] = passives
        # armes : icônes + modèles
        weapons = []
        wdir = os.path.join(GAME, 'assets', 'weapons')
        for w in c['weapons']:
            model = w[:4].lower()
            weapons.append({'code': w, 'model': 'res://assets/weapons/%s.glb' % model,
                            'texture': 'res://assets/weapons/textures/%s.png' % w.lower(),
                            'icon': export_icon(w, 'itemicon', 'assets/weapons/icons')})
        entry['weapons'] = weapons
        out_classes[cid] = entry

        if not a.skip_models:
            ap_ = c['appearance']
            dye = dict(nif2gltf.DEFAULT_DYE)
            dye.update(ap_['dye'])
            subprocess.run([PY, '-I', os.path.join(os.path.dirname(__file__), 'nif2gltf.py'),
                            'char/%s.kfm' % c['body'], os.path.join(GAME, 'assets', 'player', cid),
                            '--name', cid, '--only', ','.join([ap_['outfit'], ap_['skin'], ap_['hair'], ap_['face']]),
                            '--anims', ANIM_FILTER, '--dye', json.dumps(dye),
                            '--tex-dir', os.path.join(GAME, 'assets', 'player', 'textures')], check=True)
            conv = nif2gltf.Converter(idx, os.path.join(wdir, 'textures'), 'textures/')
            for w in sorted({x[:4].lower() for x in c['weapons']}):
                conv.convert('item/model/%s.nif' % w, [], os.path.join(wdir, w + '.glb'))
            for w in c['weapons']:
                p = conv.find_texture(w.lower() + '.dds', 'item/')
                if p:
                    conv.export_texture(p)

    import fx2godot
    fx2godot.convert(sorted(n for n in fx_names
                            if not os.path.exists(os.path.join(fx2godot.OUT, n + '.fx.json'))), idx)
    # sons des animations du héros et des monstres utilisés
    snd_dir = os.path.join(GAME, 'assets', 'sound')
    os.makedirs(snd_dir, exist_ok=True)
    monsters = json.load(open(os.path.join(GAME, 'data', 'monsters.json'), encoding='utf-8'))
    kfms = {'m'} | {m['model'] for m in monsters.values()}
    keys = {k: v for k, v in motion.items() if k in kfms}
    wavs = {snd for kf in keys.values() for an in kf.values() for _, snd in an['sounds']}
    # les sons sont des fichiers libres du client (EdenReforged/sound), pas dans les pkg
    src_dir = os.path.join(os.path.dirname(nif2gltf.PKG), 'sound')
    available = {f.lower(): f for f in os.listdir(src_dir)} if os.path.isdir(src_dir) else {}
    copied = 0
    for w in sorted(wavs):
        dst = os.path.join(snd_dir, w)
        if w in available and not os.path.exists(dst):
            shutil.copyfile(os.path.join(src_dir, available[w]), dst)
            copied += 1
    # icônes d'équipement : a1 tête, a2 torse, a3 jambes, a4 gants, a5 bottes, a6 cape
    slots = {'head': 'a1', 'chest': 'a2', 'legs': 'a3', 'gloves': 'a4', 'boots': 'a5', 'back': 'a6'}
    item_icons = {}
    for slot, pre in slots.items():
        codes = sorted(p.split('/')[-1][:-4] for p in idx
                       if re.match(r'ui/itemicon/%s\d{4}\.dds$' % pre, p))[:40]
        item_icons[slot] = [export_icon(c, 'itemicon', 'assets/ui/items') for c in codes]
    # matériaux d'amélioration et or
    item_icons['materials'] = {k: export_icon(c, 'itemicon', 'assets/ui/items')
                               for k, c in {'fragment': 'i00206', 'essence': 'i00222', 'crystal': 'i00232', 'gold': 'i00228'}.items()}
    with open(os.path.join(GAME, 'data', 'item_icons.json'), 'w', encoding='utf-8') as f:
        json.dump(item_icons, f, indent=1)
    with open(os.path.join(GAME, 'data', 'classes.json'), 'w', encoding='utf-8') as f:
        json.dump(out_classes, f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'motion_keys.json'), 'w', encoding='utf-8') as f:
        json.dump(keys, f, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'minimaps.json'), 'w', encoding='utf-8') as f:
        json.dump(MINIMAPS, f, indent=1)
    print('%d classe(s), %d animations clés, %d sons copiés' % (len(out_classes), sum(len(v) for v in keys.values()), copied))


if __name__ == '__main__':
    main()
