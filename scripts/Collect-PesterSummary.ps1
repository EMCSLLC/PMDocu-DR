<#
.SYNOPSIS
  Runs all Pester tests in /tests and emits a single CI summary line,
  while writing structured JSON evidence to docs/_evidence/.

.DESCRIPTION
  Executes all Pester test scripts under the tests/ directory,
  collects aggregate pass/fail/skip counts, and produces both:
    1. A compact CI summary line for logs
    2. A JSON evidence file for audit traceability

  Example CI output:
    SUMMARY: TESTS=7 PASSED=7 FAILED=0 SKIPPED=0 DURATION=3.2s STATUS=SUCCESS
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Paths --------------------------------------------------------------
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$TestsPath = Join-Path $RepoRoot 'tests'
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
if (-not (Test-Path $EvidenceDir)) {
  New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
}

# --- Verify test folder -------------------------------------------------
if (-not (Test-Path $TestsPath)) {
  throw "Test directory not found: $TestsPath"
}

# --- Run Pester in CI mode ---------------------------------------------
$Result = Invoke-Pester -Path $TestsPath -PassThru -CI -Output None

# --- Extract metrics ----------------------------------------------------
$Total = $Result.TotalCount
$Passed = $Result.PassedCount
$Failed = $Result.FailedCount
$Skipped = $Result.SkippedCount
$Duration = ('{0:N1}' -f $Result.Duration.TotalSeconds)
$Status = if ($Failed -gt 0) { 'FAILURE' } else { 'SUCCESS' }

# --- Build evidence record ---------------------------------------------
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$OutputFile = Join-Path $EvidenceDir ("TestSummary_{0}.json" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))

$Evidence = [ordered]@{
  schema_version = '1.0.0'
  evidence_type = 'TestSummaryResult'
  script = 'scripts/Collect-PesterSummary.ps1'
  timestamp_utc = $Timestamp
  total_tests = $Total
  passed = $Passed
  failed = $Failed
  skipped = $Skipped
  duration_sec = [decimal]$Result.Duration.TotalSeconds
  environment = [ordered]@{
    os = if ($env:RUNNER_OS) { $env:RUNNER_OS } elseif ($env:OS) { $env:OS } else { 'Unknown OS' }
    ps_version = $PSVersionTable.PSVersion.ToString()
    hostname = $env:COMPUTERNAME
  }
  status = $Status
}

# --- Write JSON evidence -----------------------------------------------
$Evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputFile -Encoding utf8NoBOM

# --- Emit concise CI summary line --------------------------------------
Write-Output ("SUMMARY: TESTS={0} PASSED={1} FAILED={2} SKIPPED={3} DURATION={4}s STATUS={5}" -f `
    $Total, $Passed, $Failed, $Skipped, $Duration, $Status)
Write-Output ("EVIDENCE_FILE={0}" -f $OutputFile)

# --- Exit code for CI ---------------------------------------------------
if ($Failed -gt 0) { exit 1 }
exit 0
