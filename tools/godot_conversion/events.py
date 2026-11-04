import sys, os, json, glob, shutil
sys.path.insert(0,'/root/.config/blender/5.2/scripts/addons')
os.environ['NO_BPY']='1'
import SourceIO
from SourceIO.library.utils import FileBuffer
from SourceIO.library.models.mdl.v49.mdl_file import MdlV49
R='/home/user/Rust'; G=R+'/godot/assets/sounds'
def find_sound(name):
    n=name.split('.',1)[-1]
    nd=lambda l:[x for x in sorted(l) if 'distant' not in x and 'zohart' not in x]
    c=nd(glob.glob(f'{R}/sounds/**/{n}.mp3',recursive=True)) or nd(glob.glob(f'{R}/sounds/**/{n}-[0-9]*.mp3',recursive=True))
    out=[]
    for x in c:
        shutil.copy(x, G); out.append('res://assets/sounds/'+os.path.basename(x))
    if not out: print("MISSING", name)
    return out
res={}
for w, extra in [('ak47u',['darky_rust.ak74u-attack']),('thompson',['darky_rust.thompson-attack']),('python',['darky_rust.python-attack','darky_rust.python-dryfire'])]:
    mdl=MdlV49.from_buffer(FileBuffer(f'/opt/tools/gmod/models/weapons/darky_m/rust/c_{w}.mdl'))
    seqs={}
    for s in mdl.sequences:
        ad=mdl.anim_descs[s.anim_desc_indices[0]]
        seqs[s.name]={'anim':ad.name.lstrip('@'),'frames':ad.frame_count,'fps':ad.fps,'activity':s.activity_name,
            'events':[{'t':round(e.cycle*(ad.frame_count-1)/ad.fps,3),'sounds':find_sound(e.options)} for e in s.events if e.event==5004]}
    res[w]={'seqs':seqs,'sounds':{e.split('.',1)[1]:find_sound(e) for e in extra}}
json.dump(res,open(R+'/godot/assets/weapons/weapons.json','w'),indent=1)
print(json.dumps(res)[:1500])
