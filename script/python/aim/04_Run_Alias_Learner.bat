@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0C
REM This title is how START_ALL_SERVICES.bat finds a running
REM worker to restart it. Change both or neither.
title AIM - 04 Alias Learner
echo ======================================================================
echo              AI INVOICE PIPELINE: ALIAS LEARNER
echo ======================================================================
echo Starting 04_alias_learner.py...
echo.
REM Absolute path: the working directory is not dependable when
REM these run from a UNC share.
python "%~dp004_alias_learner.py"
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
