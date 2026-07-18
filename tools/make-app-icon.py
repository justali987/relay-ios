"""Regenerate Relay's 1024x1024 App Store icon.

Run from the repo root:  python tools/make-app-icon.py   (requires Pillow: pip install Pillow)

Motif: the antenna / radio-waves mark from the in-app Welcome screen — a central emitter with waves
relaying left and right (horizontal orientation reads as "relay", not a generic upward Wi-Fi glyph).
Electric blue on graphite, matching the design tokens. Drawn at 4x and downsampled with LANCZOS for
crisp anti-aliasing. Saved as opaque RGB (Apple rejects alpha in the 1024 icon).
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(
    os.path.dirname(__file__), "..", "Relay", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "AppIcon-1024.png",
)
FINAL = 1024
S = 4  # supersample factor
N = FINAL * S
cx = cy = N / 2

BG_TOP = (26, 29, 36)
BG_BOT = (11, 13, 17)
EMITTER = (94, 164, 255)
WAVE_NEAR = (61, 139, 255)
WAVE_FAR = (44, 108, 214)

img = Image.new("RGB", (N, N), BG_BOT)
draw = ImageDraw.Draw(img)

for y in range(N):
    t = y / (N - 1)
    draw.line(
        [(0, y), (N, y)],
        fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOT)),
    )

def deg(a):
    return a * math.pi / 180.0

def arc_with_caps(radius, half_angle, center_deg, width, color):
    r = radius * S
    w = width * S
    bbox = [cx - r, cy - r, cx + r, cy + r]
    start, end = center_deg - half_angle, center_deg + half_angle
    draw.arc(bbox, start, end, fill=color, width=int(w))
    cap = w / 2
    for ang in (start, end):
        px = cx + r * math.cos(deg(ang))
        py = cy + r * math.sin(deg(ang))
        draw.ellipse([px - cap, py - cap, px + cap, py + cap], fill=color)

arc_with_caps(300, 46, 0, 46, WAVE_FAR)
arc_with_caps(300, 46, 180, 46, WAVE_FAR)
arc_with_caps(185, 52, 0, 46, WAVE_NEAR)
arc_with_caps(185, 52, 180, 46, WAVE_NEAR)

er = 62 * S
draw.ellipse([cx - er, cy - er, cx + er, cy + er], fill=EMITTER)

img.resize((FINAL, FINAL), Image.LANCZOS).convert("RGB").save(os.path.normpath(OUT), "PNG")
print("wrote", os.path.normpath(OUT))
