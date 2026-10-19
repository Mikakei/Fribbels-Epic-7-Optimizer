@echo off
rem Checks the gear importer's requirements: Python, Npcap, capture interfaces and the decoding server.
title Fribbels - importer check
if exist "%~dp0..\.toolchain\python-version" set /p PY_PYTHON=<"%~dp0..\.toolchain\python-version"
cd /d "%~dp0..\data\py"
py check_importer.py
echo.
pause
