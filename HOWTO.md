# Solo Azeroth, step by step

This is the long version of the README: every step, what you should see when it worked, and what to do when it
didn't. Nothing here assumes you have built a server before.

## 0. Before you start

You need:

| Thing | Check |
|---|---|
| Windows 10 or 11, 64-bit | Settings > System > About |
| A World of Warcraft 3.3.5a client, build 12340 | the client folder has `Wow.exe` and `Data\common.MPQ`. Any language. |
| An NVIDIA or AMD card with 12 GB+ for the default chat model | smaller cards work with a smaller model, see step 9 |
| ~45 GB free disk | build 8, world data 7, MySQL 5, model 8, plus room |
| Python 3 | `winget install Python.Python.3.12` then close and reopen your terminal |
| Git | `winget install Git.Git` then close and reopen your terminal |

Get the project:

```powershell
cd C:\
git clone https://github.com/T-Hamilton/solo-azeroth.git
cd C:\solo-azeroth\server
```

Every command below is typed in that `server` folder in a normal PowerShell window unless it says otherwise.

## 1. Compiler (the one admin step)

Right-click PowerShell, **Run as administrator**, then:

```powershell
cd C:\solo-azeroth\server
.\setup\install-admin.ps1
```

It downloads and installs Visual Studio 2022 Build Tools with the C++ workload. Ten minutes, a few GB.
**Worked when:** the last line says `exit code 0` (or `3010`, which means reboot when convenient). Close the admin
window; you don't need it again.

## 2. Dependencies

```powershell
.\setup\get-deps.ps1
.\setup\build-boost.cmd
```

The first downloads and unpacks Boost, OpenSSL and MySQL (a zip, no installer, no service). The second compiles the
Boost libraries: 10 to 20 minutes of scrolling.
**Worked when:** `build-boost.cmd` ends with `B2 EXIT 0` and `deps\boost_1_86_0\stage\lib` is full of `.lib` files.

## 3. Sources

```powershell
.\setup\clone-core.ps1
```

Fetches AzerothCore (Playerbot branch), mod-playerbots and mod-ollama-chat, and applies our fix to the chat module.
**Worked when:** it prints three commit lines and `applied patches\mod-ollama-chat-solo.diff`.

## 4. Build

```powershell
.\setup\build-core.cmd
```

10 to 20 minutes, 8 GB. It configures, compiles, installs to `runtime\`, then copies four DLLs next to the exes.
**Worked when:** the last line is `=== DONE ... === EXIT 0` and `runtime\` contains `worldserver.exe`,
`authserver.exe`, `libmysql.dll`, `libcrypto-3-x64.dll`, `libssl-3-x64.dll`, `legacy.dll`.
**If it says CONFIGURE FAILED:** step 1 or 2 didn't finish. Re-run them and read their last lines.

## 5. World data from your client

```powershell
.\setup\extract-client-data.cmd "C:\Games\World of Warcraft 3.3.5a"
```

Use your own client path. Maps and DBCs take minutes, vmaps about fifteen, then the mmaps (pathfinding, which the
bots need to walk anywhere) take one to three hours. Leave it running.
**Worked when:** `runtime\data\` has `dbc`, `maps`, `vmaps` and `mmaps`, and `mmaps` holds a few thousand files.

## 6. Chat model

```powershell
winget install Ollama.Ollama
```

That's all. The model itself (7 GB) downloads the first time the server starts.

## 7. Your settings

Create `server\settings.local.json` (Notepad is fine) with at least your client folder and the account you want:

```json
{
  "ClientDir": "C:\\Games\\World of Warcraft 3.3.5a",
  "Account": "me",
  "Password": "secret"
}
```

Double backslashes in paths. Anything in `settings.json` can be overridden here: realm name, ports, bot count and
level range, model. Don't edit `settings.json` itself.

## 8. First run

```powershell
.\solo.cmd first-run
```

Creates the MySQL data folder and databases, generates the server configs, boots the world once (which imports the
whole world database, several minutes), creates your account with GM rights, and shuts down cleanly.
**Worked when:** it ends with `world ready after ...s; creating account ...` and `worldserver exited 0`, then `Done`.
**If it says `world never became ready`:** open `setup\first_start.log` and read the last 30 lines; the reason is
there. The usual one on a fresh machine is step 5 not finished (`Map file ... not found`).

## 9. Shortcuts, then play

```powershell
.\solo.cmd shortcuts
```

Five shortcuts land on your Desktop. Double-click **Solo Azeroth - Play**. It starts MySQL, Ollama (pulling the model
the first time, 7 GB), the login server and the world server, points your client at the realm, and launches the game.
A small console window stays open while you play; leave it, it puts your realmlist back when you quit.

Log in with the account from step 7. The realm is called Solo Azeroth. At character select, click **AddOns** and tick
**Load out of date AddOns** if you use any.

**What you should see in the first two minutes:** bots logging in and running around (they only spawn once a real
player is online), scripted one-liners in General, then LLM lines: bots talking to each other about what they're
doing. Say something in General and up to two bots answer. Whisper a bot and it whispers back. Type
`/join LookingForGroup` to also get the realm-wide feed.

Smaller graphics card: put a smaller model in `settings.local.json`, e.g. `"OllamaModel": "dolphin3:8b"` (5 GB),
then `.\solo.cmd configs` and restart. Any model on ollama.com works.

## Day to day

| Shortcut | Does |
|---|---|
| **Play** | starts whatever isn't running, launches the game |
| **Start Server** / **Stop Server** | just the server side |
| **Bot Settings** | window for bot count, level range, chattiness, model, and a few safety switches |
| **Edit Personalities** | opens the bot personalities in Notepad; applies and reloads when you close it |

Commands, from `server\`: `solo.cmd status`, `solo.cmd configs` (after editing `settings.local.json`),
`solo.cmd personalities --reroll` (make every bot pick a personality again), `solo.cmd stop`.

In game, as GM: `.ollama status` (is the chat engine alive), `.ollama test hello` (one raw prompt, answer in the
server console), `.ollama reload` (after changing chat settings), `.playerbots bot add <name>` (take a bot into your
party), `.gm on`, `.tele orgrimmar`, `.modify speed 3`.

## Changing things

- **How many bots, what levels, how chatty:** Bot Settings window, then "Save + restart realm".
- **The personalities and the toxic/normal/nice mix:** Edit Personalities. The number of entries per kind is the mix.
  Details at the top of the file and in `docs/LLM-CHAT.md`.
- **Ports, realm name, account, model:** `settings.local.json`, then `solo.cmd configs`, then restart.
- **The chat governor (how often bots speak, how long threads run):** the `OLLAMA` table in
  `setup\gen_configs.py`, explained knob by knob in `docs/LLM-CHAT.md`. Then `solo.cmd configs` and `.ollama reload`.
- **Updating the server code:** `setup\clone-core.ps1` then `setup\build-core.cmd`, with the server stopped. If a
  newer upstream breaks the build, `SUMMARY.md` lists the commits that are known to work together.

## Other PCs on your LAN

See `docs/CLIENT-SETUP.md`: set `RealmAddress` to this PC's LAN IP, run the firewall script once as admin, give them
the realmlist and an account.

## When something is wrong

| Symptom | Cause | Fix |
|---|---|---|
| Play shortcut does nothing / "Windows cannot find ... .cmd" | stale Desktop icon from an older version | `solo.cmd shortcuts` again, press F5 on the Desktop |
| Game starts, login says Disconnected right after the status messages | the realm row points at the wrong world port | `solo.cmd configs` (it re-syncs the realm row), log in again |
| Realm shows as **Offline** in the list | the world server marked itself offline on its last shutdown | `solo.cmd configs` clears it; the login server picks it up within 20 s |
| Character creation shows strange classes / "Too many classes" | your client isn't a plain 3.3.5a client (Ascension copy) | see `client-patches/README.md` |
| `worldserver.exe` dies instantly, exit code 0xC0000135, empty log | missing DLLs next to the exe | re-run `setup\build-core.cmd`, or copy the four DLLs it lists |
| No `runtime\logs\Server.log` at all | the logs folder didn't exist when the server started | `solo.cmd stop`, `solo.cmd start` (the scripts create it now) |
| Bots run around but never talk, `.ollama status` says 0 submitted | you are counted as a bot: `AiPlayerbot.SelfBotLevel` is 3 | Bot Settings: Self-bot level = 1, Save + restart |
| Bots talk to each other but never to you | you aren't in the channel they use | `/join General`, `/join LookingForGroup` |
| `.ollama status` shows failures, "Last error" set | Ollama isn't running or the model isn't pulled | `solo.cmd ollama` |
| Everything is slow, replies take 10+ s | model doesn't fit in VRAM and spills to CPU | pick a smaller model (`ollama list` shows sizes) |
| Lua errors in game | an addon written for another client | the `SoloErrorLog` addon records them; `/errs` in game, or read `WTF\Account\<you>\SavedVariables\SoloErrorLog.lua` |
| Two servers on one PC fight over ports | both use 3306/3724/8085 | give this one different `MySQLPort`, `AuthPort`, `WorldPort`, `SoapPort` in `settings.local.json` |

Still stuck: `setup\first_start.log` (first boot), `runtime\logs\Server.log` (world), `runtime\logs\Auth.log`
(login), `mysql\logs\mysql-error.log`. With `"ChatDebug": 1` in `settings.local.json` (then `solo.cmd configs` and
`.ollama reload`) the world log prints, every 30 seconds, exactly where the chat funnel stops:
`ambient tick: bots=200 audience=72 due=31 rolled=7 topic=7 destination=1 governor=1 submitted=1`.
