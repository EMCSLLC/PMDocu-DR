<#
.SYNOPSIS
  Validates JSON evidence files produced by sign-gpg.ps1 and verify-hash.ps1.

.DESCRIPTION
  Scans docs/_evidence/ for SignResult-*.json and VerifyResult-*.json files.
  Checks for required fields, schema version, timestamp format, and valid statuses.
  Produces a combined compliance summary in JSON and console-friendly output.

.EXAMPLE
  pwsh -NoProfile -File scripts/Test-SignVerifyEvidence.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Locate evidence directory ---------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot '..')).Path
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'

if (-not (Test-Path $EvidenceDir)) {
    throw "Evidence directory not found: $EvidenceDir"
}

# --- Collect JSON files ----------------------------------------------------
$Files = Get-ChildItem $EvidenceDir -Filter '*.json' -File
if (-not $Files) {
    Write-Warning "No JSON evidence files found in $EvidenceDir"
    exit 0
}

$Results = @()
$OverallFail = $false

foreach ($f in $Files) {
    try {
        $json = Get-Content $f.FullName -Raw | ConvertFrom-Json
        $missing = @()

        # --- Base validation checks ----------------------------------------
        foreach ($key in @('schema_version', 'evidence_type', 'timestamp_utc', 'status')) {
            if (-not $json.PSObject.Properties.Name.Contains($key)) {
                $missing += $key
            }
        }

        # --- Timestamp format check ----------------------------------------
        $validTimestamp = $false
        if ($json.timestamp_utc -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
            $validTimestamp = $true
        }

        # --- Status validity ------------------------------------------------
        $validStatuses = @('Success', 'Failure', 'Generated')
        $statusValid = $validStatuses -contains $json.status

        $status = if ($missing.Count -eq 0 -and $validTimestamp -and $statusValid) {
            'Pass'
        } else {
            $OverallFail = $true
            'Fail'
        }

        $Results += [ordered]@{
            file = $f.Name
            evidence_type = $json.evidence_type
            status = $json.status
            validation = $status
            missing_keys = $missing
            valid_timestamp = $validTimestamp
            valid_status = $statusValid
        }

        if ($status -eq 'Pass') {
            Write-Host ("✅ {0} [{1}]" -f $f.Name, $json.status)
        } else {
            Write-Warning ("❌ {0} failed validation (missing: {1})" -f $f.Name, ($missing -join ', '))
        }
    } catch {
        Write-Warning ("⚠️  Invalid JSON structure in {0}: {1}" -f $f.Name, $_.Exception.Message)
        $OverallFail = $true
        $Results += [ordered]@{
            file = $f.Name
            evidence_type = 'Unknown'
            status = 'Invalid'
            validation = 'Fail'
            missing_keys = @()
            valid_timestamp = $false
            valid_status = $false
        }
    }
}

# --- Write combined summary JSON ------------------------------------------
$SummaryFile = Join-Path $EvidenceDir ("TestEvidenceSummary-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")

$Summary = [ordered]@{
    schema_version = '1.0.0'
    evidence_type = 'TestBuildGovDocsEvidence'
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    workflow = '.github/workflows/nightly-validate.yml'
    status = if ($OverallFail) { 'Fail' } else { 'Pass' }
    overall_status = if ($OverallFail) { 'Fail' } else { 'Pass' }
    results = $Results
    notes = if ($OverallFail) { 'Validation failed — see details.' } else { 'All evidence JSON passed validation.' }
}

$Summary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryFile -Encoding UTF8
Write-Output ("🧾 Evidence validation summary written → {0}" -f $SummaryFile)

if ($OverallFail) { exit 1 } else { exit 0 }
