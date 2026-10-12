"""Planche de vignettes de tous les .glb d'un dossier (une image par modèle)."""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src_dir, out_dir = argv[0], argv[1]
os.makedirs(out_dir, exist_ok=True)
for f in sorted(os.listdir(src_dir)):
    if not f.endswith('.glb'):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src_dir, f))
    scene = bpy.context.scene
    for o in list(scene.objects):
        if '-colonly' in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in scene.objects if o.type == 'MESH']
    if not meshes:
        continue
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c, s = (mn + mx) / 2, max(mx - mn)
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x = scene.render.resolution_y = 160
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = s * 1.2
    cam.data.clip_end = 10000
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = c + Vector((s, -s, s * 0.8))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(out_dir, f[:-4] + '.png')
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(out_dir, f[:-4] + '.txt'), 'w') as fh:
        fh.write('%.2f %.2f %.2f' % tuple(mx - mn))
print('OK')
