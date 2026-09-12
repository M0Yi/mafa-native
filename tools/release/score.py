"""Original synthesized ambient bed for the demo film; no client audio used."""
import wave,numpy as np
from pathlib import Path
rate=48000;seconds=45;t=np.arange(rate*seconds)/rate
music=np.zeros(len(t),dtype=np.float64)
for start,notes in [(0,[146.83,220,293.66]),(9,[130.81,196,261.63]),(18,[174.61,261.63,349.23]),(27,[146.83,220,329.63]),(36,[146.83,220,293.66])]:
 dt=t-start;active=(dt>=0)&(dt<10)
 env=np.clip(dt/2,0,1)*np.clip((10-dt)/3,0,1)*active
 for frequency in notes:
  music+=0.04*env*(np.sin(2*np.pi*frequency*t)+0.18*np.sin(2*np.pi*2*frequency*t))
for start,freq in [(2,587.33),(5,440),(8,523.25),(12,659.25),(16,587.33),(21,698.46),(26,523.25),(31,659.25),(37,587.33),(41,440)]:
 dt=t-start;env=np.exp(-np.maximum(dt,0)/1.1)*(dt>=0)*np.minimum(np.maximum(dt,0)*60,1)
 music+=0.045*np.sin(2*np.pi*freq*t)*env
music*=np.minimum(t/2,1)*np.clip((45-t)/3,0,1)
out=Path('release/media/promo-score.wav')
with wave.open(str(out),'wb') as f:
 f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((np.clip(music,-1,1)*32767).astype('<i2').tobytes())
