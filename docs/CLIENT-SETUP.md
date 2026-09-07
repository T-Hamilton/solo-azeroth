# Client and LAN notes

## The client

Any World of Warcraft 3.3.5a client, build 12340, any locale. Point `ClientDir` (and `ClientExe` if it is not
`Wow.exe`) at it in `server\settings.local.json`.

The **Play** shortcut (`launchers\play.ps1`) does the realmlist for you: it writes
`set realmlist <RealmAddress>[:<AuthPort>]` into every `Data\<locale>\realmlist.wtf` it finds (and a root
`realmlist.wtf` if present), launches the game, and restores the original files when the game exits
(`RestoreRealmlistOnExit`, on by default). If you prefer to set the realmlist yourself once and launch the game
your own way, set it to `127.0.0.1` (add `:port` if you changed `AuthPort` from 3724) and use
`solo.cmd start`.

`launchers\prelaunch.local.ps1`, if it exists, runs right before the client starts. It is git-ignored; use it
for anything specific to your install (toggling patch MPQs, launching an addon manager).

Log in with the account and password from your settings. The account has GM level 3.

## If your client is a copy of an Ascension install

That client's class tables list 32 classes and its addons are Ascension's forks, so three extra things apply:
`client-patches/README.md` explains the stock-only `patch-Z.MPQ` that gives you the plain 10-class creation screen;
Ascension's ElvUI (7.x) doesn't run on a stock server, the standard ElvUI-WotLK 6.09 from
github.com/ElvUI-WotLK/ElvUI does; and the item display ids in the world database must be swapped for Ascension's
numbering (`SUMMARY.md`, "Local-only"). A real stock 3.3.5a client needs none of this.

## Ports

| Service | Default | Setting |
|---|---|---|
| authserver (login) | 3724 | `AuthPort` |
| worldserver (realm) | 8085 | `WorldPort` |
| MySQL | 3306 | `MySQLPort` |
| SOAP (GM commands from scripts) | 7878 | `SoapPort` |
| Ollama | 11434 | `OllamaUrl` |

Change any of them in `settings.local.json`, then `solo.cmd configs`. The realm row in the auth database is
updated to match. If you run another AzerothCore server on the same PC, give this one different ports for all
of the first four.

## Other PCs on your LAN

1. Set `RealmAddress` in `settings.local.json` to this PC's LAN IP (`ipconfig`), then `solo.cmd configs`.
2. Run `setup\add-firewall-rules.ps1` once from an admin prompt. It opens the auth and world ports on the
   Private and Domain profiles only.
3. On the other PC set the realmlist to `set realmlist <LAN IP>` (plus `:<AuthPort>` if changed) and create an
   account for them from the worldserver console: `account create name password`.

The `Play` shortcut on this PC keeps working with a LAN address in `RealmAddress`.

## Where things are

| | |
|---|---|
| binaries | `server\runtime\*.exe` |
| generated configs | `server\runtime\configs\` (+ `modules\`) |
| logs | `server\runtime\logs\`, crash dumps `server\runtime\Crashes\` |
| world data | `server\runtime\data\{dbc,maps,vmaps,mmaps}` |
| MySQL data | `server\mysql\data`, root has no password (bound to 127.0.0.1 only); app user from settings |
| first-boot log | `server\setup\first_start.log` |
| Addons from the Ascension copy that error at login (TomTom, WeakAuras 5.x, AtlasLoot 7.x, CoADump, CoA_PowerBars) | they are Ascension's retail-API backports and need its client Lua; parked in `Interface\AddOns.ascension-backup` on 2026-09-07. Use 3.3.5-era builds instead (WeakAuras-WotLK, TomTom 3.3.5, AtlasLoot Enhanced 5.x) |
| Class trainer opens with no spells / talent tab blank (Ascension copy) | the client's spell and skill tables are Ascension's classless ones; `client-patches\patch-Z.MPQ` must carry the stock ones and `patch-Z6` must be off (`client-patches\README.md`) |
| Lua errors from the game | copy `client-addons\!SoloErrorLog` into `Interface\AddOns` (the `!` makes it load first, so it also catches other addons' load-time errors); `/errs` in game, or `WTF\Account\<acct>\SavedVariables\SoloErrorLog.lua` after you log out |
