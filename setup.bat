@echo off
setlocal enabledelayedexpansion
title Voice Clone Tool - Setup
cd /d "%~dp0"

echo ============================================================
echo   Voice Clone Tool - First-time setup
echo ============================================================
echo.

REM --- 1. Check Python 3.10 / 3.11 ---
set "PYEXE="
for %%V in (3.11 3.10) do (
    if not defined PYEXE (
        py -%%V -c "import sys; print(sys.version)" >nul 2>&1
        if !errorlevel! == 0 (
            set "PYEXE=py -%%V"
            echo [OK] Found Python %%V
        )
    )
)

if not defined PYEXE (
    echo [ERROR] Python 3.10 or 3.11 is required but was not found.
    echo.
    echo Please install Python 3.11 from:
    echo   https://www.python.org/downloads/release/python-3119/
    echo.
    echo IMPORTANT: During install, check "Add python.exe to PATH"
    echo            and also install the "py launcher".
    echo.
    pause
    exit /b 1
)

REM --- 2. Check ffmpeg ---
where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo [WARN] ffmpeg not found on PATH.
    echo        The tool needs ffmpeg to process uploaded audio.
    echo.
    echo Install options:
    echo   1. winget install Gyan.FFmpeg           (recommended)
    echo   2. Download from https://www.gyan.dev/ffmpeg/builds/
    echo      and add the "bin" folder to your PATH.
    echo.
    choice /M "Try to install ffmpeg now via winget"
    if !errorlevel! == 1 (
        winget install --id=Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
        echo.
        echo [INFO] ffmpeg installed. You may need to close and reopen this window
        echo        for the PATH to refresh. Continuing anyway...
    )
) else (
    echo [OK] ffmpeg found
)

REM --- 3. Create venv ---
if not exist ".venv\Scripts\python.exe" (
    echo.
    echo [*] Creating virtual environment...
    %PYEXE% -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create venv.
        pause
        exit /b 1
    )
) else (
    echo [OK] Virtual environment already exists
)

call ".venv\Scripts\activate.bat"

REM --- 4. Upgrade pip ---
echo.
echo [*] Upgrading pip...
python -m pip install --upgrade pip wheel setuptools >nul

REM --- 5. Install PyTorch with CUDA 12.1 (works with RTX 4060) ---
echo.
echo [*] Installing PyTorch with CUDA 12.1 (this is ~2.5 GB, be patient)...
python -c "import torch; import sys; sys.exit(0 if torch.cuda.is_available() else 1)" >nul 2>&1
if errorlevel 1 (
    pip install torch==2.3.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
    if errorlevel 1 (
        echo [ERROR] PyTorch install failed.
        pause
        exit /b 1
    )
) else (
    echo [OK] PyTorch with CUDA already installed
)

REM --- 6. Install the rest ---
echo.
echo [*] Installing remaining dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] Dependency install failed.
    pause
    exit /b 1
)

REM --- 7. Verify CUDA ---
echo.
echo [*] Verifying GPU...
python -c "import torch; print('CUDA available:', torch.cuda.is_available()); print('Device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU only')"

REM --- 8. Pre-download the XTTS v2 model ---
echo.
echo [*] Downloading XTTS v2 model (~1.8 GB, one-time)...
set COQUI_TOS_AGREED=1
python -c "import os; os.environ['COQUI_TOS_AGREED']='1'; from TTS.api import TTS; TTS('tts_models/multilingual/multi-dataset/xtts_v2'); print('Model ready.')"
if errorlevel 1 (
    echo [WARN] Model download failed. It will be retried on first run.
)

REM --- 9. Create desktop shortcut ---
echo.
echo [*] Creating desktop shortcut...
set "SHORTCUT=%USERPROFILE%\Desktop\Voice Clone Tool.lnk"
set "TARGET=%~dp0start.bat"
set "ICON=%SystemRoot%\System32\SHELL32.dll,138"
powershell -NoProfile -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT%');" ^
  "$s.TargetPath='%TARGET%';" ^
  "$s.WorkingDirectory='%~dp0';" ^
  "$s.IconLocation='%ICON%';" ^
  "$s.Description='Voice Clone Tool';" ^
  "$s.Save()"

echo.
echo ============================================================
echo   Setup complete!
echo ============================================================
echo.
echo   - Double-click "Voice Clone Tool" on your Desktop to launch
echo   - Or run start.bat in this folder
echo.
pause
endlocal
