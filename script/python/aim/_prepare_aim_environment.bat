@echo off
cd /d "%~dp0"

if defined AIM_ENV_FILE (
    if exist "%AIM_ENV_FILE%" (
        echo Using AIM_ENV_FILE: %AIM_ENV_FILE%
        exit /b 0
    )

    echo.
    echo ======================================================================
    echo CRITICAL ERROR: AIM_ENV_FILE is set but the file was not found.
    echo   %AIM_ENV_FILE%
    echo ======================================================================
    exit /b 1
)

if exist "%~dp0.env" (
    set "AIM_ENV_FILE=%~dp0.env"
    echo Using AIM_ENV_FILE: %AIM_ENV_FILE%
    exit /b 0
)

if exist "%~dp0..\.env" (
    set "AIM_ENV_FILE=%~dp0..\.env"
    echo Using AIM_ENV_FILE: %AIM_ENV_FILE%
    exit /b 0
)

echo.
echo ======================================================================
echo CRITICAL ERROR: AIM .env file was not found.
echo.
echo Expected one of:
echo   %~dp0.env
echo   %~dp0..\.env
echo.
echo Copy the AIM .env file to E:\AIM\_PROGRAM\.env or E:\AIM\.env,
echo or set AIM_ENV_FILE to the exact file path before starting workers.
echo ======================================================================
exit /b 1
