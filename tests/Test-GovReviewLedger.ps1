<#
.SYNOPSIS
    Validates that all GovReviewHashes JSON files are reflected in the Governance Ledger.

.DESCRIPTION
    Compares entries in `docs/_evidence/GovReviewHashes-*.json`
    against the Markdown ledger `docs/gov/review/GovReviewHashes-Template.md`.

    If any evidence file is missing from the ledger, the test fails.
    Generates an evidence JSON file and structured summary for logs.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$EvidenceDir = "docs/_evidence"
$LedgerFile = "docs/gov/review/GovReviewHashes-Template.md"

Write-Information "[init] Starting governance ledger validation..."

if (-not (Test-Path $EvidenceDir)) {
    throw "Evidence directory not found: $EvidenceDir"
}
if (-not (Test-Path $LedgerFile)) {
    throw "Ledger file not found: $LedgerFile"
}

# Gather expected evidence files
$expected = Get-ChildItem -Path $EvidenceDir -Filter 'GovReviewHashes-*.json' |
Sort-Object Name | ForEach-Object { $_.Name }

# Gather recorded entries in the ledger
$ledgerLines = Get-Content $LedgerFile -Raw -ErrorAction Stop -Encoding UTF8
$recorded = @()
if ($ledgerLines) {
    $recorded = ($ledgerLines -split "`n") |
    Where-Object { $_ -match '\| GovReviewHashes-[0-9]+' } |
    ForEach-Object {
        ($_ -split '\|')[2].Trim(' `')
    }
}

# Compare expected evidence files against ledger entries
$missing = $expected | Where-Object { $_ -notin $recorded }
$extra = $recorded | Where-Object { $_ -notin $expected }

# Build summary
$results = [ordered]@{
    timestamp_utc  = (Get-Date).ToUniversalTime().ToString('u')
    expected_count = $expected.Count
    recorded_count = $recorded.Count
    missing_count  = $missing.Count
    extra_count    = $extra.Count
    missing_files  = $missing
    extra_entries  = $extra
}

# Write JSON evidence file
$OutFile = Join-Path $EvidenceDir ("TestGovReviewLedger-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$results | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
Write-Information "🧾 Test result saved: $OutFile"

# Structured log summary
Write-Information "──────────────────────────────────────────────────────────"
Write-Information "🧩 Governance Ledger Validation Summary"
Write-Information "──────────────────────────────────────────────────────────"
Write-Information ("Expected: {0}   Recorded: {1}" -f $expected.Count, $recorded.Count)
Write-Information ("Missing:  {0}   Extra: {1}" -f $missing.Count, $extra.Count)

# Human-readable interactive summary (for local runs)
if (-not $env:GITHUB_ACTIONS) {
    $tableData = @()

    $ledgerLines -split "`n" | ForEach-Object {
        if ($_ -match '^\|') {
            $cols = ($_ -split '\|') | ForEach-Object { $_.Trim() }
            if ($cols[1] -and $cols[2] -match 'GovReviewHashes-') {
                $tableData += [pscustomobject]@{
                    'Timestamp (UTC)' = $cols[1]
                    'Evidence File'   = $cols[2]
                    'SHA-256 Hash'    = $cols[3]
                    'Source Review'   = $cols[4]
                }
            }
        }
    }

    if ($tableData.Count -gt 0) {
        Write-Information "🧾 Current Ledger Entries:"
        $tableData | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Information $_ }
    } else {
        Write-Information "⚠️ No ledger entries found in the Markdown file."
    }
}

# Fail CI if discrepancies found
if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    Write-Warning "⚠️ Governance ledger not in sync with evidence directory!"
    exit 1
}

Write-Information "[pass] Governance ledger validation successful."
