@echo off
rem Starts the locally built optimizer with the portable JDK and Node in .toolchain (see MAINTENANCE.md).
setlocal
set "ROOT=%~dp0"
set "PATH=%ROOT%.toolchain\jdk8u504-b01\bin;%ROOT%.toolchain\node-v16.20.2-win-x64;%PATH%"
set "NODE_ENV=production"
rem The importer runs data\py\scanner.py through the py launcher; pin it to 3.14 instead of the 3.15 release candidate
set "PY_PYTHON=3.14"

if not exist "%ROOT%app\main.prod.js" (
    echo app\main.prod.js not found. Build first: yarn build
    pause
    exit /b 1
)

cd /d "%ROOT%"
start "" "%ROOT%node_modules\electron\dist\electron.exe" ./app/main.prod.js
