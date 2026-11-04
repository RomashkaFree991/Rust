"""Sort unpacked Garry's Mod Rust addons into asset-type folders.

usage: organize.py <scratch_root> <out_repo>

Sources are applied in order; when two sources ship the same game path, the later one wins
(same thing the game does when all are mounted). If two different game paths would land on
the same repo path, the later one gets its source tag inserted to keep both.
"""
import os, re, shutil, sys

# (workshop id, folder under scratch root, prefix of game files inside it)
SOURCES = [
    ("2529785777", "ex/2529785777", ""),   # darky: Rust Firearms
    ("2529802557", "ex/2529802557", ""),   # darky: Rust Explosives
    ("2782092042", "ex/2782092042", ""),   # darky: Rust Melee
    ("2395395483", "ex/2395395483", ""),   # darky: Hazmat
    ("2467846835", "ex/2467846835", ""),   # darky: Scientist
    ("2659607667", "ex/2659607667", ""),   # darky: Nomad
    ("2659610837", "ex/2659610837", ""),   # darky: Spacesuit
    ("2743974910", "ex/2743974910", ""),   # darky: Arctic hazmat
    ("2815506728", "ex/2815506728", ""),   # darky: c_hands
    ("3636622724", "grust", "gamemodes/rust/content/"),  # gRust gamemode (content + code)
    ("3188160030", "zm", ""),              # zohart GRust Server Content - Models
    ("3188161638", "zmat", ""),            # zohart GRust Server Content - Materials
    ("3188165440", "zsnd", ""),            # zohart GRust Server Content - Sounds
]
TAGS = {"3636622724": "grust", "3188160030": "zohart", "3188161638": "zohart", "3188165440": "zohart"}

MODEL_EXT = re.compile(r"\.(mdl|vvd|phy|dx80\.vtx|dx90\.vtx|sw\.vtx|vtx)$")
AUTHORS = {"darky_m", "darky_m&bypolat", "zohart", "grust", "vanguard", "wystan", "rust", "rust_mp3"}
CHAR_TEX = {"hazmat", "archazmat", "nomad", "scientist", "spacesuit", "chands", "attire"}
RENAME = {"rust_distant": "distant"}


def strip(dirs):
    return [RENAME.get(d, d) for d in dirs if d.lower() not in AUTHORS]


def join(*parts):
    return "/".join(p for p in parts if p)


def model_target(p, name):
    s = MODEL_EXT.sub("", name)
    dirs = p[:-1]
    if dirs[:2] == ["models", "player"]:
        kind = "arms" if s.endswith("_arms") or s.startswith("c_arms") else "models"
        return f"characters/{kind}/{s}/{name}"
    vanguard_top = dirs == ["models", "grust", "vanguard"]
    if "attire" in dirs or vanguard_top:
        if s.endswith("_hands"):
            return f"characters/arms/{s[:-6]}/{name}"
        return f"characters/{'models' if vanguard_top else 'clothing'}/{s}/{name}"
    if s.startswith("c_"):
        return f"animations/viewmodels/{s[2:]}/{name}"
    if "weapons" in dirs or "rust_weapons" in dirs:
        if s.startswith(("mod_", "w_mod_")):
            return f"models/attachments/{s.removeprefix('w_')}/{name}"
        if s.startswith("w_"):
            return f"models/weapons/{s[2:]}/{name}"
        return f"models/ammo/{s}/{name}"
    return join("models/world", *strip(dirs[1:]), name)


def target(rel):
    p = rel.split("/")
    name = p[-1]
    ext = name.rsplit(".", 1)[-1].lower()
    if MODEL_EXT.search(name):
        return model_target(p, name)
    if p[0] == "materials":
        sub = p[1:-1]
        if sub and sub[0] in ("particle", "particles"):
            return join("particles/textures", *strip(sub[1:]), name)
        if sub and sub[0] in ("ui", "vgui", "icons", "items", "entities"):
            return join("icons", sub[0], *strip(sub[1:]), name)
        if sub and sub[0] == "models":
            rest = sub[1:]
            if "weapons" in rest or "rust_weapons" in rest:
                return join("textures/weapons", *strip(rest), name)
            if CHAR_TEX & set(rest) or rest[:2] == ["grust", "vanguard"]:
                return join("textures/characters", *[d for d in strip(rest) if d != "attire"], name)
            return join("textures/world", *strip(rest), name)
        return join("textures/effects", *strip(sub), name)
    if p[0] == "sound":
        return join("sounds", *strip(p[1:-1]), name)
    if ext == "pcf":
        return "particles/" + name
    if ext == "ttf":
        return "ui/fonts/" + name
    return "scripts/" + rel  # lua, gamemode code, configs


def main(src, out):
    seen = {}   # repo path -> (id, game path, file)
    by_game = {}
    for wid, folder, prefix in SOURCES:
        root = os.path.join(src, folder)
        for d, _, files in os.walk(root):
            for f in files:
                full = os.path.join(d, f)
                rel = os.path.relpath(full, root).replace(os.sep, "/")
                game = rel[len(prefix):] if prefix and rel.startswith(prefix) else rel
                if game in by_game:
                    dst = by_game[game]
                else:
                    dst = target(game)
                    if dst in seen and seen[dst][1] != game:
                        head, tail = dst.rsplit("/", 1)
                        dst = f"{head}/{TAGS.get(wid, wid)}/{tail}"
                    by_game[game] = dst
                seen[dst] = (wid, game, full)
    for dst, (wid, game, full) in seen.items():
        os.makedirs(os.path.dirname(os.path.join(out, dst)), exist_ok=True)
        shutil.copyfile(full, os.path.join(out, dst))
    with open(os.path.join(out, "manifest.csv"), "w", encoding="utf-8") as m:
        m.write("path,original_path,workshop_id\n")
        for dst in sorted(seen):
            wid, game, _ = seen[dst]
            m.write(f'"{dst}","{game}",{wid}\n')
    print(len(seen), "files")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
