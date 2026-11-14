@echo off
REM ============================================================
REM  Cift tiklayin  ->  arayuz acilir
REM  Arguman verin  ->  komut satiri modu
REM
REM  anlat.cmd
REM  anlat.cmd foto.jpg
REM  anlat.cmd foto.jpg sakin
REM  anlat.cmd foto.jpg enerjik "Bu manzara neresi?"
REM ============================================================

setlocal
set ROOT=%~dp0

if "%~1"=="" (
  start "" powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%gui.ps1"
  exit /b 0
)

set ARGS=-Image "%~1"
if not "%~2"=="" set ARGS=%ARGS% -Tone %~2
if not "%~3"=="" set ARGS=%ARGS% -Question "%~3"

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%describe.ps1" %ARGS%
endlocal
