# Working on Solo Azeroth (notes for the coding agent)

Human-facing docs: `README.md` (what/why), `HOWTO.md` (setup, shortcuts, troubleshooting), `docs/LLM-CHAT.md`,
`docs/CLIENT-SETUP.md`, `server/modules/mod-solo/README.md`, `client-patches/README.md`. Read those first.
`SUMMARY.md` (on disk only, git-ignored) is the chronological working log: every decision, gotcha and open item,
newest at the bottom. Append to it after every change; never commit it.

## Division of labour
The owner does not code. The agent does all code, SQL, config and build work, keeps the public repo tidy, and tells
the owner in plain language what changed and what to test in game. Commit and push after each finished change
(`git add` explicit files only). Never `git add`: `SUMMARY.md`, `server/personalities/personalities.txt`,
`server/personalities/prompts.txt`, the generated `personality_pack*.sql`, anything under `server/local/`, or any
Blizzard/Ascension game data (`client-patches/patch-Z.MPQ`, `client-patches/ghost-paladin/`).

## Layout
- `server/azerothcore` (liyunfan1223 Playerbot branch), `server/modules/` (mod-playerbots, mod-ollama-chat with
  `server/patches/mod-ollama-chat-solo.diff` applied, `mod-solo` = our own module, junctioned into
  `azerothcore/modules`). `server/build` = CMake tree, `server/runtime` = installed binaries, configs, data, logs.
- `server/settings.json` (defaults, committed) + `server/settings.local.json` (owner's values, ignored) ->
  `server/setup/gen_configs.py` renders `runtime/configs/*.conf`. Add a new knob there (WORLD/BOTS/OLLAMA tables),
  never by hand-editing a .conf. The Bot Settings window (`launchers/botsettings.ps1`) writes its values into
  `settings.local.json` under `ConfOverrides`, applied last.
- `server/solo.ps1` / `solo.cmd`: `start`, `stop`, `status`, `configs`, `first-run`, `shortcuts`, `ollama --restart`.
- `tools/soap.py "<gm command>"`: run any GM console command on the live server (SOAP). Use `player learn <name> <id>`
  rather than `learn` (the console has no target). `reload config` applies rate/config changes live.
- Client: an Ascension install copied to `C:\Games\solo-azeroth-client` (see `client-patches/README.md`); our
  `patch-Z.MPQ` is built by `tools/build_ascension_client_patch.py server/runtime/data/dbc` and installed by the Play
  launcher only while the game is closed.

## Ports (this machine)
MySQL 3307, auth 3725, world 8087, SOAP 7880. The sibling project `C:\Users\Rik\coa-rebuild` uses 3306/3724/8085-6:
never touch its processes, DBs or repo from here, and do not run both cores' builds at once.

## Build and restart
- Incremental rebuild of the world server after a mod-solo change (~15 s compile + link):
  `cmake --build server/build --config Release --target worldserver --parallel 12`
  Adding a new .cpp needs the configure step first (same flags as `server/setup/build-core.cmd`). From the Bash tool
  do NOT pass `-- /m:12 /nologo /v:m` (MSYS mangles them into MSB1008); `--parallel 12` alone is fine.
- Install = copy `server/build/bin/Release/worldserver.exe` to `server/runtime/`. The running server locks the exe:
  `tools/soap.py "server shutdown 30"` (players see a countdown), wait for OUR process to exit (match its path - the
  coa-rebuild worldserver also runs), copy, `Unblock-File` the copied exe (Smart App Control otherwise blocks the new
  binary at start), then `server\solo.cmd start` (the .ps1 is blocked by the execution policy when run directly).
  Confirm with `tools/soap.py "server info"` and the mod-solo lines at the top of `server/runtime/logs/Server.log`.
  Each `reload config` rotates that log. Never restart without the owner's explicit go for that restart; he sometimes
  restarts from the Bot Settings window himself, which does NOT install a staged exe.
- SQL for the world DB: `server/modules/mod-solo/sql/world/*.sql` (applied by `solo.cmd configs/start`, must be
  idempotent). Owner-specific rows live in `server/local/*.sql` (ignored).

## Gotchas that cost time before
- Server DBCs are stock 3.3.5a: custom items must reuse stock "Deprecated" item ids; new creature display rows must
  be added to BOTH the client table (patch-Z) and `server/runtime/data/dbc/CreatureDisplayInfo.dbc`.
- Extra race/class combos also need rows in `server/runtime/data/dbc/SkillRaceClassInfo.dbc` (Blizzard wrote e.g. the
  paladin Swords rows per race): without them `Player::_LoadSkills` deletes the skill at every login and the weapon
  master never offers it. `tools/fix_skill_race_class.py` adds them from `client-patches/class-combos.txt` and
  `solo.cmd configs/start` runs it. `ValidateSkillLearnedBySpells` only governs the spell side and is not the fix.
- The Bot Settings window replaces the whole `ConfOverrides` block of `settings.local.json` on every save, so keys
  added there by hand vanish. New knobs go in `gen_configs.py`'s WORLD/BOTS/OLLAMA tables.
- Applying config changes live: worldserver.conf -> `reload config`; mod_ollama_chat.conf -> `ollama reload`;
  playerbots.conf -> `playerbots rndbot reload` (re-runs PlayerbotAIConfig::Initialize; `reload config` does NOT
  re-read it). All three work through `tools/soap.py`. Account/character generation (AddClassAccountPoolSize,
  bot counts) only happens at worldserver start.
- `AiPlayerbot.SelfBotLevel` must stay 1. Bots only log in while a real player is online.
- Heredocs through the PowerShell/Bash tools have mangled backslashes in .ps1/.py before: write those with the
  Write/Edit tools.
- The Ascension client's `ChatChannels.dbc` differs from stock; patch-Z carries the stock one.

## Current state (2026-09-09)
Quest item drop rate x3, quest XP x2, kill XP x3 (all on the Bot Settings World tab). Paladins get Crusader Strike at
level 8 (mod-solo `SoloClassSpells.cpp`). GM Toolkit has "Dungeon quests" (mod-solo `SoloDungeonQuests.cpp`, data in
world table `solo_dungeon_quests` from `tools/build_dungeon_quests.py`; regenerate -> `solo.cmd configs` ->
`.reload config`, no rebuild) and "Pause XP (freeze level)" (mod-solo `SoloXpLock.cpp`: per-character flag in the
characters table `solo_xp_lock`, zeroes every XP source, survives relog/restart). The `/dq` addon in `client-addons/`
is the optional client-side twin of the dungeon-quest menu. The Undead paladin's Swords skill row comes from
`tools/fix_skill_race_class.py` (run by `solo.cmd configs/start`). Paladin mounts use the Ochre Skeletal Warhorse
palette. Ollama typing delays are 1200 ms + 30 ms/char (gen_configs OLLAMA). Client damage meter is Details! (WotLK
build, Bunny67/Details-WotLK); Recount's TOC was patched to 30300. See the end of `SUMMARY.md` for what was last
verified in game.
