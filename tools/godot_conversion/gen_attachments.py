"""Обвесы оружия из gRust: SWEP.Attachments (entities/weapons/*.lua) + слоты оружия (items/weapons.lua)
-> godot/assets/data/attachments.json. Печатает список моделей обвесов для конвертации."""
import json, os, re, glob
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GM = f"{R}/scripts/gamemodes/rust"
TYPES = {"Barrel": "barrel", "Sight": "sight", "Magazine": "magazine", "Stock": "stock", "Underbarrel": "underbarrel", "Other": "other"}
NUM = r"(-?[\d.]+)"
def vec(body, fn):
    m = re.search(r":%s\(\s*(?:Vector|Angle)\(\s*%s\s*,\s*%s\s*,\s*%s\s*\)\s*\)" % (fn, NUM, NUM, NUM), body)
    return [float(m.group(i)) for i in (1, 2, 3)] if m else None
def block_end(src, start):
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{": depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0: return i
    return len(src)
data = json.load(open(f"{R}/godot/assets/data/items.json"))
swep2item = {d["swep"]: k for k, d in data["items"].items() if d.get("swep")}
slots = {}
src = open(f"{GM}/gamemode/core/inventory/items/weapons.lua", encoding="utf-8").read()
for m in re.finditer(r'gRust\.ItemRegister\("([^"]+)"\)(.*?):Register\(\)', src, re.S):
    s = re.search(r":SetSlots\((\d+)\)", m.group(2))
    if s: slots[m.group(1)] = int(s.group(1))
out = {"weapons": {}, "models": []}
models = set()
for fn in sorted(glob.glob(f"{GM}/entities/weapons/*.lua")):
    cls = os.path.basename(fn)[:-4]
    s = open(fn, encoding="utf-8", errors="ignore").read()
    i = s.find("SWEP.Attachments")
    if i < 0 or cls not in swep2item: continue
    b0 = s.index("{", i); b1 = block_end(s, b0)
    body = s[b0 + 1:b1]
    atts = {}
    for m in re.finditer(r'\["([^"]+)"\]\s*=\s*gRust\.CreateAttachment\(AttachmentType\.(\w+)\)', body):
        st = m.end()
        nxt = re.search(r'\["[^"]+"\]\s*=\s*gRust\.CreateAttachment', body[st:])
        chunk = body[st: st + nxt.start()] if nxt else body[st:]
        a = {"type": TYPES.get(m.group(2), "other")}
        mm = re.search(r':SetModel\("([^"]+)"\)', chunk); a["model"] = mm.group(1) if mm else ""
        mm = re.search(r':SetBone\("([^"]+)"\)', chunk); a["bone"] = mm.group(1) if mm else "main"
        a["pos"] = vec(chunk, "SetPosition") or [0, 0, 0]
        a["ang"] = vec(chunk, "SetAngle") or [0, 0, 0]
        mm = re.search(r":SetScale\(%s\)" % NUM, chunk); a["scale"] = float(mm.group(1)) if mm else 1.0
        for k, f in [("ads", "SetIronSightsPos"), ("ads_ang", "SetIronSightsAng"), ("reticle_pos", "SetRectilePosition"), ("reticle_ang", "SetRectileAngle")]:
            v = vec(chunk, f)
            if v: a[k] = v
        mm = re.search(r":SetRectileScale\(%s\)" % NUM, chunk)
        if mm: a["reticle_scale"] = float(mm.group(1))
        mm = re.search(r"surface\.SetDrawColor\((\d+),\s*(\d+),\s*(\d+)", chunk)
        if mm: a["reticle_color"] = [int(mm.group(i)) / 255.0 for i in (1, 2, 3)]
        atts[m.group(1)] = a
        if a["model"]: models.add(a["model"])
    sil = re.search(r'SWEP\.ShootSoundSilenced\s*=\s*"([^"]+)"', s)
    iid = swep2item[cls]
    out["weapons"][iid] = {"slots": slots.get(iid, 3), "attachments": atts, "silenced_sound": sil.group(1) if sil else ""}
import shutil
allsnd = [p for p in glob.glob(f"{R}/sounds/**/*.mp3", recursive=True) + glob.glob(f"{R}/sounds/**/*.wav", recursive=True)]
for iid, w in out["weapons"].items():
    FALLBACK = {"assault_rifle": "ak74u-attack-silenced", "semi_automatic_rifle": "sar_attack-silenced", "python_revolver": "revolver-attack-silenced"}
    n = FALLBACK.get(iid, w["silenced_sound"].split(".", 1)[-1].lower())
    c = sorted(p for p in allsnd if os.path.splitext(os.path.basename(p))[0].lower() == n and "distant" not in p)
    if not c and n:
        c = sorted(p for p in allsnd if os.path.splitext(os.path.basename(p))[0].lower().startswith(n.replace("-silenced", "")) and "silenced" in p)
    files = []
    seen = set()
    c = [x for x in c if not (os.path.basename(x) in seen or seen.add(os.path.basename(x)))]
    for x in c[:2]:
        shutil.copy(x, f"{R}/godot/assets/sounds/")
        files.append("res://assets/sounds/" + os.path.basename(x))
    w["silenced_files"] = files
    if not files: print("NO SILENCED SOUND", iid, n)
out["models"] = sorted(models)
json.dump(out, open(f"{R}/godot/assets/data/attachments.json", "w"), indent=1)
print(len(out["weapons"]), "weapons")
for k, v in out["weapons"].items(): print(k, v["slots"], sorted(v["attachments"]))
for m in out["models"]: print("MODEL", m)
