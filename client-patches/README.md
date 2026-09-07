# client-patches

Only needed when the client is a copy of an **Ascension** install (its class tables list 32 classes, which breaks the
stock character-creation screen). A real stock 3.3.5a client needs nothing from here.

`patch-Z.MPQ` (not in git: it contains Blizzard files) = the stock GlueXML (login / realm / character screens) plus the
stock `ChrClasses.dbc` and `CharBaseInfo.dbc`, so the client only knows the 10 real classes. Build it with
`tools/build_ascension_client_patch.py`, which takes the folders to read the stock files from. The launcher's
`prelaunch.local.ps1` copies it into the client's `Data\` when it changes (the game must be closed for that).
