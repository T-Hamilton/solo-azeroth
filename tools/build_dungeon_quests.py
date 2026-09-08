#!/usr/bin/env python3
"""Build the dungeon -> quest-id map for the SoloDungeonQuests addon, straight from the world DB.

A quest counts as "related to a dungeon" when anything it needs is inside that dungeon's map:
  - a kill / interact objective on a creature or gameobject that spawns in the map, or
  - a required drop item that a creature in the map drops, or
  - the quest is handed out by / turned in to a creature or gameobject in the map.

Outputs:
  server/modules/mod-solo/sql/world/mod-solo-dungeon-quests.sql  (world table solo_dungeon_quests, read by the GM
      Toolkit's "Dungeon quests" menu; applied by solo.cmd configs/start, picked up by `.reload config`)
  client-addons/SoloDungeonQuests/DungeonQuestsData.lua           (the same map for the optional /dq addon)
Run any time the world DB changes; it only rewrites those two files.
"""
import json, os, subprocess, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = json.load(open(os.path.join(ROOT, "server", "settings.json"), encoding="utf-8-sig"))
loc = os.path.join(ROOT, "server", "settings.local.json")
if os.path.exists(loc):
    S.update(json.load(open(loc, encoding="utf-8-sig")))
MYSQL = os.path.join(ROOT, "server", "mysql", "mysql-8.4.0-winx64", "bin", "mysql.exe")
DB = "%s_world" % S["DbPrefix"]

# name, map id, expansion tag, level hint (for display order/label)
DUNGEONS = [
    ("Ragefire Chasm", 389, "Classic", 15),
    ("Wailing Caverns", 43, "Classic", 18),
    ("The Deadmines", 36, "Classic", 18),
    ("Shadowfang Keep", 33, "Classic", 20),
    ("Blackfathom Deeps", 48, "Classic", 22),
    ("The Stockade", 34, "Classic", 24),
    ("Gnomeregan", 90, "Classic", 28),
    ("Razorfen Kraul", 47, "Classic", 30),
    ("Scarlet Monastery", 189, "Classic", 34),
    ("Razorfen Downs", 129, "Classic", 40),
    ("Uldaman", 70, "Classic", 42),
    ("Zul'Farrak", 209, "Classic", 45),
    ("Maraudon", 349, "Classic", 48),
    ("Sunken Temple", 109, "Classic", 52),
    ("Blackrock Depths", 230, "Classic", 55),
    ("Blackrock Spire", 229, "Classic", 57),
    ("Dire Maul", 429, "Classic", 58),
    ("Stratholme", 329, "Classic", 60),
    ("Scholomance", 289, "Classic", 60),
    ("Hellfire Ramparts", 543, "Burning Crusade", 60),
    ("The Blood Furnace", 542, "Burning Crusade", 61),
    ("The Slave Pens", 547, "Burning Crusade", 62),
    ("The Underbog", 546, "Burning Crusade", 63),
    ("Mana-Tombs", 557, "Burning Crusade", 64),
    ("Auchenai Crypts", 558, "Burning Crusade", 65),
    ("Old Hillsbrad Foothills", 560, "Burning Crusade", 66),
    ("Sethekk Halls", 556, "Burning Crusade", 67),
    ("The Steamvault", 545, "Burning Crusade", 68),
    ("The Shattered Halls", 540, "Burning Crusade", 69),
    ("The Black Morass", 269, "Burning Crusade", 70),
    ("Shadow Labyrinth", 555, "Burning Crusade", 70),
    ("Magisters' Terrace", 585, "Burning Crusade", 70),
    ("Utgarde Keep", 574, "Wrath", 70),
    ("The Nexus", 576, "Wrath", 71),
    ("Azjol-Nerub", 601, "Wrath", 72),
    ("Ahn'kahet: The Old Kingdom", 619, "Wrath", 73),
    ("Drak'Tharon Keep", 600, "Wrath", 74),
    ("The Violet Hold", 608, "Wrath", 75),
    ("Gundrak", 604, "Wrath", 76),
    ("Halls of Stone", 599, "Wrath", 77),
    ("Halls of Lightning", 602, "Wrath", 79),
    ("Utgarde Pinnacle", 575, "Wrath", 80),
    ("The Oculus", 578, "Wrath", 80),
    ("The Culling of Stratholme", 595, "Wrath", 80),
    ("Trial of the Champion", 650, "Wrath", 80),
    ("The Forge of Souls", 632, "Wrath", 80),
    ("Pit of Saron", 658, "Wrath", 80),
    ("Halls of Reflection", 668, "Wrath", 80),
]


def q(sql):
    p = subprocess.run([MYSQL, "-u" + S["DbUser"], "-p" + S["DbPassword"], "-P" + str(S["MySQLPort"]),
                        "-h127.0.0.1", DB, "-N", "-B", "-e", sql],
                       capture_output=True, text=True)
    rows = []
    for line in p.stdout.splitlines():
        if not line.strip():
            continue
        rows.append(line.split("\t"))
    return rows


maps = [d[1] for d in DUNGEONS]
maps_csv = ",".join(str(m) for m in maps)

print("loading spawns and quest links...")
# creature entry -> maps (only dungeon maps)
cre_map = collections.defaultdict(set)
for eid, m in q("SELECT DISTINCT id, map FROM creature WHERE map IN (%s)" % maps_csv):
    cre_map[int(eid)].add(int(m))
go_map = collections.defaultdict(set)
for eid, m in q("SELECT DISTINCT id, map FROM gameobject WHERE map IN (%s)" % maps_csv):
    go_map[int(eid)].add(int(m))

# item linkage, high precision: a required item only ties a quest to a dungeon if the item drops ONLY inside
# instance maps (never in the open world). That keeps quest-specific dungeon drops and drops generic trade goods
# (wool, peacebloom, ore) that merely happen to fall off dungeon trash and would otherwise match every dungeon.
dungeon_set = set(maps)
cre_all_map = collections.defaultdict(set)
for eid, m in q("SELECT DISTINCT id, map FROM creature"):
    cre_all_map[int(eid)].add(int(m))
item_all = collections.defaultdict(set)
for item, ent in q("SELECT DISTINCT Item, Entry FROM creature_loot_template"):
    item_all[int(item)] |= cre_all_map.get(int(ent), set())
item_map = {}
for it, allms in item_all.items():
    dms = allms & dungeon_set
    if dms and allms <= dungeon_set:   # every place it drops is a dungeon
        item_map[it] = dms

# quest -> dungeon maps of a giver/turn-in that lives ONLY inside instances (escort, prisoner, in-dungeon quests),
# using the same exclusivity filter as items so generic city/seasonal quest givers never match.
go_all_map = collections.defaultdict(set)
for eid, m in q("SELECT DISTINCT id, map FROM gameobject"):
    go_all_map[int(eid)].add(int(m))
quest_giver_map = collections.defaultdict(set)
for tbl, is_go in (("creature_queststarter", False), ("creature_questender", False),
                   ("gameobject_queststarter", True), ("gameobject_questender", True)):
    allmap = go_all_map if is_go else cre_all_map
    for ent, quest in q("SELECT id, quest FROM %s" % tbl):
        allms = allmap.get(int(ent), set())
        dms = allms & dungeon_set
        if dms and allms <= dungeon_set:   # the giver exists only inside instances
            quest_giver_map[int(quest)] |= dms

print("scanning quests...")
rows = q("SELECT ID, LogTitle, QuestLevel, MinLevel, RequiredNpcOrGo1, RequiredNpcOrGo2, RequiredNpcOrGo3, "
         "RequiredNpcOrGo4, RequiredItemId1, RequiredItemId2, RequiredItemId3, RequiredItemId4, "
         "RequiredItemId5, RequiredItemId6 FROM quest_template")

by_map = collections.defaultdict(dict)   # map -> {quest_id: title}
import re as _re
JUNK = _re.compile(r"quest test|\[ph\]|\bph\b|template|\bunused\b|\btest\b.*\b(quest|tournament)\b", _re.I)
for r in rows:
    qid = int(r[0]); title = r[1] or ("Quest %s" % qid)
    lvl = int(r[2]); minlvl = int(r[3])
    if not r[1] or JUNK.search(title):   # skip internal / placeholder quests
        continue
    npcs = [int(x) for x in r[4:8]]
    items = [int(x) for x in r[8:14]]
    # content signal only: what you must kill/interact/collect INSIDE the map. Giver/turn-in location is too noisy
    # (seasonal and class-quest NPCs share the instance's outdoor cell), so it is used only to CONFIRM, below.
    related = set(quest_giver_map.get(qid, set()))
    for n in npcs:
        if n > 0:
            related |= cre_map.get(n, set())
        elif n < 0:
            related |= go_map.get(-n, set())
    for it in items:
        if it:
            related |= item_map.get(it, set())
    for m in related:
        by_map[m][qid] = (title, lvl if lvl > 0 else minlvl)

# emit Lua
out_dir = os.path.join(ROOT, "client-addons", "SoloDungeonQuests")
os.makedirs(out_dir, exist_ok=True)
lua = ["-- generated by tools/build_dungeon_quests.py from the world DB. Do not edit by hand.",
       "SoloDungeonQuestsData = {"]
total = 0
for name, m, exp, hint in DUNGEONS:
    quests = by_map.get(m, {})
    if not quests:
        continue
    items = sorted(quests.items(), key=lambda kv: (kv[1][1], kv[0]))
    total += len(items)
    lua.append('  { name = "%s", expansion = "%s", level = %d, quests = {' % (name.replace('"', '\\"'), exp, hint))
    for qid, (title, ql) in items:
        lua.append('    { id = %d, title = "%s", level = %d },' % (qid, title.replace("\\", "\\\\").replace('"', '\\"'), ql))
    lua.append("  } },")
lua.append("}")
open(os.path.join(out_dir, "DungeonQuestsData.lua"), "w", encoding="utf-8").write("\n".join(lua) + "\n")
print("wrote %s: %d dungeons, %d quests total" % (os.path.join(out_dir, "DungeonQuestsData.lua"),
      sum(1 for d in DUNGEONS if by_map.get(d[1])), total))

# emit SQL (world table solo_dungeon_quests for the GM Toolkit menu; idempotent: create, wipe, refill)
def sq(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"

sql = ["-- generated by tools/build_dungeon_quests.py from the world DB. Do not edit by hand.",
       "-- Dungeon -> quest map for the GM Toolkit's \"Dungeon quests\" menu (mod-solo SoloDungeonQuests.cpp).",
       "-- Applied by solo.cmd configs/start; the running server re-reads it on `.reload config`.",
       "CREATE TABLE IF NOT EXISTS `solo_dungeon_quests` (",
       "  `map` SMALLINT UNSIGNED NOT NULL,",
       "  `quest` INT UNSIGNED NOT NULL,",
       "  `dungeon` VARCHAR(64) NOT NULL,",
       "  `expansion` VARCHAR(32) NOT NULL,",
       "  `level_hint` TINYINT UNSIGNED NOT NULL,",
       "  `sort_order` SMALLINT UNSIGNED NOT NULL,",
       "  `title` VARCHAR(255) NOT NULL,",
       "  `quest_level` SMALLINT NOT NULL,",
       "  PRIMARY KEY (`map`, `quest`)",
       ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
       "DELETE FROM `solo_dungeon_quests`;",
       "INSERT INTO `solo_dungeon_quests` (`map`, `quest`, `dungeon`, `expansion`, `level_hint`, `sort_order`, `title`, `quest_level`) VALUES"]
values = []
for order, (name, m, exp, hint) in enumerate(DUNGEONS):
    quests = by_map.get(m, {})
    for qid, (title, ql) in sorted(quests.items(), key=lambda kv: (kv[1][1], kv[0])):
        values.append("(%d, %d, %s, %s, %d, %d, %s, %d)" % (m, qid, sq(name), sq(exp), hint, order, sq(title), ql))
sql.append(",\n".join(values) + ";")
sql_path = os.path.join(ROOT, "server", "modules", "mod-solo", "sql", "world", "mod-solo-dungeon-quests.sql")
open(sql_path, "w", encoding="utf-8").write("\n".join(sql) + "\n")
print("wrote %s: %d rows" % (sql_path, len(values)))
