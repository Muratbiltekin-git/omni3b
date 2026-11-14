# setup.ps1 -- Omni3B icin gerekli tum ikili dosyalari indirir ve yerlerine koyar.
#
# Kullanim (PowerShell):
#   .\setup.ps1              # NVIDIA GPU varsa CUDA, yoksa CPU surumu indirir
#   .\setup.ps1 -Cpu         # CPU surumunu zorla
#   .\setup.ps1 -Force       # var olan dosyalari da yeniden indir
#
# Indirdigi seyler:
#   llama\   llama.cpp b12387 (CUDA 12.4 x64 veya CPU x64)
#   models\  Qwen2.5-Omni-3B Q4_K_M + mmproj Q8_0  (~3.4 GB)
#   tts\     Piper TTS (Windows amd64) + tr_TR-dfki-medium sesi

[CmdletBinding()]
param(
    [switch]$Cpu,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$llamaDir  = Join-Path $root "llama"
$modelsDir = Join-Path $root "models"
$ttsDir    = Join-Path $root "tts"
$tmpDir    = Join-Path $env:TEMP ("omni3b-setup-" + [guid]::NewGuid().ToString("N"))

foreach ($d in @($llamaDir, $modelsDir, $ttsDir)) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text)   { Write-Host "    $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text) { Write-Host "    $Text" -ForegroundColor Yellow }

function Get-RemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Dest
    )
    if ((Test-Path $Dest) -and -not $Force) {
        $sz = (Get-Item $Dest).Length
        if ($sz -gt 1024) {
            Write-Ok "Zaten var, atlandi: $(Split-Path -Leaf $Dest)  ($([math]::Round($sz/1MB,1)) MB)"
            return
        }
    }

    Write-Host "    Indiriliyor: $(Split-Path -Leaf $Dest)"
    Write-Host "    $Url" -ForegroundColor DarkGray

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -L --fail --retry 3 --retry-delay 2 --progress-bar -o $Dest $Url
        if ($LASTEXITCODE -ne 0) { throw "Indirme basarisiz (curl cikis kodu $LASTEXITCODE): $Url" }
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
    }

    if (-not (Test-Path $Dest)) { throw "Dosya olusmadi: $Dest" }
    $mb = [math]::Round((Get-Item $Dest).Length / 1MB, 1)
    Write-Ok "Tamam: $(Split-Path -Leaf $Dest)  ($mb MB)"
}

function Expand-ZipTo {
    param(
        [Parameter(Mandatory)][string]$Zip,
        [Parameter(Mandatory)][string]$Dest
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }

    $staging = Join-Path $tmpDir ("x-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $staging)

    # Arsiv tek bir kok klasor iceriyorsa onun icini al
    $entries = @(Get-ChildItem $staging -Force)
    if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) {
        Move-Item $entries[0].FullName $Dest
    } else {
        Move-Item $staging $Dest
    }
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# 1) llama.cpp
# ---------------------------------------------------------------------------
Write-Step "llama.cpp hazirlaniyor"

$relTag = "b12387"
$relBase = "https://github.com/ggml-org/llama.cpp/releases/download/$relTag"

$hasNvidia = $false
if (-not $Cpu) {
    $smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($smi) {
        try {
            $null = & $smi.Source --query-gpu=name --format=csv,noheader 2>$null
            if ($LASTEXITCODE -eq 0) { $hasNvidia = $true }
        } catch { $hasNvidia = $false }
    }
}

if ($hasNvidia) {
    Write-Ok "NVIDIA GPU bulundu -> CUDA 12.4 surumu"
    $mainZip = Join-Path $tmpDir "llama-cuda.zip"
    $cudartZip = Join-Path $tmpDir "cudart.zip"
    Get-RemoteFile -Url "$relBase/llama-$relTag-bin-win-cuda-12.4-x64.zip" -Dest $mainZip
    Get-RemoteFile -Url "$relBase/cudart-llama-$relTag-bin-win-cuda-12.4-x64.zip" -Dest $cudartZip

    Expand-ZipTo -Zip $mainZip -Dest $llamaDir
    # CUDA calisma zamanı DLL'leri (cublas64_12, cudart64_12 ...) ayni klasore kopyalanir
    $cudartStage = Join-Path $tmpDir "cudart-stage"
    New-Item -ItemType Directory -Force -Path $cudartStage | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($cudartZip, $cudartStage)
    Get-ChildItem $cudartStage -Recurse -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $llamaDir $_.Name) -Force
    }
} else {
    Write-Ok "NVIDIA GPU yok (veya -Cpu) -> CPU surumu"
    $mainZip = Join-Path $tmpDir "llama-cpu.zip"
    Get-RemoteFile -Url "$relBase/llama-$relTag-bin-win-cpu-x64.zip" -Dest $mainZip
    Expand-ZipTo -Zip $mainZip -Dest $llamaDir
}

$exe = Join-Path $llamaDir "llama-mtmd-cli.exe"
if (-not (Test-Path $exe)) { throw "llama-mtmd-cli.exe bulunamadi. Arsiv yapisi beklenenden farkli." }
Write-Ok "llama.cpp hazir"

# ---------------------------------------------------------------------------
# 2) Modeller (Qwen2.5-Omni-3B, GGUF)
# ---------------------------------------------------------------------------
Write-Step "Qwen2.5-Omni-3B modelleri indiriliyor (toplam ~3.4 GB, biraz surer)"

$hf = "https://huggingface.co/ggml-org/Qwen2.5-Omni-3B-GGUF/resolve/main"
Get-RemoteFile -Url "$hf/Qwen2.5-Omni-3B-Q4_K_M.gguf" -Dest (Join-Path $modelsDir "Qwen2.5-Omni-3B-Q4_K_M.gguf")
Get-RemoteFile -Url "$hf/mmproj-Qwen2.5-Omni-3B-Q8_0.gguf" -Dest (Join-Path $modelsDir "mmproj-Qwen2.5-Omni-3B-Q8_0.gguf")
Write-Ok "Modeller hazir"

# ---------------------------------------------------------------------------
# 3) Piper TTS + Turkce ses
# ---------------------------------------------------------------------------
Write-Step "Piper TTS indiriliyor"

$piperDir = Join-Path $ttsDir "piper"
if ((Test-Path (Join-Path $piperDir "piper.exe")) -and -not $Force) {
    Write-Ok "Piper zaten var, atlandi"
} else {
    $piperZip = Join-Path $tmpDir "piper.zip"
    Get-RemoteFile -Url "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip" -Dest $piperZip
    Expand-ZipTo -Zip $piperZip -Dest $piperDir
    if (-not (Test-Path (Join-Path $piperDir "piper.exe"))) {
        throw "piper.exe bulunamadi. Arsiv yapisi beklenenden farkli."
    }
    Write-Ok "Piper hazir"
}

Write-Step "Turkce ses modeli indiriliyor (~60 MB)"
$voiceBase = "https://huggingface.co/rhasspy/piper-voices/resolve/main/tr/tr_TR/dfki/medium"
Get-RemoteFile -Url "$voiceBase/tr_TR-dfki-medium.onnx"      -Dest (Join-Path $ttsDir "tr_TR-dfki-medium.onnx")
Get-RemoteFile -Url "$voiceBase/tr_TR-dfki-medium.onnx.json" -Dest (Join-Path $ttsDir "tr_TR-dfki-medium.onnx.json")
Write-Ok "Ses modeli hazir"

# ---------------------------------------------------------------------------
# 4) Ozet
# ---------------------------------------------------------------------------
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Step "Kurulum tamamlandi"
$total = (Get-ChildItem $llamaDir, $modelsDir, $ttsDir -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Ok ("Toplam boyut: {0:N2} GB" -f $total)
Write-Host ""
Write-Host "  Simdi anlat.cmd dosyasina cift tiklayarak baslayabilirsiniz." -ForegroundColor White
Write-Host "  Komut satiri:  .\anlat.cmd ornek.jpg sakin" -ForegroundColor DarkGray
Write-Host ""
