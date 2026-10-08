@echo off
rem Release build: NSIS installer -> res\MithenMusic-setup.exe. Wrapper because running .ps1 files is
rem disabled by execution policy on some machines: this calls the script with -ExecutionPolicy Bypass.
rem
rem   scripts\build-windows-installer.cmd
rem   scripts\build-windows-installer.cmd -SkipFrontend
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-windows-installer.ps1" %*
exit /b %ERRORLEVEL%
