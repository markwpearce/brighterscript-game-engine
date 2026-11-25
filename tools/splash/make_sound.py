#!/usr/bin/env python3
"""
BrighterScript Game Engine startup sound: fuse fizz + rising three-note motif,
cannon blast, then a bright sparkling chord as the ball flies.

Everything is synthesised from scratch (numpy/scipy), so there are no
third-party samples or licences to worry about.

Output: bge_startup.wav (16-bit PCM, 44.1 kHz, stereo) + bge_startup.json (cue times)
"""
import json, sys, os
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR = 44100
BOOM_AT = 0.60          # seconds: lines up with the sprite sheet "fire" frame
LENGTH = 3.0
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

N = int(SR * LENGTH)
t = np.arange(N) / SR
L = np.zeros(N)
R = np.zeros(N)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def place(sig, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    sig = sig.copy()
    tf = min(len(sig) // 3, int(0.3 * SR))   # fade every tail: no end clicks
    sig[-tf:] *= np.linspace(1, 0, tf) ** 2
    n = min(len(sig), N - i)
    gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    L[i:i + n] += sig[:n] * gain * gl * np.sqrt(2)
    R[i:i + n] += sig[:n] * gain * gr * np.sqrt(2)


def env_adsr(n, a, decay_tau):
    tt = np.arange(n) / SR
    e = np.exp(-tt / decay_tau)
    na = max(1, int(a * SR))
    e[:na] *= np.linspace(0, 1, na)
    return e


def pluck(freq, dur, bright=1.0, attack=0.006):
    """Warm, string-like pluck: harmonic partials only, upper ones die off fast.
    (Replaces the earlier FM bell, which had a ringing metallic overtone.)"""
    n = int(dur * SR)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for h in range(1, 9):
        f = freq * h
        if f > 9000:
            break
        amp = 1.0 / h ** 1.7
        tau = (dur / 4) / (1 + 0.9 * (h - 1) / bright)   # higher partials fade sooner
        det = 1 + 0.0015 * (h % 2)                          # tiny detune, less pure
        out += amp * np.sin(2 * np.pi * f * det * tt) * np.exp(-tt / tau)
    out = lp(out, min(6000, freq * 5 * bright))
    na = max(1, int(attack * SR))
    out[:na] *= np.linspace(0, 1, na)
    return out / 1.6


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semis / 12)


# ------------------------------------------------------------------ 1. fuse fizz
fz_start, fz_end = 0.05, BOOM_AT
n = int((fz_end - fz_start) * SR)
noise = rng.standard_normal(n)
fizz = bp(noise, 2500, 9000)
ramp = np.linspace(0.15, 1.0, n) ** 1.5
crackle = np.zeros(n)
for _ in range(40):                       # random crackles
    i = rng.integers(0, n - 400)
    crackle[i:i + 300] += rng.standard_normal(300) * np.exp(-np.arange(300) / 40) * rng.uniform(0.5, 1.5)
fizz = (fizz * 0.5 + hp(crackle, 1500)) * ramp
fizz *= 1 - np.exp(-np.arange(n) / (0.02 * SR))
place(fizz, fz_start, 0.10, pan=-0.35)

# ------------------------------------------------------------------ 2. rising motif (C5 E5 G5)
for i, (nm, at) in enumerate([("C5", 0.06), ("E5", 0.22), ("G5", 0.38)]):
    place(pluck(note(nm), 0.6), at, 0.24, pan=-0.2 + 0.2 * i)

# ------------------------------------------------------------------ 3. cannon blast
bn = int(2.0 * SR)
bt = np.arange(bn) / SR
# low thump: pitch drops 110 -> 38 Hz
f = 38 + 72 * np.exp(-bt / 0.07)
phase = 2 * np.pi * np.cumsum(f) / SR
thump = np.sin(phase) * np.exp(-bt / 0.35)
thump = np.tanh(thump * 2.2) / np.tanh(2.2)
# blast body: low-passed noise with a fast attack
body = lp(rng.standard_normal(bn), 900, 4) * np.exp(-bt / 0.18)
body *= 1 - np.exp(-bt / 0.002)
# crack: short bright transient
crack = hp(rng.standard_normal(bn), 1800) * np.exp(-bt / 0.012)
# rumble tail
rumble = lp(rng.standard_normal(bn), 180, 4) * np.exp(-bt / 0.6) * 3.0
blast = 1.0 * thump + 1.6 * body + 0.5 * crack + rumble
blast /= np.max(np.abs(blast))
place(blast, BOOM_AT, 0.95, pan=-0.15)

# ------------------------------------------------------------------ 4. sparkle chord (Cadd9)
chord_at = BOOM_AT + 0.08
for i, nm in enumerate(["C4", "G4", "C5", "E5", "G5", "D6"]):
    place(pluck(note(nm), 2.2, bright=1.0, attack=0.025), chord_at + i * 0.012, 0.13, pan=-0.5 + i * 0.2)
# high sparkles following the ball up and to the right
for k in range(6):
    at = chord_at + 0.05 + k * 0.11 + rng.uniform(-0.02, 0.02)
    fr = note("C6") * 2 ** (rng.choice([0, 2, 4, 7, 9, 12]) / 12)
    place(pluck(fr, 0.35, bright=0.7), at, 0.045 * (1 - k / 8), pan=-0.1 + k * 0.15)

# ------------------------------------------------------------------ reverb + master
def reverb(x, seconds=1.4, mix=0.18, seed=1):
    r = np.random.default_rng(seed)
    m = int(seconds * SR)
    ir = r.standard_normal(m) * np.exp(-np.arange(m) / (0.25 * SR))
    ir = lp(ir, 6000)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(x, ir)[:len(x)]
    return x + mix * wet

L, R = reverb(L, seed=1), reverb(R, seed=2)
mix = np.stack([L, R], axis=1)
mix = hp(mix.T, 25).T
peak = np.max(np.abs(mix))
mix = mix / peak * 0.89                         # ~ -1 dBFS
fade = int(0.25 * SR)
mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
pcm = (mix * 32767).astype(np.int16)
wavfile.write(f"{OUT}/bge_startup.wav", SR, pcm)

json.dump({"file": "bge_startup.wav", "durationMs": int(LENGTH * 1000),
           "cues": {"fuseStartMs": int(fz_start * 1000), "boomMs": int(BOOM_AT * 1000),
                    "sparkleMs": int(chord_at * 1000)},
           "note": "Start the sound boomMs before you switch the cannon to its 'fire' frame."},
          open(f"{OUT}/bge_startup.json", "w"), indent=2)
print("ok", pcm.shape)
