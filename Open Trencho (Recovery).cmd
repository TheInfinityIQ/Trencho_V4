@echo off
setlocal
set "TRENCHO_GODOT=%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%TRENCHO_GODOT%" (
    echo Godot was not found at the installed Steam location.
    echo Open Godot's Project Manager and use Edit in recovery mode instead.
    pause
    exit /b 1
)
start "" "%TRENCHO_GODOT%" --editor --recovery-mode --path "%~dp0."
endlocal
