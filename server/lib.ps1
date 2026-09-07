# lib.ps1 - shared helpers for solo.ps1 and the launchers. Dot-source it:  . "$PSScriptRoot\lib.ps1"
$script:ServerDir = $PSScriptRoot
if ((Split-Path $script:ServerDir -Leaf) -ne "server") { $script:ServerDir = Join-Path (Split-Path $script:ServerDir -Parent) "server" }

function Get-Settings {
    # settings.json (defaults, in git) overlaid with settings.local.json (your machine, git-ignored)
    $base = Get-Content (Join-Path $script:ServerDir "settings.json") -Raw | ConvertFrom-Json
    $localPath = Join-Path $script:ServerDir "settings.local.json"
    if (Test-Path $localPath) {
        $local = Get-Content $localPath -Raw | ConvertFrom-Json
        foreach ($p in $local.PSObject.Properties) { $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    }
    $base | Add-Member -NotePropertyName ServerDir -NotePropertyValue $script:ServerDir -Force
    $base | Add-Member -NotePropertyName RootDir   -NotePropertyValue (Split-Path $script:ServerDir -Parent) -Force
    $base | Add-Member -NotePropertyName Runtime   -NotePropertyValue (Join-Path $script:ServerDir "runtime") -Force
    $base | Add-Member -NotePropertyName MySQLBin  -NotePropertyValue (Join-Path $script:ServerDir "mysql\mysql-8.4.0-winx64\bin") -Force
    return $base
}

function Listening($port) { return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) }

function Get-Python {
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c -and $c.Source -notmatch "WindowsApps") { return $c.Source }
    foreach ($p in @("$env:LOCALAPPDATA\Programs\Python\Python312\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe")) { if (Test-Path $p) { return $p } }
    return "python"
}

function Get-Ollama {
    $c = Get-Command ollama -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (Test-Path $p) { return $p }
    return $null
}

function Invoke-Soap($settings, $command) {
    # run a GM console command through the worldserver SOAP interface (SOAP.Enabled is on in our generated config)
    $py = Get-Python
    & $py (Join-Path $settings.RootDir "tools\soap.py") $command
}
