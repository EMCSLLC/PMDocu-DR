<#
.SYNOPSIS
  Generates and verifies a SHA-256 hash for a file.

.DESCRIPTION
  Computes the SHA-256 checksum of the specified file and, if a matching
  .sha256 file exists, verifies its contents. If no hash file exists, one
  is created automatically beside the input file.

  Produces CI-friendly output (STATUS=..., HASH_VERIFIED=..., etc.)
  and returns exit code 1 on any mismatch or failure.

.PARAMETER InputFile
  Path to the file to verify or hash.

.PARAMETER OutDir
  Optional output folder for the .sha256 file (defaults to same directory).

.PARAMETER Quiet
  Suppresses normal output (useful for CI runs).

.EXAMPLE
  pwsh -NoProfile -File scripts/verify-hash.ps1 -InputFile docs/releases/ChangeRequest.pdf

.EXAMPLE
  pwsh -NoProfile -File scripts/verify-hash.ps1 -InputFile docs/releases/ChangeRequest.pdf -Quiet
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputFile,

  [string]$OutDir,
  [switch]$Quiet
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

  $HashFile = Join-Path $OutDir ("{0}.sha256" -f [IO.Path]::GetFileName($InputFile))

  # Compute new hash
  $sha256 = Get-FileHash -Algorithm SHA256 -Path $InputFile
  $computedHash = $sha256.Hash.ToLowerInvariant()

  if (-not (Test-Path $HashFile)) {
    # Create new .sha256 file
    "$computedHash *$($sha256.Path | Split-Path -Leaf)" | Out-File -FilePath $HashFile -Encoding ascii -Force
    if (-not $Quiet) { Write-Output ("HASH_CREATED={0}" -f $HashFile) }
    Write-Output ("STATUS=SUCCESS | MESSAGE=Hash file created")
    exit 0
  }

  # Read expected hash
  $expectedLine = Get-Content -Path $HashFile -ErrorAction Stop | Select-Object -First 1
  $expectedHash = ($expectedLine -split '\s+')[0].ToLowerInvariant()

  if ($computedHash -eq $expectedHash) {
    if (-not $Quiet) {
      Write-Output ("HASH_VERIFIED={0}" -f $HashFile)
      Write-Output ("FILE={0}" -f $InputFile)
    }
    Write-Output "STATUS=SUCCESS"
    exit 0
  } else {
    Write-Error ("STATUS=FAILURE | MESSAGE=Hash mismatch for {0}" -f $InputFile)
    Write-Error ("EXPECTED={0}" -f $expectedHash)
    Write-Error ("COMPUTED={0}" -f $computedHash)
    exit 1
  }
} catch {
  Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
  exit 1
}
