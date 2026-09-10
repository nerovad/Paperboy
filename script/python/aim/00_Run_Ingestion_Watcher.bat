@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
REM This title is how START_ALL_SERVICES.bat finds a running
REM worker to restart it. Change both or neither.
title AIM - 00 Ingestion Watcher
color 0b

echo ======================================================================
echo             AI INVOICE PIPELINE: INGESTION WATCHER
echo ======================================================================
echo Starting 00_Ingestion_Watcher.py...
echo.
REM Absolute path: the working directory is not dependable when
REM these run from a UNC share.
python "%~dp000_Ingestion_Watcher.py"
if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo CRITICAL ERROR: The Python script crashed or failed to start.
    echo ======================================================================
    pause
)
