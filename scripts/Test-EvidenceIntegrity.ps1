<#
.SYNOPSIS
  Validates JSON evidence files before commit or audit and writes a structured summary report.

.DESCRIPTION
  Scans docs/_evidence for invalid, unreadable, or empty JSON files.
  Generates a JSON summary report (EvidenceIntegrity-YYYYMMDD-HHmmss.json)
  for traceability and CI evidence retention.

.EXAMPLE
  pwsh -File scripts/Test-EvidenceIntegrity.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$EvidenceDir = 'docs/_evidence'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportFile = Join-Path $EvidenceDir "EvidenceIntegrity-$Timestamp.json"

# Ensure folder exists
if (-not (Test-Path $EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
}

$Files = Get-ChildItem $EvidenceDir -Filter '*.json' -Recurse -ErrorAction SilentlyContinue
$Results = @()
$Failed = @()

if (-not $Files) {
    $Results += [pscustomobject]@{
        File   = "(none)"
        Status = "No JSON files found"
        Valid  = $false
    }
}
else {
    foreach ($File in $Files) {
        $entry = [ordered]@{
            File   = $File.FullName
            Status = ""
            Valid  = $false
        }

        try {
            $json = Get-Content $File -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $json -or $json.Count -eq 0) {
                $entry.Status = "Empty or missing content"
            }
            else {
                $entry.Status = "Valid JSON"
                $entry.Valid = $true
            }
        }
        catch {
            $entry.Status = "Invalid JSON: $($_.Exception.Message)"
        }

        $Results += [pscustomobject]$entry
        if (-not $entry.Valid) { $Failed += $File.FullName }
    }
}

$Summary = [ordered]@{
    Timestamp    = (Get-Date).ToString("s")
    TotalChecked = $Results.Count
    ValidCount   = ($Results | Where-Object { $_.Valid } | Measure-Object).Count
    FailedCount  = $Failed.Count
    FailedFiles  = $Failed
    Results      = $Results
}

# Write JSON report (UTF-8)
$Summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $ReportFile -Encoding utf8

if ($Failed.Count -gt 0) {
    Write-Error "Evidence validation failed for $($Failed.Count) file(s). Report saved to: $ReportFile"
    exit 1
}

Write-Information "All evidence JSON files passed validation. Report saved to: $ReportFile"
exit 0

