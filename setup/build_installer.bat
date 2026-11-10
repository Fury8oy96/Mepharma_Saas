@echo off
setlocal
echo ==================================================
echo   Building MePharma Windows Installer
echo ==================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_installer.ps1"

pause
