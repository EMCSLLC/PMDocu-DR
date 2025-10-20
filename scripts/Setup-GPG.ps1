<#
.SYNOPSIS
    Normalizes GPG paths and imports the verification key.

.DESCRIPTION
    Ensures a valid writable GNUPGHOME directory exists under $RUNNER_TEMP.
    Imports the specified public key in a cross-platform safe way.
    Designed for non-interactive CI pipelines.

.EXAMPLE
    pwsh scripts/Setup-GPG.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# 1️⃣ Normalize GNUPGHOME
$TempRoot = [IO.Path]::GetFullPath($Env:RUNNER_TEMP)
$GpgHome = Join-Path $TempRoot 'gnupg'
if (-not (Test-Path $GpgHome)) {
    New-Item -ItemType Directory -Force -Path $GpgHome | Out-Null
}
$Env:GNUPGHOME = $GpgHome

# 2️⃣ Import public key
$KeyPath = Join-Path $Env:RUNNER_TEMP 'public.asc'
if (-not (Test-Path $KeyPath)) {
    Write-Warning "No public.asc found at $KeyPath — skipping import."
    exit 0
}

# Ensure keyring files exist so gpg has something writable
$PubRing = Join-Path $Env:GNUPGHOME 'pubring.kbx'
if (-not (Test-Path $PubRing)) {
    $null = New-Item -ItemType File -Force -Path $PubRing
}

$import = & gpg --batch --yes --no-tty --import $KeyPath 2>&1
$code = $LASTEXITCODE
$import | Out-String | Out-File -FilePath (Join-Path $Env:RUNNER_TEMP 'gpg-import.log') -Encoding utf8

if ($code -ne 0) {
    Write-Error "GPG key import failed (exit code $code). See gpg-import.log for details."
    exit $code
}

# 3️⃣ Summarize result
$summary = [ordered]@{
    GNUPGHOME = $Env:GNUPGHOME
    KeyFile   = $KeyPath
    Status    = 'Imported'
    ExitCode  = 0
}
$summary | ConvertTo-Json -Compress | Out-File -FilePath (Join-Path $Env:RUNNER_TEMP 'gpg-setup.json') -Encoding utf8
