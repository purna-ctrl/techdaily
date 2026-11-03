#!/usr/bin/env python3
"""Generates the per-category Open Graph images (1200x630 PNG) into web/og/.

Run once from the repo root (needs Pillow):  python3 tool/og/generate_og.py
The PNGs are committed; `flutter build web` copies them to build/web/og/.
Used as og:image for category pages, and for stories that have no publisher image. Each card uses the
category colour and the same gradient-mesh background as web/art/<category>.svg (tool/art/generate_art.py).
"""
import math
import os

import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'art'))
from generate_art import BLOBS, COLORS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "web", "og")
FONTS = os.path.join(ROOT, "assets", "fonts")

W, H = 1200, 630
INK = (11, 11, 15)
SURFACE = (21, 21, 27)
LINE = (38, 38, 48)
PAPER = (244, 242, 236)
MUTED = (185, 181, 173)
ACCENT = (255, 90, 31)

CATS = [
    ("top-stories", "Top Stories"),
    ("scams-security", "Scams & Security"),
    ("ai", "AI"),
    ("phones-gadgets", "Phones & Gadgets"),
    ("chips-hardware", "Chips & Hardware"),
    ("startups-india", "Startups & India"),
    ("innovations", "Innovations"),
    ("money-fintech", "Money & Fintech"),
    ("privacy", "Privacy"),
    ("telecom", "Telecom & Internet"),
    ("digital-india", "Digital India"),
    ("ev-mobility", "EVs & Mobility"),
    ("space", "Space Tech"),
    ("apps-gaming", "Apps & Gaming"),
    ("health-tech", "Health Tech"),
    ("jobs-skills", "Tech Jobs & Skills"),
]


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def glyph(d: ImageDraw.ImageDraw, cid: str, cx: int, cy: int, r: int):
    """Simple geometric category mark in the accent colour."""
    w = 14
    if cid == "scams-security":  # shield with a check
        pts = [(cx - r * 0.8, cy - r * 0.75), (cx, cy - r), (cx + r * 0.8, cy - r * 0.75), (cx + r * 0.8, cy), (cx, cy + r), (cx - r * 0.8, cy)]
        d.polygon(pts, outline=ACCENT, width=w)
        d.line([(cx - r * 0.35, cy - r * 0.05), (cx - r * 0.05, cy + r * 0.28), (cx + r * 0.42, cy - r * 0.35)], fill=ACCENT, width=w, joint="curve")
    elif cid == "ai":  # four-point spark + small spark
        def spark(x, y, s):
            d.polygon([(x, y - s), (x + s * 0.22, y - s * 0.22), (x + s, y), (x + s * 0.22, y + s * 0.22), (x, y + s), (x - s * 0.22, y + s * 0.22), (x - s, y), (x - s * 0.22, y - s * 0.22)], fill=ACCENT)
        spark(cx - r * 0.15, cy + r * 0.1, r * 0.85)
        spark(cx + r * 0.7, cy - r * 0.7, r * 0.3)
    elif cid == "phones-gadgets":  # phone
        d.rounded_rectangle([cx - r * 0.5, cy - r, cx + r * 0.5, cy + r], radius=int(r * 0.18), outline=ACCENT, width=w)
        d.rounded_rectangle([cx - r * 0.16, cy - r * 0.86, cx + r * 0.16, cy - r * 0.78], radius=6, fill=ACCENT)
        d.ellipse([cx - 12, cy + r * 0.72 - 12, cx + 12, cy + r * 0.72 + 12], fill=ACCENT)
    elif cid == "chips-hardware":  # chip with pins
        s = r * 0.62
        d.rounded_rectangle([cx - s, cy - s, cx + s, cy + s], radius=18, outline=ACCENT, width=w)
        d.rectangle([cx - s * 0.45, cy - s * 0.45, cx + s * 0.45, cy + s * 0.45], fill=ACCENT)
        for i in range(-2, 3):
            o = i * s * 0.38
            for a, b in (((cx + o, cy - s), (cx + o, cy - r)), ((cx + o, cy + s), (cx + o, cy + r)), ((cx - s, cy + o), (cx - r, cy + o)), ((cx + s, cy + o), (cx + r, cy + o))):
                d.line([a, b], fill=ACCENT, width=10)
    elif cid == "startups-india":  # rising bars + arrow
        base = cy + r * 0.8
        for i, hgt in enumerate((0.45, 0.8, 1.2, 1.6)):
            x = cx - r * 0.9 + i * r * 0.5
            d.rounded_rectangle([x, base - r * hgt, x + r * 0.32, base], radius=8, fill=ACCENT if i == 3 else None, outline=ACCENT, width=10)
        d.line([(cx - r * 0.9, cy - r * 0.1), (cx + r * 0.75, cy - r * 0.95)], fill=ACCENT, width=w)
        d.polygon([(cx + r * 0.95, cy - r * 1.05), (cx + r * 0.5, cy - r * 1.0), (cx + r * 0.85, cy - r * 0.6)], fill=ACCENT)
    elif cid == "innovations":  # atom
        for ang in (0, 60, 120):
            box = Image.new("RGBA", (int(r * 2.4), int(r * 2.4)), (0, 0, 0, 0))
            bd = ImageDraw.Draw(box)
            bd.ellipse([r * 0.1, r * 0.75, r * 2.3, r * 1.65], outline=ACCENT + (255,), width=w)
            box = box.rotate(ang, resample=Image.BICUBIC)
            d._image.paste(box, (int(cx - r * 1.2), int(cy - r * 1.2)), box)
        d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=ACCENT)
    elif cid == "money-fintech":  # coin with rupee sign
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ACCENT, width=w)
        f = font("Inter-800.ttf", int(r * 1.15))
        d.text((cx, cy + 4), "\u20b9", font=f, fill=ACCENT, anchor="mm")
    elif cid == "privacy":  # eye with slash
        R = r * 1.35
        d.arc([cx - R, cy + r * 0.9 - R, cx + R, cy + r * 0.9 + R], 222, 318, fill=ACCENT, width=w)
        d.arc([cx - R, cy - r * 0.9 - R, cx + R, cy - r * 0.9 + R], 42, 138, fill=ACCENT, width=w)
        d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=ACCENT)
        d.line([(cx - r * 0.85, cy + r * 0.85), (cx + r * 0.85, cy - r * 0.85)], fill=INK, width=w + 16)
        d.line([(cx - r * 0.85, cy + r * 0.85), (cx + r * 0.85, cy - r * 0.85)], fill=ACCENT, width=w)
    elif cid == "telecom":  # tower + signal arcs
        d.line([(cx - r * 0.45, cy + r), (cx, cy - r * 0.2), (cx + r * 0.45, cy + r)], fill=ACCENT, width=w, joint="curve")
        d.ellipse([cx - 16, cy - r * 0.2 - 16, cx + 16, cy - r * 0.2 + 16], fill=ACCENT)
        for k in (0.45, 0.8):
            R = r * k
            box = [cx - R, cy - r * 0.2 - R, cx + R, cy - r * 0.2 + R]
            d.arc(box, 300, 360, fill=ACCENT, width=w)
            d.arc(box, 0, 30, fill=ACCENT, width=w)
            d.arc(box, 150, 240, fill=ACCENT, width=w)
    elif cid == "digital-india":  # fingerprint arcs
        for i, k in enumerate((0.25, 0.5, 0.75, 1.0)):
            R = r * k
            d.arc([cx - R, cy - R, cx + R, cy + R], 190 - i * 6, 350 + i * 6, fill=ACCENT, width=12)
        d.line([(cx, cy), (cx, cy + r * 0.8)], fill=ACCENT, width=12)
        d.arc([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], 0, 80, fill=ACCENT, width=12)
    elif cid == "ev-mobility":  # lightning bolt
        d.polygon([(cx + r * 0.15, cy - r), (cx - r * 0.55, cy + r * 0.12), (cx - r * 0.05, cy + r * 0.12), (cx - r * 0.2, cy + r), (cx + r * 0.55, cy - r * 0.18), (cx + r * 0.05, cy - r * 0.18)], fill=ACCENT)
    elif cid == "space":  # rocket
        d.rounded_rectangle([cx - r * 0.3, cy - r, cx + r * 0.3, cy + r * 0.55], radius=int(r * 0.3), outline=ACCENT, width=w)
        d.ellipse([cx - 18, cy - r * 0.35 - 18, cx + 18, cy - r * 0.35 + 18], fill=ACCENT)
        d.polygon([(cx - r * 0.3, cy + r * 0.1), (cx - r * 0.7, cy + r * 0.75), (cx - r * 0.3, cy + r * 0.55)], fill=ACCENT)
        d.polygon([(cx + r * 0.3, cy + r * 0.1), (cx + r * 0.7, cy + r * 0.75), (cx + r * 0.3, cy + r * 0.55)], fill=ACCENT)
        d.line([(cx, cy + r * 0.65), (cx, cy + r)], fill=ACCENT, width=w)
    elif cid == "apps-gaming":  # gamepad
        d.rounded_rectangle([cx - r, cy - r * 0.5, cx + r, cy + r * 0.5], radius=int(r * 0.5), outline=ACCENT, width=w)
        d.line([(cx - r * 0.65, cy), (cx - r * 0.25, cy)], fill=ACCENT, width=w)
        d.line([(cx - r * 0.45, cy - r * 0.2), (cx - r * 0.45, cy + r * 0.2)], fill=ACCENT, width=w)
        for (x, y) in ((cx + r * 0.35, cy - r * 0.1), (cx + r * 0.6, cy + r * 0.12)):
            d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=ACCENT)
    elif cid == "health-tech":  # heart + pulse
        R = r * 0.5
        d.ellipse([cx - 2 * R, cy - R * 1.4, cx, cy + R * 0.6], outline=ACCENT, width=w)
        d.ellipse([cx, cy - R * 1.4, cx + 2 * R, cy + R * 0.6], outline=ACCENT, width=w)
        d.polygon([(cx - 1.85 * R, cy + 0.05 * R), (cx, cy + 2 * R), (cx + 1.85 * R, cy + 0.05 * R)], fill=SURFACE)
        d.line([(cx - 1.85 * R, cy + 0.05 * R), (cx, cy + 2 * R), (cx + 1.85 * R, cy + 0.05 * R)], fill=ACCENT, width=w, joint="curve")
        d.line([(cx - r, cy), (cx - r * 0.35, cy), (cx - r * 0.15, cy - r * 0.4), (cx + r * 0.1, cy + r * 0.35), (cx + r * 0.3, cy), (cx + r, cy)], fill=INK, width=w + 12, joint="curve")
        d.line([(cx - r, cy), (cx - r * 0.35, cy), (cx - r * 0.15, cy - r * 0.4), (cx + r * 0.1, cy + r * 0.35), (cx + r * 0.3, cy), (cx + r, cy)], fill=ACCENT, width=w, joint="curve")
    elif cid == "jobs-skills":  # briefcase
        d.rounded_rectangle([cx - r, cy - r * 0.45, cx + r, cy + r * 0.8], radius=24, outline=ACCENT, width=w)
        d.rounded_rectangle([cx - r * 0.35, cy - r * 0.8, cx + r * 0.35, cy - r * 0.45], radius=14, outline=ACCENT, width=w)
        d.line([(cx - r, cy + r * 0.1), (cx + r, cy + r * 0.1)], fill=ACCENT, width=w)
        d.rectangle([cx - 20, cy - 4, cx + 20, cy + 36], fill=ACCENT)
    else:  # top stories: stacked cards with a "5"
        for i in range(3):
            o = i * 26
            d.rounded_rectangle([cx - r * 0.8 + o, cy - r * 0.8 - o, cx + r * 0.8 + o, cy + r * 0.8 - o], radius=24, outline=ACCENT, width=10, fill=INK)
        f = font("SpaceGrotesk-700.ttf", int(r * 1.2))
        d.text((cx + 52, cy - 52), "5", font=f, fill=ACCENT, anchor="mm")


def wrap(d, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if d.textlength(t, font=f) <= max_w:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mesh(cid):
    """Soft radial colour blobs on ink (same spec as the SVG art)."""
    img = Image.new("RGB", (W, H), INK)
    base, sec, ter, _ = COLORS[cid]
    cols = [rgb(base), rgb(sec), rgb(ter)]
    grad = Image.radial_gradient("L")  # 256x256, 0 centre -> 255 edge
    for cx, cy, r, k, a in BLOBS[cid]:
        cy = cy * H / 675
        size = int(r * 2)
        mask = grad.resize((size, size)).point(lambda v, a=a: int(max(0, 255 - v * 1.42) * a))
        img.paste(Image.new("RGB", (size, size), cols[k]), (int(cx - r), int(cy - r)), mask)
    # left scrim so the label always reads (WCAG: paper text on <= #2x2x2x)
    scrim = Image.linear_gradient("L").rotate(90).resize((W, H)).point(lambda v: int(min(255, v * 1.15)))
    img = Image.composite(img, Image.new("RGB", (W, H), INK), scrim)
    d = ImageDraw.Draw(img)
    for x in range(0, W, 24):
        for y in range(0, H, 24):
            d.point((x + 2, y + 2), fill=(40, 40, 48))
    return img


def make(cid, label):
    global ACCENT
    ACCENT = rgb(COLORS[cid][0])
    img = mesh(cid)
    d = ImageDraw.Draw(img)
    # glyph panel
    d.ellipse([780, 135, 1140, 495], fill=SURFACE, outline=ACCENT, width=3)
    glyph(d, cid, 960, 315, 120)
    # wordmark
    wm = font("SpaceGrotesk-700.ttf", 48)
    d.text((72, 64), "Tech", font=wm, fill=PAPER)
    d.text((72 + d.textlength("Tech", font=wm), 64), "Daily", font=wm, fill=rgb(COLORS["top-stories"][0]))
    # category
    size = 104
    f = font("SpaceGrotesk-700.ttf", size)
    lines = wrap(d, label, f, 660)
    while len(lines) > 2 or any(d.textlength(l, font=f) > 660 for l in lines):
        size -= 6
        f = font("SpaceGrotesk-700.ttf", size)
        lines = wrap(d, label, f, 660)
    y = 330 - (len(lines) * size * 1.05) / 2
    for line in lines:
        d.text((72, y), line, font=f, fill=PAPER)
        y += size * 1.05
    d.rectangle([72, 488, 72 + 120, 496], fill=ACCENT)
    tf = font("Inter-500.ttf", 30)
    d.text((72, 520), "Tech news in simple words \u00b7 for India", font=tf, fill=MUTED)
    img.save(os.path.join(OUT, f"{cid}.png"), optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for cid, label in CATS:
        make(cid, label)
    # Site-wide default preview
    make("top-stories", "Top Stories")
    import shutil

    shutil.copy(os.path.join(OUT, "top-stories.png"), os.path.join(OUT, "default.png"))
    print("wrote", len(CATS) + 1, "images to", OUT)
