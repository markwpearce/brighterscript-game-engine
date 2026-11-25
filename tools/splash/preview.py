import json
from PIL import Image
O='out'
m=json.load(open(f'{O}/bge_cannon_fhd.json'))
title=Image.open(f'{O}/bge_title_fhd.webp').convert('RGBA')
sheet=Image.open(f'{O}/bge_cannon_fhd.webp').convert('RGBA')
ball=Image.open(f'{O}/bge_cannonball_fhd.webp').convert('RGBA')
fw,fh=m['frameSize']['w'],m['frameSize']['h']; body=m['body']; gap=m['suggestedGap']
def tint(im,rgb):
    r,g,b=rgb; a=im.getchannel('A'); out=Image.new('RGBA',im.size,(r,g,b,0)); out.putalpha(a); return out
def frame(i):
    f=m['frames'][i]['frame']; return sheet.crop((f['x'],f['y'],f['x']+fw,f['y']+fh))
W,H=1920,1080
groupW=body['w']+gap+title.width
gx=(W-groupW)//2; ty=(H-title.height)//2
cx=gx-body['x']; cy=ty-body['y']; tx=gx+body['w']+gap
def compose(bg,ccol,tcol,i=0,ballpos=None,size=(W,H)):
    im=Image.new('RGBA',(W,H),bg+(255,))
    im.alpha_composite(tint(frame(i),ccol),(cx,cy))
    im.alpha_composite(tint(title,tcol),(tx,ty))
    if ballpos: im.alpha_composite(tint(ball,ccol),(int(ballpos[0]-ball.width/2),int(ballpos[1]-ball.height/2)))
    return im
compose((66,24,102),(255,255,255),(255,255,255)).convert('RGB').save(f'{O}/preview_splash_fhd.png')
# colour variants
vars_=[((66,24,102),(255,255,255),(255,255,255)),((18,24,38),(255,170,40),(240,240,245)),
       ((245,240,228),(66,24,102),(30,30,40)),((10,120,110),(255,230,120),(255,255,255))]
tiles=[compose(*v).resize((960,540),Image.LANCZOS) for v in vars_]
g=Image.new('RGB',(1920,1080))
for i,t in enumerate(tiles): g.paste(t.convert('RGB'),((i%2)*960,(i//2)*540))
g.save(f'{O}/preview_colours.png')
# animation
bs=m['ballSpawn']; frames=[]; durs=[]
seq=[0]*1+list(range(1,8))
bx,by=cx+bs['x'],cy+bs['y']; vx,vy=bs['dirX']*95,bs['dirY']*95
ballp=None
for i in seq:
    if i==4: ballp=[bx,by]
    if ballp:
        ballp=[ballp[0]+vx,ballp[1]+vy]; vy+=6
    frames.append(compose((66,24,102),(255,255,255),(255,255,255),i,ballp).resize((960,540),Image.LANCZOS)); durs.append(m['frames'][i]['duration'] if i else 900)
# keep ball flying while settled
for j in range(10):
    ballp=[ballp[0]+vx,ballp[1]+vy]; vy+=6
    frames.append(compose((66,24,102),(255,255,255),(255,255,255),7 if j<2 else 0,ballp).resize((960,540),Image.LANCZOS)); durs.append(60)
frames[0].save(f'{O}/preview_fire.webp',save_all=True,append_images=frames[1:],duration=durs,loop=0,lossless=False,quality=85)
print(cx,cy,tx,ty)
