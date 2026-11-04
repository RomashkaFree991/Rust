import sys; sys.argv[0]="blender"
import bpy, addon_utils, os
args = sys.argv[sys.argv.index('--')+1:]
p, out = args
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("SourceIO", default_set=True)
bpy.ops.sourceio.mdl(directory=os.path.dirname(p)+'/', files=[{"name":os.path.basename(p)}], import_animations=False, import_textures=True)
for o in list(bpy.data.objects):
    if o.type=='EMPTY': bpy.data.objects.remove(o)
    elif o.name not in bpy.context.scene.objects: bpy.context.scene.collection.objects.link(o)
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=False, export_yup=True)
print("EXPORTED", out)
