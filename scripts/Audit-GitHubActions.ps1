<#
.SYNOPSIS
    Scans all GitHub Actions workflow files for outdated action versions.

.DESCRIPTION
    Finds all 'uses:' references in .github/workflows and reports
    which actions use older versions (v1, v2, v3).
    Useful for ensuring consistent CI maintenance.

.EXAMPLE
    pwsh scripts/Audit-GitHubActions.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$WorkflowDir = ".github/workflows"
if (-not (Test-Path $WorkflowDir)) {
    Write-Warning "No .github/workflows directory found."
    exit 0
}

$actions =
Get-ChildItem -Path $WorkflowDir -Filter *.yml -Recurse |
    Select-String -Pattern 'uses:\s*([a-zA-Z0-9_\-/]+)@v(\d+)' |
    ForEach-Object {
        $version = [int]$_.Matches.Groups[2].Value
        [PSCustomObject]@{
            File = $_.Path
            Line = $_.LineNumber
            Action = $_.Matches.Groups[1].Value
            Version = "v$version"
            Suggest = if ($version -lt 4) { "Consider upgrading to v4 if available" } else { "OK" }
        }
    }

if ($actions) {
    Write-Output "🔍 GitHub Actions version audit:"
    $actions | Sort-Object Action, Version | Format-Table -AutoSize
} else {
    Write-Output "✅ No 'uses:' references found in workflows."
}

# Optional summary JSON for automation
$OutDir = ".\docs\_evidence\verify"
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$OutFile = Join-Path $OutDir ("actions_version_audit_{0:yyyyMMdd_HHmmss}.json" -f (Get-Date))
$actions | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutFile -Encoding UTF8
Write-Output "📁 Audit JSON written to: $OutFile"
