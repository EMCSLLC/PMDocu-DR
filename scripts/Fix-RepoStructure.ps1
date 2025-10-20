<#
.SYNOPSIS
  Validates and corrects the PMDocu-DR folder structure.

.DESCRIPTION
  Ensures required directories and scripts exist in their proper locations.
  Optionally runs Update-RepoTree.ps1 after completion to log an evidence snapshot.

.PARAMETER CheckOnly
  Performs a dry-run without making any filesystem changes.

.PARAMETER AutoTree
  Automatically runs Update-RepoTree.ps1 after successful structure verification/fix.

.EXAMPLE
  .\scripts\Fix-RepoStructure.ps1

.EXAMPLE
  .\scripts\Fix-RepoStructure.ps1 -CheckOnly -Verbose

.EXAMPLE
  .\scripts\Fix-RepoStructure.ps1 -AutoTree -Verbose
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$AutoTree
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log {
    param([string]$Message)
    $time = (Get-Date -Format 'HH:mm:ss')
    $global:LogLines += "$time $Message"
    if ($PSBoundParameters['Verbose']) { Write-Verbose $Message }
}

try {
    $RepoRoot = (Get-Location).Path
    $EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
    $TemplatesDir = Join-Path $RepoRoot 'docs/_templates'
    $OldTemplates = Join-Path $RepoRoot 'docs/templates'
    $ScriptsDir = Join-Path $RepoRoot 'scripts'
    $ReleasesDir = Join-Path $RepoRoot 'docs/releases'

    $global:LogLines = @()
    Log "=== PMDocu-DR Repo Structure Verification Started ==="

    # --- 1. Ensure docs/_templates ---
    if (Test-Path $OldTemplates) {
        Log "docs/templates detected → will rename to docs/_templates"
        if (-not $CheckOnly) {
            Rename-Item -Path $OldTemplates -NewName '_templates' -Force
        }
    }
    elseif (-not (Test-Path $TemplatesDir)) {
        Log "docs/_templates missing → will create"
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Force -Path $TemplatesDir | Out-Null
        }
    }
    else {
        Log "docs/_templates already correct"
    }

    # --- 2. Ensure scripts directory ---
    if (-not (Test-Path $ScriptsDir)) {
        Log "scripts directory missing → will create"
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
        }
    }
    else {
        Log "scripts directory present"
    }

    # --- 3. Move known scripts if misplaced ---
    $psScripts = @(
        'build-doc.ps1',
        'sign-gpg.ps1',
        'verify-hash.ps1',
        'inject-readme-meta.ps1'
    )

    foreach ($script in $psScripts) {
        $found = Get-ChildItem -Path $RepoRoot -Recurse -Filter $script -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -notmatch '\\scripts$' } | Select-Object -First 1
        if ($found) {
            $target = Join-Path $ScriptsDir $script
            Log "Found misplaced script: $($found.FullName) → will move to $target"
            if (-not $CheckOnly) {
                Move-Item -Force -Path $found.FullName -Destination $target
            }
        }
    }

    # --- 4. Ensure evidence folder ---
    if (-not (Test-Path $EvidenceDir)) {
        Log "docs/_evidence missing → will create"
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
        }
    }
    else {
        Log "docs/_evidence present"
    }

    # --- 5. Ensure releases folder ---
    if (-not (Test-Path $ReleasesDir)) {
        Log "docs/releases missing → will create"
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Force -Path $ReleasesDir | Out-Null
        }
    }
    else {
        Log "docs/releases present"
    }

    # --- 6. Log completion ---
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFile = Join-Path $EvidenceDir ("RepoStructureFix-{0}.log" -f $timestamp)
    $global:LogLines += "=== Completed $(Get-Date -Format 'u') ==="

    if (-not $CheckOnly) {
        $global:LogLines | Out-File -FilePath $logFile -Encoding utf8 -Force
        Write-Output ("STRUCTURE_FIXED_LOG={0}" -f $logFile)
    }
    else {
        Write-Output "DRY-RUN: No changes applied"
    }

    # --- 7. Optionally trigger Update-RepoTree ---
    if ($AutoTree) {
        $updateTree = Join-Path $ScriptsDir 'Update-RepoTree.ps1'
        if (Test-Path $updateTree) {
            Log "AutoTree enabled → running Update-RepoTree.ps1"
            if (-not $CheckOnly) {
                & pwsh -NoProfile -File $updateTree -Verbose:$PSBoundParameters['Verbose']
                if ($LASTEXITCODE -ne 0) {
                    Log "Warning: RepoTree generation encountered issues."
                }
            }
            else {
                Log "[DRY-RUN] Would run Update-RepoTree.ps1"
            }
        }
        else {
            Log "Warning: Update-RepoTree.ps1 not found under scripts/"
        }
    }

    Write-Output "STATUS=SUCCESS"
}
catch {
    Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
    exit 1
}

