@echo off
REM Kullanim: run-image.cmd <resim-dosyasi> [soru]
setlocal
set ROOT=%~dp0
set MODEL=%ROOT%models\Qwen2.5-Omni-3B-Q4_K_M.gguf
set MMPROJ=%ROOT%models\mmproj-Qwen2.5-Omni-3B-Q8_0.gguf

if "%~1"=="" (
  echo Kullanim: run-image.cmd ^<resim^> [soru]
  exit /b 1
)

set QUESTION=%~2
if "%QUESTION%"=="" set QUESTION=Bu resimde ne var? Turkce kisa ve net anlat.

"%ROOT%llama\llama-mtmd-cli.exe" -m "%MODEL%" --mmproj "%MMPROJ%" -ngl 99 -fit off -c 4096 --image "%~1" -p "%QUESTION%"
endlocal
