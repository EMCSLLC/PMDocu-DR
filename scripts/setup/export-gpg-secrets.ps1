<#
.SYNOPSIS
    Exports your GPG keypair (private + public) as base64 text files for GitHub Actions.
#>

$keyId = "0B57BB923F762D1E"
$outDir = "C:\PMDocu-DR\gpg_secrets"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "📦 Exporting and encoding GPG keys for CI..."

# Private key
$privateFile = Join-Path $outDir "CI_GPG_PRIVATE_KEY.asc"
$privateB64  = Join-Path $outDir "CI_GPG_PRIVATE_KEY_B64.txt"
gpg --export-secret-keys --armor $keyId | Out-File $privateFile -Encoding ascii
[Convert]::ToBase64String([IO.File]::ReadAllBytes($privateFile)) | Out-File $privateB64 -Encoding ascii

# Public key
$publicFile = Join-Path $outDir "CI_GPG_PUBLIC_KEY.asc"
$publicB64  = Join-Path $outDir "CI_GPG_PUBLIC_KEY_B64.txt"
gpg --export --armor $keyId | Out-File $publicFile -Encoding ascii
[Convert]::ToBase64String([IO.File]::ReadAllBytes($publicFile)) | Out-File $publicB64 -Encoding ascii

# Passphrase placeholder
$passphraseFile = Join-Path $outDir "CI_GPG_PASSPHRASE.txt"
"ENTER_YOUR_SECURE_PASSPHRASE_HERE" | Out-File $passphraseFile -Encoding ascii

Write-Host "`n✅ Export complete! Files ready in: $outDir"
