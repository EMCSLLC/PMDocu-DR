<#
.SYNOPSIS
    Imports a pre-generated GPG key into CI and configures Git to sign commits or tags.

.DESCRIPTION
    Designed for GitHub Actions or other ephemeral CI runners.
    It reads base64-encoded environment variables that hold the armored
    private and public keys, imports them into a temporary GPG home,
    and cleans up afterward.

    Expected environment variables:
      GPG_PRIVATE_KEY_B64 – base64-encoded private key (ASCII-armored)
      GPG_PUBLIC_KEY_B64  – base64-encoded public key  (ASCII-armored)
      GPG_KEY_ID          – optional key ID (used for git config)
      GPG_PASSPHRASE      – optional, if key is protected

.NOTES
    Safe for CI use; no keys written to persistent storage.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔐 Setting up temporary GPG environment..." -ForegroundColor Cyan

# --- Prepare temp GPG home ---------------------------------------------------
$env:GNUPGHOME = Join-Path $env:RUNNER_TEMP "gnupg"
New-Item -ItemType Directory -Force -Path $env:GNUPGHOME | Out-Null

# --- Decode and import keys --------------------------------------------------
if (-not $env:GPG_PRIVATE_KEY_B64) {
    Write-Error "Environment variable GPG_PRIVATE_KEY_B64 is required."
    exit 1
}

# Private key
$privatePath = Join-Path $env:RUNNER_TEMP "private.asc"
[System.IO.File]::WriteAllBytes($privatePath, [Convert]::FromBase64String($env:GPG_PRIVATE_KEY_B64))
gpg --batch --import $privatePath
Remove-Item $privatePath -Force

# Public key (optional)
if ($env:GPG_PUBLIC_KEY_B64) {
    $publicPath = Join-Path $env:RUNNER_TEMP "public.asc"
    [System.IO.File]::WriteAllBytes($publicPath, [Convert]::FromBase64String($env:GPG_PUBLIC_KEY_B64))
    gpg --batch --import $publicPath
    Remove-Item $publicPath -Force
}

# --- Configure Git -----------------------------------------------------------
$KeyId = if ($env:GPG_KEY_ID) { $env:GPG_KEY_ID } else {
    gpg --list-secret-keys --keyid-format=long |
    Select-String -Pattern "sec\s+.*\/(\w{8,})" |
    ForEach-Object { $_.Matches.Groups[1].Value } |
    Select-Object -First 1
}

git config --global user.signingkey $KeyId
git config --global commit.gpgsign true
git config --global gpg.program "gpg"

Write-Host "✅ GPG key $KeyId imported and configured for signing" -ForegroundColor Green

# --- Optional passphrase cache ----------------------------------------------
if ($env:GPG_PASSPHRASE) {
    Write-Output "test" | gpg --batch --pinentry-mode loopback --passphrase $env:GPG_PASSPHRASE --sign 2>$null
    Write-Host "🔑 Passphrase cached for current job."
}

# --- Test --------------------------------------------------------------------
git config --global --get user.signingkey | Out-String | Write-Host
gpg --list-secret-keys --keyid-format=short | Write-Host
