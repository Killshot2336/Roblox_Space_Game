# Download latest Windows x64 Rojo release into this folder as rojo.exe
# Run in PowerShell from anywhere:
#   powershell -ExecutionPolicy Bypass -File .\Roblox_Space_Game\download-rojo.ps1

$ErrorActionPreference = "Stop"
$destDir = $PSScriptRoot
Set-Location $destDir

Write-Host "Fetching latest Rojo release metadata..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/rojo-rbx/rojo/releases/latest" -Headers @{
    "User-Agent" = "Voidline-Rojo-Bootstrap"
}

# Prefer official windows-x86_64 zip (e.g. rojo-7.7.1-windows-x86_64.zip)
$asset = $release.assets | Where-Object { $_.name -like '*-windows-x86_64.zip' } | Select-Object -First 1
if (-not $asset) {
    $asset = $release.assets | Where-Object {
        $_.name -match 'windows|win' -and $_.name -match 'x86_64|x64|win64' -and $_.name -like '*.zip'
    } | Select-Object -First 1
}

if (-not $asset) {
    Write-Host "Available assets:"
    $release.assets | ForEach-Object { Write-Host " - $($_.name)" }
    throw "Could not find a Windows 64-bit rojo.zip asset on the latest release."
}

$zipPath = Join-Path $destDir "rojo-windows.zip"
$extractDir = Join-Path $destDir "_rojo_extract"

Write-Host "Downloading $($asset.name) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
New-Item -ItemType Directory -Path $extractDir | Out-Null

Write-Host "Extracting..."
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

$found = Get-ChildItem -Path $extractDir -Recurse -Filter "rojo.exe" | Select-Object -First 1
if (-not $found) {
    throw "rojo.exe not found inside $($asset.name)"
}

Copy-Item -Path $found.FullName -Destination (Join-Path $destDir "rojo.exe") -Force
Remove-Item $zipPath -Force
Remove-Item $extractDir -Recurse -Force

Write-Host ""
Write-Host "OK: rojo.exe -> $destDir\rojo.exe"
& "$destDir\rojo.exe" --version
Write-Host ""
Write-Host "Next:"
Write-Host "  cd `"$destDir`""
Write-Host "  .\rojo.exe serve"
Write-Host "Then connect the Rojo plugin in Studio and press Play (F5)."
