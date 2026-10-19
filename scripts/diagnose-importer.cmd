@echo off
rem Records where game traffic goes during a login (for importer problems such as game accelerators). Nothing is uploaded.
title Fribbels - network diagnostic
if exist "%~dp0..\.toolchain\python-version" set /p PY_PYTHON=<"%~dp0..\.toolchain\python-version"
cd /d "%~dp0..\data\py"
py diagnose_capture.py %*
echo.
pause
