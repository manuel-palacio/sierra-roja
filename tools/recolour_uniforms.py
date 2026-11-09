#!/usr/bin/env python3
"""Makes the three uniform textures from Kenney's Blocky Characters textures (CC0).

    uv run --with pillow python3 tools/recolour_uniforms.py

Guards: the navy police uniform becomes pale khaki. Dynamiter: the red shirt becomes the blue of
the militia's overalls. Marksman: the blue shirt becomes a brown jacket. The aim is that the three
read apart at a glance on a dark hillside.
"""
import colorsys
from pathlib import Path

from PIL import Image

TEXTURES = Path(__file__).resolve().parent.parent / "assets/characters/Textures"


def recolour(source, target, rules):
    """rules: (hue_from, hue_to, min_saturation, new_hue, saturation_scale, value_scale), hues in degrees."""
    image = Image.open(TEXTURES / source).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            for lo, hi, min_s, new_h, s_scale, v_scale in rules:
                inside = lo <= h * 360 <= hi if lo <= hi else (h * 360 >= lo or h * 360 <= hi)
                if inside and s >= min_s:
                    nr, ng, nb = colorsys.hsv_to_rgb(new_h / 360, min(s * s_scale, 1), min(v * v_scale, 1))
                    pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
                    break
    image.save(TEXTURES / target)
    print("wrote", target)


if __name__ == "__main__":
    recolour("texture-j.png", "uniform-guard.png", [(200, 260, 0.25, 46, 0.55, 1.75)])
    recolour("texture-b.png", "uniform-dynamiter.png", [(340, 12, 0.45, 216, 0.85, 0.72)])
    recolour("texture-p.png", "uniform-marksman.png", [(225, 262, 0.30, 30, 0.75, 0.55)])
