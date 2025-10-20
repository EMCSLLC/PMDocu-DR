<#
.SYNOPSIS
  Generates a full folder and file tree of the repository.

.DESCRIPTION
  Creates/updates RepoTree.txt at the repo root and saves a
  timestamped copy in docs/_evidence/ for compliance traceability.
  Supports -CheckOnly (dry-run). Uses built-in -Verbose support.

.PARAMETER CheckOnly
  Performs a dry-run (shows what would happen but does not write files).

.EXAMPLE
  .\scripts\Update-RepoTree.ps1

.EXAMPLE
  .\scripts\Update-RepoTree.ps1 -Verbose

.EXAMPLE
  .\scripts\Update-RepoTree.ps1 -CheckOnly -Verbose
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log {
    param([string]$msg)
    $time = (Get-Date -Format 'HH:mm:ss')
    $global:LogLines += "$time $msg"
    if ($PSBoundParameters['Verbose']) { Write-Verbose $msg }
}

try {
    $RepoRoot = (Get-Location).Path
    $EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
    $OutputFile = Join-Path $RepoRoot 'RepoTree.txt'

    $global:LogLines = @()
    Log "=== PMDocu-DR Repo Tree Update Started ==="

    # Ensure evidence directory exists
    if (-not (Test-Path $EvidenceDir)) {
        Log "Creating docs/_evidence directory"
        if (-not $CheckOnly) {
            New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
        }
    }

    # Build file/folder tree representation
    Log "Building repository tree view..."
    $tree = & cmd /c "tree /F /A" 2>$null
    if (-not $tree) {
        throw "Failed to generate tree listing — ensure Windows 'tree' command is available."
    }

    # Write RepoTree.txt at root
    if (-not $CheckOnly) {
        $tree | Out-File -FilePath $OutputFile -Encoding utf8 -Force
        Log "Updated root RepoTree.txt"
    }
    else {
        Log "[DRY-RUN] Would update RepoTree.txt"
    }

    # Write timestamped copy in docs/_evidence/
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $EvidenceCopy = Join-Path $EvidenceDir ("RepoTree-$timestamp.txt")
    if (-not $CheckOnly) {
        $tree | Out-File -FilePath $EvidenceCopy -Encoding utf8 -Force
        Log "Saved evidence copy: $EvidenceCopy"
    }
    else {
        Log "[DRY-RUN] Would save $EvidenceCopy"
    }

    # Log completion
    $global:LogLines += "=== Completed $(Get-Date -Format 'u') ==="

    # Save operation log in evidence directory
    if (-not $CheckOnly) {
        $logFile = Join-Path $EvidenceDir ("RepoTreeUpdate-{0}.log" -f $timestamp)
        $global:LogLines | Out-File -FilePath $logFile -Encoding utf8 -Force
        Write-Output ("TREE_UPDATED_LOG={0}" -f $logFile)
    }
    else {
        Write-Output "DRY-RUN: No changes applied"
    }

    Write-Output "STATUS=SUCCESS"
}
catch {
    Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
    exit 1
}

