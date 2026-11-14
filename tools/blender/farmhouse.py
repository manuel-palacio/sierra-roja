"""Builds a Spanish farmhouse as one mesh with per-vertex colour and baked ambient occlusion.

    blender -b -P farmhouse.py -- out.glb
Blender coordinates: x along the ridge, y across it, z up. Metres.
"""
import math, random, sys
import bpy, bmesh
from mathutils import Vector, Matrix

out = sys.argv[sys.argv.index("--") + 1]
random.seed(7)
L, D, H, RISE, EAVE = 8.0, 5.5, 3.0, 1.7, 0.45   # length, depth, wall height, roof rise, overhang

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
TILE = (0.66, 0.33, 0.22)
WOOD = (0.33, 0.23, 0.15)
SHUTTER = (0.24, 0.36, 0.27)
GLASS = (0.07, 0.09, 0.12)

# Walls, tessellated so that the baked shade has vertices to live on, over a stone plinth.
box((0, 0, H / 2 + 0.25), (L, D, H - 0.5), PLASTER, 0.035, cuts=9)
box((0, 0, 0.25), (L + 0.16, D + 0.16, 0.5), STONE, 0.12, cuts=5)
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
        for i in range(6):
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
for x in (-2.7, 2.7):
    window(x, -D / 2, 1.85, front)
window(-0.2, D / 2, 1.9, Vector((0, 1, 0)), w=0.8)
window(L / 2, 0.0, 1.9, Vector((1, 0, 0)), w=0.8)
window(-L / 2, 0.8, 1.9, Vector((-1, 0, 0)), w=0.8)
# The door: planks in a stone surround, a step, a lamp bracket.
box((0.2, -D / 2 - 0.03, 1.1), (1.25, 0.08, 2.1), WOOD, 0.0)
for i in range(5):
    box((0.2 - 0.5 + i * 0.25, -D / 2 - 0.08, 1.1), (0.22, 0.04, 2.06), WOOD, 0.16)
box((0.2, -D / 2 - 0.08, 2.28), (1.75, 0.24, 0.26), STONE, 0.1)
for s in (-1, 1):
    box((0.2 + s * 0.76, -D / 2 - 0.07, 1.1), (0.24, 0.2, 2.2), STONE, 0.12)
box((0.2, -D / 2 - 0.35, 0.09), (1.9, 0.6, 0.18), STONE, 0.1)
box((0.2, -D / 2 - 0.12, 1.1), (0.05, 0.04, 0.3), (0.12, 0.12, 0.12))
# A bench by the door and a water trough: things a yard has.
box((-1.6, -D / 2 - 0.3, 0.42), (1.4, 0.36, 0.07), WOOD, 0.1)
for s in (-1, 1):
    box((-1.6 + s * 0.55, -D / 2 - 0.3, 0.2), (0.08, 0.3, 0.4), WOOD, 0.1)
box((3.2, -D / 2 - 0.45, 0.3), (1.5, 0.6, 0.6), STONE, 0.1)
box((3.2, -D / 2 - 0.45, 0.58), (1.26, 0.38, 0.06), (0.16, 0.22, 0.24))

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
        paint(TILE, 0.2)
n = int((L + 2 * EAVE) / 0.5)
for i in range(n):
    x = -(L + 2 * EAVE) / 2 + (i + 0.5) * (L + 2 * EAVE) / n
    box((x, 0, H + RISE + 0.1), (0.52, 0.34, 0.16), TILE, 0.18)
# Rafter ends under the eaves, front and back.
for sy in (-1, 1):
    for i in range(9):
        x = -L / 2 + 0.3 + i * (L - 0.6) / 8
        box((x, sy * (D / 2 + EAVE * 0.55), H - 0.06), (0.12, EAVE * 1.1, 0.14), WOOD, 0.1)
# Chimney: plastered stack, stone cap on four posts.
cx, cy = 2.4, 0.9
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
image = bpy.data.images.new("farmhouse-shade", 1024, 1024, alpha=False)
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
scene.render.bake.margin = 6
bpy.ops.object.bake(type='AO')
import numpy as np
pixels = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
pixels[:, :3] = 0.25 + 0.75 * pixels[:, :3] ** 1.4
image.pixels = pixels.ravel().tolist()
image.filepath_raw = out.replace(".glb", "-shade.png")
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
