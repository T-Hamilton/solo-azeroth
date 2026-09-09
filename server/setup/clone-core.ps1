# clone-core.ps1 - fetches the three source trees this project is built from (no fork of our own; upstream as-is):
#   liyunfan1223/azerothcore-wotlk (Playerbot branch)   the server core
#   liyunfan1223/mod-playerbots                          the bots
#   DustinHendrickson/mod-ollama-chat                    the LLM chat for the bots
# Re-run to update (git pull on each). Pinned commits that are known to work together are listed at the end of HOWTO.md.
$ErrorActionPreference = "Stop"
$server = Split-Path $PSScriptRoot -Parent
$core = "$server\azerothcore"
if (-not (Test-Path "$core\.git")) { git clone --branch Playerbot https://github.com/liyunfan1223/azerothcore-wotlk.git $core } else { git -C $core pull --ff-only }
foreach ($m in @(@("mod-playerbots", "https://github.com/liyunfan1223/mod-playerbots.git"), @("mod-ollama-chat", "https://github.com/DustinHendrickson/mod-ollama-chat.git"))) {
    $dir = "$core\modules\$($m[0])"
    if (-not (Test-Path "$dir\.git")) { git clone $m[1] $dir } else { git -C $dir pull --ff-only }
}
# our fixes to mod-ollama-chat (channel auto-join, zone-based reply eligibility, realm-wide LFG chatter, tick diagnostics)
# and mod-playerbots (all shamans drop Windfury Totem in the air slot)
foreach ($p in @(@("mod-ollama-chat", "mod-ollama-chat-solo.diff"), @("mod-playerbots", "mod-playerbots-solo.diff"))) {
    $patch = Join-Path $server "patches\$($p[1])"
    if (Test-Path $patch) {
        git -C "$core\modules\$($p[0])" apply --check $patch 2>$null
        if ($LASTEXITCODE -eq 0) { git -C "$core\modules\$($p[0])" apply $patch; Write-Host "applied patches\$($p[1])" }
        else { Write-Host "patches\$($p[1]) did not apply cleanly (already applied, or upstream changed) - check manually" -ForegroundColor Yellow }
    }
}
# our own module (GM Toolkit, XP potions) lives in server\modules\mod-solo; link it in so the core's CMake builds it
$link = "$core\modules\mod-solo"
if (-not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target "$server\modules\mod-solo" | Out-Null; Write-Host "linked modules\mod-solo" }
Write-Host "core:            $(git -C $core log --oneline -1)"
Write-Host "mod-playerbots:  $(git -C "$core\modules\mod-playerbots" log --oneline -1)"
Write-Host "mod-ollama-chat: $(git -C "$core\modules\mod-ollama-chat" log --oneline -1)"
