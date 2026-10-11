#!/usr/bin/env python3
"""Build windows/OpenDictate.App/OpenDictate.ico from the design system.

16 and 32 px come pixel-exact from design/assets/logos/blink-16.svg and
blink-32.svg (design/assets/app-icon/README.md: below 32 px Blink is not
scaled down); 48 px and up come from app-icon-256.png. Needs Pillow.
"""

import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LOGOS = ROOT / "design" / "assets" / "logos"
OUT = ROOT / "windows" / "OpenDictate.App" / "OpenDictate.ico"
RECT = re.compile(r'<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)" fill="#([0-9A-Fa-f]{6})"')


def pixel_svg(path: Path, size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = RECT.findall(path.read_text(encoding="utf-8"))
    if not rects:
        raise ValueError(f"{path}: no pixel rectangles")
    for x, y, width, height, colour in rects:
        rgba = tuple(int(colour[i : i + 2], 16) for i in (0, 2, 4)) + (255,)
        for dx in range(int(width)):
            for dy in range(int(height)):
                image.putpixel((int(x) + dx, int(y) + dy), rgba)
    return image


def main() -> int:
    large = Image.open(ROOT / "design" / "assets" / "app-icon" / "app-icon-256.png").convert("RGBA")
    images = [pixel_svg(LOGOS / "blink-16.svg", 16), pixel_svg(LOGOS / "blink-32.svg", 32)]
    images += [large.resize((size, size), Image.LANCZOS) for size in (48, 64, 128)] + [large]
    images[-1].save(OUT, format="ICO", append_images=images[:-1], sizes=[(i.width, i.height) for i in images])
    return 0


if __name__ == "__main__":
    sys.exit(main())
