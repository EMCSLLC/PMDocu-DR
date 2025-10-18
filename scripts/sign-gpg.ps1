<#
.SYNOPSIS
  Digitally signs a file (typically PDF) with GPG.

.DESCRIPTION
  Creates a detached ASCII-armored GPG signature (.asc) for a given file.
  Uses CI-friendly structured output and explicit exit codes.
  Supports PowerShell 5.1 and 7+.

.PARAMETER InputFile
  Path to the file to sign.

.PARAMETER KeyID
  Optional GPG key identifier or fingerprint. If omitted, defaults to the default key.

.PARAMETER OutDir
  Optional output directory for signature file (defaults to same as input).

.EXAMPLE
  pwsh -NoProfile -File scripts/sign-gpg.ps1 `
    -InputFile docs/releases/ChangeRequest.pdf `
    -KeyID "ACME Build Key"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputFile,

    [string]$KeyID,
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $InputFile = (Resolve-Path $InputFile).Path
    if (-not (Test-Path $InputFile)) {
        throw "Input file not found: $InputFile"
    }

    if (-not $OutDir) {
        $OutDir = Split-Path $InputFile -Parent
    }
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    }

    $SigFile = Join-Path $OutDir ("{0}.asc" -f [IO.Path]::GetFileName($InputFile))

    $gpgArgs = @(
        "--batch",
        "--yes",
        "--armor",
        "--detach-sign",
        "--output", $SigFile
    )

    if ($KeyID) {
        $gpgArgs += @("--local-user", $KeyID)
    }

    $gpgArgs += $InputFile

    Write-Verbose "Running: gpg $($gpgArgs -join ' ')"
    $process = Start-Process -FilePath "gpg" -ArgumentList $gpgArgs `
        -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -ne 0) {
        throw "GPG exited with code $($process.ExitCode)"
    }

    if (-not (Test-Path $SigFile)) {
        throw "Signature file not created: $SigFile"
    }

    # Output structured success markers
    Write-Output ("SIGNATURE_CREATED={0}" -f $SigFile)
    Write-Output ("SIGNED_FILE={0}" -f $InputFile)
    Write-Output "STATUS=SUCCESS"
} catch {
    Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
    exit 1
}
