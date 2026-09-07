# init-db.ps1 - one-time MySQL setup: data directory, my.ini, the acore user and the four empty databases.
# The worldserver fills them on its first boot (Updates.AutoSetup imports the base SQL, including the modules').
# Safe to re-run: every step is skipped when already done.
. "$PSScriptRoot\..\lib.ps1"
$S = Get-Settings
$mysqlDir = Join-Path $S.ServerDir "mysql"
$bin = $S.MySQLBin
$ini = Join-Path $mysqlDir "my.ini"
if (-not (Test-Path "$bin\mysqld.exe")) { Write-Host "MySQL binaries missing at $bin - run setup\get-deps.ps1 first"; exit 1 }
New-Item -ItemType Directory -Force (Join-Path $mysqlDir "logs") | Out-Null
function Fwd($p) { return ($p -replace "\\", "/") }
if (-not (Test-Path $ini)) {
    $lines = @(
        "[mysqld]",
        "basedir=$(Fwd (Join-Path $mysqlDir 'mysql-8.4.0-winx64'))",
        "datadir=$(Fwd (Join-Path $mysqlDir 'data'))",
        "port=$($S.MySQLPort)",
        "bind-address=127.0.0.1",
        "max_allowed_packet=256M",
        "innodb_buffer_pool_size=1G",
        "innodb_flush_log_at_trx_commit=2",
        "log-error=$(Fwd (Join-Path $mysqlDir 'logs\mysql-error.log'))",
        "character-set-server=utf8mb4",
        "collation-server=utf8mb4_unicode_ci",
        "sql_mode=NO_ENGINE_SUBSTITUTION",
        "mysql_native_password=ON",
        "[client]",
        "port=$($S.MySQLPort)",
        "host=127.0.0.1"
    )
    Set-Content $ini $lines -Encoding ASCII
    Write-Host "wrote $ini (port $($S.MySQLPort))"
}
if (-not (Test-Path (Join-Path $mysqlDir "data\mysql"))) {
    Write-Host "initializing MySQL data directory..."
    & "$bin\mysqld.exe" "--defaults-file=$ini" --initialize-insecure --console 2>&1 | Select-Object -Last 3
}
if (-not (Listening $S.MySQLPort)) {
    Start-Process -FilePath "$bin\mysqld.exe" -ArgumentList "--defaults-file=`"$ini`"", "--console" -WindowStyle Minimized
    for ($i = 0; $i -lt 40 -and -not (Listening $S.MySQLPort); $i++) { Start-Sleep 1 }
}
if (-not (Listening $S.MySQLPort)) { Write-Host "MySQL did not start - see $mysqlDir\logs\mysql-error.log"; exit 1 }
$u = $S.DbUser; $pw = $S.DbPassword; $pre = $S.DbPrefix
$sql = @(
    "CREATE USER IF NOT EXISTS '$u'@'localhost' IDENTIFIED BY '$pw';",
    "CREATE USER IF NOT EXISTS '$u'@'%' IDENTIFIED BY '$pw';",
    "GRANT ALL PRIVILEGES ON *.* TO '$u'@'localhost' WITH GRANT OPTION;",
    "GRANT ALL PRIVILEGES ON *.* TO '$u'@'%' WITH GRANT OPTION;",
    "CREATE DATABASE IF NOT EXISTS ``${pre}_auth`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
    "CREATE DATABASE IF NOT EXISTS ``${pre}_characters`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
    "CREATE DATABASE IF NOT EXISTS ``${pre}_world`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
    "CREATE DATABASE IF NOT EXISTS ``${pre}_playerbots`` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;",
    "FLUSH PRIVILEGES;"
) -join " "
& "$bin\mysql.exe" "--user=root" "--host=127.0.0.1" "--port=$($S.MySQLPort)" "--execute=$sql"
if (-not $?) { Write-Host "creating user/databases failed"; exit 1 }
Write-Host "MySQL ready on port $($S.MySQLPort): user $u, databases ${pre}_auth / _characters / _world / _playerbots"
