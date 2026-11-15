# simge-olustur.ps1 -- Omni3B uygulama simgesini uretir.
#
#   .\assets\simge-olustur.ps1
#
# Uretilenler:
#   assets\omni3b.ico   16/24/32/48/64/128/256 px cok boyutlu Windows simgesi
#   assets\simge.png    256 px onizleme (README icin)
#
# Simge tamamen kodla cizilir; internet veya harici dosya gerekmez.
# Marka: koyu kok + kraliyet mavisi konusma balonu + turuncu ses dalgalari.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outIco = Join-Path $root "omni3b.ico"
$outPng = Join-Path $root "simge.png"

$S = 1024   # ana tuval (kucuk boyutlara kusursuz kucultmek icin buyuk cizilir)

function New-RoundedPath([single]$X, [single]$Y, [single]$W, [single]$H, [single]$R) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)

# --- 1) Koyu yuvarlak kare kok -------------------------------------------------
$pad = 40
$side = $S - ($pad * 2)
$bgPath = New-RoundedPath $pad $pad $side $side ($side * 0.23)
$bgRect = New-Object System.Drawing.Rectangle($pad, $pad, $side, $side)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bgRect,
    [System.Drawing.ColorTranslator]::FromHtml("#2E2E36"),
    [System.Drawing.ColorTranslator]::FromHtml("#151518"),
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
$g.FillPath($bgBrush, $bgPath)
$bgBrush.Dispose()

$borderPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#4A4A57"), 10)
$g.DrawPath($borderPen, $bgPath)
$borderPen.Dispose()

# --- 2) Konusma balonu (kraliyet mavisi) ---------------------------------------
$bx = 168; $by = 236; $bubbleW = 688; $bubbleH = 430; $br = 120

$tail = New-Object System.Drawing.Drawing2D.GraphicsPath
$tail.AddPolygon([System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new([single]($bx + 118), [single]($by + $bubbleH - 46)),
    [System.Drawing.PointF]::new([single]($bx + 108), [single]($by + $bubbleH + 176)),
    [System.Drawing.PointF]::new([single]($bx + 300), [single]($by + $bubbleH - 26))
))
$tailBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#3557D6"))
$g.FillPath($tailBrush, $tail)
$tailBrush.Dispose(); $tail.Dispose()

$bubblePath = New-RoundedPath $bx $by $bubbleW $bubbleH $br
$bubbleRect = New-Object System.Drawing.Rectangle($bx, $by, $bubbleW, $bubbleH)
$bubbleBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bubbleRect,
    [System.Drawing.ColorTranslator]::FromHtml("#6C8DFF"),
    [System.Drawing.ColorTranslator]::FromHtml("#2F4BC4"),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
$g.FillPath($bubbleBrush, $bubblePath)
$bubbleBrush.Dispose()

# Ust kenarda ince isik (balonun icinde, kenarlardan uzak)
$shinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), 7)
$shine = New-RoundedPath ($bx + 40) ($by + 34) ($bubbleW - 80) ($bubbleH - 68) ($br - 30)
$g.DrawPath($shinePen, $shine)
$shinePen.Dispose(); $shine.Dispose()

# --- 3) Turuncu ses dalgalari (balonun icinde) ---------------------------------
$bars = @(
    @{ X = 330; H = 150 },
    @{ X = 456; H = 250 },
    @{ X = 582; H = 190 }
)
$barW = 88; $baseY = 704

foreach ($bar in $bars) {
    $p = New-RoundedPath $bar.X ($baseY - $bar.H) $barW $bar.H ($barW / 2)
    $r = New-Object System.Drawing.Rectangle($bar.X, [int]($baseY - $bar.H), $barW, $bar.H)
    $br2 = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $r,
        [System.Drawing.ColorTranslator]::FromHtml("#FFB259"),
        [System.Drawing.ColorTranslator]::FromHtml("#F28500"),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $g.FillPath($br2, $p)
    $br2.Dispose(); $p.Dispose()
}

# --- 4) Kucuk turuncu nokta: "canli / kayit" hissi (balonun icinde) -------------
$dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#F28500"))
$g.FillEllipse($dotBrush, 726, 300, 84, 84)
$dotBrush.Dispose()

# --- 5) Png onizleme ----------------------------------------------------------
$preview = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pg = [System.Drawing.Graphics]::FromImage($preview)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$pg.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$pg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$pg.DrawImage($bmp, 0, 0, 256, 256)
$pg.Dispose()
$preview.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose()

# --- 6) Cok boyutlu .ico yaz (PNG sikistirmali) --------------------------------
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$frames = @()

foreach ($sz in $sizes) {
    $frame = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $fg = [System.Drawing.Graphics]::FromImage($frame)
    $fg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $fg.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $fg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $fg.Clear([System.Drawing.Color]::Transparent)
    $fg.DrawImage($bmp, 0, 0, $sz, $sz)
    $fg.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $frame.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += [pscustomobject]@{ Size = $sz; Bytes = $ms.ToArray() }
    $ms.Dispose()
    $frame.Dispose()
}

$ico = New-Object System.IO.MemoryStream
$bw  = New-Object System.IO.BinaryWriter($ico)
$bw.Write([uint16]0)
$bw.Write([uint16]1)
$bw.Write([uint16]$frames.Count)

$offset = 6 + (16 * $frames.Count)
foreach ($f in $frames) {
    $dim = [byte]$(if ($f.Size -ge 256) { 0 } else { $f.Size })
    $bw.Write($dim)          # genislik
    $bw.Write($dim)          # yukseklik
    $bw.Write([byte]0)       # renk sayisi
    $bw.Write([byte]0)       # ayriklik
    $bw.Write([uint16]1)     # duzlem
    $bw.Write([uint16]32)    # bit/piksel
    $bw.Write([uint32]$f.Bytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $f.Bytes.Length
}
foreach ($f in $frames) { $bw.Write($f.Bytes) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($outIco, $ico.ToArray())
$bw.Dispose(); $ico.Dispose()
$g.Dispose(); $bmp.Dispose()

Write-Host "Simge uretildi:" -ForegroundColor Green
Write-Host "  $outIco  ($((Get-Item $outIco).Length) bayt)"
Write-Host "  $outPng"
