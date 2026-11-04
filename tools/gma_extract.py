import os, struct, sys

def rstr(f):
    b = bytearray()
    while (c := f.read(1)) and c != b"\0":
        b += c
    return b.decode("utf-8", "replace")

def extract(path, out):
    with open(path, "rb") as f:
        assert f.read(4) == b"GMAD"
        ver = f.read(1)[0]
        f.read(16)
        if ver > 1:
            while rstr(f):
                pass
        name, desc, author = rstr(f), rstr(f), rstr(f)
        f.read(4)
        entries = []
        while struct.unpack("<I", f.read(4))[0]:
            n = rstr(f)
            size, = struct.unpack("<q", f.read(8))
            f.read(4)
            entries.append((n, size))
        for n, size in entries:
            n = n.replace("\\", "/")
            dst = os.path.normpath(os.path.join(out, n))
            if not dst.startswith(os.path.abspath(out) + os.sep):
                raise ValueError("unsafe path: " + n)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as o:
                o.write(f.read(size))
        print(f"{name}: {len(entries)} files", file=sys.stderr)
        return name, desc

if __name__ == "__main__":
    extract(sys.argv[1], os.path.abspath(sys.argv[2]))
