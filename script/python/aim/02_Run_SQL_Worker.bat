@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0B
REM This title is how START_ALL_SERVICES.bat finds a running
REM worker to restart it. Change both or neither.
title AIM - 02 SQL Worker
echo ======================================================================
echo                 AI INVOICE PIPELINE: SQL WORKER
echo ======================================================================
echo Starting 02_sql_worker.py...
echo.
REM Absolute path: the working directory is not dependable when
REM these run from a UNC share.
python "%~dp002_sql_worker.py"
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
