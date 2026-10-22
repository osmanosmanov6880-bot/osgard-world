#!/usr/bin/env python3
"""Create an original short loop for the v0.15 nonviolent pursuit cue.
No downloaded or third-party material, only deterministic synthesized PCM.
"""
from pathlib import Path
from math import pi, sin
import struct
import wave

RATE = 16_000
DURATION = 2.0
TARGET = Path(__file__).resolve().parents[1] / 'assets/audio/patrol_alert.wav'
TARGET.parent.mkdir(parents=True, exist_ok=True)

frames = bytearray()
phase = 0.0
for i in range(int(RATE*DURATION)):
    t = i/RATE
    sweep = (1.0 - __import__('math').cos(pi * 2 * t / DURATION)) * .5
    frequency = 520.0 + 220.0*sweep
    phase += 2*pi*frequency/RATE
    edge = min(1.0, i/320, (RATE*DURATION-i-1)/320)
    level = .20 * edge * (sin(phase) + .14*sin(phase*2.0))
    frames.extend(struct.pack('<h', round(max(-1.0,min(1.0,level))*32767)))
with wave.open(str(TARGET),'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(frames)
print(f'Wrote {TARGET.name}: {len(frames)//2} samples, source-only alert cue')
