<#
.SYNOPSIS
  Safely backs up and cleans old evidence and schema validation files.

.DESCRIPTION
  Archives current contents of docs/_evidence/ into a dated ZIP under docs/_archive/,
  then selectively removes transient or redundant evidence (SchemaValidation, FileCheckSummary, etc.)
  while preserving permanent evidence (SignResult, VerifyResult, BuildGovDocsResult, etc.).

  Intended for annual or pre-release cleanup as part of CI-EV-05.

.EXAMPLE
  pwsh -NoProfile -File scripts/Cleanup-Evidence.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Paths --------------------------------------------------------------
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
$ArchiveDir = Join-Path $RepoRoot 'docs/_archive'

if (-not (Test-Path $EvidenceDir)) { throw "Evidence directory not found: $EvidenceDir" }
if (-not (Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null }

# --- Backup current evidence -------------------------------------------
$Timestamp = (Get-Date -Format 'yyyyMMdd_HHmmss')
$BackupZip = Join-Path $ArchiveDir "backup_evidence_$Timestamp.zip"

Write-Host "📦 Backing up current evidence to $BackupZip ..."
Compress-Archive -Path (Join-Path $EvidenceDir '*') -DestinationPath $BackupZip -Force

# --- Define patterns to safely remove ----------------------------------
$PatternsToRemove = @(
    'SchemaValidation_*.json',
    'FileCheckSummary_*.json',
    'TestBuildGovDocsEvidence_*.json',
    'BaselineValidationResult_*.json',
    'NightlyValidateResult_*.json'
)

Write-Host "🧹 Removing transient evidence files..."
foreach ($pattern in $PatternsToRemove) {
    Get-ChildItem -Path $EvidenceDir -Filter $pattern -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# --- Summary ------------------------------------------------------------
$Remaining = (Get-ChildItem -Path $EvidenceDir -File).Count
Write-Host "✅ Cleanup complete. Remaining evidence files: $Remaining"
Write-Host "🗄️  Backup created at: $BackupZip"

# --- Optional: trigger re-validation -----------------------------------
$ValidateScript = Join-Path $RepoRoot 'scripts/Validate-EvidenceSchemas.ps1'
if (Test-Path $ValidateScript) {
    Write-Host "🔎 Re-validating schemas after cleanup..."
    & $ValidateScript
}
