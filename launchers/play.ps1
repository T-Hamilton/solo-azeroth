# play.ps1 - one button "boot into the game": starts the server if it is not up, points your client at it, launches it.
# While the game runs the client's realmlist.wtf is ours; when you exit it is put back the way it was (RestoreRealmlistOnExit).
. "$PSScriptRoot\..\server\lib.ps1"
$ErrorActionPreference = "Continue"
$S = Get-Settings
$solo = Join-Path $S.ServerDir "solo.ps1"

Write-Host "=== $($S.RealmName) ===" -ForegroundColor Cyan
if (-not (Listening $S.WorldPort)) {
    Write-Host "realm is not running - starting MySQL, Ollama, authserver and worldserver (first boot takes a minute)..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $solo start | Out-Host
    $t = 0
    while (-not (Listening $S.WorldPort) -and $t -lt 300) { Start-Sleep 3; $t += 3; Write-Host -NoNewline "." }
    Write-Host ""
    if (-not (Listening $S.WorldPort)) { Write-Host "worldserver did not come up on port $($S.WorldPort) - check its console window" -ForegroundColor Red; Read-Host "press Enter"; exit 1 }
}

$client = $S.ClientDir
$exe = Join-Path $client $S.ClientExe
# never start a second copy of the game (a second launcher run would also clobber the realmlist backup of the first)
$exeName = [IO.Path]::GetFileNameWithoutExtension($S.ClientExe)
$already = Get-CimInstance Win32_Process -Filter "name='$($S.ClientExe)'" -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath -like "$client*" -or -not $_.ExecutablePath }
if ($already) { Write-Host "the game is already running (pid $($already[0].ProcessId)) - look for its window" -ForegroundColor Yellow; Start-Sleep 4; exit 0 }
if (-not (Test-Path $exe)) { Write-Host "client not found: $exe  (set ClientDir / ClientExe in server\settings.local.json)" -ForegroundColor Red; Read-Host "press Enter"; exit 1 }

# realmlist.wtf lives in Data\<locale>\ on 3.3.5a clients (older layouts keep it next to the exe)
$realm = "set realmlist $($S.RealmAddress)"
if ([int]$S.AuthPort -ne 3724) { $realm += ":$($S.AuthPort)" }
$rlFiles = @(Get-ChildItem (Join-Path $client "Data\*\realmlist.wtf") -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
if (Test-Path (Join-Path $client "realmlist.wtf")) { $rlFiles += (Join-Path $client "realmlist.wtf") }
foreach ($f in $rlFiles) {
    if (-not (Test-Path "$f.solo-backup")) { Copy-Item $f "$f.solo-backup" }
    Set-Content $f $realm -Encoding ASCII
}
Write-Host "realmlist -> $realm  ($($rlFiles.Count) file(s))"

# optional machine-specific hook (git-ignored), e.g. toggling client patches before launch
$hook = Join-Path $PSScriptRoot "prelaunch.local.ps1"
if (Test-Path $hook) { & $hook }

Start-Process -FilePath $exe -WorkingDirectory $client | Out-Null
Write-Host "client launched. Login: $($S.Account) / $($S.Password)" -ForegroundColor Green
if ($S.RestoreRealmlistOnExit) {
    Write-Host "(this window restores your realmlist when the game exits - leave it open)"
    # The exe re-spawns itself (the first process exits within a second and a child carries on), so waiting on the
    # process we started would restore the realmlist before the real game process has even read it. Wait until no
    # process of that name is left instead, after a grace period for the hand-off.
    Start-Sleep 15
    while (Get-Process $exeName -ErrorAction SilentlyContinue) { Start-Sleep 5 }
    foreach ($f in $rlFiles) { if (Test-Path "$f.solo-backup") { Move-Item "$f.solo-backup" $f -Force } }
    Write-Host "realmlist restored."
} else { Start-Sleep 3 }
