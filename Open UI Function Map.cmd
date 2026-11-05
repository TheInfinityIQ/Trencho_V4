@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\update_system_map.ps1" -OpenUiMap
if errorlevel 1 pause
