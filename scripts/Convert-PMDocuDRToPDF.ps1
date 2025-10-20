<#
.SYNOPSIS
    Converts Markdown documents in the repo to PDF and signs them.

.DESCRIPTION
    Builds PDF documents using Pandoc and applies an Authenticode signature.
    Supports both batch conversion from a folder and single-file mode via -InputFile.
    Handles air-gapped operation gracefully (uses local timestamp if remote fails).

.PARAMETER InputFile
    Optional. Path to a specific Markdown file to convert.

.PARAMETER OutDir
    Optional. Output directory for PDFs (default: docs/releases).

.PARAMETER NoSign
    Optional. Skips signing phase for testing or air-gap build.
#>

[CmdletBinding()]
param(
    [string]$InputFile,
    [string]$OutDir = "docs/releases",
    [switch]$NoSign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Information "[init] PMDocu-DR document build started..."

# ──────────────────────────────────────────────────────────────
# Certificate handling
# ──────────────────────────────────────────────────────────────
$CertSubject = 'CN=PMDocu Local Dev'
$my = 'Cert:\CurrentUser\My'
$pub = 'Cert:\CurrentUser\TrustedPublisher'
$root = 'Cert:\CurrentUser\Root'

$cert = Get-ChildItem $my -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $CertSubject } |
    Sort-Object NotAfter -Descending | Select-Object -First 1

if (-not $cert) {
    Write-Information "[cert] Creating self-signed certificate $CertSubject"
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $CertSubject -CertStoreLocation $my
    $tmp = Join-Path $env:TEMP 'pmdocu.cert'
    Export-Certificate -Cert $cert -FilePath $tmp | Out-Null
    Import-Certificate -FilePath $tmp -CertStoreLocation $pub  | Out-Null
    Import-Certificate -FilePath $tmp -CertStoreLocation $root | Out-Null
}
Write-Information ("[cert] Using thumbprint {0} (exp {1:u})" -f $cert.Thumbprint, $cert.NotAfter)

# ──────────────────────────────────────────────────────────────
# Build logic
# ──────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) { throw "Pandoc not found. Install pandoc or add to PATH." }

# Determine which files to convert
$targets = @()
if ($InputFile) {
    if (-not (Test-Path $InputFile)) { throw "Input file not found: $InputFile" }
    $targets = @(Get-Item $InputFile)
}
else {
    $SourceDir = "docs/examples"
    if (-not (Test-Path $SourceDir)) {
        throw "Source directory not found: $SourceDir"
    }
    $targets = Get-ChildItem -Path $SourceDir -Filter *.md -ErrorAction Stop
}

# ──────────────────────────────────────────────────────────────
# Conversion and signing
# ──────────────────────────────────────────────────────────────
foreach ($file in $targets) {
    $pdf = Join-Path $OutDir ($file.BaseName + ".pdf")

    Write-Information "[build] Converting: $($file.Name)"

    $pandocArgs = @(
        $file.FullName
        '-o', $pdf
        '--pdf-engine=xelatex'
        '-V', 'mainfont=DejaVu Sans'
        '-V', 'geometry=margin=1in'
        '--from=markdown-yaml_metadata_block'
        '--standalone'
        '--quiet'
    )


    & pandoc @pandocArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Pandoc failed for $($file.Name)"
    }

    Write-Information "✅ Converted: $($file.Name) → $pdf"

    # Sign PDF (optional for air-gap mode)
    if (-not $NoSign) {
        try {
            $sig = Set-AuthenticodeSignature -FilePath $pdf `
                -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' -ErrorAction Stop
            Write-Information "🔏 Signed: $($file.BaseName).pdf ($($sig.Status))"
        }
        catch {
            Write-Warning "⚠️ Signing failed for $($file.Name): $($_.Exception.Message)"
            Write-Information "Retrying with local timestamp..."
            try {
                $sig = Set-AuthenticodeSignature -FilePath $pdf -Certificate $cert -ErrorAction Stop
                Write-Information "🔏 Signed (local): $($file.BaseName).pdf ($($sig.Status))"
            }
            catch {
                Write-Warning "❌ Local signing also failed for $($file.Name)"
            }
        }
    }
}

Write-Information "[done] PMDocu-DR document build complete."

