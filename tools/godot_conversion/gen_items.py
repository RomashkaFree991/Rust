"""Собирает базу предметов для Godot из Lua-исходников gRust:
  scripts/gamemodes/rust/gamemode/core/inventory/items/*.lua  — реестр (название, описание, иконка, стак, категория, рецепт)
  scripts/gamemodes/rust/entities/weapons/*.lua                — параметры оружия (SWEP: урон, темп, магазин, патроны, модели)
Пишет godot/assets/data/items.json, копирует иконки в godot/assets/icons/items/ и печатает список моделей для конвертации.
usage: python3 tools/godot_conversion/gen_items.py
"""
import csv, json, os, re, shutil, glob

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GM = f"{R}/scripts/gamemodes/rust"
OUT = f"{R}/godot/assets/data/items.json"
ICON_DIR = f"{R}/godot/assets/icons/items"

orig = {}
with open(f"{R}/manifest.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        orig.setdefault(r["original_path"].lower(), r["path"])


def lua_str(s):
    return s.replace('\\"', '"').replace("\\n", "\n")


def parse_registry():
    items = {}
    order = []
    for fn in sorted(glob.glob(f"{GM}/gamemode/core/inventory/items/*.lua")):
        src = open(fn, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r'gRust\.ItemRegister\("([^"]+)"\)(.*?):Register\(\)', src, re.S):
            iid, body = m.group(1), m.group(2)
            it = {"id": iid, "file": os.path.basename(fn)[:-4]}
            def g(name, pat=r'"((?:[^"\\]|\\.)*)"'):
                mm = re.search(r":%s\(\s*%s" % (name, pat), body)
                return mm.group(1) if mm else None
            it["name"] = lua_str(g("SetName") or iid)
            it["desc"] = lua_str(g("SetDescription") or "")
            it["icon_src"] = g("SetIcon")
            st = g("SetStack", r"(\d+)")
            it["stack"] = int(st) if st else 1
            it["categories"] = re.findall(r':AddToCategory\("([^"]+)"\)', body)
            rm = re.search(r":SetRecipe\((.*?)\)", body, re.S)
            if rm:
                parts = re.findall(r'"([^"]+)"\s*,\s*(\d+)', rm.group(1))
                it["recipe"] = [[a, int(b)] for a, b in parts]
            it["craftable"] = bool(re.search(r":SetCraftable\(true\)", body))
            ca = g("SetCraftAmount", r"(\d+)")
            it["craft_amount"] = int(ca) if ca else 1
            ct = g("SetCraftTime", r"([\d.]+)")
            it["craft_time"] = float(ct) if ct else 0.0
            tr = g("SetTier", r"(\d+)")
            it["tier"] = int(tr) if tr else 0
            it["weapon"] = g("SetWeapon")
            it["model"] = g("SetModel")
            it["material"] = g("SetMaterial")
            cl = g("SetClipSize", r"(\d+)")
            if cl:
                it["clip"] = int(cl)
            am = re.search(r"gRust\.CreateAttire\(AttireType\.(\w+)\)(.*?)\n\)", body, re.S)
            if am:
                at = {"type": am.group(1)}
                mm = re.search(r':SetModel\("([^"]+)"\)', am.group(2))
                at["model"] = mm.group(1) if mm else None
                for k in ["Projectile", "Melee", "Bite", "Radiation", "Cold", "Explosive"]:
                    v = re.search(r":Set%sResistance\(([\d.]+)\)" % k, am.group(2))
                    at[k.lower()] = float(v.group(1)) if v else 0.0
                it["attire"] = at
            items[iid] = it
            order.append(iid)
    return items, order


def parse_sweps():
    sweps = {}
    files = glob.glob(f"{GM}/entities/weapons/*.lua") + glob.glob(f"{GM}/entities/weapons/*/shared.lua")
    for fn in files:
        cls = os.path.basename(fn)[:-4] if not fn.endswith("shared.lua") else os.path.basename(os.path.dirname(fn))
        src = open(fn, encoding="utf-8", errors="ignore").read()
        s = {}
        for k, v in re.findall(r"^SWEP\.([A-Za-z_]+)\s*=\s*(.+?)\s*(?:--.*)?$", src, re.M):
            v = v.strip().rstrip(",")
            if v.startswith('"'):
                s[k] = v.strip('"')
            elif re.match(r"^-?[\d.]+$", v):
                s[k] = float(v)
            elif v.startswith("Vector("):
                s[k] = [float(x) for x in re.findall(r"-?[\d.]+", v)]
            elif v in ("true", "false"):
                s[k] = v == "true"
        am = re.search(r"SWEP\.AmmoTypes\s*=\s*\{(.*?)\n\}", src, re.S)
        if am:
            s["AmmoTypes"] = re.findall(r'Item\s*=\s*"([^"]+)"', am.group(1))
        rt = re.search(r"SWEP\.RecoilTable\s*=\s*\{(.*?)\n\}", src, re.S)
        if rt:
            s["RecoilTable"] = [[float(a), float(b)] for a, b in re.findall(r"Angle\(\s*(-?[\d.*]+)[^,]*,\s*(-?[\d.]+)", rt.group(1)) if "*" not in a][:40]
        auto = re.search(r"SWEP\.Primary\.Automatic\s*=\s*(true|false)", src)
        if auto:
            s["Automatic"] = auto.group(1) == "true"
        sweps[cls] = s
    # наследование
    def resolved(cls, depth=0):
        s = dict(sweps.get(cls, {}))
        base = s.get("Base")
        if base and base in sweps and depth < 6:
            b = resolved(base, depth + 1)
            b.update(s)
            s = b
        return s
    return {c: resolved(c) for c in sweps}


def icon_path(src):
    if not src:
        return None
    p = orig.get(src.lower()) or orig.get(("materials/" + src).lower())
    if not p:
        return None
    os.makedirs(ICON_DIR, exist_ok=True)
    dst = f"{ICON_DIR}/{os.path.basename(p)}"
    if not os.path.exists(dst):
        shutil.copy(f"{R}/{p}", dst)
    return "res://assets/icons/items/" + os.path.basename(p)


def main():
    items, order = parse_registry()
    sweps = parse_sweps()
    out = {}
    models = set()
    for iid in order:
        it = items[iid]
        cat = it["categories"][0] if it["categories"] else "Other"
        d = {"name": it["name"], "desc": it["desc"], "icon": icon_path(it["icon_src"]), "stack": it["stack"],
             "category": cat, "recipe": it.get("recipe", []), "craftable": it["craftable"],
             "craft_amount": it["craft_amount"], "craft_time": it["craft_time"], "tier": it["tier"],
             "material": it["material"], "type": "item"}
        if it.get("weapon"):
            sw = sweps.get(it["weapon"], {})
            vm = sw.get("ViewModel", "")
            wm = sw.get("WorldModel", "") or (it["model"] or "")
            d["swep"] = it["weapon"]
            d["viewmodel"] = vm
            d["worldmodel"] = wm
            base_chain = it["weapon"]
            kind = "gun"
            b = sweps.get(it["weapon"], {}).get("Base", "")
            names = [it["weapon"], b, sweps.get(b, {}).get("Base", "")]
            if any("melee" in (n or "") for n in names) or it["weapon"] in ("rust_rock",):
                kind = "melee"
            if any("explosive" in (n or "") for n in names):
                kind = "throw"
            if any("medical" in (n or "") for n in names):
                kind = "medical"
            if any("shotgun" in (n or "") for n in names):
                kind = "shotgun"
            if "bow" in it["weapon"] or "crossbow" in it["weapon"]:
                kind = "bow"
            if it["weapon"] in ("rust_rpg", "rust_grenadelauncher"):
                kind = "launcher"
            if it["weapon"] in ("rust_buildingplan", "rust_hammer", "rust_keycard", "rust_wiretool", "rust_supplysignal", "rust_hands"):
                kind = "tool"
            d["type"] = "weapon"
            d["kind"] = kind
            for k_src, k_dst in [("Damage", "damage"), ("RPM", "rpm"), ("ClipSize", "clip"), ("Bullets", "bullets"), ("AimCone", "cone"),
                                 ("IronSightsPos", "ads"), ("IronSightsFOV", "ads_fov"), ("ViewModelFOV", "vm_fov"), ("Range", "range"),
                                 ("ShootSound", "shoot_sound"), ("SwingSound", "swing_sound"), ("HitSound", "hit_sound"),
                                 ("AttackRate", "attack_rate"), ("AttackDelay", "attack_delay"), ("Radius", "radius"), ("Delay", "fuse"),
                                 ("HP", "heal"), ("Healing", "healing"), ("UseDelay", "use_delay"), ("Automatic", "auto"),
                                 ("ShellInsertTime", "shell_time"), ("RecoilTable", "recoil"), ("ReloadTime", "reload_time")]:
                if k_src in sw:
                    d[k_dst] = sw[k_src]
            if sw.get("AmmoTypes"):
                d["ammo_types"] = sw["AmmoTypes"]
            if it.get("clip"):
                d["clip"] = it["clip"]
            if vm:
                models.add(vm)
            if wm:
                models.add(wm)
        if it.get("attire"):
            d["type"] = "attire_reg"
            d["attire"] = it["attire"]
        if cat == "Ammo":
            d["type"] = "ammo"
        if cat == "Medical" and d["type"] == "item":
            d["type"] = "medical_item"
        if cat == "Food" or it["file"] == "consumable":
            d["type"] = "food"
        out[iid] = d
    # оружие из TFA-аддона (scripts/lua/weapons), которого нет в реестре gRust
    W = "models/weapons/darky_m/rust/"
    extra = {
        "l96_rifle": ("L96 Rifle", "Снайперская винтовка с продольно-скользящим затвором.", "materials/items/weapons/l96.png", "gun", "c_l96", "w_l96",
                      {"damage": 80, "rpm": 150, "clip": 5, "auto": False, "ads": [-4.699, -1.5, 3.319], "shoot_sound": "darky_rust.l96-attack", "ammo_types": ["556_rifle_ammo"]}),
        "eoka_pistol": ("Eoka Pistol", "Самодельный пистолет на один выстрел дробью.", "materials/items/weapons/eoka.png", "gun", "c_eoka", "w_eoka",
                        {"damage": 180, "bullets": 15, "rpm": 30, "clip": 1, "auto": False, "ads": [-4.511, 0.019, 3.92], "shoot_sound": "darky_rust.eoka-pistol-attack", "ammo_types": ["handmade_shell"]}),
        "compound_bow": ("Compound Bow", "Составной лук: мощнее охотничьего.", "ui/items/bow.compound.png", "bow", "c_compoundbow", "w_compoundbow",
                         {"damage": 50, "rpm": 60, "clip": 1, "ammo_types": ["wooden_arrow"]}),
        "longsword": ("Longsword", "Длинный меч.", "ui/items/longsword.png", "melee", "c_Longsword", "w_Longsword", {"damage": 75, "attack_rate": 30, "range": 1.8}),
        "mace": ("Mace", "Булава.", "ui/items/mace.png", "melee", "c_Mace", "w_Mace", {"damage": 50, "attack_rate": 30, "range": 1.6}),
        "machete": ("Machete", "Мачете.", "ui/items/machete.png", "melee", "c_Machete", "w_Machete", {"damage": 35, "attack_rate": 60, "range": 1.6}),
        "pitchfork": ("Pitchfork", "Вилы.", "ui/items/pitchfork.png", "melee", "c_pitchfork", "w_pitchfork", {"damage": 40, "attack_rate": 40, "range": 2.0}),
        "bone_knife": ("Bone Knife", "Костяной нож.", "ui/items/knife.bone.png", "melee", "c_boneknife", "w_boneknife", {"damage": 35, "attack_rate": 68, "range": 1.5}),
    }
    for iid, (nm, ds, ic, kind, vm, wm, st) in extra.items():
        src = ic if ic.startswith("materials/") else "materials/ui/zohart/items/" + ic.split("/")[-1]
        icon = icon_path(src)
        if icon is None:
            rp = f"{R}/icons/{ic}"
            if os.path.exists(rp):
                os.makedirs(ICON_DIR, exist_ok=True)
                shutil.copy(rp, f"{ICON_DIR}/{os.path.basename(rp)}")
                icon = "res://assets/icons/items/" + os.path.basename(rp)
        d = {"name": nm, "desc": ds, "icon": icon, "stack": 1, "category": "Weapons", "recipe": [["metal_fragments", 50]],
             "craftable": True, "craft_amount": 1, "craft_time": 0.0, "tier": 1, "material": "Gun", "type": "weapon", "kind": kind,
             "viewmodel": W + vm + ".mdl", "worldmodel": W + wm + ".mdl", "swep": "tfa_" + iid}
        d.update(st)
        out[iid] = d
        order.append(iid)
        models.add(d["viewmodel"]); models.add(d["worldmodel"])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump({"order": order, "items": out}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("items", len(out), "weapons", sum(1 for v in out.values() if v["type"] == "weapon"))
    for m in sorted(models):
        print("MODEL", m)
    missing = [k for k, v in out.items() if not v["icon"]]
    print("no icon:", missing)


if __name__ == "__main__":
    main()
