<#
.SYNOPSIS
    Offline verifier for PMDocu-DR Baseline Snapshots.

.DESCRIPTION
    Validates integrity of Baseline-YYYYMMDD.md files by checking:
      • SHA-256 hash file (.sha256)
      • Optional GPG detached signature (.asc)
      • Optional Authenticode signature
    Runs fully offline—no timestamp or network calls required.

.EXAMPLE
    .\bin\Verify-Baseline.ps1
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

# --- SHA-256 check ---------------------------------------------------------
$HashFile = "$File.sha256"
if (Test-Path $HashFile) {
    $expected = (Get-Content $HashFile -Raw).Split()[0]
    $actual = (Get-FileHash -Algorithm SHA256 -Path $File).Hash
    if ($expected -eq $actual) {
        Write-Output "✅ SHA-256 verified OK"
    } else {
        Write-Warning "❌ SHA-256 mismatch"
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
        } else {
            Write-Warning "❌ GPG signature verification failed:`n$verify"
        }
    } catch {
        Write-Warning "GPG not available or verification failed: $($_.Exception.Message)"
    }
} else {
    Write-Output "No GPG signature (.asc) present; skipping."
}

# --- Authenticode signature check ------------------------------------------
try {
    $sig = Get-AuthenticodeSignature -FilePath $File -ErrorAction SilentlyContinue
    if ($sig.Status -eq 'Valid') {
        Write-Output "✅ Authenticode signature valid"
    } elseif ($sig.Status -eq 'NotSigned') {
        Write-Output "No Authenticode signature present; skipping."
    } else {
        Write-Warning "❌ Authenticode signature check returned: $($sig.Status)"
    }
} catch {
    Write-Warning "Authenticode verification failed: $($_.Exception.Message)"
}

Write-Output "📦 Verification complete (offline mode OK)."
