# gui.ps1 -- Omni3B gorsel anlatici arayuzu (WinForms, modern)
# anlat.cmd tarafindan cagrilir. Dogrudan calistirmak icin:
#   powershell -STA -ExecutionPolicy Bypass -File gui.ps1
#
# Palet: charcoal black + royal blue + tangerine orange
# Ozellikler: gece/gunduz modu, hedef konusma suresi (1-50 sn), ton secimi

param()

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $root "cekirdek.ps1")

$model  = Join-Path $root "models\Qwen2.5-Omni-3B-Q4_K_M.gguf"
$mmproj = Join-Path $root "models\mmproj-Qwen2.5-Omni-3B-Q8_0.gguf"
$llama  = Join-Path $root "llama\llama-mtmd-cli.exe"
$piper  = Join-Path $root "tts\piper\piper.exe"
$voice  = Join-Path $root "tts\tr_TR-dfki-medium.onnx"
$outDir = Join-Path $root "output"
$styleFile = Join-Path $root "benim-tarzim.txt"

# ---------------------------------------------------------------------------
# PALET
# ---------------------------------------------------------------------------
function New-Palette([bool]$Dark) {
    if ($Dark) {
        @{
            Bg        = [System.Drawing.ColorTranslator]::FromHtml("#1B1B1E")   # charcoal black
            Surface   = [System.Drawing.ColorTranslator]::FromHtml("#242428")
            SurfaceHi = [System.Drawing.ColorTranslator]::FromHtml("#2E2E34")
            Border    = [System.Drawing.ColorTranslator]::FromHtml("#3A3A42")
            Text      = [System.Drawing.ColorTranslator]::FromHtml("#F2F2F5")
            Muted     = [System.Drawing.ColorTranslator]::FromHtml("#9C9CA8")
            Primary   = [System.Drawing.ColorTranslator]::FromHtml("#4169E1")   # royal blue
            PrimaryHi = [System.Drawing.ColorTranslator]::FromHtml("#5B7FEA")
            Accent    = [System.Drawing.ColorTranslator]::FromHtml("#F28500")   # tangerine orange
            AccentHi  = [System.Drawing.ColorTranslator]::FromHtml("#FFA23A")
            OnAccent  = [System.Drawing.ColorTranslator]::FromHtml("#151515")
            OnPrimary = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
            Header    = [System.Drawing.ColorTranslator]::FromHtml("#171719")
        }
    } else {
        @{
            Bg        = [System.Drawing.ColorTranslator]::FromHtml("#EEF1F8")
            Surface   = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
            SurfaceHi = [System.Drawing.ColorTranslator]::FromHtml("#E7EBF5")
            Border    = [System.Drawing.ColorTranslator]::FromHtml("#D3D9E8")
            Text      = [System.Drawing.ColorTranslator]::FromHtml("#1B1B1E")
            Muted     = [System.Drawing.ColorTranslator]::FromHtml("#6B6B78")
            Primary   = [System.Drawing.ColorTranslator]::FromHtml("#4169E1")
            PrimaryHi = [System.Drawing.ColorTranslator]::FromHtml("#3559C7")
            Accent    = [System.Drawing.ColorTranslator]::FromHtml("#F28500")
            AccentHi  = [System.Drawing.ColorTranslator]::FromHtml("#D97500")
            OnAccent  = [System.Drawing.ColorTranslator]::FromHtml("#1B1B1E")
            OnPrimary = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
            Header    = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
        }
    }
}

# ---------------------------------------------------------------------------
# Tonlar
# ---------------------------------------------------------------------------
$Tones = [ordered]@{
    normal   = @{ Length = 1.00; Noise = 0.667; NoiseW = 0.80; Silence = 0.20; Pitch = 1.00; Aciklama = "Dengeli, notr anlatim" }
    sakin    = @{ Length = 1.18; Noise = 0.35;  NoiseW = 0.55; Silence = 0.35; Pitch = 0.96; Aciklama = "Yavas, yumusak, dinlendirici" }
    hizli    = @{ Length = 0.82; Noise = 0.70;  NoiseW = 0.85; Silence = 0.10; Pitch = 1.00; Aciklama = "Hizli haber spikeri" }
    enerjik  = @{ Length = 0.90; Noise = 0.90;  NoiseW = 1.00; Silence = 0.12; Pitch = 1.05; Aciklama = "Canli, coskulu, ince" }
    yavas    = @{ Length = 1.35; Noise = 0.50;  NoiseW = 0.60; Silence = 0.40; Pitch = 1.00; Aciklama = "Ogretmen gibi, cok net" }
    dramatik = @{ Length = 1.10; Noise = 1.00;  NoiseW = 1.10; Silence = 0.55; Pitch = 0.94; Aciklama = "Derin, duraksamali, kalin" }
    sunucu   = @{ Length = 0.95; Noise = 0.55;  NoiseW = 0.75; Silence = 0.25; Pitch = 1.00; Aciklama = "Notr, profesyonel sunucu" }
    cocuk    = @{ Length = 1.05; Noise = 1.00;  NoiseW = 1.00; Silence = 0.15; Pitch = 1.12; Aciklama = "Ince, hareketli, merakli" }
}
$ToneOrder = @($Tones.Keys)
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# ---------------------------------------------------------------------------
# Ses yardimcilari
# ---------------------------------------------------------------------------
function Set-WavPitch([string]$Path, [double]$Factor) {
    if ([math]::Abs($Factor - 1.0) -lt 0.001) { return }
    $b = [System.IO.File]::ReadAllBytes($Path)
    if ([System.Text.Encoding]::ASCII.GetString($b, 0, 4) -ne "RIFF") { return }

    $pos = 12; $fmtPos = -1
    while ($pos -lt $b.Length - 8) {
        $id   = [System.Text.Encoding]::ASCII.GetString($b, $pos, 4)
        $size = [BitConverter]::ToInt32($b, $pos + 4)
        if ($id -eq "fmt ") { $fmtPos = $pos + 8; break }
        if ($size -lt 0) { break }
        $pos += 8 + $size + ($size % 2)
    }
    if ($fmtPos -lt 0) { return }

    $rate    = [BitConverter]::ToInt32($b, $fmtPos + 4)
    $blockAl = [BitConverter]::ToInt16($b, $fmtPos + 12)
    $newRate = [int][math]::Round($rate * $Factor)

    [Array]::Copy([BitConverter]::GetBytes($newRate), 0, $b, $fmtPos + 4, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]($newRate * $blockAl)), 0, $b, $fmtPos + 8, 4)
    [System.IO.File]::WriteAllBytes($Path, $b)
}

function Get-WavSeconds([string]$Path) {
    $hdr = [System.IO.File]::ReadAllBytes($Path)
    $pos = 12; $dataSize = 0; $byteRate = 0
    while ($pos -lt $hdr.Length - 8) {
        $id = [System.Text.Encoding]::ASCII.GetString($hdr, $pos, 4)
        $sz = [BitConverter]::ToInt32($hdr, $pos + 4)
        if ($id -eq "fmt ") { $byteRate = [BitConverter]::ToInt32($hdr, $pos + 12) }
        if ($id -eq "data") { $dataSize = $sz; break }
        if ($sz -lt 0) { break }
        $pos += 8 + $sz + ($sz % 2)
    }
    if ($byteRate -le 0) { return 0 }
    return [math]::Round($dataSize / $byteRate, 2)
}

# Medyayi modele verir ve anlatim metnini dondurur.
#   Donus: @{ Text = "..."; Sources = @() }
function Get-ContentSummary {
    param(
        [Parameter(Mandatory)][string]$MediaPath,
        [Parameter(Mandatory)][string]$MediaKind,
        [string]$Question,
        [string]$Style,
        [string]$Level = "normal",
        [bool]$Research = $false
    )

    $profile = Get-LevelProfile $Level
    $context = 2048
    if ($Level -eq "detayli" -or $Research) { $context = 3072 }

    $frameDir = $null
    $framePaths = @()
    $mediaArg = $MediaPath
    $extraText = ""

    switch ($MediaKind) {
        "video" {
            $vf = Get-VideoFrames -Path $MediaPath -Count 4
            $frameDir = $vf.Dir
            if (-not $vf.Ok) { throw $vf.Error }
            $framePaths = $vf.Frames
            $mediaArg = $null
        }
        "text" {
            $extraText = Get-TextPreview -Path $MediaPath
            if ([string]::IsNullOrWhiteSpace($extraText)) { throw "Metin dosyasi okunamadi veya bos." }
            $mediaArg = $null
        }
    }

    $researchText = ""
    $sources = @()
    if ($Research) {
        $wr = Get-WebResearch -Query $Question
        if ($wr.Ok) {
            $researchText = $wr.Text
            $sources = $wr.Sources
        }
    }

    $prompt = New-OmniPrompt -Question $Question -Style $Style -Level $Level `
                -ResearchText $researchText -Sources $sources `
                -MediaKind $MediaKind -ExtraText $extraText

    try {
        $text = Invoke-OmniModel -Prompt $prompt `
                    -LlamaPath $llama -ModelPath $model -MmprojPath $mmproj `
                    -MediaPath $mediaArg -MediaKind $MediaKind -FramePaths $framePaths `
                    -MaxTokens $profile.Tokens -Context $context
    } finally {
        if ($frameDir) { Remove-Item $frameDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    return [pscustomobject]@{ Text = $text; Sources = $sources }
}

# Hedef sureye gore konusma hizini ayarlayarak ses uretir.
function New-SpeechFile {
    param(
        [string]$Text,
        [string]$ToneName,
        [string]$BasePath,
        [double]$TargetSeconds = 0
    )

    $t = $Tones[$ToneName]
    $txtFile = "$BasePath.txt"
    $wavFile = "$BasePath.wav"
    [System.IO.File]::WriteAllText($txtFile, $Text, (New-Object System.Text.UTF8Encoding($false)))

    # perde kaydirmayi telafi eden taban hiz
    $lengthScale = $t.Length * $t.Pitch
    $secs = 0
    $attempts = 0

    while ($attempts -lt 3) {
        $attempts++
        $extra = @(
            "--noise_scale",      $t.Noise.ToString($inv),
            "--length_scale",     $lengthScale.ToString($inv),
            "--noise_w",          $t.NoiseW.ToString($inv),
            "--sentence_silence", $t.Silence.ToString($inv)
        ) -join " "

        $cmdLine = 'chcp 65001 >nul & type "{0}" | "{1}" -m "{2}" -f "{3}" {4} 2>nul' -f $txtFile, $piper, $voice, $wavFile, $extra
        cmd /c $cmdLine
        if (-not (Test-Path $wavFile)) { throw "Ses dosyasi olusturulamadi." }

        Set-WavPitch -Path $wavFile -Factor $t.Pitch
        $secs = Get-WavSeconds $wavFile

        if ($TargetSeconds -le 0) { break }
        if ($secs -le 0) { break }

        $ratio = $TargetSeconds / $secs
        if ([math]::Abs($ratio - 1.0) -le 0.07) { break }

        $lengthScale = [math]::Max(0.42, [math]::Min(3.4, $lengthScale * $ratio))
    }

    return [pscustomobject]@{
        Path      = $wavFile
        Seconds   = $secs
        Target    = $TargetSeconds
        Attempts  = $attempts
        HitTarget = ($TargetSeconds -le 0) -or ([math]::Abs($TargetSeconds - $secs) -le [math]::Max(1.0, $TargetSeconds * 0.12))
    }
}

# ---------------------------------------------------------------------------
# ARAYUZ
# ---------------------------------------------------------------------------
$script:dark = $true
$P = New-Palette $true

$form = New-Object System.Windows.Forms.Form
$form.Text = "Omni3B - Gorsel Anlatici"
$form.Size = New-Object System.Drawing.Size(792, 820)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = $P.Bg

# --- Ozel baslik cubugu ---
$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.Size = New-Object System.Drawing.Size(792, 58)
$header.BackColor = $P.Header
$form.Controls.Add($header)

$accentLine = New-Object System.Windows.Forms.Panel
$accentLine.Location = New-Object System.Drawing.Point(0, 58)
$accentLine.Size = New-Object System.Drawing.Size(792, 3)
$accentLine.BackColor = $P.Accent
$form.Controls.Add($accentLine)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "OMNI3B"
$lblTitle.Location = New-Object System.Drawing.Point(20, 12)
$lblTitle.Size = New-Object System.Drawing.Size(140, 22)
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$header.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Görsel Anlatıcı"
$lblSub.Location = New-Object System.Drawing.Point(22, 33)
$lblSub.Size = New-Object System.Drawing.Size(200, 18)
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$header.Controls.Add($lblSub)

$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Text = "Gece"
$btnTheme.Location = New-Object System.Drawing.Point(596, 15)
$btnTheme.Size = New-Object System.Drawing.Size(78, 28)
$btnTheme.FlatStyle = "Flat"
$btnTheme.FlatAppearance.BorderSize = 0
$btnTheme.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$btnTheme.Cursor = "Hand"
$header.Controls.Add($btnTheme)

$btnMin = New-Object System.Windows.Forms.Button
$btnMin.Text = "–"
$btnMin.Location = New-Object System.Drawing.Point(680, 15)
$btnMin.Size = New-Object System.Drawing.Size(44, 28)
$btnMin.FlatStyle = "Flat"
$btnMin.FlatAppearance.BorderSize = 0
$btnMin.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnMin.Cursor = "Hand"
$header.Controls.Add($btnMin)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "✕"
$btnClose.Location = New-Object System.Drawing.Point(728, 15)
$btnClose.Size = New-Object System.Drawing.Size(44, 28)
$btnClose.FlatStyle = "Flat"
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnClose.Cursor = "Hand"
$header.Controls.Add($btnClose)

# --- Ust satir: gorsel sec ---
$btnPick = New-Object System.Windows.Forms.Button
$btnPick.Text = "Görsel Seç"
$btnPick.Location = New-Object System.Drawing.Point(16, 74)
$btnPick.Size = New-Object System.Drawing.Size(132, 38)
$btnPick.FlatStyle = "Flat"
$btnPick.FlatAppearance.BorderSize = 0
$btnPick.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
$btnPick.Cursor = "Hand"
$form.Controls.Add($btnPick)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Henüz görsel seçilmedi"
$lblPath.Location = New-Object System.Drawing.Point(160, 84)
$lblPath.Size = New-Object System.Drawing.Size(600, 20)
$lblPath.AutoEllipsis = $true
$form.Controls.Add($lblPath)

# --- Kartlar ---
$cardLeft = New-Object System.Windows.Forms.Panel
$cardLeft.Location = New-Object System.Drawing.Point(16, 124)
$cardLeft.Size = New-Object System.Drawing.Size(372, 366)
$form.Controls.Add($cardLeft)

$cardRight = New-Object System.Windows.Forms.Panel
$cardRight.Location = New-Object System.Drawing.Point(400, 124)
$cardRight.Size = New-Object System.Drawing.Size(376, 366)
$form.Controls.Add($cardRight)

$pic = New-Object System.Windows.Forms.PictureBox
$pic.Location = New-Object System.Drawing.Point(10, 10)
$pic.Size = New-Object System.Drawing.Size(352, 346)
$pic.SizeMode = "Zoom"
$pic.BackColor = $P.SurfaceHi
$cardLeft.Controls.Add($pic)

$lblNoImg = New-Object System.Windows.Forms.Label
$lblNoImg.Text = "Önizleme"
$lblNoImg.Location = New-Object System.Drawing.Point(10, 10)
$lblNoImg.Size = New-Object System.Drawing.Size(352, 346)
$lblNoImg.TextAlign = "MiddleCenter"
$lblNoImg.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cardLeft.Controls.Add($lblNoImg)
$lblNoImg.BringToFront()

# --- Sag kart: ton ---
$lblTone = New-Object System.Windows.Forms.Label
$lblTone.Text = "SES TONU"
$lblTone.Location = New-Object System.Drawing.Point(14, 12)
$lblTone.Size = New-Object System.Drawing.Size(200, 16)
$lblTone.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($lblTone)

$cmbTone = New-Object System.Windows.Forms.ComboBox
$cmbTone.Location = New-Object System.Drawing.Point(14, 30)
$cmbTone.Size = New-Object System.Drawing.Size(348, 26)
$cmbTone.DropDownStyle = "DropDownList"
$cmbTone.FlatStyle = "Flat"
foreach ($k in $ToneOrder) { [void]$cmbTone.Items.Add("$k  -  $($Tones[$k].Aciklama)") }
$cmbTone.SelectedIndex = 0
$cardRight.Controls.Add($cmbTone)

# --- Anlatim uzunlugu ---
$lblLevel = New-Object System.Windows.Forms.Label
$lblLevel.Text = "ANLATIM UZUNLUĞU"
$lblLevel.Location = New-Object System.Drawing.Point(14, 58)
$lblLevel.Size = New-Object System.Drawing.Size(200, 16)
$lblLevel.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($lblLevel)

$cmbLevel = New-Object System.Windows.Forms.ComboBox
$cmbLevel.Location = New-Object System.Drawing.Point(14, 76)
$cmbLevel.Size = New-Object System.Drawing.Size(348, 24)
$cmbLevel.DropDownStyle = "DropDownList"
$cmbLevel.FlatStyle = "Flat"
[void]$cmbLevel.Items.Add("kisa    -  tek cümle")
[void]$cmbLevel.Items.Add("normal  -  en fazla iki cümle")
[void]$cmbLevel.Items.Add("detayli -  4-6 cümle, ayrıntılı")
$cmbLevel.SelectedIndex = 1
$cardRight.Controls.Add($cmbLevel)

# --- Sure ---
$lblDur = New-Object System.Windows.Forms.Label
$lblDur.Text = "KONUŞMA SÜRESİ"
$lblDur.Location = New-Object System.Drawing.Point(14, 106)
$lblDur.Size = New-Object System.Drawing.Size(200, 16)
$lblDur.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($lblDur)

$numDur = New-Object System.Windows.Forms.NumericUpDown
$numDur.Location = New-Object System.Drawing.Point(14, 124)
$numDur.Size = New-Object System.Drawing.Size(78, 26)
$numDur.Minimum = 1
$numDur.Maximum = 50
$numDur.Value = 15
$numDur.BorderStyle = "FixedSingle"
$cardRight.Controls.Add($numDur)

$lblDurUnit = New-Object System.Windows.Forms.Label
$lblDurUnit.Text = "saniye"
$lblDurUnit.Location = New-Object System.Drawing.Point(98, 128)
$lblDurUnit.Size = New-Object System.Drawing.Size(46, 20)
$cardRight.Controls.Add($lblDurUnit)

$lblDurHint = New-Object System.Windows.Forms.Label
$lblDurHint.Text = "1-50 sn. Model bu süreye yakın konuşur."
$lblDurHint.Location = New-Object System.Drawing.Point(146, 128)
$lblDurHint.Size = New-Object System.Drawing.Size(216, 20)
$lblDurHint.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($lblDurHint)

$chkNatural = New-Object System.Windows.Forms.CheckBox
$chkNatural.Text = "Doğal hızda bırak (süre ayarı kapalı)"
$chkNatural.Location = New-Object System.Drawing.Point(14, 150)
$chkNatural.Size = New-Object System.Drawing.Size(300, 18)
$chkNatural.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($chkNatural)

# --- Soru ---
$lblQ = New-Object System.Windows.Forms.Label
$lblQ.Text = "SORU / YÖNERGE"
$lblQ.Location = New-Object System.Drawing.Point(14, 176)
$lblQ.Size = New-Object System.Drawing.Size(240, 16)
$lblQ.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($lblQ)

$txtQ = New-Object System.Windows.Forms.TextBox
$txtQ.Location = New-Object System.Drawing.Point(14, 194)
$txtQ.Size = New-Object System.Drawing.Size(348, 48)
$txtQ.Multiline = $true
$txtQ.ScrollBars = "Vertical"
$txtQ.BorderStyle = "FixedSingle"
$txtQ.Text = "Bu görselde ne var? Kısa ve doğal Türkçeyle anlat."
$cardRight.Controls.Add($txtQ)

# --- Internet arastirmasi ---
$chkResearch = New-Object System.Windows.Forms.CheckBox
$chkResearch.Text = "Emin olmadığı / güncel konuları internette araştır"
$chkResearch.Location = New-Object System.Drawing.Point(14, 248)
$chkResearch.Size = New-Object System.Drawing.Size(348, 20)
$chkResearch.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$cardRight.Controls.Add($chkResearch)

$btnAnalyze = New-Object System.Windows.Forms.Button
$btnAnalyze.Text = "ANLAT VE DİNLE"
$btnAnalyze.Location = New-Object System.Drawing.Point(14, 276)
$btnAnalyze.Size = New-Object System.Drawing.Size(348, 40)
$btnAnalyze.FlatStyle = "Flat"
$btnAnalyze.FlatAppearance.BorderSize = 0
$btnAnalyze.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5, [System.Drawing.FontStyle]::Bold)
$btnAnalyze.Cursor = "Hand"
$btnAnalyze.Enabled = $false
$cardRight.Controls.Add($btnAnalyze)

$btnReplay = New-Object System.Windows.Forms.Button
$btnReplay.Text = "Bu tonla seslendir"
$btnReplay.Location = New-Object System.Drawing.Point(14, 324)
$btnReplay.Size = New-Object System.Drawing.Size(186, 30)
$btnReplay.FlatStyle = "Flat"
$btnReplay.FlatAppearance.BorderSize = 0
$btnReplay.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnReplay.Cursor = "Hand"
$btnReplay.Enabled = $false
$cardRight.Controls.Add($btnReplay)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Durdur"
$btnStop.Location = New-Object System.Drawing.Point(208, 324)
$btnStop.Size = New-Object System.Drawing.Size(74, 30)
$btnStop.FlatStyle = "Flat"
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnStop.Cursor = "Hand"
$btnStop.Enabled = $false
$cardRight.Controls.Add($btnStop)

$btnFolder = New-Object System.Windows.Forms.Button
$btnFolder.Text = "Klasör"
$btnFolder.Location = New-Object System.Drawing.Point(290, 324)
$btnFolder.Size = New-Object System.Drawing.Size(72, 30)
$btnFolder.FlatStyle = "Flat"
$btnFolder.FlatAppearance.BorderSize = 0
$btnFolder.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$btnFolder.Cursor = "Hand"
$cardRight.Controls.Add($btnFolder)

# --- Kisisel anlatim tarzi (kalici) ---
$lblStyle = New-Object System.Windows.Forms.Label
$lblStyle.Text = "ANLATIM TARZIM  —  nasıl konuşayım, neyi önemseyeyim? (bir kez yazın, kaydedilir)"
$lblStyle.Location = New-Object System.Drawing.Point(18, 502)
$lblStyle.Size = New-Object System.Drawing.Size(760, 16)
$lblStyle.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$form.Controls.Add($lblStyle)

$txtStyle = New-Object System.Windows.Forms.TextBox
$txtStyle.Location = New-Object System.Drawing.Point(16, 520)
$txtStyle.Size = New-Object System.Drawing.Size(760, 64)
$txtStyle.Multiline = $true
$txtStyle.ScrollBars = "Vertical"
$txtStyle.BorderStyle = "FixedSingle"
$form.Controls.Add($txtStyle)

# --- Alt: cikti ---
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "ANLATIM METNİ"
$lblOut.Location = New-Object System.Drawing.Point(18, 588)
$lblOut.Size = New-Object System.Drawing.Size(240, 16)
$lblOut.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$form.Controls.Add($lblOut)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location = New-Object System.Drawing.Point(16, 606)
$txtOut.Size = New-Object System.Drawing.Size(760, 96)
$txtOut.Multiline = $true
$txtOut.ReadOnly = $true
$txtOut.ScrollBars = "Vertical"
$txtOut.BorderStyle = "FixedSingle"
$form.Controls.Add($txtOut)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Hazır. Bir görsel, ses, video veya metin dosyası seçerek başlayın."
$lblStatus.Location = New-Object System.Drawing.Point(50, 712)
$lblStatus.Size = New-Object System.Drawing.Size(724, 22)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)
$form.Controls.Add($lblStatus)

# --- Loader (donen halka + animasyonlu noktalar) ---
$spinner = New-Object System.Windows.Forms.PictureBox
$spinner.Location = New-Object System.Drawing.Point(16, 710)
$spinner.Size = New-Object System.Drawing.Size(26, 26)
$spinner.SizeMode = "Zoom"
$spinner.Visible = $false
$form.Controls.Add($spinner)

$script:spinAngle   = 0
$script:spinDots    = 0
$script:spinBaseMsg = ""
$script:spinner     = $spinner

$spinTimer = New-Object System.Windows.Forms.Timer
$spinTimer.Interval = 110
$spinTimer.Add_Tick({
    $pal = New-Palette $script:dark

    $script:spinAngle = ($script:spinAngle + 26) % 360

    $bmp = New-Object System.Drawing.Bitmap 52, 52
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear($pal.Bg)

    $penBg = New-Object System.Drawing.Pen($pal.Border, [float]5)
    $penFg = New-Object System.Drawing.Pen($pal.Primary, [float]5)
    $penFg.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penFg.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

    $g.DrawEllipse($penBg, 7, 7, 38, 38)
    $g.DrawArc($penFg, 7, 7, 38, 38, [float]$script:spinAngle, [float]85)

    $penBg.Dispose(); $penFg.Dispose(); $g.Dispose()

    if ($script:spinner.Image) { $script:spinner.Image.Dispose() }
    $script:spinner.Image = $bmp

    $script:spinDots = ($script:spinDots + 1) % 4
    $dots = "." * $script:spinDots
    $script:spinBaseMsg = $script:spinBaseMsg.TrimEnd('.')
    $lblStatus.Text = $script:spinBaseMsg + $dots
})

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(16, 738)
$progress.Size = New-Object System.Drawing.Size(760, 6)
$progress.Style = "Marquee"
$progress.MarqueeAnimationSpeed = 0
$form.Controls.Add($progress)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "İpucu: Görsel, ses, video (ffmpeg gerekir) veya metin yükleyebilirsiniz. 'Anlatım Uzunluğu' ile kısa/normal/detaylı seçin; emin olunmayan veya güncel bilgi için 'internette araştır' işaretleyin. 'Anlatım Tarzım' kutusu kalıcıdır."
$lblHint.Location = New-Object System.Drawing.Point(18, 750)
$lblHint.Size = New-Object System.Drawing.Size(756, 36)
$lblHint.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
$form.Controls.Add($lblHint)

# ---------------------------------------------------------------------------
# TEMA UYGULAMA
# ---------------------------------------------------------------------------
function Apply-Theme([bool]$Dark) {
    $script:dark = $Dark
    $p = New-Palette $Dark

    $form.BackColor        = $p.Bg
    $header.BackColor      = $p.Header
    $accentLine.BackColor  = $p.Accent
    $spinner.BackColor     = $p.Bg
    $lblTitle.ForeColor    = $p.Text
    $lblSub.ForeColor      = $p.Accent

    foreach ($b in @($btnTheme, $btnMin)) {
        $b.BackColor = $p.Header
        $b.ForeColor = $p.Muted
        $b.FlatAppearance.MouseOverBackColor = $p.SurfaceHi
    }
    $btnClose.BackColor = $p.Header
    $btnClose.ForeColor = $p.Muted
    $btnClose.FlatAppearance.MouseOverBackColor = [System.Drawing.ColorTranslator]::FromHtml("#C42B1C")

    $btnPick.BackColor = $p.Accent
    $btnPick.ForeColor = $p.OnAccent
    $btnPick.FlatAppearance.MouseOverBackColor = $p.AccentHi

    $lblPath.ForeColor = $p.Muted

    $cardLeft.BackColor  = $p.Surface
    $cardRight.BackColor = $p.Surface
    $pic.BackColor       = $p.SurfaceHi
    $lblNoImg.ForeColor  = $p.Muted
    $lblNoImg.BackColor  = $p.SurfaceHi

    foreach ($l in @($lblTone, $lblLevel, $lblDur, $lblQ, $lblOut, $lblStyle)) { $l.ForeColor = $p.Muted }

    foreach ($c in @($cmbTone, $cmbLevel, $numDur, $txtQ, $txtOut, $txtStyle)) {
        $c.BackColor = $p.SurfaceHi
        $c.ForeColor = $p.Text
    }

    foreach ($l in @($lblDurUnit, $lblDurHint, $chkNatural, $chkResearch, $lblHint)) { $l.ForeColor = $p.Muted }

    $btnAnalyze.BackColor = $p.Primary
    $btnAnalyze.ForeColor = $p.OnPrimary
    $btnAnalyze.FlatAppearance.MouseOverBackColor = $p.PrimaryHi

    $btnReplay.BackColor = $p.SurfaceHi
    $btnReplay.ForeColor = $p.Accent
    $btnReplay.FlatAppearance.MouseOverBackColor = $p.Border

    $btnStop.BackColor = $p.SurfaceHi
    $btnStop.ForeColor = $p.Text
    $btnStop.FlatAppearance.MouseOverBackColor = $p.Border

    $btnFolder.BackColor = $p.SurfaceHi
    $btnFolder.ForeColor = $p.Text
    $btnFolder.FlatAppearance.MouseOverBackColor = $p.Border

    $lblStatus.ForeColor = $p.Primary
    $lblHint.ForeColor   = $p.Muted

    if ($Dark) { $themeLabel = "Gece" } else { $themeLabel = "Gündüz" }
    $btnTheme.Text = $themeLabel
    $form.Refresh()
}

# ---------------------------------------------------------------------------
# Durum / yardimcilar
# ---------------------------------------------------------------------------
$script:imagePath = $null
$script:mediaKind = $null
$script:lastText  = $null
$script:player    = New-Object System.Media.SoundPlayer
$script:dragging  = $false
$script:dragPoint = New-Object System.Drawing.Point(0, 0)

# Kisisel tarzi diske kaydeder (bos ise dosyayi siler) ve metni dondurur.
function Save-Style {
    $t = $txtStyle.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) {
        if (Test-Path $styleFile) { Remove-Item $styleFile -Force -ErrorAction SilentlyContinue }
        return ""
    }
    [System.IO.File]::WriteAllText($styleFile, $t, (New-Object System.Text.UTF8Encoding($false)))
    return $t
}

# Onceki oturumda kaydedilen tarzi yukle; yoksa makul bir baslangic tarzi koy
if (Test-Path $styleFile) {
    try { $txtStyle.Text = (Get-Content $styleFile -Encoding UTF8 -Raw).Trim() } catch { }
} else {
    $txtStyle.Text = "Kısa, samimi ve doğal konuşurum. Önce en dikkat çekici şeyi söylerim."
}

function Set-Busy([bool]$busy, [string]$msg) {
    if ($busy) {
        $script:spinBaseMsg = $msg.TrimEnd('.')
        $script:spinDots = 0
        $lblStatus.Text = $msg
        $spinner.Visible = $true
        $spinTimer.Start()
        $progress.MarqueeAnimationSpeed = 30
    } else {
        $spinTimer.Stop()
        $spinner.Visible = $false
        $lblStatus.Text = $msg
        $progress.MarqueeAnimationSpeed = 0
    }
    $btnPick.Enabled    = -not $busy
    $btnAnalyze.Enabled = (-not $busy) -and ($null -ne $script:imagePath)
    $btnReplay.Enabled  = (-not $busy) -and ($null -ne $script:lastText)
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-SelectedTone {
    $i = $cmbTone.SelectedIndex
    if ($i -lt 0) { return "normal" }
    return $ToneOrder[$i]
}

function Get-SelectedLevel {
    switch ($cmbLevel.SelectedIndex) {
        0 { return "kisa" }
        2 { return "detayli" }
        default { return "normal" }
    }
}

function Get-DefaultQuestion([string]$Kind) {
    switch ($Kind) {
        "audio" { return "Bu ses kaydında ne anlatılıyor? Kısa ve doğal Türkçeyle özetle." }
        "video" { return "Bu videoda ne oluyor? Kısa ve doğal Türkçeyle anlat." }
        "text"  { return "Bu metin ne anlatıyor? Kısa ve doğal Türkçeyle özetle." }
        default { return "Bu görselde ne var? Kısa ve doğal Türkçeyle anlat." }
    }
}

function Get-KindLabel([string]$Kind) {
    switch ($Kind) {
        "audio" { return "Ses" }
        "video" { return "Video" }
        "text"  { return "Metin" }
        default { return "Görsel" }
    }
}

function Get-TargetSeconds {
    if ($chkNatural.Checked) { return 0 }
    return [double]$numDur.Value
}

function Start-Speech([switch]$Quiet) {
    $tone = Get-SelectedTone
    $target = Get-TargetSeconds

    if ($target -gt 0) { $msg = "Seslendiriliyor ($tone, hedef ${target}sn)..." } else { $msg = "Seslendiriliyor ($tone)..." }
    Set-Busy $true $msg

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $base = Join-Path $outDir ("anlatim-" + $tone + "-" + $stamp)

    $r = New-SpeechFile -Text $script:lastText -ToneName $tone -BasePath $base -TargetSeconds $target

    $line = "`r`n`r`nTON: $tone   |   SÜRE: $($r.Seconds) sn"
    if ($target -gt 0 -and -not $r.HitTarget) {
        $line += "   (hedef ${target}sn tutturulamadı, sınırda)"
    }
    $line += "`r`nSES: $($r.Path)"
    $txtOut.AppendText($line)

    $script:player.Stop()
    $script:player.SoundLocation = $r.Path
    $script:player.Load()
    $script:player.Play()
    $btnStop.Enabled = $true

    Set-Busy $false "Çalıyor: $tone  ($($r.Seconds) sn)"
}

# ---------------------------------------------------------------------------
# Baslik cubugu surukleme
# ---------------------------------------------------------------------------
$dragStart = {
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:dragPoint = [System.Windows.Forms.Cursor]::Position
    }
}
$dragMove = {
    param($sender, $e)
    if ($script:dragging) {
        $cur = [System.Windows.Forms.Cursor]::Position
        $form.Location = New-Object System.Drawing.Point(
            ($form.Location.X + $cur.X - $script:dragPoint.X),
            ($form.Location.Y + $cur.Y - $script:dragPoint.Y))
        $script:dragPoint = $cur
    }
}
$dragEnd = { param($sender, $e) $script:dragging = $false }

foreach ($c in @($header, $lblTitle, $lblSub)) {
    $c.Add_MouseDown($dragStart)
    $c.Add_MouseMove($dragMove)
    $c.Add_MouseUp($dragEnd)
}

# ---------------------------------------------------------------------------
# Olaylar
# ---------------------------------------------------------------------------
$btnClose.Add_Click({ $form.Close() })
$btnMin.Add_Click({ $form.WindowState = "Minimized" })

$btnTheme.Add_Click({
    Apply-Theme (-not $script:dark)
})

$btnPick.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Görsel, ses, video veya metin seçin"
    $dlg.Filter = "Desteklenen dosyalar|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.webp;*.wav;*.mp3;*.flac;*.ogg;*.m4a;*.mp4;*.mkv;*.mov;*.webm;*.avi;*.txt;*.md|Görsel|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.webp|Ses|*.wav;*.mp3;*.flac;*.ogg;*.m4a|Video|*.mp4;*.mkv;*.mov;*.webm;*.avi|Metin|*.txt;*.md|Tüm dosyalar|*.*"
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $kind = Get-MediaKind $dlg.FileName
    if ($kind -eq "unknown") {
        [void][System.Windows.Forms.MessageBox]::Show("Bu dosya türü desteklenmiyor. Görsel, ses, video veya metin seçin.", "Desteklenmeyen dosya")
        return
    }

    if ($kind -eq "image") {
        try {
            $img = [System.Drawing.Image]::FromFile($dlg.FileName)
            $bmp = New-Object System.Drawing.Bitmap $img
            $img.Dispose()
            if ($pic.Image) { $pic.Image.Dispose() }
            $pic.Image = $bmp
            $lblNoImg.Visible = $false
        } catch {
            [void][System.Windows.Forms.MessageBox]::Show("Görsel açılamadı:`n$($_.Exception.Message)", "Hata")
            return
        }
    } else {
        if ($pic.Image) { $pic.Image.Dispose(); $pic.Image = $null }
        $lblNoImg.Text = "$(Get-KindLabel $kind) dosyası`r`n`r`n$([System.IO.Path]::GetFileName($dlg.FileName))"
        $lblNoImg.Visible = $true
        $lblNoImg.BringToFront()
    }

    $script:imagePath = $dlg.FileName
    $script:mediaKind = $kind
    $script:lastText  = $null
    $lblPath.Text = $dlg.FileName
    $txtOut.Text = ""

    # Soru kutusu hala otomatik metinse yeni medya turune gore guncelle
    $currentQ = $txtQ.Text.Trim()
    $isAuto = [string]::IsNullOrWhiteSpace($currentQ)
    foreach ($k in @("image", "audio", "video", "text")) {
        if ($currentQ -eq (Get-DefaultQuestion $k)) { $isAuto = $true }
    }
    if ($isAuto) { $txtQ.Text = Get-DefaultQuestion $kind }

    Set-Busy $false "$(Get-KindLabel $kind) yüklendi. Ton ve süre seçip 'ANLAT VE DİNLE' butonuna basın."
})

$btnAnalyze.Add_Click({
    if (-not $script:imagePath) { return }
    try {
        $kind = $script:mediaKind
        if (-not $kind) { $kind = "image" }
        $level = Get-SelectedLevel
        $research = $chkResearch.Checked

        $msg = "$(Get-KindLabel $kind) analiz ediliyor... (yaklaşık 5-15 saniye)"
        if ($research) { $msg = "Araştırma yapılıyor, ardından içerik analiz ediliyor..." }
        Set-Busy $true $msg

        $q = $txtQ.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($q)) { $q = Get-DefaultQuestion $kind }

        $res = Get-ContentSummary -MediaPath $script:imagePath -MediaKind $kind -Question $q `
                    -Style (Save-Style) -Level $level -Research $research

        $script:lastText = $res.Text
        $txtOut.Text = "METİN: " + $res.Text
        if ($res.Sources.Count -gt 0) {
            $txtOut.AppendText("`r`nKAYNAK: " + ($res.Sources -join " | "))
        }

        Start-Speech
    } catch {
        Set-Busy $false "Hata oluştu."
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Hata")
    }
})

$btnReplay.Add_Click({
    if (-not $script:lastText) { return }
    try { Start-Speech } catch {
        Set-Busy $false "Hata oluştu."
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Hata")
    }
})

$btnStop.Add_Click({
    $script:player.Stop()
    $lblStatus.Text = "Durduruldu."
})

$btnFolder.Add_Click({
    if (Test-Path $outDir) { Start-Process explorer.exe $outDir }
})

$chkNatural.Add_CheckedChanged({
    $numDur.Enabled = -not $chkNatural.Checked
    $pal = New-Palette $script:dark
    if ($chkNatural.Checked) { $lblDurUnit.ForeColor = $pal.Muted } else { $lblDurUnit.ForeColor = $pal.Text }
})

$cmbTone.Add_SelectedIndexChanged({
    if ($script:lastText) {
        $lblStatus.Text = "Ton seçildi: $(Get-SelectedTone). 'Bu tonla seslendir' ile dinleyin."
    }
})

$form.Add_FormClosed({
    $spinTimer.Stop()
    $spinTimer.Dispose()
    $script:player.Stop()
    Save-Style | Out-Null
})

$txtStyle.Add_Leave({ Save-Style | Out-Null })

# ---------------------------------------------------------------------------
# Baslat
# ---------------------------------------------------------------------------
Apply-Theme $true

$missing = @()
foreach ($f in @($llama, $model, $mmproj, $piper, $voice)) {
    if (-not (Test-Path $f)) { $missing += $f }
}
if ($missing.Count -gt 0) {
    [void][System.Windows.Forms.MessageBox]::Show("Eksik dosyalar:`n`n" + ($missing -join "`n"), "Kurulum eksik")
    return
}

[void]$form.ShowDialog()
