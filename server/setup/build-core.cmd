@echo off
rem Build AzerothCore (Playerbot branch) + mod-playerbots + mod-ollama-chat and install the binaries flat into server\runtime.
rem Needs: VS 2022 Build Tools (C++ workload), deps\boost_1_86_0 (staged), deps\openssl, mysql\mysql-8.4.0-winx64 (see setup\get-deps.ps1).
rem Usage: setup\build-core.cmd [parallel-jobs]   (default 12; a 16-way build wants ~12 GB RAM)
setlocal
set NoDefaultCurrentDirectoryInExePath=
set JOBS=%1
if "%JOBS%"=="" set JOBS=12
set SERVER=%~dp0..
for %%I in ("%SERVER%") do set SERVER=%%~fI
set SERVERF=%SERVER:\=/%
set CMAKE="C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if not exist %CMAKE% set CMAKE=cmake
set SRC=%SERVERF%/azerothcore
set BLD=%SERVERF%/build
set DEPS=%SERVERF%/deps
set MYSQL=%SERVERF%/mysql/mysql-8.4.0-winx64
echo === CONFIGURE %DATE% %TIME% ===
%CMAKE% -S %SRC% -B %BLD% -G "Visual Studio 17 2022" -A x64 ^
  -DBOOST_ROOT=%DEPS%/boost_1_86_0 -DBoost_ROOT=%DEPS%/boost_1_86_0 -DBOOST_LIBRARYDIR=%DEPS%/boost_1_86_0/stage/lib -DBoost_DIR=%DEPS%/boost_1_86_0/stage/lib/cmake/Boost-1.86.0 ^
  -DMYSQL_INCLUDE_DIR=%MYSQL%/include -DMYSQL_LIBRARY=%MYSQL%/lib/libmysql.lib ^
  -DOPENSSL_ROOT_DIR=%DEPS%/openssl/x64 ^
  -DTOOLS_BUILD=all -DSCRIPTS=static -DMODULES=static -DWITH_WARNINGS=0 ^
  -DCMAKE_INSTALL_PREFIX=%SERVERF%/runtime
if errorlevel 1 ( echo CONFIGURE FAILED & exit /b 1 )
echo === BUILD %DATE% %TIME% ===
%CMAKE% --build %BLD% --config Release --parallel %JOBS% -- /m:%JOBS% /nologo /v:m
if errorlevel 1 ( echo BUILD FAILED & exit /b 1 )
echo === INSTALL %DATE% %TIME% ===
%CMAKE% --install %BLD% --config Release
rem The exes need these next to them and the installer does not copy them: the MySQL client, OpenSSL 3 and its legacy provider.
rem Without them the worldserver exits with 0xC0000135 (DLL not found) and an empty log.
copy /Y "%SERVER%\mysql\mysql-8.4.0-winx64\lib\libmysql.dll" "%SERVER%\runtime\" >nul
copy /Y "%SERVER%\deps\openssl\x64\bin\libcrypto-3-x64.dll" "%SERVER%\runtime\" >nul
copy /Y "%SERVER%\deps\openssl\x64\bin\libssl-3-x64.dll" "%SERVER%\runtime\" >nul
copy /Y "%SERVER%\deps\openssl\x64\lib\ossl-modules\legacy.dll" "%SERVER%\runtime\" >nul
echo === DONE %DATE% %TIME% === EXIT %ERRORLEVEL%
