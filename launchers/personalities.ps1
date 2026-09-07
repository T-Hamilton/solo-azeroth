# personalities.ps1 - open server\personalities\personalities.txt in Notepad; when Notepad is closed, build the SQL,
# apply it to the database and tell the bots to reload (no server restart).
. "$PSScriptRoot\..\server\lib.ps1"
$S = Get-Settings
$file = Join-Path $S.ServerDir "personalities\personalities.txt"
$py = Get-Python
Write-Host "Editing $file"
Write-Host "Close Notepad when you are done - the bots reload automatically." -ForegroundColor Cyan
Start-Process notepad.exe -ArgumentList "`"$file`"" -Wait
& $py (Join-Path $S.RootDir "tools\build_personalities.py")
Write-Host ""
Write-Host "Bots that already picked a personality keep it. To make everyone re-roll:  solo.cmd personalities --reroll"
Start-Sleep 6
