# client-patches

Only needed when the client is a copy of an **Ascension** install. A real stock 3.3.5a client needs nothing from here.

Ascension is classless and its patches replace every client data table (`patch-M` alone carries 288 DBCs, `patch-S`
and `patch-T` the spell set). Two things break against a stock server:

- its class tables list 32 classes, which breaks the stock character-creation screen;
- its spell / skill-line / talent tables no longer tie spells to classes, so class trainers show an empty list and the
  talent tab is blank, even though the server sends the right spells.

`patch-Z.MPQ` (not in git: it contains Blizzard files) = the stock GlueXML (login / realm / character screens) plus the
stock gameplay DBCs: `ChrClasses`, `CharBaseInfo`, every `Spell*`, `Skill*`, `Talent*`, `Glyph*` and `gt*` table
(50 files, 54 MB). Item and creature display tables are deliberately left as Ascension's: this project adapts the
server's item display ids to them instead (`server\local`).

**Ghost Paladin** (`tools\ghost_paladin.py build server\runtime\data\dbc <client Data dir> [--palette ghost|purple]`):
every paladin spell effect recoloured from gold to a ghostly white/blue fade, paladin-only. The tool walks Spell.dbc
(family 10) to SpellVisual, SpellVisualKit, SpellVisualEffectName, the M2 models and their textures; clones the 122
models under `gh_` names with their skins, recolours 216 textures (written as uncompressed BLP2 under same-length
`~` names, because the M2 stores fixed-length paths), rewrites particle / ribbon / vertex colour tracks inside the
models, clones 96 visuals and 136 kits under new ids, and points the 740 paladin spells at them. Output lands in
`client-patches\ghost-paladin\` (git-ignored, 76 MB) and `build_ascension_client_patch.py` folds it into patch-Z.
Delete that folder to go back to gold. Every caster of a paladin spell gets the look: effects belong to the spell,
not to the race.

The paladin mounts (Warhorse, Charger) get recoloured skins on their own display rows. The default style, `ochre`,
borrows the palette of the Ochre Skeletal Warhorse, the Forsaken racial mount: crimson barding, tarnished steel, a
bone-ochre horse and green eyes. `GHOST_MOUNT_STYLE=ghost` gives the blue-white ghost steel with a purple (or, with
`GHOST_MOUNT_ACCENT=green`, plague-green) cloth instead. `tools\ghost_paladin.py mounts server\runtime\data\dbc <client
Data dir>` rebuilds just the two skins in seconds; then rebuild patch-Z as below.

Build it with `tools\build_ascension_client_patch.py server\runtime\data\dbc [<stock GlueXML folders>]` (the GlueXML
folders are only needed the first time; later builds reuse them from `build-patchZ`). The launcher's
`prelaunch.local.ps1` copies it into the client's `Data\` when it changes (the game must be closed for that) and keeps
the Ascension / CoA patch set in the right state: `patch-Z` and `patch-Z4` (stock in-game UI) on, `patch-Z2`,
`patch-Z3`, `patch-Z5` (Ascension UI/DLL shims) and `patch-Z6` (the CoA project's spell tables) off.
