@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0B
title AI Invoice Pipeline - SQL Worker
echo ======================================================================
echo                 AI INVOICE PIPELINE: SQL WORKER
echo ======================================================================
echo Starting 02_sql_worker.py...
echo.
python 02_sql_worker.py

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
