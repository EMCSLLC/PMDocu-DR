<#
.SYNOPSIS
    Validates Markdown files in the repository using markdownlint-cli2.

.DESCRIPTION
    This test wrapper is optimized for development and CI verification.
    It calls markdownlint-cli2 with PMDocu-DR's rule set (config/.markdownlint.json)
    and writes evidence to docs/_evidence/MarkdownTest-<timestamp>.json.
    It does not stop the session unless fatal errors occur, allowing
    multiple tests to run in sequence.

.NOTES
    Requires Node.js and markdownlint-cli2.
    Install with: npm install -g markdownlint-cli2
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Information "[test-md] Starting Markdown rule validation..."

# ─── Paths ───────────────────────────────────────────────────────────────
$Config = 'config/.markdownlint.json'
$Evidence = 'docs/_evidence'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutFile = Join-Path $Evidence "MarkdownTest-$Timestamp.json"

# Ensure evidence folder exists
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null

# ─── Check for tool availability ─────────────────────────────────────────
if (-not (Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue)) {
    Write-Information "[test-md] ⚠ markdownlint-cli2 not found. Skipping test."
    return
}

# ─── Run linter ──────────────────────────────────────────────────────────
$cmd = "markdownlint-cli2 '**/*.md' '#node_modules' --config $Config --json"
Write-Information "[test-md] Running: $cmd"

$results = & cmd /c $cmd 2>&1
$results | Out-File -FilePath $OutFile -Encoding utf8

# ─── Detect issues ───────────────────────────────────────────────────────
if ($results -match 'MD\d{3}') {
    Write-Information "[test-md] ❌ Markdown issues detected."
    Write-Information "[test-md] Evidence file: $OutFile"
    Write-Information ($results -join [Environment]::NewLine)
} else {
    Write-Information "[test-md] ✅ Markdown test passed cleanly."
    Write-Information "[test-md] Evidence file: $OutFile"
}

Write-Information "[test-md] Completed."
