@echo off
rem Wrapper so solo.ps1 runs regardless of the PowerShell execution policy.
rem Usage: solo start | stop | status | mysql | ollama | configs | first-run | client | shortcuts
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0solo.ps1" %*
