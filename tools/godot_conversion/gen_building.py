"""Строительство и размещаемые предметы для Godot: разбирает gRust
  entities/entities/rust_structure.lua      — блоки строительства (сокеты, центр, поворот, цена)
  entities/weapons/rust_buildingplan/shared.lua — список блоков плана постройки (названия, иконки)
  entities/weapons/rust_hammer/shared.lua    — уровни улучшения
  entities/entities/<ent>.lua / <ent>/shared.lua — ENT.Deploy размещаемых предметов (сокеты, модель, звук)
  gamemode/core/inventory/items/deployable.lua — предмет -> сущность
и пишет godot/assets/data/building.json. Координаты сокетов — в юнитах Source (x вперёд, y влево, z вверх).
usage: python3 tools/godot_conversion/gen_building.py"""
import json, os, re, glob

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GM = f"{R}/scripts/gamemodes/rust"


def vec(s):
    return [float(eval(x)) for x in s.split(",")]


def parse_deployable(body):
    d = {"sockets": []}
    m = re.search(r":SetCost\(([\d.]+)\)", body)
    d["cost"] = float(m.group(1)) if m else 0
    m = re.search(r":SetRotate\(([-\d.]+)\)", body)
    d["rotate"] = float(m.group(1)) if m else 0
    m = re.search(r":SetInitialRotation\(([-\d.]+)\)", body)
    d["initial_rotation"] = float(m.group(1)) if m else 0
    d["face_player"] = ":SetFacePlayer(true)" in body
    d["require_socket"] = ":SetRequireSocket(true)" in body
    m = re.search(r":SetCenter\(Vector\(([^)]*)\)\)", body)
    d["center"] = vec(m.group(1)) if m else [0, 0, 0]
    m = re.search(r':SetSound\("([^"]+)"\)', body)
    d["sound"] = m.group(1) if m else ""
    parts = body.split("gRust.CreateSocket()")[1:]
    for p in parts:
        s = {}
        m = re.search(r":SetPosition\(([^)]*)\)", p)
        s["pos"] = vec(m.group(1)) if m else [0, 0, 0]
        m = re.search(r":SetAngle\(([^)]*)\)", p)
        s["ang"] = vec(m.group(1)) if m else [0, 0, 0]
        m = re.search(r":SetAngleOffset\(([^)]*)\)", p)
        s["ang_offset"] = vec(m.group(1)) if m else [0, 0, 0]
        s["male"] = re.findall(r':AddMaleTag\("([^"]+)"\)', p)
        s["female"] = re.findall(r':AddFemaleTag\("([^"]+)"\)', p)
        s["check_free"] = "OccupiedEntity" in p
        d["sockets"].append(s)
    return d


def main():
    out = {"structures": {}, "blocks": [], "upgrades": [], "deployables": {}}
    src = open(f"{GM}/entities/entities/rust_structure.lua").read()
    block = src[src.index("gRust.Structures = {"):]
    block = block[:block.index("\n}\n")]
    keys = list(re.finditer(r'\["models/building_re/twig_([a-z_]+)\.mdl"\]\s*=\s*gRust\.CreateDeployable\(\)', block))
    for i, m in enumerate(keys):
        end = keys[i + 1].start() if i + 1 < len(keys) else len(block)
        out["structures"][m.group(1)] = parse_deployable(block[m.end():end])
    bp = open(f"{GM}/entities/weapons/rust_buildingplan/shared.lua").read()
    for m in re.finditer(r'Model\s*=\s*"models/building_re/twig_([a-z_]+)\.mdl",\s*Name\s*=\s*"([^"]+)"', bp):
        out["blocks"].append({"piece": m.group(1), "name": m.group(2)})
    hm = open(f"{GM}/entities/weapons/rust_hammer/shared.lua").read()
    for m in re.finditer(r'Name\s*=\s*"([^"]+)".*?CostMultiplier\s*=\s*([\d.]+).*?ModelPrefix\s*=\s*"([^"]+)".*?Icon\s*=\s*"([^"]+)".*?Health\s*=\s*(\d+)', hm, re.S):
        out["upgrades"].append({"name": m.group(1), "prefix": m.group(3), "icon": m.group(4), "health": int(m.group(5))})
    items = open(f"{GM}/gamemode/core/inventory/items/deployable.lua").read()
    for m in re.finditer(r'ItemRegister\("([^"]+)"\)(.*?):Register\(\)', items, re.S):
        e = re.search(r'SetEntity\("([^"]+)"\)', m.group(2))
        if not e:
            continue
        ent = e.group(1)
        fs = glob.glob(f"{GM}/entities/entities/{ent}.lua") + glob.glob(f"{GM}/entities/entities/{ent}/shared.lua")
        # базовые классы тоже (rust_tier1 -> rust_workbench)
        txt = "".join(open(f).read() for f in fs)
        base = re.search(r'ENT\.Base\s*=\s*"([^"]+)"', txt)
        dm = re.search(r"ENT\.Deploy\s*=\s*gRust\.CreateDeployable\(\)(.*?)(?:\n\n|\nfunction|\nENT\.)", txt + "\n\n", re.S)
        if not dm and base:
            bfs = glob.glob(f"{GM}/entities/entities/{base.group(1)}.lua") + glob.glob(f"{GM}/entities/entities/{base.group(1)}/shared.lua")
            btxt = "".join(open(f).read() for f in bfs)
            dm = re.search(r"ENT\.Deploy\s*=\s*gRust\.CreateDeployable\(\)(.*?)(?:\n\n|\nfunction|\nENT\.)", btxt + "\n\n", re.S)
        d = parse_deployable(dm.group(1)) if dm else {"sockets": [], "require_socket": False, "rotate": 90, "initial_rotation": 0, "center": [0, 0, 0], "sound": "", "cost": 0, "face_player": False}
        mdl = re.findall(r'(?:ENT\.Model\s*=|SetModel\()\s*"([^"]+\.mdl)"', txt)
        d["entity"] = ent
        d["base"] = base.group(1) if base else ""
        d["model"] = os.path.basename(mdl[0]).lower()[:-4] if mdl else ""
        sl = re.search(r"ENT\.Slots\s*=\s*(\d+)", txt)
        d["slots"] = int(sl.group(1)) if sl else 0
        out["deployables"][m.group(1)] = d
    json.dump(out, open(f"{R}/godot/assets/data/building.json", "w"), indent=1)
    print(len(out["structures"]), "structures", len(out["blocks"]), "blocks", len(out["deployables"]), "deployables")
    for k, v in out["deployables"].items():
        print(k, v["model"], v["base"], "socket" if v["require_socket"] else "ground", [s["male"] for s in v["sockets"]], v["slots"])


main()
