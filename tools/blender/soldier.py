"""Dresses the game's soldier: a jacket and trousers as cloth shells over the mannequin's body.

    blender -b -P soldier.py -- in.glb out.glb
The body is painted by region through its texture coordinates (an 8 x 1 palette: skin, hair,
jacket, trousers, boots, belt). The jacket's and the trousers' faces are lifted off the body,
smoothed until the muscles are gone, and given a hem, a collar and cuffs. Skin weights and texture
coordinates are carried over, so every animation and every uniform palette still fits.
"""
import sys
import bpy, bmesh
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
SKIN, HAIR, JACKET, TROUSERS, BOOTS, BELT = range(6)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = next(o for o in bpy.data.objects if o.type == 'MESH' and len(o.vertex_groups) > 0)
print("actions", len(bpy.data.actions), "mesh", body.name, "dims", tuple(round(v, 2) for v in body.dimensions))

bm = bmesh.new()
bm.from_mesh(body.data)
uv = bm.loops.layers.uv.active

def region(face):
    return int(min(7, max(0, face.loops[0][uv].uv.x * 8)))

def shell(which, lift, smooth_rounds, also=()):
    """Lifts the faces of a region off the body as cloth, and returns its vertices."""
    faces = [f for f in bm.faces if region(f) == which or region(f) in also]
    made = bmesh.ops.duplicate(bm, geom=faces)
    new_faces = [g for g in made["geom"] if isinstance(g, bmesh.types.BMFace)]
    verts = list({v for f in new_faces for v in f.verts})
    bm.normal_update()
    for v in verts:
        v.co += v.normal * lift
    for _ in range(smooth_rounds):
        bmesh.ops.smooth_vert(bm, verts=verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bm.normal_update()
        for v in verts:
            v.co += v.normal * (lift * 0.12)      # smoothing shrinks; keep the cloth off the skin
    bmesh.ops.delete(bm, geom=faces, context='FACES')
    return [f for f in new_faces if f.is_valid]

def rim(faces, keep):
    """The open edges of a shell whose middle passes keep(point)."""
    edges = {e for f in faces for e in f.edges if e.is_boundary}
    return [e for e in edges if keep((e.verts[0].co + e.verts[1].co) / 2)]

def extend(edges, which, down, outward):
    """Grows cloth from an open edge: down, and away from the limb's own axis."""
    if not edges:
        return
    made = bmesh.ops.extrude_edge_only(bm, edges=edges)
    new_verts = [g for g in made["geom"] if isinstance(g, bmesh.types.BMVert)]
    centre = sum((v.co for v in new_verts), Vector()) / len(new_verts)
    for v in new_verts:
        away = Vector((v.co.x - centre.x, v.co.y - centre.y, 0))
        if away.length > 1e-5:
            away.normalize()
        v.co += away * outward + Vector((0, 0, -down))
    u = (which + 0.5) / 8
    for g in made["geom"]:
        if isinstance(g, bmesh.types.BMFace):
            for loop in g.loops:
                loop[uv].uv = (u, 0.5)

zs = [v.co.z for v in bm.verts]
top, bottom = max(zs), min(zs)
height = top - bottom
at = lambda fraction: bottom + height * fraction      # a height on the body, as a fraction of it
print("height", round(height, 3))

jacket = shell(JACKET, 0.014, 5, also=(BELT,))
# The skirt of the jacket, down over the belt and the hips.
extend(rim(jacket, lambda p: at(0.50) < p.z < at(0.62) and abs(p.x) < height * 0.16), JACKET, height * 0.085, 0.022)
# A standing collar.
extend(rim(jacket, lambda p: p.z > at(0.80)), JACKET, -height * 0.022, 0.008)
trousers = shell(TROUSERS, 0.012, 7)
# Each leg bloused over its boot.
for side in (-1, 1):
    extend(rim(trousers, lambda p, s=side: p.z < at(0.25) and p.x * s > 0), TROUSERS, height * 0.02, 0.016)

bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(body.data)
bm.free()
for polygon in body.data.polygons:
    polygon.use_smooth = True
print("faces", len(body.data.polygons))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True, export_animations=True,
        export_animation_mode='ACTIONS', export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
        export_force_sampling=True, export_anim_slide_to_zero=False)
print("wrote", out)
