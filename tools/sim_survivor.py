#!/usr/bin/env python
"""Mesures d'équilibrage du Survivant (lot S7, conception/survivor/R_S7.md) : lance le pilote automatique
(world.tscn -- --survivor --autoplay) sur plusieurs classes / graines / profils de joueur, en parallèle, garde les
journaux bruts et résume minute par minute.

    python tools/sim_survivor.py --classes warrior,thief,hunter,cleric,magician --seeds 2 --human 0.3,0.5,0.7
    python tools/sim_survivor.py --reparse <dossier>          # relit des journaux déjà faits
    python tools/sim_survivor.py --project <copie>/game ...   # mesure une copie propre (run_tests.preparer_copie)

Collecte réelle (lot S9) : --extra=--human-magnet donne au pilote la zone de collecte d'un joueur (sinon 40 m : il ne va
pas chercher les orbes) ; lignes [sv-xp] (orbes au sol, reprises, expérience lâchée / ramassée).
Profils de joueur (--human : part des coups évités, SPEC §8.4) : débutant 0,3, moyen 0,5, bon 0,7. Le pilote prend ses
cartes avec SurvivorCards.auto_pick (un peu de hasard) et reste sur la carte jusqu'à l'entrée forcée de 20:00.
Chaque processus a son propre dossier utilisateur (APPDATA) : ni le profil ni le journal du joueur ne sont touchés.

Sortie : niveau du héros par minute (médiane), cartes prises, dégâts subis par minute (part des PV max), temps pour
vaincre les gardiens (5 / 10 / 15) et le boss, taux de victoire par profil, durée réelle de la run, builds de fin
(arme, set le plus porté, pièces à +10, sorts et niveaux, critique).
"""
import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

GODOT = r"C:\Users\Nico\Godot\Godot_v4.7.2-stable_win64_console.exe"
GAME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
PROFILES = {"0.3": "débutant", "0.5": "moyen", "0.7": "bon"}


def run_one(job):
    cls, seed, human, a, idx, out_dir, palier = job
    tag = ("p%d-" % palier if palier > 1 else "") + "%s_%d_%s" % (cls, seed, human)
    ud = os.path.join(out_dir, "ud", tag)
    os.makedirs(ud, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = ud
    env.pop("EDEN_PROFILE", None)
    log = os.path.join(out_dir, tag + ".log")
    cmd = [a.godot, "--headless", "--fixed-fps", "60", "--path", a.project, "res://scenes/world.tscn", "--", "--survivor", "--autoplay",
           "--auto-quit", "--class=" + cls, "--seed=%d" % seed, "--human=%s" % human, "--quit-at=%d" % a.quit_at,
           "--palier=%d" % palier] + (a.extra.split() if a.extra else [])
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        try:
            subprocess.run(cmd, env=env, stdout=f, stderr=subprocess.STDOUT, timeout=a.timeout)
        except subprocess.TimeoutExpired:
            f.write("\n[sim] délai dépassé\n")
    return parse(log)


def parse(log):
    name = os.path.basename(log)[:-4]
    cls, seed, human = name.rsplit("_", 2)
    palier = 1
    if cls.startswith("p") and "-" in cls:
        palier, cls = int(cls[1:cls.index("-")]), cls[cls.index("-") + 1:]
    out = open(log, encoding="utf-8", errors="replace").read()
    r = {"cls": cls, "seed": int(seed), "human": human, "palier": palier, "gold_spent": 0, "res": "?", "levels": {}, "cards": {}, "taken": {}, "maxhp": {},
         "gidx": {}, "guardians": {}, "log": log}
    for m in re.finditer(r"\[sv\] (\d+):00 · (\w+) · niveau (\d+) · PV (\d+) %.*?tués (\d+)(.*)", out):
        mi = int(m.group(1))
        r["levels"][mi] = int(m.group(3))
        rest = m.group(6)
        for key, pat in (("cards", r"cartes (\d+)"), ("taken", r"subis (\d+)"), ("maxhp", r"pv_max (\d+)"), ("gidx", r"indice ([\d.]+)")):
            mm = re.search(pat, rest)
            if mm:
                r[key][mi] = float(mm.group(1))
    # expérience (lot S9) : orbes au sol, reprises (sol plein), xp lâchée / ramassée cumulées
    r["xp"] = {}
    for m in re.finditer(r"\[sv-xp\] (\d+):00 · niveau \d+ · au sol (\d+) · posées \d+ · reprises (\d+) · xp lâchée (\d+) · ramassée (\d+)", out):
        r["xp"][int(m.group(1))] = {"ground": int(m.group(2)), "recycled": int(m.group(3)), "in": int(m.group(4)), "got": int(m.group(5))}
    for m in re.finditer(r"\[sv\] gardien (\d) vaincu en (\d+) s", out):
        r["guardians"][int(m.group(1))] = int(m.group(2))
    r["gold_spent"] = sum(int(x) for x in re.findall(r"\[sv\] pilote : marchand à [\d:]+, (\d+) or", out))
    golds = re.findall(r"\[sv\] \d+:00 · explore .*? or (\d+) ·", out)
    r["gold_20"] = int(golds[-1]) if golds else None
    r["script_errors"] = out.count("SCRIPT ERROR")
    m = re.search(r"\[sv\] entrée dans l'arène à (\d+):(\d+) \((\w+)\), niveau (\d+)", out)
    if m:
        r["arena_t"] = int(m.group(1)) * 60 + int(m.group(2))
        r["arena_lvl"] = int(m.group(4))
    m = re.search(r"\[sv\] boss vaincu à (\d+):(\d+) \((\d+) s dans l'arène\)", out)
    if m:
        r["boss_ttk"] = int(m.group(3))
    m = re.search(r"\[fin\] résultat=(\w+) niveau=(\d+) temps=(\d+)", out)
    if m:
        r.update(res=m.group(1), lvl=int(m.group(2)), t=int(m.group(3)))
    m = re.search(r"\[sv-build\] (.*)", out[out.rfind("[sv-build]"):] if "[sv-build]" in out else "")
    if m:
        r["build"] = m.group(1).strip()
    m = re.findall(r"\[sv-boss\] (.*)", out)
    if m:
        r["boss"] = m[-1]
    return r


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def fmt(x, f="%.0f"):
    return "-" if x is None else f % x


def summary(res):
    by = {}
    for r in res:
        by.setdefault(("p%d " % r.get("palier", 1)) + r["human"], []).append(r)
    print("\n=== Survivant : %d runs ===" % len(res))
    print("profil | runs | tient 10 min | 3 gardiens | boss atteint | victoire | durée médiane | niveau 5/10/15/20 | cartes à 20:00 | subis %PV/min | gardiens s | boss s")
    for h in sorted(by):
        rs = by[h]
        n = len(rs)
        t10 = sum(1 for r in rs if r.get("t", 0) >= 600 or r.get("arena_t"))
        g3 = sum(1 for r in rs if len(r["guardians"]) >= 3)
        reach = sum(1 for r in rs if r.get("arena_t"))
        won = sum(1 for r in rs if r.get("res") == "victoire")
        lv = [med([r["levels"].get(m) for r in rs]) for m in (5, 10, 15, 20)]
        cards20 = med([r["cards"].get(20) for r in rs])
        taken = []
        for r in rs:
            mins = sorted(k for k in r["taken"] if k in r["maxhp"] and r["maxhp"][k] > 0)
            for a_, b_ in zip(mins, mins[1:]):
                taken.append((r["taken"][b_] - r["taken"][a_]) / r["maxhp"][b_] * 100.0)
        gt = [med([r["guardians"].get(i) for r in rs]) for i in (1, 2, 3)]
        bt = med([r.get("boss_ttk") for r in rs])
        print("%s %s | %d | %d %% | %d %% | %d %% | %d %% | %s | %s | %s | %s | %s | %s" % (
            h, PROFILES.get(h.split()[-1], ""), n, 100 * t10 // n, 100 * g3 // n, 100 * reach // n, 100 * won // n, fmt(med([r.get("t") for r in rs])),
            "/".join(fmt(x) for x in lv), fmt(cards20), fmt(med(taken)), "/".join(fmt(x) for x in gt), fmt(bt)))
    print("\nniveau par minute (médiane, tous profils) : " + " ".join("%d:%s" % (m, fmt(med([r["levels"].get(m) for r in res]))) for m in range(1, 21)))
    print("or : restant à la dernière minute de carte (médiane) %s ; marchands %s or (médiane) ; erreurs de script %d" % (
        fmt(med([r.get("gold_20") for r in res])), fmt(med([r.get("gold_spent") for r in res])), sum(r.get("script_errors", 0) for r in res)))
    coll = [r["xp"][max(r["xp"])]["got"] / max(1, r["xp"][max(r["xp"])]["in"]) for r in res if r.get("xp")]
    if coll:
        print("expérience ramassée / lâchée (médiane) : %d %% ; orbes reprises (sol plein) : %s" % (
            round(100 * statistics.median(coll)), [r["xp"][max(r["xp"])]["recycled"] for r in res if r.get("xp")]))
    deaths = sorted(r.get("t", 0) for r in res if r.get("res") == "defaite")
    print("défaites : %d, minutes de mort : %s" % (len(deaths), [round(t / 60.0, 1) for t in deaths]))
    for r in res:
        print("  %-9s %d %s : %-9s t=%s niv=%s gardiens=%s arène=%s boss=%s | %s | %s" % (r["cls"], r["seed"], r["human"], r.get("res"), r.get("t"), r.get("lvl"),
              r["guardians"], r.get("arena_t"), r.get("boss_ttk"), r.get("build", ""), r.get("boss", "")))


def probe_one(job):
    cls, strategy, seed, a, out_dir = job
    ud = os.path.join(out_dir, "ud", "p_%s_%s_%d" % (cls, strategy, seed))
    os.makedirs(ud, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = ud
    env.pop("EDEN_PROFILE", None)
    cmd = [a.godot, "--headless", "--fixed-fps", "60", "--path", a.project, "res://tools/sv_build_probe.tscn", "--", "--class=" + cls,
           "--strategy=" + strategy, "--seed=%d" % seed, "--level=%d" % a.level, "--chests=%d" % a.chests, "--free=%d" % a.free,
           "--max=%d" % a.max] + (["--fight"] if a.fight else [])
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900).stdout
    except subprocess.TimeoutExpired:
        return None
    m = re.findall(r"\[probe\] (.*)", out)
    if not m:
        return None
    r = dict(kv.split("=", 1) for kv in m[-1].split() if "=" in kv)
    return r


def probe_summary(rows, rage):
    """Dominance (lot S7) : par type de build (stratégie, arme, famille du set le plus porté), part des builds qui battent le
    boss avant la rage (TTK ≤ rage) et DPS médian ; le meilleur type ne doit pas gagner 3 fois plus souvent que le type médian."""
    rows = [r for r in rows if r and "ttk" in r]
    print("\n=== Sonde de builds : %d builds (boss %s PV) ===" % (len(rows), rows[0].get("pv_boss") if rows else "-"))
    ttks = sorted(float(r["ttk"]) for r in rows)
    if not ttks:
        return {}
    q = lambda p: ttks[min(len(ttks) - 1, int(p * len(ttks)))]
    print("TTK du boss (s) : 10 %% %.0f · 25 %% %.0f · médiane %.0f · 75 %% %.0f · 90 %% %.0f ; battu avant la rage (%d s) : %d %%" % (
        q(0.1), q(0.25), q(0.5), q(0.75), q(0.9), rage, 100 * sum(1 for t in ttks if t <= rage) // len(ttks)))
    out = {}
    for key in ("stratégie", "arme", "set", "classe"):
        groups = {}
        for r in rows:
            k = r.get(key, "-")
            if key == "set":
                k = k.split(":")[0] + (":3+" if int(k.split(":")[1]) >= 3 else ":<3") if ":" in k else k
            groups.setdefault(k, []).append(r)
        stats = []
        for k, rs in groups.items():
            if len(rs) < 4:
                continue
            win = sum(1 for r in rs if float(r["ttk"]) <= rage) / len(rs)
            dps = statistics.median(float(r["dps"]) for r in rs)
            stats.append((k, len(rs), win, dps))
        if not stats:
            continue
        stats.sort(key=lambda s: -s[3])
        wins = sorted(s[2] for s in stats)
        dpss = sorted(s[3] for s in stats)
        mw = statistics.median(wins)
        md = statistics.median(dpss)
        ratio_w = (max(wins) / mw) if mw > 0 else float("inf") if max(wins) > 0 else 1.0
        ratio_d = max(dpss) / md if md > 0 else float("inf")
        print("par %s : %s" % (key, " · ".join("%s (%d) %.0f %% %.0fk" % (k, n, 100 * w, d / 1000) for k, n, w, d in stats)))
        print("   meilleur / médian : victoires ×%.2f, DPS ×%.2f" % (ratio_w, ratio_d))
        out[key] = {"win_ratio": ratio_w, "dps_ratio": ratio_d, "groups": [{"k": k, "n": n, "win": w, "dps": d} for k, n, w, d in stats]}
    for k in ("crit", "mcrit", "critdmg", "vit", "recharge", "plafond", "s10", "évolutions", "plus10"):
        vals = [float(r[k]) for r in rows if k in r]
        if vals:
            print("   %s : médiane %.2f, max %.2f" % (k, statistics.median(vals), max(vals)))
    out["ttk"] = {"q10": q(0.1), "q25": q(0.25), "median": q(0.5), "q75": q(0.75), "q90": q(0.9)}
    out["n"] = len(rows)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true", help="sonde de builds (dominance) au lieu des runs au pilote")
    ap.add_argument("--strategies", default="pilote,bot,set,sorts,arme,pieces,passifs")
    ap.add_argument("--level", type=int, default=38)
    ap.add_argument("--chests", type=int, default=12)
    ap.add_argument("--free", type=int, default=6)
    ap.add_argument("--max", type=int, default=150)
    ap.add_argument("--fight", action="store_true")
    ap.add_argument("--rage", type=int, default=240)
    ap.add_argument("--classes", default="warrior,thief,hunter,cleric,magician")
    ap.add_argument("--seeds", type=int, default=1)
    ap.add_argument("--seed-base", dest="seed_base", type=int, default=1000)
    ap.add_argument("--human", default="0.3,0.5,0.7")
    ap.add_argument("--palier", default="1", help="palier(s) I à V, liste possible : 1,2,3")
    ap.add_argument("--quit-at", dest="quit_at", type=int, default=1800)
    ap.add_argument("--timeout", type=int, default=7200)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--project", default=GAME)
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--out", default="")
    ap.add_argument("--extra", default="")
    ap.add_argument("--reparse", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    for flux in (sys.stdout, sys.stderr):
        try:
            flux.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if a.probe:
        out_dir = a.out or tempfile.mkdtemp(prefix="sv_probe_")
        os.makedirs(out_dir, exist_ok=True)
        jobs = [(cls, st, a.seed_base + s, a, out_dir) for s in range(a.seeds) for st in a.strategies.split(",") for cls in a.classes.split(",")]
        with ThreadPoolExecutor(max_workers=a.jobs) as ex:
            rows = list(ex.map(probe_one, jobs))
        rows = [r for r in rows if r]
        summ = probe_summary(rows, a.rage) if a.fight else {}
        if a.json:
            with open(a.json, "w", encoding="utf-8") as f:
                json.dump({"rows": rows, "summary": summ}, f, ensure_ascii=False, indent=1)
        if not a.fight:
            for r in rows:
                print(r)
        return
    if a.reparse:
        res = [parse(os.path.join(a.reparse, f)) for f in sorted(os.listdir(a.reparse)) if f.endswith(".log")]
    else:
        out_dir = a.out or tempfile.mkdtemp(prefix="sim_survivor_")
        os.makedirs(out_dir, exist_ok=True)
        print("journaux : %s" % out_dir, flush=True)
        jobs = []
        for pal in [int(x) for x in str(a.palier).split(",")]:
            for s in range(a.seeds):
                for h in a.human.split(","):
                    for cls in a.classes.split(","):
                        jobs.append((cls, a.seed_base + s * 7919, h, a, len(jobs), out_dir, pal))
        with ThreadPoolExecutor(max_workers=a.jobs) as ex:
            res = list(ex.map(run_one, jobs))
    summary(res)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(res, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
