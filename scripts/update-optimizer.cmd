@echo off
rem Merges the original repo's changes and rebuilds what changed. Close the optimizer first, or pass -WaitForApp.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-optimizer.ps1" -Interactive %*
