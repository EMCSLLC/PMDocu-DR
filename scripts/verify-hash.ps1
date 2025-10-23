<#
.SYNOPSIS
  Verifies SHA-256 hash and optional GPG signature for a file.

.DESCRIPTION
  Confirms the integrity and authenticity of an input file (typically PDF)
  by checking its SHA-256 hash against a .sha256 file and optionally verifying
  its detached GPG signature (.asc). Produces a JSON evidence file
  VerifyHashResult_<timestamp>.json in docs/_evidence/.

.PARAMETER InputFile
  Path to the file to verify (e.g. docs/releases/ChangeRequest.pdf)

.PARAMETER HashFile
  Optional .sha256 file to compare against. If omitted, assumes same basename.

.PARAMETER SignatureFile
  Optional .asc file to verify with GPG. If omitted, assumes same basename.

.EXAMPLE
  pwsh -NoProfile -File scripts/verify-hash.ps1 -InputFile docs/releases/ChangeRequest.pdf
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputFile,

  [string]$HashFile,
  [string]$SignatureFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

try {
  # --- Resolve paths --------------------------------------------------
  $InputFile = (Resolve-Path $InputFile).Path
  if (-not (Test-Path $InputFile)) {
    throw "Input file not found: $InputFile"
  }

  if (-not $HashFile) {
    $HashFile = [System.IO.Path]::ChangeExtension($InputFile, '.sha256')
  }
  if (-not (Test-Path $HashFile)) {
    throw "Hash file not found: $HashFile"
  }

  if (-not $SignatureFile) {
    $SignatureFile = "$InputFile.asc"
  }

  # --- Verify SHA256 --------------------------------------------------
  $ExpectedHash = (Get-Content $HashFile -Raw).Split(' ')[0].Trim()
  $ActualHash = (Get-FileHash -Algorithm SHA256 $InputFile).Hash

  if ($ExpectedHash -ne $ActualHash) {
    throw "SHA256 mismatch for $InputFile"
  }

  Write-Host "✅ SHA256 match confirmed for $InputFile"

  # --- Verify GPG signature ------------------------------------------
  $SignatureVerified = $false
  if (Test-Path $SignatureFile) {
    Write-Host "🔏 Verifying GPG signature..."
    $process = Start-Process -FilePath "gpg" -ArgumentList @("--verify", $SignatureFile, $InputFile) -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
      throw "GPG signature verification failed (exit code $($process.ExitCode))"
    }
    $SignatureVerified = $true
    Write-Host "✅ GPG signature verified successfully."
  } else {
    Write-Warning "⚠️  No .asc signature found for $InputFile — skipping GPG verification."
  }

  # --- Prepare evidence directory ------------------------------------
  $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  $RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..')
  $EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
  if (-not (Test-Path $EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
  }

  $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
  $EvidenceFile = Join-Path $EvidenceDir ("VerifyHashResult_{0}.json" -f $Timestamp)

  # --- Build verification evidence object -----------------------------
  $TimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

  $VerifyResult = [ordered]@{
    schema_version = '1.0.0'
    evidence_type = 'VerifyHashResult'
    script = 'scripts/verify-hash.ps1'
    timestamp_utc = $TimestampUtc
    input_file = $InputFile
    hash_file = $HashFile
    signature_file = $SignatureFile
    hash_verified = $true
    signature_verified = $SignatureVerified
    status = 'SUCCESS'
    environment = [ordered]@{
      os = if ($env:RUNNER_OS) { $env:RUNNER_OS } elseif ($env:OS) { $env:OS } else { 'Unknown OS' }
      ps_version = $PSVersionTable.PSVersion.ToString()
      hostname = $env:COMPUTERNAME
    }
  }

  # --- Write evidence JSON -------------------------------------------
  $Json = $VerifyResult | ConvertTo-Json -Depth 6 -Compress
  [System.IO.File]::WriteAllText($EvidenceFile, $Json, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "🧾 Evidence JSON written: $EvidenceFile"

  # --- Schema validation ---------------------------------------------
  $SchemaPath = Join-Path (Join-Path $ScriptRoot '..') 'schemas/VerifyHashResult.schema.json'
  if (Test-Path $SchemaPath) {
    try {
      $IsValid = Get-Content $EvidenceFile -Raw | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
      if ($IsValid) {
        Write-Host "✅ Schema validation passed for $EvidenceFile"
      } else {
        Write-Warning "⚠️ Schema validation failed for $EvidenceFile"
      }
    } catch {
      Write-Warning "⚠️ Schema validation error: $($_.Exception.Message)"
    }
  } else {
    Write-Warning "⚠️ Schema file not found: $SchemaPath"
  }

  # --- CI structured output ------------------------------------------
  Write-Output ("HASH_VERIFIED={0}" -f $InputFile)
  Write-Output ("SIGNATURE_VERIFIED={0}" -f $SignatureFile)
  Write-Output ("STATUS=SUCCESS")

} catch {
  Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
  exit 1
}
