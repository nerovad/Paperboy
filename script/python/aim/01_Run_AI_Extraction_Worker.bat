@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0E
title AI Invoice Pipeline - CPU Vision Test
echo ======================================================================
echo               AI INVOICE PIPELINE: CPU VISION TEST
echo ======================================================================
echo Starting 01_AI_Extraction_Worker.py...
echo.
python 01_AI_Extraction_Worker.py

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
