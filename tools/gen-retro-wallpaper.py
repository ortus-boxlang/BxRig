#!/usr/bin/env python3
"""Draws the wallpaper of the bxrig-retro theme: assets/wallpapers/bxrig-retro.jpg, 2560x1440.
A sliced sunset sun, neon mountains, a perspective grid, stars, scanlines and a vignette, in the palette of themes/bxrig-retro/colors.toml.
Nothing is random: the stars come from a fixed small generator, so the same Pillow draws the same pixels. Run when the design changes:
    python3 tools/gen-retro-wallpaper.py [OUTPUT.jpg]       (needs Pillow; the picture is committed, building needs nothing extra)
Original artwork made for BxRig (see assets/wallpapers/README.md)."""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'assets/wallpapers/bxrig-retro.jpg')
W, H = 2560, 1440
SS = 2                      # supersampling: draw at twice the size, shrink at the end
w, h = W * SS, H * SS
U = w / 1600.0              # the design is laid out on 1600x900 and scaled
HORIZON = int(540 * U)

VOID, DEEP, NIGHT, DUSK = (11, 6, 24), (18, 10, 38), (26, 16, 51), (58, 38, 112)
MAG, CYAN, VIOLET, MOON = (255, 46, 196), (25, 230, 255), (180, 76, 255), (242, 233, 255)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ramp(stops, t):
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 0)
    return stops[-1][1]


def vgradient(width, top, height, stops):
    im = Image.new('RGB', (width, height))
    d = ImageDraw.Draw(im)
    for y in range(height):
        d.line([(0, y), (width, y)], fill=ramp(stops, y / max(1, height - 1)))
    return im


def glow(layer, radius):
    """layer (RGBA) blurred and returned; composited under the sharp drawing for a neon halo."""
    return layer.filter(ImageFilter.GaussianBlur(radius))


img = Image.new('RGB', (w, h), VOID)
# sky
sky = vgradient(w, 0, HORIZON, [(0, VOID), (.45, (42, 17, 96)), (.8, (138, 31, 156)), (1, (255, 77, 154))])
img.paste(sky, (0, 0))
# ground
gnd = vgradient(w, 0, h - HORIZON, [(0, (58, 19, 120)), (.25, (26, 10, 58)), (1, VOID)])
img.paste(gnd, (0, HORIZON))

# stars: a small fixed generator (no random module, so the picture never changes between runs)
d = ImageDraw.Draw(img, 'RGBA')
seed = 2654435769
for i in range(190):
    seed = (seed * 1664525 + 1013904223) % 4294967296
    x = (seed >> 8) % w
    seed = (seed * 1664525 + 1013904223) % 4294967296
    y = ((seed >> 8) % int(HORIZON * 0.78))
    seed = (seed * 1664525 + 1013904223) % 4294967296
    r = (0.8 + ((seed >> 8) % 9) / 10.0) * U
    a = 90 + ((seed >> 4) % 4) * 55
    d.ellipse([x - r, y - r, x + r, y + r], fill=MOON + (min(255, a),))

# sun: a big soft halo, then the disc with horizontal slices cut out of its lower half
cx, cy, R = int(800 * U), int(350 * U), int(190 * U)
halo = Image.new('RGBA', (w, h), (0, 0, 0, 0))
ImageDraw.Draw(halo).ellipse([cx - R * 1.1, cy - R * 1.1, cx + R * 1.1, cy + R * 1.1], fill=MAG + (150,))
img.paste(glow(halo, 26 * U), (0, 0), glow(halo, 26 * U))
sun = Image.new('RGB', (2 * R, 2 * R))
sd = ImageDraw.Draw(sun)
for y in range(2 * R):
    sd.line([(0, y), (2 * R, y)], fill=ramp([(0, (255, 228, 92)), (.5, (255, 138, 61)), (1, MAG)], y / (2 * R - 1)))
mask = Image.new('L', (2 * R, 2 * R), 0)
md = ImageDraw.Draw(mask)
md.ellipse([0, 0, 2 * R - 1, 2 * R - 1], fill=255)
for (top, thick) in [(204, 3), (232, 5), (260, 8), (289, 11), (319, 14)]:
    y0 = int(top * U)
    md.rectangle([0, y0, 2 * R, y0 + int(thick * U)], fill=0)
img.paste(sun, (cx - R, cy - R), mask)

# mountains: dark body, neon outline, glowing
def mountains(polys, fill, line, width, alpha=255):
    body = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    for p in polys:
        pts = [(int(x * U), int(y * U)) for x, y in p]
        bd.polygon(pts, fill=fill + (alpha,))
    edge = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    for p in polys:
        pts = [(int(x * U), int(y * U)) for x, y in p]
        ed.line(pts + [pts[0]], fill=line + (255,), width=int(width * U), joint='curve')
    halo = glow(edge, 3.5 * U)
    img.paste(body, (0, 0), body)
    img.paste(halo, (0, 0), halo)
    img.paste(edge, (0, 0), edge)

mountains([[(0, 540), (0, 468), (90, 402), (168, 452), (262, 358), (362, 470), (436, 430), (528, 540)],
           [(1070, 540), (1176, 452), (1268, 392), (1338, 440), (1432, 352), (1520, 432), (1600, 402), (1600, 540)]], (27, 11, 68), CYAN, 2)
mountains([[(300, 540), (380, 478), (452, 500), (540, 446), (640, 540)],
           [(930, 540), (1010, 470), (1090, 500), (1176, 452), (1256, 540)]], (42, 17, 96), MAG, 1.6, 245)

# the horizon glow band
band = Image.new('RGBA', (w, h), (0, 0, 0, 0))
bdraw = ImageDraw.Draw(band)
for y in range(int(52 * U)):
    t = y / (52 * U)
    a = int(140 * (1 - abs(t - .5) * 2))
    bdraw.line([(0, HORIZON - int(26 * U) + y), (w, HORIZON - int(26 * U) + y)], fill=MAG + (a,))
img.paste(band, (0, 0), band)

# the perspective grid: horizontal lines bunch up toward the horizon, vertical ones run to the vanishing point
grid = Image.new('RGBA', (w, h), (0, 0, 0, 0))
gd = ImageDraw.Draw(grid)
gh = h - HORIZON
for i in range(1, 27):
    t = (i / 26.0) ** 2.2
    y = HORIZON + int(t * gh)
    gd.line([(0, y), (w, y)], fill=MAG + (int(120 + 135 * t),), width=max(1, int((1.2 + 2.6 * t) * U)))
vx = w // 2
for k in range(-34, 35):
    bx = vx + k * int(112 * U)
    gd.line([(vx, HORIZON), (bx, h)], fill=MAG + (200,), width=max(1, int(2.2 * U)))
gdim = grid.copy()
img.paste(glow(grid, 4 * U), (0, 0), glow(grid, 4 * U))
img.paste(grid, (0, 0), grid)
hz = Image.new('RGBA', (w, h), (0, 0, 0, 0))
ImageDraw.Draw(hz).line([(0, HORIZON), (w, HORIZON)], fill=CYAN + (255,), width=int(3 * U))
img.paste(glow(hz, 5 * U), (0, 0), glow(hz, 5 * U))
img.paste(hz, (0, 0), hz)

# scanlines and a vignette
scan = Image.new('RGBA', (w, h), (0, 0, 0, 0))
sdraw = ImageDraw.Draw(scan)
step = int(4 * U)
for y in range(0, h, step):
    sdraw.rectangle([0, y, w, y + int(1.6 * U)], fill=(0, 0, 0, 40))
img.paste(scan, (0, 0), scan)
vig = Image.new('L', (w, h), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-w * .18, -h * .25, w * 1.18, h * 1.25], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(w * .12))
dark = Image.new('RGB', (w, h), (0, 0, 0))
img = Image.composite(img, Image.blend(img, dark, .55), vig)

img = img.resize((W, H), Image.LANCZOS)
os.makedirs(os.path.dirname(out_path), exist_ok=True)
img.save(out_path, 'JPEG', quality=84, optimize=False, progressive=False, subsampling=0)
print('wrote %s (%d bytes)' % (out_path, os.path.getsize(out_path)))
