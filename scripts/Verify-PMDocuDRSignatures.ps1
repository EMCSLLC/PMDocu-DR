<#
.SYNOPSIS
    Verifies Authenticode signatures and SHA-256 hashes for all PMDocu-DR PDFs.

.DESCRIPTION
    Scans the release directory for .pdf files.
    Verifies each file’s Authenticode signature and SHA-256 checksum.
    Produces structured JSON and Markdown evidence reports suitable for CI upload.
    If -FailOnInvalid is set, the script exits immediately on the first failed signature.

.EXAMPLE
    pwsh scripts/Verify-PMDocuDRSignatures.ps1 -Path .\docs\releases -OutDir .\docs\_evidence\verify -FailOnInvalid
#>

[CmdletBinding()]
param(
    [string]$Path = ".\docs\releases",
    [string]$OutDir = ".\docs\_evidence\verify",
    [switch]$FailOnInvalid
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Ensure output directory exists
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$results = @()
$files = Get-ChildItem -Path $Path -Filter *.pdf -ErrorAction SilentlyContinue

if (-not $files) {
    Write-Warning "No PDF files found under $Path"
    exit 0
}

foreach ($file in $files) {
    try {
        $sig = Get-AuthenticodeSignature $file.FullName
        $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
        $status = if ($sig.Status -eq 'Valid') { 'PASS' } else { 'FAIL' }

        $entry = [ordered]@{
            File       = $file.Name
            FullPath   = $file.FullName
            SHA256     = $hash
            Status     = $status
            Signer     = $sig.SignerCertificate.Subject
            Thumbprint = $sig.SignerCertificate.Thumbprint
            VerifiedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
        }

        $results += $entry

        if ($FailOnInvalid -and $status -ne 'PASS') {
            Write-Error "Signature verification failed for $($file.Name). Failing early."
            $results | ConvertTo-Json -Depth 4 | Out-File (Join-Path $OutDir 'evidence_fail_snapshot.json') -Encoding UTF8 -Force
            exit 1
        }
    } catch {
        $results += [ordered]@{
            File       = $file.Name
            FullPath   = $file.FullName
            SHA256     = $null
            Status     = 'ERROR'
            Signer     = $null
            Thumbprint = $null
            VerifiedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
            Error      = $_.Exception.Message
        }

        if ($FailOnInvalid) {
            Write-Error "Unhandled error verifying $($file.Name): $($_.Exception.Message)"
            exit 1
        }
    }
}

# Write reports
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$jsonPath = Join-Path $OutDir "evidence_report_${timestamp}.json"
$mdPath = Join-Path $OutDir "evidence_report_${timestamp}.md"

$results | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonPath -Encoding UTF8 -Force

$header = @(
    "# 📜 PMDocu-DR Signature Verification Report",
    "",
    "| File | Status | SHA256 | Signer | VerifiedAt |",
    "|------|---------|--------|---------|------------|"
)
$rows = $results | ForEach-Object {
    $sha = if ($_.SHA256) { $_.SHA256.Substring(0, 16) + "…" } else { "-" }
    "| $($_.File) | $($_.Status) | $sha | $($_.Signer) | $($_.VerifiedAt) |"
}
($header + $rows) -join "`n" | Out-File -FilePath $mdPath -Encoding UTF8 -Force

# Summary
$pass = ($results | Where-Object { $_.Status -eq 'PASS' }).Count
$total = $results.Count
$fail = $total - $pass

Write-Output "Signatures verified: $pass / $total passed, $fail failed."
Write-Output "Evidence reports:"
Write-Output " - JSON: $jsonPath"
Write-Output " - Markdown: $mdPath"

if ($FailOnInvalid -and $fail -gt 0) {
    Write-Error "Verification completed with $fail failed signatures."
    exit 1
}

return $results
