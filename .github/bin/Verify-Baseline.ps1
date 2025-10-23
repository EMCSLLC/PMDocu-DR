<#
.SYNOPSIS
    Offline verifier for PMDocu-DR Baseline Snapshots.

.DESCRIPTION
    Validates integrity of Baseline-YYYYMMDD.md files by checking:
      • SHA-256 hash file (.sha256)
      • Optional GPG detached signature (.asc)
      • Optional Authenticode signature
    Runs fully offline—no timestamp or network calls required.
    Writes structured JSON evidence to docs/_evidence/BaselineVerifyResult-<timestamp>.json
#>

[CmdletBinding()]
param(
    [string]$File = (Get-ChildItem 'docs/releases' -Filter 'Baseline-*.md' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $File) {
    Write-Warning "No baseline file found to verify."
    exit 1
}

Write-Output "🧾 Verifying baseline snapshot → $File"

$Results = @{
    sha256_status  = 'Skipped'
    gpg_status     = 'Skipped'
    auth_status    = 'Skipped'
    overall_status = 'Unknown'
    file           = $File
}

# --- SHA-256 check ---------------------------------------------------------
$HashFile = "$File.sha256"
if (Test-Path $HashFile) {
    $expected = (Get-Content $HashFile -Raw).Split()[0]
    $actual = (Get-FileHash -Algorithm SHA256 -Path $File).Hash
    if ($expected -eq $actual) {
        Write-Output "✅ SHA-256 verified OK"
        $Results.sha256_status = 'Valid'
    } else {
        Write-Warning "❌ SHA-256 mismatch"
        $Results.sha256_status = 'Invalid'
    }
} else {
    Write-Warning "No .sha256 file present; skipping hash verification."
}

# --- GPG detached signature (.asc) check -----------------------------------
$Asc = "$File.asc"
if (Test-Path $Asc) {
    try {
        $verify = & gpg --verify $Asc $File 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ GPG signature verified OK"
            $Results.gpg_status = 'Valid'
        } else {
            Write-Warning "❌ GPG signature verification failed"
            $Results.gpg_status = 'Invalid'
        }
    } catch {
        Write-Warning "GPG not available or verification failed: $($_.Exception.Message)"
        $Results.gpg_status = 'Error'
    }
}

# --- Authenticode signature check ------------------------------------------
try {
    $sig = Get-AuthenticodeSignature -FilePath $File -ErrorAction SilentlyContinue
    if ($sig.Status -eq 'Valid') {
        Write-Output "✅ Authenticode signature valid"
        $Results.auth_status = 'Valid'
    } elseif ($sig.Status -eq 'NotSigned') {
        Write-Output "No Authenticode signature present; skipping."
        $Results.auth_status = 'NotSigned'
    } else {
        Write-Warning "❌ Authenticode signature check returned: $($sig.Status)"
        $Results.auth_status = $sig.Status
    }
} catch {
    Write-Warning "Authenticode verification failed: $($_.Exception.Message)"
    $Results.auth_status = 'Error'
}

# --- Compute overall status ------------------------------------------------
if ($Results.sha256_status -eq 'Valid' -and
    ($Results.gpg_status -in @('Valid', 'Skipped')) -and
    ($Results.auth_status -in @('Valid', 'NotSigned', 'Skipped'))) {
    $Results.overall_status = 'Success'
} else {
    $Results.overall_status = 'Fail'
}

Write-Output "📦 Verification complete (offline mode OK)."

# --- Evidence Export -------------------------------------------------------
try {
    $Root = Resolve-Path (Join-Path $PSScriptRoot '..') | ForEach-Object { $_.Path }
    $EvidencePath = Join-Path $Root 'docs/_evidence'
    if (-not (Test-Path $EvidencePath)) {
        New-Item -ItemType Directory -Path $EvidencePath | Out-Null
    }

    $Timestamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
    $OutFile = Join-Path $EvidencePath ("BaselineVerifyResult-$Timestamp.json")

    $Evidence = @{
        evidence_type  = 'BaselineVerifyResult'
        timestamp_utc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        script         = 'bin/Verify-Baseline.ps1'
        file_verified  = (Split-Path $File -Leaf)
        sha256_status  = $Results.sha256_status
        gpg_status     = $Results.gpg_status
        auth_status    = $Results.auth_status
        overall_status = $Results.overall_status
        environment    = "$env:COMPUTERNAME / PowerShell $($PSVersionTable.PSVersion)"
        retention_days = 30
        notes          = 'Offline baseline verification evidence.'
    }

    $Evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
    Write-Output "🧾 Evidence recorded → $OutFile"
} catch {
    Write-Warning "Failed to write verification evidence: $($_.Exception.Message)"
}
