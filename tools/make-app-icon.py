"""Regenerate Relay's 1024x1024 App Store icon.

Run from the repo root:  python tools/make-app-icon.py   (requires Pillow: pip install Pillow)

Concept A — the remote's directional pad: a tactile graphite D-pad with four chevrons and a glossy
electric-blue OK button at the center. Mirrors the app's signature control (the blue OK-in-dpad),
reads clearly at small sizes, and stays clear of the category clichés (lone power button, TV+play).
Drawn at 4x and downsampled with LANCZOS. Opaque RGB, no alpha (Apple requirement).
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.normpath(os.path.join(
    os.path.dirname(__file__), "..", "Relay", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "AppIcon-1024.png",
))
FINAL = 1024
S = 4
N = FINAL * S
CX = CY = N / 2

BG_TOP, BG_BOT = (26, 29, 36), (11, 13, 17)
KEY_FACE, KEY_TOP, KEY_RIM = (34, 37, 46), (46, 50, 60), (58, 62, 74)
BLUE, BLUE_TOP = (61, 139, 255), (108, 176, 255)
GLYPH = (232, 236, 242)

def px(v):
    return v * S

img = Image.new("RGB", (N, N), BG_BOT)
d = ImageDraw.Draw(img)

# graphite vertical gradient
for y in range(N):
    t = y / (N - 1)
    d.line([(0, y), (N, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOT)))

# directional-pad disc: rim + flat face
d.ellipse([px(512 - 346), px(512 - 346), px(512 + 346), px(512 + 346)], fill=KEY_RIM)
d.ellipse([px(512 - 336), px(512 - 336), px(512 + 336), px(512 + 336)], fill=KEY_FACE)

# soft top-light on the disc (blurred, then clipped to the disc so it reads as a smooth dome, not a
# hard two-tone seam)
sheen = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ImageDraw.Draw(sheen).ellipse([px(512 - 300), px(512 - 322), px(512 + 300), px(512 + 40)], fill=(*KEY_TOP, 210))
sheen = sheen.filter(ImageFilter.GaussianBlur(px(40)))
disc_mask = Image.new("L", (N, N), 0)
ImageDraw.Draw(disc_mask).ellipse([px(512 - 336), px(512 - 336), px(512 + 336), px(512 + 336)], fill=255)
r_, g_, b_, a_ = sheen.split()
sheen = Image.merge("RGBA", (r_, g_, b_, ImageChops.multiply(a_, disc_mask)))
img.paste(sheen, (0, 0), sheen)

def chevron(cx, cy, direction, reach, thick, color):
    cx, cy, reach, thick = px(cx), px(cy), px(reach), px(thick)
    ang = {"up": -90, "down": 90, "left": 180, "right": 0}[direction]
    a = math.radians(ang)
    tipx, tipy = cx + reach * math.cos(a), cy + reach * math.sin(a)
    for da in (135, -135):
        b = math.radians(ang + da)
        ex, ey = tipx + reach * math.cos(b), tipy + reach * math.sin(b)
        d.line([(tipx, tipy), (ex, ey)], fill=color, width=int(thick))
        for pt in ((tipx, tipy), (ex, ey)):
            d.ellipse([pt[0] - thick / 2, pt[1] - thick / 2, pt[0] + thick / 2, pt[1] + thick / 2], fill=color)

for dr, (x, y) in [("up", (512, 246)), ("down", (512, 778)), ("left", (246, 512)), ("right", (778, 512))]:
    chevron(x, y, dr, 40, 34, GLYPH)

# central OK button + soft top highlight
r = px(138)
d.ellipse([CX - r, CY - r, CX + r, CY + r], fill=BLUE)
hl = Image.new("RGBA", (int(2 * r), int(2 * r)), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse([r * 0.28, r * 0.16, r * 1.72, r * 1.15], fill=(*BLUE_TOP, 150))
img.paste(hl, (int(CX - r), int(CY - r)), hl)

img.resize((FINAL, FINAL), Image.LANCZOS).convert("RGB").save(OUT, "PNG")
print("wrote", OUT)
