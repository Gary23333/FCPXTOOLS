#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "AppIconSource.png"
ICONSET = ROOT / "assets" / "AppIcon.iconset"
ICNS = ROOT / "assets" / "AppIcon.icns"

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def run(command):
    subprocess.run(command, check=True)


def main():
    if not SOURCE.exists():
        raise SystemExit(f"Missing icon source: {SOURCE}")

    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES:
        run(["sips", "-z", str(size), str(size), str(SOURCE), "--out", str(ICONSET / name)])

    run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)])
    print(ICNS)


if __name__ == "__main__":
    main()
