#!/usr/bin/env python3
"""Build client-patches/patch-Z.MPQ for an Ascension-copy client: stock GlueXML + the stock gameplay DBCs.

usage: build_ascension_client_patch.py <dbc dir> [<GlueXML dir> ...]
  <dbc dir>      a folder with the stock 3.3.5a DBCs (server/runtime/data/dbc after extraction from a stock client)
  <GlueXML dir>  extracted Interface/GlueXML folders from the stock enUS MPQs, oldest first (later ones override).
                 Optional once built: without them the GlueXML from the previous build (client-patches/build-patchZ)
                 is kept and only the DBCs are refreshed.

Why these DBCs: Ascension is classless and its patches replace every client table. Its spell / skill-line / talent
tables no longer tie spells to classes, so a stock 3.3.5 server's trainer lists come up empty and the talent tab is
blank. The client must see the same tables the server uses. Item and creature display tables are deliberately NOT
restored: this project adapts the server's item display ids to the Ascension client instead (server/local).
"""
import os, re, shutil, subprocess, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build = os.path.join(root, "client-patches", "build-patchZ")
if len(sys.argv) < 2:
    sys.exit(__doc__)
dbc_src = sys.argv[1]
glue_dirs = sys.argv[2:]

glue = os.path.join(build, "Interface", "GlueXML")
dbc = os.path.join(build, "DBFilesClient")
if glue_dirs:
    shutil.rmtree(glue, ignore_errors=True)
    os.makedirs(glue)
    for d in glue_dirs:
        for f in os.listdir(d):
            shutil.copy(os.path.join(d, f), glue)
elif not os.path.isdir(glue) or not os.listdir(glue):
    sys.exit("no GlueXML in %s - pass the stock GlueXML folders on the first build" % build)

# class tables (character creation), spells, skill lines, talents, glyphs, stat curves
WANT = re.compile(r"^(ChrClasses|CharBaseInfo|Spell[A-Za-z]*|Skill[A-Za-z]*|Talent[A-Za-z]*|Glyph[A-Za-z]*|gt[A-Za-z]*)\.dbc$")
shutil.rmtree(dbc, ignore_errors=True)
os.makedirs(dbc)
names = sorted(f for f in os.listdir(dbc_src) if WANT.match(f))
for f in names:
    shutil.copy(os.path.join(dbc_src, f), dbc)
print("DBCs (%d): %s" % (len(names), " ".join(names)))


def add_class_combos(dbc_path, combos_path):
    """Append race/class pairs from class-combos.txt to CharBaseInfo.dbc (2 one-byte fields per record)."""
    import struct
    if not os.path.exists(combos_path):
        return
    combos = []
    for line in open(combos_path, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if line:
            r, c = line.split()
            combos.append((int(r), int(c)))
    if not combos:
        return
    with open(dbc_path, "rb") as f:
        magic, n, fields, rs, ss = struct.unpack("<4sIIII", f.read(20))
        data = bytearray(f.read(n * rs))
        strings = f.read(ss)
    assert magic == b"WDBC" and fields == 2 and rs == 2, "unexpected CharBaseInfo.dbc layout"
    have = {tuple(data[i * 2:i * 2 + 2]) for i in range(n)}
    added = [rc for rc in combos if rc not in have]
    for r, c in added:
        data += bytes([r, c])
    with open(dbc_path, "wb") as f:
        f.write(struct.pack("<4sIIII", magic, n + len(added), fields, rs, ss))
        f.write(data)
        f.write(strings)
    print("CharBaseInfo.dbc: %d records, added %s" % (n + len(added), added or "nothing new"))


add_class_combos(os.path.join(dbc, "CharBaseInfo.dbc"), os.path.join(root, "client-patches", "class-combos.txt"))

out = os.path.join(root, "client-patches", "patch-Z.MPQ")
subprocess.check_call([sys.executable, os.path.join(root, "tools", "mpq_writer.py"), out, build])
subprocess.check_call([sys.executable, os.path.join(root, "tools", "mpq_verify.py"), out, build])
print("built", out)
