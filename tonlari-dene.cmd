@echo off
REM Ayni metni TUM tonlarla uretir (karsilastirma icin).
REM Kullanim: tonlari-dene.cmd foto.jpg
if "%~1"=="" (
  echo Kullanim: tonlari-dene.cmd ^<resim^>
  exit /b 1
)
setlocal
set ROOT=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%describe.ps1" -Image "%~1" -AllTones
endlocal
