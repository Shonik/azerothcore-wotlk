@echo off
REM Build script for WoW Patch Installer
REM Requires MinGW (gcc) to be installed and in PATH

echo Building WoW Patch Installer...

REM Check if gcc is available
where gcc >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: gcc not found in PATH
    echo Please install MinGW-w64 and add it to your PATH
    echo Download from: https://www.mingw-w64.org/
    pause
    exit /b 1
)

REM Compile with static linking for portability
REM -lcomctl32 required for progress bar (InitCommonControlsEx)
gcc -o installer.exe installer.c -mwindows -static -s -lcomctl32

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: installer.exe created
    echo.
    echo Next steps:
    echo 1. Copy installer.exe to your patch MPQ
    echo 2. Update prepatch.lst with:
    echo    extract installer.exe
    echo    execute installer.exe
    echo.
) else (
    echo.
    echo ERROR: Compilation failed
)

pause
