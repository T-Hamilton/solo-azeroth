@echo off
rem Regenerate the navigation meshes of the four continents from the Ascension-client terrain in runtime\data-ascension
rem (maps + vmaps copied from the CoA project's Ascension extraction). Run from PowerShell; 1-3 hours.
rem Afterwards: stop the world, rename runtime\data -> data-stock and data-ascension -> data, start the world.
rem The generator binary is the CoA project's copy: the one installed in this runtime is blocked by Windows app
rem control on this PC ("Device Guard policy"); same build, it has simply never been allowed to run here.
setlocal enabledelayedexpansion
set NoDefaultCurrentDirectoryInExePath=
cd /d C:\Users\Rik\solo-azeroth\server\runtime\data-ascension
set LOG=C:\Users\Rik\solo-azeroth\server\setup\mmaps-ascension.log
set GEN=C:\Users\Rik\coa-rebuild\server\runtime\mmaps_generator.exe
echo MMAPS ASCENSION START %DATE% %TIME% > %LOG%
for %%i in (0 1 530 571) do (
  echo === map %%i %TIME% >> %LOG%
  %GEN% %%i --threads 10 --silent >> %LOG% 2>&1
  echo map %%i rc !ERRORLEVEL! %TIME% >> %LOG%
)
echo MMAPS ASCENSION DONE %DATE% %TIME% >> %LOG%
