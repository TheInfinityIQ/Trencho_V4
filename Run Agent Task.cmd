@echo off
setlocal
cd /d "%~dp0"
set "TASK_PY=%USERPROFILE%\AppData\Local\Python\pythoncore-3.13-64\python.exe"
set "TASK_PY_ARGS="
if exist "%TASK_PY%" goto run
where py.exe >nul 2>nul
if errorlevel 1 goto fallback
set "TASK_PY=py.exe"
set "TASK_PY_ARGS=-3"
goto run
:fallback
set "TASK_PY=python.exe"
:run
"%TASK_PY%" %TASK_PY_ARGS% "%~dp0tools\agent_task.py" %*
exit /b %errorlevel%
