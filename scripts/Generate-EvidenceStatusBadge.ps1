<#
.SYNOPSIS
    Generates a simple SVG badge showing overall evidence validation status.

.DESCRIPTION
    Reads the output of tests/Test-EvidenceSchema.ps1 or reruns it directly.
    Writes docs/_evidence/evidence-status.svg.
    Intended for use in CI or local verification dashboards.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$Recheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$EvidencePath = Join-Path $Root 'docs/_evidence'
if (-not (Test-Path $EvidencePath)) {
    New-Item -ItemType Directory -Path $EvidencePath | Out-Null
}

# --- Run schema test or read cached result ----------------------------------
$SchemaTest = Join-Path $Root 'tests/Test-EvidenceSchema.ps1'
$Status = "unknown"

if ($Recheck -and (Test-Path $SchemaTest)) {
    Write-Output "🔍 Running schema validation check..."
    try {
        pwsh -NoProfile -File $SchemaTest | Tee-Object -Variable out | Out-Null
        if ($LASTEXITCODE -eq 0) { $Status = "passing" } else { $Status = "failing" }
    }
    catch { $Status = "error" }
}
else {
    # fallback heuristic: look for last BaselineValidationResult
    $latest = Get-ChildItem "$EvidencePath\BaselineValidationResult-*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        try {
            $json = Get-Content $latest.FullName -Raw | ConvertFrom-Json
            $Status = if ($json.overall_status -eq 'Success') { 'passing' } else { 'failing' }
        }
        catch { $Status = "error" }
    }
    else { $Status = "missing" }
}

# --- Define badge colors ----------------------------------------------------
$ColorMap = @{
    passing = '#4c1'
    failing = '#e05d44'
    error   = '#fe7d37'
    missing = '#9f9f9f'
    unknown = '#9f9f9f'
}
$Color = $ColorMap[$Status]

# --- Build minimal SVG badge ------------------------------------------------
$Svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="150" height="20" role="img" aria-label="evidence:$Status">
  <linearGradient id="a" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <rect width="80" height="20" fill="#555"/>
  <rect x="80" width="70" height="20" fill="$Color"/>
  <rect width="150" height="20" fill="url(#a)"/>
  <g fill="#fff" text-anchor="middle"
     font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11">
    <text x="40" y="14">evidence</text>
    <text x="115" y="14">$Status</text>
  </g>
</svg>
"@

$OutFile = Join-Path $EvidencePath 'evidence-status.svg'
$Svg | Set-Content -Path $OutFile -Encoding UTF8
Write-Output "🏷️  Evidence status badge generated → $OutFile ($Status)"
exit 0

