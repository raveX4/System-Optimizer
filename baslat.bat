@echo off
setlocal EnableDelayedExpansion

:: Yonetici yetkisi kontrolu
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~s0\"' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

cd /d "%~dp0"

:: PS1 arayuzunu oncelikli ac (konsol penceresi gizli, form gozukur)
if exist "system_optimizer.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0system_optimizer.ps1\"' -WindowStyle Minimized"
    exit /b
)

:: PS1 yoksa Python ile ac
if exist "system_optimizer.py" (
    if exist "C:\Python314\pythonw.exe" (
        start "" "C:\Python314\pythonw.exe" "system_optimizer.py"
        exit /b
    )
    where pythonw >nul 2>&1
    if %errorLevel% equ 0 (
        start "" pythonw "system_optimizer.py"
        exit /b
    )
)

echo [X] Error: system_optimizer.ps1 not found!
pause
endlocal
exit /b
