<#
.SYNOPSIS
    Generates README.md from README.template.md, logs evidence, and commits
    automatically when executed inside GitHub Actions.

.DESCRIPTION
    - Replaces ${REPO} in README.template.md with the actual GitHub repo path.
    - Logs JSON evidence under docs/_evidence.
    - If GITHUB_ACTIONS=true, commits README.md to the current branch
      using an auto-generated commit message and bot identity.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "[build-readme] Starting README generation..."

# ────────────────────────────────────────────────────────────────
# Resolve repo paths
# ────────────────────────────────────────────────────────────────
$Root = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $Root 'README.template.md'
$Output = Join-Path $Root 'README.md'
$Evidence = Join-Path $Root 'docs/_evidence'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$EvidenceFile = Join-Path $Evidence "ReadmeBuild-$Timestamp.json"

if (-not (Test-Path $Template)) {
    throw "Template file not found: $Template"
}

New-Item -ItemType Directory -Force -Path $Evidence | Out-Null

# ────────────────────────────────────────────────────────────────
# Detect repository name
# ────────────────────────────────────────────────────────────────
$Repo = $env:GITHUB_REPOSITORY
if (-not $Repo) {
    try {
        $Repo = git config --get remote.origin.url |
        ForEach-Object { ($_ -replace '.*[:/](.+?)(?:\.git)?$', '$1') }
    } catch {
        $Repo = 'EMCSLLC/PMDocu-DR'
    }
}
Write-Information "[build-readme] Repository detected: $Repo"

# ────────────────────────────────────────────────────────────────
# Perform substitution and write README.md
# ────────────────────────────────────────────────────────────────
$Content = Get-Content -Raw -Path $Template
$Updated = $Content -replace '\$\{REPO\}', [Regex]::Escape($Repo)
$Updated | Set-Content -Path $Output -Encoding utf8
Write-Information "[build-readme] README.md generated."

# ────────────────────────────────────────────────────────────────
# Log compliance evidence
# ────────────────────────────────────────────────────────────────
$EvidenceData = [pscustomobject]@{
    repo          = $Repo
    template_used = Split-Path -Leaf $Template
    output_file   = Split-Path -Leaf $Output
    generated_at  = (Get-Date).ToString('u')
    status        = 'success'
    auto_commit   = $false
}
$EvidenceData | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 $EvidenceFile
Write-Information "[build-readme] Evidence logged: $EvidenceFile"

# ────────────────────────────────────────────────────────────────
# Auto-commit in GitHub Actions
# ────────────────────────────────────────────────────────────────
if ($env:GITHUB_ACTIONS -eq 'true') {
    Write-Information "[build-readme] Detected CI environment – attempting auto-commit..."

    git config user.name  "PMDocu-Bot"
    git config user.email "pmdocu-bot@emcsllc.local"

    $status = git status --porcelain README.md
    if ($status) {
        git add README.md
        git commit -m "🤖 Auto-update README badges [auto-readme]"
        git push origin HEAD
        $EvidenceData.auto_commit = $true
        Write-Information "[build-readme] ✅ Changes committed to branch."
    } else {
        Write-Information "[build-readme] No changes detected; nothing to commit."
    }

    # Update evidence to reflect commit status
    $EvidenceData | ConvertTo-Json -Depth 4 | Out-File -Encoding utf8 $EvidenceFile
}

Write-Information "[build-readme] ✅ Completed successfully."
