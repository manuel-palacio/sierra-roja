#!/usr/bin/env python3
"""Makes the building models the missions use, with Blender (on the PATH as `blender`).

    python3 tools/make_buildings.py            # every model the mission scenes ask for
    python3 tools/make_buildings.py --list     # only say which those are

A plaster building that is whole and not gone into is drawn from a model made by
tools/blender/farmhouse.py, one for each size, number of storeys and season the scenes use:
`assets/buildings/plaster-<length>x<height>x<depth>-r<roof>-s<storeys>[-snow].glb`, the measures
in decimetres (see Building.model_path in src/terrain/building.gd, which makes the same name).
Buildings with no model are still built in code.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/buildings"
# The smallest footprint worth a model: a sentry box stays a box.
MIN_LENGTH = 3.0
DEFAULTS = {"size": "Vector3(5, 3, 4)", "roof_height": "1.4", "storeys": "1", "style": '&"plaster"',
            "enterable": "false", "ruin": "false", "snowy": "false"}


def variants() -> set:
    found = set()
    for scene in sorted((ROOT / "scenes/missions").glob("*.tscn")):
        text = scene.read_text()
        script = re.search(r'\[ext_resource [^\]]*path="res://src/terrain/building.gd" id="([^"]+)"\]', text)
        if not script:
            continue
        for node in re.finditer(r'\[node [^\]]*\]\n((?:[a-z_]+ = .*\n)+)', text):
            props = dict(re.findall(r"^([a-z_]+) = (.*)$", node.group(1), re.M))
            if props.get("script") != f'ExtResource("{script.group(1)}")':
                continue
            props = {**DEFAULTS, **props}
            if props["enterable"] == "true" or props["ruin"] == "true" or props["style"] != '&"plaster"':
                continue
            length, height, depth = (float(v) for v in re.findall(r"[-\d.]+", props["size"].split("(", 1)[1]))
            roof = float(props["roof_height"])
            if length < MIN_LENGTH or roof <= 0.0:
                continue
            found.add((length, height, depth, roof, int(props["storeys"]), props["snowy"] == "true"))
    return found


def name(length, height, depth, roof, storeys, snowy) -> str:
    dm = lambda v: round(v * 10)
    return f"plaster-{dm(length)}x{dm(height)}x{dm(depth)}-r{dm(roof)}-s{storeys}{'-snow' if snowy else ''}.glb"


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for v in sorted(variants()):
        length, height, depth, roof, storeys, snowy = v
        target = OUT / name(*v)
        print(target.name)
        if "--list" in sys.argv:
            continue
        subprocess.run(["blender", "-b", "-P", str(ROOT / "tools/blender/farmhouse.py"), "--", str(target),
                        str(length), str(depth), str(height), str(roof), str(storeys), "1" if snowy else "0"],
                       check=True, stdout=subprocess.DEVNULL)
