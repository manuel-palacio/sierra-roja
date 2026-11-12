#!/usr/bin/env python3
"""Makes the soldier model and its uniforms from Quaternius's Universal Animation Library (CC0).

    uv run --with pygltflib --with numpy --with pillow python3 tools/make_soldier.py <AnimationLibrary_Godot_Standard.glb>

The library's mannequin is a well-proportioned, fully animated human with no clothes or colours.
This script paints it by body part: every triangle is given one region (skin, hair, jacket,
trousers, boots, belt) from the bone that moves it and its height, and its texture coordinates
are pointed at that region's square in an 8 x 1 palette image. A uniform is then just a palette:
`uniform-guard.png`, `uniform-dynamiter.png`, `uniform-marksman.png`. Only the animations in KEEP
are kept.
Helmets, caps, rifles and bags are added in the game (src/units/soldier_gear.gd).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from pygltflib import GLTF2, Accessor, BufferView

OUT = Path(__file__).resolve().parent.parent / "assets/characters/soldier"
SKIN, HAIR, JACKET, TROUSERS, BOOTS, BELT = range(6)
REGIONS = 8  # squares in a palette
# Heights in metres on the 1.83 m mannequin.
# Hair covers the crown, and the back of the head down to the nape; the face is left clear.
CROWN = 1.765
NAPE = 1.64
BELT_BAND = (1.03, 1.10)
BOOT_TOP = 0.30
WAIST = 1.06

PALETTES = {
    # skin, hair, jacket, trousers, boots, belt
    "guard": ["#d9a987", "#3a2c20", "#a3966b", "#93875f", "#2a1f19", "#5a3a20"],
    "dynamiter": ["#c89673", "#1c1a1c", "#3a5c96", "#335288", "#3a2c22", "#4a301c"],
    "marksman": ["#d4a482", "#4a3423", "#6e4c30", "#5f6450", "#2a1f19", "#3a2616"],
}

# The clips the game uses or is likely to use next; the rest are left out of the model.
KEEP = ["Idle", "Walk", "Jog_Fwd", "Sprint", "Death01", "Swim_Fwd", "Crouch_Idle", "Crouch_Fwd", "Pistol_Idle",
        "Pistol_Shoot", "Sword_Attack", "PickUp_Table", "Hit_Chest"]

COMPONENT = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def region_of(bone: str, y: float, z: float) -> int:
    if "head" in bone:
        return HAIR if y > CROWN or (y > NAPE and z < -0.015) else SKIN
    if "neck" in bone or "hand" in bone or "f_" in bone or "thumb" in bone:
        return SKIN
    if "foot" in bone or "toe" in bone:
        return BOOTS
    if "shin" in bone:
        return BOOTS if y < BOOT_TOP else TROUSERS
    if "thigh" in bone:
        return TROUSERS
    if "hips" in bone or "spine.001" in bone:
        if BELT_BAND[0] <= y <= BELT_BAND[1]:
            return BELT
        return JACKET if y > WAIST else TROUSERS
    return JACKET  # the rest of the spine, shoulders and arms


def main(source: str) -> None:
    gltf = GLTF2().load(source)
    blob = bytearray(gltf.binary_blob())

    def read(index: int) -> np.ndarray:
        accessor = gltf.accessors[index]
        view = gltf.bufferViews[accessor.bufferView]
        dtype = np.dtype(COMPONENT[accessor.componentType])
        width = WIDTH[accessor.type]
        assert not view.byteStride or view.byteStride == dtype.itemsize * width
        offset = (view.byteOffset or 0) + (accessor.byteOffset or 0)
        return np.frombuffer(bytes(blob), dtype=dtype, count=accessor.count * width, offset=offset).reshape(
            accessor.count, width)

    def append(data: np.ndarray, kind: str, component: int, target, bounds: bool = False) -> int:
        while len(blob) % 4:
            blob.append(0)
        raw = np.ascontiguousarray(data).tobytes()
        gltf.bufferViews.append(BufferView(buffer=0, byteOffset=len(blob), byteLength=len(raw), target=target))
        blob.extend(raw)
        accessor = Accessor(bufferView=len(gltf.bufferViews) - 1, componentType=component, count=len(data), type=kind)
        if bounds:
            accessor.min = data.min(axis=0).tolist()
            accessor.max = data.max(axis=0).tolist()
        gltf.accessors.append(accessor)
        return len(gltf.accessors) - 1

    bones = [gltf.nodes[j].name for j in gltf.skins[0].joints]
    for primitive in gltf.meshes[0].primitives:
        position = read(primitive.attributes.POSITION)
        normal = read(primitive.attributes.NORMAL)
        joints = read(primitive.attributes.JOINTS_0)
        weights = read(primitive.attributes.WEIGHTS_0)
        triangles = read(primitive.indices).reshape(-1, 3)
        lead = joints[np.arange(len(joints)), weights.argmax(axis=1)]
        of_vertex = np.array([region_of(bones[lead[i]], position[i, 1], position[i, 2]) for i in range(len(position))])
        # One region per triangle (the commonest among its corners), and a copy of each vertex for
        # every region that uses it, so no triangle's texture coordinates run across the palette.
        remap, order, faces = {}, [], []
        for tri in triangles:
            corners = of_vertex[tri]
            region = int(np.bincount(corners).argmax())
            face = []
            for v in tri:
                key = (int(v), region)
                if key not in remap:
                    remap[key] = len(order)
                    order.append(key)
                face.append(remap[key])
            faces.append(face)
        source_index = np.array([k[0] for k in order])
        regions = np.array([k[1] for k in order])
        uv = np.stack([(regions + 0.5) / REGIONS, np.full(len(order), 0.5)], axis=1).astype(np.float32)
        primitive.attributes.POSITION = append(position[source_index], "VEC3", 5126, 34962, bounds=True)
        primitive.attributes.NORMAL = append(normal[source_index], "VEC3", 5126, 34962)
        primitive.attributes.TEXCOORD_0 = append(uv, "VEC2", 5126, 34962)
        primitive.attributes.TEXCOORD_1 = None
        primitive.attributes.JOINTS_0 = append(joints[source_index].astype(np.uint8), "VEC4", 5121, 34962)
        primitive.attributes.WEIGHTS_0 = append(weights[source_index].astype(np.float32), "VEC4", 5126, 34962)
        primitive.indices = append(np.array(faces, dtype=np.uint16).reshape(-1), "SCALAR", 5123, 34963)
    # Looping clips are named with a _Loop ending in the file, which Godot reads and drops.
    gltf.animations = [a for a in gltf.animations if a.name.removesuffix("_Loop") in KEEP]
    assert len(gltf.animations) == len(KEEP), [a.name for a in gltf.animations]
    for material in gltf.materials:
        material.pbrMetallicRoughness.baseColorFactor = [1.0, 1.0, 1.0, 1.0]
        material.pbrMetallicRoughness.metallicFactor = 0.0
        material.pbrMetallicRoughness.roughnessFactor = 1.0
    gltf.buffers[0].byteLength = len(blob)
    gltf.set_binary_blob(bytes(blob))
    OUT.mkdir(parents=True, exist_ok=True)
    gltf.save(str(OUT / "soldier.glb"))
    print("wrote soldier.glb", round(len(blob) / 1e6, 1), "MB")

    for name, colours in PALETTES.items():
        image = Image.new("RGB", (REGIONS * 4, 4), "#ff00ff")
        for i, colour in enumerate(colours):
            image.paste(Image.new("RGB", (4, 4), colour), (i * 4, 0))
        image.save(OUT / f"uniform-{name}.png")
        print("wrote", f"uniform-{name}.png")


if __name__ == "__main__":
    main(sys.argv[1])
