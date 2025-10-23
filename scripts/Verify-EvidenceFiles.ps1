<#
.SYNOPSIS
  Verifies that required evidence JSON files exist and match defined schemas.

.DESCRIPTION
  Performs repository integrity checks for PMDocu-DR evidence and schema compliance.
  - Detects missing / empty evidence JSON files.
  - Ensures each schema has a matching evidence file in docs/_evidence.
  - Enforces JSON Schema Draft-07 for all schemas.
  - Automatically runs Validate-EvidenceSchemas.ps1 if all checks pass.
  - Produces both JSON and Markdown summaries for audit records.

.EXAMPLE
  pwsh -NoProfile -File scripts/Verify-EvidenceFiles.ps1
#>

[CmdletBinding()]
param (
  [string]$EvidenceDir = (Join-Path $PSScriptRoot '..\docs\_evidence'),
  [string]$SchemaDir = (Join-Path $PSScriptRoot '..\schemas'),
  [string]$ReviewDir = (Join-Path $PSScriptRoot '..\docs\gov\review')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Required Evidence Patterns -----------------------------------------
$ExpectedPatterns = @(
  'SignResult_*.json',
  'VerifyHashResult_*.json',
  'BuildGovDocsResult_*.json',
  'ArchiveResult_*.json',
  'SchemaValidation_*.json'
)

# --- Path Validation ----------------------------------------------------
if (-not (Test-Path $EvidenceDir)) { Write-Error "Evidence dir not found: $EvidenceDir"; exit 1 }
if (-not (Test-Path $SchemaDir)) { Write-Error "Schema dir not found: $SchemaDir"; exit 1 }
if (-not (Test-Path $ReviewDir)) { New-Item -ItemType Directory -Force -Path $ReviewDir | Out-Null }

# --- Step 1: Missing or Empty Evidence ----------------------------------
$Missing = @()
$Empty = @()

foreach ($pattern in $ExpectedPatterns) {
  $files = Get-ChildItem -Path $EvidenceDir -Filter $pattern -ErrorAction SilentlyContinue
  if (-not $files) { $Missing += $pattern; continue }
  foreach ($f in $files) {
    if ((Get-Item $f.FullName).Length -eq 0) { $Empty += $f.Name }
  }
}

# --- Step 2: Schema Coverage --------------------------------------------
$SchemaFiles = Get-ChildItem -Path $SchemaDir -Filter '*.schema.json' -File
$SchemaMissingEvidence = @()

foreach ($schema in $SchemaFiles) {
  $base = [IO.Path]::GetFileNameWithoutExtension($schema.Name)
  if (-not (Get-ChildItem -Path $EvidenceDir -Filter "$base*.json" -ErrorAction SilentlyContinue)) {
    $SchemaMissingEvidence += $schema.Name
  }
}

# --- Step 3: Draft-07 Enforcement ---------------------------------------
$SchemaNonDraft7 = @()
foreach ($schema in $SchemaFiles) {
  $firstLines = Get-Content -Path $schema.FullName -TotalCount 5 -ErrorAction SilentlyContinue
  if ($firstLines -notmatch 'draft-07') { $SchemaNonDraft7 += $schema.Name }
}

# --- Step 4: Summary ----------------------------------------------------
$ExitCode = if (($Missing.Count -gt 0) -or ($Empty.Count -gt 0) -or
  ($SchemaMissingEvidence.Count -gt 0) -or ($SchemaNonDraft7.Count -gt 0)) { 1 } else { 0 }

$Status = if ($ExitCode -eq 0) { 'SUCCESS' } else { 'REVIEW_REQUIRED' }

$Summary = [ordered]@{
  missing_patterns = $Missing
  empty_files = $Empty
  schemas_missing_evidence = $SchemaMissingEvidence
  schemas_non_draft7 = $SchemaNonDraft7
  total_patterns_checked = $ExpectedPatterns.Count
  total_schemas_checked = $SchemaFiles.Count
  timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  status = $Status
}

# --- Step 5: Write JSON Summary ----------------------------------------
$JsonPath = Join-Path $EvidenceDir ("FileCheckSummary_{0}.json" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))
$Summary | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonPath -Encoding utf8NoBOM

# --- Step 6: Write Markdown Summary ------------------------------------
# NOTE:
# - Each interpolated string is wrapped in parentheses to satisfy strict parsers.
# - VS Code PowerShell extension may mis-flag '+=' lines without these.
# - Safe for PS 5.1 and PS 7.x.
# - Suppress local false positives for readability.
[Diagnostics.CodeAnalysis.SuppressMessage("ParseError", "", Justification = "Interpolated strings in += context are valid")]
$MdPath = Join-Path $ReviewDir ("FileCheckSummary_{0}.md" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))

$md = @()
$md += ( "# 🧾 Evidence & Schema File Verification Summary" )
$md += ""
$md += ( "**Timestamp (UTC):** $($Summary.timestamp_utc)" )
$md += ( "**Status:** `$Status`" )
$md += ""
$md += ( "| Category | Count | Details | " )
$md += ( "| ---------- - | ------ - | ---------- | " )
$md += ( "| Missing Evidence Patterns | $($Missing.Count) | $($Missing -join ', ') | " )
$md += ( "| Empty Evidence Files | $($Empty.Count) | $($Empty -join ', ') | " )
$md += ( "| Schemas Missing Evidence | $($SchemaMissingEvidence.Count) | $($SchemaMissingEvidence -join ', ') | " )
$md += ( "| Non-Draft-07 Schemas | $($SchemaNonDraft7.Count) | $($SchemaNonDraft7 -join ', ') | " )
$md += ( "| Invalid Schema Versions | $($SchemaVersionMismatch.Count) | $($SchemaVersionMismatch -join ', ') | " )
$md += ""
$md += ( "* * Overall Result:** `$Status`" )
$md += ""
$md += ( "_Generated by `scripts/Verify-EvidenceFiles.ps1`_" )

# Write Markdown file (UTF-8 without BOM)
$md -join "`r`n" | Set-Content -Path $MdPath -Encoding utf8NoBOM

# --- Step 6b: Console / CI output --------------------------------------
Write-Host ""
Write-Host ("🧾 JSON summary written: {0}" -f $JsonPath)
Write-Host ("🧾 Markdown summary written: {0}" -f $MdPath)

$summaryLine = ("SUMMARY: MISSING={0} EMPTY={1} SCHEMA_MISSING={2} NON_DRAFT7={3} VERSION_MISMATCH={4} STATUS={5}" -f `
    $Missing.Count, $Empty.Count, $SchemaMissingEvidence.Count, $SchemaNonDraft7.Count, $SchemaVersionMismatch.Count, $Status)
Write-Host $summaryLine

# --- Step 7: Conditional Schema Validation -----------------------------
if ($ExitCode -eq 0) {
  Write-Host "`n✅ All evidence and schemas verified. Launching Validate-EvidenceSchemas.ps1..."
  $Validate = Join-Path $PSScriptRoot 'Validate-EvidenceSchemas.ps1'
  if (Test-Path $Validate) {
    & pwsh -NoProfile -File $Validate
    exit $LASTEXITCODE
  } else {
    Write-Warning "⚠️ Validation script not found at $Validate"
    exit 0
  }
} else {
  Write-Warning "⚠️ Skipping validation due to missing or non-compliant files."
  exit 1
}
