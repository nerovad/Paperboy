@echo off
call "%~dp0_prepare_aim_environment.bat" || (
    pause
    exit /b 1
)
mode con: cols=120 lines=30
color 0B
title AI Invoice Pipeline - Model Benchmark Test
echo ======================================================================
echo               AI INVOICE PIPELINE: MODEL BENCHMARK
echo ======================================================================
echo Starting 07_benchmark_models.py...
echo.
python 07_benchmark_models.py

if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo [!] CRITICAL ERROR: SCRIPT CRASHED! 
    echo Please read the error message above to see what went wrong.
    echo ======================================================================
    pause
) else (
    echo.
    echo Benchmark finished successfully.
    pause
)
