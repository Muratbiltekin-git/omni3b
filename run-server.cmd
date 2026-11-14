@echo off
REM Tarayicidan sohbet arayuzu: http://127.0.0.1:8080
REM Gorsel veya ses eklemek icin arayuzdeki ataç butonunu kullanin.
setlocal
set ROOT=%~dp0
"%ROOT%llama\llama-server.exe" ^
  -m "%ROOT%models\Qwen2.5-Omni-3B-Q4_K_M.gguf" ^
  --mmproj "%ROOT%models\mmproj-Qwen2.5-Omni-3B-Q8_0.gguf" ^
  -ngl 99 -fit off -c 4096 -np 1 ^
  --host 127.0.0.1 --port 8080
endlocal
