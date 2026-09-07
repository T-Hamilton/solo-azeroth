@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\server\solo.ps1" start
pause
