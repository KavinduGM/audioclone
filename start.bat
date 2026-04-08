@echo off
title Voice Clone Tool
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    echo [ERROR] Not set up yet. Please run setup.bat first.
    pause
    exit /b 1
)

call ".venv\Scripts\activate.bat"

set COQUI_TOS_AGREED=1
set HOST=127.0.0.1
set PORT=8000

echo ============================================================
echo   Voice Clone Tool
echo   Opening http://%HOST%:%PORT% in your browser...
echo   Close this window to stop the server.
echo ============================================================
echo.

REM Open browser after a short delay so the server has time to boot
start "" /b cmd /c "timeout /t 6 /nobreak >nul & start http://%HOST%:%PORT%"

python -m uvicorn app.main:app --host %HOST% --port %PORT%
