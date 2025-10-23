<#
.SYNOPSIS
    Displays the currently active PowerShell linting mode (Chill or Strict).

.DESCRIPTION
    Detects which PSScriptAnalyzerSettings.psd1 is active in .vscode,
    and prints a friendly colored status banner for developers or CI output.
#>

param()

$basePath = ".vscode"
$current = Join-Path $basePath "PSScriptAnalyzerSettings.psd1"

if (-not (Test-Path $current)) {
    Write-Host "⚠️  No active lint settings found at $current" -ForegroundColor Yellow
    return
}

# Compute hash to match which file is in use
$strictFile = Join-Path $basePath "PSScriptAnalyzerSettings.Strict.psd1"
$chillFile = Join-Path $basePath "PSScriptAnalyzerSettings.Chill.psd1"

function Get-FileHashIfExists($path) {
    if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { $null }
}

$currentHash = (Get-FileHashIfExists $current)
$strictHash = (Get-FileHashIfExists $strictFile)
$chillHash = (Get-FileHashIfExists $chillFile)

if ($currentHash -eq $strictHash) {
    Write-Host "🧠  Linting mode: Strict  (CI / QA Enforcement)" -ForegroundColor Cyan
} elseif ($currentHash -eq $chillHash) {
    Write-Host "😎  Linting mode: Chill   (Relaxed Developer Mode)" -ForegroundColor Green
} else {
    Write-Host "❓  Unknown linting configuration in use" -ForegroundColor Yellow
}
