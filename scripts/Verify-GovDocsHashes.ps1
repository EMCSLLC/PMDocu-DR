<#
.SYNOPSIS
    Re-verifies the SHA-256 hashes for all governance PDFs
    listed in the most recent BuildGovDocsResult JSON evidence file.

.DESCRIPTION
    Reads the newest evidence JSON from docs/_evidence/,
    recomputes SHA-256 for each referenced PDF, and compares the
    results.  Outputs a summary and writes a verification log
    (VerifyGovDocsHashes-<timestamp>.json) for audit purposes.

.PARAMETER Root
    Optional. Root of the repository (defaults to current directory).

.EXAMPLE
    pwsh -NoProfile -File scripts/Verify-GovDocsHashes.ps1 -Root "C:\PMDocu-DR"
#>

[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$EvidenceDir = Join-Path $Root 'docs/_evidence'
$ReleaseDir = Join-Path $Root 'docs/releases'

if (-not (Test-Path $EvidenceDir)) {
    throw "Evidence directory not found: $EvidenceDir"
}

# Get the newest BuildGovDocsResult file
$EvidenceFile = Get-ChildItem $EvidenceDir -Filter 'BuildGovDocsResult-*.json' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $EvidenceFile) {
    throw "No BuildGovDocsResult JSON found in $EvidenceDir"
}

Write-Information "[verify] Using evidence file: $($EvidenceFile.Name)"

# Parse evidence JSON
$Evidence = Get-Content $EvidenceFile.FullName -Raw | ConvertFrom-Json

if (-not $Evidence.evidence_outputs.file_hashes) {
    throw "No file_hashes section found in evidence JSON."
}

$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$OutFile = Join-Path $EvidenceDir ("VerifyGovDocsHashes-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")

$Results = @()
$AllPass = $true

foreach ($entry in $Evidence.evidence_outputs.file_hashes) {
    $path = Join-Path $Root $entry.file
    if (-not (Test-Path $path)) {
        Write-Warning "Missing file: $($entry.file)"
        $Results += [ordered]@{ file = $entry.file; status = "missing" }
        $AllPass = $false
        continue
    }

    $computed = (Get-FileHash -Path $path -Algorithm SHA256).Hash
    $match = ($computed -eq $entry.sha256)
    $status = if ($match) { "match" } else { "mismatch" }

    if (-not $match) {
        Write-Warning "Hash mismatch for $($entry.file)"
        $AllPass = $false
    }
    else {
        Write-Information "✅ Verified: $($entry.file)"
    }

    $Results += [ordered]@{
        file     = $entry.file
        expected = $entry.sha256
        computed = $computed
        status   = $status
    }
}

$Verification = [ordered]@{
    verification_type = 'VerifyGovDocsHashes'
    timestamp_utc     = $Timestamp
    evidence_source   = $EvidenceFile.Name
    all_passed        = $AllPass
    results           = $Results
}

$Verification | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8

if ($AllPass) {
    Write-Information "🧩 All governance PDF hashes verified successfully."
}
else {
    Write-Warning "❌ One or more governance PDF hashes failed verification."
}

Write-Information "🧾 Verification log saved: $OutFile"

