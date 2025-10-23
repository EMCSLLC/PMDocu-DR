<#
.SYNOPSIS
  Digitally signs a file (typically PDF) with GPG.

.DESCRIPTION
  Creates a detached ASCII-armored GPG signature (.asc) for a given file,
  generates a matching SHA-256 hash file, and writes a schema-compliant JSON
  evidence record (SignResult_<timestamp>.json) to docs/_evidence/.
  Fully compatible with PowerShell 5.1+ and 7.x+ on Windows, Linux, and macOS.
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
$InformationPreference = "Continue"

try {
  # --- Resolve input path -------------------------------------------------
  $InputFile = (Resolve-Path $InputFile).Path
  if (-not (Test-Path $InputFile)) {
    throw "Input file not found: $InputFile"
  }

  # --- Determine output directory ----------------------------------------
  if (-not $OutDir) { $OutDir = Split-Path $InputFile -Parent }
  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

  # --- Signature output file path ----------------------------------------
  $SignatureFile = Join-Path $OutDir ("{0}.asc" -f [IO.Path]::GetFileName($InputFile))

  # --- Run GPG signing ---------------------------------------------------
  $gpgArgs = @("--batch", "--yes", "--armor", "--detach-sign", "--output", $SignatureFile)
  if ($KeyID) { $gpgArgs += @("--local-user", $KeyID) }
  $gpgArgs += $InputFile

  Write-Host "🔏 Running: gpg $($gpgArgs -join ' ')"
  $process = Start-Process -FilePath "gpg" -ArgumentList $gpgArgs -Wait -NoNewWindow -PassThru
  if ($process.ExitCode -ne 0) { throw "GPG exited with code $($process.ExitCode)" }
  if (-not (Test-Path $SignatureFile)) { throw "Signature file not created: $SignatureFile" }

  # --- Generate SHA256 hash ----------------------------------------------
  $HashValue = (Get-FileHash -Algorithm SHA256 $InputFile).Hash
  $HashFile = [System.IO.Path]::ChangeExtension($InputFile, '.sha256')
  "$HashValue  $(Split-Path $InputFile -Leaf)" | Out-File -FilePath $HashFile -Encoding ascii -Force
  Write-Output ("HASH_CREATED={0}" -f $HashFile)

  # --- GPG key metadata --------------------------------------------------
  $GpgKeyId = $KeyID
  $GpgFingerprint = (gpg --list-secret-keys --with-colons | Select-String '^fpr:' | Select-Object -First 1).ToString().Split(':')[9]
  $GpgUserId = (gpg --list-secret-keys --with-colons | Select-String '^uid:' | Select-Object -First 1).ToString().Split(':')[9]
  $GpgCreated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  # --- OS info ------------------------------------------------------------
  $LibPath = Join-Path $PSScriptRoot 'lib/Get-OsInfo.ps1'
  if (Test-Path $LibPath) {
    $OsInfo = & $LibPath
  } else {
    $OsInfo = [PSCustomObject]@{
      OsName = if ($env:RUNNER_OS) { $env:RUNNER_OS } elseif ($env:OS) { $env:OS } else { "Unknown OS" }
      HostName = $env:COMPUTERNAME
      PsVersion = $PSVersionTable.PSVersion.ToString()
      Platform = $PSVersionTable.Platform
    }
  }

  $OSName = $OsInfo.OsName
  $Hostname = $OsInfo.HostName
  $PSVersion = $OsInfo.PsVersion

  # --- Evidence metadata -------------------------------------------------
  $Status = "SUCCESS"
  $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
  $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  $EvidenceDir = Join-Path (Join-Path $ScriptRoot '..') 'docs/_evidence'
  if (-not (Test-Path $EvidenceDir)) { New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null }
  $EvidenceFile = Join-Path $EvidenceDir ("SignResult_{0}.json" -f $Timestamp)

  $SignResult = [ordered]@{
    '$schema' = '../schemas/SignResult.schema.json'
    schema_version = '1.0.0'
    evidence_type = 'SignResult'
    timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    status = $Status
    input_file = $InputFile
    signed_file = $InputFile
    signature_file = $SignatureFile
    hash_file = $HashFile
    hash_sha256 = $HashValue
    signing_key = [ordered]@{
      key_id = $GpgKeyId
      fingerprint = $GpgFingerprint
      user_id = $GpgUserId
      created = $GpgCreated
      expires = $null
    }
    signing_engine = [ordered]@{
      tool = 'gpg --batch --yes --detach-sign'
      version = (gpg --version | Select-String 'gpg' | Select-Object -First 1).ToString().Trim()
      os = $OSName
      hostname = $Hostname
    }
    environment = [ordered]@{
      os = $OSName
      ps_version = $PSVersion
      hostname = $Hostname
    }
    evidence_output = $EvidenceFile
  }

  # --- Write JSON safely (trimmed, clean, BOM-free) ---
  if ($SignResult.Contains('schema_version')) {
    $SignResult.schema_version = $SignResult.schema_version.Trim()
  }

  $Json = $SignResult | ConvertTo-Json -Depth 6 -Compress
  [System.IO.File]::WriteAllText($EvidenceFile, $Json, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "🧾 Evidence JSON written: $EvidenceFile"

  # --- Schema validation -------------------------------------------------
  $SchemaPath = Join-Path (Join-Path $ScriptRoot '..') 'schemas/SignResult.schema.json'
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
  }

  # --- CI structured output ----------------------------------------------
  Write-Output ("SIGNATURE_CREATED={0}" -f $SignatureFile)
  Write-Output ("SIGNED_FILE={0}" -f $InputFile)
  Write-Output ("STATUS=SUCCESS")
} catch {
  Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
  exit 1
}

