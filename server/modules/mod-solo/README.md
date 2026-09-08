# mod-solo

The few things this project adds to an otherwise stock world. Built as a normal AzerothCore module: `clone-core.ps1`
links this folder into `azerothcore\modules\mod-solo`, `build-core.cmd` compiles it, and `solo.cmd configs` (also
`start` and `first-run`) applies `sql\world\*.sql`. Everything is stock-client safe: no DBC or client patch needed.

| Piece | What | Source |
|---|---|---|
| **GM Toolkit** | Item every GM-level account gets on login. Right-click: teleports (cities, starting zones, dungeons and raids, back to where I was), GM powers (god, no cast time, no cooldowns, infinite power, fly, speed, water walking, GM mode, visibility, all flight paths, explore all, everything on/off) and character helpers (heal, revive, clear cooldowns, level +1/+5/+10, max weapon skills, repair, 100 gold, 5 XP potions). Lost it? Relog, or `.additem 3878`. | `src\SoloGMToolkit.cpp` |
| **Potion of Experience** | +100% experience from every source (kills, quests, exploration, battlegrounds) for one hour per potion; drink up to five for +500%. Each potion adds a stack and restarts the hour. Buff icon is borrowed from a stock spell (Brewfest Enthusiast), so its tooltip text is the stock one; the chat line when you drink states the real bonus. More: `.additem 2461 5`. | `src\SoloXPPotion.cpp` |

Item ids are stock "Deprecated" entries (3878, 2461) renamed by `sql\world\mod-solo-items.sql`, so any 3.3.5 client
already knows them.

| **Paladin mounts for trainer-less races** | The Warhorse (13819) and Charger (23214) spells are race-locked in the skill tables, so no trainer offers them to an Undead paladin. Undead paladins learn them on login / level-up at 20 and 40 (riding skill still comes from the riding trainer in Brill). | `src\SoloPaladinMounts.cpp` |
| **Forsaken paladin trainers** | Aldric the Redeemed (Deathknell, starter spells), Sister Ophelia Blackthorn (Brill) and Lord Corvane Duskbane (Undercity), full Horde paladin list, standing next to the warrior trainers. Copies of the Blood Elf trainers with Forsaken models. | `sql\world\mod-solo-paladin-trainers.sql` |
| **Quest item drop rate** | Every quest item, from every loot source (creatures, chests, nodes, containers), drops `Solo.QuestDropRate` times as often; entries already at 100% stay there. Default 3 (`"QuestDropRate"` in settings.json / settings.local.json, or the World tab of Bot Settings). `.reload config` applies a change live. | `src\SoloQuestDrops.cpp` |
| **Early class spells** | Spells every character of a class gets at a level, without a trainer or talent point: paladins learn Crusader Strike (35395) at level 8. Granted on login and level-up (bots included) and re-granted after a talent reset. Add rows to the table at the top of the source. | `src\SoloClassSpells.cpp` |
| **Extra race/class combos** | Undead Paladin (never existed in retail). Server side: start position, action bar and starting gear in `sql\world\mod-solo-class-combos.sql` (stats and spells need nothing on this core). Client side: the combo is added to `CharBaseInfo.dbc` inside patch-Z from `client-patches\class-combos.txt`, one `race class` pair per line; add a line, rebuild patch-Z, add the matching SQL rows. Mounts: Summon Warhorse gives a horse. | `sql\world\mod-solo-class-combos.sql` |
