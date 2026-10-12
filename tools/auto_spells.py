"""Conversion automatique des sorts d'Eden (c_spell + texte anglais de t_spell) en
compétences du hack and slash, avec une description française générée.

Champs de c_spell utilisés :
  1 icône, 3 animation (motion.ini), 5 effet d'incantation (E…), 10 effet d'impact,
  22 niveau requis, 32 recharge (dixièmes de s), 35 puissance (% de l'attaque), 18 cible (1 ennemi, 2 soi / groupe, 4 allié, 5 zone alliée), 20 forme (0 autour de soi,
  1 soi, 3 groupe autour de soi, 4 cible, 5 zone au sol), 28 portée (m),
  29 rayon de zone (m), 33 élément (1 physique, 4 feu, 5 glace, 6 foudre, 7 nature,
  8 sacré, 9 ténèbres, 10 aucun).
Les distances d'Eden (mètres du MMO) sont réduites pour l'arène du hack and slash.
"""
import re

ELEMENT_PROJECTILE = {1: 'arrow', 4: 'fire', 5: 'ice', 6: 'lightning', 7: 'nature', 8: 'holy', 9: 'dark'}
ELEMENT_FR = {4: 'de feu', 5: 'de glace', 6: 'de foudre', 7: 'de nature', 8: 'sacrés', 9: 'des ténèbres'}
STATUS_FR = {
    'stun': 'Renversé', 'freeze': 'Gelé', 'chill': 'Ralenti', 'root': 'Immobilisé', 'sleep': 'Endormi',
    'fear': 'Terreur', 'disarm': 'Désarmé', 'poison': 'Poison', 'bleed': 'Saignement', 'burn': 'Brûlure',
    'purgatory': 'Vulnérable (+20 % de dégâts subis)', 'shock': 'Électrocuté (+15 % de dégâts subis)',
    'scar': 'Affaibli (-30 % de dégâts infligés)',
    'barrier': 'Barrière (-40 % de dégâts subis)', 'titan': 'Mur du titan (-50 % de dégâts subis, -60 % de vitesse)',
    'fury': 'Fureur (+25 % de dégâts)', 'might': 'Puissance (+30 % de force)', 'swift': 'Célérité (+30 % d\'agilité)',
    'grace': 'Grâce (+30 % d\'intelligence et de sagesse)', 'frenzy': 'Frénésie (+30 % de vitesse d\'attaque)',
    'keen': 'Œil acéré (+25 % de critique)', 'haste': 'Hâte (+30 % de vitesse)', 'evasion': 'Évasion (40 % d\'esquive)',
    'invisible': 'Invisible', 'regen': 'Régénération (3 % des PV par seconde)', 'vitality': 'Vitalité (+15 % de PV max)',
    'survival': 'Instinct de survie (+20 % de PV max)', 'thorns': 'Épines (renvoie 30 % des dégâts au corps à corps)',
    'resolve': 'Résolution (insensible au renversement)',
}
DEBUFFS = {'stun', 'freeze', 'chill', 'root', 'sleep', 'fear', 'disarm', 'poison', 'bleed', 'burn',
           'purgatory', 'shock', 'scar'}


def clean_desc(s):
    s = s.replace('\r\n', ' ').replace('\n', ' ')
    m = re.search(r'\$15\$(.*?)(\$12\$|$)', s)
    s = m.group(1) if m else s
    s = re.sub(r'#B\d+\$(\d+)#', r'\1', s)
    s = re.sub(r'\$\d+\$', '', s)
    return re.sub(r'\s+', ' ', s).strip()


def _num(row, i):
    try:
        return float(row[i]) if i < len(row) and row[i] not in ('', None) else 0.0
    except ValueError:
        return 0.0


def _dur(text, key_pos=None, default=6.0):
    """Durée (s) la plus proche d'un mot-clé, sinon la première du texte."""
    durs = [(m.start(), float(m.group(1))) for m in re.finditer(r'(\d+(?:\.\d+)?)\s*(?:sec|second)', text)]
    mins = [(m.start(), 15.0) for m in re.finditer(r'\d+\s*minute', text)]
    durs += mins
    if not durs:
        return default
    if key_pos is None:
        return durs[0][1]
    after = [d for d in durs if d[0] >= key_pos]
    return (after[0] if after else min(durs, key=lambda d: abs(d[0] - key_pos)))[1]


def _hits(text):
    t = text.lower()
    if 'quadruple hit' in t or '4 hits' in t:
        return 4
    if 'triple hit' in t or '3 hits' in t or 'three times' in t:
        return 3
    if 'double hit' in t or '2 hits' in t or 'twice' in t:
        return 2
    return 1


ENEMY_STATUS_RULES = [
    (r'knock ?down|knocked down|stun|daze|dizz', 'stun', 2.0),
    (r'frozen|freez', 'freeze', 2.5),
    (r'immobiliz|cannot move|unable to move|root', 'root', 3.0),
    (r'sleep|hypnoti|slumber', 'sleep', 4.0),
    (r'fear|frighten|terrif', 'fear', 3.0),
    (r'silence|preventing them from casting|cannot cast|disarm', 'disarm', 3.0),
    (r'move spd -|move spd by -|reduc\w* (?:enemy\'s |their |its )?move spd|slow', 'chill', 5.0),
    (r'poison|toxic|venom', 'poison', 8.0),
    (r'bleed|blood loss', 'bleed', 8.0),
    (r'fire (?:dmg|damage) per second|burn', 'burn', 6.0),
    (r'lightning (?:dmg|damage) per second', 'shock', 6.0),
    (r'(?:dark|nature|ice|holy) (?:dmg|damage) per second', 'poison', 8.0),
    (r'\d+ (?:physical )?(?:dmg|damage) per second', 'bleed', 8.0),
    (r'def -|def by -|decreas\w* (?:their |its |the target\'s )?def|resistances? -|dmg taken \+|damage received \+|damage taken \+'
     r'|received \+|dmg received \+', 'purgatory', 8.0),
    (r'p-atk -|p-atk by -|m-atk -|dmg dealt -|damage dealt by|reduc\w* (?:its |their )?(?:dmg|damage) dealt|atk spd & cast spd -'
     r"|atk spd -|reduc\w* (?:the target's |its |their )?atk", 'scar', 6.0),
]
SELF_STATUS_RULES = [
    (r'immobile|heavy wall', 'titan', 6.0),
    (r'invisib|stealth|hidden|conceal', 'invisible', 6.0),
    (r'reflect', 'thorns', 10.0),
    (r'immun', 'resolve', 8.0),
    (r'damage taken|dmg taken|dmg received|damage received|reduc\w* (?:all )?(?:the )?damage|def \+|block', 'barrier', 8.0),
    (r'hp per second|hp each second|hp every|restores \+?\d+% hp|recover\w* [\d+]', 'regen', 8.0),
    (r'max hp', 'vitality', 15.0),
    (r'atk spd|cast spd|attack speed', 'frenzy', 10.0),
    (r'crit', 'keen', 10.0),
    (r'move spd|movement speed|running speed', 'haste', 8.0),
    (r'eva \+|dodge|evasion|eva by', 'evasion', 6.0),
    (r'\bstr\b|p-atk \+|(?<!-)\batk \+|(?<!-)\batk by', 'might', 12.0),
    (r'\bint\b|\bwis\b|m-atk \+|magic power', 'grace', 12.0),
    (r'\bagi\b|\blck\b', 'swift', 12.0),
    (r'dmg dealt|damage dealt|skill dmg|\bdmg \+', 'fury', 8.0),
]


def enemy_statuses(text):
    t = text.lower()
    out = {}
    for pat, st, cap in ENEMY_STATUS_RULES:
        m = re.search(pat, t)
        if m and st not in out:
            d = _dur(t, m.start())
            out[st] = round(min(max(d * 0.6, 1.0), cap), 1)
    # « renversé » et « gelé » suffisent : pas de ralenti en plus
    if 'stun' in out or 'freeze' in out:
        out.pop('root', None)
    if 'sleep' in out:
        out.pop('stun', None)
    return dict(list(out.items())[:2])


def self_statuses(text):
    t = text.lower()
    out = {}
    for pat, st, cap in SELF_STATUS_RULES:
        m = re.search(pat, t)
        if m and st not in out:
            d = _dur(t, m.start())
            out[st] = round(min(max(d * 0.5, 5.0), cap), 1)
    return dict(list(out.items())[:2])


def mechanics(row, text):
    """Lecture brute du sort."""
    t = text.lower()
    target, shape = row[18].strip(), row[20].strip()
    rng, aoe = _num(row, 28), _num(row, 29)
    element = int(_num(row, 33))
    damaging = bool(re.search(r'\b(?:dmg|damage)\b', t)) and not re.search(r'^(?:heals?|recovers?|restores?)', t) \
        and bool(re.search(r'atk \+#|deal|caus|inflict\w* .*damage|damage to', t)) and (target == '1' or 'atk +#' in t)
    heal = bool(re.search(r'\bheals?\b|recover\w* \+#30#|\+#30# hp|revive|removes? \d* ?debuff', t)) and target in ('4', '5', '2', '7')
    mag = 'm-atk +#' in t or ('m-atk' in t and 'p-atk' not in t) or (element in (4, 5, 6, 7, 8, 9) and 'p-atk' not in t)
    return {
        'target': target, 'shape': shape, 'range': rng, 'aoe': aoe, 'element': element,
        'cooldown': _num(row, 32) / 10.0, 'power': _num(row, 35), 'level': _num(row, 22), 'damaging': damaging, 'heal': heal, 'mag': mag,
        'hits': _hits(t), 'fan': 'fan' in t or 'cone' in t,
        'mobility': bool(re.search(r'advanc\w* (?:the caster )?\d+ meters|jump back|leap|charg\w* (?:at|towards|to)|rush'
                                   r'|advancing towards|teleport|dash|move behind', t)),
        'pull': 'pull' in t or 'gather' in t,
        'text': text,
    }


def _cooldown(cd, kind):
    if kind in ('buff', 'heal', 'blink'):
        return round(min(max(5.0 + cd, 12.0), 30.0), 1)
    return round(min(max(2.0 + cd * 0.5, 3.5), 14.0), 1)


def _pct(v):
    return int(round(v * 100))


def _fmt_s(v):
    return ('%g' % v).replace('.', ',')


def _status_text(sts):
    return ', '.join('%s (%s s)' % (STATUS_FR.get(k, k), _fmt_s(v)) for k, v in sts.items())


def convert(spell_id, row, text, name_fr):
    """Compétence du jeu (dict) pour le sort d'Eden [spell_id]."""
    m = mechanics(row, text)
    t = text.lower()
    sk = {'id': spell_id, 'eden_desc': text}
    rng_m = min(max(m['range'] * 0.35, 3.0), 14.0) if m['range'] else 0.0
    rad = min(max(m['aoe'] * 0.3, 2.5), 8.0) if m['aoe'] else 0.0
    melee = m['range'] <= 8.0
    elem = ELEMENT_FR.get(m['element'], '')
    dmg_word = ('dégâts magiques ' + elem).strip() if m['mag'] else ('dégâts ' + elem).strip()
    debuffs = enemy_statuses(t)
    if m['heal'] and not m['damaging']:
        sk.update({'kind': 'heal', 'mult': 0.0, 'radius': max(rad, 4.0), 'arc': 360,
                   'heal': 0.25 if 'all' in t or m['aoe'] else 0.3})
        buffs = {k: v for k, v in self_statuses(t.split('hp', 1)[-1] if 'hp' in t else '').items()
                 if k not in ('vitality',)}
        if 'debuff' in t or 'cleans' in t or 'remov' in t:
            sk['cleanse'] = True
        if 'revive' in t or 'ressurect' in t or 'resurrect' in t:
            sk['buff'] = {'angel': 30.0}
            desc = "Bénit le héros : s'il tombe dans les 30 s, il se relève avec 30 %% des PV. Rend aussi %d %% des PV max." % _pct(sk['heal'])
        else:
            if buffs:
                sk['buff'] = buffs
            desc = 'Soin : rend %d %% des PV max%s%s.' % (
                _pct(sk['heal']), ' et dissipe un effet néfaste' if sk.get('cleanse') else '',
                (' ; ' + _status_text(buffs)) if buffs else '')
    elif not m['damaging'] and m['target'] in ('2', '4', '7', '增益', '5', '3', '6') or (m['shape'] in ('1', '3') and not m['damaging']):
        buffs = self_statuses(t)
        aura = re.search(r'(?:dmg|damage) to (?:all )?(?:nearby )?(?:enemies|hostile|targets)|enemies within \d+'
                         r'|missile|bullet|bombard|explo', t) and re.search(r'\b(?:dmg|damage)\b', t)
        if aura:
            # renforcement qui frappe aussi autour du lanceur (missiles, aura, explosion)
            cd = _cooldown(m['cooldown'], 'spin')
            sk.update({'kind': 'spin', 'mult': round(0.75 * (0.7 + cd * 0.03), 2), 'hits': 2, 'radius': max(rad, 4.5),
                       'arc': 360, 'cooldown': cd})
            if debuffs:
                sk['applies'] = debuffs
            if buffs:
                sk['buff'] = dict(list(buffs.items())[:1])
            desc = 'Déchaînement autour de toi (%s m) : 2 coups de %d %% de %s%s%s.' % (
                _fmt_s(sk['radius']), _pct(sk['mult']), dmg_word, (' et ' + _status_text(debuffs)) if debuffs else '',
                ('. Te donne ' + _status_text(sk['buff'])) if sk.get('buff') else '')
        elif m['mobility'] and re.search(r'advanc|jump|leap|teleport|dash|move', t):
            back = 'back' in t
            sk.update({'kind': 'blink', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'range': 9.0 if not back else 7.0})
            if back:
                sk['move_dir'] = 'back'
            if buffs:
                sk['buff'] = buffs
            desc = '%s (%s m)%s.' % ('Bond en arrière' if back else 'Bond éclair vers la cible', _fmt_s(sk['range']),
                                     (' puis ' + _status_text(buffs)) if buffs else '')
        else:
            if not buffs:
                buffs = {'fury': 8.0}
            sk.update({'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'buff': buffs})
            desc = 'Renforcement : ' + _status_text(buffs) + '.'
    elif not m['damaging']:
        # sort de contrôle sans dégâts : zone autour de soi ou au sol
        if not debuffs:
            debuffs = {'purgatory': 6.0}
        if m['shape'] == '5' or (m['shape'] == '4' and not melee):
            sk.update({'kind': 'ground', 'mult': 0.3, 'radius': max(rad, 4.0), 'arc': 360, 'range': max(rng_m, 8.0)})
            desc = 'Zone au sol (%s m de rayon) : %d %% de %s et %s.' % (
                _fmt_s(sk['radius']), _pct(sk['mult']), dmg_word, _status_text(debuffs))
        else:
            sk.update({'kind': 'spin', 'mult': 0.3, 'radius': max(rad, 4.5), 'arc': 360})
            desc = 'Onde autour de toi (%s m) : %d %% de %s et %s.' % (
                _fmt_s(sk['radius']), _pct(sk['mult']), dmg_word, _status_text(debuffs))
        if 'sleep' in debuffs:
            sk['mult'] = 0.0  # un coup réveillerait les cibles
            desc = desc.replace('30 % de ' + dmg_word + ' et ', '')
        sk['applies'] = debuffs
    else:
        hits = m['hits']
        if m['shape'] == '5':
            kind = 'ground'
        elif m['shape'] == '0' or (m['shape'] == '3'):
            kind = 'spin'
        elif m['fan']:
            kind = 'fan'
        elif m['mobility']:
            kind = 'dash'
        elif not melee and m['aoe']:
            kind = 'ground'
        elif not melee:
            kind = 'bolt'
        elif m['aoe']:
            kind = 'cone'
        elif hits >= 2:
            kind = 'flurry'
        else:
            kind = 'cone'
        cd = _cooldown(m['cooldown'], kind)
        base = {'ground': 1.6, 'spin': 1.4, 'fan': 1.7, 'dash': 1.8, 'bolt': 1.9, 'cone': 2.0, 'flurry': 0.9}[kind]
        power = m['power'] / 120.0 if m['power'] else 1.0
        mult = base * min(max(power, 0.7), 1.6) * (0.7 + cd * 0.03)
        if kind != 'flurry' and hits > 1:
            mult = mult * 1.15 / hits  # plusieurs coups : total un peu plus fort
        sk.update({'kind': kind, 'mult': round(mult, 2), 'cooldown': cd})
        if kind == 'ground':
            sk.update({'radius': max(rad, 4.0), 'arc': 360, 'range': max(rng_m, 8.0)})
            shape = 'Zone au sol (%s m de rayon)' % _fmt_s(sk['radius'])
        elif kind == 'spin':
            sk.update({'radius': max(rad, 4.0), 'arc': 360})
            shape = 'Tout autour de toi (%s m)' % _fmt_s(sk['radius'])
        elif kind == 'fan':
            sk.update({'radius': max(rad, 7.0), 'arc': 90})
            shape = 'Éventail devant toi (%s m)' % _fmt_s(sk['radius'])
        elif kind == 'dash':
            sk.update({'radius': 2.8, 'arc': 120, 'dash': min(max(rng_m, 5.0), 9.0)})
            shape = 'Fonce sur la cible (%s m)' % _fmt_s(sk['dash'])
        elif kind == 'bolt':
            sk.update({'radius': 0.0, 'arc': 0, 'range': max(rng_m, 10.0),
                       'projectile': ELEMENT_PROJECTILE.get(m['element'], 'magic' if m['mag'] else 'arrow')})
            if 'all enemies' in t or 'enemies within' in t:
                sk['pierce'] = 2
            shape = 'Projectile %s' % ('perçant' if sk.get('pierce') else 'sur la cible')
        elif kind == 'flurry':
            sk.update({'radius': 3.4, 'arc': 150})
            shape = 'Rafale de coups devant toi'
        else:
            wide = bool(m['aoe'])
            sk.update({'radius': max(rad, 3.6) if wide else 3.4, 'arc': 140 if wide else 90})
            shape = 'Frappe devant toi' + (' (zone)' if wide else '')
        if hits > 1:
            sk['hits'] = hits
        if debuffs:
            sk['applies'] = debuffs
        if m['pull'] and kind in ('spin', 'ground'):
            sk['pull'] = 3.0
        hits_txt = '%d coups de %d %%' % (hits, _pct(sk['mult'])) if hits > 1 else '%d %%' % _pct(sk['mult'])
        desc = '%s : %s de %s%s.' % (shape, hits_txt, dmg_word, (' et ' + _status_text(debuffs)) if debuffs else '')
        # sorts qui renforcent aussi le lanceur (« Grants … status », « increases your … »)
        if re.search(r'grants? (?:the )?"|increasing your|gain the|for yourself|to yourself|recover \d+% of the damage', t):
            b = self_statuses(t)
            b = {k: v for k, v in b.items() if k not in ('evasion',) or 'eva +' in t}
            if b:
                sk['buff'] = dict(list(b.items())[:1])
                desc += ' Te donne ' + _status_text(sk['buff']) + '.'
        if 'recover' in t and 'damage dealt as hp' in t:
            sk['heal'] = 0.08
    if 'cooldown' not in sk:
        sk['cooldown'] = _cooldown(m['cooldown'], sk['kind'])
    sk.setdefault('radius', 0.0)
    sk.setdefault('arc', 0)
    sk['dmg_type'] = 'mag' if m['mag'] else 'phys'
    sk['name'] = name_fr
    sk['desc'] = desc
    return sk


# --- certificats (passifs d'Eden) -------------------------------------------------------------
CERT_RULES = [
    (r"weapon's p-atk (?:&|and) m-atk \+(\d+)%|atk and (?:magic power|mana) .*?(\d+)%|weapon's m-atk \+(\d+)%"
     r"|magic power is increased by (\d+)%", 'atk_pct', 0.006, 0.2),
    (r'cast(?:ing)? spd \+(\d+)%|casting speed is increased by (\d+)%', 'cast_speed', 0.01, 0.2),
    (r'atk spd (?:& eva )?\+(\d+)%|attack speed (?:and dodge value )?(?:increased by )?(\d+)%', 'atk_speed', 0.008, 0.2),
    (r'm-crit rate \+(\d+)%|m-crit and p-crit by (\d+)%', 'mcrit', 0.006, 0.15),
    (r'(?<!m-)crit rate \+(\d+)%|critical strike value increased by (\d+)', 'crit', 0.006, 0.15),
    (r'crit dmg \+(\d+)%|critical strike damage increased by (\d+)%|m-crit dmg (?:\+|increased by )(\d+)%', 'crit_dmg', 0.01, 0.3),
    (r'move(?:ment)? spd \+(\d+)%|movement speed increased by (\d+)|running speed by (\d+)%', 'move_speed', 0.008, 0.12),
    (r'received [pm]-dmg -(\d+)%|reduces p-dmg taken -(\d+)%|reduce damage taken by (\d+)%', 'def_pct', 0.02, 0.25),
    (r'eva \+(\d+)%|dodge (?:value )?(?:by |increased by )?(\d+)', 'eva', 0.004, 0.1),
    (r'(?:life|blood volume|max hp) by (\d+)%', 'hp_pct', 0.01, 0.2),
    (r'cooldown -(\d+)%', 'cdr', 0.006, 0.15),
    (r'p-atk \+(\d+)%|increase atk by (\d+)', 'atk_pct', 0.01, 0.15),
    (r'double hit rate \+(\d+)%', 'atk_speed', 0.025, 0.1),
    (r'acc \+(\d+)%', 'dmg_pct', 0.003, 0.1),
    (r'parry value increased by (\d+)%', 'parry', 0.003, 0.12),
    (r'elemental resistances|total resistance|resistance to', 'def_pct', 0.0, 0.05),
    (r'stun the enemy|dmg taken \+', 'dmg_pct', 0.0, 0.05),
    (r'g-healing \+(\d+)%', 'heal_pct', 0.02, 0.2),
]
STAT_FR = {
    'atk_pct': "d'attaque", 'cast_speed': "de vitesse d'incantation", 'atk_speed': "de vitesse d'attaque",
    'mcrit': 'de critique magique', 'crit': 'de critique', 'crit_dmg': 'de dégâts critiques', 'move_speed': 'de vitesse',
    'def_pct': 'de défense', 'eva': "d'esquive", 'hp_pct': 'de PV max', 'cdr': 'de réduction des recharges',
    'dmg_pct': 'de dégâts', 'parry': 'de parade', 'heal_pct': 'de soins',
}


def certificate(text):
    """Statistiques d'un certificat d'Eden (dict stat -> valeur) et description française."""
    t = text.lower()
    stat = {}
    for pat, key, k, cap in CERT_RULES:
        m = re.search(pat, t)
        if not m or key in stat:
            continue
        nums = [g for g in m.groups() if g] if m.groups() else []
        v = float(nums[0]) * k if nums and k else cap
        stat[key] = round(min(max(v, 0.02), cap), 3)
        if len(stat) >= 2:
            break
    if not stat:
        stat = {'hp_pct': 0.05}
    desc = ', '.join('+%d %% %s' % (_pct(v), STAT_FR.get(s, s)) for s, v in stat.items())
    if 'immune' in t or 'never be affected' in t:
        desc += ' ; insensible aux renversements des monstres'
    return stat, desc[0].upper() + desc[1:] + '.'
