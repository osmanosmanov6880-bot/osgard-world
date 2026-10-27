#!/usr/bin/env python3
"""Generate IRON PULSE's ORIGINAL procedural game audio. Public-domain mathematics,
no third-party recordings, no external dependencies, deterministic for audit.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 16000
BASE = Path(__file__).resolve().parent.parent / "audio"
BASE.mkdir(parents=True, exist_ok=True)


def output(name, length, build):
    count = int(length * RATE)
    frames = bytearray()
    for i in range(count):
        t = i / RATE
        # Common envelope reduces clicks at start/end; ambience loops softly.
        edge = min(1.0, t / 0.20, (length - t) / 0.25)
        sample = max(-0.92, min(0.92, build(t) * max(0.0, edge)))
        frames.extend(struct.pack("<h", int(sample * 32767)))
    path = BASE / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(frames)
    print(f"{path.name}: {len(frames)} PCM bytes")


def ambient(t):
    slow = 0.5 + 0.5 * math.sin(2 * math.pi * 0.16 * t)
    electric = 0.045 * math.sin(2 * math.pi * (103 * t + 0.2 * math.sin(0.12 * t)))
    sub = 0.16 * math.sin(2 * math.pi * 49 * t) + 0.075 * math.sin(2 * math.pi * 73 * t)
    air = 0.013 * math.sin(2 * math.pi * 365 * t) * (0.25 + slow)
    return 0.52 * (sub * (0.82 + slow * 0.15) + electric + air)


def click(t):
    return 0.36 * math.exp(-t * 18) * (
        math.sin(2 * math.pi * (490 * t + 170 * t * t)) +
        0.35 * math.sin(2 * math.pi * 810 * t))


def alarm(t):
    mod = 0.5 + 0.5 * math.sin(2 * math.pi * 1.15 * t)
    phase = 2 * math.pi * (266 * t + 35 * math.sin(2 * math.pi * 0.6 * t))
    return 0.30 * (0.7 + mod * 0.3) * (math.sin(phase) + 0.34 * math.sin(phase * 2.01))


def success(t):
    f = 420 + 255 * min(1.0, t / 1.45)
    return 0.31 * math.exp(-t * 1.35) * (
        math.sin(2 * math.pi * f * t) + 0.44 * math.sin(2 * math.pi * (f * 1.5) * t))


output("reactor_ambience.wav", 12.0, ambient)
output("terminal_confirm.wav", 0.52, click)
output("containment_alarm.wav", 2.6, alarm)
output("evacuation_success.wav", 3.0, success)
