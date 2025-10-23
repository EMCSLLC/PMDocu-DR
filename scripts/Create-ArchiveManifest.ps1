<#
.SYNOPSIS
  Creates a long-term governance evidence archive bundle (.zip) for PMDocu-DR.

.DESCRIPTION
  Collects all JSON evidence files from docs/_evidence/, generates a manifest
  (schema-compliant with EvidenceArchiveManifest.schema.json), optionally signs
  it with GPG, validates the manifest, and compresses all artifacts into
  docs/_archive/EvidenceArchive_<YEAR>.zip.
  Records its own operation as an ArchiveResult evidence JSON under docs/_evidence/.

.PARAMETER KeyID
  Optional GPG key ID or fingerprint to sign the manifest (if omitted, no signing is performed).

.PARAMETER IncludeBadge
  If specified, includes docs/badges/evidence-status.svg in the archive for
  full compliance snapshots.

.EXAMPLE
  pwsh -NoProfile -File scripts/Create-ArchiveManifest.ps1 -KeyID "EMCSLLC Compliance Key" -IncludeBadge
#>

[CmdletBinding()]
param (
    [string]$KeyID,
    [switch]$IncludeBadge
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

Write-Host "=== 🗄️ Creating Evidence Archive Manifest ==="

# --- Paths ------------------------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..')
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
$ArchiveDir = Join-Path $RepoRoot 'docs/_archive'
$SchemaPath = Join-Path $RepoRoot 'schemas/EvidenceArchiveManifest.schema.json'
$BadgePath = Join-Path $RepoRoot 'docs/badges/evidence-status.svg'

if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Force -Path $ArchiveDir | Out-Null
}

# --- Metadata ---------------------------------------------------------
$Timestamp = (Get-Date).ToUniversalTime()
$Year = $Timestamp.Year
$ArchiveID = "PMDOCU-DR-$Year"
$ManifestPath = Join-Path $ArchiveDir "EvidenceArchiveManifest.json"
$ArchiveZip = Join-Path $ArchiveDir ("EvidenceArchive_{0}.zip" -f $Year)

# --- Collect Evidence Files ------------------------------------------
$EvidenceFiles = Get-ChildItem $EvidenceDir -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue
if (-not $EvidenceFiles) {
    throw "No evidence files found in $EvidenceDir"
}

# --- Generate file index ----------------------------------------------
$fileIndex = foreach ($f in $EvidenceFiles) {
    [ordered]@{
        file = $f.Name
        hash_sha256 = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    }
}

# --- Count evidence by type ------------------------------------------
function Get-CountByType($pattern) {
    ($EvidenceFiles | Where-Object { $_.Name -like $pattern }).Count
}

$buildCount = Get-CountByType("BuildGovDocsResult*")
$signCount = Get-CountByType("SignResult*")
$verifyCount = Get-CountByType("VerifyResult*")
$schemaCount = Get-CountByType("SchemaValidation*")

# --- Environment metadata (cross-platform safe) ----------------------
$osName = if ($env:RUNNER_OS) {
    $env:RUNNER_OS
} elseif ($env:OS) {
    $env:OS
} elseif ($IsLinux) {
    (uname -srv)
} elseif ($IsMacOS) {
    (sw_vers -productName) + " " + (sw_vers -productVersion)
} elseif (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    (Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
} else {
    "Unknown OS"
}

$EnvData = [ordered]@{
    os = $osName
    ps_version = $PSVersionTable.PSVersion.ToString()
    hostname = $env:COMPUTERNAME
}

# --- Construct manifest object ---------------------------------------
$Manifest = [ordered]@{
    '$schema' = '../schemas/EvidenceArchiveManifest.schema.json'
    archive_id = $ArchiveID
    archive_version = '1.1.0'
    created_utc = $Timestamp.ToString('yyyy-MM-ddTHH:mm:ssZ')
    description = "Annual governance evidence archive for PMDocu-DR ($Year)"
    generated_by = [ordered]@{
        tool = 'PMDocu-DR Archiver'
        version = '1.1.0'
        executed_by = $env:GITHUB_ACTOR
    }
    evidence_summary = [ordered]@{
        build_results = $buildCount
        sign_results = $signCount
        verify_results = $verifyCount
        schema_results = $schemaCount
        total_artifacts = $EvidenceFiles.Count
    }
    file_index = $fileIndex
    environment = $EnvData
}

# --- Write manifest JSON ---------------------------------------------
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $ManifestPath -Encoding utf8NoBOM
Write-Host "🧾 Manifest written to: $ManifestPath"

# --- Optional signing ------------------------------------------------
if ($KeyID) {
    Write-Host "🔏 Signing manifest with GPG key: $KeyID"
    & gpg --batch --yes --armor --detach-sign --local-user $KeyID --output ($ManifestPath + ".asc") $ManifestPath
    if (Test-Path ($ManifestPath + ".asc")) {
        "$((Get-FileHash -Path $ManifestPath -Algorithm SHA256).Hash)  $(Split-Path $ManifestPath -Leaf)" |
            Set-Content -Path ($ManifestPath + ".sha256") -Encoding ascii
        Write-Host "✅ Manifest signed and hashed."
    } else {
        Write-Warning "⚠️ Failed to generate signature file."
    }
}

# --- Validate manifest (optional strict mode) -------------------------
if (Test-Path $SchemaPath) {
    try {
        $Valid = Get-Content $ManifestPath -Raw | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
        if ($Valid) {
            Write-Host "✅ Manifest validated against schema."
        }
    } catch {
        Write-Warning "⚠️ Manifest validation failed: $($_.Exception.Message)"
    }
}

# --- Compress evidence bundle ----------------------------------------
$ZipContents = @($EvidenceFiles.FullName + $ManifestPath)
if (Test-Path ($ManifestPath + ".asc")) { $ZipContents += ($ManifestPath + ".asc") }
if (Test-Path ($ManifestPath + ".sha256")) { $ZipContents += ($ManifestPath + ".sha256") }

if ($IncludeBadge -and (Test-Path $BadgePath)) {
    Write-Host "🏷️ Including badge: $BadgePath"
    $ZipContents += $BadgePath
}

Compress-Archive -Path $ZipContents -DestinationPath $ArchiveZip -Force
Write-Host "📦 Archive created: $ArchiveZip"

# --- Record archive evidence -----------------------------------------
$ArchiveEvidence = [ordered]@{
    schema_version = "1.0.0"
    evidence_type = "ArchiveResult"
    script = "scripts/Create-ArchiveManifest.ps1"
    timestamp_utc = $Timestamp.ToString("yyyy-MM-ddTHH:mm:ssZ")
    archive_file = $ArchiveZip
    manifest_file = $ManifestPath
    included_badge = [bool]$IncludeBadge
    signed = [bool](Test-Path ($ManifestPath + ".asc"))
    total_evidence = $EvidenceFiles.Count
    environment = $EnvData
    status = "SUCCESS"
}

$EvidenceFile = Join-Path $EvidenceDir ("ArchiveResult_{0}.json" -f $Timestamp.ToString("yyyyMMddTHHmmssZ"))
$ArchiveEvidence | ConvertTo-Json -Depth 6 | Set-Content -Path $EvidenceFile -Encoding utf8NoBOM
Write-Host "🧮 Archive evidence written: $EvidenceFile"

Write-Output "STATUS=SUCCESS | ARCHIVE=$ArchiveZip | FILES=$($EvidenceFiles.Count)"
