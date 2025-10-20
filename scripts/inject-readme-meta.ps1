<#
.SYNOPSIS
  Generates and optionally commits README.md from the template.

.DESCRIPTION
  Builds README.md from docs/_templates/README.template.md, injecting metadata:
  {{REPO_OWNER}}, {{REPO_NAME}}, {{VERSION}}, {{BUILD_DATE}}, {{NEXT_REVIEW}}.
  Writes evidence JSON into docs/_evidence/.
  Optionally commits and pushes changes if -Commit is specified.

.PARAMETER Template
  Path to the README template file (default: docs/_templates/README.template.md).

.PARAMETER Output
  Output path for the generated README (default: ./README.md).

.PARAMETER Commit
  When specified, automatically adds, commits, and pushes changes to Git.

.EXAMPLE
  .\scripts\inject-readme-meta.ps1

.EXAMPLE
  .\scripts\inject-readme-meta.ps1 -Commit
#>

[CmdletBinding()]
param(
    [string]$Template = "docs/_templates/README.template.md",
    [string]$Output = "README.md",
    [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path $Template)) {
        throw "Template not found: $Template"
    }

    # --- Repository info ---
    $repoRoot = (git rev-parse --show-toplevel 2>$null)
    if (-not $repoRoot) { throw "Not inside a Git repository." }

    $repoName = Split-Path $repoRoot -Leaf
    $remoteUrl = (git remote get-url origin 2>$null)
    $repoOwner = if ($remoteUrl -match '[:/]([^/]+)/[^/]+$') { $matches[1] } else { 'Unknown' }

    # --- Version detection from tags ---
    $gitTag = (git describe --tags --abbrev=0 2>$null)
    if (-not $gitTag) { $gitTag = "v1.0" }

    # --- Dates ---
    $buildDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss UTC")
    $nextReview = (Get-Date).AddMonths(6).ToString("yyyy-MM")

    # --- Inject metadata ---
    $templateText = Get-Content -Path $Template -Raw
    $outputText = $templateText `
        -replace '{{REPO_OWNER}}', $repoOwner `
        -replace '{{REPO_NAME}}', $repoName `
        -replace '{{VERSION}}', $gitTag `
        -replace '{{BUILD_DATE}}', $buildDate `
        -replace '{{NEXT_REVIEW}}', $nextReview

    # --- Write output ---
    $outputPath = Join-Path $repoRoot $Output
    $outputText | Out-File -FilePath $outputPath -Encoding utf8 -Force

    # --- Evidence record ---
    $evidenceDir = Join-Path $repoRoot "docs/_evidence"
    if (-not (Test-Path $evidenceDir)) {
        New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
    }

    $sha = (Get-FileHash -Algorithm SHA256 -Path $outputPath).Hash
    $jsonPath = Join-Path $evidenceDir ("ReadmeBuild-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    $record = @{
        file      = $Output
        generated = $buildDate
        commit    = (git rev-parse HEAD)
        hash      = $sha
        repo      = "$repoOwner/$repoName"
        version   = $gitTag
        mode      = if ($Commit) { "local-commit" } else { "local-preview" }
    }

    $record | ConvertTo-Json | Out-File -FilePath $jsonPath -Encoding utf8 -Force

    Write-Output ("README_BUILT={0}" -f $outputPath)
    Write-Output ("EVIDENCE_FILE={0}" -f $jsonPath)

    # --- Optional Commit logic ---
    if ($Commit) {
        Write-Verbose "Committing README and evidence changes..."
        Push-Location $repoRoot

        git add README.md docs/_evidence/ | Out-Null
        $diff = git diff --cached --name-only
        if ($diff) {
            $commitMsg = "🪶 Local README rebuild ($gitTag)"
            git commit -m $commitMsg | Out-Null
            git push | Out-Null
            Write-Output ("COMMIT_MESSAGE={0}" -f $commitMsg)
            Write-Output "STATUS=SUCCESS (committed)"
        }
        else {
            Write-Output "No changes detected — nothing committed."
            Write-Output "STATUS=SUCCESS (no-op)"
        }

        Pop-Location
    }
    else {
        Write-Output "STATUS=SUCCESS (preview)"
    }
}
catch {
    Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
    exit 1
}

