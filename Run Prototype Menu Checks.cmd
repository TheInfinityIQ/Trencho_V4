@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_gdunit4_performance.ps1" -OrdinaryMenusOnly -WithoutCallStacks %*
pause
