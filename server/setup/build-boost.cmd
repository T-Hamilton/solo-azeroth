@echo off
rem Builds the Boost libraries AzerothCore needs (static, release) into deps\boost_1_86_0\stage. Needs VS 2022 Build Tools.
setlocal
set NoDefaultCurrentDirectoryInExePath=
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cd /d "%~dp0..\deps\boost_1_86_0"
if not exist b2.exe call bootstrap.bat vc143
b2.exe -j%NUMBER_OF_PROCESSORS% toolset=msvc-14.3 address-model=64 architecture=x86 variant=release link=static runtime-link=shared threading=multi --with-filesystem --with-program_options --with-iostreams --with-regex --with-thread --with-system --with-atomic --with-chrono --with-date_time --build-dir="%~dp0..\deps\boost-build" --stagedir="%~dp0..\deps\boost_1_86_0\stage" -sNO_BZIP2=1 stage
echo B2 EXIT %ERRORLEVEL%
