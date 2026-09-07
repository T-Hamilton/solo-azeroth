# get-deps.ps1 - downloads and unpacks the build/runtime dependencies (no admin needed):
#   Boost 1.86 source (built by build-boost.cmd), OpenSSL 3.5.8 (FireDaemon build, headers + libs), MySQL 8.4.0 (zip, runs without a service).
$ErrorActionPreference = "Stop"
$server = Split-Path $PSScriptRoot -Parent
$dl = "$server\downloads"; $deps = "$server\deps"; $mysql = "$server\mysql"
New-Item -ItemType Directory -Force $dl, $deps, $mysql | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Fetch($url, $file) {
    $path = Join-Path $dl $file
    if (Test-Path $path) { Write-Host "have $file"; return $path }
    Write-Host "downloading $file ..."; Invoke-WebRequest $url -OutFile $path; return $path
}
$boost = Fetch "https://archives.boost.io/release/1.86.0/source/boost_1_86_0.zip" "boost_1_86_0.zip"
$ssl   = Fetch "https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.5.8.zip" "openssl-3.5.8.zip"
$my    = Fetch "https://dev.mysql.com/get/Downloads/MySQL-8.4/mysql-8.4.0-winx64.zip" "mysql-8.4.0-winx64.zip"
if (-not (Test-Path "$deps\boost_1_86_0\bootstrap.bat")) { Write-Host "unpacking boost (large)..."; Expand-Archive $boost $deps -Force }
if (-not (Test-Path "$deps\openssl\x64\lib\libssl.lib")) {
    Write-Host "unpacking openssl..."; Expand-Archive $ssl "$deps\openssl-tmp" -Force
    $inner = Get-ChildItem "$deps\openssl-tmp" -Directory | Select-Object -First 1
    if (Test-Path "$deps\openssl") { Remove-Item "$deps\openssl" -Recurse -Force }
    Move-Item $inner.FullName "$deps\openssl"; Remove-Item "$deps\openssl-tmp" -Recurse -Force
}
if (-not (Test-Path "$mysql\mysql-8.4.0-winx64\bin\mysqld.exe")) { Write-Host "unpacking mysql..."; Expand-Archive $my $mysql -Force }
Write-Host "deps ready. Next: setup\build-boost.cmd  (10-20 min), then setup\clone-core.ps1, then setup\build-core.cmd"
