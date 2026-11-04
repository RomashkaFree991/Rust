"""Sort gRust (Workshop content + latest GitHub code) and rust_highland into an empty repo."""
import os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import organize as O
S, out = sys.argv[1:]
SOURCES = [  # (id, dir, game prefix to prepend, prefix to strip) — later wins
    ("3636622724", "grust", "", "gamemodes/rust/content/"),
    ("github:Down-s/gRust", "downs/repo", "gamemodes/rust/", ""),
    ("3636630095", "map", "", ""),
]
RENAME = [("hazmat_grust", "hazmat_v2"), ("scientist_grust", "scientist_v2"), ("grustplus", "plus"),
          ("grust_logo", "main_logo"), ("grust_particle", "main_particle"), ("/grust.fgd", "/gamemode.fgd"),
          ("grust-roboto", "roboto"), ("/grust/", "/v2/")]
def target(game):
    if game.startswith("maps/"):
        return game
    t = O.target(game)
    for a, b in RENAME: t = t.replace(a, b)
    return t
seen, by_game = {}, {}
for sid, folder, add, strip in SOURCES:
    root = os.path.join(S, folder)
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        for f in files:
            full = os.path.join(d, f)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if strip and rel.startswith(strip): rel = rel[len(strip):]
            game = add + rel
            dst = by_game.get(game)
            if dst is None:
                dst = target(game)
                if dst in seen:  # different source file, same sorted spot: keep both
                    head, tail = dst.rsplit("/", 1); dst = f"{head}/v2/{tail}"
                    assert dst not in seen, dst
            by_game[game] = dst; seen[dst] = (sid, game, full)
for dst, (sid, game, full) in seen.items():
    os.makedirs(os.path.dirname(os.path.join(out, dst)), exist_ok=True)
    shutil.copyfile(full, os.path.join(out, dst))
with open(os.path.join(out, "manifest.csv"), "w", encoding="utf-8") as m:
    m.write("path,original_path,source\n")
    for dst in sorted(seen):
        sid, game, _ = seen[dst]; m.write(f'"{dst}","{game}",{sid}\n')
print(len(seen), "files")
