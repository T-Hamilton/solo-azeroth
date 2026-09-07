<#
  Solo Azeroth - server control.

    .\solo.cmd start        MySQL + Ollama (with the chat model) + authserver + worldserver
    .\solo.cmd stop         stop every server process (MySQL included; Ollama is left running)
    .\solo.cmd status       what is running / listening
    .\solo.cmd mysql        start only MySQL
    .\solo.cmd ollama       start only Ollama and make sure the chat model is downloaded
    .\solo.cmd configs      (re)generate runtime\configs\*.conf from settings.json + settings.local.json, install personality packs
    .\solo.cmd first-run    one-time: create the MySQL data dir, databases, import the world, create your account
    .\solo.cmd client       point your WoW client at this server and launch it (same as the Play shortcut)
    .\solo.cmd shortcuts    put the Play / Start / Stop / Bot Settings / Edit Personalities shortcuts on your Desktop
    .\solo.cmd personalities [--reroll]   apply server\personalities\personalities.txt to the bots (edit it in Notepad)

  Each server opens in its own console window so you can type GM commands into it (the worldserver console takes
  commands without the leading dot, e.g.  account set gmlevel player 3 -1  or  ollama status ).
#>
param([string]$cmd = "status", [string]$arg = "")
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\lib.ps1"
$S = Get-Settings
$Runtime = $S.Runtime
$Configs = "$Runtime\configs"
$MyIni = "$($S.ServerDir)\mysql\my.ini"
$Py = Get-Python

function Start-MySQL {
    if (Listening $S.MySQLPort) { Write-Host "MySQL: already listening on $($S.MySQLPort)"; return }
    if (-not (Test-Path $MyIni)) { Write-Host "MySQL is not set up yet - run:  .\solo.cmd first-run"; return }
    Start-Process -FilePath "$($S.MySQLBin)\mysqld.exe" -ArgumentList "--defaults-file=`"$MyIni`"", "--console" -WindowStyle Minimized
    for ($i = 0; $i -lt 40 -and -not (Listening $S.MySQLPort); $i++) { Start-Sleep 1 }
    if (Listening $S.MySQLPort) { Write-Host "MySQL: up on $($S.MySQLPort)" } else { Write-Host "MySQL: FAILED to start (see mysql\logs\mysql-error.log)" }
}

function Start-Ollama {
    $ol = Get-Ollama
    if (-not $ol) { Write-Host "Ollama is not installed. Install it with:  winget install Ollama.Ollama   (bots will play without chat until then)"; return }
    $uri = [uri]$S.OllamaUrl
    if (-not (Listening $uri.Port)) {
        $env:OLLAMA_NUM_PARALLEL = "$($S.OllamaParallel)"
        $env:OLLAMA_KEEP_ALIVE = "-1"      # keep the chat model loaded instead of unloading it after 5 idle minutes
        Start-Process -FilePath $ol -ArgumentList "serve" -WindowStyle Hidden
        for ($i = 0; $i -lt 20 -and -not (Listening $uri.Port); $i++) { Start-Sleep 1 }
        Write-Host "Ollama: started on port $($uri.Port)"
    } else { Write-Host "Ollama: already listening on $($uri.Port)" }
    $have = (& $ol list 2>$null) -join "`n"
    if ($have -notmatch [regex]::Escape($S.OllamaModel)) {
        Write-Host "Ollama: downloading chat model $($S.OllamaModel) (one time, several GB)..."
        & $ol pull $S.OllamaModel
    } else { Write-Host "Ollama: model $($S.OllamaModel) is ready" }
}

function Start-Auth {
    if (Listening $S.AuthPort) { Write-Host "authserver: already listening on $($S.AuthPort)"; return }
    New-Item -ItemType Directory -Force "$Runtime\logs" | Out-Null   # AC does not create LogsDir; without it file logging is silently off
    if (-not (Test-Path "$Configs\authserver.conf")) { Write-Host "missing $Configs\authserver.conf - run: .\solo.cmd configs"; return }
    Start-Process -FilePath "$Runtime\authserver.exe" -ArgumentList "-c", "`"$Configs\authserver.conf`"" -WorkingDirectory $Runtime
    Write-Host "authserver: starting (port $($S.AuthPort))"
}

function Start-World {
    if (Listening $S.WorldPort) { Write-Host "worldserver: already listening on $($S.WorldPort)"; return }
    New-Item -ItemType Directory -Force "$Runtime\logs" | Out-Null
    if (-not (Test-Path "$Configs\worldserver.conf")) { Write-Host "missing $Configs\worldserver.conf - run: .\solo.cmd configs"; return }
    Start-Process -FilePath "$Runtime\worldserver.exe" -ArgumentList "-c", "`"$Configs\worldserver.conf`"" -WorkingDirectory $Runtime
    Write-Host "worldserver: starting (port $($S.WorldPort)). Give it 30-60 s; bots log in once you do."
}

function Sync-Realmlist {
    # keep the realm row in the auth DB in step with settings (name / address / port)
    if (-not (Listening $S.MySQLPort)) { return }
    # flag=0 clears the OFFLINE bit (2) the worldserver sets when it shuts down; with it set the client shows the realm as Offline
    $sql = "UPDATE realmlist SET name='$($S.RealmName)', address='$($S.RealmAddress)', localAddress='127.0.0.1', port=$($S.WorldPort), flag=0, gamebuild=12340 WHERE id=1;"
    $env:MYSQL_PWD = $S.DbPassword    # env var instead of --password: no stderr warning, and $LASTEXITCODE stays meaningful
    & "$($S.MySQLBin)\mysql.exe" "--user=$($S.DbUser)" "--host=127.0.0.1" "--port=$($S.MySQLPort)" "--database=$($S.DbPrefix)_auth" "--execute=$sql" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "realmlist: '$($S.RealmName)' -> $($S.RealmAddress):$($S.WorldPort)" } else { Write-Host "realmlist: not updated yet (auth DB not populated until the first worldserver boot)" }
}

function Install-PersonalityPacks {
    # our personality packs live in server\personalities; AzerothCore applies module SQL from the module's own updates dir
    $dst = "$($S.ServerDir)\azerothcore\modules\mod-ollama-chat\data\sql\characters\updates"
    if (-not (Test-Path $dst)) { return }
    Get-ChildItem "$($S.ServerDir)\personalities\*.sql" -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $dst -Force; Write-Host "personality pack: $($_.Name)" }
}

switch ($cmd) {
    "mysql"   { Start-MySQL }
    "ollama"  { Start-Ollama }
    "configs" { & $Py "$($S.ServerDir)\setup\gen_configs.py"; Install-PersonalityPacks; Start-MySQL; Sync-Realmlist }
    "first-run" {
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$($S.ServerDir)\setup\init-db.ps1"
        if (-not $?) { Write-Host "database setup failed"; exit 1 }
        & $Py "$($S.ServerDir)\setup\gen_configs.py"; Install-PersonalityPacks
        Write-Host "First worldserver boot: imports the world database (several minutes) and creates account '$($S.Account)'..."
        & $Py "$($S.ServerDir)\setup\first_start.py"
        Sync-Realmlist
        Write-Host "Done. Next:  .\solo.cmd shortcuts   then double-click 'Solo Azeroth - Play' on your Desktop."
    }
    "start"   { Start-MySQL; Sync-Realmlist; Start-Ollama; Start-Auth; Start-World }
    "stop" {
        foreach ($n in "worldserver", "authserver") {
            Get-Process $n -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Runtime*" } | ForEach-Object { Write-Host "stopping $n ($($_.Id))"; $_.CloseMainWindow() | Out-Null }
        }
        Start-Sleep 5
        foreach ($n in "worldserver", "authserver") { Get-Process $n -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Runtime*" } | Stop-Process -Force }
        if (Listening $S.MySQLPort) { Write-Host "stopping MySQL"; & "$($S.MySQLBin)\mysqladmin.exe" "--user=root" "--host=127.0.0.1" "--port=$($S.MySQLPort)" shutdown 2>$null }
    }
    "client"    { & powershell -NoProfile -ExecutionPolicy Bypass -File "$($S.RootDir)\launchers\play.ps1" }
    "personalities" { & $Py "$($S.RootDir)	oolsuild_personalities.py" $arg }
    "shortcuts" {
        # real .lnk shortcuts: the .cmd files locate their scripts relative to themselves, so copying them would not work
        $desk = [Environment]::GetFolderPath("Desktop")
        $wsh = New-Object -ComObject WScript.Shell
        Get-ChildItem "$($S.RootDir)\launchers\*.cmd" | ForEach-Object {
            Remove-Item (Join-Path $desk $_.Name) -ErrorAction SilentlyContinue      # leftovers from the old copy approach
            $lnk = $wsh.CreateShortcut((Join-Path $desk ($_.BaseName + ".lnk")))
            $lnk.TargetPath = $_.FullName; $lnk.WorkingDirectory = $_.DirectoryName
            $lnk.IconLocation = "$env:SystemRoot\System32\imageres.dll,$(if ($_.BaseName -match 'Play') { 149 } elseif ($_.BaseName -match 'Stop') { 100 } elseif ($_.BaseName -match 'Bot') { 109 } else { 94 })"
            $lnk.Save(); Write-Host "Desktop: $($_.BaseName)"
        }
    }
    "status" {
        $uri = [uri]$S.OllamaUrl
        foreach ($x in @(@("MySQL", $S.MySQLPort), @("Ollama", $uri.Port), @("authserver", $S.AuthPort), @("worldserver", $S.WorldPort), @("SOAP", $S.SoapPort))) {
            $state = "down"; if (Listening $x[1]) { $state = "LISTENING :" + $x[1] }
            Write-Host ("{0,-12} {1}" -f $x[0], $state)
        }
        Get-Process worldserver, authserver, mysqld, ollama -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, @{n = "MB"; e = { [int]($_.WorkingSet64 / 1MB) } }, Path -AutoSize
    }
    default { Write-Host "usage: .\solo.cmd start | stop | status | mysql | ollama | configs | first-run | client | shortcuts | personalities [--reroll]" }
}
