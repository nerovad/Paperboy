@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0E
REM This title is how START_ALL_SERVICES.bat finds a running
REM worker to restart it. Change both or neither.
title AIM - 01 AI Extraction Worker
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
