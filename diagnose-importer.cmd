@echo off
rem Records where game traffic goes during a login (for importer problems such as game accelerators). Nothing is uploaded.
set "PY_PYTHON=3.14"
cd /d "%~dp0data\py"
py diagnose_capture.py %*
pause
