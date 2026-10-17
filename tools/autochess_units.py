# -*- coding: utf-8 -*-
"""Génère game/data/autochess_units.json : les 60 unités de L'Échiquier (mode autochess, lot AC-A).

    python tools/autochess_units.py           # écrit le fichier
    python tools/autochess_units.py --check   # compare seulement (code de sortie 1 si le fichier diffère)

Source : game/data/classes.json (nom français, famille, type d'arme, lignée, sorts) et l'annexe A de la spécification
(conception/autochess/ANNEXE_A_UNITES.md) pour le coût, le sort signature et le rôle, recopiés ci-dessous (COST, SIGNATURE, ROLE).
Tout le reste est calculé : traits (famille + arme), portée et place d'après l'arme, allonge et distance préférée
(lues par l'IA scriptée), type du sort signature, mana = recharge du sort × 10 (40 à 140), 2e sort (enchaînement ★3).
Aucun cerveau neuronal dans ce mode (décision du joueur du 16/10) : toutes les unités sont pilotées par l'IA scriptée.
Les valeurs sont provisoires (« provisional » : true) : le lot de mesure AC-J recale coûts et « sim_factor ».
Les tables de traits et de portée doivent rester celles de game/scripts/core/autochess_data.gd (test_ac_data le vérifie).
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLASSES = ROOT / "game" / "data" / "classes.json"
OUT = ROOT / "game" / "data" / "autochess_units.json"

# Famille du code (class_data.family) -> trait de famille (AutochessData.FAMILY_TRAIT).
FAMILY_TRAIT = {1: "rempart", 2: "ombre", 3: "traque", 4: "ferveur", 5: "arcane"}
# Type d'arme -> trait d'arme (AutochessData.WEAPON_TRAIT) : 17 types en 10 traits de 6 unités.
WEAPON_TRAIT = {
    "sword": "escrime", "bow": "tir", "staff": "elementaire", "katana": "tranchant", "dagger": "tranchant",
    "axe": "fracas", "hammer": "fracas", "rapier": "estoc", "spear": "estoc", "cannon": "poudre", "gunscythe": "poudre",
    "scepter": "choeur", "guitar": "choeur", "grimoire": "malediction", "rod": "malediction",
    "greatsword": "impact", "cestus": "impact",
}
# Portée en cases selon l'arme (AutochessData.WEAPON_RANGE) : mêlée 1, lance / faux-fusil 2,
# sceptre / guitare / bâton de métal 3, arc / bâton / canon / grimoire 4.
WEAPON_RANGE = {
    "sword": 1, "katana": 1, "dagger": 1, "axe": 1, "hammer": 1, "rapier": 1, "cestus": 1, "greatsword": 1,
    "spear": 2, "gunscythe": 2, "scepter": 3, "guitar": 3, "rod": 3, "bow": 4, "staff": 4, "cannon": 4, "grimoire": 4,
}
MANA_MIN, MANA_MAX, MANA_PER_CD = 40, 140, 10
# Mana selon le rôle, en % (AutochessData.ROLE_MANA, lot AC-J) : lanceurs plus souvent, tanks moins souvent.
ROLE_MANA = {"mage": 35, "soigneur": 55, "soutien": 60, "tank": 140}
CELL = 2.0  # m (AutochessData.CELL)
MELEE_REACH = 3.2  # m : allonge d'une arme de mêlée (ClassRival._attack_range sans « attack_range »)
# Distance de combat préférée selon le rôle (AutochessData.ROLES[*].distance) : m, ou écart sous l'allonge (négatif).
ROLE_DISTANCE = {"tank": 1.6, "combattant": 1.8, "assassin": 1.6, "tireur": -1.0, "mage": -1.0, "soigneur": -0.5,
                 "soutien": -0.5}
# Kind du sort -> type de sort signature (AutochessData.SPELL_TYPES).
SPELL_TYPE = {"ground": "zone", "spin": "zone", "cone": "zone", "fan": "zone", "flurry": "zone",
              "line": "cible", "bolt": "cible", "heal": "soin", "buff": "renfort", "dash": "deplacement", "blink": "deplacement"}

# Annexe A : coût (palier de boutique) et sort signature (« n° » = rang dans skills, à partir de 1).
COST = {
    "warrior": 1, "knight": 1, "thief": 1, "martial_artist": 1, "hunter": 1, "engineer": 1, "cleric": 1, "bard": 1,
    "magician": 1, "warlock": 1,
    "templar": 2, "dragon_knight": 2, "shielder": 2, "samurai": 2, "blade_dancer": 2, "assassin": 2, "ranger": 2,
    "inquisitor": 2, "trainer": 2, "shaman": 2, "sage": 2, "battlefield_poet": 2, "illusionist": 2, "luminary": 2,
    "conjurer": 2,
    "berserker": 3, "executioner": 3, "dawnbreaker": 3, "rakshasa": 3, "blade_acrobat": 3, "blade_master": 3,
    "mecha_ares": 3, "rifleteer": 3, "devil_hunter": 3, "druid": 3, "adjudicator": 3, "psalmist": 3,
    "arch_elementalist": 3, "demon_tamer": 3, "dark_envoy": 3,
    "glacier_knight": 4, "dragon_soul": 4, "kage": 4, "elegant_dancer": 4, "reaver": 4, "holy_arrow": 4,
    "equilibrian": 4, "life_worshipper": 4, "stormcaster": 4, "light_blade": 4,
    "paladin": 5, "dragon_rider": 5, "asura": 5, "master_fencer": 5, "annihilator": 5, "absolute_arrow": 5,
    "orator": 5, "archimage": 5, "chronologist": 5, "black_blade": 5,
}
SIGNATURE = {
    "warrior": 15, "knight": 8, "thief": 5, "martial_artist": 12, "hunter": 7, "engineer": 12, "cleric": 6, "bard": 8,
    "magician": 14, "warlock": 6, "templar": 13, "dragon_knight": 7, "shielder": 12, "samurai": 12, "blade_dancer": 14,
    "assassin": 12, "ranger": 11, "inquisitor": 8, "trainer": 11, "shaman": 11, "sage": 8, "battlefield_poet": 12,
    "illusionist": 15, "luminary": 12, "conjurer": 17, "berserker": 15, "executioner": 12, "dawnbreaker": 18,
    "rakshasa": 11, "blade_acrobat": 18, "blade_master": 14, "mecha_ares": 18, "rifleteer": 13, "devil_hunter": 15,
    "druid": 14, "adjudicator": 11, "psalmist": 11, "arch_elementalist": 12, "demon_tamer": 18, "dark_envoy": 19,
    "glacier_knight": 18, "dragon_soul": 12, "kage": 13, "elegant_dancer": 13, "reaver": 13, "holy_arrow": 12,
    "equilibrian": 12, "life_worshipper": 11, "stormcaster": 13, "light_blade": 12, "paladin": 16, "dragon_rider": 12,
    "asura": 17, "master_fencer": 17, "annihilator": 18, "absolute_arrow": 14, "orator": 13, "archimage": 12,
    "chronologist": 13, "black_blade": 14,
}
# Annexe A (révision du 16/10) : rôle de l'IA de combat scriptée (SPEC §4.1).
ROLE = {
    "warrior": "tank", "knight": "tank", "thief": "assassin", "martial_artist": "combattant", "hunter": "tireur",
    "engineer": "tireur", "cleric": "soigneur", "bard": "soigneur", "magician": "mage", "warlock": "mage",
    "templar": "tank", "dragon_knight": "tank", "shielder": "tank", "samurai": "combattant",
    "blade_dancer": "combattant", "assassin": "assassin", "ranger": "tireur", "inquisitor": "tireur",
    "trainer": "tireur", "shaman": "soigneur", "sage": "soigneur", "battlefield_poet": "soutien",
    "illusionist": "mage", "luminary": "combattant", "conjurer": "mage", "berserker": "combattant",
    "executioner": "combattant", "dawnbreaker": "combattant", "rakshasa": "combattant",
    "blade_acrobat": "combattant", "blade_master": "combattant", "mecha_ares": "tireur", "rifleteer": "tireur",
    "devil_hunter": "tireur", "druid": "soigneur", "adjudicator": "soigneur", "psalmist": "soutien",
    "arch_elementalist": "mage", "demon_tamer": "mage", "dark_envoy": "mage", "glacier_knight": "tank",
    "dragon_soul": "tank", "kage": "assassin", "elegant_dancer": "combattant", "reaver": "tireur",
    "holy_arrow": "tireur", "equilibrian": "soutien", "life_worshipper": "soigneur", "stormcaster": "mage",
    "light_blade": "combattant", "paladin": "tank", "dragon_rider": "tank", "asura": "combattant",
    "master_fencer": "combattant", "annihilator": "tireur", "absolute_arrow": "tireur", "orator": "soutien",
    "archimage": "soutien", "chronologist": "mage", "black_blade": "combattant",
}
# Kinds de sort qui frappent (les « buff » et « blink » ne servent pas de 2e sort).
STRIKE_KINDS = ("ground", "bolt", "spin", "cone", "fan", "line", "flurry", "dash", "heal")


def place_of(rng: int) -> str:
    return "avant" if rng <= 1 else ("milieu" if rng == 2 else "arriere")


def mana_of(cooldown: float, role: str = "") -> int:
    """Mana max = recharge (arrondie à la seconde) × 10, bornée à 40-140, puis × ROLE_MANA du rôle (en %, arrondi à la
    dizaine, borné à 40-140 ; AutochessData.mana_for, même calcul entier)."""
    m = int(max(MANA_MIN, min(MANA_MAX, math.floor(cooldown + 0.5) * MANA_PER_CD)))
    k = ROLE_MANA.get(role, 100)
    return m if k == 100 else max(MANA_MIN, min(MANA_MAX, (m * k + 500) // 1000 * 10))


def attack_range_m(rng: int) -> float:
    return MELEE_REACH if rng <= 1 else rng * CELL + 0.5


def score(s: dict) -> float:
    """Score de l'annexe A : mult × rayon (les soins comptent leur mult seul, rayon au moins 1)."""
    return float(s.get("mult", 0.0)) * max(float(s.get("radius", 0.0)), 1.0)


def own_skills(cd: dict) -> list:
    return [(i, s) for i, s in enumerate(cd["skills"]) if not s.get("shared")]


def build() -> dict:
    classes = json.loads(CLASSES.read_text(encoding="utf-8"))
    units = {}
    for cid in COST:
        cd = classes[cid]
        idx = SIGNATURE[cid] - 1
        sig = cd["skills"][idx]
        assert not sig.get("shared"), "%s : sort signature partagé" % cid
        rest = sorted([(i, s) for i, s in own_skills(cd) if i != idx and s.get("kind") in STRIKE_KINDS],
                      key=lambda p: (-score(p[1]), p[0]))
        second = rest[0] if rest else None
        wt = cd["weapon_type"]
        rng = WEAPON_RANGE[wt]
        fam = FAMILY_TRAIT[int(cd["family"])]
        role = ROLE[cid]
        reach = attack_range_m(rng)
        pref = ROLE_DISTANCE[role]
        units[cid] = {
            "name": cd["name_fr"],
            "cost": COST[cid],
            "family": int(cd["family"]),
            "traits": [fam, WEAPON_TRAIT[wt]],
            "weapon_type": wt,
            "lineage": "verte" if cd["tier"] == "green" else "ascension",
            "parent": cd.get("parent", cid),
            "range": rng,
            "place": place_of(rng),
            "role": role,
            "attack_range_m": round(reach, 2),
            "preferred_distance_m": round(pref if pref > 0 else max(1.6, reach + pref), 2),
            "skill_id": int(sig["id"]),
            "skill_index": idx,
            "skill_name": sig["name"],
            "skill_kind": sig["kind"],
            "spell_type": SPELL_TYPE[sig["kind"]],
            "mana": mana_of(float(sig.get("cooldown", 0.0)), role),
            "second_skill_id": int(second[1]["id"]) if second else 0,
            "sim_factor": 1.0,
            "provisional": True,
        }
    return units


def main() -> int:
    units = build()
    doc = {
        "_doc": "L'Échiquier (autochess) : 60 unités. Généré par tools/autochess_units.py (ne pas éditer à la main : "
                "changer COST / SIGNATURE dans le script). Valeurs provisoires, recalées par le lot de mesure AC-J.",
        "units": units,
    }
    text = json.dumps(doc, ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("autochess_units.json à jour" if same else "autochess_units.json DIFFÈRE : relancer le script")
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8", newline="\n")
    from collections import Counter
    print("%d unités écrites dans %s" % (len(units), OUT))
    print("coûts", sorted(Counter(u["cost"] for u in units.values()).items()))
    print("familles", sorted(Counter(u["traits"][0] for u in units.values()).items()))
    print("armes", sorted(Counter(u["traits"][1] for u in units.values()).items()))
    print("rôles", sorted(Counter(u["role"] for u in units.values()).items()))
    print("sorts", sorted(Counter(u["spell_type"] for u in units.values()).items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
