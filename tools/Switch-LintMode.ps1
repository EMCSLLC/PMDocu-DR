param(
    [ValidateSet('Chill', 'Strict')]
    [string]$Mode = 'Chill'
)

$src = ".vscode\PSScriptAnalyzerSettings.$Mode.psd1"
$dst = ".vscode\PSScriptAnalyzerSettings.psd1"

if (-not (Test-Path $src)) {
    Write-Host "❌ Mode file not found: $src" -ForegroundColor Red
    exit 1
}

Copy-Item -Force $src $dst
Write-Host "✅ Linting mode switched to: $Mode"
