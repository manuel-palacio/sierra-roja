#!/usr/bin/env python3
"""Paints the leaf sprites the generated trees are covered in.

    uv run --with pillow python3 tools/make_foliage.py

Each sprite is a square of see-through background with a spray of leaves on it: broad leaves for
oaks, olives and bushes, needles on twigs for pines. src/terrain/tree_builder.gd hangs dozens of
these on each tree. Seeded, so a rerun gives the same pictures.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets/textures"
SIZE = 256


def shade(colour, by):
    return tuple(max(0, min(255, round(c * by))) for c in colour)


def broad(seed, base):
    rng = random.Random(seed)
    image = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    for _ in range(120):
        # Leaves crowd toward the middle and thin out at the rim.
        r = (rng.random() ** 0.75) * SIZE * 0.86
        a = rng.uniform(0, math.tau)
        x, y = SIZE + r * math.cos(a), SIZE + r * math.sin(a)
        length, width = rng.uniform(46, 70), rng.uniform(22, 34)
        leaf = Image.new("RGBA", (int(length) + 8, int(width) + 8), (0, 0, 0, 0))
        draw = ImageDraw.Draw(leaf)
        tone = shade(base, rng.uniform(0.62, 1.22))
        draw.ellipse((4, 4, 4 + length, 4 + width), fill=tone + (255,), outline=shade(tone, 0.6) + (255,), width=2)
        draw.line((6, 4 + width / 2, 2 + length, 4 + width / 2), fill=shade(tone, 1.25) + (255,), width=2)
        leaf = leaf.rotate(rng.uniform(0, 360), expand=True, resample=Image.BICUBIC)
        image.alpha_composite(leaf, (int(x - leaf.width / 2), int(y - leaf.height / 2)))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def needles(seed, base):
    rng = random.Random(seed)
    image = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # A bough: twigs fanning down and out from the top middle, each bristling with needles.
    for _ in range(11):
        a = rng.uniform(math.radians(35), math.radians(145))
        length = rng.uniform(SIZE * 1.0, SIZE * 1.75)
        x0, y0 = SIZE + rng.uniform(-30, 30), 24
        x1, y1 = x0 + length * math.cos(a), y0 + length * math.sin(a)
        draw.line((x0, y0, x1, y1), fill=(70, 50, 34, 255), width=5)
        steps = int(length / 9)
        for i in range(steps):
            t = i / steps
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for side in (-1, 1):
                b = a + side * rng.uniform(0.5, 1.1)
                n = rng.uniform(26, 44) * (1.0 - 0.4 * t)
                tone = shade(base, rng.uniform(0.6, 1.25))
                draw.line((px, py, px + n * math.cos(b), py + n * math.sin(b)), fill=tone + (255,), width=4)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    broad(1, (86, 128, 52)).save(OUT / "leaves_broad.png")
    needles(2, (48, 96, 52)).save(OUT / "leaves_pine.png")
    print("wrote leaves_broad.png and leaves_pine.png")
