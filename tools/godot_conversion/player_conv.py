import sys; sys.argv[0]="blender"
import bpy, addon_utils, os
from mathutils import Matrix
args = sys.argv[sys.argv.index('--')+1:]
player_mdl, out = args[0], args[1]
attire = args[2] if len(args) > 2 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("SourceIO", default_set=True)
def imp(p):
    before = set(bpy.data.objects)
    bpy.ops.sourceio.mdl(directory=os.path.dirname(p)+'/', files=[{"name":os.path.basename(p)}], import_animations=False, import_textures=True)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.name not in bpy.context.scene.objects: bpy.context.scene.collection.objects.link(o)
    return new
P = imp(player_mdl)
PA = [o for o in P if o.type=='ARMATURE'][0]
for o in P:
    if o.type=='EMPTY': bpy.data.objects.remove(o, do_unlink=True)
P = list(bpy.data.objects)
pbones = set(b.name for b in PA.data.bones)
def fix(n):
    if n in pbones: return n
    if 'V'+n in pbones: return 'V'+n
    for b in pbones:
        if b.endswith(n.split('.')[-1]) and n.split('.')[-1].startswith('Bip01'): return b
    return None
KEEP = ('Head.Male.Light01','Torso.00','Torso.01','Hands.00','Legs.00','Legs.01','Underwear_Legs','Feet.00','hairs/male_hairstyle_01_LOD0.smd','MaleLight_reference')
if not attire:
    for o in P:
        if o.type=='MESH' and not o.name.startswith(KEEP): bpy.data.objects.remove(o, do_unlink=True)
    P = list(bpy.data.objects)
if attire:
    for o in P:
        if o.type=='MESH': bpy.data.objects.remove(o, do_unlink=True)
    C = imp(attire)
    CA = [o for o in C if o.type=='ARMATURE'][0]
    bpy.context.view_layer.update()
    def depth(b):
        d=0
        while b.parent: b=b.parent; d+=1
        return d
    for b in sorted(CA.data.bones, key=depth):
        t = fix(b.name)
        if not t: continue
        pb = CA.pose.bones[b.name]; pb.rotation_mode='QUATERNION'
        pb.matrix = CA.matrix_world.inverted() @ PA.matrix_world @ PA.data.bones[t].matrix_local
        bpy.context.view_layer.update()
    for m in [o for o in C if o.type=='MESH']:
        bpy.context.view_layer.objects.active = m
        for o in bpy.context.selected_objects: o.select_set(False)
        m.select_set(True)
        mw = m.matrix_world.copy()
        for md in [md for md in m.modifiers if md.type=='ARMATURE']:
            bpy.ops.object.modifier_apply(modifier=md.name)
        m.parent=None; m.matrix_world=mw
        m.data.transform(PA.matrix_world.inverted() @ m.matrix_world)
        m.matrix_world = PA.matrix_world
        m.parent = PA; m.matrix_parent_inverse = Matrix.Identity(4)
        md = m.modifiers.new("Armature",'ARMATURE'); md.object = PA
        for vg in list(m.vertex_groups):
            t = fix(vg.name)
            if t is None:
                # weight to nearest known parent bone in clothing skeleton
                b = CA.data.bones.get(vg.name)
                while b and fix(b.name) is None: b = b.parent
                t = fix(b.name) if b else 'ValveBiped.Bip01_Pelvis'
            if t != vg.name:
                tv = m.vertex_groups.get(t) or m.vertex_groups.new(name=t)
                for v in m.data.vertices:
                    for g in v.groups:
                        if g.group == vg.index and g.weight > 0: tv.add([v.index], g.weight, 'ADD')
                m.vertex_groups.remove(vg)
    for o in C:
        if o.type in ('ARMATURE','EMPTY'): bpy.data.objects.remove(o, do_unlink=True)
for o in bpy.data.objects: print("OBJ", o.name, o.type)
PFX = os.environ.get("PFX","")
for img in bpy.data.images:
    if PFX and not img.name.startswith(PFX+"_"): img.name = PFX+"_"+img.name
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLTF_SEPARATE', export_texture_dir='tex', export_animations=False, export_yup=True)
print("EXPORTED", out)
