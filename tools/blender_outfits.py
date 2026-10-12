"""Planche des tenues : un rendu de face par forme #L2xx (avec visage et cheveux)."""
import sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
out = argv[1]
scene = bpy.context.scene
arm = next(o for o in scene.objects if o.type == 'ARMATURE')
if arm.animation_data:
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
meshes = [o for o in scene.objects if o.type == 'MESH']
always = [o for o in meshes if 'FACE' in o.name.upper() or o.name.upper().startswith('#L101')]
outfits = [o for o in meshes if o not in always]
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'TEXTURE'
scene.render.resolution_x, scene.render.resolution_y = 160, 220
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.7
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = Vector((0, -6, 0.75))
cam.rotation_euler = (1.5708, 0, 0)
names = []
for i, o in enumerate(outfits):
    for m in outfits:
        m.hide_render = (m is not o)
    scene.render.filepath = '%s/%03d.png' % (out, i)
    bpy.ops.render.render(write_still=True)
    names.append(o.name)
open(out + '/names.txt', 'w').write('\n'.join(names))
print('OK', len(names))
