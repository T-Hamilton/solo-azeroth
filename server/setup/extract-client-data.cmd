@echo off
rem Extracts maps / dbc / vmaps / mmaps from YOUR WoW 3.3.5a client into runtime\data. Run after build-core.cmd.
rem Usage: extract-client-data.cmd "C:\Games\World of Warcraft 3.3.5a"
rem Maps + dbc take minutes, vmaps ~15 min, mmaps (pathfinding, needed by the bots) 1-3 HOURS on a fast CPU. Total ~7 GB.
setlocal
set NoDefaultCurrentDirectoryInExePath=
set CLIENT=%~1
if "%CLIENT%"=="" ( echo usage: extract-client-data.cmd "path\to\WoW 3.3.5a client folder" & exit /b 1 )
if not exist "%CLIENT%\Data\common.MPQ" ( echo "%CLIENT%" does not look like a 3.3.5a client - no Data\common.MPQ & exit /b 1 )
set RT=%~dp0..\runtime
for %%I in ("%RT%") do set RT=%%~fI
set DATA=%RT%\data
if not exist "%DATA%" mkdir "%DATA%"
echo === MAPS + DBC ===
"%RT%\map_extractor.exe" -i "%CLIENT%" -o "%DATA%" -e 1 -f 0
if errorlevel 1 ( echo map_extractor FAILED & exit /b 1 )
echo === VMAPS ===
if not exist "%RT%\vmap-work" mkdir "%RT%\vmap-work"
cd /d "%RT%\vmap-work"
"%RT%\vmap4_extractor.exe" -d "%CLIENT%\Data"
if errorlevel 1 ( echo vmap4_extractor FAILED & exit /b 1 )
if not exist "%DATA%\vmaps" mkdir "%DATA%\vmaps"
"%RT%\vmap4_assembler.exe" "%RT%\vmap-work\Buildings" "%DATA%\vmaps"
if errorlevel 1 ( echo vmap4_assembler FAILED & exit /b 1 )
echo === MMAPS (this is the long one) ===
cd /d "%DATA%"
"%RT%\mmaps_generator.exe"
echo === DONE === EXIT %ERRORLEVEL%
