"""Nettoyage d'un GLB généré (Blender en arrière-plan) : pose au sol, centrage, taille, aperçu.

  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup \\
      --python tools/art/glb_cleanup.py -- entree.glb sortie.glb [hauteur_m=0.8] [faces_max=0] [apercu.png]

- un seul objet (fusion), origine au centre de la base (x = z = 0, bas à y = 0 dans Godot) ;
- mise à l'échelle pour une hauteur donnée en mètres (Godot : 1 unité = 1 m) ;
- faces_max > 0 : réduction (Decimate) jusqu'à ce nombre de triangles ;
- textures réécrites en JPEG qualité 90 (couleur, ORM, normales) : fichier ~4 fois plus léger ;
- apercu.png : rendu Eevee 3/4 avec les textures (vérification visuelle).
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
height = float(argv[2]) if len(argv) > 2 else 0.8
max_faces = int(argv[3]) if len(argv) > 3 else 0
preview = argv[4] if len(argv) > 4 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
# détacher des éventuels parents vides, appliquer les transformations
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)

if max_faces > 0 and len(obj.data.polygons) > max_faces:
    m = obj.modifiers.new("dec", "DECIMATE")
    m.ratio = max_faces / len(obj.data.polygons)
    bpy.ops.object.modifier_apply(modifier=m.name)

bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
scale = height / max(hi.z - lo.z, 1e-6)  # Blender : Z vers le haut
base = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
obj.data.transform(__import__("mathutils").Matrix.Translation(-base))
obj.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
obj.name = obj.data.name = "objet"
dims = tuple(round(d, 3) for d in obj.dimensions)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=False,
                          export_image_format="JPEG", export_jpeg_quality=90,
                          export_apply=True, export_yup=True)
print(f"[glb_cleanup] {dst} : {len(obj.data.polygons)} faces, dimensions x/y/z(haut) {dims} m, échelle x{scale:.3f}")

if preview:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 768
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.07, 0.16, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    d = max(obj.dimensions) * 2.2
    target = Vector((0, 0, obj.dimensions.z * 0.45))
    cam.location = target + Vector((d * math.sin(math.radians(35)), -d * math.cos(math.radians(35)), d * 0.55))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    for i, (rot, energy) in enumerate((((50, 0, 30), 4.0), ((60, 0, 200), 1.5))):
        sun = bpy.data.objects.new(f"sun{i}", bpy.data.lights.new(f"sun{i}", "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(sun)
    sc.render.filepath = preview
    bpy.ops.render.render(write_still=True)
    print(f"[glb_cleanup] aperçu {preview}")
