"""CITY REIGN R169: verify native generated PCM before actual Godot WebGL export."""
from pathlib import Path
import wave,struct,math,hashlib
BASE=Path(__file__).resolve().parents[1]/'assets'/'audio'
checks=0
for name in ('engine_load.wav','tyre_roll.wav'):
    path=BASE/name
    with wave.open(str(path),'rb') as sample:
        assert sample.getnchannels()==1, f'{name}: expected mono'
        assert sample.getframerate()==16000, f'{name}: invalid sample rate'
        assert sample.getsampwidth()==2, f'{name}: expected PCM16'
        assert sample.getnframes()==32000, f'{name}: expected exact 2-second loop'
        pcm=sample.readframes(sample.getnframes())
    assert len(pcm)==64000 and path.stat().st_size<65500, f'{name}: mobile audio budget'
    values=struct.unpack('<32000h',pcm)
    peak=max(abs(x) for x in values)
    selected=values[::32]
    rms=math.sqrt(sum(float(x*x) for x in selected)/len(selected))
    assert 1000<peak<31000 and 600<rms<17000, f'{name}: clipping or silence'
    assert abs(values[0]-values[-1])<8500, f'{name}: loop discontinuity'
    checks+=7
    print(f'R169 ORIGINAL AUDIO {name}: RMS={rms:.0f} peak={peak} sha256={hashlib.sha256(pcm).hexdigest()[:16]} PASS')
print(f'CITY REIGN R169 ORIGINAL PCM: {checks} PASS 0 FAIL')
