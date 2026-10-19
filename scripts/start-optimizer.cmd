@echo off
rem Starts the locally built optimizer. The app finds the portable JDK and pinned Python in .toolchain itself.
set "ROOT=%~dp0.."
if not exist "%ROOT%\app\main.prod.js" (
    echo app\main.prod.js not found. Build first: yarn build
    pause
    exit /b 1
)
start "" /d "%ROOT%" "%ROOT%\node_modules\electron\dist\electron.exe" app
