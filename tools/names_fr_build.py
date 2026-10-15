# -*- coding: utf-8 -*-
"""Génère game/data/names_fr.json : noms français de toutes les entrées anglaises d'Eden.

    python tools/names_fr_build.py            # écrit game/data/names_fr.json
    python tools/names_fr_build.py --report   # liste les mots restés en anglais

Le fichier JSON est lisible et éditable à la main : la section « overrides » (noms exacts
corrigés à la main, anglais -> français) est CONSERVÉE à chaque régénération et l'emporte sur
les tables générées. Le lexique et les règles sont dans tools/names_fr_lexicon.py et ici.
Les identifiants ne sont jamais touchés (la table est indexée par le nom d'origine).
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import names_fr_lexicon as LEX  # noqa: E402
import importlib  # noqa: E402
import pkgutil  # noqa: E402
EXTRAS = [importlib.import_module(m.name) for m in pkgutil.iter_modules([str(Path(__file__).parent)]) if m.name.startswith("names_fr_") and m.name != "names_fr_lexicon" and m.name != "names_fr_build"]

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data"
OUT = DATA / "names_fr.json"

VOWELS = "aeiouyàâäéèêëîïôöùûüœæ"
ASPIRATED = ("hache", "hurlement", "héros", "hibou", "harpe", "héraut", "hérisson", "hydre", "houle", "homard", "hâche", "haut", "hanche", "hameau")


def parse_nouns(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        kind = p[3] if len(p) > 3 else "n"
        fr = p[1][:1].lower() + p[1][1:] if kind == "m" else p[1]
        out[p[0]] = {"fr": fr, "g": p[2], "k": kind, "key": p[0]}
    return out


def feminize(m):
    if m.endswith("e") or " " in m or m.startswith(("d'", "de ")):
        return m
    for a, b in (("éen", "éenne"), ("eux", "euse"), ("if", "ive"), ("ier", "ière"), ("eur", "euse"), ("ien", "ienne"), ("on", "onne"), ("el", "elle"),
                 ("al", "ale"), ("ain", "aine"), ("er", "ère")):
        if m.endswith(a):
            return m[: -len(a)] + b
    return m + "e"


PRE_ADJ = {"grand", "petit", "premier", "dernier", "vieux", "nouveau", "troisième", "deuxième", "quatrième", "neuf", "six", "sept", "quatre",
           "deux", "trois", "mille", "cent", "un", "demi", "beau", "bon", "jeune", "ancien"}


def parse_adjs(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        m = p[1]
        f = p[2] if len(p) > 2 else feminize(m)
        out[p[0]] = (m, f, m in PRE_ADJ and p[0] not in ("Ancient", "Elder", "Old"))
    return out


NOUNS = parse_nouns(LEX.NOUNS)
ADJS = parse_adjs(LEX.ADJS)
PHRASES = {}
EXACT = {}
FAMILIES = {"Holy": "Sacré", "Flame Eagle": "Aigle de flamme", "Temple Knights": "Chevaliers du Temple"}
PREFER_ADJ = {"Noble", "Sage", "Elder", "Guard", "Grand"}
SLOT_HEADS = {"Boots", "Belt", "Gloves", "Bracers", "Gauntlets", "Hat", "Helmet", "Helm", "Crown", "Headdress", "Brigandine", "Robe",
              "Armor", "Tunic", "Vestment", "Cape", "Cloak", "Band", "Greaves", "Shoes", "Necklace", "Ring", "Shield", "Mask", "Cap",
              "WristArmor", "Pendant", "Bracelet", "Coat", "Turban", "Mantle", "Chain", "Amulet", "Girdle", "Vest", "Slippers", "Wraps", "Scarf"}
TAGS = {"Epic": "Épique", "Ancient": "Antique", "Cursed": "Maudit", "Blessed": "Béni", "Prime": "Primordial", "Legendary": "Légendaire",
        "Mythic": "Mythique", "Alpha": "Alpha", "Beta": "Bêta", "Gamma": "Gamma", "Rare": "Rare", "Common": "Commun", "Special": "Spécial"}
for EXTRA in sorted(EXTRAS, key=lambda m: m.__name__):
    NOUNS.update(parse_nouns(getattr(EXTRA, "NOUNS", "")))
    ADJS.update(parse_adjs(getattr(EXTRA, "ADJS", "")))
    PHRASES.update(getattr(EXTRA, "PHRASES", {}))
    EXACT.update(getattr(EXTRA, "EXACT", {}))

UNKNOWN = {}  # mot anglais inconnu -> occurrences


def is_vowel(fr, proper=False):
    c = fr[0].lower()
    if proper and c == "y":
        return False
    if c == "h":
        return not fr.lower().startswith(ASPIRATED)
    return c in VOWELS


NUMERALS = {"neuf", "six", "sept", "huit", "quatre", "trois", "mille", "cent", "dix", "deux", "un", "une"}


def plural_adj(a):
    return a if (a.endswith(("s", "x")) or " " in a or a in NUMERALS) else a + "s"


DEEP_BARE = set("""Ice Fire Flame Flames Frost Snow Water Wind Storm Thunder Lightning Blood Death Shadow Stone Rock Earth Sand
Bone Dragon Wolf Lion Tiger Fox Bear Eagle Falcon Hawk Phoenix Demon Devil Angel Star Moon Sun Wing Feather Fang Claw Thorn
Rose Lily Flower Crystal Gem Pearl Rainbow Aurora Hellfire Ash Ember Smoke Mist Rain Poison Venom Acid Lava Spirit Soul Heart""".split())


class Unit:
    def __init__(self, fr, g="m", k="n", adjs=None, key=""):
        self.fr, self.g, self.k, self.adjs = fr, g, k, adjs or []
        self.suffix = ""
        self.key = key
        self.poss = False

    def bare(self):
        """Forme sans article, minuscule : « de flamme », « d'os » (unité éloignée de la tête)."""
        t = self.text()
        t = t[:1].lower() + t[1:]
        return ("d'" if is_vowel(t) else "de ") + t

    @property
    def plural(self):
        return self.g in ("mp", "fp")

    @property
    def fem(self):
        return self.g in ("f", "fp")

    def text(self):
        s = self.fr
        pre = []
        for a3 in self.adjs:
            m, f = a3[0], a3[1]
            a = f if self.fem else m
            if self.plural:
                a = plural_adj(a)
            if len(a3) > 2 and a3[2]:
                pre.append(a)
            else:
                s += " " + a
        if pre:
            s = " ".join(w[:1].upper() + w[1:] for w in pre) + " " + s
        if self.suffix:
            s += " " + self.suffix
        return s

    def prep(self, body=None):
        """« de la Flamme », « d'acier », « de Johnson » devant le texte [body]."""
        t = body if body is not None else self.text()
        if self.k == "m":
            return ("d'" if is_vowel(t) else "de ") + t
        if self.k == "p":
            return ("d'" if is_vowel(t, True) else "de ") + t
        if self.plural:
            return "des " + t
        if is_vowel(t):
            return "de l'" + t
        return ("du " if self.g == "m" else "de la ") + t


def tokenize(s):
    s = s.replace("’", "'")
    toks = re.findall(r"[A-Za-z][A-Za-z'\.]*|\d+[A-Za-z']*|[^\sA-Za-z\d]", s)
    return toks


def classify(tok):
    """-> ('noun', entry) / ('adj', (m, f)) / ('num', tok) / ('prop', tok) / ('skip', None)"""
    t = tok
    poss = False
    if t.endswith("'s") or t.endswith("s'"):
        base = t[:-2] if t.endswith("'s") else t[:-1]
        poss = True
        t = base
    if re.fullmatch(r"\d+", t):
        return ("num", tok, poss)
    low = t
    if t in PREFER_ADJ and t in ADJS:
        return ("adj", ADJS[t], poss)
    if t in NOUNS:
        return ("noun", NOUNS[t], poss)
    if t in ADJS:
        return ("adj", ADJS[t], poss)
    cap = t.capitalize() if t.isupper() else t
    if cap in NOUNS:
        return ("noun", NOUNS[cap], poss)
    if cap in ADJS:
        return ("adj", ADJS[cap], poss)
    if t.lower() in ("the", "a", "an"):
        return ("skip", None, poss)
    UNKNOWN[t] = UNKNOWN.get(t, 0) + 1
    return ("prop", tok if not poss else t, poss)


def known(w):
    return w in NOUNS or w in ADJS


def split_compound(tok):
    """« Icesoul » -> [Ice, Soul] quand les deux moitiés sont des mots connus."""
    if "'" in tok or "." in tok or not tok.isalpha() or known(tok) or len(tok) < 7:
        return [tok]
    low = tok.lower()
    best = None
    for i in range(3, len(low) - 2):
        a, b = low[:i].capitalize(), low[i:].capitalize()
        if known(a) and known(b):
            # on préfère la coupe dont la 2e moitié est la plus longue (tête du composé)
            if best is None or len(b) > len(best[1]):
                best = [a, b]
    return best or [tok]


def build_units(tokens):
    """Liste de mots -> liste d'unités (la dernière est la tête)."""
    units = []
    pending = []
    exp = []
    for t in tokens:
        exp.extend(split_compound(t))
    for tok in exp:
        kind, ent, poss = classify(tok)
        if kind == "skip":
            continue
        if kind == "adj":
            pending.append(ent)
            continue
        if kind == "num":
            if units:
                units[-1].suffix = (units[-1].suffix + " " + tok).strip()
            else:
                pending.append(("%s" % tok, "%s" % tok))
            continue
        if kind == "noun":
            u = Unit(ent["fr"], ent["g"], ent["k"], pending, ent["key"])
        else:  # nom propre inconnu : tel quel
            u = Unit(ent, "m", "p", pending)
        u.poss = poss
        pending = []
        # « Karis Amon's » : deux noms propres de suite ; « Knight Morris's » : titre + nom
        if units and not u.adjs and not units[-1].suffix and u.k == "p" and (units[-1].k == "p" or (units[-1].k == "n" and poss and not units[-1].adjs)):
            units[-1].fr += " " + u.fr
            units[-1].poss = poss
            continue
        units.append(u)
    if pending:
        if units:
            units[-1].adjs = units[-1].adjs + pending
        else:  # nom entièrement fait d'adjectifs : « Impardonné »
            u = Unit(pending[0][0], "m", "n", [])  # pylint: disable=unsubscriptable-object
            u.adjs = pending[1:]
            units.append(u)
    return units


def chain(units):
    """[U1..Un] -> « Tête de U(n-1) de ... de U1 » ; renvoie (texte, tête)."""
    if not units:
        return "", None
    head = units[-1]
    s = head.text()
    for idx, u in enumerate(reversed(units[:-1])):
        s += " " + (u.bare() if idx > 0 and u.key in DEEP_BARE and u.k == "n" else u.prep())
    return s, head


def phrase(tokens):
    """Groupe nominal avec « of »/« and »."""
    tokens = [t.lower() if t in ("Of", "And", "The", "To") else t for t in tokens if t not in (",",)]
    if "and" in tokens:
        i = tokens.index("and")
        a, b = tokens[:i], tokens[i + 1:]
        if a and b:
            return phrase(a)[0] + " et " + phrase(b)[0], None
    if "of" in tokens:
        i = tokens.index("of")
        left, right = tokens[:i], tokens[i + 1:]
        if left and right:
            jj = 0
            while jj < len(right) - 1 and classify(right[jj])[0] == "adj":
                jj += 1
            if right[-1] in SLOT_HEADS and len(right) > 1 and jj < len(right) - 1:
                # « Seal of Destruction Leather Boots » : Bottes de cuir du Sceau de la Destruction
                j = 0
                while j < len(right) - 1 and classify(right[j])[0] == "adj":
                    j += 1
                obj = right[: j + 1]
                mid = right[j + 1: -1]
                head = right[-1]
                owner_txt, owner_head = phrase(left + ["of"] + obj)
                s, h = chain(build_units(mid + [head]))
                return s + " " + owner_head.prep(owner_txt) if owner_head else s + " de " + owner_txt, h
            ltxt, lhead = phrase(left)
            rtxt, rhead = phrase(right)
            if rhead is None:
                return ltxt + " de " + rtxt, lhead
            return ltxt + " " + rhead.prep(rtxt), lhead
    units = build_units(tokens)
    return chain(units)


def cap1(s):
    return s[:1].upper() + s[1:] if s else s


def translate_item(name):
    """Nom d'équipement / d'objet d'Eden -> français."""
    s = name.strip()
    s = s.replace(" ", " ")
    if s in EXACT:
        return EXACT[s]
    # étiquettes finales : « (Alpha) », « - S »
    tag = ""
    m = re.search(r"\s*\((Alpha|Beta|Gamma|Epic|Ancient|Cursed|Blessed|Prime|Legendary|Mythic|Rare|Common|Special)\)\s*$", s)
    if m:
        tag = " (" + TAGS[m.group(1)] + ")"
        s = s[: m.start()]
    m = re.search(r"\s+-\s+S$", s)
    if m:
        tag = " (rang S)" + tag
        s = s[: m.start()]
    s = re.sub(r"^Test\s+", "", s)
    m = re.search(r"\s+Lv\s?(\d+)$", s)
    if m:
        tag = " (niv. %s)" % m.group(1) + tag
        s = s[: m.start()]
    for a, b in PHRASES.items():
        s = s.replace(a, b)
    # noms déjà en français : « Armure (Brave de la Tribu) »
    m = re.fullmatch(r"([^()]+?)\s*\((.+)\)", s)
    if m and re.search(r"\b(de la|du|de l')", m.group(2)) and not re.search(r"[A-Z][a-z]+ [A-Z]", m.group(1)):
        inner = m.group(2).strip()
        first = inner[:1].lower()
        pre = "de " if inner.lower().startswith("l'") else ("de l'" if is_vowel(inner) else "du ")
        inner = inner[2:] if inner.lower().startswith("l'") else inner
        return cap1(m.group(1).strip()) + " " + pre + inner + tag
    if is_french(s):
        return s
    # préfixe de famille ou de série : « Flame Eagle- Rage Axe », « Doomsday - Landslide », « Fist Soul: Luster »
    m = re.match(r"^(.+?)(?:\s+-\s+|-\s+|:\s+)(.+)$", s)
    if m:
        a, b = m.group(1).strip(), m.group(2).strip()
        if a in FAMILIES:
            return cap1(translate_item(b)) + " (" + FAMILIES[a] + ")" + tag
        if s.startswith("5 Beast Team Totem"):
            return "Totem de l'Équipe des 5 Bêtes : " + b + tag
        if b.split()[-1] in SLOT_HEADS:
            return cap1(translate_item(b)) + " (" + translate_item(a).lower() + ")" + tag
        return cap1(translate_item(a)) + " : " + cap1(translate_item(b)) + tag
    s = re.sub(r"\s+", " ", s)
    s = s.replace(" - ", " ")
    s = re.sub(r"(\w)-(\w)", r"\1 \2", s)  # « Anti-Gavel », « Breath-Holding »
    toks = [t for t in tokenize(s) if re.search(r"[A-Za-z\d]", t)]
    # « Awaken X Y Crown » : adjectif porté par la tête
    if toks and toks[0] == "Awaken":
        txt, head = phrase(toks[1:])
        if head is not None:
            return cap1(txt) + " " + ("éveillées" if head.plural and head.fem else "éveillés" if head.plural else "éveillée" if head.fem else "éveillé") + tag
        return cap1(txt) + " éveillé" + tag
    txt, head = phrase(toks)
    return cap1(txt) + tag


FRENCH_RE = re.compile(r"[àâçéèêëîïôùûüœ]|\b(de|du|des|la|le|les)\b|\bl'|\bd'")


def is_french(n):
    return bool(FRENCH_RE.search(n))


def load_catalog():
    return json.loads((DATA / "eden_catalog.json").read_text(encoding="utf-8"))


def main():
    report = "--report" in sys.argv
    cat = load_catalog()
    old = {}
    if OUT.exists():
        try:
            old = json.loads(OUT.read_text(encoding="utf-8"))
        except Exception:
            old = {}
    overrides = old.get("overrides", {})
    out = {
        "_doc": "Table de traduction des noms d'Eden (anglais -> français). Générée par tools/names_fr_build.py ; "
                "modifiable à la main : la section « overrides » (nom anglais exact -> nom français) est conservée à "
                "chaque génération et prime sur toutes les autres sections. Les identifiants ne changent jamais.",
        "overrides": overrides,
    }
    import names_fr_exact as EX  # noqa: E402
    zones = {}
    for z in json.loads((DATA / "zones.json").read_text(encoding="utf-8")):
        for nm in (z["name"], z.get("dungeon", {}).get("name")):
            if nm:
                zones[nm] = EX.ZONES.get(nm) or (nm if is_french(nm) else translate_item(nm))
    out["zones"] = zones
    mons = {}
    for m in json.loads((DATA / "monsters.json").read_text(encoding="utf-8")).values():
        mons[m["name"]] = EX.MONSTERS.get(m["name"]) or (m["name"] if is_french(m["name"]) else translate_item(m["name"]))
    out["monsters"] = mons
    items = {}
    for i in cat["items"]:
        items[i["name"]] = None
    for n in items:
        items[n] = EX.ITEMS.get(n) or translate_item(n)
    out["items"] = items
    if report and "--items" in sys.argv:
        for w, n in sorted(UNKNOWN.items(), key=lambda x: -x[1]):
            print(w, n)
        print(len(UNKNOWN), "mots inconnus")
        return
    def set_name(n):
        m = re.fullmatch(r"Set (\d+)", n)
        if m:
            return "Panoplie " + m.group(1)
        return translate_item(re.sub(r"\s+Set\b", "", n))

    sets = {v["name"]: set_name(v["name"]) for v in cat["sets"].values()}
    out["sets"] = sets
    cos = {c["name"]: translate_item(c["name"]) for c in cat["cosmetics"]}
    out["cosmetics"] = cos
    col = {c["name"]: translate_item(c["name"]) for c in cat["collection"]}
    out["collection"] = col
    if report:
        for w, n in sorted(UNKNOWN.items(), key=lambda x: -x[1])[:400]:
            print(w, n)
        print(len(UNKNOWN), "mots inconnus")
        return
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print("écrit", OUT, OUT.stat().st_size // 1024, "Ko")


if __name__ == "__main__":
    main()
