"""Give the extra race/class combinations their missing skill lines in the server's SkillRaceClassInfo.dbc.

Why: the core checks every skill a character has against SkillRaceClassInfo.dbc - at login (Player::_LoadSkills),
when validating skill-teaching spells (CheckSkillLearnedBySpell) and when building trainer lists. Blizzard wrote
some class skill rows per race: the Paladin "Swords" (43) rows only list Human/Dwarf/Draenei and Blood Elf, while
Maces and Two-Handed Swords got an all-races row. A combo that never existed in retail (our Undead paladin) has no
Swords row, so the server deletes the skill at every login ("has skill (43) that is invalid for the race/class
combination ... Will be deleted"), the weapon master never offers it, and 1H swords cannot be equipped even though
the proficiency spell itself is fine.

For each combo in class-combos.txt this appends one row per skill that the class's stock races have but the new
race does not (weapon, armor, class and secondary skills; racial and language skills are race-bound on purpose and
left alone), copying Flags/MinLevel/SkillTierID/SkillCostIndex from the class's existing row for that skill.
Idempotent: skills already covered are skipped. The first time the file changes a .bak of the original is kept.

Usage: python tools\\fix_skill_race_class.py server\\runtime\\data\\dbc client-patches\\class-combos.txt [--dry-run]

The server reads the DBC at startup, so restart the worldserver afterwards, then rebuild patch-Z
(tools\\build_ascension_client_patch.py packs Skill*.dbc) so the client's skill window matches.
"""
import os
import shutil
import struct
import sys

SKIP_CATEGORIES = {9, 10}    # SkillLine.dbc categoryId: 9 = racial, 10 = languages


def read_dbc(path):
    data = open(path, "rb").read()
    magic, n, fields, rs, ss = struct.unpack_from("<4sIIII", data, 0)
    assert magic == b"WDBC", path
    body = data[20:20 + n * rs]
    strings = data[20 + n * rs:20 + n * rs + ss]
    return n, fields, rs, body, strings


def rows_u32(body, n, fields, rs):
    return [list(struct.unpack_from("<%dI" % fields, body, i * rs)) for i in range(n)]


def load_combos(path):
    combos = []
    for line in open(path, encoding="utf8"):
        line = line.split("#", 1)[0].strip()
        if line:
            race, cls = line.split()
            combos.append((int(race), int(cls)))
    return combos


def covers(row, race, cls):
    """Mirror GetSkillRaceClassInfo(): a zero mask means any race / any class."""
    race_mask, class_mask = row[2], row[3]
    return (not race_mask or race_mask & (1 << (race - 1))) and (not class_mask or class_mask & (1 << (cls - 1)))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry_run = "--dry-run" in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    dbc_dir, combos_path = args
    combos = load_combos(combos_path)

    # SkillLine.dbc: id, categoryId, ..., name (field 3 = string offset)
    n, fields, rs, body, strings = read_dbc(os.path.join(dbc_dir, "SkillLine.dbc"))
    category, name = {}, {}
    for r in rows_u32(body, n, fields, rs):
        category[r[0]] = r[1]
        name[r[0]] = strings[r[3]:strings.index(b"\0", r[3])].decode("utf8", "replace")

    # CharBaseInfo.dbc: the stock (race, class) pairs, two one-byte fields per record
    n, fields, rs, body, _ = read_dbc(os.path.join(dbc_dir, "CharBaseInfo.dbc"))
    assert fields == 2 and rs == 2, "unexpected CharBaseInfo.dbc layout"
    stock = {(body[i * 2], body[i * 2 + 1]) for i in range(n)} - set(combos)

    path = os.path.join(dbc_dir, "SkillRaceClassInfo.dbc")
    n, fields, rs, body, strings = read_dbc(path)
    assert fields == 8 and rs == 32, "unexpected SkillRaceClassInfo.dbc layout"
    rows = rows_u32(body, n, fields, rs)   # ID, SkillID, RaceMask, ClassMask, Flags, MinLevel, SkillTierID, SkillCostIndex
    next_id = max(r[0] for r in rows) + 1

    by_skill = {}
    for r in rows:
        by_skill.setdefault(r[1], []).append(r)

    added = []
    for race, cls in combos:
        ref_races = [r for (r, c) in stock if c == cls]
        for skill, skill_rows in sorted(by_skill.items()):
            if category.get(skill) in SKIP_CATEGORIES:
                continue
            if any(covers(r, race, cls) for r in skill_rows):
                continue
            if not any(covers(r, ref, cls) for r in skill_rows for ref in ref_races):
                continue
            template = next((r for r in skill_rows if r[3] & (1 << (cls - 1))), skill_rows[0])
            new = [next_id, skill, 1 << (race - 1), 1 << (cls - 1), template[4], template[5], template[6], template[7]]
            rows.append(new)
            added.append(new)
            next_id += 1
            print("race %d class %d: + skill %d %s (row %d, copied from row %d)" % (race, cls, skill, name.get(skill, "?"), new[0], template[0]))

    if not added:
        print("SkillRaceClassInfo.dbc: every combo already has its skill rows, nothing to add")
        return
    if dry_run:
        print("dry run: %d row(s) would be added, file not written" % len(added))
        return

    backup = path + ".bak"
    if not os.path.exists(backup):
        shutil.copy(path, backup)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sIIII", b"WDBC", len(rows), fields, rs, len(strings)))
        for r in rows:
            out.write(struct.pack("<8I", *r))
        out.write(strings)
    print("SkillRaceClassInfo.dbc: %d rows (+%d); original kept as %s" % (len(rows), len(added), os.path.basename(backup)))


if __name__ == "__main__":
    main()
