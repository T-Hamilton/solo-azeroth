# clone-core.ps1 - fetches the three source trees this project is built from (no fork of our own; upstream as-is):
#   liyunfan1223/azerothcore-wotlk (Playerbot branch)   the server core
#   liyunfan1223/mod-playerbots                          the bots
#   DustinHendrickson/mod-ollama-chat                    the LLM chat for the bots
# Re-run to update (git pull on each). Pinned commits that are known to work together are listed in SUMMARY.md.
$ErrorActionPreference = "Stop"
$server = Split-Path $PSScriptRoot -Parent
$core = "$server\azerothcore"
if (-not (Test-Path "$core\.git")) { git clone --branch Playerbot https://github.com/liyunfan1223/azerothcore-wotlk.git $core } else { git -C $core pull --ff-only }
foreach ($m in @(@("mod-playerbots", "https://github.com/liyunfan1223/mod-playerbots.git"), @("mod-ollama-chat", "https://github.com/DustinHendrickson/mod-ollama-chat.git"))) {
    $dir = "$core\modules\$($m[0])"
    if (-not (Test-Path "$dir\.git")) { git clone $m[1] $dir } else { git -C $dir pull --ff-only }
}
Write-Host "core:            $(git -C $core log --oneline -1)"
Write-Host "mod-playerbots:  $(git -C "$core\modules\mod-playerbots" log --oneline -1)"
Write-Host "mod-ollama-chat: $(git -C "$core\modules\mod-ollama-chat" log --oneline -1)"
