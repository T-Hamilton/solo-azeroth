import mpyq, os, sys
mpq, src = sys.argv[1], sys.argv[2]
a = mpyq.MPQArchive(mpq)
files = a.files
print("mpyq sees", len(files), "files; sample:", [f.decode() for f in files[:3]])
ok = checked = 0
for f in files:
    rel = f.decode().replace("\\", "/")
    p = os.path.join(src, rel)
    if not os.path.exists(p):
        continue
    checked += 1
    if a.read_file(f) == open(p, "rb").read():
        ok += 1
    else:
        print("MISMATCH", rel)
print("byte-identical read-back:", ok, "of", checked)
_al = a.read_file(b"Interface\GlueXML\AccountLogin.lua")
if _al: print("AccountLogin.lua has DefaultServerLogin:", b"DefaultServerLogin" in _al)
