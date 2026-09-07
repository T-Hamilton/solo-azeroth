# add-firewall-rules.ps1 - run elevated ONLY if other PCs on your LAN should connect. Opens the auth and world ports.
. "$PSScriptRoot\..\lib.ps1"
$S = Get-Settings
foreach ($exe in @("authserver", "worldserver")) {
    $path = Join-Path $S.Runtime "$exe.exe"
    Get-NetFirewallRule -DisplayName "Solo Azeroth $exe" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName "Solo Azeroth $exe" -Direction Inbound -Action Allow -Program $path -Protocol TCP -Profile Domain,Private -Enabled True | Out-Null
    Write-Host "rule added: Solo Azeroth $exe"
}
Write-Host "Other PCs: set their realmlist to  set realmlist <this PC's LAN IP>:$($S.AuthPort)  and set RealmAddress in settings.local.json to that IP."
