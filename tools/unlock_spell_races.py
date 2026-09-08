#!/usr/bin/env python3
"""Clear the race lock on chosen spells in SkillLineAbility.dbc.

The client's spellbook only lists a known spell if a SkillLineAbility row says the character's race and class may
have it; the server uses the same rows to decide what a trainer offers. The paladin mount spells are locked to the
Alliance paladin races (mask 1029) and the Thalassian pair to Blood Elves, so an Undead paladin who has learned
Summon Warhorse (mod-solo teaches it at 20) does not see it in the book. Setting RaceMask to 0 on those rows makes
the book show them to any race of the class.

Edits the file in place (a .stock copy is kept next to it). Run it on server\runtime\data\dbc\SkillLineAbility.dbc:
the server reads that copy, and build_ascension_client_patch.py copies it into patch-Z for the client.

usage: unlock_spell_races.py <SkillLineAbility.dbc> <spell id> [<spell id> ...]
"""
import os, shutil, struct, sys

if len(sys.argv) < 3:
    sys.exit(__doc__)
path = sys.argv[1]
spells = {int(x) for x in sys.argv[2:]}
if not os.path.exists(path + ".stock"):
    shutil.copy(path, path + ".stock")
with open(path, "rb") as f:
    magic, n, fields, rs, ss = struct.unpack("<4sIIII", f.read(20))
    data = bytearray(f.read(n * rs))
    strings = f.read(ss)
assert magic == b"WDBC" and fields == 14, "unexpected SkillLineAbility layout"
changed = 0
for i in range(n):
    spell, race = struct.unpack_from("<II", data, i * rs + 8)
    if spell in spells and race != 0:
        struct.pack_into("<I", data, i * rs + 12, 0)
        changed += 1
with open(path, "wb") as f:
    f.write(struct.pack("<4sIIII", magic, n, fields, rs, ss))
    f.write(data)
    f.write(strings)
print("SkillLineAbility.dbc: race lock cleared on %d rows for spells %s" % (changed, sorted(spells)))
