"""Rendu d'un .glb vu en plongée à 45°, faces arrière masquées (comme en jeu).
blender -b --factory-startup --python tools/blender_cull_view.py -- in.glb out.png [x y z cible Blender]"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
scene = bpy.context.scene
for o in list(scene.objects):
    if '-colonly' in o.name:
        bpy.data.objects.remove(o, do_unlink=True)
target = Vector([float(v) for v in argv[2:5]]) if len(argv) >= 5 else Vector((50, 60, 10))
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.show_backface_culling = True
scene.render.resolution_x, scene.render.resolution_y = 1000, 700
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
scene.camera = cam
d = 30.0
cam.location = target + Vector((0, -d * math.cos(math.radians(50)), d * math.sin(math.radians(50))))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = argv[1]
bpy.ops.render.render(write_still=True)
print('OK')
