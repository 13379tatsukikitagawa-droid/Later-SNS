# motion/_frames → motion/<ID>.png(コマ割り)
import json,os,sys
from PIL import Image,ImageDraw,ImageFont
root=sys.argv[1] if len(sys.argv)>1 else '.'
L=json.load(open(os.path.join(root,'motion/_frames/log.json')))
try: F=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc',18,index=0)
except: F=ImageFont.load_default()
for m in L:
    ims=[Image.open(os.path.join(root,'motion/_frames',f)).convert('RGB') for f,_,_ in m['frames']]
    w,h=ims[0].size;s=min(1,260/w);tw,th=int(w*s),int(h*s);cols=min(6,len(ims));rows=(len(ims)+cols-1)//cols
    S=Image.new('RGB',(cols*(tw+10)+10,rows*(th+34)+60),(236,236,240));d=ImageDraw.Draw(S)
    d.text((10,14),f"{m['id']} ・ {m['name']}",font=F,fill=(20,20,20))
    for i,(im,(f,t,real)) in enumerate(zip(ims,m['frames'])):
        x=10+(i%cols)*(tw+10);y=50+(i//cols)*(th+34)
        S.paste(im.resize((tw,th)),(x,y+26));d.text((x,y+2),f"{t} ms",font=F,fill=(36,160,60))
    S.save(os.path.join(root,'motion',m['id']+'.png'));print(m['id'],S.size)
