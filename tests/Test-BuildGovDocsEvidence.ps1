<#
.SYNOPSIS
    Validates the latest BuildGovDocsResult JSON evidence.

.DESCRIPTION
    Ensures that the most recent BuildGovDocsResult-*.json file in `docs/_evidence/`
    exists, matches required schema keys, and reports `overall_status = "Success"`.
    Produces a structured JSON summary (TestBuildGovDocsEvidence-<timestamp>.json)
    for compliance workflows such as nightly validation or evidence-integrity tests.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Locate evidence file ---------------------------------------------------
$EvidencePath = Join-Path $Root 'docs/_evidence'
$Latest = Get-ChildItem -Path $EvidencePath -Filter 'BuildGovDocsResult-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $Latest) {
    Write-Warning "⚠️ No BuildGovDocsResult evidence found in $EvidencePath"
    exit 1
}

Write-Output "🧾 Validating evidence: $($Latest.Name)"

# --- Read JSON --------------------------------------------------------------
try {
    $Data = Get-Content $Latest.FullName -Raw | ConvertFrom-Json
} catch {
    Write-Warning "⚠️ Invalid JSON in $($Latest.Name): $($_.Exception.Message)"
    exit 1
}

# --- Schema validation ------------------------------------------------------
$required = @(
    'evidence_type', 'timestamp_utc', 'workflow',
    'build_summary', 'evidence_outputs', 'overall_status'
)

$missing = @()
foreach ($key in $required) {
    if (-not $Data.PSObject.Properties.Name -contains $key) {
        $missing += $key
    }
}

if ($missing.Count -gt 0) {
    Write-Warning "⚠️ Missing schema keys: $($missing -join ', ')"
}

# --- Check build status -----------------------------------------------------
$overall = $Data.overall_status
if ($overall -ne 'Success') {
    Write-Warning "❌ BuildGovDocsResult reported failure: overall_status = $overall"
    $Pass = $false
} else {
    Write-Output "✅ BuildGovDocsResult evidence passed validation."
    $Pass = $true
}

# --- Prepare result object --------------------------------------------------
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$OutFile = Join-Path $EvidencePath ("TestBuildGovDocsEvidence-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')

$Result = [ordered]@{
    schema_version = '1.0.0'
    evidence_type = 'TestBuildGovDocsEvidence'
    timestamp_utc = $Timestamp
    source_file = $Latest.Name
    workflow = '.github/workflows/nightly-validate.yml'
    status = if ($Pass) { 'Pass' } else { 'Fail' }
    missing_keys = $missing
    overall_status = $overall
    notes = if ($Pass) {
        'Latest BuildGovDocsResult evidence verified successfully.'
    } else {
        'Validation failed — see logs or JSON evidence for details.'
    }
}

$Result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
Write-Output "📄 Test evidence written → $OutFile"

# --- Exit for CI/CD enforcement ---------------------------------------------
if (-not $Pass -or $missing.Count -gt 0) {
    exit 1
}
