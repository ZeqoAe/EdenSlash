"""Profils de stats des 60 classes (lot E3 de la nuit du 15/10) -> game/data/class_profiles.json.

Règle (reproductible, sans le client d'Eden) :
- type de dégâts : celui de la classe, corrigé comme `GameData._balance_damage_types` (une classe dont la
  majorité des sorts d'attaque sont magiques est magique) ;
- classe de garde : défense de base 6 (les classes « tank ») -> Rempart (physique) ou Croisé (magique) ;
- sinon l'attribut de croissance le plus fort parmi ceux qui comptent pour ses dégâts :
  physique -> Force / Agilité / Chance (Puissance, Vivacité, Précision), magique -> Intelligence / Sagesse
  (Arcane, Esprit). Égalité : l'ordre de la liste.
Poids : 1 = neutre (la note d'un objet sans profil reste la même), 0,3 = presque inutile, 1,5 = recherché.
Type d'armure préféré : un petit bonus de note pour une pièce de ce type (tissu, cuir, plates).

python tools/gen_class_profiles.py          (réécrit le fichier et affiche le tableau)
"""
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ROOT / "game" / "data" / "classes.json"
OUT = ROOT / "game" / "data" / "class_profiles.json"

PHYS = {"patk": 1.4, "matk": 0.3, "str": 1.0, "agi": 1.0, "lck": 1.0, "int": 0.3, "wis": 0.5,
        "crit": 1.2, "mcrit": 0.3, "crit_dmg": 1.1, "atk_speed": 1.2, "cast_speed": 0.6, "heal_pct": 0.5,
        "hp": 1.0, "def": 0.9, "def_pct": 0.9, "hp_pct": 1.0, "eva": 1.0, "parry": 0.9, "dmg_pct": 1.2,
        "move_speed": 0.9, "cdr": 1.0}
MAG = {"patk": 0.3, "matk": 1.4, "str": 0.5, "agi": 0.7, "lck": 0.9, "int": 1.2, "wis": 0.9,
       "crit": 0.3, "mcrit": 1.2, "crit_dmg": 1.1, "atk_speed": 0.6, "cast_speed": 1.2, "heal_pct": 0.8,
       "hp": 1.0, "def": 0.9, "def_pct": 0.9, "hp_pct": 1.0, "eva": 0.9, "parry": 0.6, "dmg_pct": 1.2,
       "move_speed": 0.9, "cdr": 1.2}
GUARD = {"hp": 1.3, "def": 1.4, "def_pct": 1.3, "hp_pct": 1.3}

# id -> (nom, dégâts, attribut principal, armure, retouches des poids, description courte)
PROFILES = {
    "puissance": ("Puissance", "phys", "str", "cuir", {"str": 1.5, "patk": 1.5}, "Mêlée physique : force et attaque"),
    "vivacite": ("Vivacité", "phys", "agi", "cuir", {"agi": 1.5, "atk_speed": 1.4, "eva": 1.2}, "Physique rapide : agilité, vitesse d'attaque"),
    "precision": ("Précision", "phys", "lck", "cuir", {"lck": 1.5, "crit": 1.4, "crit_dmg": 1.3}, "Physique de précision : chance et critiques"),
    "rempart": ("Rempart", "phys", "str", "plates", dict(GUARD, str=1.2, parry=1.2), "Garde physique : PV, défense, force"),
    "croise": ("Croisé", "mag", "int", "plates", dict(GUARD, int=1.3), "Garde magique : PV, défense, attaque magique"),
    "arcane": ("Arcane", "mag", "int", "tissu", {"int": 1.5, "matk": 1.5}, "Magie offensive : intelligence et attaque magique"),
    "esprit": ("Esprit", "mag", "wis", "tissu", {"wis": 1.5, "int": 1.0, "heal_pct": 1.3, "cdr": 1.3}, "Magie de soutien : sagesse, soins, recharge"),
}
PHYS_FOCUS = {"str": "puissance", "agi": "vivacite", "lck": "precision"}
MAG_FOCUS = {"int": "arcane", "wis": "esprit"}


def damage_type(c):
    """Type de dégâts après la correction du jeu (GameData._balance_damage_types)."""
    mag = phys = 0
    for s in c.get("skills", []):
        if s.get("shared") or s.get("kind", "") in ("buff", "heal"):
            continue
        if s.get("dmg_type", "phys") == "mag":
            mag += 1
        else:
            phys += 1
    if mag > phys:
        return "mag"
    return c.get("dmg_type", "phys")


def profile_of(c):
    dmg = damage_type(c)
    if float(c.get("base", {}).get("def", 0.0)) >= 6.0:
        return "rempart" if dmg == "phys" else "croise"
    growth = c.get("attributes", {}).get("growth", {})
    table = PHYS_FOCUS if dmg == "phys" else MAG_FOCUS
    best = max(table, key=lambda a: (float(growth.get(a, 0.0)), -list(table).index(a)))
    return table[best]


def main():
    classes = json.loads(CLASSES.read_text(encoding="utf-8"))
    out = {"_doc": "Généré par tools/gen_class_profiles.py (ne pas modifier à la main) : profil de stats de chaque classe (lot E3).",
           "profiles": {}, "classes": {}}
    for pid, (name, dmg, focus, armor, tweak, desc) in PROFILES.items():
        w = dict(PHYS if dmg == "phys" else MAG)
        w.update(tweak)
        out["profiles"][pid] = {"name": name, "dmg": dmg, "focus": focus, "armor": armor, "desc": desc,
                                "weights": {k: w[k] for k in sorted(w)}}
    for cid, c in classes.items():
        out["classes"][cid] = profile_of(c)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    groups = collections.defaultdict(list)
    for cid, pid in out["classes"].items():
        groups[pid].append(cid)
    for pid in PROFILES:
        print(f"{PROFILES[pid][0]:10} {len(groups[pid]):2}  {', '.join(groups[pid])}")
    print(f"{len(out['classes'])} classes, {len(PROFILES)} profils -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
