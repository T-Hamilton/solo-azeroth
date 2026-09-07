# botsettings.ps1 - a small window to tune the bots and their chat without touching config files by hand.
# Edits runtime\configs\modules\playerbots.conf and mod_ollama_chat.conf; "Save + restart" applies them.
# NOTE: solo.cmd configs regenerates both files from settings + gen_configs.py and would undo these edits.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\..\server\lib.ps1"
$S = Get-Settings
$botsConf = Join-Path $S.Runtime "configs\modules\playerbots.conf"
$chatConf = Join-Path $S.Runtime "configs\modules\mod_ollama_chat.conf"

# file, key, label, kind (int | bool | text), help
$settings = @(
    @("bots", "AiPlayerbot.RandomBotAutologin",        "Spawn bots when the realm starts",                 "bool", "0 = no bots at all until you add them yourself"),
    @("bots", "AiPlayerbot.MinRandomBots",             "Minimum bots",                                     "int",  "200 is a lively low-pop server; 500+ wants a strong CPU"),
    @("bots", "AiPlayerbot.MaxRandomBots",             "Maximum bots",                                     "int",  "usually the same as the minimum"),
    @("bots", "AiPlayerbot.RandomBotMinLevel",         "Lowest bot level",                                 "int",  ""),
    @("bots", "AiPlayerbot.RandomBotMaxLevel",         "Highest bot level",                                "int",  "80 = full spread; set both to your level to have company where you play"),
    @("bots", "AiPlayerbot.DisabledWithoutRealPlayer", "Pause bots while nobody is online",                "bool", "saves CPU and LLM calls when you are logged out"),
    @("bots", "AiPlayerbot.RandomBotMaps",             "Maps bots roam (ids)",                             "text", "0 Eastern Kingdoms, 1 Kalimdor, 530 Outland, 571 Northrend"),
    @("bots", "AiPlayerbot.RandomBotJoinBG",           "Bots queue battlegrounds / arenas",                "bool", ""),
    @("bots", "AiPlayerbot.RandomBotJoinLfg",          "Bots use the dungeon finder",                      "bool", ""),
    @("bots", "AiPlayerbot.RandomBotGroupNearby",      "Bots may invite you to group",                     "bool", ""),
    @("bots", "AiPlayerbot.RandomBotTalk",             "Scripted one-liners (non-LLM)",                    "bool", "the canned playerbots chatter; the LLM still replies to it"),
    @("bots", "AiPlayerbot.SelfBotLevel",              "Self-bot level (keep at 1)",                       "int",  "0 off, 1 GM by command, 2 everyone by command. 3 = YOU become a bot on login and the chat ignores you"),
    @("chat", "OllamaChat.Enable",                     "LLM chat on",                                      "bool", "master switch for everything below"),
    @("chat", "OllamaChat.Model",                      "Ollama model",                                     "text", "any model you have pulled; .ollama reload in-game after changing"),
    @("chat", "OllamaChat.EnableRandomChatter",        "Ambient general/trade/LFG chatter",                "bool", "bots start conversations on their own"),
    @("chat", "OllamaChat.RandomChatterBotCommentChance", "Ambient chatter chance % per bot tick",         "int",  "20 = busy; 5 = quiet"),
    @("chat", "OllamaChat.BotReplyChance.Channel",     "Bot replies to another bot in a channel %",        "int",  "35 = real back-and-forth; 3 = the module default"),
    @("chat", "OllamaChat.BotConversation.MaxChainDepth", "Max bot-to-bot hops per conversation",          "int",  ""),
    @("chat", "OllamaChat.BotConversation.RequireRecentHuman", "Bots only talk to bots after you spoke",    "bool", "off = chat is alive even when you are quiet"),
    @("chat", "OllamaChat.RateLimit.GlobalPerMinute",  "Hard cap: bot lines per minute (whole server)",    "int",  "0 = unlimited"),
    @("chat", "OllamaChat.EnableEventChatter",         "React to events (levels, loot, deaths, duels)",    "bool", ""),
    @("chat", "OllamaChat.EnableRPPersonalities",      "Personalities on",                                 "bool", "off = every bot uses the default voice"),
    @("chat", "OllamaChat.EnableTypingSimulation",     "Typing delay before replies",                      "bool", "")
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

$current = @{ bots = (Read-Conf $botsConf); chat = (Read-Conf $chatConf) }
$form = New-Object System.Windows.Forms.Form
$form.Text = "$($S.RealmName) - bots and chat"
$form.Size = New-Object System.Drawing.Size(760, 100 + 30 * $settings.Count)
$form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false
$tip = New-Object System.Windows.Forms.ToolTip
$controls = @{}
$y = 12
foreach ($s in $settings) {
    $file, $key, $label, $kind, $help = $s
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label; $lbl.Location = New-Object System.Drawing.Point(12, ($y + 4)); $lbl.Size = New-Object System.Drawing.Size(380, 20)
    if ($file -eq "chat") { $lbl.ForeColor = [System.Drawing.Color]::DarkSlateBlue }
    $form.Controls.Add($lbl)
    $val = $current[$file][$key]
    if ($kind -eq "bool") {
        $c = New-Object System.Windows.Forms.CheckBox
        $c.Checked = ($val -eq "1"); $c.Location = New-Object System.Drawing.Point(400, $y); $c.Size = New-Object System.Drawing.Size(30, 24)
    } else {
        $c = New-Object System.Windows.Forms.TextBox
        $c.Text = "$val"; $c.Location = New-Object System.Drawing.Point(400, $y); $c.Size = New-Object System.Drawing.Size(320, 24)
    }
    if ($help) { $tip.SetToolTip($c, $help); $tip.SetToolTip($lbl, $help) }
    $form.Controls.Add($c)
    $controls[$key] = @($c, $kind, $file)
    $y += 30
}
function Collect {
    $v = @{ bots = @{}; chat = @{} }
    foreach ($key in $controls.Keys) {
        $c, $kind, $file = $controls[$key]
        if ($kind -eq "bool") { $v[$file][$key] = $(if ($c.Checked) { "1" } else { "0" }) }
        elseif ($kind -eq "int") { $v[$file][$key] = [string]([int]($c.Text -replace '[^0-9-]', '')) }
        else { $v[$file][$key] = $c.Text.Trim() }
    }
    return $v
}
function Save-All { $v = Collect; Write-Conf $botsConf $v.bots; Write-Conf $chatConf $v.chat }

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(12, ($y + 6)); $status.Size = New-Object System.Drawing.Size(420, 40)
$status.Text = "runtime\configs\modules\playerbots.conf + mod_ollama_chat.conf"
$form.Controls.Add($status)
$save = New-Object System.Windows.Forms.Button
$save.Text = "Save"; $save.Location = New-Object System.Drawing.Point(450, $y); $save.Size = New-Object System.Drawing.Size(110, 30)
$save.Add_Click({ Save-All; $status.Text = "saved - chat settings apply with .ollama reload in-game; bot settings on the next restart" })
$form.Controls.Add($save)
$apply = New-Object System.Windows.Forms.Button
$apply.Text = "Save + restart realm"; $apply.Location = New-Object System.Drawing.Point(570, $y); $apply.Size = New-Object System.Drawing.Size(150, 30)
$apply.Add_Click({
    Save-All
    $status.Text = "saved; restarting the realm..."; $form.Refresh()
    Invoke-Soap $S "server shutdown 3" 2>$null | Out-Null
    $proc = { Get-Process worldserver -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$($S.Runtime)*" } }
    $t = 0; while ((& $proc) -and $t -lt 20) { Start-Sleep 1; $t++ }
    foreach ($p in (& $proc)) { $p.CloseMainWindow() | Out-Null }
    $t = 0; while ((& $proc) -and $t -lt 30) { Start-Sleep 1; $t++ }
    foreach ($p in (& $proc)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $S.ServerDir "solo.ps1") start | Out-Null
    $status.Text = "realm restarting - give it a minute, then log in"
})
$form.Controls.Add($apply)
[void]$form.ShowDialog()
