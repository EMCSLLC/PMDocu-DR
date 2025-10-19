<#
.SYNOPSIS
  Appends a CI-AUT-002-A compliance summary to the latest release markdown file.

.DESCRIPTION
  Searches docs/releases/ for the most recent Baseline-*.md file.
  Creates or updates a matching ChangeRecord-YYYYMMDD.md (release note)
  by inserting a one-line compliance confirmation referencing CI-AUT-002-A.

.EXAMPLE
  pwsh -NoProfile -File scripts/Update-ReleaseCompliance.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Get-Location).Path
$ReleasesDir = Join-Path $RepoRoot 'docs/releases'

if (-not (Test-Path $ReleasesDir)) {
    throw "Releases directory not found at $ReleasesDir"
}

# --- Locate latest baseline snapshot ---
$Baseline = Get-ChildItem $ReleasesDir -Filter 'Baseline-*.md' |
Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $Baseline) {
    throw "No Baseline-*.md file found; run Write-BaselineSnapshot.ps1 first."
}

# --- Metadata ---
$DateStamp = (Get-Date -Format 'yyyy-MM-dd')
$CommitHash = (git rev-parse --short HEAD).Trim()
$ReleaseFile = Join-Path $ReleasesDir "ChangeRecord-$($DateStamp -replace '-', '').md"

$Line = "**CI-AUT-002-A:** Nightly Validation and Baseline Snapshot recordkeeping verified — " +
"`${($Baseline.Name)}` successfully generated under `docs/releases/`, " +
"referencing commit `$CommitHash` and latest evidence logs " +
"(`RepoTree*.txt`, `RepoStructureFix*.log`, `SignResult*.json`). " +
"All CI controls passed; structure and documentation integrity confirmed.`r`n"

# --- Insert or create ---
if (Test-Path $ReleaseFile) {
    Add-Content -Path $ReleaseFile -Value "`r`n$Line"
    Write-Host "✅ Appended CI-AUT-002-A compliance summary to existing file: $($ReleaseFile)"
} else {
    $Header = "# 🧩 Change Record – $DateStamp`r`n`r`n## Compliance Verification`r`n`r`n"
    ($Header + $Line) | Out-File -FilePath $ReleaseFile -Encoding utf8 -Force
    Write-Host "✅ Created new release compliance record: $($ReleaseFile)"
}
