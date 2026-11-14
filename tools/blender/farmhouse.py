"""Builds a Spanish farmhouse as one mesh with colour on its vertices and its shade baked to a texture.

    blender -b -P tools/blender/farmhouse.py -- out.glb [length depth wall_height roof_rise storeys snowy]

tools/make_buildings.py runs it for every size the missions use. Blender coordinates: x along the
ridge, y across it, z up, the door on the -y side (which is +z, the south, in the game). Metres.
The plinth goes 0.6 m below the ground, for standing on a slope.
"""
import math, random, sys
import bpy, bmesh
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
numbers = [float(a) for a in args[1:5]] + [8.0, 5.5, 3.0, 1.7][len(args[1:5]):]
L, D, H, RISE = numbers                              # length, depth, wall height, roof rise
STOREYS = int(args[5]) if len(args) > 5 else 1
SNOWY = len(args) > 6 and args[6] == "1"
EAVE = 0.45
FLOOR = H / STOREYS
random.seed(int(L * 10 + D * 100 + H * 1000))

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
col = bm.loops.layers.color.new("Base")

def shade(c, by):
    return tuple(max(0.0, min(1.0, v * by)) for v in c)

done = bm.faces.layers.int.new("done")

def paint(c, vary=0.0):
    """Colours every face made since the last call."""
    for f in bm.faces:
        if f[done] == 0:
            f[done] = 1
            k = shade(c, 1.0 + random.uniform(-vary, vary))
            for loop in f.loops:
                loop[col] = (*k, 1.0)

def box(centre, size, c, vary=0.0, cuts=0, rot=None):
    made = bmesh.ops.create_cube(bm, size=1.0)
    verts = made["verts"]
    bmesh.ops.scale(bm, vec=Vector(size), verts=verts)
    if rot is not None:
        bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=rot, verts=verts)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=verts)
    if cuts:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)
    paint(c, vary)

PLASTER = (0.87, 0.84, 0.76)
STONE = (0.62, 0.57, 0.50)
TILE = (0.90, 0.92, 0.96) if SNOWY else (0.66, 0.33, 0.22)
TILE_VARY = 0.03 if SNOWY else 0.2
WOOD = (0.33, 0.23, 0.15)
SHUTTER = (0.24, 0.36, 0.27)
GLASS = (0.07, 0.09, 0.12)

# Walls, tessellated so that the baked shade has vertices to live on, over a stone plinth.
box((0, 0, H / 2 + 0.25), (L, D, H - 0.5), PLASTER, 0.035, cuts=9)
box((0, 0, -0.05), (L + 0.16, D + 0.16, 1.1), STONE, 0.12, cuts=5)
# Gable ends: a triangle of wall above each short side.
for sx in (-1, 1):
    x = sx * L / 2
    v = [bm.verts.new((x, -D / 2, H)), bm.verts.new((x, D / 2, H)), bm.verts.new((x, 0, H + RISE))]
    f = bm.faces.new(v if sx > 0 else v[::-1])
    bmesh.ops.subdivide_edges(bm, edges=list(f.edges), cuts=5, use_grid_fill=True)
    paint(PLASTER, 0.035)
# Quoins: dressed stones up each corner, alternately long and short.
for sx in (-1, 1):
    for sy in (-1, 1):
        for i in range(int((H - 0.5) / 0.42)):
            long_x = i % 2 == 0
            w, d = (0.62, 0.34) if long_x else (0.34, 0.62)
            box((sx * (L / 2 - w / 2 + 0.05), sy * (D / 2 - d / 2 + 0.05), 0.62 + i * 0.42), (w, d, 0.38), STONE, 0.14)

# Door and windows on the front (-y) and one window on each gable.
def window(x, y, z, facing, w=0.9, h=1.15):
    """facing: unit vector the window looks out along."""
    side = Vector((-facing.y, facing.x, 0))
    at = Vector((x, y, z))
    rot = Matrix.Rotation(math.atan2(facing.y, facing.x) - math.pi / 2 + math.pi, 4, 'Z')
    box(at - facing * 0.02, (w, 0.06, h), GLASS, rot=rot)
    for dz, hh in ((h / 2 + 0.06, 0.12), (-h / 2 - 0.05, 0.10)):                 # lintel and sill
        box(at + facing * 0.05 + Vector((0, 0, dz)), (w + 0.3, 0.2, hh), STONE if dz < 0 else WOOD, 0.1, rot=rot)
    box(at + facing * 0.03, (0.05, 0.08, h), WOOD, rot=rot)                       # mullion
    box(at + facing * 0.03, (w, 0.08, 0.05), WOOD, rot=rot)
    for s, ajar in ((-1, 0.35), (1, 0.12)):                                        # shutters, one swung wider
        hinge = at + side * s * (w / 2 + 0.02) + facing * 0.07
        swing = Matrix.Rotation(-s * ajar, 4, 'Z') @ rot
        centre = hinge + (Matrix.Rotation(-s * ajar, 3, 'Z') @ (side * s * (w / 4)))
        box(centre, (w / 2, 0.05, h), SHUTTER, 0.08, rot=swing)
        for k in (-0.3, 0.0, 0.3):
            box(centre + facing * 0.03 + Vector((0, 0, k * h)), (w / 2 - 0.06, 0.03, 0.05), shade(SHUTTER, 0.8), rot=swing)

front = Vector((0, -1, 0))
door_x = 0.0 if L >= 5.5 else -L * 0.18
for storey in range(STOREYS):
    z = storey * FLOOR + min(1.85, FLOOR - 1.1)
    if L >= 5.5:
        for x in (-L * 0.33, L * 0.33):
            window(x, -D / 2, z, front)
    else:
        window(L * 0.24, -D / 2, z, front, w=0.8)
    if storey > 0:
        # Over the door: a door onto a wooden balcony.
        box((door_x, -D / 2 - 0.02, storey * FLOOR + 1.05), (0.95, 0.06, 1.9), GLASS)
        box((door_x, -D / 2 - 0.05, storey * FLOOR + 1.05), (0.06, 0.06, 1.9), WOOD)
        box((door_x, -D / 2 - 0.5, storey * FLOOR + 0.05), (2.2, 1.0, 0.1), WOOD, 0.1)
        for k in range(3):
            box((door_x - 0.9 + k * 0.9, -D / 2 - 0.5, storey * FLOOR - 0.08), (0.12, 1.0, 0.16), WOOD, 0.1)
        for k in range(8):
            box((door_x - 1.05 + k * 0.3, -D / 2 - 0.96, storey * FLOOR + 0.5), (0.05, 0.05, 0.9), WOOD, 0.12)
        for sx in (-1, 1):
            for k in range(3):
                box((door_x + sx * 1.07, -D / 2 - 0.2 - k * 0.3, storey * FLOOR + 0.5), (0.05, 0.05, 0.9), WOOD, 0.12)
            box((door_x + sx * 1.07, -D / 2 - 0.5, storey * FLOOR + 0.97), (0.07, 1.0, 0.07), WOOD)
        box((door_x, -D / 2 - 0.96, storey * FLOOR + 0.97), (2.2, 0.07, 0.07), WOOD)
    if D >= 3.0:
        window(L / 2, 0.0, z + 0.05, Vector((1, 0, 0)), w=0.8)
        window(-L / 2, D * 0.14, z + 0.05, Vector((-1, 0, 0)), w=0.8)
    if storey > 0 or L < 5.5:
        window(L * 0.2, D / 2, z + 0.05, Vector((0, 1, 0)), w=0.8)
# The door: planks in a stone surround, a step, a handle.
door_h = min(2.1, FLOOR - 0.5)
box((door_x, -D / 2 - 0.03, door_h / 2 + 0.05), (1.25, 0.08, door_h), WOOD, 0.0)
for i in range(5):
    box((door_x - 0.5 + i * 0.25, -D / 2 - 0.08, door_h / 2 + 0.05), (0.22, 0.04, door_h - 0.04), WOOD, 0.16)
box((door_x, -D / 2 - 0.08, door_h + 0.18), (1.75, 0.24, 0.26), STONE, 0.1)
for s in (-1, 1):
    box((door_x + s * 0.76, -D / 2 - 0.07, door_h / 2 + 0.05), (0.24, 0.2, door_h + 0.1), STONE, 0.12)
box((door_x, -D / 2 - 0.35, 0.09), (1.9, 0.6, 0.18), STONE, 0.1)
box((door_x + 0.42, -D / 2 - 0.12, door_h / 2), (0.05, 0.04, 0.3), (0.12, 0.12, 0.12))
if L >= 5.5:
    # A bench by the door and a water trough: things a yard has.
    bench_x = door_x - 1.9
    box((bench_x, -D / 2 - 0.3, 0.42), (1.4, 0.36, 0.07), WOOD, 0.1)
    for s in (-1, 1):
        box((bench_x + s * 0.55, -D / 2 - 0.3, 0.2), (0.08, 0.3, 0.4), WOOD, 0.1)
    box((L * 0.4, -D / 2 - 0.45, 0.3), (1.5, 0.6, 0.6), STONE, 0.1)
    box((L * 0.4, -D / 2 - 0.45, 0.58), (1.26, 0.38, 0.06), (0.16, 0.22, 0.24))
# Against the back wall: a plank lean-to under a sloping roof, and a pile of logs beside it.
lean_w, lean_h, lean_d = L * 0.45, min(H, 3.0) * 0.6, 1.5
lean_x = -L * 0.2
box((lean_x, D / 2 + lean_d / 2, lean_h / 2 - 0.3), (lean_w, lean_d, lean_h + 0.6), shade(WOOD, 1.25), 0.1, cuts=2)
for i in range(int(lean_w / 0.3)):
    box((lean_x - lean_w / 2 + 0.15 + i * 0.3, D / 2 + lean_d + 0.02, lean_h / 2), (0.04, 0.04, lean_h), shade(WOOD, 0.8))
box((lean_x, D / 2 + lean_d / 2 + 0.08, lean_h + 0.12), (lean_w + 0.3, lean_d + 0.45, 0.09), TILE, 0.12,
    rot=Matrix.Rotation(-0.22, 4, 'X'))
for row in range(3):
    for i in range(5 - row):
        made = bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=0.13, radius2=0.13, depth=0.9)
        bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 2, 4, 'X'), verts=made["verts"])
        bmesh.ops.translate(bm, vec=Vector((L * 0.2 + (i + row * 0.5) * 0.27, D / 2 + 0.5, 0.13 + row * 0.23)), verts=made["verts"])
        paint((0.50, 0.40, 0.28), 0.18)

# The roof: a board each side, then rows of barrel tiles from ridge to eaves, and ridge caps.
slope = math.atan2(RISE, D / 2)
run = math.hypot(D / 2 + EAVE, (D / 2 + EAVE) * math.tan(slope))
for sy in (-1, 1):
    tilt = Matrix.Rotation(sy * slope, 4, 'X')
    mid = Vector((0, sy * (D / 2 + EAVE) / 2, H + RISE - (D / 2 + EAVE) * math.tan(slope) / 2 + 0.02))
    box(mid, (L + 2 * EAVE, run, 0.08), shade(WOOD, 1.1), rot=Matrix.Rotation(-sy * slope, 4, 'X'))
    n = int((L + 2 * EAVE) / 0.19)
    for i in range(n):
        x = -(L + 2 * EAVE) / 2 + (i + 0.5) * (L + 2 * EAVE) / n
        made = bmesh.ops.create_cone(bm, cap_ends=False, segments=8, radius1=0.11, radius2=0.095, depth=run + 0.1)
        verts = made["verts"]
        # Keep the upper half of the tube: a barrel tile, laid along the slope.
        for f in list({f for v in verts for f in v.link_faces}):
            if f.calc_center_median().y < -0.02:
                bm.faces.remove(f)
        verts = [v for v in verts if v.is_valid and v.link_faces]
        bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 2, 4, 'X'), verts=verts)   # axis along y, open side down
        bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(-sy * slope, 4, 'X'), verts=verts)
        bmesh.ops.translate(bm, vec=mid + Vector((x, 0, 0.07)), verts=verts)
        paint(TILE, TILE_VARY)
n = int((L + 2 * EAVE) / 0.5)
for i in range(n):
    x = -(L + 2 * EAVE) / 2 + (i + 0.5) * (L + 2 * EAVE) / n
    box((x, 0, H + RISE + 0.1), (0.52, 0.34, 0.16), TILE, TILE_VARY)
# Rafter ends under the eaves, front and back.
for sy in (-1, 1):
    for i in range(9):
        x = -L / 2 + 0.3 + i * (L - 0.6) / 8
        box((x, sy * (D / 2 + EAVE * 0.55), H - 0.06), (0.12, EAVE * 1.1, 0.14), WOOD, 0.1)
# Chimney: plastered stack, stone cap on four posts.
cx, cy = L * 0.3, D * 0.16
top = H + RISE + 0.75
box((cx, cy, (H + top) / 2 + 0.3), (0.7, 0.7, top - H - 0.6), PLASTER, 0.05, cuts=2)
for sx in (-1, 1):
    for sy in (-1, 1):
        box((cx + sx * 0.26, cy + sy * 0.26, top + 0.1), (0.1, 0.1, 0.22), STONE)
box((cx, cy, top + 0.26), (0.92, 0.92, 0.1), TILE, 0.1)

bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
mesh = bpy.data.meshes.new("Farmhouse")
bm.to_mesh(mesh)
bm.free()
house = bpy.data.objects.new("Farmhouse", mesh)
bpy.context.scene.collection.objects.link(house)
# The ground it stands on, for the bake only: walls are darker where they meet it.
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
ground = bpy.context.active_object

# Bake ambient occlusion into a texture over an automatic unwrap. The colours stay on the
# vertices; the game multiplies the two.
bpy.context.view_layer.objects.active = house
house.select_set(True)
ground.select_set(False)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.object.mode_set(mode='OBJECT')
image = bpy.data.images.new("farmhouse-shade", 512, 512, alpha=False)
material = bpy.data.materials.new("Farmhouse")
material.use_nodes = True
mesh.materials.append(material)
nodes, links = material.node_tree.nodes, material.node_tree.links
texture = nodes.new("ShaderNodeTexImage")
texture.image = image
nodes.active = texture
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 64
scene.render.bake.target = 'IMAGE_TEXTURES'
scene.render.bake.margin = 4
bpy.ops.object.bake(type='AO')
import numpy as np
pixels = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
pixels[:, :3] = 0.25 + 0.75 * pixels[:, :3] ** 1.4
image.pixels = pixels.ravel().tolist()
import os, tempfile
image.filepath_raw = os.path.join(tempfile.mkdtemp(), "shade.png")   # the model file carries its own copy
image.file_format = 'PNG'
image.save()
bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
base = mesh.color_attributes["Base"]
# The game shows these numbers as they are written, so write the ones meant.
for item in base.data:
    item.color = item.color_srgb
mesh.color_attributes.active_color = base
mesh.color_attributes.render_color_index = 0
bpy.data.objects.remove(ground)
bpy.ops.object.select_all(action='DESELECT')
house.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_format='GLB', export_yup=True, export_apply=True, export_vertex_color='ACTIVE', export_all_vertex_colors=False)
print("faces", len(mesh.polygons), "wrote", out)
