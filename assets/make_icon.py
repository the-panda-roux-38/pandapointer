from PIL import Image, ImageDraw
import sys, os

ORANGE=(233,98,47,255); DEEP=(190,70,28,255); DARK=(42,24,16,255); WHITE=(246,237,227,255); BG=(23,18,15,255)

def face(size, bg, tray=False):
    S=size*4
    im=Image.new("RGBA",(S,S),(0,0,0,0))
    d=ImageDraw.Draw(im)
    if bg:
        d.rounded_rectangle([0,0,S-1,S-1],radius=int(S*0.22),fill=BG)
        k=0.80; ox=oy=S*(1-k)/2
    else:
        k=1.0; ox=oy=0
    def X(v): return ox+v*S*k
    def Y(v): return oy+v*S*k
    def ell(cx,cy,rx,ry,fill):
        d.ellipse([X(cx-rx),Y(cy-ry),X(cx+rx),Y(cy+ry)],fill=fill)
    # ears
    for cx in (0.20,0.80):
        ell(cx,0.24,0.15,0.15,DEEP)
        ell(cx,0.25,0.085,0.085,WHITE)
    # head
    ell(0.5,0.54,0.42,0.36,ORANGE)
    # cheeks (white fur)
    ell(0.27,0.66,0.17,0.13,WHITE)
    ell(0.73,0.66,0.17,0.13,WHITE)
    ell(0.5,0.72,0.14,0.11,WHITE)
    # brow marks
    ell(0.35,0.40,0.07,0.045,WHITE)
    ell(0.65,0.40,0.07,0.045,WHITE)
    # tear stripes
    for sx in (1,-1):
        cx=0.5-sx*0.15
        pts=[(cx-sx*0.0,0.52),(cx-sx*0.03,0.52),(cx-sx*0.11,0.70),(cx-sx*0.07,0.70)]
        d.polygon([(X(a),Y(b)) for a,b in pts],fill=DEEP)
    # eyes
    ell(0.35,0.50,0.05,0.055,DARK)
    ell(0.65,0.50,0.05,0.055,DARK)
    if not tray:
        ell(0.365,0.485,0.014,0.014,WHITE); ell(0.665,0.485,0.014,0.014,WHITE)
    # nose
    ell(0.5,0.66,0.055,0.04,DARK)
    return im.resize((size,size),Image.LANCZOS)

out=sys.argv[1]; os.makedirs(out,exist_ok=True)
# tray raw RGBA 32x32
t=face(32,False,True)
open(f"{out}/tray32.rgba","wb").write(t.tobytes())
face(256,True).save(f"{out}/icon-256.png")
face(1024,True).save(f"{out}/icon-1024.png")
face(512,False).save(f"{out}/icon-fg-512.png")
imgs=[face(s,True) for s in (256,64,48,32,16)]
imgs[0].save(f"{out}/pandapointer.ico",format="ICO",sizes=[(256,256),(64,64),(48,48),(32,32),(16,16)],append_images=imgs[1:])
print("ok")
