#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Output "🔧 Running Normalize-Spacing.ps1 on staged PowerShell files..."
$changed = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -like '*.ps1' }
foreach ($f in $changed) {
    if (Test-Path 'scripts/Normalize-Spacing.ps1') {
        pwsh -NoProfile -File scripts/Normalize-Spacing.ps1 -Path $f
    }
    git add $f
}
Write-Output "✅ Spacing normalization complete."

# Ensure PSScriptAnalyzer is available
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
}
catch {
    Write-Output 'Installing PSScriptAnalyzer for current user...'
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
    Import-Module PSScriptAnalyzer -ErrorAction Stop
}

Write-Output "🔍 Running PSScriptAnalyzer (with fixes) on staged files..."
$ps1Staged = @($changed | Where-Object { $_ -like '*.ps1' })
if ($ps1Staged.Count -gt 0) {
    $results = Invoke-ScriptAnalyzer -Path $ps1Staged -Settings './config/PSScriptAnalyzerSettings.psd1' -Fix
}
else {
    $results = @()
}
$errors = @($results | Where-Object { $_.Severity -eq 'Error' })
if ($errors.Count -gt 0) {
    $errors | Sort-Object RuleName | Format-Table -AutoSize | Out-String | Write-Output
    Write-Error ("PSScriptAnalyzer found {0} error(s). Commit blocked." -f $errors.Count)
    exit 1
}
Write-Output "✅ Lint passed."
