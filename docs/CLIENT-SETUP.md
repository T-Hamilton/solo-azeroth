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
