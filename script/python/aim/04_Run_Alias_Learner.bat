@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0C
title AI Invoice Pipeline - Alias Learner
echo ======================================================================
echo              AI INVOICE PIPELINE: ALIAS LEARNER
echo ======================================================================
echo Starting 04_alias_learner.py...
echo.
python 04_alias_learner.py

if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo [!] CRITICAL ERROR: SCRIPT CRASHED! 
    echo Please read the error message above to see what went wrong.
    echo ======================================================================
    pause
) else (
    echo.
    echo Process stopped cleanly.
    pause
)
