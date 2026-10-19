@echo off
rem Merges upstream changes and rebuilds what changed. Close the optimizer first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-optimizer.ps1" %*
pause
