#!/usr/bin/env python3
"""Give every font in a Flutter web build a content-hashed file name.

Why: Flutter tree-shakes MaterialIcons-Regular.otf to the icons the app uses, but keeps the
same file name every build. A phone that cached the old font (Hosting sent fonts with a long
max-age) then draws empty squares for icons added later (section headers, Listen) while older
icons (Save, Sources) still show. Pointing FontManifest.json at `<name>.td-<hash>.<ext>` copies
makes every build load exactly the font it was built with.

Usage: python3 tool/web/fingerprint_fonts.py [build/web]   (idempotent; originals are kept)
"""
import hashlib
import json
import os
import re
import shutil
import sys

HASHED = re.compile(r"\.td-[0-9a-f]{10}\.(otf|ttf|woff2?)$")


def main(root: str) -> int:
    manifest_path = os.path.join(root, "assets", "FontManifest.json")
    if not os.path.exists(manifest_path):
        print(f"no FontManifest.json under {root}", file=sys.stderr)
        return 1
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    changed = 0
    for family in manifest:
        for font in family.get("fonts", []):
            asset = font.get("asset", "")
            if not asset or HASHED.search(asset):
                continue
            src = os.path.join(root, "assets", asset)
            if not os.path.exists(src):
                print(f"missing font file: {src}", file=sys.stderr)
                continue
            with open(src, "rb") as fh:
                digest = hashlib.sha256(fh.read()).hexdigest()[:10]
            base, ext = os.path.splitext(asset)
            hashed = f"{base}.td-{digest}{ext}"
            shutil.copyfile(src, os.path.join(root, "assets", hashed))
            font["asset"] = hashed
            changed += 1
            print(f"{asset} -> {hashed}")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, separators=(",", ":"))
    print(f"fingerprinted {changed} font file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/web"))
