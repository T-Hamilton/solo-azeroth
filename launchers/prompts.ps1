# prompts.ps1 - open server\personalities\prompts.txt (the prompt frame around every bot line) in Notepad; when Notepad
# is closed, regenerate the chat config and tell the running server to reload it (no restart).
. "$PSScriptRoot\..\server\lib.ps1"
$S = Get-Settings
$file = Join-Path $S.ServerDir "personalities\prompts.txt"
Write-Host "Editing $file"
Write-Host "Close Notepad when you are done - the server reloads the prompts automatically." -ForegroundColor Cyan
Start-Process notepad.exe -ArgumentList "`"$file`"" -Wait
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $S.ServerDir "solo.ps1") prompts
Start-Sleep 6
