# botsettings.ps1 - the Bot Settings window: bots, chat and advanced tabs, with real controls.
# Edits runtime\configs\modules\playerbots.conf and mod_ollama_chat.conf.
#   Save                writes the files (bot settings apply on the next realm start, chat settings on "Reload chat")
#   Reload chat         applies the chat tab to the running server right away (.ollama reload), no restart
#   Save + restart      writes and restarts the realm (needed for the Bots tab)
#   Status              shows what the chat engine is doing right now (.ollama status)
# Every save is also stored in server\settings.local.json under "ConfOverrides", which gen_configs.py applies last:
# solo.cmd configs (run by the scripts whenever settings change) keeps what you set here.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\..\server\lib.ps1"
$S = Get-Settings
$botsConf = Join-Path $S.Runtime "configs\modules\playerbots.conf"
$chatConf = Join-Path $S.Runtime "configs\modules\mod_ollama_chat.conf"

# tab, file, key, label, kind (int:min:max | float:min:max | bool | text | model), help
$defs = @(
    # ---------------------------------------------------------------- Bots
    @("Bots", "bots", "AiPlayerbot.RandomBotAutologin",        "Spawn bots when the realm starts",              "bool",           "off = no bots at all until you add some by hand"),
    @("Bots", "bots", "AiPlayerbot.MinRandomBots",             "Minimum number of bots",                        "int:0:3000",     "how many bots live on the server. 200 = lively low-pop; 500+ wants a strong CPU"),
    @("Bots", "bots", "AiPlayerbot.MaxRandomBots",             "Maximum number of bots",                        "int:0:3000",     "usually the same as the minimum"),
    @("Bots", "bots", "AiPlayerbot.RandomBotMinLevel",         "Lowest bot level",                              "int:1:80",       ""),
    @("Bots", "bots", "AiPlayerbot.RandomBotMaxLevel",         "Highest bot level",                             "int:1:80",       "80 = full spread. Set both to your level to have company where you play"),
    @("Bots", "bots", "AiPlayerbot.RandomBotMaps",             "Maps bots roam (ids, comma separated)",         "text",           "0 Eastern Kingdoms, 1 Kalimdor, 530 Outland, 571 Northrend"),
    @("Bots", "bots", "AiPlayerbot.DisabledWithoutRealPlayer", "Pause bots while nobody is online",             "bool",           "saves CPU and LLM calls when you are logged out"),
    @("Bots", "bots", "AiPlayerbot.RandomBotJoinBG",           "Bots queue battlegrounds and arenas",           "bool",           ""),
    @("Bots", "bots", "AiPlayerbot.RandomBotJoinLfg",          "Bots use the dungeon finder",                   "bool",           ""),
    @("Bots", "bots", "AiPlayerbot.RandomBotGroupNearby",      "Bots may invite you to group",                  "bool",           ""),
    @("Bots", "bots", "AiPlayerbot.RandomBotGuildNearby",      "Bots may invite you to their guild",            "bool",           ""),
    @("Bots", "bots", "AiPlayerbot.RandomBotTalk",             "Scripted one-liners (not the LLM)",             "bool",           "the canned playerbots chatter (hello, lol...); off by default, the LLM does this better"),
    @("Bots", "bots", "AiPlayerbot.EnableBroadcasts",          "Scripted broadcasts (accepted quest X, looted Y)", "bool",        "the canned 'I just accepted...' / 'looted...' / 'anyone for dungeon...' lines; off by default"),
    @("Bots", "bots", "AiPlayerbot.RandomBotSuggestDungeons",  "Bots suggest dungeons in chat",                 "bool",           ""),
    @("Bots", "bots", "AiPlayerbot.SelfBotLevel",              "Self-bot level  (keep at 1)",                   "int:0:2",        "0 off, 1 GM by command, 2 everyone by command. 3 would make YOU a bot on login; not offered here"),
    # ---------------------------------------------------------------- Chat
    @("Chat", "chat", "OllamaChat.Enable",                     "LLM chat on",                                   "bool",           "master switch for everything on this tab"),
    @("Chat", "chat", "OllamaChat.Model",                      "Model",                                         "model",          "any model Ollama has pulled (ollama pull <name> in a terminal to get more)"),
    @("Chat", "chat", "OllamaChat.EnableRPPersonalities",      "Personalities on",                              "bool",           "off = every bot uses the same default voice"),
    @("Chat", "chat", "OllamaChat.EnableRandomChatter",        "Ambient chatter (bots start conversations)",    "bool",           ""),
    @("Chat", "chat", "OllamaChat.RandomChatterBotCommentChance", "Ambient chatter chance per bot, %",          "int:0:100",      "the main volume dial for bots starting lines on their own. 20 = busy, 5 = quiet"),
    @("Chat", "chat", "OllamaChat.Ambient.HoldPassPct",        "Ambient lines allowed into a live conversation, %", "int:0:100",  "while people are talking in a channel, this share of ambient lines still gets in (and joins the talk). 100 = no hold"),
    @("Chat", "chat", "OllamaChat.BotConversation.ChainLinesPerMinute", "Bot-to-bot lines per channel per minute", "int:0:60", "hard cap on bots answering bots. 8 = a steady argument, 20 = a brawl. Replies to you never count"),
    @("Chat", "chat", "OllamaChat.BotConversation.MaxChainDepth", "Bot-to-bot hops before a thread stops",      "int:0:20",       "how long two bots can go back and forth without you"),
    @("Chat", "chat", "OllamaChat.Transcript.Lines",           "Lines of recent chat shown to a bot",           "int:0:40",       "context for replies. 10 = follows the thread; 20+ = starts imitating the crowd"),
    @("Chat", "chat", "OllamaChat.NumPredict",                 "Max tokens per line",                           "int:10:400",     "110 = two or three sentences, 60 = one-liners"),
    @("Chat", "chat", "OllamaChat.MinRandomInterval",          "Ambient: min seconds between a bot's tries",    "int:5:3600",     ""),
    @("Chat", "chat", "OllamaChat.MaxRandomInterval",          "Ambient: max seconds between a bot's tries",    "int:5:3600",     ""),
    @("Chat", "chat", "OllamaChat.Chatter.ZoneChannelsAcrossMap", "Whole continent talks in your zone channel", "bool",         "on: any bot on your continent may speak and reply in YOUR General/Trade. off: only bots in your zone (1000 bots over four continents = a few per zone)"),
    @("Chat", "chat", "OllamaChat.Chatter.UseGeneralChannel",  "Ambient in General",                            "bool",           ""),
    @("Chat", "chat", "OllamaChat.Chatter.UseTradeChannel",    "Ambient in Trade (cities)",                     "bool",           ""),
    @("Chat", "chat", "OllamaChat.Chatter.UseLookingForGroupChannel", "Ambient in LookingForGroup (realm-wide)", "bool",          "you must /join LookingForGroup to see it"),
    @("Chat", "chat", "OllamaChat.PlayerReplyChance.Say",      "Reply to YOU in /say, %",                       "int:0:100",      ""),
    @("Chat", "chat", "OllamaChat.PlayerReplyChance.Channel",  "Reply to YOU in a channel, %",                  "int:0:100",      ""),
    @("Chat", "chat", "OllamaChat.PlayerReplyChance.Party",    "Reply to YOU in party, %",                      "int:0:100",      ""),
    @("Chat", "chat", "OllamaChat.BotReplyChance.Say",         "Bot replies to another bot in /say, %",         "int:0:100",      ""),
    @("Chat", "chat", "OllamaChat.BotReplyChance.Channel",     "Bot replies to another bot in a channel, %",    "int:0:100",      "this is what makes conversations. 35 = real back-and-forth, 3 = the module default"),
    @("Chat", "chat", "OllamaChat.MaxBotsToPick",              "Max bots that answer one message",              "int:1:10",       ""),
    @("Chat", "chat", "OllamaChat.EnableWhisperReplies",       "Bots answer whispers",                          "bool",           ""),
    @("Chat", "chat", "OllamaChat.EnableEventChatter",         "React to events (dings, loot, deaths, duels)",  "bool",           ""),
    @("Chat", "chat", "OllamaChat.EnableTypingSimulation",     "Typing delay before a line appears",            "bool",           ""),
    # ---------------------------------------------------------------- Advanced
    @("Advanced", "chat", "OllamaChat.BotConversation.MaxChainDepth", "Bot-to-bot hops before a thread is cut", "int:0:20",       ""),
    @("Advanced", "chat", "OllamaChat.BotConversation.ChanceDecayPct", "Reply chance kept per hop, %",          "int:0:100",      "higher = longer threads"),
    @("Advanced", "chat", "OllamaChat.BotConversation.EngagedWindowSeconds", "Seconds two speakers stay 'in conversation'", "int:0:900", "while engaged, the partner answers first and skips pacing cooldowns"),
    @("Advanced", "chat", "OllamaChat.Ambient.HoldSeconds",    "A channel counts as 'live' this long after a line", "int:0:600",  "ambient hold applies while the last line is younger than this"),
    @("Advanced", "chat", "OllamaChat.Repetition.OpenerHistorySize", "Opener check: recent lines compared",    "int:0:30",       "drops a reply that starts like one of the last N lines in the channel. 0 = off (the whole channel will start copying one opener)"),
    @("Advanced", "chat", "OllamaChat.Repetition.CheckDirectAddress", "Repetition check also on replies to a partner", "bool",  ""),
    @("Advanced", "chat", "OllamaChat.RepeatPenalty",          "Repeat penalty",                                "float:1:1.5",    "1.15 = stop parroting the transcript's words; 1.0 = off"),
    @("Advanced", "chat", "OllamaChat.BotConversation.RequireRecentHuman", "Bots only answer bots after you spoke", "bool",       "off = the chat lives without you"),
    @("Advanced", "chat", "OllamaChat.BotConversation.HumanWindowSeconds", "...for this many seconds",           "int:10:3600",    ""),
    @("Advanced", "chat", "OllamaChat.Cooldown.PerBotSeconds", "Min seconds between two lines from one bot",    "int:0:600",      ""),
    @("Advanced", "chat", "OllamaChat.Cooldown.PerScopeSeconds", "Min seconds between any two bot lines in a channel", "int:0:600", ""),
    @("Advanced", "chat", "OllamaChat.RateLimit.ScopePerMinute", "Hard cap: bot lines per channel per minute", "int:0:200",      "0 = unlimited"),
    @("Advanced", "chat", "OllamaChat.RateLimit.GlobalPerMinute", "Hard cap: bot lines per minute, whole server", "int:0:1000",   "0 = unlimited"),
    @("Advanced", "chat", "OllamaChat.RandomChatterRealPlayerDistance", "Ambient: max distance to you, yards",  "int:1:1000000", "100000 = anyone on your continent (the channel still has to contain you)"),
    @("Advanced", "chat", "OllamaChat.EventChatterRealPlayerDistance", "Events: max distance to you, yards",    "int:1:100000",   ""),
    @("Advanced", "chat", "OllamaChat.SayDistance",            "/say reply distance, yards",                    "float:1:200",    ""),
    @("Advanced", "chat", "OllamaChat.Temperature",            "Temperature",                                   "float:0:2",      "0.9 = lively, 0.5 = predictable"),
    @("Advanced", "chat", "OllamaChat.MaxConcurrentQueries",   "Parallel requests to Ollama",                   "int:0:16",       "match OLLAMA_NUM_PARALLEL (4)"),
    @("Advanced", "chat", "OllamaChat.DisableRepliesInCombat", "Bots stay quiet while fighting",                "bool",           ""),
    @("Advanced", "chat", "OllamaChat.Memory.Enable",          "Long-term memory",                              "bool",           ""),
    @("Advanced", "chat", "OllamaChat.Relationship.Enable",    "Relationships between characters",              "bool",           ""),
    @("Advanced", "chat", "OllamaChat.EnableSentimentTracking", "Like/dislike score per player",                "bool",           ""),
    @("Advanced", "chat", "OllamaChat.DebugEnabled",           "Debug logging (funnel line every 30 s)",        "bool",           "runtime\logs\Server.log")
)

function Read-Conf($path) {
    $map = @{}
    if (-not (Test-Path $path)) { return $map }
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*([A-Za-z0-9_.]+)\s*=\s*(.*?)\s*$') { $map[$matches[1]] = $matches[2].Trim('"') }
    }
    return $map
}
function Write-Conf($path, $values) {
    $lines = if (Test-Path $path) { Get-Content $path } else { @() }
    $seen = @{}
    $out = foreach ($line in $lines) {
        if ($line -match '^\s*([A-Za-z0-9_.]+)\s*=') {
            $k = $matches[1]
            if ($values.ContainsKey($k)) { $seen[$k] = $true; "$k = $($values[$k])"; continue }
        }
        $line
    }
    foreach ($k in $values.Keys) { if (-not $seen[$k]) { $out += "$k = $($values[$k])" } }
    Set-Content $path $out -Encoding UTF8
}
function Get-Models {
    $ol = Get-Ollama
    if (-not $ol) { return @() }
    $names = @()
    foreach ($line in (& $ol list 2>$null)) { if ($line -match '^(\S+)\s' -and $matches[1] -ne 'NAME') { $names += $matches[1] } }
    return $names
}

$current = @{ bots = (Read-Conf $botsConf); chat = (Read-Conf $chatConf) }
$models = Get-Models

$form = New-Object System.Windows.Forms.Form
$form.Text = "$($S.RealmName) - bots and chat"
$form.Size = [System.Drawing.Size]::new(820, 700)
$form.MinimumSize = [System.Drawing.Size]::new(700, 500)
$form.StartPosition = "CenterScreen"
$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 15000

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = [System.Drawing.Point]::new(10, 10)
$tabs.Size = [System.Drawing.Size]::new(785, 560)
$tabs.Anchor = "Top,Bottom,Left,Right"
$form.Controls.Add($tabs)

$pages = @{}
foreach ($name in @("Bots", "Chat", "Advanced")) {
    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = $name
    $page.AutoScroll = $true
    $tabs.TabPages.Add($page)
    $pages[$name] = @{ page = $page; y = 12 }
}

$controls = @{}
foreach ($d in $defs) {
    $tab, $file, $key, $label, $kind, $help = $d
    $p = $pages[$tab]
    $y = $p.y
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = [System.Drawing.Point]::new(12, ($y + 4))
    $lbl.Size = [System.Drawing.Size]::new(400, 20)
    $p.page.Controls.Add($lbl)
    $val = $current[$file][$key]
    $parts = $kind.Split(":")
    switch ($parts[0]) {
        "bool" {
            $c = New-Object System.Windows.Forms.CheckBox
            $c.Checked = ($val -eq "1")
            $c.Location = [System.Drawing.Point]::new(420, $y); $c.Size = [System.Drawing.Size]::new(30, 24)
        }
        "int" {
            $c = New-Object System.Windows.Forms.NumericUpDown
            $c.Minimum = [decimal]$parts[1]; $c.Maximum = [decimal]$parts[2]
            $n = 0; if ([int]::TryParse("$val", [ref]$n)) { $c.Value = [Math]::Min([Math]::Max($n, $c.Minimum), $c.Maximum) }
            $c.Location = [System.Drawing.Point]::new(420, $y); $c.Size = [System.Drawing.Size]::new(110, 24)
        }
        "float" {
            $c = New-Object System.Windows.Forms.NumericUpDown
            $c.DecimalPlaces = 2; $c.Increment = 0.05
            $c.Minimum = [decimal]$parts[1]; $c.Maximum = [decimal]$parts[2]
            $f = 0.0; if ([double]::TryParse("$val", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$f)) { $c.Value = [Math]::Min([Math]::Max([decimal]$f, $c.Minimum), $c.Maximum) }
            $c.Location = [System.Drawing.Point]::new(420, $y); $c.Size = [System.Drawing.Size]::new(110, 24)
        }
        "model" {
            $c = New-Object System.Windows.Forms.ComboBox
            $c.DropDownStyle = "DropDown"
            foreach ($m in $models) { [void]$c.Items.Add($m) }
            if ($val -and -not $c.Items.Contains($val)) { [void]$c.Items.Add($val) }
            $c.Text = "$val"
            $c.Location = [System.Drawing.Point]::new(420, $y); $c.Size = [System.Drawing.Size]::new(330, 24)
        }
        default {
            $c = New-Object System.Windows.Forms.TextBox
            $c.Text = "$val"
            $c.Location = [System.Drawing.Point]::new(420, $y); $c.Size = [System.Drawing.Size]::new(330, 24)
        }
    }
    if ($help) { $tip.SetToolTip($c, $help); $tip.SetToolTip($lbl, $help) }
    $p.page.Controls.Add($c)
    $controls[$key] = @($c, $parts[0], $file)
    $p.y = $y + 30
}

function Collect {
    $v = @{ bots = @{}; chat = @{} }
    foreach ($key in $controls.Keys) {
        $c, $kind, $file = $controls[$key]
        switch ($kind) {
            "bool"  { $v[$file][$key] = $(if ($c.Checked) { "1" } else { "0" }) }
            "int"   { $v[$file][$key] = [string]([int]$c.Value) }
            "float" { $v[$file][$key] = ([double]$c.Value).ToString("0.##", [Globalization.CultureInfo]::InvariantCulture) }
            default { $v[$file][$key] = $c.Text.Trim() }
        }
    }
    return $v
}
function Save-Overrides($v) {
    # persist into settings.local.json -> ConfOverrides, so solo.cmd configs regenerates the files WITH these values
    $path = Join-Path $S.ServerDir "settings.local.json"
    $obj = if (Test-Path $path) { Get-Content $path -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    $ov = [ordered]@{}
    foreach ($pair in @(@("playerbots.conf", $v.bots), @("mod_ollama_chat.conf", $v.chat))) {
        $h = [ordered]@{}
        foreach ($k in ($pair[1].Keys | Sort-Object)) { $h[$k] = $pair[1][$k] }
        $ov[$pair[0]] = $h
    }
    if ($obj.PSObject.Properties["ConfOverrides"]) { $obj.ConfOverrides = $ov } else { $obj | Add-Member -NotePropertyName ConfOverrides -NotePropertyValue $ov }
    # no byte-order mark: Python's json module chokes on one
    [System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
}
function Save-All { $v = Collect; Write-Conf $botsConf $v.bots; Write-Conf $chatConf $v.chat; Save-Overrides $v }

$status = New-Object System.Windows.Forms.TextBox
$status.Multiline = $true; $status.ReadOnly = $true; $status.ScrollBars = "Vertical"
$status.Location = [System.Drawing.Point]::new(10, 580)
$status.Size = [System.Drawing.Size]::new(785, 40)
$status.Anchor = "Bottom,Left,Right"
$status.Text = "runtime\configs\modules\playerbots.conf + mod_ollama_chat.conf"
$form.Controls.Add($status)

function Add-Button($text, $x, $action) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = [System.Drawing.Point]::new($x, 628); $b.Size = [System.Drawing.Size]::new(150, 30)
    $b.Anchor = "Bottom,Left"
    $b.Add_Click($action)
    $form.Controls.Add($b)
}
Add-Button "Save" 10 {
    Save-All
    $status.Text = "saved. Bot count / levels / maps: next realm start. Everything else: press Reload."
}
Add-Button "Reload (no restart)" 170 {
    Save-All
    # re-read the .conf files, then let both modules pick the values up (bot count / levels / maps still need a restart)
    Invoke-Soap $S "reload config" 2>$null | Out-Null
    Invoke-Soap $S "playerbots rndbot reload" 2>$null | Out-Null
    $r = Invoke-Soap $S "ollama reload" 2>&1 | Out-String
    $status.Text = $(if ($r -match "reload") { "settings applied to the running server (bot count / levels / maps: next restart)" } else { "saved; the server is not running (or SOAP is off) - they apply on the next start" })
}
Add-Button "Status" 330 {
    $r = Invoke-Soap $S "ollama status" 2>&1 | Out-String
    $status.Text = $(if ($r) { ($r -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '').Trim() } else { "server not running" })
    $status.Size = [System.Drawing.Size]::new($status.Width, 40)
}
Add-Button "Save + restart realm" 490 {
    Save-All
    $status.Text = "saved; restarting the realm (about a minute)..."; $form.Refresh()
    Invoke-Soap $S "server shutdown 3" 2>$null | Out-Null
    $proc = { Get-Process worldserver -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$($S.Runtime)*" } }
    $t = 0; while ((& $proc) -and $t -lt 20) { Start-Sleep 1; $t++ }
    foreach ($p in (& $proc)) { $p.CloseMainWindow() | Out-Null }
    $t = 0; while ((& $proc) -and $t -lt 30) { Start-Sleep 1; $t++ }
    foreach ($p in (& $proc)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $S.ServerDir "solo.ps1") start | Out-Null
    $status.Text = "realm restarting - give it a minute, then log in"
}
Add-Button "Close" 650 { $form.Close() }

[void]$form.ShowDialog()
