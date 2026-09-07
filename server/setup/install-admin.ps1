# install-admin.ps1 - the ONE step that needs an elevated prompt: Visual Studio 2022 Build Tools with the C++ workload.
# Right-click PowerShell -> Run as administrator, then:  .\install-admin.ps1
$dl = Join-Path $PSScriptRoot "..\downloads"
New-Item -ItemType Directory -Force $dl | Out-Null
$exe = Join-Path $dl "vs_BuildTools.exe"
if (-not (Test-Path $exe)) { Invoke-WebRequest "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $exe }
$p = Start-Process -FilePath $exe -ArgumentList '--passive', '--norestart', '--wait', '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended' -Wait -PassThru
Write-Host "VS Build Tools installer exit code $($p.ExitCode) (0 = ok, 3010 = ok but reboot)"
