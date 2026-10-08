@echo off
rem Fast dev loop. Wrapper because running .ps1 files is disabled by execution policy on some
rem machines: this calls dev-run.ps1 with -ExecutionPolicy Bypass.
rem
rem   scripts\dev-run.cmd              build (frontend if needed) and launch
rem   scripts\dev-run.cmd -Check       cargo check only (fastest)
rem   scripts\dev-run.cmd -NoRun       build, do not launch
rem   scripts\dev-run.cmd -Frontend    force a frontend rebuild first
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev-run.ps1" %*
exit /b %ERRORLEVEL%
