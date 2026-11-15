# masaustu-kisayol.ps1 -- Masaustune simgeli Omni3B kisayolu olusturur.
#
#   .\masaustu-kisayol.ps1
#
# Ne yapar:
#   - assets\omni3b.ico yoksa once onu uretir
#   - Masaustune "Omni3B" adli .lnk olusturur (hedef: anlat.cmd, simge: omni3b.ico)
#
# Kisayol yalnizca bu bilgisayarda olusur, depoya girmez.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$icon   = Join-Path $root "assets\omni3b.ico"
$target = Join-Path $root "anlat.cmd"

if (-not (Test-Path $icon)) {
    $maker = Join-Path $root "assets\simge-olustur.ps1"
    if (Test-Path $maker) {
        Write-Host "Simge uretiliyor..." -ForegroundColor Cyan
        & $maker
    }
}
if (-not (Test-Path $icon))   { throw "Simge bulunamadi: $icon" }
if (-not (Test-Path $target)) { throw "Baslatici bulunamadi: $target" }

$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = Join-Path $desktop "Omni3B.lnk"

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath       = $target
$lnk.WorkingDirectory = $root
$lnk.IconLocation     = "$icon,0"
$lnk.Description      = "Omni3B - görselden Türkçe sesli anlatım"
$lnk.WindowStyle      = 1
$lnk.Save()

Write-Host "Masaustu kisayolu olusturuldu:" -ForegroundColor Green
Write-Host "  $lnkPath"
Write-Host "  Simge: $icon"
