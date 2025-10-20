<#
.SYNOPSIS
    Initializes GPG-based Git commit signing for EMCSLLC projects.

.DESCRIPTION
    Generates (or imports) a GPG key, configures Git to sign commits by default,
    and optionally prints a ready-to-paste public key block for GitHub.
    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.NOTES
    Author: EMCSLLC DevOps
    Safe for offline or air-gapped systems. Never exports private keys.
#>

[CmdletBinding()]
param(
    [string]$RealName = "EMCS LLC",
    [string]$Email = (git config --global user.email),
    [string]$Comment = "PMDocu-DR Signing Key",
    [switch]$ForceNew,
    [switch]$ExportForGitHub
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔐 Initializing GPG signing setup..." -ForegroundColor Cyan

# --- Ensure GnuPG exists ----------------------------------------------------
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    Write-Error "GnuPG (gpg) is not installed or not in PATH."
    exit 1
}

# --- List existing secret keys ---------------------------------------------
$keys = gpg --list-secret-keys --keyid-format=long 2>$null
if ($keys -and -not $ForceNew) {
    Write-Host "`nExisting GPG keys found:`n$keys" -ForegroundColor Yellow
    $existing = Read-Host "Use an existing key ID (blank to create new)"
    if ($existing) {
        git config --global user.signingkey $existing
        git config --global commit.gpgsign true
        Write-Host "✅ Configured Git to use existing key: $existing" -ForegroundColor Green
        exit 0
    }
}

# --- Create new key ---------------------------------------------------------
$KeySpec = @"
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $RealName
Name-Email: $Email
Name-Comment: $Comment
Expire-Date: 1y
%commit
"@

$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $KeySpec -Encoding Ascii
gpg --batch --gen-key $tmp
Remove-Item $tmp -Force

# --- Configure Git ----------------------------------------------------------
$keyInfo = gpg --list-secret-keys --keyid-format=long $Email |
Select-String -Pattern "sec\s+.*\/(\w{8,})" | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1

if (-not $keyInfo) {
    Write-Error "Unable to detect new GPG key ID."
    exit 1
}

git config --global user.signingkey $keyInfo
git config --global commit.gpgsign true

Write-Host "✅ New GPG key created and configured: $keyInfo" -ForegroundColor Green

# --- Optional export for GitHub --------------------------------------------
if ($ExportForGitHub) {
    Write-Host "`n📋 Public key (add to GitHub → Settings → SSH & GPG keys → New GPG key):`n"
    gpg --armor --export $keyInfo
}

Write-Host "`n🎯 Setup complete. Test signing with:" -ForegroundColor Cyan
Write-Host "   git commit -S -m 'test: verify signing'" -ForegroundColor Gray
