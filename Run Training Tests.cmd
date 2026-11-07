@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_gdunit4_performance.ps1" -TrainingOnly %*
pause
