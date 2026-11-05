"""Таблица анимаций/событий/звуков для всех вьюмоделей (godot/assets/weapons/weapons.json)."""
import sys, os, json, glob, shutil
sys.path.insert(0, '/root/.config/blender/5.2/scripts/addons'); os.environ['NO_BPY'] = '1'
import SourceIO
from SourceIO.library.utils import FileBuffer
from SourceIO.library.models.mdl.v49.mdl_file import MdlV49
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GM = '/opt/tools/gmod'
SND = R + '/godot/assets/sounds'
idx = {p.lower(): p for p in glob.glob(f"{GM}/models/**/*.mdl", recursive=True)}
allsnd = [p for p in glob.glob(f'{R}/sounds/**/*.*', recursive=True) if p.endswith(('.mp3', '.wav', '.ogg'))]
def find_sound(name):
    if not name:
        return []
    n = name.split('.', 1)[-1].lower()
    nd = lambda l: [x for x in sorted(l) if 'distant' not in x and '/zohart/' not in x and 'silenced' not in x]
    c = nd([p for p in allsnd if os.path.splitext(os.path.basename(p))[0].lower() == n])
    if not c:
        c = nd([p for p in allsnd if os.path.splitext(os.path.basename(p))[0].lower().startswith(n + '-') and os.path.splitext(os.path.basename(p))[0][len(n)+1:].lstrip('0').isdigit()])
    if not c:
        c = nd([p for p in allsnd if os.path.splitext(os.path.basename(p))[0].lower().startswith(n)])[:4]
    out = []
    for x in c[:4]:
        b = os.path.basename(x)
        if not os.path.exists(f'{SND}/{b}'):
            shutil.copy(x, SND)
        out.append('res://assets/sounds/' + b)
    return out
data = json.load(open(R + '/godot/assets/data/items.json'))
res = {}
for iid in data['order']:
    d = data['items'][iid]
    vn = d.get('vm_name')
    if not vn or vn in res:
        continue
    p = idx.get(f"{GM}/{d['viewmodel']}".lower())
    mdl = MdlV49.from_buffer(FileBuffer(p))
    seqs = {}
    for s in mdl.sequences:
        ad = mdl.anim_descs[s.anim_desc_indices[0]]
        seqs[s.name] = {'anim': ad.name.lstrip('@'), 'frames': ad.frame_count, 'fps': ad.fps, 'activity': s.activity_name,
                        'events': [{'t': round(e.cycle * (ad.frame_count - 1) / ad.fps, 3), 'sounds': find_sound(e.options)} for e in s.events if e.event == 5004]}
    snd = {}
    for k in ['shoot_sound', 'swing_sound', 'hit_sound']:
        if d.get(k):
            snd[k] = find_sound(d[k])
    if 'shoot_sound' in d and not snd.get('shoot_sound'):
        snd['shoot_sound'] = find_sound(vn + '-attack') or find_sound(vn.split('_')[0] + '-attack')
    FB = {'semi_auto_pistol': 'semi-auto-pistol-attack', 'sar': 'semi-auto-rifle-attack', 'rocketlauncher': 'rocket-launcher-attack',
          'crossbow': 'crossbow-attack', 'bow': 'bow-attack', 'compoundbow': 'compound-bow-attack', 'grenadelauncher': 'grenade-launcher-attack'}
    if vn in FB and not snd.get('shoot_sound'):
        snd['shoot_sound'] = find_sound(FB[vn])
    if d.get('kind') == 'melee':
        if not snd.get('swing_sound'):
            snd['swing_sound'] = find_sound('2handed-sword-attack' if vn in ('longsword', 'mace', 'salvaged_cleaver') else 'bone-knife-attack')
        if not snd.get('hit_sound'):
            snd['hit_sound'] = find_sound('2handed-sword-strike' if vn in ('longsword', 'mace') else 'bone-knife-strike')
    if d.get('kind') == 'throw':
        snd['explode'] = find_sound('explosion') or find_sound('c4-explosion')
    res[vn] = {'seqs': seqs, 'sounds': snd}
    print(vn, sorted({s['activity'] for s in seqs.values()}), {k: len(v) for k, v in snd.items()})
json.dump(res, open(R + '/godot/assets/weapons/weapons.json', 'w'), indent=1)
