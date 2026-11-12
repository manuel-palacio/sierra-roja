#!/usr/bin/env python3
"""Makes the HUD's pictures: the two portraits and the ability icons.

    mkdir -p /tmp/portraits && godot --path . -s tools/portrait_render.gd -- /tmp/portraits
    uv run --with pillow python3 tools/make_ui_art.py /tmp/portraits

The portraits are the game's own soldier models, rendered close up and then softened and reduced
to a few tones so they read as painted miniatures rather than screenshots. The icons are drawn
here as plain cream silhouettes: a knife, a bundle of dynamite, a pistol, a rifle, and a man
carrying another.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

OUT = Path(__file__).resolve().parent.parent / "assets/ui"
CREAM = (236, 222, 190, 255)
INK = (34, 28, 20, 255)
ICON = 96


def portrait(source: Path, name: str) -> None:
    image = Image.open(source).convert("RGB")
    side = min(image.size)
    image = image.crop(((image.width - side) // 2, 0, (image.width + side) // 2, side)).resize((192, 192), Image.LANCZOS)
    image = image.filter(ImageFilter.MedianFilter(3))
    image = ImageEnhance.Contrast(image).enhance(1.15)
    image = ImageOps.posterize(image, 5)
    # A darkening toward the corners, as on a small oil portrait.
    shade = Image.new("L", image.size, 0)
    ImageDraw.Draw(shade).ellipse((-40, -50, 232, 250), fill=255)
    shade = shade.filter(ImageFilter.GaussianBlur(26))
    image = Image.composite(image, Image.new("RGB", image.size, (22, 20, 14)), shade)
    image.save(OUT / f"portrait-{name}.png")
    print("wrote", f"portrait-{name}.png")


def icon(name: str, draw_it) -> None:
    big = Image.new("RGBA", (ICON * 4, ICON * 4), (0, 0, 0, 0))
    draw_it(ImageDraw.Draw(big), ICON * 4)
    image = big.resize((ICON, ICON), Image.LANCZOS)
    image.save(OUT / f"icon-{name}.png")
    print("wrote", f"icon-{name}.png")


def shape(d, points, s, width=10):
    scaled = [(x * s, y * s) for x, y in points]
    d.polygon(scaled, fill=CREAM, outline=INK)
    d.line(scaled + [scaled[0]], fill=INK, width=width, joint="curve")


def knife(d, s):
    shape(d, [(0.14, 0.80), (0.22, 0.88), (0.44, 0.66), (0.36, 0.58)], s)  # grip
    shape(d, [(0.33, 0.50), (0.50, 0.67), (0.56, 0.61), (0.39, 0.44)], s)  # guard
    shape(d, [(0.44, 0.50), (0.52, 0.58), (0.86, 0.22), (0.88, 0.12), (0.78, 0.14)], s)  # blade


def charge(d, s):
    for i in range(3):  # three sticks, bound
        x = 0.24 + i * 0.18
        shape(d, [(x, 0.36), (x + 0.16, 0.36), (x + 0.16, 0.86), (x, 0.86)], s)
    shape(d, [(0.20, 0.52), (0.82, 0.52), (0.82, 0.62), (0.20, 0.62)], s)
    d.line([(0.50 * s, 0.36 * s), (0.52 * s, 0.22 * s), (0.64 * s, 0.14 * s), (0.74 * s, 0.18 * s)], fill=INK, width=26, joint="curve")
    d.line([(0.50 * s, 0.36 * s), (0.52 * s, 0.22 * s), (0.64 * s, 0.14 * s), (0.74 * s, 0.18 * s)], fill=CREAM, width=12, joint="curve")
    for dx, dy in ((0.07, -0.05), (0.09, 0.02), (0.03, -0.09)):  # the spark
        d.line([(0.74 * s, 0.18 * s), ((0.74 + dx) * s, (0.18 + dy) * s)], fill=CREAM, width=10)


def pistol(d, s):
    shape(d, [(0.14, 0.34), (0.86, 0.34), (0.86, 0.48), (0.50, 0.48), (0.46, 0.56), (0.40, 0.56),
              (0.34, 0.84), (0.18, 0.84), (0.24, 0.50), (0.14, 0.50)], s)
    d.arc((0.38 * s, 0.44 * s, 0.56 * s, 0.66 * s), 0, 180, fill=INK, width=10)


def rifle(d, s):
    shape(d, [(0.06, 0.70), (0.10, 0.82), (0.34, 0.66), (0.46, 0.62), (0.94, 0.30), (0.92, 0.25),
              (0.44, 0.52), (0.30, 0.54)], s)
    shape(d, [(0.52, 0.52), (0.56, 0.60), (0.62, 0.56), (0.58, 0.49)], s)
    d.line([(0.60 * s, 0.44 * s), (0.94 * s, 0.24 * s)], fill=INK, width=10)


def carry(d, s):
    d.ellipse((0.34 * s, 0.26 * s, 0.50 * s, 0.42 * s), fill=CREAM, outline=INK, width=10)  # the carrier's head
    shape(d, [(0.34, 0.44), (0.52, 0.44), (0.56, 0.68), (0.50, 0.92), (0.40, 0.92), (0.42, 0.70), (0.34, 0.92),
              (0.24, 0.92), (0.32, 0.66)], s)
    shape(d, [(0.16, 0.30), (0.26, 0.24), (0.84, 0.30), (0.88, 0.40), (0.60, 0.44), (0.20, 0.42)], s)  # the one carried
    d.ellipse((0.80 * s, 0.26 * s, 0.94 * s, 0.40 * s), fill=CREAM, outline=INK, width=10)


if __name__ == "__main__":
    renders = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if renders:
        for who in ("dynamiter", "marksman"):
            portrait(renders / f"{who}.png", who)
    for name, draw_it in (("knife", knife), ("charge", charge), ("pistol", pistol), ("rifle", rifle), ("carry", carry)):
        icon(name, draw_it)
