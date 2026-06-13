#!/usr/bin/env python3
from pathlib import Path
import struct
import zlib
import math

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "assets" / "AppIcon.iconset"

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


def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def write_png(path, width, height, pixels):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    data += chunk(b"IEND", b"")
    path.write_bytes(data)


def rounded_alpha(x, y, size, radius):
    px = min(x, size - 1 - x)
    py = min(y, size - 1 - y)
    if px >= radius or py >= radius:
        return 255
    dx = radius - px
    dy = radius - py
    dist = math.sqrt(dx * dx + dy * dy)
    if dist <= radius - 1:
        return 255
    if dist >= radius + 1:
        return 0
    return int(max(0, min(255, (radius + 1 - dist) * 127.5)))


def blend(dst, src):
    sr, sg, sb, sa = src
    dr, dg, db, da = dst
    a = sa / 255.0
    inv = 1 - a
    return (
        int(sr * a + dr * inv),
        int(sg * a + dg * inv),
        int(sb * a + db * inv),
        int(min(255, sa + da * inv)),
    )


def in_round_rect(x, y, rect, radius):
    x1, y1, x2, y2 = rect
    if x < x1 or x > x2 or y < y1 or y > y2:
        return False
    cx = min(max(x, x1 + radius), x2 - radius)
    cy = min(max(y, y1 + radius), y2 - radius)
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def in_polygon(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y):
            x_intersect = (xj - xi) * (y - yi) / ((yj - yi) or 1) + xi
            if x < x_intersect:
                inside = not inside
        j = i
    return inside


def draw_icon(size):
    pixels = []
    radius = int(size * 0.215)
    for y in range(size):
        for x in range(size):
            t = (x * 0.55 + y * 0.45) / max(1, size - 1)
            base = (int(18 + 18 * t), int(82 + 78 * t), int(78 + 98 * t), rounded_alpha(x, y, size, radius))
            pixels.append(base)

    def set_px(x, y, color):
        if 0 <= x < size and 0 <= y < size:
            pixels[y * size + x] = blend(pixels[y * size + x], color)

    def rect(rect, radius, color):
        x1, y1, x2, y2 = [int(v) for v in rect]
        for yy in range(max(0, y1), min(size, y2 + 1)):
            for xx in range(max(0, x1), min(size, x2 + 1)):
                if in_round_rect(xx, yy, (x1, y1, x2, y2), radius):
                    set_px(xx, yy, color)

    def line(x, y1, y2, width, color):
        half = max(1, width // 2)
        for xx in range(x - half, x + half + 1):
            for yy in range(y1, y2 + 1):
                set_px(xx, yy, color)

    s = size / 1024.0
    left, right = int(180 * s), int(820 * s)
    top, h, gap = int(280 * s), int(86 * s), int(74 * s)
    for i, color in enumerate([(110, 236, 203, 255), (106, 172, 245, 255), (255, 217, 116, 255)]):
        y = top + i * (h + gap)
        rect((left, y, right, y + h), int(28 * s), (11, 54, 50, 80))
        rect((left + int(36 * s), y + int(22 * s), right - int(36 * s), y + h - int(22 * s)), int(16 * s), (238, 255, 250, 210))
        clip_left = left + int((52 + i * 74) * s)
        clip_right = clip_left + int((250 + i * 42) * s)
        rect((clip_left, y + int(18 * s), clip_right, y + h - int(18 * s)), int(16 * s), color)

    x = int(620 * s)
    line(x, int(230 * s), int(700 * s), max(3, int(10 * s)), (255, 255, 255, 210))

    cx, cy = int(750 * s), int(235 * s)
    long, short = int(94 * s), int(42 * s)
    star = [
        (cx, cy - long), (cx + short, cy - short), (cx + long, cy), (cx + short, cy + short),
        (cx, cy + long), (cx - short, cy + short), (cx - long, cy), (cx - short, cy - short)
    ]
    for yy in range(cy - long, cy + long + 1):
        for xx in range(cx - long, cx + long + 1):
            if in_polygon(xx, yy, star):
                set_px(xx, yy, (255, 255, 255, 245))
            if (xx - cx) ** 2 + (yy - cy) ** 2 <= max(1, int(22 * s)) ** 2:
                set_px(xx, yy, (255, 244, 170, 255))

    return pixels


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES:
        write_png(ICONSET / name, size, size, draw_icon(size))


if __name__ == "__main__":
    main()

