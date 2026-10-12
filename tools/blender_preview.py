"""Rendu d'aperçu d'un .glb avec Blender en ligne de commande.

blender -b --factory-startup --python tools/blender_preview.py -- <in.glb> <out.png> [anim] [frame]
Produit une planche : face / profil / dos (+ la pose d'animation demandée).
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, out = argv[0], argv[1]
anim = argv[2] if len(argv) > 2 else None
frame = float(argv[3]) if len(argv) > 3 else 0.5

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
# les volumes de collision (-colonly) ne se voient pas en jeu
for o in list(scene.objects):
    if '-colonly' in o.name:
        bpy.data.objects.remove(o, do_unlink=True)
top_view = anim == 'top'
if top_view:
    anim = None

arm = next((o for o in scene.objects if o.type == 'ARMATURE'), None)
if arm and arm.animation_data:
    act = bpy.data.actions.get(anim) if anim else None
    if anim and act is None:
        act = next((a for a in bpy.data.actions if a.name.startswith(anim)), None)
    if act:
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        scene.frame_set(int(f0 + (f1 - f0) * frame))
    else:
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis.identity()
bpy.context.view_layer.update()

# boîte englobante des maillages évalués
deps = bpy.context.evaluated_depsgraph_get()
pts = []
for o in scene.objects:
    if o.type == 'MESH':
        eo = o.evaluated_get(deps)
        me = eo.to_mesh()
        pts += [eo.matrix_world @ v.co for v in me.vertices]
        eo.to_mesh_clear()
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center, size = (mn + mx) / 2, (mx - mn)
print('BBOX min', tuple(round(x, 3) for x in mn), 'max', tuple(round(x, 3) for x in mx))

scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 400, 500
scene.render.film_transparent = False
world = bpy.data.worlds.new('w')
scene.world = world
world.color = (0.18, 0.2, 0.25)

cam_data = bpy.data.cameras.new('cam')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = max(size.x, size.y, size.z) * 1.15
cam_data.clip_end = 10000
cam = bpy.data.objects.new('cam', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

import os  # noqa: E402
tiles = []
views = (('dessus', None),) if top_view else (('face', 0), ('profil', 90), ('dos', 180))
if top_view:
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
for label, ang in views:
    if ang is None:
        cam.location = center + Vector((0, 0, max(size) * 3))
        cam.rotation_euler = (0, 0, 0)
        scene.render.filepath = out.replace('.png', '_%s.png' % label)
        bpy.ops.render.render(write_still=True)
        tiles.append(scene.render.filepath)
        continue
    a = math.radians(ang)
    d = max(size) * 3
    # glTF -Z avant -> Blender +Y ; on regarde depuis +Y vers l'objet ("face")
    cam.location = center + Vector((math.sin(a) * d, -math.cos(a) * d * -1, 0))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    path = out.replace('.png', '_%s.png' % label)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    tiles.append(path)

# assemble en une planche
imgs = [bpy.data.images.load(p) for p in tiles]
w, h = imgs[0].size
sheet = bpy.data.images.new('sheet', w * len(imgs), h)
px = [0.0] * (w * len(imgs) * h * 4)
for k, im in enumerate(imgs):
    src_px = list(im.pixels)
    for y in range(h):
        row = src_px[y * w * 4:(y + 1) * w * 4]
        start = (y * w * len(imgs) + k * w) * 4
        px[start:start + w * 4] = row
sheet.pixels = px
sheet.filepath_raw = out
sheet.file_format = 'PNG'
sheet.save()
for p in tiles:
    os.remove(p)
print('OK', out)
