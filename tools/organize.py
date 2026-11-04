"""Sort extracted GMod addon files into category folders.

usage: organize.py <extracted_root> <out_repo>
Packs are applied oldest -> newest, so for identical paths the newer pack wins.
"""
import os, re, shutil, sys

PACKS = ["2529785777", "2529802557", "2782092042"]  # firearms, explosives, melee (oldest -> newest)
MODEL_EXT = re.compile(r"\.(mdl|vvd|phy|dx80\.vtx|dx90\.vtx|sw\.vtx|vtx)$")

def stem(name):
    return MODEL_EXT.sub("", name)

def target(rel):
    p = rel.split("/")
    name = p[-1]
    if p[0] == "models":
        s = stem(name)
        if s.startswith("c_"):
            return f"animations/viewmodels/{s[2:]}/{name}"
        if s.startswith("w_mod_") or s.startswith("mod_"):
            return f"models/attachments/{s.removeprefix('w_')}/{name}"
        if s.startswith("w_"):
            return f"models/weapons/{s[2:]}/{name}"
        return f"models/ammo/{s}/{name}"
    if p[0] == "materials":
        if p[1] == "models":                        # materials/models/darky_m/rust_weapons/<w>/...
            return "textures/weapons/" + "/".join(p[4:])
        if p[1] == "particle":
            return "particles/textures/" + name
        if p[1] == "entities":
            return "icons/spawnmenu/" + name
        if p[1] == "vgui":
            return {"hud": "icons/hud/", "entities": "icons/attachments/"}[p[2]] + name
    if p[0] == "particles":
        return "particles/" + name
    if p[0] == "sound":                             # sound/weapons/<dir>/<file>
        sub = {"rust_mp3": "weapons", "rust": "loops", "rust_distant": "distant"}.get(p[2], p[2])
        return f"sounds/{sub}/" + "/".join(p[3:])
    if p[0] == "lua":
        return rel
    raise ValueError("unmapped: " + rel)

def main(src, out):
    seen = {}
    for pack in PACKS:
        root = os.path.join(src, pack)
        for d, _, files in os.walk(root):
            for f in files:
                rel = os.path.relpath(os.path.join(d, f), root).replace(os.sep, "/")
                dst = target(rel)
                if dst in seen:
                    print(f"override {dst}: {seen[dst][0]} -> {pack}")
                seen[dst] = (pack, rel)
                full = os.path.join(out, dst)
                os.makedirs(os.path.dirname(full), exist_ok=True)
                shutil.copyfile(os.path.join(d, f), full)
    with open(os.path.join(out, "manifest.csv"), "w", encoding="utf-8") as m:
        m.write("path,original_path,workshop_id\n")
        for dst in sorted(seen):
            pack, rel = seen[dst]
            m.write(f'"{dst}","{rel}",{pack}\n')
    print(len(seen), "files")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
