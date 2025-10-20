<#
.SYNOPSIS
  Updates the "Last verified" line in CI-Compliance-Matrix.md.

.DESCRIPTION
  Replaces or inserts the line starting with "_Last verified:" with
  the current date and short commit hash. Designed for nightly use.

.EXAMPLE
  pwsh -NoProfile -File scripts/Update-ComplianceBanner.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$File = Join-Path (Get-Location) 'docs/gov/CI-Compliance-Matrix.md'
if (-not (Test-Path $File)) {
    throw "File not found: $File"
}

$Date = Get-Date -Format 'yyyy-MM-dd'
$Commit = (git rev-parse --short HEAD).Trim()
$Line = "_Last verified: $Date ($Commit)_"

$Content = Get-Content $File -Raw -Encoding utf8
if ($Content -match '_Last verified:') {
    $Updated = $Content -replace '_Last verified:.*', $Line
}
else {
    $Updated = "$Content`r`n---`r`n$Line"
}

$Updated | Out-File -FilePath $File -Encoding utf8 -Force
Write-Host "✅ Updated CI Compliance Matrix verification line → $Line"

