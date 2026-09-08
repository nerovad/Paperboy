@echo off
setlocal EnableDelayedExpansion
REM ---------------------------------------------------------------------------
REM AI Invoice Pipeline - master launcher.
REM
REM Safe to run at any time. For each worker it restarts the one that is
REM already running and starts the one that is not, so there is a single
REM command to use after bin/deploy-aim-workers has shipped new code.
REM
REM   START_ALL_SERVICES.bat          restart running workers, start stopped ones
REM   START_ALL_SERVICES.bat stop     stop every worker and exit
REM
REM A worker is matched by its console window title, which is set by the start
REM command below. A worker launched by hand under a different title will not
REM be matched, and would end up running twice -- use this script to start them.
REM ---------------------------------------------------------------------------
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
title AI Invoice Pipeline - MASTER LAUNCHER

set "MODE=%~1"

echo ======================================================================
if /I "%MODE%"=="stop" (
    echo             STOPPING ALL AI INVOICE PIPELINE SERVICES
) else (
    echo             STARTING ALL AI INVOICE PIPELINE SERVICES
)
echo ======================================================================
echo.

REM  <window title>  <launcher script>  <title used before 2026-09-08>
call :service "AIM - 00 Ingestion Watcher"    "00_Run_Ingestion_Watcher.bat"    "AI - 00 INGESTION WATCHER"
call :service "AIM - 01 AI Extraction Worker" "01_Run_AI_Extraction_Worker.bat" "AI Invoice Pipeline - CPU Vision Test"
call :service "AIM - 02 SQL Worker"           "02_Run_SQL_Worker.bat"           "AI Invoice Pipeline - SQL Worker"
call :service "AIM - 03 Batch Splitter"       "03_Run_Batch_Splitter.bat"       "AI Invoice Pipeline - Batch Splitter"
call :service "AIM - 04 Alias Learner"        "04_Run_Alias_Learner.bat"        "AI Invoice Pipeline - Alias Learner"

echo.
echo ======================================================================
if /I "%MODE%"=="stop" (
    echo All services stopped.
) else (
    echo All services running. This window closes in 15 seconds.
)
echo ======================================================================
if /I "%MODE%"=="stop" (
    pause
) else (
    timeout /t 15
)
exit /b 0

REM ---------------------------------------------------------------------------
REM :service <window title> <launcher script> [legacy title]
REM
REM taskkill reports a non-zero exit code when nothing matched the filter, so
REM its result is what tells us whether the worker was running. /T takes the
REM python child down with the console window; without it the worker would
REM survive and a second copy would start alongside it.
REM ---------------------------------------------------------------------------
:service
set "WORKER_TITLE=%~1"
set "WORKER_SCRIPT=%~2"
set "LEGACY_TITLE=%~3"
set "WAS_RUNNING=0"

taskkill /FI "WINDOWTITLE eq %WORKER_TITLE%" /T /F >nul 2>&1
if not errorlevel 1 set "WAS_RUNNING=1"

REM Workers started before the titles were normalised on 2026-09-08 still
REM carry the old one. Without this the first restart after that change
REM would leave them running and start a second copy alongside.
if not "%LEGACY_TITLE%"=="" (
    taskkill /FI "WINDOWTITLE eq %LEGACY_TITLE%" /T /F >nul 2>&1
    if not errorlevel 1 set "WAS_RUNNING=1"
)

if /I "%MODE%"=="stop" (
    if "!WAS_RUNNING!"=="1" (
        echo   stopped  %WORKER_TITLE%
    ) else (
        echo   not running  %WORKER_TITLE%
    )
    exit /b 0
)

if "!WAS_RUNNING!"=="1" (
    echo   restarting  %WORKER_TITLE%
    REM Let the console close and release its file handles before relaunching.
    timeout /t 2 /nobreak >nul
) else (
    echo   starting  %WORKER_TITLE%
)

start "%WORKER_TITLE%" cmd /c "%~dp0%WORKER_SCRIPT%"
exit /b 0
