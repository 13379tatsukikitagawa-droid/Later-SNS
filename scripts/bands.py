#!/usr/bin/env python3
"""差の 大きい 場所を 帯(80px)と 区画ごとに 出す。使い方: scripts/bands.py <ID> [sim.png]"""
import sys
from PIL import Image, ImageChops
ID=sys.argv[1]; sim=sys.argv[2] if len(sys.argv)>2 else "/tmp/sim.png"
ref=f"Design/LattagKit/screens/{ID}.jpg"
def norm(p,w=780):
    im=Image.open(p).convert("RGB"); return im.resize((w,round(im.height*w/im.width)),Image.LANCZOS)
a,b=norm(ref),norm(sim); H=min(a.height,b.height)
d=ImageChops.difference(a.crop((0,0,780,H)),b.crop((0,0,780,H))).convert("L")
tot=sum(d.histogram()[i]*i for i in range(256))
print("total",round(tot/(780*H)/2.55,1))
for y in range(0,H,160):
    for x in range(0,780,390):
        c=d.crop((x,y,x+390,min(H,y+160))); h=c.histogram()
        v=sum(h[i]*i for i in range(256))/(c.width*c.height)/2.55
        print(f"y{y//2:4d} x{x//2:3d} {v:5.1f} "+"#"*int(v))
