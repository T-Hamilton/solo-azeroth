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
