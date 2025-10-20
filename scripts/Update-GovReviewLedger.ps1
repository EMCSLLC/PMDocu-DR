<#
.SYNOPSIS
    Updates or previews the Governance Review Hash Ledger (GovReviewHashes-Template.md).

.DESCRIPTION
    Reads all JSON hash records from `docs/_evidence/GovReviewHashes-*.json`
    and appends any new entries to `docs/gov/review/GovReviewHashes-Template.md`.
    If -CheckOnly is specified, no files are written or committed — only differences are shown.

.PARAMETER CheckOnly
    Preview mode: outputs what would be added, but does not modify files or commit changes.

.EXAMPLE
    pwsh -NoProfile -File scripts/Update-GovReviewLedger.ps1

.EXAMPLE
    pwsh -NoProfile -File scripts/Update-GovReviewLedger.ps1 -CheckOnly
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$EvidenceDir = "docs/_evidence"
$LedgerFile = "docs/gov/review/GovReviewHashes-Template.md"

if (-not (Test-Path $EvidenceDir)) {
    Write-Information "Evidence directory not found: $EvidenceDir"
    exit 0
}
if (-not (Test-Path $LedgerFile)) {
    Write-Information "Ledger file not found, creating new: $LedgerFile"
    New-Item -ItemType File -Path $LedgerFile -Force | Out-Null
}

$ledgerContent = Get-Content $LedgerFile -Raw
$existingRows = ($ledgerContent -split "`n") | Where-Object { $_ -match '\| GovReviewHashes-' }

$hashFiles = Get-ChildItem -Path $EvidenceDir -Filter 'GovReviewHashes-*.json' | Sort-Object LastWriteTimeUtc
if (-not $hashFiles) {
    Write-Information "No governance hash JSON files found in $EvidenceDir"
    exit 0
}

$entriesToAdd = @()

foreach ($file in $hashFiles) {
    $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
    if (-not $json) { continue }

    if ($file.BaseName -match 'GovReviewHashes-(\d{8})-(\d{6})') {
        $timestamp = "{0}-{1}" -f $matches[1], $matches[2]
        $utc = [datetime]::ParseExact($timestamp, 'yyyyMMdd-HHmmss', $null).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    }
    else {
        $utc = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }

    foreach ($entry in $json) {
        $source = $entry.file
        $sha = $entry.sha256
        $jsonFile = $file.Name

        if ($existingRows -match [regex]::Escape($jsonFile)) { continue }

        $entriesToAdd += "| $utc | `$jsonFile` | `$sha` | `$source` |"
    }
}

if (-not $entriesToAdd) {
    Write-Information "[info] No new ledger entries found."
    exit 0
}

if ($CheckOnly) {
    Write-Information "🧾 Ledger preview mode (-CheckOnly enabled)"
    Write-Host "`nEntries that would be added:`n" -ForegroundColor Cyan
    $entriesToAdd | ForEach-Object { Write-Host $_ }
    exit 0
}

# Append new rows
foreach ($row in $entriesToAdd) {
    Add-Content -Path $LedgerFile -Value $row
    Write-Information "🧾 Added ledger entry: $row"
}

Write-Information "[done] Governance hash ledger updated successfully."

# ──────────────────────────────────────────────────────────────
# Optional Auto-Commit if in GitHub Actions or local git repo
# ──────────────────────────────────────────────────────────────
if ($env:GITHUB_ACTIONS -eq 'true' -or (Test-Path '.git')) {
    try {
        Write-Information "[git] Preparing to commit ledger update..."
        git config user.name  "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"

        git add $LedgerFile
        $diff = git diff --cached --name-only
        if ($diff) {
            $msg = "🧾 Update governance hash ledger ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
            git commit -m $msg
            if ($env:GITHUB_TOKEN) {
                git push "https://x-access-token:$($env:GITHUB_TOKEN)@github.com/$($env:GITHUB_REPOSITORY).git" HEAD:$env:GITHUB_REF
                Write-Information "[git] Ledger changes pushed successfully."
            }
            else {
                Write-Information "[git] Commit created locally (no push token available)."
            }
        }
        else {
            Write-Information "[git] No staged changes detected — skipping commit."
        }
    }
    catch {
        Write-Warning "⚠️ Git auto-commit failed: $($_.Exception.Message)"
    }
}

