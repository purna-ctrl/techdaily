#!/usr/bin/env python3
"""Generates TechDaily's category artwork from ONE spec, in two forms that look the same:

  web/art/<category>.svg                       static pages (fallback behind every story image)
  lib/widgets/v3/category_art_data.dart        Flutter CustomPainter data (app fallback)

Each artwork is a 1200x675 gradient mesh (soft radial colour blobs on near-black), a faint dot grid
and a category motif (radar for scams, neural net for AI, phones, a chip, rising bars, an atom,
coins and a rupee, a padlock, a sunburst). Run from the repo root:  python3 tool/art/generate_art.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 1200, 675
BG = "#0B0B0F"

# id: (base colour, secondary, tertiary, light tint for strokes)
COLORS = {
    "scams-security": ("#FF3B4E", "#FF9F1C", "#7C1D3F", "#FF7683"),
    "ai": ("#8B5CF6", "#EC4899", "#3B82F6", "#B090F9"),
    "phones-gadgets": ("#3B82F6", "#06B6D4", "#8B5CF6", "#72A5F9"),
    "chips-hardware": ("#22C55E", "#A3E635", "#0EA5E9", "#6EE7A0"),
    "startups-india": ("#FF9933", "#FF3B4E", "#138808", "#FFB870"),
    "innovations": ("#06B6D4", "#3B82F6", "#22C55E", "#67E8F9"),
    "money-fintech": ("#EAB308", "#F97316", "#22C55E", "#FDE047"),
    "privacy": ("#14B8A6", "#3B82F6", "#0EA5E9", "#5EEAD4"),
    "top-stories": ("#FF5A1F", "#FF3B4E", "#EAB308", "#FF8255"),
}

# Blobs: (cx, cy, r, colour key 0/1/2, opacity)
BLOBS = {
    "scams-security": [(880, 320, 520, 0, 0.55), (230, 620, 420, 2, 0.7), (1150, 40, 300, 1, 0.35)],
    "ai": [(820, 260, 520, 0, 0.6), (260, 560, 420, 1, 0.4), (1100, 640, 360, 2, 0.45)],
    "phones-gadgets": [(840, 300, 520, 0, 0.55), (180, 120, 380, 2, 0.4), (1050, 650, 360, 1, 0.4)],
    "chips-hardware": [(860, 340, 500, 0, 0.5), (240, 600, 400, 2, 0.4), (1120, 60, 280, 1, 0.35)],
    "startups-india": [(860, 280, 520, 0, 0.6), (200, 600, 420, 1, 0.4), (1100, 660, 320, 2, 0.45)],
    "innovations": [(820, 320, 520, 0, 0.55), (200, 140, 380, 1, 0.4), (1080, 640, 340, 2, 0.4)],
    "money-fintech": [(860, 300, 500, 0, 0.5), (220, 600, 420, 1, 0.4), (1120, 640, 320, 2, 0.35)],
    "privacy": [(840, 320, 520, 0, 0.5), (220, 120, 360, 1, 0.4), (1080, 660, 340, 2, 0.4)],
    "top-stories": [(860, 300, 540, 0, 0.6), (220, 600, 420, 1, 0.45), (1120, 60, 300, 2, 0.35)],
}


def motif(cid):
    """List of primitives. Colours: 't' tint, 'c' base, 'w' white. Opacity a. Stroke width sw (0 = fill)."""
    P = []
    if cid == "scams-security":
        cx, cy = 820, 340
        for i, r in enumerate((70, 140, 210, 280)):
            P.append(("circle", cx, cy, r, "t", 0.55 - i * 0.1, 3))
        P.append(("line", cx, cy, cx + 260 * math.cos(-0.7), cy + 260 * math.sin(-0.7), "t", 0.8, 5))
        P.append(("poly", [(cx, cy), (cx + 280 * math.cos(-0.7), cy + 280 * math.sin(-0.7)), (cx + 280 * math.cos(-1.15), cy + 280 * math.sin(-1.15))], True, "c", 0.25, 0))
        for (x, y, r) in ((cx + 120, cy - 150, 12), (cx - 170, cy + 60, 9), (cx + 60, cy + 190, 10)):
            P.append(("circle", x, y, r, "w", 0.85, 0))
        # warning triangle
        tx, ty = 330, 250
        P.append(("poly", [(tx, ty - 70), (tx + 80, ty + 70), (tx - 80, ty + 70)], True, "t", 0.5, 8))
        P.append(("line", tx, ty - 22, tx, ty + 22, "t", 0.6, 10))
        P.append(("circle", tx, ty + 46, 6, "t", 0.6, 0))
    elif cid == "ai":
        cols = [(640, [200, 340, 480]), (820, [140, 270, 410, 540]), (1000, [230, 450])]
        nodes = [[(x, y) for y in ys] for x, ys in cols]
        for a, b in ((0, 1), (1, 2)):
            for p in nodes[a]:
                for q in nodes[b]:
                    P.append(("line", p[0], p[1], q[0], q[1], "t", 0.28, 2))
        for col in nodes:
            for (x, y) in col:
                P.append(("circle", x, y, 18, "c", 0.95, 0))
                P.append(("circle", x, y, 30, "t", 0.5, 3))
        # sparkle
        sx, sy, s = 300, 230, 90
        P.append(("poly", [(sx, sy - s), (sx + s * 0.2, sy - s * 0.2), (sx + s, sy), (sx + s * 0.2, sy + s * 0.2), (sx, sy + s), (sx - s * 0.2, sy + s * 0.2), (sx - s, sy), (sx - s * 0.2, sy - s * 0.2)], True, "t", 0.6, 0))
    elif cid == "phones-gadgets":
        for i, (x, y, rot, a) in enumerate(((700, 140, -14, 0.35), (820, 110, -4, 0.55), (950, 130, 8, 0.8))):
            P.append(("rrect", x, y, 190, 400, 34, rot, "t", a, 5))
            P.append(("rrect", x + 70, y + 18, 50, 12, 6, rot, "t", a, 0))
        for r in (60, 100, 140):
            P.append(("arc", 330, 420, r, -135, 90, "t", 0.55, 8))
        P.append(("circle", 330, 420, 14, "t", 0.7, 0))
    elif cid == "chips-hardware":
        cx, cy, s = 860, 330, 130
        P.append(("rrect", cx - s, cy - s, 2 * s, 2 * s, 24, 0, "t", 0.75, 6))
        P.append(("rrect", cx - 60, cy - 60, 120, 120, 12, 0, "c", 0.8, 0))
        for i in range(-2, 3):
            o = i * 46
            P.append(("line", cx + o, cy - s, cx + o, cy - s - 60, "t", 0.6, 6))
            P.append(("line", cx + o, cy + s, cx + o, cy + s + 60, "t", 0.6, 6))
            P.append(("line", cx - s, cy + o, cx - s - 60, cy + o, "t", 0.6, 6))
            P.append(("line", cx + s, cy + o, cx + s + 60, cy + o, "t", 0.6, 6))
        for pts in (
            [(cx - s - 60, cy - 46), (520, cy - 46), (460, 180), (240, 180)],
            [(cx - s - 60, cy + 46), (540, cy + 46), (480, 470), (200, 470)],
            [(cx + 46, cy + s + 60), (cx + 46, 620), (1150, 620)],
        ):
            P.append(("poly", pts, False, "t", 0.4, 4))
            P.append(("circle", pts[-1][0], pts[-1][1], 10, "t", 0.7, 0))
    elif cid == "startups-india":
        base = 560
        for i, hgt in enumerate((110, 180, 260, 350, 440)):
            x = 620 + i * 100
            P.append(("rrect", x, base - hgt, 64, hgt, 14, 0, "t" if i < 4 else "c", 0.35 + i * 0.12, 0))
        P.append(("poly", [(560, 470), (700, 400), (800, 420), (920, 280), (1040, 220), (1130, 110)], False, "w", 0.85, 7))
        P.append(("poly", [(1150, 80), (1095, 105), (1135, 140)], True, "w", 0.9, 0))
        for (x, y, r) in ((260, 160, 6), (360, 260, 4), (180, 330, 5), (420, 120, 3)):
            P.append(("circle", x, y, r, "t", 0.8, 0))
    elif cid == "innovations":
        cx, cy = 840, 330
        for rot in (0, 60, 120):
            P.append(("ellipse", cx, cy, 260, 90, rot, "t", 0.6, 5))
        P.append(("circle", cx, cy, 40, "c", 0.95, 0))
        P.append(("circle", cx, cy, 64, "t", 0.4, 3))
        for ang, rot in ((30, 0), (200, 60), (300, 120)):
            a, r = math.radians(ang), math.radians(rot)
            x, y = 260 * math.cos(a), 90 * math.sin(a)
            P.append(("circle", cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r), 14, "w", 0.9, 0))
        for (x, y) in ((260, 180), (330, 230), (230, 300)):
            P.append(("circle", x, y, 8, "t", 0.6, 0))
    elif cid == "money-fintech":
        cx, cy = 870, 330
        for i, (dx, dy, r) in enumerate(((-150, 110, 120), (0, 0, 180), (170, 130, 110))):
            P.append(("circle", cx + dx, cy + dy, r, "t", 0.35 + i * 0.12, 6))
        # rupee sign (strokes)
        x, y = cx - 50, cy - 90
        P.append(("line", x, y, x + 110, y, "w", 0.9, 14))
        P.append(("line", x, y + 45, x + 110, y + 45, "w", 0.9, 14))
        P.append(("poly", [(x, y), (x + 40, y), (x + 70, y + 12), (x + 82, y + 45), (x + 70, y + 76), (x + 40, y + 88), (x + 5, y + 88), (x + 95, y + 185)], False, "w", 0.9, 14))
        P.append(("poly", [(170, 520), (300, 440), (390, 470), (520, 330)], False, "t", 0.55, 6))
        P.append(("poly", [(545, 300), (495, 315), (532, 350)], True, "t", 0.6, 0))
    elif cid == "privacy":
        cx, cy = 860, 360
        P.append(("arc", cx, cy - 70, 105, 180, 180, "t", 0.75, 26))
        P.append(("line", cx - 105, cy - 70, cx - 105, cy - 10, "t", 0.75, 26))
        P.append(("line", cx + 105, cy - 70, cx + 105, cy - 10, "t", 0.75, 26))
        P.append(("rrect", cx - 170, cy - 20, 340, 250, 36, 0, "c", 0.85, 0))
        P.append(("circle", cx, cy + 75, 30, "w", 0.95, 0))
        P.append(("rrect", cx - 12, cy + 85, 24, 70, 8, 0, "w", 0.95, 0))
        # masked password field: ••••••
        P.append(("rrect", 110, 290, 380, 96, 48, 0, "t", 0.55, 5))
        for i in range(6):
            P.append(("circle", 170 + i * 52, 338, 13, "w", 0.85 - i * 0.08, 0))
    else:  # top-stories: sunburst + stacked cards
        cx, cy = 860, 330
        for i in range(16):
            a = math.radians(i * 22.5)
            P.append(("line", cx + 120 * math.cos(a), cy + 120 * math.sin(a), cx + 300 * math.cos(a), cy + 300 * math.sin(a), "t", 0.35 if i % 2 else 0.6, 6))
        P.append(("circle", cx, cy, 95, "c", 0.95, 0))
        P.append(("circle", cx, cy, 120, "t", 0.5, 4))
        for i in range(3):
            P.append(("rrect", 200 + i * 28, 170 - i * 28, 220, 300, 26, 0, "t", 0.25 + i * 0.2, 4))
    return P


def color(cid, key):
    base, sec, ter, tint = COLORS[cid]
    return {"c": base, "t": tint, "w": "#FFFFFF", 0: base, 1: sec, 2: ter}[key]


def svg_for(cid):
    base, sec, ter, tint = COLORS[cid]
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" preserveAspectRatio="xMidYMid slice" role="img" aria-hidden="true">', "<defs>"]
    for i, (cx, cy, r, k, a) in enumerate(BLOBS[cid]):
        c = color(cid, k)
        out.append(f'<radialGradient id="b{i}"><stop offset="0" stop-color="{c}" stop-opacity="{a}"/><stop offset="1" stop-color="{c}" stop-opacity="0"/></radialGradient>')
    out.append('<pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.4" fill="#FFFFFF" fill-opacity=".07"/></pattern>')
    out.append(f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{BG}"/><stop offset="1" stop-color="{mix(BG, base, 0.18)}"/></linearGradient>')
    out.append("</defs>")
    out.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
    for i, (cx, cy, r, k, a) in enumerate(BLOBS[cid]):
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#b{i})"/>')
    out.append(f'<rect width="{W}" height="{H}" fill="url(#dots)"/>')
    for p in motif(cid):
        out.append(svg_prim(cid, p))
    out.append("</svg>")
    return "\n".join(out)


def f1(x):
    return f"{x:.1f}".rstrip("0").rstrip(".")


def paint(cid, ckey, a, sw):
    c = color(cid, ckey)
    if sw:
        return f'fill="none" stroke="{c}" stroke-opacity="{a}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"'
    return f'fill="{c}" fill-opacity="{a}"'


def svg_prim(cid, p):
    k = p[0]
    if k == "circle":
        _, x, y, r, c, a, sw = p
        return f'<circle cx="{f1(x)}" cy="{f1(y)}" r="{f1(r)}" {paint(cid, c, a, sw)}/>'
    if k == "line":
        _, x1, y1, x2, y2, c, a, sw = p
        return f'<line x1="{f1(x1)}" y1="{f1(y1)}" x2="{f1(x2)}" y2="{f1(y2)}" {paint(cid, c, a, sw)}/>'
    if k == "poly":
        _, pts, closed, c, a, sw = p
        tag = "polygon" if closed else "polyline"
        return f'<{tag} points="{" ".join(f"{f1(x)},{f1(y)}" for x, y in pts)}" {paint(cid, c, a, sw)}/>'
    if k == "rrect":
        _, x, y, w, h, rx, rot, c, a, sw = p
        tr = f' transform="rotate({rot} {f1(x + w / 2)} {f1(y + h / 2)})"' if rot else ""
        return f'<rect x="{f1(x)}" y="{f1(y)}" width="{f1(w)}" height="{f1(h)}" rx="{f1(rx)}"{tr} {paint(cid, c, a, sw)}/>'
    if k == "ellipse":
        _, x, y, rx, ry, rot, c, a, sw = p
        return f'<ellipse cx="{f1(x)}" cy="{f1(y)}" rx="{f1(rx)}" ry="{f1(ry)}" transform="rotate({rot} {f1(x)} {f1(y)})" {paint(cid, c, a, sw)}/>'
    if k == "arc":
        _, x, y, r, start, sweep, c, a, sw = p
        s, e = math.radians(start), math.radians(start + sweep)
        x1, y1 = x + r * math.cos(s), y + r * math.sin(s)
        x2, y2 = x + r * math.cos(e), y + r * math.sin(e)
        large = 1 if abs(sweep) > 180 else 0
        return f'<path d="M{f1(x1)} {f1(y1)} A{f1(r)} {f1(r)} 0 {large} 1 {f1(x2)} {f1(y2)}" {paint(cid, c, a, sw)}/>'
    raise ValueError(k)


def mix(a, b, t):
    a, b = a.lstrip("#"), b.lstrip("#")
    return "#" + "".join("%02X" % round(int(a[i:i + 2], 16) * (1 - t) + int(b[i:i + 2], 16) * t) for i in (0, 2, 4))


def dart_color(hexstr):
    return "Color(0xFF" + hexstr.lstrip("#").upper() + ")"


def dart():
    lines = [
        "// GENERATED by tool/art/generate_art.py — do not edit by hand.",
        "// Same artwork as web/art/<category>.svg, drawn by CategoryArtPainter.",
        "import 'dart:ui';",
        "",
        "/// One artwork: background tint, colour blobs and motif primitives in a 1200x675 space.",
        "class ArtSpec {",
        "  final Color base;",
        "  final Color secondary;",
        "  final Color tertiary;",
        "  final Color tint;",
        "  final Color bgEnd;",
        "  /// [cx, cy, r, colourIndex(0-2), opacity]",
        "  final List<List<double>> blobs;",
        "  final List<ArtPrim> prims;",
        "  const ArtSpec(this.base, this.secondary, this.tertiary, this.tint, this.bgEnd, this.blobs, this.prims);",
        "}",
        "",
        "/// kind: circle [x,y,r] · line [x1,y1,x2,y2] · poly [x,y,...] · rrect [x,y,w,h,rx,rot] · ellipse [x,y,rx,ry,rot] · arc [x,y,r,start,sweep]",
        "/// colour: 't' tint, 'c' base, 'w' white. strokeWidth 0 = fill.",
        "class ArtPrim {",
        "  final String kind;",
        "  final List<double> v;",
        "  final String colour;",
        "  final double opacity;",
        "  final double strokeWidth;",
        "  final bool closed;",
        "  const ArtPrim(this.kind, this.v, this.colour, this.opacity, this.strokeWidth, {this.closed = false});",
        "}",
        "",
        "const Map<String, ArtSpec> kCategoryArt = {",
    ]
    for cid, (base, sec, ter, tint) in COLORS.items():
        blobs = ", ".join(f"[{cx}, {cy}, {r}, {k}, {a}]" for cx, cy, r, k, a in BLOBS[cid])
        lines.append(f"  '{cid}': ArtSpec({dart_color(base)}, {dart_color(sec)}, {dart_color(ter)}, {dart_color(tint)}, {dart_color(mix(BG, base, 0.18))}, [{blobs}], [")
        for p in motif(cid):
            k = p[0]
            if k == "circle":
                _, x, y, r, c, a, sw = p
                vals, extra = [x, y, r], ""
            elif k == "line":
                _, x1, y1, x2, y2, c, a, sw = p
                vals, extra = [x1, y1, x2, y2], ""
            elif k == "poly":
                _, pts, closed, c, a, sw = p
                vals = [v for pt in pts for v in pt]
                extra = ", closed: true" if closed else ""
            elif k == "rrect":
                _, x, y, w, h, rx, rot, c, a, sw = p
                vals, extra = [x, y, w, h, rx, rot], ""
            elif k == "ellipse":
                _, x, y, rx, ry, rot, c, a, sw = p
                vals, extra = [x, y, rx, ry, rot], ""
            else:
                _, x, y, r, start, sweep, c, a, sw = p
                vals, extra = [x, y, r, start, sweep], ""
            vs = ", ".join(f1(float(v)) if "." in f1(float(v)) else f1(float(v)) + ".0" for v in vals)
            lines.append(f"    ArtPrim('{k}', [{vs}], '{c}', {a}, {float(sw)}{extra}),")
        lines.append("  ]),")
    lines.append("};")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    out = os.path.join(ROOT, "web", "art")
    os.makedirs(out, exist_ok=True)
    for cid in COLORS:
        with open(os.path.join(out, f"{cid}.svg"), "w") as fh:
            fh.write(svg_for(cid))
    with open(os.path.join(ROOT, "lib", "widgets", "v3", "category_art_data.dart"), "w") as fh:
        fh.write(dart())
    print("wrote", len(COLORS), "SVGs and category_art_data.dart")
