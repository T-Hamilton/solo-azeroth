# Solo Azeroth

Your own World of Warcraft 3.3.5a server, full of player-bots that talk back.

One PC, one player, a few hundred bots levelling, questing, running dungeons and battlegrounds around you, and a
general chat that is alive: the bots talk to each other and to you through a local LLM, each with its own
personality, and they remember you. Some are helpful, some are just there, and a good half of them are the kind of
people you remember from Barrens chat.

Everything runs on your machine. No accounts, no cloud, no per-message cost.

## What it is made of

| Piece | What it does |
|---|---|
| [AzerothCore](https://github.com/liyunfan1223/azerothcore-wotlk) (Playerbot branch) | the 3.3.5a server |
| [mod-playerbots](https://github.com/liyunfan1223/mod-playerbots) | the bots: real characters that level, quest, group, raid, PvP |
| [mod-ollama-chat](https://github.com/DustinHendrickson/mod-ollama-chat) | gives the bots an LLM voice through [Ollama](https://ollama.com) |
| this repo | Windows setup scripts, a settings file, one-button launchers, a bot-settings window, the chat tuning, the personality pack, and a small server module ([mod-solo](server/modules/mod-solo/README.md): a GM Toolkit item and Potions of Experience) |

This repo holds only our own scripts and docs. It never contains game data: you need your own WoW 3.3.5a
(build 12340) client, and the server extracts what it needs from it on your machine.

## Requirements

- Windows 10/11, 64-bit.
- A World of Warcraft 3.3.5a client (build 12340), any language.
- A GPU for the chat model. The default, Gemma 3 12B abliterated at Q4 (7.3 GB), wants about 9 GB of VRAM. Any Ollama
  model works: pick a smaller one on a smaller card (see [docs/LLM-CHAT.md](docs/LLM-CHAT.md)). Without a GPU the
  bots still play, they just do not talk.
- About 45 GB of disk: 8 for the build, 7 for the extracted world data, 5 for MySQL, 9 for the model, plus your client.
- Python 3 (`winget install Python.Python.3.12`) and Git (`winget install Git.Git`).

## Setup

Everything below runs from a normal PowerShell prompt inside `server\`, except step 1.

1. **Compiler** (the only step that needs an admin prompt): `setup\install-admin.ps1` installs Visual Studio 2022
   Build Tools with the C++ workload.
2. **Dependencies**: `setup\get-deps.ps1` downloads and unpacks Boost, OpenSSL and MySQL (no service, no installer).
   Then `setup\build-boost.cmd` (10-20 minutes).
3. **Sources**: `setup\clone-core.ps1` fetches AzerothCore, mod-playerbots and mod-ollama-chat.
4. **Build**: `setup\build-core.cmd` (10-20 minutes, ~8 GB). Binaries land flat in `runtime\`.
5. **World data**: `setup\extract-client-data.cmd "C:\path\to\your\WoW 3.3.5a"`. Maps and vmaps take minutes; the
   mmaps (pathfinding, which the bots need) take one to three hours. Go do something else.
6. **Chat model**: `winget install Ollama.Ollama`. The model itself is downloaded on the first server start.
7. **Your settings**: create `settings.local.json` next to `settings.json` with at least your client folder:
   ```json
   { "ClientDir": "C:\\Games\\World of Warcraft 3.3.5a", "Account": "me", "Password": "secret" }
   ```
   Any key from `settings.json` can be overridden there (ports, realm name, bot count and level range, model).
8. **First run**: `solo.cmd first-run` creates the databases, imports the world (a few minutes) and creates your
   account with GM rights.
9. **Shortcuts**: `solo.cmd shortcuts` puts five shortcuts on your Desktop.

Step-by-step with what you should see after each step, and a troubleshooting table: [HOWTO.md](HOWTO.md).

Then double-click **Solo Azeroth - Play**. It starts everything that is not running, points your client at the
server, launches the game, and puts your realmlist back when you quit.

## Day to day

| Shortcut / command | Does |
|---|---|
| **Solo Azeroth - Play** | start what is needed, launch the client |
| **Solo Azeroth - Start Server** / **Stop Server** | just the server side |
| **Solo Azeroth - Bot Settings** | a window for the things you will actually want to tweak: bot count, level range, how chatty they are, which model |
| **Solo Azeroth - Edit Personalities** | the bot personalities in Notepad; applied and reloaded when you close it |
| `solo.cmd status` | what is running |
| `solo.cmd configs` | regenerate the server configs after editing `settings.local.json` or `setup\gen_configs.py` |

In game you are a GM, and a **GM Toolkit** lands in your bags on login: right-click it for teleports, GM powers
(god, fly, speed, no cooldowns...), level-ups, heal, repair, gold and **Potions of Experience** (+100% XP per
potion for an hour, up to five). Useful commands: `.playerbots bot add <name>` / `.bot add` to take bots into your party,
`.ollama status` to see the chat engine, `.ollama test hello` to fire one raw prompt, `.ollama reload` after
changing chat settings or personalities. The bots follow the whole mod-playerbots command set
([wiki](https://github.com/liyunfan1223/mod-playerbots/wiki)).

## The chat

Bots pick a personality when they first speak and keep it. `server\personalities\personalities.txt` (plain text,
edit it in Notepad via the Desktop shortcut) sets the voices and the mix:
half of them are toxic in the ways WoW players are toxic (gatekeepers, meter addicts, trolls, ragers, doomers),
a third are ordinary (looking for group, asking where things are, selling stuff), a fifth are the nicest people
you have ever met online. They start conversations in General, Trade and LFG, answer each other, react to what
happens around you (dings, drops, deaths, duels), whisper back, and keep long-term memories and relationships,
so the one who called you trash last week still thinks so.

How the mix, the volume and the model are chosen, and how to change them: [docs/LLM-CHAT.md](docs/LLM-CHAT.md).
Client and LAN notes: [docs/CLIENT-SETUP.md](docs/CLIENT-SETUP.md). Running notes and pinned versions:
[SUMMARY.md](SUMMARY.md).

## Legal

This project is for running a private server for yourself and friends with a client you own. It contains no
Blizzard assets and does not distribute any. AzerothCore and mod-playerbots are AGPL-3.0; mod-ollama-chat is
MIT; the scripts in this repository are MIT ([LICENSE](LICENSE)).
