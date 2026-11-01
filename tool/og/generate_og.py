#!/usr/bin/env python3
"""Generates the per-category Open Graph images (1200x630 PNG) into web/og/.

Run once from the repo root (needs Pillow):  python3 tool/og/generate_og.py
The PNGs are committed; `flutter build web` copies them to build/web/og/.
No publisher images are used anywhere: every preview is this generated category art.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

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


def make(cid, label):
    img = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(img)
    # subtle grid
    for x in range(0, W, 60):
        d.line([(x, 0), (x, H)], fill=(17, 17, 23), width=1)
    for y in range(0, H, 60):
        d.line([(0, y), (W, y)], fill=(17, 17, 23), width=1)
    # glyph panel
    d.ellipse([780, 135, 1140, 495], fill=SURFACE, outline=LINE, width=2)
    glyph(d, cid, 960, 315, 120)
    # wordmark
    wm = font("SpaceGrotesk-700.ttf", 48)
    d.text((72, 64), "Tech", font=wm, fill=PAPER)
    d.text((72 + d.textlength("Tech", font=wm), 64), "Daily", font=wm, fill=ACCENT)
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
