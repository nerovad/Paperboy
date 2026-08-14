@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
title AI Invoice Pipeline - MASTER LAUNCHER
echo ======================================================================
echo           LAUNCHING ALL AI INVOICE PIPELINE SERVICES
echo ======================================================================
echo.

echo Starting Ingestion Watcher...
start "AI - 00 INGESTION WATCHER" cmd /c "00_Run_Ingestion_Watcher.bat"

echo Starting AI Extraction Worker...
start "AI - 01 EXTRACTION WORKER" cmd /c "01_Run_AI_Extraction_Worker.bat"

echo Starting SQL Worker...
start "AI - 02 SQL WORKER" cmd /c "02_Run_SQL_Worker.bat"

echo Starting Batch Splitter...
start "AI - 03 SPLITTER" cmd /c "03_Run_Batch_Splitter.bat"

echo Starting Alias Learner...
start "AI - 04 LEARNER" cmd /c "04_Run_Alias_Learner.bat"

echo.
echo ======================================================================
echo All services launched. This window will close automatically in 15 seconds.
echo ======================================================================
timeout /t 15
