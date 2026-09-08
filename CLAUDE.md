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
  `tools/soap.py "server shutdown 30"` (players see a countdown), wait for the process to exit, copy, then
  `powershell -File server/solo.ps1 start`. Confirm with `tools/soap.py "server info"` and the mod-solo lines at the
  top of `server/runtime/logs/Server.log`. Each `reload config` rotates that log.
- SQL for the world DB: `server/modules/mod-solo/sql/world/*.sql` (applied by `solo.cmd configs/start`, must be
  idempotent). Owner-specific rows live in `server/local/*.sql` (ignored).

## Gotchas that cost time before
- Server DBCs are stock 3.3.5a: custom items must reuse stock "Deprecated" item ids; new creature display rows must
  be added to BOTH the client table (patch-Z) and `server/runtime/data/dbc/CreatureDisplayInfo.dbc`.
- `AiPlayerbot.SelfBotLevel` must stay 1. Bots only log in while a real player is online.
- Heredocs through the PowerShell/Bash tools have mangled backslashes in .ps1/.py before: write those with the
  Write/Edit tools.
- The Ascension client's `ChatChannels.dbc` differs from stock; patch-Z carries the stock one.

## Current state (2026-09-08)
Quest item drop rate x3, quest XP x2, kill XP x3 (all on the Bot Settings World tab). Paladins get Crusader Strike at
level 8 (mod-solo `SoloClassSpells.cpp`). Paladin mounts use the Ochre Skeletal Warhorse palette (patch-Z rebuilt,
installs at the next Play with the game closed). See the end of `SUMMARY.md` for what was last verified in game.
