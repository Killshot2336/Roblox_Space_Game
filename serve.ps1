# Voidline: Deep Space — start Rojo serve (Windows)
# Usage: right-click → Run with PowerShell, or: powershell -File .\serve.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
    Write-Host "Rojo not found. Installing via winget..."
    winget install Rojo.Rojo --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "Rojo version:" (rojo --version)
Write-Host "Serving Voidline: Deep Space — connect Studio Rojo plugin, then press F5 / Play"
rojo serve default.project.json
