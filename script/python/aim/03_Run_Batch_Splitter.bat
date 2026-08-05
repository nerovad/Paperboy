@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0E
title AI Invoice Pipeline - Batch Splitter
echo ======================================================================
echo              AI INVOICE PIPELINE: BATCH SPLITTER
echo ======================================================================
echo Starting 03_batch_splitter.py...
echo.
python 03_batch_splitter.py

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
