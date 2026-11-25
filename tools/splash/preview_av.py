import json, os, subprocess
exec(open('preview.py').read().split('# colour variants')[0])
FPS=50; snd=json.load(open('out/bge_startup.json'))
boom=snd['cues']['boomMs']/1000
durs=[f['duration']/1000 for f in m['frames']]
fire_t=boom; t_wind=fire_t-durs[1]
starts=[0,t_wind]; acc=fire_t
for i in range(2,8): starts.append(acc); acc+=durs[i]
os.makedirs('vid',exist_ok=True)
bs=m['ballSpawn']; spawn_t=starts[4]
for k in range(int(3.0*FPS)):
    t=k/FPS
    idx=max(i for i,s in enumerate(starts) if s<=t)
    if t>=acc: idx=0
    bp=None
    if t>=spawn_t:
        dt=(t-spawn_t)*FPS/1.25   # ~40 steps/s like preview
        vx,vy=bs['dirX']*95,bs['dirY']*95
        bp=[cx+bs['x']+vx*(dt+1), cy+bs['y']+vy*(dt+1)+3*dt*(dt+1)]
    compose((66,24,102),(255,255,255),(255,255,255),idx,bp).convert('RGB').resize((1280,720)).save(f'vid/{k:04d}.png')
subprocess.run(['ffmpeg','-loglevel','error','-y','-framerate',str(FPS),'-i','vid/%04d.png','-i','out/bge_startup.wav',
 '-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-shortest','out/preview_splash_with_sound.mp4'],check=True)
print('done')
