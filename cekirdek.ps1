# cekirdek.ps1 -- Omni3B ortak cekirdegi
#
# describe.ps1 (CLI) ve gui.ps1 (arayuz) tarafindan dot-source edilir.
# Amac: ayni mantigi iki yerde tekrar etmemek.
#
#   Get-MediaKind        : uzantidan medya turu (image/audio/video/text/unknown)
#   Get-LevelProfile     : anlatim uzunlugu -> kural + token butcesi
#   New-OmniPrompt       : rol + tarz + uzunluk + dogruluk + arastirma + gorev
#   Invoke-OmniModel     : llama-mtmd-cli'yi calistirir, metni dondurur
#   Get-WebResearch      : Wikipedia / DuckDuckGo ile kisa arastirma
#   Get-VideoFrames      : videodan kare cikarir (ffmpeg gerekir)

# ---------------------------------------------------------------------------
# Medya turu
# ---------------------------------------------------------------------------
function Get-MediaKind {
    param([Parameter(Mandatory)][string]$Path)

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".jpg"   { return "image" }
        ".jpeg"  { return "image" }
        ".png"   { return "image" }
        ".bmp"   { return "image" }
        ".gif"   { return "image" }
        ".webp"  { return "image" }
        ".wav"   { return "audio" }
        ".mp3"   { return "audio" }
        ".flac"  { return "audio" }
        ".ogg"   { return "audio" }
        ".m4a"   { return "audio" }
        ".mp4"   { return "video" }
        ".mkv"   { return "video" }
        ".mov"   { return "video" }
        ".webm"  { return "video" }
        ".avi"   { return "video" }
        ".txt"   { return "text" }
        ".md"    { return "text" }
        default  { return "unknown" }
    }
}

# ---------------------------------------------------------------------------
# Anlatim uzunlugu
#   kisa    : tek cumle          (az token)
#   normal  : en fazla iki cumle (varsayilan)
#   detayli : 4-6 cumle          (fazla token)
# ---------------------------------------------------------------------------
function Get-LevelProfile {
    param(
        [ValidateSet("kisa", "normal", "detayli")]
        [string]$Level = "normal"
    )

    switch ($Level) {
        "kisa" {
            return [pscustomobject]@{
                Name  = "kisa"
                Rule  = "Uzunluk: tek cumle, en fazla 18 kelime."
                Tokens = 110
            }
        }
        "detayli" {
            return [pscustomobject]@{
                Name  = "detayli"
                Rule  = "Uzunluk: 4-6 cumle. Once tek cumlelik ozet, sonra ayrintilar. Madde isareti veya baslik kullanma."
                Tokens = 420
            }
        }
        default {
            return [pscustomobject]@{
                Name  = "normal"
                Rule  = "Uzunluk: en fazla iki cumle."
                Tokens = 200
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Prompt kurucu
# ---------------------------------------------------------------------------
function New-OmniPrompt {
    param(
        [string]$Question,
        [string]$Style,
        [ValidateSet("kisa", "normal", "detayli")]
        [string]$Level = "normal",
        [string]$ResearchText = "",
        [string[]]$Sources = @(),
        [string]$MediaKind = "image",
        [string]$ExtraText = ""
    )

    $profile = Get-LevelProfile $Level
    $parts = @()

    $parts += "Sen kullanicinin agzindan konusuyorsun."
    if (-not [string]::IsNullOrWhiteSpace($Style)) {
        $parts += "Kullanicinin anlatim tarzi: " + ($Style -replace '\s+', ' ').Trim()
    }

    $parts += $profile.Rule
    $parts += "Uslup: kisa, net, dogal ve akici Turkce. 'Gorselde', 'resimde', 'fotografta' diye baslama."

    # Dogruluk ilkesi
    $parts += "Dogruluk: Yalnizca gordugunden ve sana verilen bilgiden konus. Emin olmadigin ayrintiyi uydurma; emin degilsen 'tam emin degilim' diye acikca belirt. Kisi adi, yer adi, marka ve tarih gibi kesin bilgileri tahmin etme."

    if ($MediaKind -eq "audio") {
        $parts += "Girdi bir ses kaydi. Duyduklarini anlat; anlasilmayan yerler icin 'tam anlayamadim' de."
    } elseif ($MediaKind -eq "video") {
        $parts += "Girdi bir videodan alinmis kareler. Kareler arasindaki degisimi de dikkate al."
    } elseif ($MediaKind -eq "text") {
        $parts += "Girdi bir metin dosyasi."
    }

    if (-not [string]::IsNullOrWhiteSpace($ResearchText)) {
        $parts += "Internet arastirmasi (guvenilir kaynak kabul et): $ResearchText"
        if ($Sources.Count -gt 0) {
            $parts += "Kaynaklar: " + ($Sources -join " | ")
        }
        $parts += "Arastirma sorusuyla ilgili degilse bu bilgiyi kullanma."
    }

    if (-not [string]::IsNullOrWhiteSpace($ExtraText)) {
        $parts += "Metin: " + $ExtraText
    }

    if (-not [string]::IsNullOrWhiteSpace($Question)) {
        $parts += "Gorev: $Question"
    }

    return ($parts -join " ")
}

# ---------------------------------------------------------------------------
# Modeli calistir
#   Donus: duz metin (tekrar dongusu kirpilmis)
# ---------------------------------------------------------------------------
function Invoke-OmniModel {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$LlamaPath,
        [Parameter(Mandatory)][string]$ModelPath,
        [Parameter(Mandatory)][string]$MmprojPath,
        [string]$MediaPath,
        [ValidateSet("image", "audio", "video", "text", "none")]
        [string]$MediaKind = "image",
        [string[]]$FramePaths = @(),
        [int]$MaxTokens = 200,
        [int]$Context = 2048,
        [double]$RepeatPenalty = 1.1
    )

    $tmpDir = Join-Path $env:TEMP ("omni3b-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $promptFile = Join-Path $tmpDir "prompt.txt"
    $outFile    = Join-Path $tmpDir "out.txt"
    $errFile    = Join-Path $tmpDir "err.txt"

    try {
        # Turkce karakterler komut satirinda bozulmasin diye prompt dosyadan veriliyor
        [System.IO.File]::WriteAllText($promptFile, $Prompt, (New-Object System.Text.UTF8Encoding($false)))

        $mediaArgs = @()
        switch ($MediaKind) {
            "image" {
                if ($MediaPath) { $mediaArgs += @("--image", "`"$MediaPath`"") }
            }
            "audio" {
                if ($MediaPath) { $mediaArgs += @("--audio", "`"$MediaPath`"") }
            }
            "video" {
                foreach ($f in $FramePaths) { $mediaArgs += @("--image", "`"$f`"") }
            }
        }

        $argList = @(
            "-m", "`"$ModelPath`"", "--mmproj", "`"$MmprojPath`"",
            "-ngl", "99", "-fit", "off", "-c", "$Context"
        ) + $mediaArgs + @(
            "--temp", "0", "--repeat-penalty", "$RepeatPenalty", "--repeat-last-n", "128",
            "-n", "$MaxTokens", "-f", "`"$promptFile`""
        )

        $p = Start-Process -FilePath $LlamaPath -ArgumentList ($argList -join " ") -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $outFile -RedirectStandardError $errFile

        $text = (Get-Content $outFile -Encoding UTF8 -Raw)
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "Model bos yanit dondurdu. (llama cikis kodu: $($p.ExitCode))"
        }

        $text = ($text -replace '\s+', ' ').Trim()
        return (Protect-FromLoop $text)
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Tekrar dongusu korumasi: ayni 8 kelimelik parca 3 kez gecerse kes
function Protect-FromLoop {
    param([string]$Text)

    $words = $Text -split ' '
    if ($words.Count -lt 24) { return $Text }

    for ($i = 0; $i -le $words.Count - 24; $i++) {
        $chunk = ($words[$i..($i + 7)] -join ' ')
        if ($chunk.Trim().Length -lt 8) { continue }
        $hits = ([regex]::Matches($Text, [regex]::Escape($chunk))).Count
        if ($hits -ge 3) {
            $cut = $Text.Substring(0, $Text.IndexOf($chunk, [StringComparison]::Ordinal)).TrimEnd(' ', ',', '-', ':')
            if (-not $cut.EndsWith('.')) { $cut += '.' }
            return $cut
        }
    }
    return $Text
}

# ---------------------------------------------------------------------------
# Internet arastirmasi (anahtar gerektirmez)
#   Once Turkce Wikipedia, sonra Ingilizce Wikipedia, en son DuckDuckGo.
#   Donus: @{ Text = "..."; Sources = @("..."); Ok = $true/$false; Error = "..." }
# ---------------------------------------------------------------------------
function Get-WebResearch {
    param(
        [Parameter(Mandatory)][string]$Query,
        [int]$MaxChars = 900,
        [int]$TimeoutSec = 12
    )

    $result = [pscustomobject]@{
        Text    = ""
        Sources = @()
        Ok      = $false
        Error   = ""
    }

    if ([string]::IsNullOrWhiteSpace($Query)) {
        $result.Error = "Sorgu bos"
        return $result
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "Omni3B/1.0 (local)" }
        $q = [uri]::EscapeDataString($Query.Trim())

        $sources = @()

        foreach ($lang in @("tr", "en")) {
            $url = "https://$lang.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=1&explaintext=1&redirects=1&generator=search&gsrsearch=$q&gsrlimit=1"
            try {
                $r = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers $headers
                $page = $r.query.pages.PSObject.Properties | Select-Object -First 1
                if ($page) {
                    $pv = $page.Value
                    $ex = $pv.extract
                    if (-not [string]::IsNullOrWhiteSpace($ex)) {
                        $clean = ($ex -replace '\s+', ' ').Trim()
                        $result.Text = $clean
                        $sources += ("Wikipedia ({0}): {1}" -f $lang, $pv.title)
                        break
                    }
                }
            } catch { }
        }

        if ([string]::IsNullOrWhiteSpace($result.Text)) {
            $url = "https://api.duckduckgo.com/?q=$q&format=json&no_html=1&skip_disambig=1"
            try {
                $d = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers $headers
                if (-not [string]::IsNullOrWhiteSpace($d.AbstractText)) {
                    $result.Text = ($d.AbstractText -replace '\s+', ' ').Trim()
                    $src = "DuckDuckGo"
                    if ($d.AbstractSource) { $src = $d.AbstractSource }
                    $sources += $src
                }
            } catch { }
        }

        if ($result.Text.Length -gt $MaxChars) {
            $result.Text = $result.Text.Substring(0, $MaxChars).TrimEnd() + "..."
        }
        if (-not [string]::IsNullOrWhiteSpace($result.Text)) {
            $result.Text = ($result.Text -replace '\s+', ' ').Trim()
        }

        $result.Sources = $sources
        $result.Ok = (-not [string]::IsNullOrWhiteSpace($result.Text))
        if (-not $result.Ok) { $result.Error = "Sonuc bulunamadi" }
        return $result
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }
}

# ---------------------------------------------------------------------------
# Videodan kare cikarma (ffmpeg gerekir)
#   Donus: @{ Frames = @(...); Dir = "..."; Ok = $bool; Error = "..." }
#   Cagiran taraf is bitince $x.Dir klasorunu silmelidir.
# ---------------------------------------------------------------------------
function Get-VideoFrames {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Count = 4
    )

    $dir = Join-Path $env:TEMP ("omni3b-frames-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $ff = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if (-not $ff) {
        return [pscustomobject]@{
            Frames = @()
            Dir    = $dir
            Ok     = $false
            Error  = "ffmpeg bulunamadi. Video icin ffmpeg kurun (winget install Gyan.FFmpeg) veya tek kare/dosya kullanin."
        }
    }

    $pattern = Join-Path $dir "frame_%02d.jpg"
    & $ff.Source -y -loglevel error -i "$Path" -vf "fps=1/2,scale=768:-2" -frames:v $Count "$pattern" 2>$null | Out-Null

    $frames = @(Get-ChildItem $dir -Filter "frame_*.jpg" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -ExpandProperty FullName)
    return [pscustomobject]@{
        Frames = $frames
        Dir    = $dir
        Ok     = ($frames.Count -gt 0)
        Error  = $(if ($frames.Count -eq 0) { "Videodan kare cikarilamadi." } else { "" })
    }
}

# ---------------------------------------------------------------------------
# Metin dosyasi icerigini guvenli sekilde okur
# ---------------------------------------------------------------------------
function Get-TextPreview {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxChars = 1200
    )

    try {
        $t = Get-Content $Path -Encoding UTF8 -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($t)) { return "" }
        $t = ($t -replace '\s+', ' ').Trim()
        if ($t.Length -gt $MaxChars) { $t = $t.Substring(0, $MaxChars).TrimEnd() + "..." }
        return $t
    } catch {
        return ""
    }
}
