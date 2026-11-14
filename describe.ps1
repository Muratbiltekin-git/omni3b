# describe.ps1 -- Resmi Turkce anlatir ve secilen tonla seslendirir.
#
# Kullanim:
#   .\describe.ps1 -Image "foto.jpg"
#   .\describe.ps1 -Image "foto.jpg" -Tone sakin
#   .\describe.ps1 -Image "foto.jpg" -Tone enerjik -Repeat 2
#   .\describe.ps1 -Image "foto.jpg" -Tone dramatik -Question "Bu manzara neresi?"
#   .\describe.ps1 -Image "foto.jpg" -Style "Kisa ve esprili konusurum, renkleri onemserim."
#   .\describe.ps1 -ListTones
#
# Kisisel tarz: proje klasorundeki "benim-tarzim.txt" dosyasi varsa otomatik
# kullanilir. -NoStyle ile bu seferlik yok sayilir.

param(
    [string]$Image,
    [string]$Question = "Bu görselde ne var? En fazla iki cümleyle, doğal konuşma dilinde Türkçe anlat.",
    [string]$Style,
    [switch]$NoStyle,
    [ValidateSet("normal", "sakin", "hizli", "enerjik", "yavas", "dramatik", "sunucu", "cocuk")]
    [string]$Tone = "normal",
    [switch]$NoPlay,
    [int]$Repeat = 1,
    [switch]$ListTones,
    [switch]$AllTones
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# Ton tanimlari
#   Length  : konusma hizi      (kucuk = hizli)
#   Noise   : tonlama cesitliligi (buyuk = daha canli/oynak)
#   NoiseW  : hece suresi degiskenligi (buyuk = daha ritmik)
#   Silence : cumleler arasi duraklama (saniye)
#   Pitch   : perde carpani (1.0 notr, >1 ince, <1 kalin)
# ---------------------------------------------------------------------------
$Tones = [ordered]@{
    normal   = @{ Length = 1.00; Noise = 0.667; NoiseW = 0.80; Silence = 0.20; Pitch = 1.00; Aciklama = "Dengeli, notr anlatim" }
    sakin    = @{ Length = 1.18; Noise = 0.35;  NoiseW = 0.55; Silence = 0.35; Pitch = 0.96; Aciklama = "Yavas, yumusak, dinlendirici" }
    hizli    = @{ Length = 0.82; Noise = 0.70;  NoiseW = 0.85; Silence = 0.10; Pitch = 1.00; Aciklama = "Hizli haber spikeri" }
    enerjik  = @{ Length = 0.90; Noise = 0.90;  NoiseW = 1.00; Silence = 0.12; Pitch = 1.05; Aciklama = "Canli, coskulu, ince" }
    yavas    = @{ Length = 1.35; Noise = 0.50;  NoiseW = 0.60; Silence = 0.40; Pitch = 1.00; Aciklama = "Ogretmen gibi, cok net" }
    dramatik = @{ Length = 1.10; Noise = 1.00;  NoiseW = 1.10; Silence = 0.55; Pitch = 0.94; Aciklama = "Derin, duraksamali, kalin" }
    sunucu   = @{ Length = 0.95; Noise = 0.55;  NoiseW = 0.75; Silence = 0.25; Pitch = 1.00; Aciklama = "Notr profesyonel sunucu" }
    cocuk    = @{ Length = 1.05; Noise = 1.00;  NoiseW = 1.00; Silence = 0.15; Pitch = 1.12; Aciklama = "Ince, hareketli, merakli" }
}

if ($ListTones) {
    Write-Host "`nKullanilabilir tonlar:`n" -ForegroundColor Cyan
    foreach ($k in $Tones.Keys) {
        "  {0,-10} {1}" -f $k, $Tones[$k].Aciklama | Write-Host
    }
    Write-Host "`nOrnek: .\describe.ps1 -Image foto.jpg -Tone sakin`n" -ForegroundColor DarkGray
    return
}

if ([string]::IsNullOrWhiteSpace($Image)) { throw "Resim belirtilmedi. -Image parametresini kullanin veya -ListTones yazin." }

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$model  = Join-Path $root "models\Qwen2.5-Omni-3B-Q4_K_M.gguf"
$mmproj = Join-Path $root "models\mmproj-Qwen2.5-Omni-3B-Q8_0.gguf"
$llama  = Join-Path $root "llama\llama-mtmd-cli.exe"
$piper  = Join-Path $root "tts\piper\piper.exe"
$voice  = Join-Path $root "tts\tr_TR-dfki-medium.onnx"

# ---------------------------------------------------------------------------
# Kisisel anlatim tarzi
#   Oncelik: -Style parametresi  >  benim-tarzim.txt  >  tarz yok
# ---------------------------------------------------------------------------
$styleFile = Join-Path $root "benim-tarzim.txt"
$styleText = ""
if (-not $NoStyle) {
    if (-not [string]::IsNullOrWhiteSpace($Style)) {
        $styleText = ($Style -replace '\s+', ' ').Trim()
    } elseif (Test-Path $styleFile) {
        $styleText = ((Get-Content $styleFile -Encoding UTF8 -Raw) -replace '\s+', ' ').Trim()
    }
}

$rules = "Kurallar: en fazla iki cümle, doğal konuşma dili, Türkçe. 'Görselde', 'resimde', 'fotoğrafta' diye başlama."
$promptParts = @("Sen kullanıcının ağzından konuşuyorsun.")
if ($styleText) { $promptParts += "Kullanıcının anlatım tarzı: $styleText" }
$promptParts += "Görev: $Question"
$promptParts += $rules
$promptText = ($promptParts -join " ")

foreach ($f in @($llama, $model, $mmproj, $piper, $voice)) {
    if (-not (Test-Path $f)) { throw "Eksik dosya: $f" }
}
if (-not (Test-Path $Image)) { throw "Resim bulunamadi: $Image" }
$Image = (Resolve-Path $Image).Path

# WAV basligindaki ornekleme hizini degistirir -> perde kaydirma.
# Ses verisi ayni kalir, sadece calinma hizi degisir.
function Set-WavPitch([string]$Path, [double]$Factor) {
    if ([math]::Abs($Factor - 1.0) -lt 0.001) { return }

    $b = [System.IO.File]::ReadAllBytes($Path)
    if ([System.Text.Encoding]::ASCII.GetString($b, 0, 4) -ne "RIFF") { return }

    $pos = 12
    while ($pos -lt $b.Length - 8) {
        $id = [System.Text.Encoding]::ASCII.GetString($b, $pos, 4)
        $size = [BitConverter]::ToInt32($b, $pos + 4)
        if ($id -eq "fmt ") {
            $fmtPos = $pos + 8
            break
        }
        $pos += 8 + $size + ($size % 2)
    }
    if (-not $fmtPos) { return }

    $rate     = [BitConverter]::ToInt32($b, $fmtPos + 4)
    $blockAl  = [BitConverter]::ToInt16($b, $fmtPos + 12)
    $newRate  = [int][math]::Round($rate * $Factor)

    [Array]::Copy([BitConverter]::GetBytes($newRate), 0, $b, $fmtPos + 4, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]($newRate * $blockAl)), 0, $b, $fmtPos + 8, 4)
    [System.IO.File]::WriteAllBytes($Path, $b)
}

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$t = $Tones[$Tone]

# ---------- 1) Gorsel -> metin ----------
Write-Host "[1/4] Gorsel analiz ediliyor..." -ForegroundColor Cyan
if ($styleText) { Write-Host "      Tarz: $styleText" -ForegroundColor DarkGray }

$tmpDir = Join-Path $env:TEMP ("omni3b-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$promptFile = Join-Path $tmpDir "prompt.txt"
$outFile    = Join-Path $tmpDir "out.txt"
$errFile    = Join-Path $tmpDir "err.txt"

# Turkce karakterler komut satirinda bozulmasin diye prompt dosyadan veriliyor
[System.IO.File]::WriteAllText($promptFile, $promptText, (New-Object System.Text.UTF8Encoding($false)))

$args1 = @(
    "-m", "`"$model`"", "--mmproj", "`"$mmproj`"",
    "-ngl", "99", "-fit", "off", "-c", "2048",
    "--image", "`"$Image`"",
    "--temp", "0", "--repeat-penalty", "1.1", "--repeat-last-n", "128",
    "-n", "200", "-f", "`"$promptFile`""
) -join " "

$p = Start-Process -FilePath $llama -ArgumentList $args1 -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile

$text = (Get-Content $outFile -Encoding UTF8 -Raw)
Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

$text = ($text -replace '\s+', ' ').Trim()
if ([string]::IsNullOrWhiteSpace($text)) {
    throw "Model bos yanit dondurdu. (llama cikis kodu: $($p.ExitCode))"
}

# Tekrar dongusu korumasi: ayni 8 kelimelik parca 3 kez gecerse kes
$words = $text -split ' '
if ($words.Count -ge 24) {
    for ($i = 0; $i -le $words.Count - 24; $i++) {
        $chunk = ($words[$i..($i + 7)] -join ' ')
        if ($chunk.Trim().Length -lt 8) { continue }
        $hits = ([regex]::Matches($text, [regex]::Escape($chunk))).Count
        if ($hits -ge 3) {
            $text = $text.Substring(0, $text.IndexOf($chunk, [StringComparison]::Ordinal)).TrimEnd(' ', ',', '-', ':')
            if (-not $text.EndsWith('.')) { $text += '.' }
            break
        }
    }
}

Write-Host "[2/4] Metin: $text" -ForegroundColor Green

$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $root "output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Metin -> ses (tek bir ton icin)
function New-Speech {
    param([string]$ToneName, [string]$BasePath)

    $tt = $Tones[$ToneName]
    $wav = "$BasePath.wav"
    $txt = "$BasePath.txt"
    [System.IO.File]::WriteAllText($txt, $text, (New-Object System.Text.UTF8Encoding($false)))

    # Perde kaydirmadan sonra sure degismesin diye length_scale telafi edilir
    $lengthScale = $tt.Length * $tt.Pitch

    $extra = @(
        "--noise_scale",      $tt.Noise.ToString($inv),
        "--length_scale",     $lengthScale.ToString($inv),
        "--noise_w",          $tt.NoiseW.ToString($inv),
        "--sentence_silence", $tt.Silence.ToString($inv)
    ) -join " "

    $cmdLine = 'chcp 65001 >nul & type "{0}" | "{1}" -m "{2}" -f "{3}" {4} 2>nul' -f $txt, $piper, $voice, $wav, $extra
    cmd /c $cmdLine
    if (-not (Test-Path $wav)) { throw "Ses dosyasi olusturulamadi: $wav" }

    Set-WavPitch -Path $wav -Factor $tt.Pitch
    return $wav
}

# WAV suresini okur
function Get-WavSeconds([string]$Path) {
    $hdr = [System.IO.File]::ReadAllBytes($Path)
    $pos = 12
    $dataSize = 0; $byteRate = 0
    while ($pos -lt $hdr.Length - 8) {
        $id  = [System.Text.Encoding]::ASCII.GetString($hdr, $pos, 4)
        $sz  = [BitConverter]::ToInt32($hdr, $pos + 4)
        if ($id -eq "fmt ")  { $byteRate = [BitConverter]::ToInt32($hdr, $pos + 12) }
        if ($id -eq "data")  { $dataSize = $sz; break }
        $pos += 8 + $sz + ($sz % 2)
    }
    if ($byteRate -le 0) { return 0 }
    return [math]::Round($dataSize / $byteRate, 1)
}

# ---------- 2) Ton(lar) -> ses ----------
$targets = if ($AllTones) { @($Tones.Keys) } else { @($Tone) }
$made = @()

foreach ($tn in $targets) {
    Write-Host "[3/4] Seslendiriliyor -> $tn ($($Tones[$tn].Aciklama))" -ForegroundColor Cyan
    $basePath = Join-Path $outDir "anlatim-$tn-$stamp"
    $w = New-Speech -ToneName $tn -BasePath $basePath
    $secs = Get-WavSeconds $w
    Write-Host "        $w (~$secs sn)" -ForegroundColor DarkGray
    $made += [pscustomobject]@{ Tone = $tn; File = $w; Secs = $secs }
}

Write-Host "[4/4] Tamamlandi: $($made.Count) dosya" -ForegroundColor Green

if (-not $NoPlay) {
    for ($i = 1; $i -le $Repeat; $i++) {
        foreach ($m in $made) {
            Write-Host "Oynatiliyor ($i/$Repeat) -> $($m.Tone)" -ForegroundColor Yellow
            $player = New-Object System.Media.SoundPlayer $m.File
            $player.PlaySync()
        }
    }
}

$made | ForEach-Object { Write-Output $_.File }
