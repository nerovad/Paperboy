@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0B
title AIM v2 - Worker
echo ======================================================================
echo                    AIM v2 WORKER (row-first)
echo ======================================================================
echo Starting worker.py...
echo.
REM Absolute path: the working directory is not dependable when
REM these run from a UNC share.
python "%~dp0worker.py"
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
