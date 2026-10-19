@echo off
rem Checks that the gear importer's requirements (Python 3.14, Npcap) are in place.
set "PY_PYTHON=3.14"
cd /d "%~dp0data\py"
py check_importer.py
pause
