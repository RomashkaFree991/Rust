import sys; sys.argv[0]="blender"
import bpy, addon_utils, os
from mathutils import Matrix, Vector, Quaternion
args = sys.argv[sys.argv.index('--')+1:]
player_mdl, ual1, ual2, out = args
bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("SourceIO", default_set=True)
bpy.ops.sourceio.mdl(directory=os.path.dirname(player_mdl)+'/', files=[{"name":os.path.basename(player_mdl)}], import_animations=True, import_include_animations=True, import_textures=False)
native_acts = [a for a in bpy.data.actions]
print("NATIVE", [a.name for a in native_acts])
for o in list(bpy.data.objects):
    if o.name not in bpy.context.scene.objects: bpy.context.scene.collection.objects.link(o)
PA = [o for o in bpy.data.objects if o.type=='ARMATURE'][0]
keep = None
for o in list(bpy.data.objects):
    if o.type=='MESH' and o.name.startswith('Hands.00') and keep is None: keep = o
for o in list(bpy.data.objects):
    if o.type in ('MESH','EMPTY') and o is not keep: bpy.data.objects.remove(o, do_unlink=True)
V = "ValveBiped.Bip01_"
def side(m):
    r = {}
    for k, v in m.items():
        if "{s}" in k or "{S}" in k or "{S}" in v:
            for s, S in (("l","L"),("r","R")):
                r[k.format(s=s, S=S)] = v.format(S=S)
        else: r[k] = v
    return r
MAP1 = side({"DEF-hips":"Pelvis","DEF-spine.001":"Spine","DEF-spine.002":"Spine2","DEF-spine.003":"Spine4","DEF-neck":"Neck1","DEF-head":"Head1",
 "DEF-shoulder.{S}":"{S}_Clavicle","DEF-upper_arm.{S}":"{S}_UpperArm","DEF-forearm.{S}":"{S}_Forearm","DEF-hand.{S}":"{S}_Hand",
 "DEF-thumb.01.{S}":"{S}_Finger0","DEF-thumb.02.{S}":"{S}_Finger01","DEF-thumb.03.{S}":"{S}_Finger02",
 "DEF-f_index.01.{S}":"{S}_Finger1","DEF-f_index.02.{S}":"{S}_Finger11","DEF-f_index.03.{S}":"{S}_Finger12",
 "DEF-f_middle.01.{S}":"{S}_Finger2","DEF-f_middle.02.{S}":"{S}_Finger21","DEF-f_middle.03.{S}":"{S}_Finger22",
 "DEF-f_ring.01.{S}":"{S}_Finger3","DEF-f_ring.02.{S}":"{S}_Finger31","DEF-f_ring.03.{S}":"{S}_Finger32",
 "DEF-f_pinky.01.{S}":"{S}_Finger4","DEF-f_pinky.02.{S}":"{S}_Finger41","DEF-f_pinky.03.{S}":"{S}_Finger42",
 "DEF-thigh.{S}":"{S}_Thigh","DEF-shin.{S}":"{S}_Calf","DEF-foot.{S}":"{S}_Foot","DEF-toe.{S}":"{S}_Toe0"})
MAP2 = side({"pelvis":"Pelvis","spine_01":"Spine","spine_02":"Spine2","spine_03":"Spine4","neck_01":"Neck1","Head":"Head1",
 "clavicle_{s}":"{S}_Clavicle","upperarm_{s}":"{S}_UpperArm","lowerarm_{s}":"{S}_Forearm","hand_{s}":"{S}_Hand",
 "thumb_01_{s}":"{S}_Finger0","thumb_02_{s}":"{S}_Finger01","thumb_03_{s}":"{S}_Finger02",
 "index_01_{s}":"{S}_Finger1","index_02_{s}":"{S}_Finger11","index_03_{s}":"{S}_Finger12",
 "middle_01_{s}":"{S}_Finger2","middle_02_{s}":"{S}_Finger21","middle_03_{s}":"{S}_Finger22",
 "ring_01_{s}":"{S}_Finger3","ring_02_{s}":"{S}_Finger31","ring_03_{s}":"{S}_Finger32",
 "pinky_01_{s}":"{S}_Finger4","pinky_02_{s}":"{S}_Finger41","pinky_03_{s}":"{S}_Finger42",
 "thigh_{s}":"{S}_Thigh","calf_{s}":"{S}_Calf","foot_{s}":"{S}_Foot","ball_{s}":"{S}_Toe0"})
# направление кости: к какому ребёнку смотреть (в именах цели)
DIRCHILD = side({"Pelvis":"Spine","Spine":"Spine2","Spine2":"Spine4","Spine4":"Neck1","Neck1":"Head1",
 "{S}_Clavicle":"{S}_UpperArm","{S}_UpperArm":"{S}_Forearm","{S}_Forearm":"{S}_Hand","{S}_Hand":"{S}_Finger2",
 "{S}_Finger0":"{S}_Finger01","{S}_Finger01":"{S}_Finger02","{S}_Finger1":"{S}_Finger11","{S}_Finger11":"{S}_Finger12",
 "{S}_Finger2":"{S}_Finger21","{S}_Finger21":"{S}_Finger22","{S}_Finger3":"{S}_Finger31","{S}_Finger31":"{S}_Finger32",
 "{S}_Finger4":"{S}_Finger41","{S}_Finger41":"{S}_Finger42",
 "{S}_Thigh":"{S}_Calf","{S}_Calf":"{S}_Foot","{S}_Foot":"{S}_Toe0"})

tb = PA.data.bones
tgt_rest = {b.name: PA.matrix_world @ b.matrix_local for b in tb}
def tdir(n):
    c = DIRCHILD.get(n)
    if c and V+c in tb:
        return (tgt_rest[V+c].translation - tgt_rest[V+n].translation).normalized()
    m = tgt_rest[V+n]; return (m.to_3x3() @ Vector((0,1,0))).normalized()

order = []
def walk(b):
    order.append(b)
    for c in b.children: walk(c)
for b in tb:
    if b.parent is None: walk(b)

def process(path, MAP, wanted):
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    SA = [o for o in new if o.type=='ARMATURE'][0]
    acts = [a for a in bpy.data.actions if a not in acts_before]
    inv = {v: k for k, v in MAP.items()}
    sb = SA.data.bones
    src_rest = {b.name: SA.matrix_world @ b.matrix_local for b in sb}
    def sdir(tn):
        sn = inv[tn]; c = DIRCHILD.get(tn)
        if c and c in inv and inv[c] in sb:
            return (src_rest[inv[c]].translation - src_rest[sn].translation).normalized()
        return (src_rest[sn].to_3x3() @ Vector((0,1,0))).normalized()
    # разворот и масштаб
    def flat(v): v = Vector((v.x, v.y, 0)); return v.normalized()
    fs = flat(src_rest[inv["L_Toe0"]].translation - src_rest[inv["L_Foot"]].translation)
    ft = flat(tgt_rest[V+"L_Toe0"].translation - tgt_rest[V+"L_Foot"].translation)
    G = fs.rotation_difference(ft).to_matrix()
    hs = src_rest[inv["Pelvis"]].translation.z - min(src_rest[inv["L_Toe0"]].translation.z, 0)
    ht = tgt_rest[V+"Pelvis"].translation.z - tgt_rest[V+"L_Toe0"].translation.z
    k = ht / max(hs, 1e-4)
    Q = {}
    for b in order:
        tn = b.name[len(V):] if b.name.startswith(V) else None
        if tn is None or tn not in inv or inv[tn] not in sb: continue
        if tn in ("Pelvis", "Spine", "Spine2", "Spine4", "Neck1", "Head1"):
            # корпус в покое у обоих скелетов прямой — переносим поворот без поправки направления
            Q[tn] = Matrix.Identity(3)
        elif tn in DIRCHILD and DIRCHILD[tn] in inv:
            Q[tn] = tdir(tn).rotation_difference(G @ sdir(tn)).to_matrix()
        else:
            # концевая кость (голова, кончики пальцев, носок) — как у родителя / без поправки
            pn = b.parent.name[len(V):] if b.parent and b.parent.name.startswith(V) else None
            Q[tn] = Q.get(pn, Matrix.Identity(3)) if tn != "Head1" else Matrix.Identity(3)
    results = []
    for act in acts:
        name = act.name
        if wanted and name not in wanted: continue
        SA.animation_data_create()
        SA.animation_data.action = act
        if hasattr(SA.animation_data, "action_slot") and len(getattr(act, "slots", [])):
            SA.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        frames = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            bpy.context.view_layer.update()
            sw = {n: SA.matrix_world @ SA.pose.bones[n].matrix for n in sb.keys()}
            world = {}
            basis = {}
            for b in order:
                tn = b.name[len(V):] if b.name.startswith(V) else None
                par = world.get(b.parent.name) if b.parent else None
                rest_local = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
                fk = (par @ rest_local) if par is not None else (PA.matrix_world @ b.matrix_local)
                if tn in Q:
                    sn = inv[tn]
                    D = G @ sw[sn].to_3x3() @ src_rest[sn].to_3x3().inverted() @ G.inverted()
                    rot = (D @ Q[tn] @ tgt_rest[b.name].to_3x3()).normalized()
                    pos = fk.translation
                    if tn == "Pelvis":
                        pos = tgt_rest[b.name].translation + G @ (sw[sn].translation - src_rest[sn].translation) * k
                    wm = Matrix.Translation(pos) @ rot.to_4x4()
                else:
                    wm = fk
                world[b.name] = wm
                pw = par if par is not None else PA.matrix_world
                basis[b.name] = rest_local.inverted() @ pw.inverted() @ wm
            frames.append(basis)
        results.append((name, f0, frames))
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    return results

all_res = []
all_res += process(ual1, MAP1, {"Idle_Loop","Walk_Loop","Jog_Fwd_Loop","Sprint_Loop","Crouch_Idle_Loop","Crouch_Fwd_Loop","Jump_Start","Jump_Loop","Jump_Land","Death01","Hit_Chest","Hit_Head","Pistol_Idle_Loop","Pistol_Aim_Down","Pistol_Aim_Neutral","Pistol_Aim_Up","Pistol_Shoot","Pistol_Reload","Sword_Attack","Sword_Idle","Punch_Jab","Interact","PickUp_Table"})
all_res += process(ual2, MAP2, {"Chest_Open", "Hit_Knockback", "Consume", "OverhandThrow", "Melee_Hook"})
PA.animation_data_create()
PA.animation_data.action = None
for a in native_acts:
    nm = a.name.lstrip('@')
    if nm not in ("wounded", "sleep", "ragdoll"): continue
    a.name = "Native_" + nm
    # корневая кость нативных анимаций повернута на 90 градусов относительно остальных — доворачиваем
    PA.animation_data.action = a
    if hasattr(PA.animation_data, "action_slot") and len(getattr(a, "slots", [])):
        PA.animation_data.action_slot = a.slots[0]
    root = [b for b in PA.data.bones if b.parent is None][0]
    pb = PA.pose.bones[root.name]
    rest = root.matrix_local
    Rz = Matrix.Rotation(float(os.environ.get("NATIVE_YAW", "90")) * 3.14159265 / 180.0, 4, 'Z')
    f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
    mats = []
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        mats.append(pb.matrix_basis.copy())
    pb.rotation_mode = 'QUATERNION'
    for i, f in enumerate(range(f0, f1 + 1)):
        pb.matrix_basis = rest.inverted() @ Rz @ rest @ mats[i]
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
    PA.animation_data.action = None
    tr = PA.animation_data.nla_tracks.new(); tr.name = a.name
    st = tr.strips.new(a.name, int(a.frame_range[0]), a)
    print("ANIM", a.name, a.frame_range[:])
for name, f0, frames in all_res:
    act = bpy.data.actions.new(name)
    PA.animation_data.action = act
    for i, basis in enumerate(frames):
        for bn, m in basis.items():
            pb = PA.pose.bones[bn]
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis = m
            pb.keyframe_insert("location", frame=i + 1)
            pb.keyframe_insert("rotation_quaternion", frame=i + 1)
    PA.animation_data.action = None
    tr = PA.animation_data.nla_tracks.new(); tr.name = name
    tr.strips.new(name, 1, act)
    print("ANIM", name, len(frames))
for pb in PA.pose.bones: pb.matrix_basis = Matrix.Identity(4)
for o in bpy.data.objects: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
    export_force_sampling=True, export_optimize_animation_size=True, export_image_format='NONE')
print("EXPORTED", out, bpy.context.scene.render.fps)
