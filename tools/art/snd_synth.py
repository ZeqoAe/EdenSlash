"""Bibliothèque de sons d'interface d'Eden Slash (département SND, lot SND-1), entièrement synthétisée.

Aucun échantillon extérieur : chaque son est calculé ici (numpy / scipy) à partir d'oscillateurs, d'enveloppes,
de bruit filtré et d'une petite réverbération synthétique. Graine fixe : relancer le script refait les mêmes fichiers.

    python tools/art/snd_synth.py              # écrit game/assets/sfx/ui/*.wav + conception/art/snd/index.md
    python tools/art/snd_synth.py --only hover # quelques sons seulement (préfixe du nom)
    python tools/art/snd_synth.py --preview    # + conception/art/snd/ecoute_planche.ogg (tous les sons à la suite, ffmpeg)

Matière (bible § 11) : jouet — bois, plastique, carillon, papier ; gamme pentatonique de do (do ré mi sol la) pour
que deux sons qui se suivent ne frottent jamais ; attaques douces (≥ 1 ms), aucun aigu perçant (passe-bas 9-11 kHz).
Format : WAV PCM 16 bits, 44,1 kHz, mono, même sonie pour tous (NOMINAL, crête ≤ -1 dBFS) ; le volume de chaque rôle
est réglé dans le jeu (UiFeel.SOUNDS, appels Sfx.ui).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import zlib

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "sfx", "ui")
DOC = os.path.join(ROOT, "conception", "art", "snd")
PEAK = 10 ** (-1.0 / 20.0)  # -1 dBFS : plafond de crête
NOMINAL = -20.0  # sonie de référence (dB, pondération K, 50 ms) : celle du son « confirm » du jeu (UI007) ; le volume de
                 # chaque rôle se règle ensuite en dB dans le jeu (UiFeel.SOUNDS, appels Sfx.ui)

# --- notes (pentatonique de do) ----------------------------------------------------------------
_N = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def hz(name: str) -> float:
    """« C5 », « G#4 »… -> fréquence (la4 = 440)."""
    n, rest = name[0], name[1:]
    alt = 0
    if rest.startswith("#"):
        alt, rest = 1, rest[1:]
    elif rest.startswith("b"):
        alt, rest = -1, rest[1:]
    semis = _N[n] + alt + (int(rest) - 4) * 12
    return 440.0 * 2 ** (semis / 12.0)


# --- briques ------------------------------------------------------------------------------------
def _rng(key: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(key.encode("utf-8")))


def tl(d: float) -> np.ndarray:
    return np.arange(int(round(d * SR))) / SR


def silence(d: float) -> np.ndarray:
    return np.zeros(int(round(d * SR)))


def attack(n: int, a: float) -> np.ndarray:
    """Montée en demi-cosinus de [a] secondes (jamais de marche : pas de clic)."""
    k = max(int(a * SR), 8)
    e = np.ones(n)
    k = min(k, n)
    e[:k] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, k))
    return e


def decay(t: np.ndarray, tau: float) -> np.ndarray:
    return np.exp(-t / max(tau, 1e-4))


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)


def bp(x: np.ndarray, f1: float, f2: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, [f1, min(f2, SR * 0.45)], "band", fs=SR, output="sos"), x)


def svf_sweep(x: np.ndarray, f0: float, f1: float, q: float = 1.2, curve: float = 1.0) -> np.ndarray:
    """Passe-bande à état variable dont la fréquence glisse de f0 à f1 (souffle, papier, élan)."""
    n = len(x)
    k = np.linspace(0.0, 1.0, n) ** curve
    fc = f0 * (f1 / f0) ** k
    g = 2.0 * np.sin(np.pi * np.minimum(fc, SR * 0.2) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band += g[i] * high
        low += g[i] * band
        out[i] = band
    return out


def place(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> np.ndarray:
    """Ajoute [src] dans [dst] à [at] secondes (allonge dst au besoin)."""
    i = int(round(at * SR))
    need = i + len(src)
    if need > len(dst):
        dst = np.concatenate([dst, np.zeros(need - len(dst))])
    dst[i:i + len(src)] += src * gain
    return dst


def mix(*parts: tuple) -> np.ndarray:
    """mix((son, instant, gain), …)."""
    out = np.zeros(1)
    for p in parts:
        s, at = p[0], p[1]
        g = p[2] if len(p) > 2 else 1.0
        out = place(out, s, at, g)
    return out


# --- instruments --------------------------------------------------------------------------------
def marimba(f: float, d: float = 0.35, bright: float = 1.0, key: str = "m") -> np.ndarray:
    """Lame de bois frappée : fondamentale + partiels 3,93 et 9,2 qui s'éteignent vite + toucher de maillet."""
    t = tl(d)
    x = np.sin(2 * np.pi * f * t) * decay(t, d * 0.32)
    x += 0.30 * bright * np.sin(2 * np.pi * f * 3.93 * t) * decay(t, 0.028)
    x += 0.06 * bright * np.sin(2 * np.pi * f * 9.2 * t) * decay(t, 0.010)
    m = _rng(key + str(f)).standard_normal(len(t)) * decay(t, 0.003)
    x += 0.10 * bright * bp(m, min(f * 2.0, 6000), min(f * 5.0, 9000))
    return x * attack(len(t), 0.0012)


def bell(f: float, d: float = 0.8, bright: float = 1.0) -> np.ndarray:
    """Carillon / glockenspiel : partiels 1 ; 2,76 ; 5,40 ; 8,93 (lame de métal), décroissances échelonnées."""
    t = tl(d)
    parts = [(1.0, 1.0, 0.45), (2.76, 0.42, 0.22), (5.40, 0.20, 0.10), (8.93, 0.08, 0.05)]
    x = np.zeros(len(t))
    for r, a, tau in parts:
        if f * r < SR * 0.42:
            x += a * (bright if r > 1 else 1.0) * np.sin(2 * np.pi * f * r * t) * decay(t, d * tau)
    return x * attack(len(t), 0.0015)


def celesta(f: float, d: float = 0.6) -> np.ndarray:
    """Clochette douce et ronde (harmoniques entières), pour les accords tenus."""
    t = tl(d)
    x = np.sin(2 * np.pi * f * t) * decay(t, d * 0.4)
    x += 0.35 * np.sin(2 * np.pi * 2 * f * t) * decay(t, d * 0.18)
    x += 0.12 * np.sin(2 * np.pi * 3 * f * t) * decay(t, d * 0.08)
    return x * attack(len(t), 0.003)


def fm_pluck(f: float, d: float = 0.3, ratio: float = 1.0, index: float = 2.0) -> np.ndarray:
    """Pincé FM doux (indice qui retombe vite : son de jouet en plastique)."""
    t = tl(d)
    ind = index * decay(t, d * 0.12)
    x = np.sin(2 * np.pi * f * t + ind * np.sin(2 * np.pi * f * ratio * t)) * decay(t, d * 0.3)
    return x * attack(len(t), 0.0012)


def wood(f: float, d: float = 0.05, key: str = "w", grit: float = 0.35) -> np.ndarray:
    """Bloc de bois : tonalité courte + partiel 2,3 + éclat de bruit filtré."""
    t = tl(d)
    x = np.sin(2 * np.pi * f * t) * decay(t, d * 0.25)
    x += 0.35 * np.sin(2 * np.pi * f * 2.31 * t) * decay(t, d * 0.12)
    n = _rng(key + str(f)).standard_normal(len(t)) * decay(t, 0.0025)
    x += grit * bp(n, f * 0.8, min(f * 3.0, 9000))
    return x * attack(len(t), 0.0008)


def pop(f0: float, f1: float, d: float = 0.05, tau: float = 0.018) -> np.ndarray:
    """« Pop » de bulle : sinus dont la hauteur glisse de f0 à f1."""
    t = tl(d)
    f = f0 * (f1 / f0) ** np.clip(t / (d * 0.6), 0, 1)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * decay(t, tau) * attack(len(t), 0.0008)


def noise(d: float, key: str) -> np.ndarray:
    return _rng(key).standard_normal(int(round(d * SR)))


def swish(d: float, f0: float, f1: float, key: str, q: float = 1.4, shape: float = 0.5) -> np.ndarray:
    """Souffle filtré qui glisse (élan, page, carte) : enveloppe en cloche dissymétrique."""
    x = svf_sweep(noise(d, key), f0, f1, q)
    t = np.linspace(0, 1, len(x))
    env = np.sin(np.pi * np.clip(t, 0, 1) ** shape) ** 2
    return x * env


def metal(f: float, d: float, key: str, soft: float = 1.0) -> np.ndarray:
    """Métal inharmonique (enclume, pièce) : partiels non entiers, décroissances différentes."""
    t = tl(d)
    ratios = [1.0, 2.41, 3.87, 5.32, 6.95]
    amps = [1.0, 0.6, 0.4, 0.22, 0.12]
    taus = [0.5, 0.32, 0.2, 0.12, 0.07]
    rng = _rng(key)
    x = np.zeros(len(t))
    for r, a, tau in zip(ratios, amps, taus):
        fr = f * r * (1 + rng.uniform(-0.01, 0.01))
        if fr < SR * 0.42:
            x += a * np.sin(2 * np.pi * fr * t + rng.uniform(0, 6.28)) * decay(t, d * tau * soft)
    return x * attack(len(t), 0.001)


def thump(f0: float, f1: float, d: float, key: str, body: float = 0.5) -> np.ndarray:
    """Coup feutré : pop grave + bruit étouffé (coussin, tambour d'enfant)."""
    x = pop(f0, f1, d, d * 0.35)
    n = lp(noise(d, key), 900) * decay(tl(d), 0.012)
    return x + body * n


def room(x: np.ndarray, mix_: float = 0.15, size: float = 0.35, key: str = "room", bright: float = 3500) -> np.ndarray:
    """Petite pièce synthétique (convolution avec un bruit qui s'éteint) : colle les sons entre eux."""
    if mix_ <= 0:
        return x
    n = int(size * SR)
    ir = lp(_rng(key).standard_normal(n), bright) * np.exp(-np.arange(n) / (size * SR / 6.0))
    ir[: int(0.004 * SR)] = 0.0  # pré-délai 4 ms
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(np.concatenate([x, np.zeros(n)]), ir)[: len(x) + n]
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - mix_) + wet * mix_ * 1.6


def arp(notes: list, step: float, inst, d: float, gains=None, **kw) -> np.ndarray:
    out = np.zeros(1)
    for i, nt in enumerate(notes):
        g = gains[i] if gains else 1.0
        out = place(out, inst(hz(nt) if isinstance(nt, str) else nt, d, **kw), i * step, g)
    return out


# --- finition -----------------------------------------------------------------------------------
def finish(x: np.ndarray, lowcut: float = 70.0, highcut: float = 10500.0, tail_db: float = -54.0) -> np.ndarray:
    """Passe-haut / passe-bas doux, sans continu, queue coupée sous -60 dB puis fondu, crête à -1 dBFS."""
    x = np.asarray(x, dtype=np.float64)
    x = hp(x, lowcut, 2)
    x = lp(x, highcut, 4)
    x -= np.mean(x)
    pk = np.max(np.abs(x)) + 1e-12
    thr = pk * 10 ** (tail_db / 20)
    idx = np.nonzero(np.abs(x) > thr)[0]
    end = min(len(x), (idx[-1] if len(idx) else len(x) - 1) + int(0.010 * SR))
    x = x[:end]
    fo = min(int(0.008 * SR), len(x) // 3)
    x[-fo:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fo))
    x *= attack(len(x), 0.0008)
    x = np.tanh(x / pk * 1.15) / np.tanh(1.15)  # saturation très douce : un peu de chaleur, crêtes arrondies
    x -= np.mean(x)
    x[0] = 0.0
    x[-1] = 0.0
    return x / (np.max(np.abs(x)) + 1e-12) * PEAK


def _shelf(x: np.ndarray, f0: float, gain_db: float) -> np.ndarray:
    """Plateau aigu (RBJ) : sert à la pondération K."""
    a = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / 2 * np.sqrt(2)
    c = np.cos(w0)
    b0 = a * ((a + 1) + (a - 1) * c + 2 * np.sqrt(a) * al)
    b1 = -2 * a * ((a - 1) + (a + 1) * c)
    b2 = a * ((a + 1) + (a - 1) * c - 2 * np.sqrt(a) * al)
    a0 = (a + 1) - (a - 1) * c + 2 * np.sqrt(a) * al
    a1 = 2 * ((a - 1) - (a + 1) * c)
    a2 = (a + 1) - (a - 1) * c - 2 * np.sqrt(a) * al
    from scipy.signal import lfilter
    return lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x)


def loudness(x: np.ndarray) -> float:
    """Sonie courte : RMS maximal sur 50 ms après pondération K (BS.1770 : coupe-grave 100 Hz, aigu +4 dB)."""
    k = _shelf(hp(x, 100.0, 2), 1680.0, 4.0)
    w = int(0.050 * SR)
    sq = np.convolve(k ** 2, np.ones(w) / w, mode="valid") if len(k) > w else np.array([np.mean(k ** 2)])
    return 10 * np.log10(np.max(sq) + 1e-12)


def level(x: np.ndarray) -> np.ndarray:
    """Amène le son à la sonie NOMINAL (crête plafonnée à -1 dBFS)."""
    x = x * 10 ** ((NOMINAL - loudness(x)) / 20)
    pk = np.max(np.abs(x))
    return x * (PEAK / pk) if pk > PEAK else x


# --- la bibliothèque ----------------------------------------------------------------------------
# Chaque entrée : nom -> (fonction, description, usage en jeu, groupe). Les fonctions renvoient le signal brut.
def s_hover(v: int):
    f = [1900.0, 2050.0, 1780.0][v]
    x = wood(f, 0.035, key=f"hover{v}", grit=0.25)
    x = place(x, marimba(f * 0.5, 0.05, 0.4, key=f"hv{v}"), 0.0, 0.25)
    return lp(x, 6500)


def s_focus(v: int):
    f = hz(["E6", "D6", "G6"][v])
    return room(place(marimba(f, 0.09, 0.6, key=f"focus{v}"), wood(f * 1.5, 0.02, key=f"fo{v}"), 0.0, 0.2), 0.08, 0.18, key=f"rf{v}")


def s_press(v: int):
    a, b = [(420.0, 780.0), (460.0, 830.0), (390.0, 720.0)][v]
    x = place(pop(a, b, 0.06, 0.016), wood(b * 1.6, 0.02, key=f"press{v}", grit=0.4), 0.0, 0.25)
    return lp(x, 4000)


def s_release(v: int):
    f = [1250.0, 1340.0, 1180.0][v]
    x = wood(f, 0.05, key=f"rel{v}", grit=0.3)
    x = place(x, 0.45 * pop(f * 1.4, f * 1.9, 0.03, 0.01), 0.004)
    return room(x, 0.06, 0.15, key=f"rr{v}")


def s_primary(_v: int):
    x = pop(380.0, 760.0, 0.07, 0.02)
    x = place(x, 0.55 * bell(hz("C6"), 0.45), 0.035)
    x = place(x, 0.50 * bell(hz("G6"), 0.55), 0.105)
    return room(x, 0.18, 0.4, key="prim")


def s_confirm(_v: int):
    x = mix((marimba(hz("A5"), 0.25, 0.8, key="cf1"), 0.0, 0.8), (marimba(hz("E6"), 0.35, 0.8, key="cf2"), 0.07, 0.9),
            (celesta(hz("E6"), 0.4), 0.07, 0.25))
    return room(x, 0.14, 0.35, key="conf")


def s_deny(_v: int):
    x = pop(300.0, 205.0, 0.16, 0.06) * 0.9
    x = place(x, pop(620.0, 410.0, 0.08, 0.02), 0.0, 0.35)
    x = place(x, thump(160.0, 110.0, 0.12, key="deny", body=0.4), 0.0, 0.3)
    x = place(x, 0.35 * marimba(hz("D4"), 0.18, 0.3, key="dn"), 0.06)
    return lp(x, 2600)


def s_tab(_v: int):
    x = swish(0.10, 900.0, 3800.0, key="tab", q=1.1, shape=0.6) * 0.8
    x = place(x, 0.45 * wood(1900.0, 0.02, key="tabk", grit=0.35), 0.07)
    return room(x, 0.08, 0.18, key="rtab")


def s_toggle(on: bool):
    a, b = (900.0, 1500.0) if on else (1300.0, 850.0)
    x = mix((wood(a, 0.03, key=f"tg{on}a", grit=0.4), 0.0, 0.8), (wood(b, 0.04, key=f"tg{on}b", grit=0.3), 0.038, 1.0))
    return room(x, 0.06, 0.15, key="rtg")


def s_swoosh(_v: int):
    x = swish(0.24, 380.0, 2200.0, key="swoosh", q=0.9, shape=0.45)
    x = place(x, 0.35 * wood(1500.0, 0.025, key="swk"), 0.0)
    return room(x, 0.12, 0.3, key="rsw")


def s_equip(_v: int):
    x = mix((wood(820.0, 0.04, key="eq1", grit=0.5), 0.0, 1.0), (wood(1250.0, 0.04, key="eq2", grit=0.3), 0.022, 0.7),
            (bell(hz("E6") * 1.0, 0.22, bright=0.6), 0.03, 0.35))
    return room(x, 0.1, 0.25, key="req")


def s_open(_v: int):
    x = swish(0.16, 500.0, 2600.0, key="open", q=1.0, shape=0.7) * 0.7
    x = place(x, 0.8 * fm_pluck(hz("G5"), 0.25, 2.0, 1.2), 0.11)
    x = place(x, 0.4 * fm_pluck(hz("C6"), 0.25, 2.0, 1.0), 0.15)
    return room(x, 0.12, 0.3, key="ropen")


def s_close(_v: int):
    x = swish(0.15, 2600.0, 520.0, key="close", q=1.0, shape=0.35) * 0.7
    x = place(x, 0.7 * fm_pluck(hz("C5"), 0.22, 2.0, 0.9), 0.10)
    return room(x, 0.10, 0.3, key="rclose")


def s_card_flip(_v: int):
    a = bp(noise(0.03, "flip1"), 1800, 5200) * decay(tl(0.03), 0.006)
    b = bp(noise(0.03, "flip2"), 1500, 4500) * decay(tl(0.03), 0.007)
    x = mix((swish(0.12, 800.0, 3000.0, key="flipw", q=0.9, shape=0.5), 0.0, 0.5), (a, 0.02, 0.9), (b, 0.085, 0.8),
            (marimba(hz("C6"), 0.12, 0.4, key="flipm"), 0.09, 0.25))
    return room(x, 0.1, 0.2, key="rflip")


def s_card_pick(_v: int):
    x = swish(0.18, 1200.0, 6000.0, key="pick", q=1.6, shape=0.5) * 0.45
    x = place(x, 0.6 * bell(hz("E6"), 0.5), 0.10)
    x = place(x, 0.45 * bell(hz("A6"), 0.55), 0.14)
    x = place(x, 0.25 * bell(hz("E7"), 0.3, bright=0.4), 0.18)
    return room(x, 0.2, 0.45, key="rpick")


def s_notify(_v: int):
    x = mix((marimba(hz("G5"), 0.3, 0.9, key="nt1"), 0.0, 0.9), (marimba(hz("D6"), 0.45, 0.9, key="nt2"), 0.12, 1.0),
            (celesta(hz("D6"), 0.5), 0.12, 0.25))
    return room(x, 0.16, 0.4, key="rnot")


def s_tick(_v: int):
    return room(place(wood(1150.0, 0.07, key="tick", grit=0.3), marimba(hz("G5"), 0.08, 0.2, key="tk"), 0.0, 0.3), 0.06, 0.15, key="rtick")


def s_go(_v: int):
    x = mix((celesta(hz("C6"), 0.7), 0.0, 0.6), (celesta(hz("E6"), 0.7), 0.0, 0.5), (celesta(hz("G6"), 0.7), 0.0, 0.45),
            (marimba(hz("C5"), 0.4, 1.0, key="go"), 0.0, 0.7), (swish(0.2, 1500.0, 5000.0, key="gow", q=1.2), 0.0, 0.25))
    return room(x, 0.2, 0.5, key="rgo")


def s_coin(v: int):
    rng = _rng(f"coin{v}")
    f1, f2 = [(2650.0, 3420.0), (2880.0, 3610.0), (2500.0, 3300.0)][v]
    gap = [0.045, 0.055, 0.04][v]
    x = mix((metal(f1, 0.18, key=f"c{v}a", soft=0.5), 0.0, 0.8), (metal(f2, 0.22, key=f"c{v}b", soft=0.55), gap, 0.7),
            (wood(1800.0 + rng.uniform(-80, 80), 0.02, key=f"ck{v}", grit=0.6), 0.0, 0.3))
    return room(lp(x, 6500, 4), 0.1, 0.25, key="rcoin")


def s_forge_ok(_v: int):
    x = metal(hz("A5"), 0.7, key="anvil", soft=0.8) * 0.7
    x = place(x, lp(noise(0.03, "anvn"), 4000) * decay(tl(0.03), 0.004), 0.0, 0.25)
    x = place(x, arp(["C6", "E6", "G6", "C7"], 0.06, bell, 0.5, gains=[0.35, 0.35, 0.4, 0.3]), 0.12)
    return room(x, 0.2, 0.55, key="rforge")


def s_forge_fail(_v: int):
    x = lp(metal(260.0, 0.35, key="clonk", soft=0.4), 1800) * 0.9
    x = place(x, thump(150.0, 90.0, 0.12, key="clth"), 0.0, 0.4)
    puff = lp(noise(0.35, "puff"), 1600)
    puff *= np.sin(np.pi * np.linspace(0, 1, len(puff))) ** 2
    x = place(x, 0.18 * puff, 0.06)
    x = place(x, arp(["D5", "A4"], 0.13, marimba, 0.35, gains=[0.45, 0.4], bright=0.4), 0.16)
    return room(x, 0.14, 0.4, key="rfail")


def s_hit(v: int):
    f0, f1 = [(210.0, 120.0), (230.0, 130.0), (195.0, 110.0)][v]
    x = thump(f0, f1, 0.09, key=f"hit{v}", body=0.7)
    x = place(x, bp(noise(0.02, f"hs{v}"), 900, 2600) * decay(tl(0.02), 0.004), 0.0, 0.15)
    return lp(x, 2400)


_REWARD = {
    1: (["C5", "E5"], 0.075, 0.0, 0.10),
    2: (["C5", "E5", "G5"], 0.07, 0.15, 0.13),
    3: (["C5", "E5", "G5", "C6"], 0.065, 0.3, 0.16),
    4: (["C5", "E5", "G5", "A5", "C6"], 0.06, 0.45, 0.19),
    5: (["G4", "C5", "E5", "G5", "C6", "E6"], 0.058, 0.7, 0.22),
}


def s_reward(r: int):
    notes, step, shine, rv = _REWARD[r]
    x = arp(notes, step, marimba, 0.4, bright=0.8)
    end = step * (len(notes) - 1)
    if shine > 0:
        top = notes[-1]
        x = place(x, shine * bell(hz(top) * 2, 0.4 + 0.3 * r * 0.25), end + 0.02)
    if r >= 3:
        for i, nt in enumerate(["C6", "E6", "G6"][: r - 2]):
            x = place(x, 0.22 * celesta(hz(nt), 0.5 + 0.15 * r), end + 0.03 + 0.01 * i)
    if r >= 4:
        x = place(x, 0.12 * swish(0.25, 3000.0, 8000.0, key=f"rw{r}", q=2.0), end)
    if r == 5:
        x = place(x, arp(["C7", "G7", "E7"], 0.05, bell, 0.25, gains=[0.18, 0.14, 0.12], bright=0.3), end + 0.12)
        x = place(x, 0.35 * marimba(hz("C4"), 0.5, 0.3, key="rwb"), end)
    return room(x, rv, 0.5 + 0.06 * r, key=f"rrew{r}")


def s_level_up(_v: int):
    x = arp(["C5", "D5", "E5", "G5", "A5", "C6"], 0.05, marimba, 0.3, bright=0.9)
    t0 = 0.30
    for i, (nt, g) in enumerate([("C6", 0.5), ("E6", 0.42), ("G6", 0.38), ("C7", 0.2)]):
        x = place(x, g * celesta(hz(nt), 0.9), t0 + 0.012 * i)
    x = place(x, 0.4 * bell(hz("G6"), 0.6), t0)
    x = place(x, 0.5 * marimba(hz("C4"), 0.6, 0.4, key="lvb"), t0)
    x = place(x, 0.12 * swish(0.4, 2500.0, 8000.0, key="lvw", q=2.0), t0 - 0.05)
    return room(x, 0.2, 0.6, key="rlvl")


def s_star(_v: int):
    x = 0.25 * swish(0.12, 3000.0, 9000.0, key="starw", q=2.2, shape=0.4)
    x = place(x, 0.8 * bell(hz("E6"), 0.5), 0.05)
    x = place(x, 0.4 * bell(hz("B6"), 0.4, bright=0.6), 0.075)
    x = place(x, 0.2 * bell(hz("E7"), 0.25, bright=0.3), 0.10)
    return room(x, 0.2, 0.45, key="rstar")


def s_record(_v: int):
    x = mix((marimba(hz("A5"), 0.18, 0.9, key="rc1"), 0.0, 0.8), (marimba(hz("A5"), 0.18, 0.9, key="rc2"), 0.09, 0.7),
            (marimba(hz("D6"), 0.25, 0.9, key="rc3"), 0.18, 0.85))
    t0 = 0.30
    for i, (nt, g) in enumerate([("D6", 0.45), ("G6", 0.38), ("A6", 0.3), ("D7", 0.15)]):
        x = place(x, g * celesta(hz(nt), 0.8), t0 + 0.015 * i)
    x = place(x, 0.5 * bell(hz("A6"), 0.6), t0)
    x = place(x, 0.45 * marimba(hz("D4"), 0.6, 0.4, key="rcb"), t0)
    x = place(x, 0.4 * pop(160.0, 70.0, 0.15, 0.05), t0)
    return room(x, 0.2, 0.6, key="rrec")


def s_victory(_v: int):
    mel = [("C5", 0.0), ("E5", 0.11), ("G5", 0.22), ("A5", 0.38), ("G5", 0.49), ("E6", 0.62)]
    x = np.zeros(1)
    for nt, at in mel:
        x = place(x, marimba(hz(nt), 0.35, 0.9, key="vm" + nt), at, 0.85)
    t0 = 0.78
    for nt, g in [("C6", 0.5), ("E6", 0.45), ("G6", 0.4), ("C7", 0.22)]:
        x = place(x, g * celesta(hz(nt), 1.3), t0)
    x = place(x, 0.5 * bell(hz("C7"), 0.9, bright=0.5), t0 + 0.02)
    for nt, at in [("C3", 0.0), ("G3", 0.38), ("C3", t0)]:
        x = place(x, 0.55 * fm_pluck(hz(nt), 0.45 if at < t0 else 1.0, 1.0, 1.0), at)
    x = place(x, 0.15 * swish(0.5, 2500.0, 8000.0, key="vicw", q=2.0), t0 - 0.05)
    x = place(x, arp(["G7", "E7", "C7"], 0.07, bell, 0.25, gains=[0.12, 0.1, 0.1], bright=0.3), t0 + 0.25)
    return room(x, 0.22, 0.8, key="rvic")


def s_defeat(_v: int):
    mel = [("E5", 0.0), ("D5", 0.2), ("C5", 0.4), ("A4", 0.62)]
    x = np.zeros(1)
    for nt, at in mel:
        x = place(x, marimba(hz(nt), 0.45, 0.5, key="dm" + nt), at, 0.75)
    t0 = 0.88
    for nt, g in [("G4", 0.45), ("C5", 0.4), ("D5", 0.3)]:  # accord suspendu : « la prochaine fois », pas un glas
        x = place(x, g * celesta(hz(nt), 1.1), t0)
    x = place(x, 0.4 * fm_pluck(hz("C3"), 1.0, 1.0, 0.6), t0)
    return room(lp(x, 5000), 0.2, 0.8, key="rdef")


def s_banner(_v: int):
    x = 0.35 * swish(0.09, 600.0, 4000.0, key="bnw", q=1.0, shape=0.8)
    hit = place(pop(120.0, 55.0, 0.22, 0.07) * 0.9, bp(noise(0.02, "bns"), 1800, 6000) * decay(tl(0.02), 0.004), 0.0, 0.35)
    x = place(x, hit, 0.075)
    for nt, g in [("C6", 0.35), ("G6", 0.3), ("E7", 0.12)]:
        x = place(x, g * bell(hz(nt), 0.4, bright=0.6), 0.09)
    return room(x, 0.15, 0.4, key="rbn")


def _v(fn, n):
    return [(f"{fn.__name__[2:]}_{i + 1}", (lambda i=i: fn(i))) for i in range(n)]


# nom -> (générateur, description, rôle Sfx, groupe)
LIBRARY: list = []


def _add(name, gen, desc, role, group):
    LIBRARY.append((name, gen, desc, role, group))


for nm, g in _v(s_hover, 3):
    _add(nm, g, "« tic » de bois très court (50 ms), doux, sans aigu : survol à la souris", "ui_hover", "Interface")
for nm, g in _v(s_focus, 3):
    _add(nm, g, "note de marimba aiguë très brève (mi, ré, sol) : le cadre de la manette avance", "ui_focus", "Interface")
for nm, g in _v(s_press, 3):
    _add(nm, g, "« pop » mat de bulle (60 ms) : bouton enfoncé", "ui_press", "Interface")
for nm, g in _v(s_release, 3):
    _add(nm, g, "« clic » clair de bloc de bois + petite montée : bouton relâché", "ui_release", "Interface")
_add("primary", lambda: s_primary(0), "pop + carillon montant do → sol : bouton primaire (soleil)", "ui_primary", "Interface")
_add("confirm", lambda: s_confirm(0), "deux lames la → mi qui montent : validation, achat, choix confirmé", "confirm", "Interface")
_add("deny", lambda: s_deny(0), "« bonk » rond et sourd qui descend : bouton désactivé, action refusée", "ui_deny", "Interface")
_add("tab", lambda: s_tab(0), "« flip » de papier + petit tic : changement d'onglet", "ui_tab", "Interface")
_add("toggle_on", lambda: s_toggle(True), "clic-clac qui monte : interrupteur allumé", "ui_toggle_on", "Interface")
_add("toggle_off", lambda: s_toggle(False), "clac-clic qui descend : interrupteur éteint", "ui_toggle_off", "Interface")
_add("swoosh", lambda: s_swoosh(0), "souffle doux qui monte : carte d'activité ouverte", "ui_swoosh", "Interface")
_add("equip", lambda: s_equip(0), "« clac » de plastique + petite clochette : pièce équipée", "ui_equip", "Interface")
_add("open", lambda: s_open(0), "souffle montant + pincé sol-do : page ou fenêtre qui s'ouvre", "ui_open", "Interface")
_add("close", lambda: s_close(0), "souffle descendant + pincé do grave : page qui se ferme", "ui_close", "Interface")
_add("card_flip", lambda: s_card_flip(0), "deux frottements de papier + note : carte qui se retourne", "ui_card_flip", "Interface")
_add("card_pick", lambda: s_card_pick(0), "« shing » : souffle aigu + clochettes mi-la : carte choisie", "ui_card_pick", "Interface")
_add("notify", lambda: s_notify(0), "deux lames sol → ré (quinte) : notification, nouveauté", "ui_notify", "Interface")
_add("tick", lambda: s_tick(0), "bloc de bois sec et rond : compte à rebours (3, 2, 1)", "ui_tick", "Interface")
_add("go", lambda: s_go(0), "accord de clochettes do-mi-sol + élan : « C'est parti ! »", "ui_go", "Interface")
for nm, g in _v(s_coin, 3):
    _add(nm, g, "deux pièces de métal qui tintent (inharmonique, pas une mélodie) : or, pièces", "ui_coin", "Récompenses")
for r in range(1, 6):
    _add(f"reward_{r}", (lambda r=r: s_reward(r)), {
        1: "2 notes montantes : objet commun ou spécial",
        2: "3 notes : objet rare",
        3: "4 notes + clochette : objet épique",
        4: "5 notes + clochettes + scintillement : objet mythique",
        5: "6 notes + accord + étincelles + basse : objet légendaire (signature, bible § 7)",
    }[r], f"ui_reward_{r}", "Récompenses")
_add("level_up", lambda: s_level_up(0), "gamme qui monte puis accord de clochettes : niveau gagné", "ui_level_up", "Moments")
_add("star", lambda: s_star(0), "éclat de verre + clochettes mi-si : étoile gagnée", "ui_star", "Moments")
_add("record", lambda: s_record(0), "« ta-ta-taa » (la la ré) + accord : record battu", "ui_record", "Moments")
_add("victory", lambda: s_victory(0), "petite mélodie montante + accord tenu + étincelles (1,9 s) : victoire", "ui_victory", "Moments")
_add("defeat", lambda: s_defeat(0), "4 lames qui descendent + accord suspendu, feutré : défaite douce", "ui_defeat", "Moments")
_add("banner", lambda: s_banner(0), "élan + coup rond grave + éclat de clochettes (0,4 s) : bannière de moment manga", "ui_banner", "Moments")
_add("forge_ok", lambda: s_forge_ok(0), "tintement d'enclume + arpège de clochettes : forge réussie", "ui_forge_ok", "Moments")
_add("forge_fail", lambda: s_forge_fail(0), "« clonk » étouffé + bouffée + 2 notes qui descendent, sans dureté : forge ratée", "ui_forge_fail", "Moments")
for nm, g in _v(s_hit, 3):
    _add(nm, g, "coup feutré grave (90 ms), sans aigu : coup reçu léger (HUD)", "ui_hit", "Moments")


# --- mesures (écoute indirecte) -----------------------------------------------------------------
def measure(x: np.ndarray) -> dict:
    """Durée, crête, RMS court maximal (30 ms), centroïde spectral, part d'énergie > 8 kHz, bords et saut max."""
    w = int(0.030 * SR)
    sq = np.convolve(x ** 2, np.ones(w) / w, mode="valid") if len(x) > w else np.array([np.mean(x ** 2)])
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    cen = float(np.sum(fr * spec) / (np.sum(spec) + 1e-12))
    hi = float(np.sum(spec[fr > 8000]) / (np.sum(spec) + 1e-12))
    return {
        "dur": len(x) / SR,
        "peak_db": 20 * np.log10(np.max(np.abs(x)) + 1e-12),
        "rms_db": 10 * np.log10(np.max(sq) + 1e-12),
        "lk": loudness(x),
        "centroid": cen,
        "hi": hi,
        "edges": max(abs(x[0]), abs(x[-1])),
        "jump": float(np.max(np.abs(np.diff(x)))),
        "dc": float(abs(np.mean(x))),
    }


def write_index(rows: list) -> None:
    os.makedirs(DOC, exist_ok=True)
    total = sum(r["bytes"] for r in rows)
    lines = [
        "# Planche des sons d'interface (lot SND-1)",
        "",
        "Générée par `python tools/art/snd_synth.py` (ne pas éditer à la main). Fichiers : `game/assets/sfx/ui/` (WAV 16 bits,",
        "44,1 kHz, mono ; tous à la même sonie, -20 dB en pondération K sur 50 ms, crête ≤ -1 dBFS : le volume de chaque rôle",
        "se règle dans le jeu, `UiFeel.SOUNDS` et les appels `Sfx.ui`). Rôle = nom passé à `Sfx.ui(...)` (une liste = variantes",
        "tirées au hasard). Écoute d'un coup :",
        "`ecoute_planche.ogg` (tous les sons à la suite, dans l'ordre du tableau, 0,45 s de silence entre deux).",
        "",
        "Mesures : **RMS** = niveau le plus fort sur 30 ms (dBFS, avant le volume du jeu) ; **centre** = centroïde spectral",
        "(clarté) ; **> 8 kHz** = part de l'énergie dans l'aigu (perçant au-delà de 5 %) ; **bords** = premier / dernier",
        "échantillon (0 = aucun clic au début ni à la fin) ; **saut** = plus grand écart entre deux échantillons voisins.",
        "",
        f"Total : {len(rows)} fichiers, {total / 1024:.0f} Ko.",
        "",
    ]
    group = None
    for r in rows:
        if r["group"] != group:
            group = r["group"]
            lines += ["", f"## {group}", "", "| Fichier | Rôle | Son | Durée | RMS | Centre | > 8 kHz | Bords | Saut | Ko |",
                      "|---|---|---|---|---|---|---|---|---|---|"]
        m = r["m"]
        lines.append(
            f"| `{r['name']}.wav` | `{r['role']}` | {r['desc']} | {m['dur'] * 1000:.0f} ms | {m['rms_db']:.1f} | "
            f"{m['centroid']:.0f} Hz | {m['hi'] * 100:.1f} % | {m['edges']:.0e} | {m['jump']:.2f} | {r['bytes'] / 1024:.0f} |")
    with open(os.path.join(DOC, "index.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def preview(rows: list) -> None:
    gap = silence(0.45)
    out = [silence(0.3)]
    for r in rows:
        out += [r["x"], gap]
    x = np.concatenate(out)
    tmp = os.path.join(DOC, "snd1_preview.wav")
    wavfile.write(tmp, SR, (x * 32767).astype(np.int16))
    dst = os.path.join(DOC, "ecoute_planche.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
    os.remove(tmp)
    print(f"écoute : {dst} ({os.path.getsize(dst) / 1024:.0f} Ko, {len(x) / SR:.1f} s)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="préfixe(s) de nom séparés par des virgules")
    ap.add_argument("--preview", action="store_true", help="écrit aussi conception/art/snd/ecoute_planche.ogg (ffmpeg)")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = [s for s in a.only.split(",") if s]
    rows = []
    bad = []
    for name, gen, desc, role, group in LIBRARY:
        if only and not any(name.startswith(o) for o in only):
            continue
        x = level(finish(gen()))
        pcm = np.round(x * 32767).astype(np.int16)
        path = os.path.join(a.out, f"{name}.wav")
        wavfile.write(path, SR, pcm)
        m = measure(pcm.astype(np.float64) / 32767)
        rows.append({"name": name, "desc": desc, "role": role, "group": group, "m": m, "bytes": os.path.getsize(path), "x": x})
        flag = ""
        if m["edges"] > 1e-3 or m["dc"] > 1e-3 or m["hi"] > 0.05:
            flag = "  <-- à revoir"
            bad.append(name)
        print(f"{name:12s} {m['dur'] * 1000:6.0f} ms  crête {m['peak_db']:5.1f}  sonie {m['lk']:5.1f}  rms {m['rms_db']:6.1f}  centre {m['centroid']:5.0f} Hz"
              f"  >8k {m['hi'] * 100:4.1f} %  bords {m['edges']:.0e}  saut {m['jump']:.2f}{flag}")
    total = sum(r["bytes"] for r in rows)
    print(f"{len(rows)} sons, {total / 1024:.0f} Ko")
    if not only:
        write_index(rows)
    if a.preview:
        preview(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
