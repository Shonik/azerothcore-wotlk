@echo off
REM Simple WoW Patch Installer
REM This batch file is converted to EXE using bat2exe or similar tool

echo WoW Patch Installer
echo ====================
echo.

REM Wait for WoW to close
:wait_wow
tasklist /FI "IMAGENAME eq Wow.exe" 2>NUL | find /I /N "Wow.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo Waiting for WoW.exe to close...
    timeout /t 2 /nobreak >nul
    goto wait_wow
)

echo WoW.exe closed, proceeding with patch...
echo.

REM ============================================
REM ADD YOUR PATCHING COMMANDS HERE
REM ============================================
REM Examples:
REM copy /Y "new_file.dll" "file.dll"
REM del "old_file.txt"
REM ============================================

REM Delete the patch file
if exist "wow-patch.mpq" (
    echo Cleaning up patch file...
    del "wow-patch.mpq"
)

echo.
echo Patch installed successfully!
echo.

REM Ask to restart WoW
choice /C YN /M "Do you want to restart World of Warcraft"
if errorlevel 2 goto end
if errorlevel 1 goto restart

:restart
echo Starting WoW...
start "" "Wow.exe"
goto end

:end
REM Self-delete
(goto) 2>nul & del "%~f0"
