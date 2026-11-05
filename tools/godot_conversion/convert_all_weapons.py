"""Конвертирует все c_/w_ модели оружия из godot/assets/data/items.json (через Blender bpy + SourceIO)
и прописывает в items.json пути к сценам (scene/world). usage: python3 convert_all_weapons.py"""
import json, os, subprocess, glob
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONV = "/opt/tools/conv"
GM = "/opt/tools/gmod"
G = f"{R}/godot/assets/weapons"
ARMS = f"{GM}/models/player/darky_m/rust/c_arms_human.mdl"
idx = {p.lower(): p for p in glob.glob(f"{GM}/models/**/*.mdl", recursive=True)}
data = json.load(open(f"{R}/godot/assets/data/items.json"))
done = {}
for iid in data["order"]:
    d = data["items"][iid]
    if d.get("type") != "weapon":
        continue
    vm = d.get("viewmodel") or ""
    wm = d.get("worldmodel") or ""
    vp = idx.get(f"{GM}/{vm}".lower()) if vm else None
    wp = idx.get(f"{GM}/{wm}".lower()) if wm else None
    name = os.path.basename(vm).lower()[2:-4] if vp else None
    pfx = name or iid
    if vp:
        out = f"{G}/{name}.gltf"
        if out not in done and not os.path.exists(out):
            r = subprocess.run([f"{CONV}/run.sh", f"{CONV}/convert2.py", vp, ARMS, out], env={**os.environ, "PFX": pfx}, capture_output=True, text=True)
            print("VM", iid, os.path.exists(out), (r.stdout + r.stderr).count("Error"))
        done[out] = 1
        d["scene"] = f"res://assets/weapons/{name}.gltf"
        d["vm_name"] = name
    if wp:
        wn = os.path.basename(wm).lower()[:-4]
        out = f"{G}/{wn}.gltf"
        if out not in done and not os.path.exists(out):
            r = subprocess.run([f"{CONV}/run.sh", f"{CONV}/static2.py", wp, out], env={**os.environ, "PFX": pfx}, capture_output=True, text=True)
            print("WM", iid, os.path.exists(out))
        done[out] = 1
        d["world"] = f"res://assets/weapons/{wn}.gltf"
    if not vp:
        print("NO VIEWMODEL", iid, vm)
json.dump(data, open(f"{R}/godot/assets/data/items.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
