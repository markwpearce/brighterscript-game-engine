#!/usr/bin/env python3
"""Downmix the startup sound to mono 22.05kHz 16-bit for shipping (about a quarter the size).

Usage: python3 downmix.py out/bge_startup.wav ../../src/source/engine/splash/sounds/bge_startup.wav
Uses only the standard library (audioop, Python 3.12 or older).
"""
import audioop
import sys
import wave

src, dst = sys.argv[1], sys.argv[2]
with wave.open(src) as w:
    p = w.getparams()
    data = w.readframes(p.nframes)
if p.nchannels == 2:
    data = audioop.tomono(data, p.sampwidth, 0.5, 0.5)
out, _ = audioop.ratecv(data, p.sampwidth, 1, p.framerate, 22050, None)
with wave.open(dst, "wb") as o:
    o.setnchannels(1)
    o.setsampwidth(p.sampwidth)
    o.setframerate(22050)
    o.writeframes(out)
