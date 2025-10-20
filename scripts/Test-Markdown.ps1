<#
.SYNOPSIS
    Runs markdownlint-cli2 against all Markdown files in the repository.

.DESCRIPTION
    Executes markdownlint-cli2 using PMDocu-DR's config/.markdownlint.json rules.
    Outputs a JSON evidence report under docs/_evidence/.
    Exits with code 1 if any linting issues are found (for CI integration).

.NOTES
    Requires: Node.js + markdownlint-cli2 (npm install -g markdownlint-cli2)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Information "[lint-md] Starting markdown validation..."

# ─── Paths ───────────────────────────────────────────────────────────────
$Config = 'config/.markdownlint.json'
$Evidence = 'docs/_evidence'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutFile = Join-Path $Evidence "MarkdownReport-$Timestamp.json"

# Ensure evidence directory exists
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null

# ─── Verify markdownlint-cli2 availability ──────────────────────────────
if (-not (Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue)) {
    throw "markdownlint-cli2 not found. Run: npm install -g markdownlint-cli2"
}

# ─── Run Linter ─────────────────────────────────────────────────────────
$cmd = "markdownlint-cli2 '**/*.md' '#node_modules' --config $Config --json"
Write-Information "[lint-md] Running command: $cmd"

$results = & cmd /c $cmd 2>&1
$results | Out-File -FilePath $OutFile -Encoding utf8

# ─── Parse and summarize ────────────────────────────────────────────────
if ($results -match 'MD\d{3}') {
    Write-Information "[lint-md] ❌ Issues detected. Evidence file: $OutFile"
    Write-Information ($results -join [Environment]::NewLine)
    exit 1
}
else {
    Write-Information "[lint-md] ✅ No lint issues found. Evidence file: $OutFile"
}

Write-Information "[lint-md] Completed successfully."

