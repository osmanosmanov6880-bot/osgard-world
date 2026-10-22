"""Procedural, licence-free OSGARD prototype audio; deterministic PCM output."""
from pathlib import Path
import math
import random
import wave
import struct
import hashlib

out=Path(__file__).resolve().parents[1]/'assets'/'audio'
out.mkdir(parents=True,exist_ok=True)
RATE=16000
r=random.Random(412987)

def save(name, duration, sample):
 n=int(RATE*duration)
 data=bytearray()
 for i in range(n):
  t=i/RATE
  x=max(-1,min(1,sample(i,t,n)*0.86))
  data.extend(struct.pack('<h',round(x*32767)))
 with wave.open(str(out/name),'wb') as wav:
  wav.setframerate(RATE); wav.setsampwidth(2); wav.setnchannels(1); wav.writeframes(data)
 print(name,n,'samples',hashlib.sha256(data).hexdigest()[:12])

last=[0.0]
def city(i,t,n):
 x=r.random()*2-1
 last[0]=0.988*last[0]+0.012*x
 ring=(0.09*math.sin(2*math.pi*53*t)+0.07*math.sin(2*math.pi*71*t))
 wind=(0.1*last[0]+0.02*x)
 return ring+wind+0.015*math.sin(2*math.pi*240*t)*math.sin(2*math.pi*t/6)**2
save('city_air.wav',6.0,city)

def engine(i,t,n):
 # Frequencies have integer number of full cycles over 2 seconds (loop-safe).
 return 0.24*math.sin(2*math.pi*90*t)+0.12*math.sin(2*math.pi*180*t)+0.09*math.sin(2*math.pi*270*t)+0.09*math.sin(2*math.pi*45*t)
save('engine_low.wav',2.0,engine)

s=[0.0]
def rain(i,t,n):
 x=r.random()*2-1
 s[0]=0.86*s[0]+0.14*x
 fade=min(1.0,i/1000,(n-i)/1000)
 return (0.24*s[0]+0.07*x)*max(0.0,fade)
save('rain.wav',4.0,rain)

def positive(i,t,n):
 env=min(1,t/0.018)*math.exp(-t*15)
 return 0.32*env*(math.sin(2*math.pi*620*t)+0.35*math.sin(2*math.pi*930*t))
save('ui_success.wav',0.30,positive)
