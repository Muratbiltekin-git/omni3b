@echo off
REM Kullanilabilir tonlari listeler.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0describe.ps1" -ListTones
