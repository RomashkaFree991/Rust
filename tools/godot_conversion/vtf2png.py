import sys; sys.argv[0]="blender"
import os; sys.path.insert(0,'/root/.config/blender/5.2/scripts/addons'); 
import bpy, addon_utils
addon_utils.enable("SourceIO", default_set=True)
from SourceIO.library.source1.vtf import load_texture
from SourceIO.library.utils import FileBuffer
import numpy as np
args = sys.argv[sys.argv.index('--')+1:]
for src, dst in zip(args[::2], args[1::2]):
    rgba, h, w = load_texture(FileBuffer(src))
    rgba = np.asarray(rgba, dtype=np.float32).reshape(-1)
    if rgba.max() > 1.0: rgba = rgba / 255.0
    img = bpy.data.images.new("t", w, h, alpha=True)
    img.pixels.foreach_set(rgba)
    img.filepath_raw = dst; img.file_format = 'PNG'; img.save()
    print("SAVED", dst, w, h)
