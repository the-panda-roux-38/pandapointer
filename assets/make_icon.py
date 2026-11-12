"""Fabrique les icônes de PandaPointer à partir de assets/panda.svg (le panda roux de Coche).

Sorties :
  assets/icon-1024.png, assets/icon-fg-512.png          (aperçu, source des icônes Android)
  pc-companion/assets/pandapointer.ico, tray32.rgba     (icône du .exe et de la barre des tâches)
  mobile/android/app/src/main/res/...                   (icônes du lanceur Android)
Nécessite : rsvg-convert (librsvg) et Pillow.
"""
import io, os, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BG = (27, 20, 16, 255)  # brun crépuscule #1b1410


def panda(width):
    png = subprocess.run(["rsvg-convert", "-w", str(width), os.path.join(HERE, "panda.svg")],
                         check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def icon(size, bg=True, scale=0.82):
    base = Image.new("RGBA", (size, size), BG if bg else (0, 0, 0, 0))
    p = panda(int(size * scale))
    base.alpha_composite(p, ((size - p.width) // 2, (size - p.height) // 2 + int(size * 0.02)))
    return base


icon(1024).save(os.path.join(HERE, "icon-1024.png"))
icon(512, bg=False, scale=0.9).save(os.path.join(HERE, "icon-fg-512.png"))

# PC : barre des tâches (32x32 brut, sans fond) et .ico
pc = os.path.join(ROOT, "pc-companion", "assets")
os.makedirs(pc, exist_ok=True)
tray = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
p = panda(32)
tray.alpha_composite(p, (0, (32 - p.height) // 2))
open(os.path.join(pc, "tray32.rgba"), "wb").write(tray.tobytes())
imgs = [icon(s, scale=0.9) for s in (256, 64, 48, 32, 16)]
imgs[0].save(os.path.join(pc, "pandapointer.ico"), format="ICO",
             sizes=[(256, 256), (64, 64), (48, 48), (32, 32), (16, 16)], append_images=imgs[1:])

# Android : icône classique + icône adaptative (premier plan transparent sur fond brun)
res = os.path.join(ROOT, "mobile", "android", "app", "src", "main", "res")
for d, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    os.makedirs(os.path.join(res, f"mipmap-{d}"), exist_ok=True)
    icon(s, scale=0.9).save(os.path.join(res, f"mipmap-{d}", "ic_launcher.png"))
os.makedirs(os.path.join(res, "drawable-nodpi"), exist_ok=True)
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
pp = panda(250)
fg.alpha_composite(pp, ((432 - pp.width) // 2, (432 - pp.height) // 2 + 6))
fg.save(os.path.join(res, "drawable-nodpi", "ic_launcher_foreground.png"))
os.makedirs(os.path.join(res, "values"), exist_ok=True)
open(os.path.join(res, "values", "ic_launcher_background.xml"), "w").write(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#1B1410</color>\n</resources>\n')
print("ok")
