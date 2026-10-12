"""Refonte des trophées (data/eden_catalog.json), sans le client d'Eden.

Pour chaque trophée d'Eden :
- garde le nom, l'icône, le niveau d'Eden et la rareté ;
- retire les stats fixes (« r » vide) et l'ancien passif ; le texte d'Eden reste dans
  « eden_text » (fiche de l'archive) ;
- écrit « trophy » : la famille de buff sous condition inspirée de son texte d'Eden
  (agi, crit, double, speed…). Les effets réels sont dans game/scripts/core/trophies.gd ;
- marque « nopool » les objets qui n'ont rien à faire dans le butin (familiers, objets de test,
  bonus de sorts d'autres classes) : ils restent dans l'archive.

Relançable : repart du texte d'Eden conservé.
python tools/rework_trophies.py
"""
import collections
import json
import re
import zlib
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "game" / "data" / "eden_catalog.json"

# (motif dans le texte de l'effet, famille) : le premier qui correspond gagne
RULES = [
    (r"double hit|triple hit|combo chance|additional hit", "double"),
    (r"agi\w*[^.\n]{0,14}\bint|\bint\w*[^.\n]{0,14}agi", "agi_int"),
    (r"all stats|all attributes|all attribute", "all"),
    (r"agi(lity)? (and|&) lck|agi(lity)? (and|&) luck", "agi"),
    (r"\bcrit\b(?! hit)|crit rate|crit value|critical", "crit"),
    (r"m-crit", "crit"),
    (r"atk spd|attack speed|cast spd|mana speed|casting speed", "speed"),
    (r"transform the caster|caster transform|p-atk|physical attack|attack power", "str"),
    (r"m-atk|magic attack|magic burst|explosion val", "int_wis"),
    (r"summon", "might"),
    (r"stun|transform the target|turn the target|silence|skill casts to fail|failure rate|disarm", "stun"),
    (r"lightning|holy (light )?d(a)?m(a)?g|light damage", "storm"),
    (r"fire d(a)?m(a)?g|fire damage|burn", "fire"),
    (r"ice d(a)?m(a)?g|frost|chill|freez", "frost"),
    (r"nature|dark d(a)?m(a)?g|poison|dot", "venom"),
    (r"remove (a |one |1 |2 )?(random )?debuff|cleanse", "resolve"),
    (r"\beva\b|evasion|move spd|move speed|dodge", "evade"),
    (r"recover|restore|hp per second|healing|heal", "regen"),
    (r"\bdef\b|defense|damage taken|resistance|block|parry", "guard"),
    (r"\bagi\b|agility", "agi"),
    (r"\bstr\b|strength", "str"),
    (r"\bint\b|\bwis\b|wisdom|intelligence|spiritual|mental|mp", "int_wis"),
    (r"\blck\b|luck", "luck"),
    (r"d(a)?m(a)?g dealt|damage done|extra", "might"),
]
# sans texte : d'après les anciennes stats fixes
STAT_KIND = {"agi": "agi", "str": "str", "int": "int_wis", "wis": "int_wis", "lck": "luck",
             "crit": "crit", "mcrit": "crit", "atk_speed": "speed", "def": "guard", "def_pct": "guard",
             "hp": "regen", "move_speed": "evade", "patk": "str", "matk": "int_wis"}
FALLBACK = ["agi", "crit", "double", "speed", "str", "int_wis", "guard", "regen", "storm", "might"]


def kind_of(e):
    k = _kind(e)
    r = e.get("r_old", {})
    text = e.get("eden_text", "").lower()
    has_agi = "agi" in r or re.search(r"\bagi\b|agility", text)
    has_int = "int" in r or re.search(r"\bint\b|intelligence", text)
    # Agilité et Intelligence dans le trophée d'Eden : buff Agi + Int
    if k in ("agi", "int_wis", "all", "guard", "regen") and has_agi and has_int:
        return "agi_int"
    # simples résistances élémentaires ou mana rendue : le buff suit plutôt la stat d'Eden
    m = re.search(r"chance(.*)", text, re.S)
    effect = m.group(1) if m else ""
    weak = (k == "guard" and re.search(r"resistance", effect) and not re.search(r"\bdef\b|defense|damage taken|block", effect)) \
        or (k == "regen" and re.search(r"\bmp\b", effect) and not re.search(r"\bhp\b", effect))
    if weak and r:
        best = max(r, key=lambda s: r[s])
        if STAT_KIND.get(best, "regen") not in ("guard", "regen"):
            return STAT_KIND[best]
    if k == "regen" and re.search(r"\bmp\b", effect) and not re.search(r"\bhp\b", effect):
        return "int_wis"
    return k


def _kind(e):
    text = e.get("eden_text", "").lower()
    # l'effet déclenché d'abord (après « chance »), puis tout le texte
    m = re.search(r"chance(.*)", text, re.S)
    for part in ([m.group(1)] if m else []) + [text]:
        for pat, kind in RULES:
            if re.search(pat, part):
                return kind
    r = e.get("r_old", {})
    if r:
        best = max(r, key=lambda s: r[s])
        if best in STAT_KIND:
            return STAT_KIND[best]
    return FALLBACK[zlib.crc32(e["name"].encode()) % len(FALLBACK)]


def nopool_reason(e):
    n = e["name"]
    if "Elf Sculpture" in n:
        return "familier (statue d'elfe)"
    if n in ("Special Trophy", "Wisdom Bracelet", "Golden Medal") or re.search(r"\btest", n, re.I):
        return "objet de test"
    if n.startswith("Holy Bracelet - "):
        return "bonus de sort d'une autre classe"
    if not e.get("eden_text") and not e.get("src") and not e.get("r_old"):
        return "bonus de sort d'une autre classe"
    return ""


def main():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    kinds = collections.Counter()
    out = []
    for e in data["items"]:
        if e.get("slot") != "trophy":
            continue
        if "eden_text" not in e:
            e["eden_text"] = (e.get("passive") or {}).get("eden", "")
            e["r_old"] = e.get("r", {})
        e.pop("passive", None)
        e["r"] = {}
        e["trophy"] = kind_of(e)
        reason = nopool_reason(e)
        if reason:
            e["nopool"] = reason
            out.append((e["id"], e["name"], reason))
        else:
            e.pop("nopool", None)
            kinds[e["trophy"]] += 1
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("familles :", dict(kinds.most_common()))
    print("retirés du butin (%d) :" % len(out))
    for x in out:
        print("  ", *x)


if __name__ == "__main__":
    main()
