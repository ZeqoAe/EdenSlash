"""L'Échiquier (autochess), lot AC-J : rapport de la mesure de masse (SPEC §9 ; conception/autochess/R_AC_J.md).

Lit les lignes JSON écrites par game/tools/autochess_games.tscn (une par partie) et imprime en Markdown :
durées (combats, partie, 1re élimination, éliminations par manche), échelle des difficultés, unités, traits par palier,
objets, atouts (place, top 4, top 4 relatif, taux de choix), méta (compositions gagnantes), économie, écarts aux cibles.

    python tools/autochess_report.py <fichiers .jsonl ou dossiers> [--min=30] [--json=resume.json] [--all]
    python tools/autochess_report.py <...> [--data=<dossier game>]   (tables lues dans une autre copie du jeu : mesure « avant »)
    python tools/autochess_report.py --run=<dossier> [--games=2000] [--jobs=4] [--godot=exe] [--project=game]
        (--run : lance les parties en parallèle — echelle en --jobs morceaux + l7r, r7l, pilote, legendes à 200 —
         puis imprime le rapport ; --games = parties de la mise en place « echelle »)

Top 4 relatif : 50 % + moyenne de (top 4 de la partie − top 4 attendu de la difficulté du stratège dans sa mise en place) :
la force de l'IA qui joue l'unité ne compte pas, seule l'unité (le trait, l'objet, l'atout) compte. Hors 40-60 % : à voir.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import re
import statistics
import subprocess
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_GD = ROOT / "game" / "scripts" / "core" / "autochess_data.gd"
UNITS_JSON = ROOT / "game" / "data" / "autochess_units.json"
DIFFS = ["recrue", "veteran", "champion", "legende"]
DIFF_FR = {"recrue": "Recrue", "veteran": "Vétéran", "champion": "Champion", "legende": "Légende"}
TEMPER_FR = {"econome": "Économe", "relanceur": "Relanceur", "montee_rapide": "Montée rapide"}
SETUP_FR = {"echelle": "Échelle (2 de chaque difficulté)", "l7r": "1 Légende contre 7 Recrues",
            "r7l": "1 Recrue contre 7 Légendes", "pilote": "1 Vétéran contre le mélange Vétéran",
            "legendes": "8 Légendes"}


# --- Données du jeu (noms, coûts) ------------------------------------------------------------------------------------
def _block(text: str, name: str) -> str:
    i = text.find(f"const {name} := {{")
    if i < 0:
        return ""
    j = text.find("\n}\n", i)
    return text[i:j]


def load_names(game_dir: Path | None = None) -> dict:
    data_gd = (game_dir / "scripts" / "core" / "autochess_data.gd") if game_dir else DATA_GD
    units_json = (game_dir / "data" / "autochess_units.json") if game_dir else UNITS_JSON
    text = data_gd.read_text(encoding="utf-8")
    out = {"items": {}, "components": {}, "augments": {}, "traits": {}, "trait_kind": {}, "aug_rarity": {}}
    for m in re.finditer(r'^\t"(\w+)": \{"name": "([^"]+)"', _block(text, "ITEMS"), re.M):
        out["items"][m.group(1)] = m.group(2)
    for m in re.finditer(r'^\t"(\w+)": \{"name": "([^"]+)"', _block(text, "COMPONENTS"), re.M):
        out["components"][m.group(1)] = m.group(2)
    for m in re.finditer(r'^\t"(\w+)": \{"name": "([^"]+)"', _block(text, "SPECIAL_ITEMS"), re.M):
        out["components"][m.group(1)] = m.group(2)
    for m in re.finditer(r'^\t"(\w+)": \{"rarity": "(\w+)", "name": "([^"]+)"', _block(text, "AUGMENTS"), re.M):
        out["augments"][m.group(1)] = m.group(3)
        out["aug_rarity"][m.group(1)] = m.group(2)
    for m in re.finditer(r'^\t"(\w+)": \{"name": "([^"]+)", "kind": "(\w+)"', _block(text, "TRAITS"), re.M):
        out["traits"][m.group(1)] = m.group(2)
        out["trait_kind"][m.group(1)] = m.group(3)
    units = json.loads(units_json.read_text(encoding="utf-8"))["units"]
    out["units"] = {k: v.get("name", k) for k, v in units.items()}
    out["cost"] = {k: int(v.get("cost", 1)) for k, v in units.items()}
    out["role"] = {k: v.get("role", "") for k, v in units.items()}
    out["family"] = {k: (v.get("traits") or [""])[0] for k, v in units.items()}  # famille d'origine (1er trait)
    return out


# --- Lecture -------------------------------------------------------------------------------------------------------
def read_games(paths: list[str]) -> list[dict]:
    files: list[str] = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(glob.glob(os.path.join(p, "*.jsonl")))
        else:
            files += sorted(glob.glob(p)) or [p]
    games = []
    seen = set()
    for f in files:
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                g = json.loads(line)
                key = (g.get("setup"), g.get("seed"), g.get("v"), g.get("fight"))
                if key in seen:
                    continue
                seen.add(key)
                games.append(g)
    return games


def rkey(k: str) -> int:
    """« 4-1 » -> 41 (ordre des manches)."""
    if not k:
        return 999
    a, b = k.split("-")
    return int(a) * 10 + int(b)


def pct(x: float) -> str:
    return f"{100.0 * x:.0f} %"


def f1(x: float) -> str:
    return f"{x:.1f}".replace(".", ",")


def f2(x: float) -> str:
    return f"{x:.2f}".replace(".", ",")


def quant(xs: list[float], q: float) -> float:
    if not xs:
        return 0.0
    s = sorted(xs)
    return s[min(len(s) - 1, int(q * len(s)))]


# --- Agrégats ------------------------------------------------------------------------------------------------------
class Acc:
    """Place, top 4 et écart à l'attendu de la difficulté (top 4 relatif) d'un objet de mesure."""

    def __init__(self) -> None:
        self.n = 0
        self.place = 0.0
        self.top4 = 0
        self.win = 0
        self.resid = 0.0
        self.resid_place = 0.0
        self.leg = 0

    def add(self, place: int, exp_top4: float, exp_place: float, legende: bool) -> None:
        self.n += 1
        self.place += place
        self.top4 += 1 if place <= 4 else 0
        self.win += 1 if place == 1 else 0
        self.resid += (1.0 if place <= 4 else 0.0) - exp_top4
        self.resid_place += place - exp_place
        self.leg += 1 if legende else 0

    def row(self) -> dict:
        n = max(self.n, 1)
        return {"n": self.n, "place": self.place / n, "top4": self.top4 / n, "win": self.win / n,
                "rel_top4": 0.5 + self.resid / n, "rel_place": 4.5 + self.resid_place / n}


def baselines(games: list[dict]) -> dict:
    """(mise en place, difficulté) -> [top 4 attendu, place attendue]."""
    acc: dict = defaultdict(lambda: [0, 0, 0])
    for g in games:
        for p in g["players"]:
            a = acc[(g["setup"], p["d"])]
            a[0] += 1
            a[1] += 1 if p["place"] <= 4 else 0
            a[2] += p["place"]
    return {k: [v[1] / v[0], v[2] / v[0]] for k, v in acc.items()}


def main_traits(traits: dict, kind: dict) -> tuple[str, str]:
    """Trait de famille et trait d'arme principaux (palier, puis compte) d'un plateau ; « » si aucun."""
    best = {"famille": ("", -1, -1), "arme": ("", -1, -1)}
    for t, v in traits.items():
        tier, count = (v if isinstance(v, list) else [v, 0])
        k = kind.get(t, "arme")
        if (tier, count) > best[k][1:]:
            best[k] = (t, tier, count)
    return best["famille"][0], best["arme"][0]


def analyse(games: list[dict], names: dict, min_n: int) -> dict:
    base = baselines(games)
    res: dict = {"setups": Counter(g["setup"] for g in games), "versions": Counter(g.get("v", "?") for g in games),
                 "fights": Counter(g.get("fight", "?") for g in games)}
    main = [g for g in games if g["setup"] == "echelle"] or games
    res["main_n"] = len(main)
    # durées
    jcj = [d for g in main for d in g.get("jcj", [])]
    draws = sum(g.get("draws", 0) for g in main)
    res["fight"] = {"n": len(jcj), "median": statistics.median(jcj) if jcj else 0, "p90": quant(jcj, 0.9),
                    "under40": sum(1 for d in jcj if d < 40.0) / max(len(jcj), 1), "draws": draws / max(len(jcj), 1),
                    "p10": quant(jcj, 0.1)}
    tot = [g["min"]["total"] for g in main]
    x2 = [g["min"]["prep"] + g["min"]["recap"] + g["min"]["fight"] / 2.0 for g in main]
    res["game"] = {"total": statistics.mean(tot), "total_med": statistics.median(tot), "x2": statistics.mean(x2),
                   "prep": statistics.mean(g["min"]["prep"] for g in main),
                   "recap": statistics.mean(g["min"]["recap"] for g in main),
                   "fightmin": statistics.mean(g["min"]["fight"] for g in main),
                   "rounds": statistics.mean(g["rounds"] for g in main),
                   "p10": quant(tot, 0.1), "p90": quant(tot, 0.9),
                   "last": Counter(g["last"].split("-")[0] for g in main),
                   "ms": statistics.mean(g.get("ms", 0) for g in main) / 1000.0}
    firsts = []
    elim = Counter()
    for g in main:
        outs = [p["out"] for p in g["players"] if p["out"]]
        for o in outs:
            elim[o] += 1
        if outs:
            firsts.append(min(outs, key=rkey))
    res["first_out"] = {"before41": sum(1 for k in firsts if rkey(k) < 41) / max(len(main), 1),
                        "median": sorted(firsts, key=rkey)[len(firsts) // 2] if firsts else "",
                        "dist": Counter(k.split("-")[0] for k in firsts)}
    res["elim"] = {k: v / len(main) for k, v in sorted(elim.items(), key=lambda kv: rkey(kv[0]))}
    # 1re élimination (minutes) et durée du gagnant
    res["first_min"] = statistics.mean(min(p["out_min"] for p in g["players"] if p["out"]) for g in main
                                       if any(p["out"] for p in g["players"]))
    # difficultés
    diff = {}
    for setup in res["setups"]:
        gs = [g for g in games if g["setup"] == setup]
        by = defaultdict(lambda: Acc())
        focal = Acc()
        by_t = defaultdict(lambda: Acc())
        for g in gs:
            for p in g["players"]:
                dk = DIFFS[p["d"]]
                by[dk].add(p["place"], 0.5, 4.5, False)
                by_t[f"{dk}/{p['t']}"].add(p["place"], 0.5, 4.5, False)
                if p.get("focal"):
                    focal.add(p["place"], 0.5, 4.5, False)
        diff[setup] = {"by": {k: v.row() for k, v in by.items()}, "focal": focal.row() if focal.n else None,
                       "by_t": {k: v.row() for k, v in by_t.items()}, "n": len(gs)}
    res["diff"] = diff
    # unités, traits, objets, atouts (mise en place « echelle » ; part jouée par les Légende : echelle + legendes)
    units = defaultdict(Acc)
    units_carry = defaultdict(Acc)
    traits = defaultdict(Acc)
    items = defaultdict(Acc)
    augs = defaultdict(Acc)
    offered = Counter()
    picked = Counter()
    leg_boards = 0
    leg_unit = Counter()
    leg_trait_any = Counter()
    leg_trait_main = Counter()
    win_comps = Counter()
    win_fam = Counter()
    win_weap = Counter()
    win_pair = Counter()  # lot ACX-4 : les deux traits principaux du 1er, quel que soit leur genre
    mono = []  # part de la famille la plus présente sur le plateau du 1er
    s3 = []
    econ = defaultdict(lambda: defaultdict(list))
    for g in games:
        is_main = g["setup"] == "echelle"
        for p in g["players"]:
            dk = DIFFS[p["d"]]
            legende = p["d"] == 3
            if legende and g["setup"] in ("echelle", "legendes"):
                leg_boards += 1
                for uid in {u[0] for u in p["board"]}:
                    leg_unit[uid] += 1
                for t in p["traits"]:
                    leg_trait_any[t] += 1
                fam, wea = main_traits(p["traits"], names["trait_kind"])
                for t in (fam, wea):
                    if t:
                        leg_trait_main[t] += 1
            if not is_main:
                continue
            exp_t4, exp_pl = base[(g["setup"], p["d"])]
            pl = p["place"]
            for uid in {u[0] for u in p["board"]}:
                units[uid].add(pl, exp_t4, exp_pl, legende)
            for uid in {u[0] for u in p["board"] if any(it in names["items"] for it in u[2])}:
                units_carry[uid].add(pl, exp_t4, exp_pl, legende)
            for t, v in p["traits"].items():
                tier = v[0] if isinstance(v, list) else v
                traits[(t, tier)].add(pl, exp_t4, exp_pl, legende)
            for u in p["board"]:
                for it in u[2]:
                    key = it.split(":")[0]
                    items[key].add(pl, exp_t4, exp_pl, legende)
            for a in p["augs"]:
                augs[a].add(pl, exp_t4, exp_pl, legende)
            for opts, took in p["offers"]:
                for o in opts:
                    offered[o] += 1
                if took:
                    picked[took] += 1
            if pl == 1:
                fam, wea = main_traits(p["traits"], names["trait_kind"])
                win_comps[f"{fam or '—'}+{wea or '—'}"] += 1
                win_fam[fam or "—"] += 1
                win_weap[wea or "—"] += 1
                ranked = sorted(p["traits"].items(), key=lambda kv: (-(kv[1][0] if isinstance(kv[1], list) else kv[1]),
                                                                     -(kv[1][1] if isinstance(kv[1], list) else 0), kv[0]))
                win_pair["+".join(sorted(t for t, _ in ranked[:2])) or "—"] += 1
                fams = Counter(names["family"].get(u[0], "") for u in p["board"])
                if p["board"]:
                    mono.append(max(fams.values()) / len(p["board"]))
            e = p["econ"]
            r = max(e["rounds"], 1)
            ec = econ[dk]
            ec["gold"].append(e["gold"] / r)
            ec["income"].append(e["income"] / r)
            ec["interest"].append(e["interest"] / r)
            ec["streak"].append(e["streak"] / r)
            if e["gold41"] >= 0:
                ec["gold41"].append(e["gold41"])
                ec["level41"].append(e["level41"])
            ec["rerolls"].append(p["stats"]["rerolls"])
            ec["xp"].append(p["stats"]["xp_bought"])
            ec["spent"].append(p["stats"]["gold_spent"])
            ec["level"].append(p["level"])
            ec["s3"].append(p["s3"])
        if is_main:
            s3.append(sum(p["s3"] for p in g["players"]))
    res["units"] = {k: v.row() | {"leg": leg_unit[k] / max(leg_boards, 1)} for k, v in units.items()}
    res["units_carry"] = {k: v.row() for k, v in units_carry.items()}
    res["unused_by_leg"] = sorted(k for k in names["units"] if leg_unit[k] == 0)
    res["traits"] = {f"{k[0]}:{k[1]}": v.row() for k, v in traits.items()}
    res["leg_trait"] = {t: [leg_trait_any[t] / max(leg_boards, 1), leg_trait_main[t] / max(leg_boards, 1)] for t in names["traits"]}
    res["items"] = {k: v.row() for k, v in items.items()}
    for k in offered:
        augs.setdefault(k, Acc())
    res["augs"] = {k: v.row() | {"offered": offered[k], "picked": picked[k],
                                 "pick_rate": picked[k] / offered[k] if offered[k] else 0.0} for k, v in augs.items()}
    nwin = sum(win_comps.values())
    ent = -sum((c / nwin) * math.log(c / nwin) for c in win_comps.values()) if nwin else 0.0
    npair = sum(win_pair.values())
    ent2 = -sum((c / npair) * math.log(c / npair) for c in win_pair.values()) if npair else 0.0
    res["meta"] = {"wins": nwin, "distinct": len(win_comps), "top": win_comps.most_common(8),
                   "top_share": win_comps.most_common(1)[0][1] / nwin if nwin else 0.0, "effective": math.exp(ent),
                   "entropy": ent, "fam": win_fam.most_common(), "weap": win_weap.most_common(),
                   "pair_top": win_pair.most_common(8), "pair_distinct": len(win_pair),
                   "pair_share": win_pair.most_common(1)[0][1] / npair if npair else 0.0, "pair_effective": math.exp(ent2),
                   "fam_top_share": win_fam.most_common(1)[0][1] / nwin if nwin else 0.0,
                   "mono_mean": statistics.mean(mono) if mono else 0.0,
                   "mono6": sum(1 for x in mono if x >= 0.75) / len(mono) if mono else 0.0}
    res["econ"] = {dk: {k: statistics.mean(v) if v else 0.0 for k, v in d.items()} for dk, d in econ.items()}
    res["s3_per_game"] = statistics.mean(s3) if s3 else 0.0
    res["leg_boards"] = leg_boards
    res["min_n"] = min_n
    return res


# --- Impression ----------------------------------------------------------------------------------------------------
def table(head: list[str], rows: list[list]) -> str:
    out = ["| " + " | ".join(head) + " |", "|" + "|".join("---" for _ in head) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(x) for x in r) + " |")
    return "\n".join(out)


def flag(rel: float) -> str:
    return "▲ fort" if rel > 0.60 else ("▼ faible" if rel < 0.40 else "")


def report(res: dict, names: dict, show_all: bool) -> tuple[str, list[str]]:
    L: list[str] = []
    gaps: list[str] = []
    mn = res["min_n"]
    L.append(f"Parties : {dict(res['setups'])} ; versions {dict(res['versions'])} ; combats {dict(res['fights'])}.")
    L.append("")
    fi = res["fight"]
    gm = res["game"]
    fo = res["first_out"]
    L.append("## Durées (mise en place « echelle »)")
    L.append(table(["Mesure", "Valeur", "Cible (§9)"], [
        ["combats JcJ (simulateur calé)", f"médiane {f1(fi['median'])} s, p10 {f1(fi['p10'])} s, p90 {f1(fi['p90'])} s", "médiane 22-28 s"],
        ["combats sous 40 s / égalités", f"{pct(fi['under40'])} / {f1(100 * fi['draws'])} %", "≥ 90 % / < 3 %"],
        ["partie entière (×1, préparations pleines)", f"{f1(gm['total'])} min (médiane {f1(gm['total_med'])}, p10 {f1(gm['p10'])}, p90 {f1(gm['p90'])})", "25-30 min"],
        ["dont préparation / bilans / combats", f"{f1(gm['prep'])} / {f1(gm['recap'])} / {f1(gm['fightmin'])} min", "—"],
        ["partie entière, combats ×2", f"{f1(gm['x2'])} min", "≈ 22 min"],
        ["manches jouées", f"{f1(gm['rounds'])} ; dernière étape {dict(sorted(gm['last'].items()))}", "≈ 35"],
        ["1re élimination", f"médiane {fo['median']}, {f1(res['first_min'])} min ; avant 4-1 : {pct(fo['before41'])}", "avant 4-1 < 20 %"],
        ["calcul", f"{f2(gm['ms'])} s par partie", "< 3 s"],
    ]))
    if not 22 <= fi["median"] <= 28:
        gaps.append(f"Combat JcJ médian {f1(fi['median'])} s (cible 22-28 s).")
    if fi["draws"] >= 0.03:
        gaps.append(f"Égalités {f1(100 * fi['draws'])} % des combats (cible < 3 %).")
    if fi["under40"] < 0.9:
        gaps.append(f"Combats sous 40 s : {pct(fi['under40'])} (cible ≥ 90 %).")
    if not 25 <= gm["total"] <= 30:
        gaps.append(f"Partie de {f1(gm['total'])} min à ×1 (cible 25-30 min).")
    if fo["before41"] >= 0.2:
        gaps.append(f"1re élimination avant 4-1 dans {pct(fo['before41'])} des parties (cible < 20 %).")
    L.append("")
    L.append("Éliminations par manche (moyenne par partie) : " + ", ".join(f"{k} {f2(v)}" for k, v in res["elim"].items() if v >= 0.05))
    L.append("")
    # difficultés
    L.append("## Échelle des difficultés")
    rows = []
    for setup, d in res["diff"].items():
        for dk in DIFFS:
            if dk in d["by"]:
                r = d["by"][dk]
                rows.append([SETUP_FR.get(setup, setup), DIFF_FR[dk], r["n"], f2(r["place"]), pct(r["top4"]), pct(r["win"])])
    L.append(table(["Mise en place", "Difficulté", "Places", "Place moyenne", "Top 4", "1re"], rows))
    targets = {"l7r": (">=", 0.75), "r7l": ("<=", 0.25), "pilote": ("~", 0.50)}
    L.append("")
    for setup, (op, v) in targets.items():
        d = res["diff"].get(setup)
        if not d or not d["focal"]:
            continue
        t4 = d["focal"]["top4"]
        ok = t4 >= v if op == ">=" else (t4 <= v if op == "<=" else abs(t4 - v) <= 0.08)
        L.append(f"- {SETUP_FR[setup]} : top 4 de l'IA observée {pct(t4)} (place {f2(d['focal']['place'])}, {d['n']} parties) ; cible {op} {pct(v)} : {'tenu' if ok else 'ÉCART'}")
        if not ok:
            gaps.append(f"{SETUP_FR[setup]} : top 4 {pct(t4)} (cible {op} {pct(v)}).")
    if "echelle" in res["diff"]:
        bt = res["diff"]["echelle"]["by_t"]
        L.append("- Échelle par tempérament (place) : " + ", ".join(f"{DIFF_FR[k.split('/')[0]]} {TEMPER_FR.get(k.split('/')[1], k)} {f2(v['place'])}" for k, v in sorted(bt.items())))
    L.append("")
    # unités
    L.append(f"## Unités (plateaux finaux, mise en place « echelle », {res['main_n']} parties ; part Légende sur {res['leg_boards']} plateaux de Légende)")
    rows = []
    strong, weak = [], []
    for k, r in sorted(res["units"].items(), key=lambda kv: -kv[1]["rel_top4"]):
        c = res["units_carry"].get(k, {})
        fl = flag(r["rel_top4"]) if r["n"] >= mn else "(peu vu)"
        if r["n"] >= mn and r["rel_top4"] > 0.60:
            strong.append(names["units"].get(k, k))
        if r["n"] >= mn and r["rel_top4"] < 0.40:
            weak.append(names["units"].get(k, k))
        if show_all or fl:
            rows.append([names["units"].get(k, k), names["cost"].get(k, "?"), names["role"].get(k, ""), r["n"], f2(r["place"]),
                         f2(c["place"]) if c else "—", pct(r["top4"]), pct(r["rel_top4"]), pct(r["leg"]), fl])
    L.append(table(["Unité", "Coût", "Rôle", "Plateaux", "Place", "Place porteuse", "Top 4", "Top 4 relatif", "Part Légende", ""], rows))
    if strong:
        gaps.append(f"Unités trop fortes (top 4 relatif > 60 %) : {', '.join(strong)}.")
    if weak:
        gaps.append(f"Unités trop faibles (top 4 relatif < 40 %) : {', '.join(weak)}.")
    if res["unused_by_leg"]:
        L.append("")
        L.append("Jamais jouées par une Légende : " + ", ".join(names["units"].get(k, k) for k in res["unused_by_leg"]))
        gaps.append(f"{len(res['unused_by_leg'])} unité(s) jamais jouée(s) par une Légende : {', '.join(names['units'].get(k, k) for k in res['unused_by_leg'])}.")
    cost_place = defaultdict(list)
    for k, r in res["units_carry"].items():
        if r["n"] >= mn:
            cost_place[names["cost"].get(k, 0)].append(r["place"])
    L.append("")
    L.append("Place moyenne des unités porteuses d'objets, par coût : " + ", ".join(
        f"coût {c} : {f2(min(v))}-{f2(max(v))}" for c, v in sorted(cost_place.items())))
    L.append("")
    # traits
    L.append("## Traits par palier")
    rows = []
    hi_strong, hi_weak = [], []
    for t in sorted(names["traits"]):
        for tier in (1, 2, 3):
            r = res["traits"].get(f"{t}:{tier}")
            if not r:
                continue
            fl = flag(r["rel_top4"]) if r["n"] >= mn else "(peu vu)"
            if tier >= 2 and r["n"] >= mn and r["rel_top4"] > 0.60:
                hi_strong.append(f"{names['traits'][t]} {tier}")
            if tier >= 2 and r["n"] >= mn and r["rel_top4"] < 0.40:
                hi_weak.append(f"{names['traits'][t]} {tier}")
            rows.append([names["traits"][t], tier, r["n"], f2(r["place"]), pct(r["top4"]), pct(r["rel_top4"]), fl])
    L.append(table(["Trait", "Palier", "Plateaux", "Place", "Top 4", "Top 4 relatif", ""], rows))
    L.append("")
    L.append("Traits des Légende (actif / principal) : " + ", ".join(
        f"{names['traits'][t]} {pct(v[0])} / {pct(v[1])}" for t, v in sorted(res["leg_trait"].items(), key=lambda kv: -kv[1][1])))
    over = [names["traits"][t] for t, v in res["leg_trait"].items() if v[1] > 0.30]
    if over:
        gaps.append(f"Traits principaux de plus de 30 % des Légende : {', '.join(over)}.")
    if hi_strong:
        gaps.append(f"Paliers hauts trop forts : {', '.join(hi_strong)}.")
    if hi_weak:
        gaps.append(f"Paliers hauts trop faibles : {', '.join(hi_weak)}.")
    L.append("")
    # objets
    L.append("## Objets portés (plateaux finaux)")
    rows = []
    for k, r in sorted(res["items"].items(), key=lambda kv: -kv[1]["rel_top4"]):
        nm = names["items"].get(k) or names["components"].get(k) or k
        kind = "objet" if k in names["items"] else "composant"
        fl = flag(r["rel_top4"]) if r["n"] >= mn else "(peu vu)"
        if show_all or fl or kind == "composant":
            rows.append([nm, kind, r["n"], f2(r["place"]), pct(r["top4"]), pct(r["rel_top4"]), fl])
    L.append(table(["Objet", "Sorte", "Portés", "Place", "Top 4", "Top 4 relatif", ""], rows))
    it_s = [names["items"].get(k, k) for k, r in res["items"].items() if k in names["items"] and r["n"] >= mn and r["rel_top4"] > 0.6]
    it_w = [names["items"].get(k, k) for k, r in res["items"].items() if k in names["items"] and r["n"] >= mn and r["rel_top4"] < 0.4]
    if it_s:
        gaps.append(f"Objets trop forts : {', '.join(it_s)}.")
    if it_w:
        gaps.append(f"Objets trop faibles : {', '.join(it_w)}.")
    L.append("")
    # atouts
    L.append("## Atouts")
    rows = []
    a_bad = []
    for k, r in sorted(res["augs"].items(), key=lambda kv: kv[1]["place"] if kv[1]["n"] else 9):
        nm = names["augments"].get(k, k)
        fl = ""
        if r["n"] >= mn and not 4.0 <= r["place"] <= 5.0:
            fl = "place hors 4-5"
        if r["offered"] >= mn and r["pick_rate"] > 0.5:
            fl = (fl + " ; " if fl else "") + "pris > 50 %"
        if fl:
            a_bad.append(f"{nm} ({fl})")
        rows.append([nm, names["aug_rarity"].get(k, ""), r["offered"], r["picked"], pct(r["pick_rate"]), r["n"],
                     f2(r["place"]) if r["n"] else "—", pct(r["rel_top4"]) if r["n"] else "—", fl])
    L.append(table(["Atout", "Rareté", "Proposé", "Pris", "Taux de choix", "Parties", "Place", "Top 4 relatif", ""], rows))
    if a_bad:
        gaps.append(f"{len(a_bad)} atout(s) hors cible : " + ", ".join(a_bad) + ".")
    L.append("")
    # méta
    me = res["meta"]
    L.append("## Méta (compositions gagnantes : trait de famille + trait d'arme principaux du 1er)")
    L.append(f"{me['wins']} victoires, {me['distinct']} compositions distinctes (nombre effectif {f1(me['effective'])}) ; "
             f"la plus fréquente gagne {pct(me['top_share'])} des parties.")
    L.append("")
    L.append(table(["Composition", "Victoires", "Part"], [[" + ".join(names["traits"].get(t, t) for t in c.split("+")), n,
                                                          pct(n / max(me["wins"], 1))] for c, n in me["top"]]))
    L.append("")
    L.append("Familles des gagnants : " + ", ".join(f"{names['traits'].get(t, t)} {pct(n / max(me['wins'], 1))}" for t, n in me["fam"]))
    L.append("")
    L.append("Styles (traits d'arme) des gagnants : " + ", ".join(f"{names['traits'].get(t, t)} {pct(n / max(me['wins'], 1))}" for t, n in me["weap"]))
    L.append("")
    L.append(f"Entropie des compositions gagnantes : {f2(me['entropy'])} ; famille la plus fréquente chez les 1ers : "
             f"{pct(me['fam_top_share'])} ; plateau du 1er pris dans une seule famille : {pct(me['mono_mean'])} en moyenne, "
             f"{pct(me['mono6'])} des plateaux aux trois quarts d'une couleur.")
    L.append("")
    L.append(f"Paires de traits principaux du 1er (tous genres) : {me['pair_distinct']} distinctes (nombre effectif "
             f"{f1(me['pair_effective'])}), la plus fréquente {pct(me['pair_share'])} : " + ", ".join(
                 f"{' + '.join(names['traits'].get(t, t) for t in c.split('+'))} {n}" for c, n in me["pair_top"][:5]))
    if me["fam_top_share"] > 0.25:
        gaps.append(f"Une famille gagne {pct(me['fam_top_share'])} des parties (cible ≤ 25 %).")
    if me["top_share"] > 0.15:
        gaps.append(f"Méta resserrée : une composition gagne {pct(me['top_share'])} des parties.")
    L.append("")
    # économie
    L.append("## Économie (par stratège, mise en place « echelle »)")
    rows = []
    for dk in DIFFS:
        e = res["econ"].get(dk)
        if e:
            rows.append([DIFF_FR[dk], f1(e["gold"]), f1(e["income"]), f2(e["interest"]), f2(e["streak"]), f1(e["gold41"]),
                         f1(e["level41"]), f1(e["rerolls"]), f1(e["xp"]), f1(e["spent"]), f1(e["level"]), f2(e["s3"])])
    L.append(table(["Difficulté", "Or en banque / manche", "Revenu / manche", "Intérêts / manche", "Série / manche",
                    "Or à 4-1", "Niveau à 4-1", "Relances / partie", "Achats d'XP", "Or dépensé", "Niveau final", "★3 finales"], rows))
    L.append("")
    L.append(f"★3 sur les plateaux finaux : {f2(res['s3_per_game'])} par partie (8 plateaux).")
    return "\n".join(L), gaps


# --- Lancement des parties ------------------------------------------------------------------------------------------
def run_all(out_dir: Path, games: int, jobs: int, godot: str, project: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    per = math.ceil(games / jobs)
    cmds = []
    for k in range(jobs):
        cmds.append(["--games=%d" % per, "--seed=%d" % (1 + k * per), "--setup=echelle", f"--out={out_dir / f'echelle_{k}.jsonl'}"])
    for s in ("l7r", "r7l", "pilote", "legendes"):
        cmds.append(["--games=200", "--seed=1", f"--setup={s}", f"--out={out_dir / f'{s}.jsonl'}"])
    t0 = time.time()
    running: list = []
    while cmds or running:
        while cmds and len(running) < jobs:
            c = cmds.pop(0)
            running.append(subprocess.Popen([godot, "--headless", "--path", str(project), "res://tools/autochess_games.tscn",
                                             "--quit-after", "3", "--"] + c, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        time.sleep(2)
        running = [p for p in running if p.poll() is None]
    print(f"parties jouées en {time.time() - t0:.0f} s", file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--min", type=int, default=30, help="plateaux au moins pour juger une ligne (30)")
    ap.add_argument("--all", action="store_true", help="toutes les lignes (pas seulement celles hors cible)")
    ap.add_argument("--json", help="résumé chiffré (dictionnaire) écrit dans ce fichier")
    ap.add_argument("--run", help="dossier : lance les parties puis lit ce dossier")
    ap.add_argument("--games", type=int, default=2000)
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--godot", default=os.environ.get("GODOT", str(Path.home() / "Godot" / "Godot_v4.7.2-stable_win64_console.exe")))
    ap.add_argument("--project", default=str(ROOT / "game"))
    ap.add_argument("--data", help="dossier game/ dont lire les tables (noms, familles) ; défaut : ce dépôt")
    a = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    paths = list(a.paths)
    if a.run:
        run_all(Path(a.run), a.games, a.jobs, a.godot, Path(a.project))
        paths.append(a.run)
    games = read_games(paths)
    if not games:
        sys.exit("aucune partie lue")
    names = load_names(Path(a.data) if a.data else None)
    res = analyse(games, names, a.min)
    text, gaps = report(res, names, a.all)
    print(text)
    print()
    print("## Écarts aux cibles")
    for g in gaps:
        print("- " + g)
    if a.json:
        keep = {k: v for k, v in res.items() if k in ("fight", "game", "first_out", "first_min", "meta", "s3_per_game", "main_n")}
        keep["diff"] = {s: {"focal": d["focal"], "by": d["by"]} for s, d in res["diff"].items()}
        keep["gaps"] = gaps
        Path(a.json).write_text(json.dumps(keep, ensure_ascii=False, indent=1, default=str), encoding="utf-8")


if __name__ == "__main__":
    main()
