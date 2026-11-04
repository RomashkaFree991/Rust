import sys; sys.argv[0]="blender"
import bpy, addon_utils, os
from mathutils import Matrix
args = sys.argv[sys.argv.index('--')+1:]
wpn_mdl, arms_mdl, out = args
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("SourceIO", default_set=True)

def imp(p, anims):
    before = set(bpy.data.objects)
    bpy.ops.sourceio.mdl(directory=os.path.dirname(p)+'/', files=[{"name":os.path.basename(p)}],
        import_animations=anims, import_include_animations=anims, import_textures=True)
    return [o for o in bpy.data.objects if o not in before]

wobjs = imp(wpn_mdl, True)
W = [o for o in wobjs if o.type=='ARMATURE'][0]
aobjs = imp(arms_mdl, False)
A = [o for o in aobjs if o.type=='ARMATURE'][0]
arm_meshes = [o for o in aobjs if o.type=='MESH' and o.name.split('.')[0] in ('hand_mesh','Hoodie_vm','TacticalGloves_vm','BurlapGloves_vm','RoadsignGloves_vm')]
for o in aobjs:
    if o.type=='MESH' and o not in arm_meshes: bpy.data.objects.remove(o, do_unlink=True)
print("W mat", W.matrix_world, "A mat", A.matrix_world)
for o in list(bpy.data.objects):
    if o.name not in bpy.context.scene.objects:
        bpy.context.scene.collection.objects.link(o)
bpy.context.view_layer.update()

# bonemerge: pose arms skeleton so that common bones match weapon rest pose
A.animation_data_clear() if A.animation_data else None
W.animation_data_create(); W.animation_data.action = None
common = [b.name for b in A.data.bones if b.name in W.data.bones]
print("common bones", len(common), "arms-only", [b.name for b in A.data.bones if b.name not in W.data.bones])
def depth(b):
    d=0
    while b.parent: b=b.parent; d+=1
    return d
for bn in sorted(common, key=lambda n: depth(A.data.bones[n])):
    pb = A.pose.bones[bn]
    pb.rotation_mode='QUATERNION'
    target_world = W.matrix_world @ W.data.bones[bn].matrix_local
    pb.matrix = A.matrix_world.inverted() @ target_world
    bpy.context.view_layer.update()

for m in arm_meshes:
    bpy.context.view_layer.objects.active = m
    for o in bpy.context.selected_objects: o.select_set(False)
    m.select_set(True)
    mods = [md for md in m.modifiers if md.type=='ARMATURE']
    mw = m.matrix_world.copy()
    for md in mods:
        bpy.ops.object.modifier_apply(modifier=md.name)
    m.parent = None
    m.matrix_world = mw
    # bake into W space
    m.data.transform(W.matrix_world.inverted() @ m.matrix_world)
    m.matrix_world = W.matrix_world
    m.parent = W
    m.matrix_parent_inverse = Matrix.Identity(4)
    md = m.modifiers.new("Armature", 'ARMATURE'); md.object = W
    # drop vertex groups that don't exist in W (shouldn't be weighted)
    for vg in list(m.vertex_groups):
        if vg.name not in W.data.bones:
            tgt = vg.name.replace("Ulna","Forearm")
            print("merge vgroup", vg.name, "->", tgt)
            tv = m.vertex_groups.get(tgt) or m.vertex_groups.new(name=tgt)
            for v in m.data.vertices:
                for g in v.groups:
                    if g.group == vg.index and g.weight > 0:
                        tv.add([v.index], g.weight, 'ADD')
            m.vertex_groups.remove(vg)

bpy.data.objects.remove(A, do_unlink=True)
for o in wobjs:
    if o.type=='EMPTY':
        print("EMPTY", o.name, o.parent, o.parent_type, o.parent_bone)
        o.name = {"0":"muzzle","1":"eject"}.get(o.name, o.name)
        mw = o.matrix_world.copy()
        o.constraints.clear()
        o.parent = W; o.parent_type='BONE'; o.parent_bone='main'
        bpy.context.view_layer.update()
        o.matrix_world = mw

# Actions -> NLA tracks for export
acts = [a for a in bpy.data.actions]
print("actions", [a.name for a in acts])
W.animation_data.action = None
for a in acts:
    tr = W.animation_data.nla_tracks.new(); tr.name = a.name.lstrip('@')
    st = tr.strips.new(a.name.lstrip('@'), int(a.frame_range[0]), a)
    a.name = a.name.lstrip('@')
for m in list(bpy.data.meshes):
    if m.users == 0: bpy.data.meshes.remove(m)
for m in list(bpy.data.materials):
    if m.users == 0: bpy.data.materials.remove(m)
PFX = os.environ.get("PFX", "")
SHARED = ("ViewmodelArms","BurlapHandWraps","Roadsign_","TacticalGloves","hoodie_")
for img in bpy.data.images:
    if PFX and not img.name.startswith(SHARED) and not img.name.startswith(PFX + "_"):
        img.name = PFX + "_" + img.name
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLTF_SEPARATE', export_texture_dir='tex', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_image_format='AUTO', export_yup=True,
    export_force_sampling=True, export_frame_range=False, export_def_bones=False, export_optimize_animation_size=True)
print("EXPORTED", out)
