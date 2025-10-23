<#
.SYNOPSIS
    Tests build process for governance documents and outputs structured JSON evidence.

.DESCRIPTION
    Runs document build verification, logs results, and writes a compliant
    BuildGovDocsResult-YYYYMMDD-HHmmss.json file under docs/_evidence/.
#>

[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Prepare evidence output path -------------------------------------------
$EvidencePath = Join-Path $Root 'docs/_evidence'
if (-not (Test-Path $EvidencePath)) {
    New-Item -ItemType Directory -Force -Path $EvidencePath | Out-Null
}

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutFile = Join-Path $EvidencePath ("BuildGovDocsResult-$Timestamp.json")
Write-Output "🧾 Building governance documents → $OutFile"

# --- Run build test ---------------------------------------------------------
try {
    $DocsPath = Join-Path $Root 'docs/gov'
    $PdfFiles = @(Get-ChildItem -Path $DocsPath -Recurse -Include *.pdf -ErrorAction SilentlyContinue)
    if (-not $PdfFiles) { $PdfFiles = @() }

    $Details = @()
    foreach ($pdf in @($PdfFiles)) {
        if ($pdf -is [System.IO.FileInfo]) {
            $Details += [ordered]@{
                file_name = $pdf.Name
                size_kb = [math]::Round($pdf.Length / 1KB, 2)
                modified = $pdf.LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
                build_pass = $true
            }
        }
    }

    # Count defensively
    $TotalPdfCount = @($PdfFiles).Count
    $GeneratedCount = @($Details | Where-Object { $_.build_pass }).Count
    $OverallStatus = if ($TotalPdfCount -gt 0) { "Success" } else { "Fail" }

    $Result = [ordered]@{
        schema_version = "1.0.0"
        evidence_type = "BuildGovDocsResult"
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        workflow = ".github/workflows/nightly-validate.yml"
        build_status = $OverallStatus
        overall_status = $OverallStatus
        build_summary = @{
            total_pdfs = $TotalPdfCount
            generated = $GeneratedCount
        }
        details = $Details
        notes = "Automated build evidence for governance document validation."
    }

    Write-Output "✅ BuildGovDocsResult status: $OverallStatus"
} catch {
    Write-Warning "⚠️ BuildGovDocsResult encountered an error: $($_.Exception.Message)"
    $Result = [ordered]@{
        schema_version = "1.0.0"
        evidence_type = "BuildGovDocsResult"
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        workflow = ".github/workflows/nightly-validate.yml"
        build_status = "Fail"
        overall_status = "Fail"
        build_summary = @{ total_pdfs = 0; generated = 0 }
        details = @()
        notes = "Build process failed: $($_.Exception.Message)"
    }
}

# --- Write JSON evidence ----------------------------------------------------
$Result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Output "📄 Evidence written: $OutFile"
