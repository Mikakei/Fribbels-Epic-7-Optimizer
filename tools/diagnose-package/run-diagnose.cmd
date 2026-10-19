@echo off
rem Epic Seven importer network diagnostic. Needs Python 3 and Npcap. Nothing is uploaded; see README.txt.
setlocal
cd /d "%~dp0"

set "PYCMD="
py -3 -c "import sys" >nul 2>&1 && set "PYCMD=py -3"
if not defined PYCMD python -c "import sys" >nul 2>&1 && set "PYCMD=python"
if not defined PYCMD (
    echo Python 3 was not found. Install it from https://www.python.org/downloads/ and enable "Add Python to PATH".
    pause
    exit /b 1
)

%PYCMD% "%~dp0diagnose_capture.py" --out-dir "%~dp0reports"
pause
