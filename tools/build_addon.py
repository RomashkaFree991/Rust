"""Собирает файлы репозитория обратно в рабочую структуру аддона Garry's Mod.

usage: python3 tools/build_addon.py <папка_назначения>
Например: python3 tools/build_addon.py "C:/.../GarrysMod/garrysmod/addons/rust_weapons"
"""
import csv, os, shutil, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1]
with open(os.path.join(root, "manifest.csv"), encoding="utf-8") as f:
    rows = list(csv.DictReader(f))
for r in rows:
    dst = os.path.join(out, r["original_path"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(os.path.join(root, r["path"]), dst)
print(f"{len(rows)} файлов скопировано в {out}")
