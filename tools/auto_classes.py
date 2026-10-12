"""Import automatique des classes d'Eden restantes (14 classes « vertes » de base et
40 classes « orange » d'ascension) : sorts, certificats, apparence, armes et combos.

Appelé par build_classes.py (build(ctx)) après les 6 classes réglées à la main.

Sorts partagés (« jouables directement », sans attendre la maîtrise) :
  - classe verte : les 5 sorts de novice de sa famille d'Eden (Guerrier, Voleur, Chasseur,
    Clerc, Magicien) ;
  - classe orange : tous les sorts de sa classe parente (comme dans Eden, l'ascension
    garde les sorts de la classe d'origine), et le certificat qu'elle partage avec elle.
"""
import os

import auto_spells
from eden_fr import CLASS_META, FAMILY_BASE, NEW_WEAPON_TYPES, SPELL_FR

# combos d'auto-attaque des nouvelles armes (mêmes champs que COMBOS de build_classes)
NEW_COMBOS = {
    'sword': [
        {'name': 'Taille', 'anim': 'attack01', 'mult': 1.0, 'arc': 150, 'hit_fx': 's00141', 'desc': "Coup d'épée horizontal."},
        {'name': 'Revers', 'anim': 'attack02', 'mult': 1.1, 'arc': 150, 'hit_fx': 's00241', 'desc': 'Revers rapide.'},
        {'name': 'Estoc tournoyant', 'anim': 'attack03', 'mult': 0.8, 'hits': 2, 'spin_turns': 1, 'arc': 360, 'radius': 3.4,
         'finisher': True, 'applies': {'bleed': 4.0}, 'hit_fx': 's00541',
         'desc': 'Tour complet lame tendue : 2 coups tout autour et Saignement.'},
    ],
    'rapier': [
        {'name': 'Estoc', 'anim': 'attack17', 'mult': 1.0, 'arc': 60, 'radius': 3.8, 'speed': 1.2, 'hit_fx': 's00141',
         'desc': 'Estocade longue et précise.'},
        {'name': 'Double estoc', 'anim': 'attack18', 'mult': 0.65, 'hits': 2, 'arc': 60, 'radius': 3.8, 'speed': 1.2,
         'hit_fx': 's00141', 'desc': 'Deux estocades éclair.'},
        {'name': 'Fente', 'anim': 'attack19', 'mult': 2.0, 'arc': 30, 'radius': 5.5, 'dash': 3.0, 'finisher': True,
         'applies': {'purgatory': 4.0}, 'hit_fx': 's00541', 'desc': "Fente de 3 m qui transperce la ligne d'ennemis."},
    ],
    'greatsword': [
        {'name': 'Taille lourde', 'anim': 'attack08', 'mult': 1.3, 'arc': 170, 'radius': 3.4, 'hit_fx': 's00241',
         'desc': 'Large taille à deux mains.'},
        {'name': 'Revers lourd', 'anim': 'attack09', 'mult': 1.4, 'arc': 170, 'radius': 3.4, 'hit_fx': 's00241',
         'desc': 'Le revers balaie tout devant.'},
        {'name': 'Fracas', 'anim': 'shoot25', 'mult': 2.7, 'arc': 360, 'radius': 4.0, 'leap': 6.0, 'leap_forward': 2.5,
         'land_hit': True, 'finisher': True, 'applies': {'stun': 0.8}, 'hit_fx': 's00541',
         'desc': "Bond puis l'espadon s'abat : onde de choc et renversement."},
    ],
    'hammer': [
        {'name': 'Coup de marteau', 'anim': 'attack08', 'mult': 1.3, 'arc': 140, 'radius': 3.2, 'hit_fx': 's00241',
         'desc': 'Coup écrasant.'},
        {'name': 'Revers écrasant', 'anim': 'attack09', 'mult': 1.4, 'arc': 140, 'radius': 3.2, 'applies': {'stun': 0.5},
         'hit_fx': 's00241', 'desc': 'Le revers sonne la cible.'},
        {'name': 'Séisme', 'anim': 'shoot24', 'mult': 2.6, 'arc': 360, 'radius': 4.4, 'leap': 5.0, 'land_hit': True,
         'finisher': True, 'applies': {'stun': 1.0}, 'hit_fx': 's00541', 'desc': 'Le marteau frappe le sol : séisme tout autour.'},
    ],
    'rod': [
        {'name': "Trait d'ombre", 'anim': 'attack10', 'mult': 1.0, 'bolt': True, 'projectile': 'dark', 'hit_fx': 's00341',
         'desc': 'Projectile des ténèbres.'},
        {'name': 'Double trait', 'anim': 'attack11', 'mult': 0.7, 'bolt': True, 'volley': 2, 'spread': 14, 'projectile': 'dark',
         'hit_fx': 's00341', 'desc': 'Deux projectiles des ténèbres.'},
        {'name': 'Puits maudit', 'anim': 'shoot01', 'kind': 'ground', 'range': 9.0, 'mult': 1.6, 'radius': 3.5, 'arc': 360,
         'finisher': True, 'applies': {'poison': 4.0}, 'hit_fx': 's00541', 'desc': 'Zone maudite sur la cible : dégâts et Poison.'},
    ],
    'cestus': [
        {'name': 'Direct', 'anim': 'attack21', 'mult': 0.8, 'arc': 120, 'radius': 2.8, 'speed': 1.35, 'hit_fx': 's00141',
         'desc': 'Coup de poing rapide.'},
        {'name': 'Crochet', 'anim': 'attack22', 'mult': 0.9, 'arc': 140, 'radius': 2.8, 'speed': 1.35, 'hit_fx': 's00141',
         'desc': 'Crochet du gauche.'},
        {'name': 'Rafale', 'anim': 'attack21', 'mult': 0.45, 'hits': 3, 'arc': 120, 'radius': 2.8, 'speed': 1.4,
         'hit_fx': 's00241', 'desc': 'Trois coups enchaînés.'},
        {'name': 'Uppercut du dragon', 'anim': 'shoot23', 'mult': 2.0, 'arc': 360, 'radius': 3.2, 'leap': 6.0, 'finisher': True,
         'applies': {'stun': 0.8}, 'hit_fx': 's00541', 'desc': 'Uppercut sauté : projette et renverse les ennemis proches.'},
    ],
    'cannon': [
        {'name': 'Obus', 'anim': 'attack13', 'mult': 1.1, 'bolt': True, 'projectile': 'fire', 'hit_fx': 's00341',
         'desc': 'Obus explosif.'},
        {'name': 'Mitraille', 'anim': 'attack13', 'mult': 0.6, 'bolt': True, 'volley': 3, 'spread': 22, 'projectile': 'arrow',
         'hit_fx': 's00141', 'desc': '3 balles en éventail.'},
        {'name': 'Bombardement', 'anim': 'shoot50', 'kind': 'ground', 'range': 12.0, 'mult': 1.6, 'radius': 4.0, 'arc': 360,
         'drop': 'rain', 'finisher': True, 'applies': {'burn': 3.0}, 'hit_fx': 's00541',
         'desc': 'Une salve d\'obus retombe sur la zone visée.'},
    ],
    'spear': [
        {'name': 'Estoc de lance', 'anim': 'attack07', 'mult': 1.1, 'arc': 40, 'radius': 4.6, 'hit_fx': 's00141',
         'desc': 'Estoc à longue portée.'},
        {'name': 'Balayage', 'anim': 'attack07', 'mult': 1.0, 'arc': 220, 'radius': 3.8, 'hit_fx': 's00241',
         'desc': 'La hampe balaie largement.'},
        {'name': 'Plongeon du dragon', 'anim': 'shoot24', 'mult': 2.5, 'arc': 360, 'radius': 3.8, 'leap': 14.0, 'leap_forward': 5.0,
         'land_hit': True, 'finisher': True, 'applies': {'stun': 0.8}, 'hit_fx': 's00541',
         'desc': 'Saut très haut puis plongeon lance en avant : impact tout autour.'},
    ],
    'guitar': [
        {'name': 'Note de feu', 'anim': 'attack15', 'mult': 1.0, 'bolt': True, 'projectile': 'fire', 'hit_fx': 's00341',
         'desc': 'Une note brûlante.'},
        {'name': 'Accord', 'anim': 'attack15', 'mult': 0.65, 'bolt': True, 'volley': 3, 'spread': 30, 'projectile': 'magic',
         'hit_fx': 's00341', 'desc': '3 notes en éventail.'},
        {'name': 'Onde sonore', 'anim': 'shoot01', 'mult': 1.5, 'arc': 360, 'radius': 4.6, 'finisher': True,
         'applies': {'chill': 2.0}, 'self_status': {'regen': 2.0}, 'hit_fx': 's00541',
         'desc': 'Riff assourdissant tout autour : ralentit les ennemis et te soigne un peu.'},
    ],
    'grimoire': [
        {'name': 'Page arcanique', 'anim': 'attack16', 'mult': 1.0, 'bolt': True, 'projectile': 'magic', 'hit_fx': 's00341',
         'desc': 'Projectile arcanique.'},
        {'name': 'Glyphe', 'anim': 'attack16', 'kind': 'ground', 'range': 11.0, 'mult': 1.1, 'radius': 2.8, 'arc': 360,
         'hit_fx': 's12141', 'desc': 'Un glyphe explose sur la zone visée.'},
        {'name': 'Salve de pages', 'anim': 'shoot01', 'mult': 0.8, 'bolt': True, 'volley': 5, 'spread': 40, 'pierce': 1,
         'projectile': 'magic', 'finisher': True, 'hit_fx': 's00541', 'desc': '5 projectiles perçants en éventail.'},
    ],
    'gunscythe': [
        {'name': 'Faux', 'anim': 'attack08', 'mult': 1.2, 'arc': 200, 'radius': 3.6, 'hit_fx': 's00241',
         'desc': 'Large coup de faux.'},
        {'name': 'Moisson', 'anim': 'attack09', 'mult': 1.1, 'arc': 200, 'radius': 4.2, 'pull': 2.5, 'hit_fx': 's00241',
         'desc': 'La lame attire les ennemis vers toi.'},
        {'name': 'Rafale de la faux', 'anim': 'shoot50', 'mult': 0.9, 'bolt': True, 'volley': 3, 'spread': 26, 'pierce': 1,
         'projectile': 'dark', 'finisher': True, 'hit_fx': 's00541', 'desc': 'Le canon de la faux tire 3 balles perçantes.'},
    ],
}

ARMOR_BASE = {1: {'hp': 1.15, 'def': 6.0}, 2: {'hp': 1.0, 'def': 3.0}, 3: {'hp': 0.9, 'def': 0.0}}


def _attributes(row):
    """Attributs de base et croissance d'après les coefficients d'Eden (c_class col. 17-21)."""
    vals = {}
    for key, col in (('str', 17), ('agi', 18), ('int', 19), ('wis', 20), ('lck', 21)):
        try:
            v = float(row[col])
        except (ValueError, IndexError):
            v = 100.0
        vals[key] = v
    base = {k: max(3, round(2 + (v - 90) * 0.35)) for k, v in vals.items()}
    growth = {k: round(max(0.4, base[k] * 0.21), 2) for k in base}
    return {'base': base, 'growth': growth}


def _passive(spell_id, text, name, icon):
    stat, desc = auto_spells.certificate(text)
    return {'id': 'c%d' % spell_id, 'eden': spell_id, 'name': name, 'stat': stat, 'max': 1, 'desc': desc, 'icon': icon}


def build(ctx):
    """ctx : crow (c_class par n°), cspell, tspell, export_icon(code[, folder, dir]), motion(id->anim),
    fx_ok(code)->bool, classes (classes déjà construites, modifiées en place), common_passives."""
    crows, cspell, tspell = ctx['crow'], ctx['cspell'], ctx['tspell']
    classes = ctx['classes']
    by_eden = {int(c['class_id']): cid for cid, c in classes.items()}
    by_eden.update({m['eden']: k for k, m in CLASS_META.items()})
    # les classes parentes d'abord (les ascensions héritent de leurs sorts)
    order = sorted(CLASS_META, key=lambda k: (crows[CLASS_META[k]['eden']][2] != str(CLASS_META[k]['eden']), CLASS_META[k]['eden']))
    novice = {}
    for fam, base in FAMILY_BASE.items():
        novice[fam] = [dict(s) for s in classes[base]['skills'] if 50011 <= int(s['id']) <= 50035]
    dup_icons = {}
    for k in CLASS_META:
        code = crows[CLASS_META[k]['eden']][3]
        dup_icons[code] = dup_icons.get(code, 0) + 1
    for key in order:
        meta = CLASS_META[key]
        row = crows[meta['eden']]
        family = int(row[11]) if row[11].isdigit() else 1
        parent_num = int(row[2]) if row[2].isdigit() else meta['eden']
        parent = by_eden.get(parent_num, key) if parent_num != meta['eden'] else key
        tier = 'orange' if parent != key else 'green'
        wt = meta['weapon_type']
        own = []
        for s in row[34:49]:
            if not s or s not in cspell:
                continue
            sid = int(s)
            r = cspell[s]
            text = auto_spells.clean_desc(tspell[sid][1])
            sk = auto_spells.convert(sid, r, text, SPELL_FR.get(sid, tspell[sid][0]))
            sk['icon'] = ctx['export_icon'](r[1])
            sk['anim'] = ctx['motion'](r[3])
            cast = ('s' + r[5][1:]).lower() if r[5].upper().startswith('E') else ''
            hit = r[10].lower()
            sk['fx'] = {'cast': cast if ctx['fx_ok'](cast) else '', 'hit': hit if ctx['fx_ok'](hit) else ''}
            sk['eden_name'] = tspell[sid][0]
            sk['eden_level'] = int(float(r[22])) if r[22].replace('.', '').isdigit() else 0
            own.append(sk)
        # sorts partagés
        if tier == 'green':
            shared = [dict(s, shared=True) for s in novice.get(family, [])]
        else:
            shared = [dict(s, shared=True) for s in classes[parent]['skills'] if not s.get('shared')]
        # certificats : les siens + celui partagé avec la classe parente (marqué « commun »)
        passives = []
        parent_certs = set(crows[parent_num][30:32]) if tier == 'orange' else set()
        for s in row[30:32]:
            if not s or not s.isdigit():
                continue
            sid = int(s)
            p = _passive(sid, auto_spells.clean_desc(tspell[sid][1]), SPELL_FR.get(sid, tspell[sid][0]),
                         ctx['export_icon'](cspell[s][1]) if s in cspell else '')
            if s in parent_certs:
                p['shared'] = True
            passives.append(p)
        passives += ctx['common_passives']
        wdef = NEW_WEAPON_TYPES.get(wt) or ctx['weapon_types'][wt]
        dmg_type = 'mag' if sum(1 for s in own if s['dmg_type'] == 'mag') > len(own) / 2 else 'phys'
        armor = int(row[12]) if row[12].isdigit() else 2
        base = dict(ARMOR_BASE.get(armor, ARMOR_BASE[2]))
        try:
            base['hp'] = round(base['hp'] * float(row[15]) / 105.0, 2)
        except (ValueError, IndexError):
            pass
        base['atk'] = 0.6 if dmg_type == 'mag' else 1.0
        base['matk'] = 1.1 if dmg_type == 'mag' else 0.5
        name = ctx['tclass'][meta['eden']][0]
        entry = {
            'class_id': meta['eden'], 'body': 'm', 'tier': tier, 'family': family, 'parent': parent,
            'appearance': {'outfit': '#L%d' % meta['outfit'], 'skin': 'SL%d' % meta['outfit'], 'hair': '#L%d' % meta['hair'],
                           'face': '#LFACE', 'dye': meta['dye']},
            'weapons': list(wdef['codes']),
            'anims': {'idle': 'stand01', 'battle': wdef['battle'], 'run': 'move02',
                      'attacks': sorted({c['anim'] for c in NEW_COMBOS.get(wt, []) if c['anim'].startswith('attack')}) or ['attack01'],
                      'hurt': 'hurt13', 'death': 'death01', 'jump': 'jump01', 'dodge': 'jump02'},
            'combo': NEW_COMBOS.get(wt) or ctx['combos'].get(wdef.get('class', ''), []),
            'start_skills': 3, 'lore_fr': meta['lore_fr'], 'weapon_name': wdef['name'], 'base': base,
            'attributes': _attributes(row), 'weapon_type': wt, 'dmg_type': dmg_type,
            'name': name, 'name_fr': meta['name_fr'], 'lore': meta['lore_fr'],
            # icône de classe d'Eden ; les ascensions partagent souvent une icône « ? » générique
            # (J069, J070…) : on prend alors l'icône de leur premier sort
            'icon': ctx['export_icon'](row[3], 'uiicon', 'assets/ui/classes') if dup_icons.get(row[3], 0) <= 1 or not own
            else own[0]['icon'],
            'skills': shared + own, 'passives': passives,
        }
        if wdef.get('attack_range'):
            entry['attack_range'] = wdef['attack_range']
        # déblocage : maîtrise de la classe de base de la famille (verte, d'après le niveau
        # de classe exigé par Eden) ou de la classe parente (orange)
        if tier == 'orange':
            entry['unlock'] = {'cls': parent, 'level': 8}
        else:
            need = int(row[9]) if row[9].isdigit() else 10
            entry['unlock'] = {'cls': FAMILY_BASE.get(family, 'warrior'), 'level': min(max(round(need / 5) + 1, 2), 8)}
        classes[key] = entry
    return classes


def weapon_type_entries():
    """Nouveaux types d'arme pour weapon_types.json (combo inclus)."""
    out = {}
    for wt, w in NEW_WEAPON_TYPES.items():
        e = dict(w)
        e['combo'] = NEW_COMBOS[wt]
        e['class'] = next((k for k, m in CLASS_META.items() if m['weapon_type'] == wt and
                           m['eden'] in (6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 59)), next(
            k for k, m in CLASS_META.items() if m['weapon_type'] == wt))
        out[wt] = e
    return out


def outfit_parts(classes, out_dir):
    """Pièces de modèle à exporter : {(code, dye_json): nom de fichier}."""
    parts = {}
    for cid, c in classes.items():
        ap = c['appearance']
        o = ap['outfit'].lstrip('#')
        h = ap['hair'].lstrip('#')
        parts[cid] = {'outfit': (o, ap['outfit'], ap['skin'], ap['dye'].get('outfit')),
                      'hair': (h, ap['hair'], ap['dye'].get('hair'))}
    return parts


def part_path(kind, code, dye):
    import hashlib
    import json
    h = hashlib.md5(json.dumps(dye, sort_keys=True).encode()).hexdigest()[:6] if dye else 'base'
    sub = 'outfits' if kind == 'outfit' else 'hairs'
    return 'res://assets/player/%s/%s_%s.glb' % (sub, code.lower(), h), os.path.join('assets', 'player', sub, '%s_%s.glb' % (code.lower(), h))
