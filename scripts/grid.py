#!/usr/bin/env python3
"""差の 地図(6列 × 12行)と 各 セルの 平均色の ちがい。使い方: scripts/grid.py <ID>"""
import sys
from PIL import Image, ImageChops, ImageStat
ID=sys.argv[1]
a=Image.open(f"Design/LattagKit/screens/{ID}.jpg").convert("RGB"); b=Image.open("/tmp/sim.png").convert("RGB").resize(a.size)
cw,ch=a.width//6,a.height//12
print("      "+"".join(f"x{c*65:<4}  " for c in range(6)))
for r in range(12):
    row=[]
    for c in range(6):
        box=(c*cw,r*ch,(c+1)*cw,(r+1)*ch)
        A,B=a.crop(box),b.crop(box)
        d=ImageStat.Stat(ImageChops.difference(A,B).convert("L")).mean[0]
        m=ImageStat.Stat(B.convert("L")).mean[0]-ImageStat.Stat(A.convert("L")).mean[0]
        row.append(f"{d:4.0f}{'+' if m>3 else '-' if m<-3 else ' '} ")
    print(f"y{r*70:<4} "+"  ".join(row))
